import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/app_theme.dart';
import '../../core/day_key.dart';
import '../../core/formatting.dart';
import '../../core/widgets.dart';
import '../../data/models/focus_session.dart';
import '../../data/models/habit.dart';
import '../../data/models/pomodoro_phase.dart';
import '../../mascot/mascot_mood.dart';
import '../../mascot/mascot_speech.dart';
import '../../providers.dart';
import 'heatmap.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heatmap = ref.watch(heatmapProvider);
    final total = ref.watch(totalSessionsProvider).value ?? 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('History')),
      body: heatmap.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load history.\n$e')),
        data: (stats) {
          if (stats.isEmpty && total == 0) return const _EmptyHistory();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              const _WeeklyChart(),
              const SizedBox(height: 20),
              const SectionHeader('Last 26 weeks'),
              SectionCard(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 148,
                      child: ProductivityHeatmap(
                        stats: stats,
                        weeks: 26,
                        selected: ref.watch(selectedHistoryDayProvider),
                        onDayTap: (day) => ref
                            .read(selectedHistoryDayProvider.notifier)
                            .select(day),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const HeatmapLegend(),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const SectionHeader('Calendar'),
              const _HistoryCalendar(),
              const SizedBox(height: 20),
              const _SelectedDayDetail(),
            ],
          );
        },
      ),
    );
  }
}

