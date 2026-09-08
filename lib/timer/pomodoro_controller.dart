import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/constants.dart';
import '../core/day_key.dart';
import '../core/formatting.dart';
import '../data/habit_repository.dart';
import '../data/models/app_settings.dart';
import '../data/models/focus_session.dart';
import '../data/models/pomodoro_phase.dart';
import '../data/models/timer_preset.dart';
import '../data/session_repository.dart';
import '../data/settings_repository.dart';
import '../providers.dart';
import 'alarm_player.dart';
import 'dnd_service.dart';
import 'exact_alarm_channel.dart';
import 'foreground_service.dart';
import 'notification_service.dart';
import 'pomodoro_state.dart';

/// A single interval that just finished, published so the UI can celebrate.
class PhaseCompletion {
  const PhaseCompletion({
    required this.phase,
    required this.next,
    required this.at,
    required this.autoStarted,
  });

  final PomodoroPhase phase;
  final PomodoroPhase next;
  final DateTime at;
  final bool autoStarted;
}

/// Drives the Pomodoro engine.
///
/// Correctness rules this class is built around:
///   * `endsAt` is authoritative. Nothing accumulates ticks.
///   * Every transition is persisted immediately, so a killed process can be
///     reconstructed exactly on the next launch.
///   * Intervals that elapsed while the app was away are replayed in order by
///     [_catchUp], using their real timestamps, so history and streaks are
///     right even if the app was gone for hours.
class PomodoroController extends Notifier<PomodoroState> {
  late final SettingsRepository _settings;
  late final SessionRepository _sessions;
  late final HabitRepository _habits;
  late final NotificationService _notifications;
  late final AlarmPlayer _alarm;

  late List<TimerPreset> _presets;
  late AppSettings _appSettings;

  Timer? _ticker;
  StreamSubscription<bool>? _exactAlarmSub;

  /// Repaints and completions are driven off this; it is a *display* clock.
  static const _tickInterval = Duration(milliseconds: 200);

  final _completions = StreamController<PhaseCompletion>.broadcast();
  Stream<PhaseCompletion> get completions => _completions.stream;

  /// Bumped whenever history changes so dependent providers can refresh.
  final historyRevision = ValueNotifier<int>(0);

  /// Display clock. Countdown widgets listen to this rather than to the timer
  /// state, so a running session repaints two small widgets, not the screen.
  final clock = ValueNotifier<DateTime>(DateTime.now());

  @override
  PomodoroState build() {
    // Dependencies are read, not watched: this notifier must survive for the
    // life of the app, and a rebuild would drop a running session.
    final boot = ref.read(bootstrapProvider);
    _settings = boot.settings;
    _notifications = boot.notifications;
    _alarm = boot.alarm;
    _sessions = ref.read(sessionRepositoryProvider);
    _habits = ref.read(habitRepositoryProvider);
    _presets = ref.read(presetsProvider);
    _appSettings = ref.read(settingsProvider);

    ref.onDispose(() {
      _ticker?.cancel();
      _exactAlarmSub?.cancel();
      _completions.close();
      historyRevision.dispose();
      clock.dispose();
      dndActive.dispose();
      // Never leave the user silenced because the app went away.
      unawaited(DndService.disable());
    });

    _exactAlarmSub = ExactAlarmChannel.permissionChanges.listen((granted) {
      // The OS drops queued exact alarms when the permission is revoked, so
      // re-arm the chain as soon as it comes back.
      if (granted && state.status == TimerStatus.running) {
        unawaited(_rescheduleAlerts());
      }
    });

    final restored = _restore();
    scheduleMicrotask(() => resync());
    return restored;
  }

  // --- wiring ----------------------------------------------------------

  TimerPreset get preset => presetById(state.presetId);

  TimerPreset presetById(String id) => _presets.firstWhere(
        (p) => p.id == id,
        orElse: () => _presets.isEmpty ? TimerPreset.defaults.first : _presets.first,
      );

