import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/day_key.dart';
import '../../core/formatting.dart';
import '../../core/widgets.dart';
import '../../data/habit_repository.dart';
import '../../data/models/habit.dart';
import '../../mascot/mascot_mood.dart';
import '../../mascot/mascot_speech.dart';
import '../../mascot/tomato_mascot.dart';
import '../../providers.dart';
import 'habit_editor.dart';

class HabitsScreen extends ConsumerWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(habitProgressProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Habits'),
        actions: [
          IconButton(
            tooltip: 'New habit',
            icon: const Icon(Icons.add_rounded),
            onPressed: () => showHabitEditor(context, ref),
          ),
        ],
      ),
      body: progress.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load habits.\n$e')),
        data: (items) {
          if (items.isEmpty) return const _EmptyHabits();
          final today = DateTime.now();
          final due = items.where((p) => p.habit.isDueOn(today)).toList();
          final rest = items.where((p) => !p.habit.isDueOn(today)).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              _TodayProgress(items: due),
              const SizedBox(height: 20),
              if (due.isNotEmpty) ...[
                const SectionHeader('Due today'),
                for (final p in due) ...[
                  _HabitTile(progress: p),
                  const SizedBox(height: 10),
                ],
              ],
              if (rest.isNotEmpty) ...[
                const SizedBox(height: 14),
                const SectionHeader('Not scheduled today'),
                for (final p in rest) ...[
                  _HabitTile(progress: p),
                  const SizedBox(height: 10),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _TodayProgress extends StatelessWidget {
  const _TodayProgress({required this.items});

  final List<HabitProgress> items;

  @override
  Widget build(BuildContext context) {
    final done = items.where((p) => p.doneToday).length;
    final total = items.length;
    final ratio = total == 0 ? 0.0 : done / total;
    final allDone = total > 0 && done == total;

    return SectionCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  allDone ? 'All done for today' : '$done of $total done today',
                  style: context.texts.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 10,
                    backgroundColor: context.colors.outlineVariant,
                    valueColor: AlwaysStoppedAnimation(
                      allDone ? context.tokens.shortBreak : context.colors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 74,
            child: Center(
              child: _MiniMascot(allDone: allDone, any: total > 0),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMascot extends StatelessWidget {
  const _MiniMascot({required this.allDone, required this.any});

  final bool allDone;
  final bool any;

  @override
  Widget build(BuildContext context) {
    return TomatoMascot(
      size: 74,
      mood: allDone
          ? MascotMood.celebrating
          : (any ? MascotMood.alert : MascotMood.idle),
    );
  }
}

class _HabitTile extends ConsumerWidget {
  const _HabitTile({required this.progress});

  final HabitProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habit = progress.habit;
    final done = progress.doneToday;

    return SectionCard(
      padding: const EdgeInsets.all(14),
      onTap: () => showHabitEditor(context, ref, habit: habit),
      child: Row(
        children: [
          _CheckButton(
            done: done,
            color: habit.color,
            onTap: () async {
              await ref
                  .read(habitRepositoryProvider)
                  .toggle(habit.id, DayKey.today());
              ref.invalidate(habitProgressProvider);
              ref.invalidate(todaySummaryProvider);
              ref.invalidate(heatmapProvider);
            },
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(habit.emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        habit.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          decoration: done ? TextDecoration.lineThrough : null,
                          color: done
                              ? context.tokens.textMuted
                              : context.colors.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (progress.currentStreak > 0)
                      TagChip(
                        label: '${progress.currentStreak} day streak',
                        icon: Icons.local_fire_department_rounded,
                        color: progress.streakAtRisk
                            ? const Color(0xFFE8A33D)
                            : habit.color,
                        dense: true,
                      )
                    else
                      TagChip(
                        label: habit.schedule == HabitSchedule.weekly
                            ? '${progress.completionsThisWeek}/${habit.targetPerWeek} this week'
                            : 'Not started',
                        color: context.tokens.textMuted,
                        dense: true,
                      ),
                    const SizedBox(width: 8),
                    if (progress.bestStreak > progress.currentStreak)
                      Text(
                        'best ${plural(progress.bestStreak, 'day')}',
                        style: context.texts.bodySmall
                            ?.copyWith(color: context.tokens.textMuted),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _MiniStrip(progress: progress),
        ],
      ),
    );
  }
}

class _CheckButton extends StatelessWidget {
  const _CheckButton({
    required this.done,
    required this.color,
    required this.onTap,
  });

  final bool done;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: done,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: done ? color : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: done ? color : context.colors.outline,
              width: 2,
            ),
          ),
          child: Icon(
            Icons.check_rounded,
            size: 22,
            color: done ? Colors.white : context.colors.outline,
          ),
        ),
      ),
    );
  }
}

/// Fourteen little bars: the habit's last two weeks at a glance.
class _MiniStrip extends StatelessWidget {
  const _MiniStrip({required this.progress});

  final HabitProgress progress;

  @override
  Widget build(BuildContext context) {
    final days = progress.last30.entries.toList();
    final recent = days.length <= 14 ? days : days.sublist(days.length - 14);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final day in recent)
          Container(
            width: 4,
            height: day.value ? 20 : 10,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: day.value
                  ? progress.habit.color
                  : context.tokens.heatmapEmpty,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    );
  }
}

class _EmptyHabits extends ConsumerWidget {
  const _EmptyHabits();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MascotCoach(
              mood: MascotMood.welcoming,
              message: MascotLines.noHabits,
              size: 150,
              bubbleAbove: true,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () => showHabitEditor(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add your first habit'),
            ),
          ],
        ),
      ),
    );
  }
}
