import 'package:flutter_test/flutter_test.dart';
import 'package:tomato_focus/core/formatting.dart';
import 'package:tomato_focus/data/models/pomodoro_phase.dart';
import 'package:tomato_focus/data/models/timer_preset.dart';
import 'package:tomato_focus/timer/pomodoro_state.dart';

void main() {
  group('countdown formatting', () {
    test('pads minutes and seconds', () {
      expect(formatCountdown(const Duration(minutes: 25)), '25:00');
      expect(formatCountdown(const Duration(seconds: 5)), '00:05');
    });

    test('grows an hours field only when needed', () {
      expect(formatCountdown(const Duration(hours: 1, minutes: 2)), '1:02:00');
    });

    test('never renders a negative countdown', () {
      expect(formatCountdown(const Duration(seconds: -30)), '00:00');
    });
  });

  group('pomodoro cycle', () {
    final preset = TimerPreset.defaults.first; // 25/5, long break after 4

    test('focus is followed by a short break until the cycle completes', () {
      var state = PomodoroState.initial(preset)
          .copyWith(sessionsBeforeLongBreak: 4);
      final next = state.nextAfter();
      expect(next.phase, PomodoroPhase.shortBreak);
      expect(next.completedFocusInCycle, 1);
    });

    test('the fourth focus session earns the long break', () {
      final state = PomodoroState.initial(preset).copyWith(
        completedFocusInCycle: 3,
        sessionsBeforeLongBreak: 4,
      );
      expect(state.nextAfter().phase, PomodoroPhase.longBreak);
    });

    test('a long break resets the cycle counter', () {
      final state = PomodoroState.initial(preset).copyWith(
        phase: PomodoroPhase.longBreak,
        completedFocusInCycle: 4,
      );
      final next = state.nextAfter();
      expect(next.phase, PomodoroPhase.focus);
      expect(next.completedFocusInCycle, 0);
    });
  });

  group('wall-clock timing', () {
    test('remaining time is derived from endsAt, not from ticks', () {
      final now = DateTime(2026, 1, 1, 9);
      final state = PomodoroState.initial(TimerPreset.defaults.first).copyWith(
        status: TimerStatus.running,
        plannedDuration: const Duration(minutes: 25),
        phaseStartedAt: now,
        endsAt: now.add(const Duration(minutes: 25)),
      );

      expect(state.remainingAt(now), const Duration(minutes: 25));
      expect(
        state.remainingAt(now.add(const Duration(minutes: 10))),
        const Duration(minutes: 15),
      );
      // Long after the end - the case where the app was backgrounded.
      expect(
        state.remainingAt(now.add(const Duration(hours: 3))),
        Duration.zero,
      );
      expect(state.isElapsedAt(now.add(const Duration(hours: 3))), isTrue);
      expect(state.progressAt(now.add(const Duration(minutes: 25))), 1.0);
    });

    test('a ringing timer previews the next interval, not a spent one', () {
      // After an interval ends the phase has already advanced, so the display
      // should show the upcoming break at full length rather than 00:00.
      final state = PomodoroState.initial(TimerPreset.defaults.first).copyWith(
        status: TimerStatus.ringing,
        phase: PomodoroPhase.shortBreak,
        plannedDuration: const Duration(minutes: 5),
        completedFocusInCycle: 1,
      );

      expect(state.remainingAt(DateTime.now()), const Duration(minutes: 5));
      expect(state.progressAt(DateTime.now()), 0.0);
      expect(state.isElapsedAt(DateTime.now()), isFalse);
    });

    test('state survives a round trip through storage', () {
      final now = DateTime(2026, 3, 4, 14, 30);
      final original = PomodoroState.initial(TimerPreset.defaults[1]).copyWith(
        status: TimerStatus.running,
        phase: PomodoroPhase.focus,
        completedFocusInCycle: 2,
        endsAt: now,
        phaseStartedAt: now.subtract(const Duration(minutes: 50)),
        linkedHabitId: 'habit_1',
        autoStartNext: true,
      );

      final restored = PomodoroStateJson.fromJson(original.toJson());

      expect(restored.status, original.status);
      expect(restored.endsAt, original.endsAt);
      expect(restored.completedFocusInCycle, 2);
      expect(restored.linkedHabitId, 'habit_1');
      expect(restored.autoStartNext, isTrue);
    });
  });
}