  void updatePresets(List<TimerPreset> presets) {
    _presets = presets;
    if (state.status == TimerStatus.idle) {
      final p = presetById(state.presetId);
      state = state.copyWith(
        plannedDuration: p.durationFor(state.phase),
        sessionsBeforeLongBreak: p.sessionsBeforeLongBreak,
      );
    }
  }

  void updateAppSettings(AppSettings settings) {
    final wasAuto = _appSettings.autoStartNext;
    _appSettings = settings;
    if (state.status == TimerStatus.running &&
        (settings.autoStartNext != wasAuto)) {
      state = state.copyWith(autoStartNext: settings.autoStartNext);
      unawaited(_persist());
      unawaited(_rescheduleAlerts());
    }
    unawaited(_applyWakelock());
  }

  PomodoroState _restore() {
    final json = _settings.loadTimerState();
    final fallback = PomodoroState.initial(
      presetById(_appSettings.activePresetId),
    ).copyWith(autoStartNext: _appSettings.autoStartNext);
    if (json == null) return fallback;
    try {
      return PomodoroStateJson.fromJson(json);
    } catch (e) {
      debugPrint('Pomo Sauce: could not restore timer state ($e)');
      return fallback;
    }
  }

  Future<void> _persist() =>
      _settings.saveTimerState(state.isActive || state.status == TimerStatus.ringing
          ? state.toJson()
          : null);

  // --- public commands -------------------------------------------------

  /// Chooses a preset without starting anything.
  void selectPreset(String presetId) {
    if (state.isActive) return;
    final p = presetById(presetId);
    state = state.copyWith(
      presetId: p.id,
      plannedDuration: p.durationFor(state.phase),
      sessionsBeforeLongBreak: p.sessionsBeforeLongBreak,
      autoStartNext: _appSettings.autoStartNext,
    );
  }

  void linkHabit(String? habitId) {
    state = habitId == null
        ? state.copyWith(clearHabit: true)
        : state.copyWith(linkedHabitId: habitId);
    unawaited(_persist());
  }

  /// Starts (or restarts) the current phase.
  ///
  /// Returns false when notification permission was refused - the caller
  /// shows the "you will not be alerted" explainer in that case.
  Future<bool> start({String? presetId, String? habitId}) async {
    final granted = await TimerForegroundService.ensureNotificationPermission();
    if (granted) {
      await _notifications.requestNotificationPermission();
    }

    final p = presetId != null ? presetById(presetId) : preset;
    final now = DateTime.now();
    final duration = p.durationFor(state.phase);

    _dndSuppressedThisSession = false;
    state = state.copyWith(
      status: TimerStatus.running,
      presetId: p.id,
      plannedDuration: duration,
      endsAt: now.add(duration),
      phaseStartedAt: now,
      remainingWhenPaused: Duration.zero,
      linkedHabitId: habitId ?? state.linkedHabitId,
      autoStartNext: _appSettings.autoStartNext,
      sessionsBeforeLongBreak: p.sessionsBeforeLongBreak,
    );

    await _afterTransition();
    return granted;
  }

  Future<void> pause() async {
    if (state.status != TimerStatus.running) return;
    final remaining = state.remainingAt(DateTime.now());
    state = state.copyWith(
      status: TimerStatus.paused,
      remainingWhenPaused: remaining,
      clearEndsAt: true,
    );
    await _afterTransition();
  }

  Future<void> resume() async {
    if (state.status != TimerStatus.paused) return;
    final now = DateTime.now();
    state = state.copyWith(
      status: TimerStatus.running,
      endsAt: now.add(state.remainingWhenPaused),
      remainingWhenPaused: Duration.zero,
    );
    await _afterTransition();
  }

  Future<void> toggle() =>
      state.status == TimerStatus.running ? pause() : resume();

