import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/constants.dart';
import '../../core/formatting.dart';
import '../../core/widgets.dart';
import '../../data/models/pomodoro_phase.dart';
import '../../mascot/mascot_mood.dart';
import '../../mascot/mascot_speech.dart';
import '../../mascot/tomato_mascot.dart';
import '../../providers.dart';
import '../../timer/pomodoro_state.dart';
import '../focus/focus_screen.dart';
import 'preset_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pomodoroProvider);
    final presets = ref.watch(presetsProvider);
    final summary = ref.watch(todaySummaryProvider);
    final atRisk = ref.watch(streakAtRiskProvider);

    // One source of truth for the face; the line follows the mood, with a
    // habit-specific nudge when we have one worth naming.
    final mood = ref.watch(mascotMoodProvider);
    final line = (!state.isActive && atRisk != null && mood == MascotMood.alert)
        ? MascotLines.streakAtRisk(
            atRisk.habit.name.toLowerCase(), atRisk.currentStreak)
        : mood.supportLine;

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          MascotLines.greeting(DateTime.now().hour),
                          style: context.texts.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppConstants.appTagline,
                          style: context.texts.bodyMedium
                              ?.copyWith(color: context.tokens.textMuted),
                        ),
                      ],
                    ),
                  ),
                  TomatoMascot(mood: mood, size: 66),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: SpeechBubble(
                text: line,
                tailAlignment: Alignment.topCenter,
                compact: true,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: state.isActive || state.status == TimerStatus.ringing
                  ? const _ActiveSessionCard()
                  : const _StartCard(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: SectionCard(
                child: summary.when(
                  loading: () => const AsyncSlot(
                      loading: true, error: null, height: 76, child: SizedBox()),
                  error: (e, _) => AsyncSlot(
                      loading: false, error: e, height: 76, child: const SizedBox()),
                  data: (s) => Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          value: '${s.focusSessions}',
                          label: s.focusSessions == 1
                              ? 'session today'
                              : 'sessions today',
                          icon: Icons.local_fire_department_outlined,
                        ),
                      ),
                      Expanded(
                        child: StatTile(
                          value: formatDurationShort(s.focusTime),
                          label: 'focused',
                          icon: Icons.schedule_outlined,
                          color: context.tokens.shortBreak,
                        ),
                      ),
                      Expanded(
                        child: StatTile(
                          value: '${s.habitsDone}/${s.habitsTotal}',
                          label: 'habits done',
                          icon: Icons.check_circle_outline,
                          color: context.tokens.longBreak,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: SectionHeader(
                'Pick a rhythm',
                action: Text(
                  'Tap to select',
                  style: context.texts.bodySmall
                      ?.copyWith(color: context.tokens.textMuted),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 168,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: presets.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final preset = presets[i];
                  return PresetCard(
                    preset: preset,
                    selected: preset.id == state.presetId,
                    enabled: !state.isActive,
                    onTap: () {
                      ref.read(pomodoroProvider.notifier).selectPreset(preset.id);
                      ref
                          .read(settingsProvider.notifier)
                          .setActivePreset(preset.id);
                    },
                  );
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 22, 20, 0),
              child: _HabitLinkCard(),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
        ],
      ),
    );
  }
}

/// Quick start: the current preset's focus length and one big button.
class _StartCard extends ConsumerWidget {
  const _StartCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preset = ref.watch(activePresetProvider);
    final state = ref.watch(pomodoroProvider);

