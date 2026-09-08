/// The three kinds of interval the Pomodoro engine cycles through.
enum PomodoroPhase {
  focus,
  shortBreak,
  longBreak;

  bool get isBreak => this != PomodoroPhase.focus;

  String get label => switch (this) {
        PomodoroPhase.focus => 'Focus',
        PomodoroPhase.shortBreak => 'Short break',
        PomodoroPhase.longBreak => 'Long break',
      };

  String get storageKey => name;

  static PomodoroPhase fromKey(String? key) => PomodoroPhase.values.firstWhere(
        (p) => p.name == key,
        orElse: () => PomodoroPhase.focus,
      );
}