  /// Abandons the current interval. Focus intervals are still written to
  /// history (marked incomplete) so the user can see what actually happened.
  Future<void> stop({bool recordPartial = true}) async {
    await _alarm.stop();
    final started = state.phaseStartedAt;
    if (recordPartial &&
        state.isActive &&
        started != null &&
        state.phase == PomodoroPhase.focus) {
      final now = DateTime.now();
      final elapsed = state.plannedDuration - state.remainingAt(now);
      if (elapsed.inSeconds >= 60) {
        await _recordSession(
          startedAt: started,
          endedAt: now,
          elapsed: elapsed,
          completed: false,
        );
      }
    }

    final p = preset;
    state = PomodoroState.initial(p).copyWith(
      completedFocusInCycle: state.completedFocusInCycle,
      linkedHabitId: state.linkedHabitId,
      autoStartNext: _appSettings.autoStartNext,
    );
    await _afterTransition();
  }

  /// Jumps straight to the next interval without crediting the current one.
  Future<void> skip() async {
    await _alarm.stop();
    final next = state.nextAfter();
    final p = preset;
    state = state.copyWith(
      status: TimerStatus.idle,
      phase: next.phase,
      completedFocusInCycle: next.completedFocusInCycle,
      plannedDuration: p.durationFor(next.phase),
      clearEndsAt: true,
      clearPhaseStartedAt: true,
      remainingWhenPaused: Duration.zero,
    );
    await _afterTransition();
    if (_appSettings.autoStartNext) await start();
  }

  /// Dismisses the alarm after an interval ends and queues the next one.
  Future<void> dismissAlarm({bool startNext = false}) async {
    await _alarm.stop();
    if (state.status == TimerStatus.ringing) {
      state = state.copyWith(status: TimerStatus.idle);
      await _afterTransition();
    }
    if (startNext) await start();
  }

  /// Adds time to a running interval - the "just five more minutes" case.
  Future<void> extend(Duration by) async {
    if (state.status != TimerStatus.running || state.endsAt == null) return;
    state = state.copyWith(
      endsAt: state.endsAt!.add(by),
      plannedDuration: state.plannedDuration + by,
    );
    await _afterTransition();
  }

  /// Re-reads the wall clock. Called on every app resume and on a display
  /// tick; this is what makes a backgrounded timer land correctly.
  Future<void> resync() async {
    await _catchUp();
    _ensureTicker();
    // A session restored after process death should be silenced again if it
    // is still running: startup hands the user's own mode back first, then
    // this re-engages only if a focus interval is genuinely still going.
    await _guarded(_syncDnd, 'do not disturb');
    await _applyWakelock();
  }

  // --- the engine ------------------------------------------------------

