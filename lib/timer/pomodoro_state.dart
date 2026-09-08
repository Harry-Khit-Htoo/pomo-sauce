import '../data/models/pomodoro_phase.dart';
import '../data/models/timer_preset.dart';

enum TimerStatus {
  idle,
  running,
  paused,

  /// The interval finished and the alarm is sounding, waiting to be dismissed.
  ringing,
}

/// The timer state is defined by *absolute timestamps*, never by an
/// accumulated tick count. `endsAt` is the single source of truth, so the
/// countdown stays exact across backgrounding, doze, and process death - the
/// UI ticker only decides when to repaint.
class PomodoroState {
  const PomodoroState({
    required this.status,
    required this.phase,
    required this.presetId,
    required this.plannedDuration,
    this.completedFocusInCycle = 0,
    this.endsAt,
    this.phaseStartedAt,
    this.remainingWhenPaused = Duration.zero,
    this.linkedHabitId,
    this.autoStartNext = false,
    this.sessionsBeforeLongBreak = 4,
  });

  final TimerStatus status;
  final PomodoroPhase phase;
  final String presetId;
  final Duration plannedDuration;

  /// Focus intervals finished since the last long break.
  final int completedFocusInCycle;

  /// Wall-clock instant this interval is due to finish. Null unless running.
  final DateTime? endsAt;
  final DateTime? phaseStartedAt;
  final Duration remainingWhenPaused;

  /// Habit credited when a focus interval here completes.
  final String? linkedHabitId;

  final bool autoStartNext;
  final int sessionsBeforeLongBreak;

  static PomodoroState initial(TimerPreset preset) => PomodoroState(
        status: TimerStatus.idle,
        phase: PomodoroPhase.focus,
        presetId: preset.id,
        plannedDuration: preset.durationFor(PomodoroPhase.focus),
        autoStartNext: preset.autoStartNext,
        sessionsBeforeLongBreak: preset.sessionsBeforeLongBreak,
      );

  bool get isActive =>
      status == TimerStatus.running || status == TimerStatus.paused;

  Duration remainingAt(DateTime now) {
    switch (status) {
      case TimerStatus.running:
        final end = endsAt;
        if (end == null) return plannedDuration;
        final left = end.difference(now);
        return left.isNegative ? Duration.zero : left;
      case TimerStatus.paused:
        return remainingWhenPaused;
      case TimerStatus.ringing:
        // The phase has already advanced, so show the interval that is about
        // to start at its full length rather than a spent countdown.
        return plannedDuration;
      case TimerStatus.idle:
        return plannedDuration;
    }
  }

  /// 0.0 at the start of the interval, 1.0 when it is done.
  double progressAt(DateTime now) {
    final total = plannedDuration.inMilliseconds;
    if (total <= 0) return 0;
    final left = remainingAt(now).inMilliseconds;
    return ((total - left) / total).clamp(0.0, 1.0);
  }

  bool isElapsedAt(DateTime now) =>
      status == TimerStatus.running &&
      endsAt != null &&
      !now.isBefore(endsAt!);

  /// Which interval follows this one, and the cycle counter that goes with it.
  ({PomodoroPhase phase, int completedFocusInCycle}) nextAfter() {
    if (phase == PomodoroPhase.focus) {
      final done = completedFocusInCycle + 1;
      final isLong = done >= sessionsBeforeLongBreak;
      return (
        phase: isLong ? PomodoroPhase.longBreak : PomodoroPhase.shortBreak,
        completedFocusInCycle: done,
      );
    }
    return (
      phase: PomodoroPhase.focus,
      completedFocusInCycle:
          phase == PomodoroPhase.longBreak ? 0 : completedFocusInCycle,
    );
  }

  PomodoroState copyWith({
    TimerStatus? status,
    PomodoroPhase? phase,
    String? presetId,
    Duration? plannedDuration,
    int? completedFocusInCycle,
    DateTime? endsAt,
    bool clearEndsAt = false,
    DateTime? phaseStartedAt,
    bool clearPhaseStartedAt = false,
    Duration? remainingWhenPaused,
    String? linkedHabitId,
    bool clearHabit = false,
    bool? autoStartNext,
    int? sessionsBeforeLongBreak,
  }) {
    return PomodoroState(
      status: status ?? this.status,
      phase: phase ?? this.phase,
      presetId: presetId ?? this.presetId,
      plannedDuration: plannedDuration ?? this.plannedDuration,
      completedFocusInCycle:
          completedFocusInCycle ?? this.completedFocusInCycle,
      endsAt: clearEndsAt ? null : (endsAt ?? this.endsAt),
      phaseStartedAt:
          clearPhaseStartedAt ? null : (phaseStartedAt ?? this.phaseStartedAt),
      remainingWhenPaused: remainingWhenPaused ?? this.remainingWhenPaused,
      linkedHabitId: clearHabit ? null : (linkedHabitId ?? this.linkedHabitId),
      autoStartNext: autoStartNext ?? this.autoStartNext,
      sessionsBeforeLongBreak:
          sessionsBeforeLongBreak ?? this.sessionsBeforeLongBreak,
    );
  }
}

extension PomodoroStateJson on PomodoroState {
  Map<String, dynamic> toJson() => {
        'status': status.name,
        'phase': phase.name,
        'presetId': presetId,
        'plannedMs': plannedDuration.inMilliseconds,
        'cycle': completedFocusInCycle,
        'endsAt': endsAt?.millisecondsSinceEpoch,
        'startedAt': phaseStartedAt?.millisecondsSinceEpoch,
        'pausedMs': remainingWhenPaused.inMilliseconds,
        'habitId': linkedHabitId,
        'autoStart': autoStartNext,
        'cycleLength': sessionsBeforeLongBreak,
      };

  static PomodoroState fromJson(Map<String, dynamic> json) {
    DateTime? ms(Object? v) => v == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch((v as num).toInt());
    return PomodoroState(
      status: TimerStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => TimerStatus.idle,
      ),
      phase: PomodoroPhase.fromKey(json['phase'] as String?),
      presetId: (json['presetId'] as String?) ?? 'study',
      plannedDuration:
          Duration(milliseconds: ((json['plannedMs'] as num?) ?? 0).toInt()),
      completedFocusInCycle: ((json['cycle'] as num?) ?? 0).toInt(),
      endsAt: ms(json['endsAt']),
      phaseStartedAt: ms(json['startedAt']),
      remainingWhenPaused:
          Duration(milliseconds: ((json['pausedMs'] as num?) ?? 0).toInt()),
      linkedHabitId: json['habitId'] as String?,
      autoStartNext: (json['autoStart'] as bool?) ?? false,
      sessionsBeforeLongBreak: ((json['cycleLength'] as num?) ?? 4).toInt(),
    );
  }
}