    return SectionCard(
      child: Column(
        children: [
          Row(
            children: [
              Text(preset.emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preset.name,
                      style: context.texts.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      preset.summary,
                      style: context.texts.bodySmall
                          ?.copyWith(color: context.tokens.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            formatCountdown(state.plannedDuration),
            style: TextStyle(
              fontSize: 58,
              fontWeight: FontWeight.w200,
              letterSpacing: -2,
              height: 1,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            state.phase.label.toUpperCase(),
            style: context.texts.labelMedium?.copyWith(
              color: context.tokens.focus,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _start(context, ref),
              icon: const Icon(Icons.play_arrow_rounded, size: 26),
              label: const Text('Start focus session'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    // Captured before the await: this widget is swapped out for the
    // active-session card as soon as the timer starts, so its own context is
    // gone by the time start() returns. Opening the Focus Display is RootShell's
    // job - it watches for the timer leaving idle, so every start route (here,
    // the focus screen itself, a chained break) behaves the same.
    final messenger = ScaffoldMessenger.of(context);
    final granted = await ref.read(pomodoroProvider.notifier).start();
    if (!granted) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text(
            'Notifications are off, so we cannot alert you when the session '
            'ends. The timer still runs.',
          ),
          action: SnackBarAction(
            label: 'Fix',
            onPressed: () =>
                ref.read(notificationServiceProvider).requestNotificationPermission(),
          ),
        ),
      );
    }
  }
}

/// Shown in place of the start card while a session is live.
class _ActiveSessionCard extends ConsumerWidget {
  const _ActiveSessionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pomodoroProvider);
    final controller = ref.watch(pomodoroProvider.notifier);
    final colour = switch (state.phase) {
      PomodoroPhase.focus => context.tokens.focus,
      PomodoroPhase.shortBreak => context.tokens.shortBreak,
      PomodoroPhase.longBreak => context.tokens.longBreak,
    };

    return SectionCard(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const FocusScreen())),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TagChip(
                  label: state.status == TimerStatus.paused
                      ? 'Paused'
                      : state.phase.label,
                  color: colour,
                  icon: state.status == TimerStatus.paused
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  dense: true,
                ),
                const SizedBox(height: 10),
                ValueListenableBuilder<DateTime>(
                  valueListenable: controller.clock,
                  builder: (context, now, _) => Text(
                    formatCountdown(state.remainingAt(now)),
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w200,
                      letterSpacing: -1.5,
                      height: 1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: context.colors.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tap to open the focus display',
                  style: context.texts.bodySmall
                      ?.copyWith(color: context.tokens.textMuted),
                ),
              ],
            ),
          ),
          IconButton.filled(
            onPressed: () => controller.toggle(),
            iconSize: 30,
            style: IconButton.styleFrom(
              minimumSize: const Size(60, 60),
              backgroundColor: colour,
            ),
            icon: Icon(
              state.status == TimerStatus.running
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

/// Optional linkage: a completed focus session ticks this habit off.
class _HabitLinkCard extends ConsumerWidget {
  const _HabitLinkCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider);
    final linkedId =
        ref.watch(pomodoroProvider.select((s) => s.linkedHabitId));

    return habits.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        final linked = list.where((h) => h.id == linkedId).firstOrNull;
        return SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.link_rounded,
                      size: 18, color: context.tokens.textMuted),
                  const SizedBox(width: 8),
                  Text(
                    'Credit a habit',
                    style: context.texts.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                linked == null
                    ? 'Finished sessions can tick a habit off for you.'
                    : 'Finishing a focus session marks '
                        '"${linked.name}" done for today.',
                style: context.texts.bodySmall
                    ?.copyWith(color: context.tokens.textMuted, height: 1.4),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _LinkChip(
                    label: 'None',
                    selected: linkedId == null,
                    onTap: () =>
                        ref.read(pomodoroProvider.notifier).linkHabit(null),
                  ),
                  for (final habit in list)
                    _LinkChip(
                      label: '${habit.emoji} ${habit.name}',
                      selected: habit.id == linkedId,
                      color: habit.color,
                      onTap: () => ref
                          .read(pomodoroProvider.notifier)
                          .linkHabit(habit.id),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LinkChip extends StatelessWidget {
  const _LinkChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.colors.primary;
    return Material(
      color: selected ? tint.withValues(alpha: 0.16) : context.tokens.surfaceAlt,
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            label,
            style: context.texts.labelLarge?.copyWith(
              color: selected ? tint : context.colors.onSurface,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