class _WeeklyChart extends ConsumerWidget {
  const _WeeklyChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(weeklyChartProvider);
    final totalSeconds =
        data.value?.fold<int>(0, (a, b) => a + b.seconds) ?? 0;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This week',
            style: context.texts.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Focused for ${formatDurationShort(Duration(seconds: totalSeconds))} '
            'over the last 7 days',
            style: context.texts.bodySmall
                ?.copyWith(color: context.tokens.textMuted),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: data.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const SizedBox.shrink(),
              data: (days) => _buildChart(context, days),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(
    BuildContext context,
    List<({String day, int seconds, int count})> days,
  ) {
    final peak = days
        .map((d) => d.seconds / 60)
        .fold<double>(0, (a, b) => b > a ? b : a);
    // Round the axis up to a clean multiple of 15 so the gridline labels are
    // whole numbers and never collide with an auto-generated max label.
    final maxY = ((peak * 1.25 / 15).ceil() * 15).toDouble().clamp(30.0, 600.0);

    return BarChart(
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, _, rod, _) => BarTooltipItem(
              formatDurationShort(Duration(minutes: rod.toY.round())),
              TextStyle(
                color: context.colors.onInverseSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: context.colors.outlineVariant,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: maxY / 3,
              maxIncluded: false,
              getTitlesWidget: (value, meta) => Text(
                '${value.round()}m',
                style: context.texts.labelSmall
                    ?.copyWith(color: context.tokens.textMuted),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= days.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    DateFormat('E').format(DayKey.parse(days[i].day))[0],
                    style: context.texts.labelSmall
                        ?.copyWith(color: context.tokens.textMuted),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < days.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: days[i].seconds / 60,
                  width: 18,
                  color: i == days.length - 1
                      ? context.colors.primary
                      : context.colors.primary.withValues(alpha: 0.45),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _HistoryCalendar extends ConsumerWidget {
  const _HistoryCalendar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedHistoryDayProvider);
    final stats = ref.watch(heatmapProvider).value ?? const {};

    return SectionCard(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 12),
      child: TableCalendar<void>(
        firstDay: DateTime.now().subtract(const Duration(days: 365 * 3)),
        lastDay: DateTime.now(),
        focusedDay: selected,
        currentDay: DateTime.now(),
        selectedDayPredicate: (day) => DayKey.isSameDay(day, selected),
        onDaySelected: (day, _) =>
            ref.read(selectedHistoryDayProvider.notifier).select(day),
        startingDayOfWeek: StartingDayOfWeek.monday,
        availableGestures: AvailableGestures.horizontalSwipe,
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: context.texts.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700) ??
              const TextStyle(),
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          todayDecoration: BoxDecoration(
            color: context.colors.primary.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          todayTextStyle: TextStyle(color: context.colors.onSurface),
          selectedDecoration: BoxDecoration(
            color: context.colors.primary,
            shape: BoxShape.circle,
          ),
          defaultTextStyle: TextStyle(color: context.colors.onSurface),
          weekendTextStyle: TextStyle(color: context.tokens.textMuted),
        ),
        calendarBuilders: CalendarBuilders(
          // A dot under each day that had activity, sized by intensity.
          markerBuilder: (context, day, _) {
            final level = stats[DayKey.of(day)]?.level ?? 0;
            if (level == 0) return null;
            return Padding(
              padding: const EdgeInsets.only(top: 30),
              child: Container(
                width: 5.0 + level,
                height: 5.0 + level,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SelectedDayDetail extends ConsumerWidget {
  const _SelectedDayDetail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(selectedHistoryDayProvider);
    final sessions = ref.watch(sessionsOnDayProvider);
    final habitsDone = ref.watch(habitsDoneOnDayProvider).value ?? const {};
    final habits = ref.watch(habitsProvider).value ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(DateFormat('EEEE d MMMM').format(day)),
        SectionCard(
          child: sessions.when(
            loading: () => const AsyncSlot(
                loading: true, error: null, height: 80, child: SizedBox()),
            error: (e, _) => AsyncSlot(
                loading: false, error: e, height: 80, child: SizedBox()),
            data: (list) => _dayBody(context, list, habits, habitsDone),
          ),
        ),
      ],
    );
  }

  Widget _dayBody(
    BuildContext context,
    List<FocusSession> list,
    List<Habit> habits,
    Set<String> habitsDone,
  ) {
    final focus = list
        .where((s) => s.phase == PomodoroPhase.focus && s.completed)
        .toList();
    final doneHabits = habits.where((h) => habitsDone.contains(h.id)).toList();

    if (list.isEmpty && doneHabits.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Nothing recorded on this day.',
          textAlign: TextAlign.center,
          style: context.texts.bodyMedium
              ?.copyWith(color: context.tokens.textMuted),
        ),
      );
    }

    final totalFocus =
        Duration(seconds: focus.fold<int>(0, (a, s) => a + s.actualSeconds));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: StatTile(
                value: '${focus.length}',
                label: focus.length == 1 ? 'focus session' : 'focus sessions',
                icon: Icons.local_fire_department_outlined,
              ),
            ),
            Expanded(
              child: StatTile(
                value: formatDurationShort(totalFocus),
                label: 'total focus',
                icon: Icons.schedule_outlined,
                color: context.tokens.shortBreak,
              ),
            ),
            Expanded(
              child: StatTile(
                value: '${doneHabits.length}',
                label: 'habits ticked',
                icon: Icons.check_circle_outline,
                color: context.tokens.longBreak,
              ),
            ),
          ],
        ),
        if (doneHabits.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final h in doneHabits)
                TagChip(
                  label: '${h.emoji} ${h.name}',
                  color: h.color,
                  dense: true,
                ),
            ],
          ),
        ],
        if (list.isNotEmpty) ...[
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 10),
          for (final s in list) _SessionRow(session: s),
        ],
      ],
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});

  final FocusSession session;

  @override
  Widget build(BuildContext context) {
    final colour = switch (session.phase) {
      PomodoroPhase.focus => context.tokens.focus,
      PomodoroPhase.shortBreak => context.tokens.shortBreak,
      PomodoroPhase.longBreak => context.tokens.longBreak,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: session.completed ? colour : context.colors.outline,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              session.completed
                  ? session.phase.label
                  : '${session.phase.label} (stopped early)',
              style: context.texts.bodyMedium,
            ),
          ),
          Text(
            DateFormat('HH:mm').format(session.startedAt),
            style: context.texts.bodySmall
                ?.copyWith(color: context.tokens.textMuted),
          ),
          const SizedBox(width: 10),
          Text(
            formatDurationShort(session.actual),
            style: context.texts.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: MascotCoach(
          mood: MascotMood.welcoming,
          message: MascotLines.noHistory,
          size: 150,
        ),
      ),
    );
  }
}