  void _ensureTicker() {
    final needed = state.status == TimerStatus.running;
    if (needed && _ticker == null) {
      _ticker = Timer.periodic(_tickInterval, (_) => _onTick());
    } else if (!needed) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  void _onTick() {
    final now = DateTime.now();
    if (state.isElapsedAt(now)) {
      unawaited(_catchUp());
      return;
    }
    // Only the clock advances. The state object is unchanged - remaining time
    // is derived - so just the countdown widgets repaint, not the whole tree.
    clock.value = now;
  }

  /// Replays every interval boundary that has already passed.
  ///
  /// Runs on resume, on cold start, and on each tick. Boundaries are replayed
  /// in order with their true timestamps, so a session that ended 40 minutes
  /// ago is filed at the time it actually ended.
  ///
  /// Auto-start chaining is capped at the number of boundaries we actually
  /// scheduled alerts for. Beyond that the user was never notified, so they
  /// plainly were not working the cycle - a phone left in a drawer overnight
  /// must not wake up having logged nine focus sessions nobody sat through.
  /// When the cap is hit the timer goes quietly idle instead.
  Future<void> _catchUp() async {
    const maxReplay = AppConstants.maxScheduledChainLength;
    var replayed = 0;
    var changed = false;
    var autoStarted = false;
    var lostTheThread = false;

    while (state.isElapsedAt(DateTime.now()) && replayed < maxReplay) {
      final endedAt = state.endsAt!;
      final startedAt =
          state.phaseStartedAt ?? endedAt.subtract(state.plannedDuration);
      final ended = state.phase;
      final next = state.nextAfter();

      if (ended == PomodoroPhase.focus) {
        await _recordSession(
          startedAt: startedAt,
          endedAt: endedAt,
          elapsed: state.plannedDuration,
          completed: true,
        );
        await _creditLinkedHabit(endedAt);
      }

      replayed++;
      final nextDuration = preset.durationFor(next.phase);
      final canChain = state.autoStartNext && replayed < maxReplay;

      if (canChain) {
        // Chain from the boundary that just passed, not from now, so a late
        // catch-up does not drift the schedule.
        state = state.copyWith(
          status: TimerStatus.running,
          phase: next.phase,
          completedFocusInCycle: next.completedFocusInCycle,
          plannedDuration: nextDuration,
          phaseStartedAt: endedAt,
          endsAt: endedAt.add(nextDuration),
        );
        autoStarted = true;
      } else {
        lostTheThread = state.autoStartNext;
        state = state.copyWith(
          status: lostTheThread ? TimerStatus.idle : TimerStatus.ringing,
          phase: next.phase,
          completedFocusInCycle: next.completedFocusInCycle,
          plannedDuration: nextDuration,
          clearEndsAt: true,
          clearPhaseStartedAt: true,
        );
      }

      changed = true;
      _completions.add(PhaseCompletion(
        phase: ended,
        next: next.phase,
        at: endedAt,
        autoStarted: canChain,
      ));

      if (state.status != TimerStatus.running) break;
    }

    if (!changed) return;

    if (state.status == TimerStatus.ringing) {
      await _ring();
    } else if (autoStarted || lostTheThread) {
      // Silent hand-off: the scheduled notification chain already alerted,
      // or we gave up chaining and there is nothing to announce.
      await _alarm.stop();
    }
    await _afterTransition();
    historyRevision.value++;
  }

  Future<void> _ring() async {
    await _alarm.start(
      _appSettings.alarmTone,
      sound: _appSettings.soundEnabled,
      vibration: _appSettings.vibrationEnabled,
      volume: _appSettings.alarmVolume,
    );
  }

  Future<void> _recordSession({
    required DateTime startedAt,
    required DateTime endedAt,
    required Duration elapsed,
    required bool completed,
  }) async {
    await _sessions.insert(
      FocusSession(
        id: '${startedAt.microsecondsSinceEpoch}-${state.phase.name}',
        phase: PomodoroPhase.focus,
        startedAt: startedAt,
        endedAt: endedAt,
        plannedSeconds: state.plannedDuration.inSeconds,
        actualSeconds: elapsed.inSeconds,
        completed: completed,
        presetId: state.presetId,
        habitId: state.linkedHabitId,
      ),
    );
    historyRevision.value++;
  }

  /// A completed focus session ticks its linked habit off for that day.
  Future<void> _creditLinkedHabit(DateTime at) async {
    final habitId = state.linkedHabitId;
    if (habitId == null) return;
    final day = DayKey.of(at);
    if (await _habits.isDone(habitId, day)) return;
    await _habits.setDone(habitId, day, done: true, source: 'pomodoro');
    historyRevision.value++;
  }

  /// Persist, re-arm the OS alerts, and bring the service in line with the
  /// new state. Every command funnels through here so the three can never
  /// disagree with each other.
  Future<void> _afterTransition() async {
    _ensureTicker();
    await _persist();
    // Each step is isolated: if the OS refuses to schedule an alarm, we still
    // want the foreground service running and the state persisted.
    await _guarded(_rescheduleAlerts, 'schedule alerts');
    await _guarded(_syncForegroundService, 'foreground service');
    await _guarded(_syncDnd, 'do not disturb');
    await _guarded(_applyWakelock, 'wakelock');
  }

  Future<void> _guarded(Future<void> Function() step, String label) async {
    try {
      await step();
    } catch (e) {
      debugPrint('Pomo Sauce: $label failed ($e)');
    }
  }

  /// Builds the upcoming boundary list and hands it to the OS.
  List<ScheduledAlert> _upcomingAlerts() {
    if (state.status != TimerStatus.running || state.endsAt == null) {
      return const [];
    }
    final alerts = <ScheduledAlert>[];
    var phase = state.phase;
    var cycle = state.completedFocusInCycle;
    var boundary = state.endsAt!;
    final p = preset;

    final limit = state.autoStartNext ? 8 : 1;
    for (var i = 0; i < limit; i++) {
      final probe = PomodoroState(
        status: TimerStatus.running,
        phase: phase,
        presetId: p.id,
        plannedDuration: p.durationFor(phase),
        completedFocusInCycle: cycle,
        sessionsBeforeLongBreak: p.sessionsBeforeLongBreak,
      );
      final next = probe.nextAfter();
      alerts.add(ScheduledAlert(
        phase: phase,
        firesAt: boundary,
        nextPhase: next.phase,
      ));
      phase = next.phase;
      cycle = next.completedFocusInCycle;
      boundary = boundary.add(p.durationFor(phase));
    }
    return alerts;
  }

  Future<void> _rescheduleAlerts() async {
    await _notifications.scheduleChain(
      _upcomingAlerts(),
      tone: _appSettings.alarmTone,
      sound: _appSettings.soundEnabled,
      vibration: _appSettings.vibrationEnabled,
    );
  }

  Future<void> _syncForegroundService() async {
    if (state.status == TimerStatus.running ||
        state.status == TimerStatus.paused) {
      await TimerForegroundService.start(
        title: state.status == TimerStatus.paused
            ? '${state.phase.label} paused'
            : state.phase.label,
        text: '${formatCountdown(state.remainingAt(DateTime.now()))} remaining',
      );
    } else if (state.status != TimerStatus.ringing) {
      await TimerForegroundService.stop();
    }
  }

  /// Whether this app is currently holding the phone in Do Not Disturb.
  /// Drives the "DND is on - tap to disable" chip on the focus screen.
  final dndActive = ValueNotifier<bool>(false);

  /// Suppresses DND for the current session only, when the user taps the chip.
  /// Cleared on the next start so opting out once is not permanent.
  bool _dndSuppressedThisSession = false;

  /// Silence the phone only while a *work* interval is actually running, and
  /// hand it straight back otherwise - on a break, a pause, a stop, or the
  /// completion alert. Breaks are deliberately left un-silenced: the user is
  /// meant to be away from the app.
  Future<void> _syncDnd() async {
    if (!DndService.isSupported) return;

    final shouldSilence = _appSettings.dndDuringFocus &&
        !_dndSuppressedThisSession &&
        state.status == TimerStatus.running &&
        state.phase == PomodoroPhase.focus;

    if (shouldSilence) {
      if (dndActive.value) return;
      if (!await DndService.isPolicyAccessGranted()) return;
      dndActive.value = await DndService.enable();
    } else if (dndActive.value || await DndService.isHoldingDnd()) {
      await DndService.disable();
      dndActive.value = false;
    }
  }

  /// The per-session opt-out behind the focus-screen chip. Never silently
  /// changes the user's setting - just this session.
  Future<void> suppressDndForThisSession() async {
    _dndSuppressedThisSession = true;
    await _syncDnd();
  }

  Future<void> _applyWakelock() async {
    final shouldHold = _appSettings.keepScreenOn &&
        state.status == TimerStatus.running &&
        _focusScreenVisible;
    try {
      final held = await WakelockPlus.enabled;
      if (shouldHold != held) await WakelockPlus.toggle(enable: shouldHold);
    } catch (e) {
      debugPrint('Pomo Sauce: wakelock unavailable ($e)');
    }
  }

  bool _focusScreenVisible = false;

  /// The Focus Display tells the controller when it is on screen, so the
  /// wakelock is only held while the user can actually see the countdown.
  void setFocusScreenVisible(bool visible) {
    if (_focusScreenVisible == visible) return;
    _focusScreenVisible = visible;
    unawaited(_applyWakelock());
  }

  Future<void> previewTone(AlarmTone tone) =>
      _alarm.preview(tone, volume: _appSettings.alarmVolume);

  Future<void> stopPreview() => _alarm.stop();
}
