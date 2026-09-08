import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_theme.dart';
import '../../core/day_key.dart';
import '../../data/models/focus_session.dart';

/// A GitHub-style contribution grid: one column per week, one cell per day,
/// shaded by how much focus and habit work landed that day.
class ProductivityHeatmap extends StatelessWidget {
  const ProductivityHeatmap({
    super.key,
    required this.stats,
    required this.weeks,
    this.onDayTap,
    this.selected,
  });

  final Map<String, DayStats> stats;
  final int weeks;
  final ValueChanged<DateTime>? onDayTap;
  final DateTime? selected;

  static const _cell = 15.0;
  static const _gap = 3.0;

  Color _shade(BuildContext context, int level) {
    if (level == 0) return context.tokens.heatmapEmpty;
    final base = context.colors.primary;
    return Color.lerp(
      base.withValues(alpha: 0.28),
      base,
      (level - 1) / 3,
    )!;
  }

  @override
  Widget build(BuildContext context) {
    final today = DayKey.startOfDay(DateTime.now());
    // Anchor on the Monday of the current week so columns line up.
    final lastMonday = DayKey.startOfWeek(today);
    final firstMonday = lastMonday.subtract(Duration(days: (weeks - 1) * 7));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 18, right: 6),
            child: Column(
              children: [
                for (final label in const ['M', '', 'W', '', 'F', '', 'S'])
                  SizedBox(
                    height: _cell + _gap,
                    width: 14,
                    child: Text(
                      label,
                      style: context.texts.labelSmall
                          ?.copyWith(color: context.tokens.textMuted),
                    ),
                  ),
              ],
            ),
          ),
          for (var w = 0; w < weeks; w++)
            _WeekColumn(
              monday: firstMonday.add(Duration(days: w * 7)),
              showMonthLabel: _startsMonth(firstMonday, w),
              stats: stats,
              today: today,
              selected: selected,
              onDayTap: onDayTap,
              shade: (level) => _shade(context, level),
            ),
        ],
      ),
    );
  }

  bool _startsMonth(DateTime firstMonday, int w) {
    final monday = firstMonday.add(Duration(days: w * 7));
    if (w == 0) return true;
    final previous = firstMonday.add(Duration(days: (w - 1) * 7));
    return monday.month != previous.month;
  }
}

class _WeekColumn extends StatelessWidget {
  const _WeekColumn({
    required this.monday,
    required this.showMonthLabel,
    required this.stats,
    required this.today,
    required this.selected,
    required this.onDayTap,
    required this.shade,
  });

  final DateTime monday;
  final bool showMonthLabel;
  final Map<String, DayStats> stats;
  final DateTime today;
  final DateTime? selected;
  final ValueChanged<DateTime>? onDayTap;
  final Color Function(int level) shade;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 18,
          width: ProductivityHeatmap._cell + ProductivityHeatmap._gap,
          child: showMonthLabel
              ? OverflowBox(
                  alignment: Alignment.centerLeft,
                  maxWidth: 48,
                  child: Text(
                    DateFormat('MMM').format(monday),
                    softWrap: false,
                    style: context.texts.labelSmall
                        ?.copyWith(color: context.tokens.textMuted),
                  ),
                )
              : null,
        ),
        for (var d = 0; d < 7; d++)
          Builder(
            builder: (context) {
              final day = monday.add(Duration(days: d));
              final future = day.isAfter(today);
              final key = DayKey.of(day);
              final level = future ? 0 : (stats[key]?.level ?? 0);
              final isSelected =
                  selected != null && DayKey.isSameDay(day, selected!);
              final isToday = DayKey.isSameDay(day, today);

              return Padding(
                padding: const EdgeInsets.only(
                  right: ProductivityHeatmap._gap,
                  bottom: ProductivityHeatmap._gap,
                ),
                child: GestureDetector(
                  onTap: future ? null : () => onDayTap?.call(day),
                  child: Tooltip(
                    message: _tooltip(key, stats[key], future),
                    child: Container(
                      width: ProductivityHeatmap._cell,
                      height: ProductivityHeatmap._cell,
                      decoration: BoxDecoration(
                        color: future
                            ? Colors.transparent
                            : shade(level),
                        borderRadius: BorderRadius.circular(4),
                        border: isSelected
                            ? Border.all(
                                color: context.colors.onSurface, width: 1.6)
                            : isToday
                                ? Border.all(
                                    color: context.colors.primary, width: 1.4)
                                : null,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  String _tooltip(String key, DayStats? day, bool future) {
    if (future) return '';
    final pretty = DateFormat('EEE d MMM').format(DayKey.parse(key));
    if (day == null) return '$pretty - nothing yet';
    return '$pretty - ${day.focusSessions} sessions, '
        '${day.habitsCompleted} habits';
  }
}

/// The "less ... more" key under the grid.
class HeatmapLegend extends StatelessWidget {
  const HeatmapLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          'Less',
          style: context.texts.labelSmall
              ?.copyWith(color: context.tokens.textMuted),
        ),
        const SizedBox(width: 6),
        for (var level = 0; level < 5; level++)
          Container(
            width: 11,
            height: 11,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: level == 0
                  ? context.tokens.heatmapEmpty
                  : Color.lerp(
                      context.colors.primary.withValues(alpha: 0.28),
                      context.colors.primary,
                      (level - 1) / 3,
                    )!,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        const SizedBox(width: 6),
        Text(
          'More',
          style: context.texts.labelSmall
              ?.copyWith(color: context.tokens.textMuted),
        ),
      ],
    );
  }
}
