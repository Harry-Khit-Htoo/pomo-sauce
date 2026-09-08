import 'package:flutter/material.dart';

enum HabitSchedule {
  daily,
  weekly;

  static HabitSchedule fromName(String? n) => HabitSchedule.values
      .firstWhere((s) => s.name == n, orElse: () => HabitSchedule.daily);
}

class Habit {
  const Habit({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
    required this.schedule,
    required this.weekdays,
    required this.targetPerWeek,
    required this.createdAt,
    this.archived = false,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final String emoji;
  final Color color;
  final HabitSchedule schedule;

  /// Which weekdays a *daily* habit is expected on (DateTime.monday..sunday).
  /// An empty set means every day.
  final Set<int> weekdays;

  /// For *weekly* habits: how many days a week counts as a win.
  final int targetPerWeek;

  final DateTime createdAt;
  final bool archived;
  final int sortOrder;

  bool isDueOn(DateTime day) {
    if (schedule == HabitSchedule.weekly) return true;
    return weekdays.isEmpty || weekdays.contains(day.weekday);
  }

  Habit copyWith({
    String? name,
    String? emoji,
    Color? color,
    HabitSchedule? schedule,
    Set<int>? weekdays,
    int? targetPerWeek,
    bool? archived,
    int? sortOrder,
  }) {
    return Habit(
      id: id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      color: color ?? this.color,
      schedule: schedule ?? this.schedule,
      weekdays: weekdays ?? this.weekdays,
      targetPerWeek: targetPerWeek ?? this.targetPerWeek,
      createdAt: createdAt,
      archived: archived ?? this.archived,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, Object?> toRow() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'color': color.toARGB32(),
        'schedule': schedule.name,
        'weekdays': weekdays.join(','),
        'target_per_week': targetPerWeek,
        'created_at': createdAt.millisecondsSinceEpoch,
        'archived': archived ? 1 : 0,
        'sort_order': sortOrder,
      };

  factory Habit.fromRow(Map<String, Object?> row) {
    final raw = (row['weekdays'] as String?) ?? '';
    return Habit(
      id: row['id'] as String,
      name: row['name'] as String,
      emoji: (row['emoji'] as String?) ?? '🎯',
      color: Color((row['color'] as int?) ?? 0xFFE9503E),
      schedule: HabitSchedule.fromName(row['schedule'] as String?),
      weekdays: raw.isEmpty
          ? const <int>{}
          : raw.split(',').map(int.parse).toSet(),
      targetPerWeek: (row['target_per_week'] as int?) ?? 7,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch((row['created_at'] as int?) ?? 0),
      archived: (row['archived'] as int?) == 1,
      sortOrder: (row['sort_order'] as int?) ?? 0,
    );
  }

  /// Habit colours the user can choose from. Kept inside the app's warm
  /// family so a habit chip never reintroduces the blue the brand dropped.
  static const palette = <Color>[
    Color(0xFFE9503E), // tomato
    Color(0xFF4E9F52), // leaf
    Color(0xFFD4902F), // amber
    Color(0xFFC2603A), // terracotta
    Color(0xFF9C4F72), // plum
    Color(0xFF7A8B3C), // olive
    Color(0xFF8C5A3C), // cocoa
  ];
}
