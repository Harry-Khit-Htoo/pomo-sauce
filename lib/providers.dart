import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/day_key.dart';
import 'data/app_database.dart';
import 'data/habit_repository.dart';
import 'data/models/app_settings.dart';
import 'data/models/focus_session.dart';
import 'data/models/habit.dart';
import 'data/models/timer_preset.dart';
import 'data/session_repository.dart';
import 'data/settings_repository.dart';
import 'mascot/mascot_mood.dart';
import 'mascot/mood_selector.dart';
import 'timer/alarm_player.dart';
import 'timer/notification_service.dart';
import 'timer/pomodoro_controller.dart';
import 'timer/pomodoro_state.dart';

/// Everything that has to exist before the first frame. Created once in
/// main() and injected with a ProviderScope override, so no provider in the
/// tree ever has to deal with an uninitialised singleton.
class AppBootstrap {
  const AppBootstrap({
    required this.database,
    required this.settings,
    required this.notifications,
    required this.alarm,
  });

  final AppDatabase database;
  final SettingsRepository settings;
  final NotificationService notifications;
  final AlarmPlayer alarm;
}

final bootstrapProvider = Provider<AppBootstrap>(
  (ref) => throw UnimplementedError('bootstrapProvider must be overridden'),
);

final settingsRepositoryProvider =
    Provider<SettingsRepository>((ref) => ref.watch(bootstrapProvider).settings);

final habitRepositoryProvider = Provider<HabitRepository>(
  (ref) => HabitRepository(ref.watch(bootstrapProvider).database),
);

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepository(ref.watch(bootstrapProvider).database),
);

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => ref.watch(bootstrapProvider).notifications,
);

final alarmPlayerProvider =
    Provider<AlarmPlayer>((ref) => ref.watch(bootstrapProvider).alarm);

// --- settings ----------------------------------------------------------

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(settingsRepositoryProvider).load();

  Future<void> _write(AppSettings next) async {
    state = next;
    await ref.read(settingsRepositoryProvider).save(next);
    ref.read(pomodoroProvider.notifier).updateAppSettings(next);
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      _write(state.copyWith(themeMode: mode));
  Future<void> setTone(AlarmTone tone) => _write(state.copyWith(alarmTone: tone));
  Future<void> setVolume(double v) => _write(state.copyWith(alarmVolume: v));
  Future<void> setSound(bool v) => _write(state.copyWith(soundEnabled: v));
  Future<void> setVibration(bool v) =>
      _write(state.copyWith(vibrationEnabled: v));
  Future<void> setKeepScreenOn(bool v) =>
      _write(state.copyWith(keepScreenOn: v));
  Future<void> setDimDuringFocus(bool v) =>
      _write(state.copyWith(dimDuringFocus: v));
  Future<void> setAutoStart(bool v) => _write(state.copyWith(autoStartNext: v));
  Future<void> setActivePreset(String id) =>
      _write(state.copyWith(activePresetId: id));
  Future<void> completeOnboarding() =>
      _write(state.copyWith(onboardingComplete: true));
  Future<void> markPrimerShown() =>
      _write(state.copyWith(notificationPrimerShown: true));
  Future<void> setDndDuringFocus(bool v) =>
      _write(state.copyWith(dndDuringFocus: v));
  Future<void> markDndExplainerShown() =>
      _write(state.copyWith(dndExplainerShown: true));
}

final settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

// --- presets -----------------------------------------------------------

class PresetsController extends Notifier<List<TimerPreset>> {
  @override
  List<TimerPreset> build() => ref.watch(settingsRepositoryProvider).loadPresets();

  Future<void> _write(List<TimerPreset> next) async {
    state = next;
    await ref.read(settingsRepositoryProvider).savePresets(next);
    ref.read(pomodoroProvider.notifier).updatePresets(next);
  }

  Future<void> save(TimerPreset preset) async {
    final next = [...state];
    final i = next.indexWhere((p) => p.id == preset.id);
    if (i >= 0) {
      next[i] = preset;
    } else {
      next.add(preset);
    }
    await _write(next);
  }

  Future<void> remove(String id) async {
    if (state.length <= 1) return;
    await _write(state.where((p) => p.id != id).toList());
  }

  Future<void> restoreDefaults() async {
    await ref.read(settingsRepositoryProvider).resetPresets();
    await _write(List.of(TimerPreset.defaults));
  }
}

final presetsProvider =
    NotifierProvider<PresetsController, List<TimerPreset>>(PresetsController.new);

final activePresetProvider = Provider<TimerPreset>((ref) {
  final presets = ref.watch(presetsProvider);
  final id = ref.watch(pomodoroProvider.select((s) => s.presetId));
  return presets.firstWhere(
    (p) => p.id == id,
    orElse: () => presets.isEmpty ? TimerPreset.defaults.first : presets.first,
  );
});

// --- timer -------------------------------------------------------------

