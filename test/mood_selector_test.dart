import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomo_sauce/data/habit_repository.dart';
import 'package:pomo_sauce/data/models/habit.dart';
import 'package:pomo_sauce/data/models/pomodoro_phase.dart';
import 'package:pomo_sauce/data/models/timer_preset.dart';
import 'package:pomo_sauce/mascot/mascot_mood.dart';
import 'package:pomo_sauce/mascot/mood_selector.dart';
import 'package:pomo_sauce/timer/pomodoro_state.dart';

HabitProgress _habit({
  bool doneToday = false,
  bool dueToday = true,
  bool missedYesterday = false,
  int currentStreak = 0,
  int streakBeforeLapse = 0,
}) {
  return HabitProgress(
    habit: Habit(
      id: 'h',
      name: 'Read',
      emoji: '📚',
      color: const Color(0xFFE9503E),
      schedule: HabitSchedule.daily,
      weekdays: const {},
      targetPerWeek: 7,
      createdAt: DateTime(2026),
    ),
    doneToday: doneToday,
    dueToday: dueToday,
    missedYesterday: missedYesterday,
    currentStreak: currentStreak,
    bestStreak: currentStreak,
    streakBeforeLapse: streakBeforeLapse,
    completionsThisWeek: 0,
    last30: const {},
  );
}

MoodSignals _signals({
  List<HabitProgress> habits = const [],
  PomodoroState? timer,
  int completedFocusToday = 0,
  int totalCompletedSessions = 0,
  DateTime? justCompletedAt,
  bool onboarding = false,
  DateTime? now,
}) {
  return MoodSignals(
    habits: habits,
    timer: timer ?? PomodoroState.initial(TimerPreset.defaults.first),
    completedFocusToday: completedFocusToday,
    totalCompletedSessions: totalCompletedSessions,
    justCompletedAt: justCompletedAt,
    onboarding: onboarding,
    now: now ?? DateTime(2026, 9, 8, 10),
  );
}

void main() {
  group('mascot mood selection', () {
    test('a new user is greeted', () {
      expect(selectMood(_signals(onboarding: true)), MascotMood.welcoming);
    });

    test('nothing due, nothing done is a plain idle', () {
      expect(selectMood(_signals()), MascotMood.idle);
    });

    test('a habit still due today is a nudge, not a scolding', () {
      final mood = selectMood(_signals(habits: [_habit()]));
      expect(mood, MascotMood.alert);
      expect(mood, isNot(MascotMood.angry));
    });

    test('a habit missed outright earns the cross face', () {
      expect(
        selectMood(_signals(habits: [_habit(missedYesterday: true)])),
        MascotMood.angry,
      );
    });

    test('still-due late in the day also earns it', () {
      expect(
        selectMood(_signals(
          habits: [_habit()],
          now: DateTime(2026, 9, 8, 21),
        )),
        MascotMood.angry,
      );
    });

    test('a broken streak is sad, never angry', () {
      final mood = selectMood(_signals(
        habits: [_habit(doneToday: true, streakBeforeLapse: 6)],
      ));
      expect(mood, MascotMood.sad);
    });

    test('a completion beats everything else on screen', () {
      final now = DateTime(2026, 9, 8, 21);
      expect(
        selectMood(_signals(
          habits: [_habit(missedYesterday: true)],
          justCompletedAt: now,
          now: now,
        )),
        MascotMood.happy,
      );
    });

    test('a milestone completion celebrates instead', () {
      final now = DateTime(2026, 9, 8, 12);
      expect(
        selectMood(_signals(
          justCompletedAt: now,
          totalCompletedSessions: 25,
          now: now,
        )),
        MascotMood.celebrating,
      );
    });

    test('a stale completion no longer counts as just-completed', () {
      final now = DateTime(2026, 9, 8, 12);
      expect(
        selectMood(_signals(
          justCompletedAt: now.subtract(const Duration(minutes: 5)),
          now: now,
        )),
        isNot(MascotMood.happy),
      );
    });

    test('a running focus interval owns the face', () {
      final state = PomodoroState.initial(TimerPreset.defaults.first).copyWith(
        status: TimerStatus.running,
        endsAt: DateTime(2026, 9, 8, 11),
      );
      expect(
        selectMood(_signals(habits: [_habit()], timer: state)),
        MascotMood.neutral,
      );
    });

    test('a running break puts the mascot to sleep', () {
      final state = PomodoroState.initial(TimerPreset.defaults.first).copyWith(
        status: TimerStatus.running,
        phase: PomodoroPhase.shortBreak,
        endsAt: DateTime(2026, 9, 8, 11),
      );
      expect(selectMood(_signals(timer: state)), MascotMood.sleepy);
    });

    test('every mood carries a supportive line, including the angry one', () {
      for (final mood in MascotMood.values) {
        expect(mood.supportLine, isNotEmpty);
      }
      expect(MascotMood.angry.supportLine, contains('back on track'));
    });
  });
}
