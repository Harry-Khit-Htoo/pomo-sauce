import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../data/models/habit.dart';
import '../../providers.dart';

Future<void> showHabitEditor(
  BuildContext context,
  WidgetRef ref, {
  Habit? habit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _HabitEditor(habit: habit),
  );
}

const _emojiChoices = [
  '🎯', '📚', '💻', '🏃', '🧘', '💧', '🎨', '🎸', '🌱', '✍️', '🛏️', '🥗',
];

class _HabitEditor extends ConsumerStatefulWidget {
  const _HabitEditor({this.habit});

  final Habit? habit;

  @override
  ConsumerState<_HabitEditor> createState() => _HabitEditorState();
}

class _HabitEditorState extends ConsumerState<_HabitEditor> {
  late final TextEditingController _name =
      TextEditingController(text: widget.habit?.name ?? '');
  late String _emoji = widget.habit?.emoji ?? '🎯';
  late Color _color = widget.habit?.color ?? Habit.palette.first;
  late HabitSchedule _schedule = widget.habit?.schedule ?? HabitSchedule.daily;
  late final Set<int> _weekdays = {...?widget.habit?.weekdays};
  late int _target = widget.habit?.targetPerWeek ?? 3;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);

    final existing = widget.habit;
    final habit = existing == null
        ? Habit(
            id: 'habit_${DateTime.now().microsecondsSinceEpoch}',
            name: name,
            emoji: _emoji,
            color: _color,
            schedule: _schedule,
            weekdays: _weekdays,
            targetPerWeek: _target,
            createdAt: DateTime.now(),
          )
        : existing.copyWith(
            name: name,
            emoji: _emoji,
            color: _color,
            schedule: _schedule,
            weekdays: _weekdays,
            targetPerWeek: _target,
          );

    await ref.read(habitRepositoryProvider).upsert(habit);
    ref.invalidate(habitProgressProvider);
    ref.invalidate(habitsProvider);
    ref.invalidate(todaySummaryProvider);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final habit = widget.habit;
    if (habit == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${habit.name}"?'),
        content: const Text(
          'Its history and streak will be removed. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(habitRepositoryProvider).delete(habit.id);
    ref.invalidate(habitProgressProvider);
    ref.invalidate(habitsProvider);
    ref.invalidate(todaySummaryProvider);
    ref.invalidate(heatmapProvider);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    const weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.outline,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.habit == null ? 'New habit' : 'Edit habit',
              style: context.texts.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _name,
              autofocus: widget.habit == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'What do you want to do?',
                hintText: 'Read 10 pages',
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 20),
            Text('Icon', style: context.texts.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in _emojiChoices)
                  GestureDetector(
                    onTap: () => setState(() => _emoji = e),
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _emoji == e
                            ? _color.withValues(alpha: 0.18)
                            : context.tokens.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _emoji == e ? _color : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Colour', style: context.texts.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final c in Habit.palette)
                  GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: Container(
                      width: 36,
                      height: 36,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: c.toARGB32() == _color.toARGB32()
                              ? context.colors.onSurface
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            SegmentedButton<HabitSchedule>(
              segments: const [
                ButtonSegment(
                  value: HabitSchedule.daily,
                  label: Text('Daily'),
                  icon: Icon(Icons.today_outlined),
                ),
                ButtonSegment(
                  value: HabitSchedule.weekly,
                  label: Text('Weekly'),
                  icon: Icon(Icons.date_range_outlined),
                ),
              ],
              selected: {_schedule},
              onSelectionChanged: (s) => setState(() => _schedule = s.first),
            ),
            const SizedBox(height: 16),
            if (_schedule == HabitSchedule.daily) ...[
              Text(
                'On which days? Leave all off for every day.',
                style: context.texts.bodySmall
                    ?.copyWith(color: context.tokens.textMuted),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 1; i <= 7; i++)
                    GestureDetector(
                      onTap: () => setState(() {
                        _weekdays.contains(i)
                            ? _weekdays.remove(i)
                            : _weekdays.add(i);
                      }),
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _weekdays.contains(i)
                              ? _color
                              : context.tokens.surfaceAlt,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          weekdayLabels[i - 1],
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _weekdays.contains(i)
                                ? Colors.white
                                : context.tokens.textMuted,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ] else ...[
              Text(
                'Target: ${_target}x per week',
                style: context.texts.bodyMedium,
              ),
              Slider(
                value: _target.toDouble(),
                min: 1,
                max: 7,
                divisions: 6,
                label: '$_target',
                onChanged: (v) => setState(() => _target = v.round()),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                if (widget.habit != null) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _delete,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.colors.error,
                      ),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Delete'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(widget.habit == null ? 'Add habit' : 'Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