final pomodoroProvider =
    NotifierProvider<PomodoroController, PomodoroState>(PomodoroController.new);

/// Fires once per completed interval; the UI uses it to celebrate.
final phaseCompletionProvider = StreamProvider<PhaseCompletion>(
  (ref) => ref.watch(pomodoroProvider.notifier).completions,
);

/// Bumped by the controller every time history changes, so the data
/// providers below refetch without polling.
final historyRevisionProvider = Provider<int>((ref) {
  final controller = ref.watch(pomodoroProvider.notifier);
  void listener() => ref.invalidateSelf();
  controller.historyRevision.addListener(listener);
  ref.onDispose(() => controller.historyRevision.removeListener(listener));
  return controller.historyRevision.value;
});

// --- habits ------------------------------------------------------------

final habitProgressProvider = FutureProvider<List<HabitProgress>>((ref) async {
  ref.watch(historyRevisionProvider);
  return ref.watch(habitRepositoryProvider).allProgress();
});

final habitsProvider = FutureProvider<List<Habit>>((ref) async {
  ref.watch(historyRevisionProvider);
  return ref.watch(habitRepositoryProvider).allHabits();
});

/// The habit whose streak is closest to lapsing, if any - drives the
/// concerned mascot on the home screen.
final streakAtRiskProvider = Provider<HabitProgress?>((ref) {
  final progress = ref.watch(habitProgressProvider).value;
  if (progress == null) return null;
  final atRisk = progress.where((p) => p.streakAtRisk).toList()
    ..sort((a, b) => b.currentStreak.compareTo(a.currentStreak));
  return atRisk.isEmpty ? null : atRisk.first;
});

// --- history -----------------------------------------------------------

final todaySummaryProvider = FutureProvider<TodaySummary>((ref) async {
  ref.watch(historyRevisionProvider);
  final habits = await ref.watch(habitRepositoryProvider).allProgress();
  final dueToday =
      habits.where((p) => p.habit.isDueOn(DateTime.now())).toList();
  return ref.watch(sessionRepositoryProvider).todaySummary(
        habitsDone: dueToday.where((p) => p.doneToday).length,
        habitsTotal: dueToday.length,
      );
});

/// Day-key -> stats, covering the last 26 weeks for the heatmap.
final heatmapProvider = FutureProvider<Map<String, DayStats>>((ref) async {
  ref.watch(historyRevisionProvider);
  final today = DateTime.now();
  final from = DayKey.of(today.subtract(const Duration(days: 26 * 7)));
  final to = DayKey.of(today);
  final habitCounts =
      await ref.watch(habitRepositoryProvider).completionCountsBetween(from, to);
  return ref.watch(sessionRepositoryProvider).statsBetween(from, to, habitCounts);
});

final weeklyChartProvider =
    FutureProvider<List<({String day, int seconds, int count})>>((ref) async {
  ref.watch(historyRevisionProvider);
  return ref.watch(sessionRepositoryProvider).lastDays(7);
});

final selectedHistoryDayProvider =
    NotifierProvider<SelectedDayController, DateTime>(SelectedDayController.new);

class SelectedDayController extends Notifier<DateTime> {
  @override
  DateTime build() => DayKey.startOfDay(DateTime.now());

  void select(DateTime day) => state = DayKey.startOfDay(day);
}

final sessionsOnDayProvider = FutureProvider<List<FocusSession>>((ref) async {
  ref.watch(historyRevisionProvider);
  final day = ref.watch(selectedHistoryDayProvider);
  return ref.watch(sessionRepositoryProvider).onDay(DayKey.of(day));
});

final habitsDoneOnDayProvider = FutureProvider<Set<String>>((ref) async {
  ref.watch(historyRevisionProvider);
  final day = ref.watch(selectedHistoryDayProvider);
  return ref.watch(habitRepositoryProvider).completedOn(DayKey.of(day));
});

final totalSessionsProvider = FutureProvider<int>((ref) async {
  ref.watch(historyRevisionProvider);
  return ref.watch(sessionRepositoryProvider).totalCompletedFocusSessions();
});


// --- mascot -------------------------------------------------------------

/// The mascot's mood, derived from real behaviour rather than a static loop.
///
/// Everything the face reacts to funnels through here, so a screen only ever
/// asks "what mood?" and never re-implements the rules.
final mascotMoodProvider = Provider<MascotMood>((ref) {
  final onboarded = ref.watch(settingsProvider.select((s) => s.onboardingComplete));
  final lastCompletion = ref.watch(phaseCompletionProvider).value;

  return selectMood(
    MoodSignals(
      habits: ref.watch(habitProgressProvider).value ?? const [],
      timer: ref.watch(pomodoroProvider),
      completedFocusToday:
          ref.watch(todaySummaryProvider).value?.focusSessions ?? 0,
      totalCompletedSessions: ref.watch(totalSessionsProvider).value ?? 0,
      justCompletedAt: lastCompletion?.at,
      onboarding: !onboarded,
    ),
  );
});
