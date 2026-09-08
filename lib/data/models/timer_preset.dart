import 'pomodoro_phase.dart';

/// A named set of timer durations. The four built-ins ship with the app; the
/// user can edit any of them or add their own, and every preset stays fully
/// tweakable after it has been picked.
class TimerPreset {
  const TimerPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.focusMinutes,
    required this.shortBreakMinutes,
    required this.longBreakMinutes,
    required this.sessionsBeforeLongBreak,
    this.autoStartNext = false,
    this.builtIn = false,
  });

  final String id;
  final String name;
  final String description;
  final String emoji;
  final int focusMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;
  final int sessionsBeforeLongBreak;
  final bool autoStartNext;
  final bool builtIn;

  Duration durationFor(PomodoroPhase phase) => Duration(
        minutes: switch (phase) {
          PomodoroPhase.focus => focusMinutes,
          PomodoroPhase.shortBreak => shortBreakMinutes,
          PomodoroPhase.longBreak => longBreakMinutes,
        },
      );

  String get summary =>
      '$focusMinutes / $shortBreakMinutes min  ·  long break '
      '$longBreakMinutes min after $sessionsBeforeLongBreak';

  TimerPreset copyWith({
    String? name,
    String? description,
    String? emoji,
    int? focusMinutes,
    int? shortBreakMinutes,
    int? longBreakMinutes,
    int? sessionsBeforeLongBreak,
    bool? autoStartNext,
  }) {
    return TimerPreset(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      emoji: emoji ?? this.emoji,
      focusMinutes: focusMinutes ?? this.focusMinutes,
      shortBreakMinutes: shortBreakMinutes ?? this.shortBreakMinutes,
      longBreakMinutes: longBreakMinutes ?? this.longBreakMinutes,
      sessionsBeforeLongBreak:
          sessionsBeforeLongBreak ?? this.sessionsBeforeLongBreak,
      autoStartNext: autoStartNext ?? this.autoStartNext,
      builtIn: builtIn,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'emoji': emoji,
        'focus': focusMinutes,
        'short': shortBreakMinutes,
        'long': longBreakMinutes,
        'cycles': sessionsBeforeLongBreak,
        'autoStart': autoStartNext,
        'builtIn': builtIn,
      };

  factory TimerPreset.fromJson(Map<String, dynamic> json) => TimerPreset(
        id: json['id'] as String,
        name: json['name'] as String,
        description: (json['description'] as String?) ?? '',
        emoji: (json['emoji'] as String?) ?? '🍅',
        focusMinutes: (json['focus'] as num).toInt(),
        shortBreakMinutes: (json['short'] as num).toInt(),
        longBreakMinutes: (json['long'] as num).toInt(),
        sessionsBeforeLongBreak: (json['cycles'] as num).toInt(),
        autoStartNext: (json['autoStart'] as bool?) ?? false,
        builtIn: (json['builtIn'] as bool?) ?? false,
      );

  static const defaults = <TimerPreset>[
    TimerPreset(
      id: 'study',
      name: 'Study Focus',
      description: 'The classic. Short bursts that are easy to start.',
      emoji: '📚',
      focusMinutes: 25,
      shortBreakMinutes: 5,
      longBreakMinutes: 15,
      sessionsBeforeLongBreak: 4,
      builtIn: true,
    ),
    TimerPreset(
      id: 'coding',
      name: 'Coding Focus',
      description: 'Longer deep-work blocks for getting into flow.',
      emoji: '💻',
      focusMinutes: 50,
      shortBreakMinutes: 10,
      longBreakMinutes: 20,
      sessionsBeforeLongBreak: 3,
      builtIn: true,
    ),
    TimerPreset(
      id: 'productivity',
      name: 'Quick Tasks',
      description: 'Standard Pomodoro for chores and admin.',
      emoji: '⚡',
      focusMinutes: 25,
      shortBreakMinutes: 5,
      longBreakMinutes: 15,
      sessionsBeforeLongBreak: 4,
      builtIn: true,
    ),
    TimerPreset(
      id: 'reading',
      name: 'Reading / Creative',
      description: 'Gentle blocks with room to wander.',
      emoji: '🎨',
      focusMinutes: 40,
      shortBreakMinutes: 8,
      longBreakMinutes: 25,
      sessionsBeforeLongBreak: 3,
      builtIn: true,
    ),
  ];
}
