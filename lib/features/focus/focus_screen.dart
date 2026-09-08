import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/formatting.dart';
import '../../data/models/pomodoro_phase.dart';
import '../../mascot/mascot_mood.dart';
import '../../mascot/mascot_speech.dart';
import '../../mascot/tomato_mascot.dart';
import '../../providers.dart';
import '../../timer/pomodoro_controller.dart';
import '../../timer/pomodoro_state.dart';
import 'timer_ring.dart';

/// The Focus Display: mascot plus countdown, big and centred.
///
/// The layout is chosen from the available box rather than from a locked
/// orientation, so it reflows for portrait, landscape, split screen and
/// short phones without any fixed pixel assumptions.
class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  bool _dimmed = false;

  /// Held so dispose() never has to touch `ref` after the element unmounts.
  PomodoroController? _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = ref.read(pomodoroProvider.notifier);
      _controller = controller;
      controller.setFocusScreenVisible(true);
      if (ref.read(settingsProvider).dimDuringFocus) {
        setState(() => _dimmed = true);
      }
    });
  }

  @override
  void dispose() {
    _controller?.setFocusScreenVisible(false);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleDim() {
    setState(() => _dimmed = !_dimmed);
    SystemChrome.setEnabledSystemUIMode(
      _dimmed ? SystemUiMode.immersive : SystemUiMode.edgeToEdge,
    );
  }

  Color _phaseColor(BuildContext context, PomodoroPhase phase) =>
      switch (phase) {
        PomodoroPhase.focus => context.tokens.focus,
        PomodoroPhase.shortBreak => context.tokens.shortBreak,
        PomodoroPhase.longBreak => context.tokens.longBreak,
      };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pomodoroProvider);
    final controller = ref.watch(pomodoroProvider.notifier);
    final preset = ref.watch(activePresetProvider);
    final colour = _phaseColor(context, state.phase);
    final mood = ref.watch(mascotMoodProvider);

    final body = LayoutBuilder(
      builder: (context, box) {
        // Landscape gets its own layout, not a stretched portrait one.
        final landscape = box.maxWidth > box.maxHeight * 1.15;

        // Chrome that must never be clipped gets its height reserved first;
        // the ring then takes whatever is genuinely left over. Sizing the ring
        // from the full height is what pushed the controls off the bottom of
        // short landscape screens.
        // Short landscape (a small phone on its side, a foldable cover screen)
        // has almost no vertical room. Rather than let anything clip, that tier
        // drops the speech bubble, shrinks the badge to its icon, and lets the
        // ring go genuinely small.
        final tight = landscape && box.maxHeight < 320;

        final controlsBand = tight ? 46.0 : 68.0;
        final badgeBand = tight ? 46.0 : 64.0;
        final gaps = tight ? 18.0 : 32.0;

        final double ringSize;
        final double mascotSize;
        if (landscape) {
          final half = box.maxWidth / 2;
          final vertical = box.maxHeight - controlsBand - badgeBand - gaps;
          // Generous: FittedBox shrinks the whole group if it does not fit.
          ringSize = math.min(vertical, half * 0.80).clamp(150.0, 320.0);
          // The mascot is a co-equal element, not a footnote beside the ring.
          // It is sized from the height it actually has rather than from the
          // ring, because the ring's budget is eaten by the badge and controls
          // stacked under it while the mascot only carries a speech bubble.
          mascotSize = (box.maxHeight - (tight ? 40.0 : 118.0)).clamp(
            tight ? 96.0 : 120.0,
            260.0,
          );
        } else {
          ringSize = (box.maxWidth * 0.72).clamp(200.0, 340.0);
          mascotSize = (box.maxWidth * 0.38).clamp(110.0, 200.0);
        }

        final ring = TimerRing(
          clock: controller.clock,
          remaining: state.remainingAt,
          progress: state.progressAt,
          color: colour,
          label: state.phase.label,
          size: ringSize,
          dimmed: _dimmed,
        );

        final mascot = _MascotPanel(
          mood: mood,
          state: state,
          size: mascotSize,
          dimmed: _dimmed,
          compact: landscape,
          showBubble: !tight,
        );

        final controls = _Controls(dimmed: _dimmed, dense: tight);
        final dndBadge = _DndBadge(dimmed: _dimmed, compact: tight);

        if (landscape) {
          // The halves stay flexible so nothing can overflow horizontally, but
          // each one hugs the centre line instead of centring inside its own
          // half - otherwise the two groups sit at 25% and 75% of the width
          // with a dead gap between them.
          // Cap the pair's overall width and centre it: on a wide landscape
          // display, two half-width columns drift to 25% and 75% and leave a
          // canyon down the middle however their contents are aligned.
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: math.min(box.maxWidth, 720),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // BoxFit.scaleDown is what actually guarantees nothing
                  // clips: a hand-computed height budget can always be
                  // defeated by a display we did not think of, so each group
                  // is laid out at its natural size and shrunk uniformly if it
                  // does not fit. The alignment pulls both groups in toward
                  // the centre line.
                  Flexible(
                    child: SizedBox.expand(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: mascot,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 28),
                  Flexible(
                    child: SizedBox.expand(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ring,
                              SizedBox(height: tight ? 10 : 14),
                              dndBadge,
                              SizedBox(height: tight ? 10 : 14),
                              controls,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              mascot,
              const SizedBox(height: 22),
              ring,
              const SizedBox(height: 18),
              dndBadge,
              const SizedBox(height: 18),
              controls,
              const SizedBox(height: 18),
              _CycleIndicator(
                completed: state.completedFocusInCycle,
                total: preset.sessionsBeforeLongBreak,
                color: colour,
                dimmed: _dimmed,
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      color: _dimmed
          ? (Theme.of(context).brightness == Brightness.dark
                ? Colors.black
                : context.colors.surface)
          : Theme.of(context).scaffoldBackgroundColor,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _dimmed
            ? null
            : AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  onPressed: () => Navigator.of(context).maybePop(),
                  tooltip: 'Close',
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.brightness_2_outlined),
                    onPressed: _toggleDim,
                    tooltip: 'Desk mode',
                  ),
                ],
              ),
        body: SafeArea(
          child: GestureDetector(
            onTap: _dimmed ? _toggleDim : null,
            behavior: HitTestBehavior.opaque,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 400),
              opacity: _dimmed ? 0.62 : 1,
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}

class _MascotPanel extends ConsumerWidget {
  const _MascotPanel({
    required this.mood,
    required this.state,
    required this.size,
    required this.dimmed,
    required this.compact,
    this.showBubble = true,
  });

  final MascotMood mood;
  final PomodoroState state;
  final double size;
  final bool dimmed;
  final bool compact;

  /// Dropped on very short landscape screens, where the bubble is the first
  /// thing that has to go: the face still carries the mood without it.
  final bool showBubble;

  String _line(int completedSessions) {
    if (state.status == TimerStatus.ringing) {
      // Milestone runs get their own line; every other completion falls back
      // to the mood's standard well-done.
      return MascotLines.milestone(completedSessions);
    }
    if (state.status == TimerStatus.paused) return MascotLines.paused;
    if (state.status == TimerStatus.idle) return MascotLines.firstSession;
    return mood.supportLine;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // In desk mode the mascot stops animating: a still frame at 62% opacity
    // is the whole point of leaving the phone on the table for an hour.
    if (dimmed) {
      return TomatoMascot(mood: mood, size: size, animate: false);
    }
    if (!showBubble) return TomatoMascot(mood: mood, size: size);
    final completed = ref.watch(totalSessionsProvider).value ?? 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TomatoMascot(mood: mood, size: size),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: SpeechBubble(
            text: _line(completed),
            tailAlignment: Alignment.topCenter,
            compact: compact,
          ),
        ),
      ],
    );
  }
}

class _Controls extends ConsumerWidget {
  const _Controls({required this.dimmed, this.dense = false});

  final bool dimmed;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pomodoroProvider);
    final controller = ref.read(pomodoroProvider.notifier);

    if (state.status == TimerStatus.ringing) {
      return Column(
        children: [
          SizedBox(
            width: 260,
            child: FilledButton.icon(
              onPressed: () => controller.dismissAlarm(startNext: true),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text('Start ${state.phase.label.toLowerCase()}'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: 260,
            child: OutlinedButton(
              onPressed: () => controller.dismissAlarm(),
              child: const Text('Not yet'),
            ),
          ),
        ],
      );
    }

    final running = state.status == TimerStatus.running;
    final idle = state.status == TimerStatus.idle;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _RoundAction(
          icon: Icons.stop_rounded,
          tooltip: 'Stop',
          onPressed: idle ? null : () => controller.stop(),
          dimmed: dimmed,
          dense: dense,
        ),
        SizedBox(width: dense ? 12 : 18),
        _PrimaryAction(
          icon: running ? Icons.pause_rounded : Icons.play_arrow_rounded,
          label: idle ? 'Start' : (running ? 'Pause' : 'Resume'),
          onPressed: () => idle ? controller.start() : controller.toggle(),
          dense: dense,
        ),
        SizedBox(width: dense ? 12 : 18),
        _RoundAction(
          icon: Icons.skip_next_rounded,
          tooltip: 'Skip to next',
          onPressed: () => controller.skip(),
          dimmed: dimmed,
          dense: dense,
        ),
      ],
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.dense = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: Size(0, dense ? 44 : 52),
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 20 : 30,
          vertical: dense ? 8 : 16,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      ),
      icon: Icon(icon, size: dense ? 20 : 26),
      label: Text(label, style: TextStyle(fontSize: dense ? 15 : 17)),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.dimmed,
    this.dense = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool dimmed;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: dense ? 20 : 24,
      style: IconButton.styleFrom(
        minimumSize: Size(dense ? 44 : 52, dense ? 44 : 52),
        backgroundColor: dimmed
            ? Colors.transparent
            : context.tokens.surfaceAlt,
        foregroundColor: context.colors.onSurface,
      ),
      icon: Icon(icon),
    );
  }
}

/// Four dots showing where you are in the cycle before the long break.
class _CycleIndicator extends StatelessWidget {
  const _CycleIndicator({
    required this.completed,
    required this.total,
    required this.color,
    required this.dimmed,
  });

  final int completed;
  final int total;
  final Color color;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(total, (i) {
            final done = i < completed;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              margin: const EdgeInsets.symmetric(horizontal: 5),
              width: done ? 12 : 10,
              height: done ? 12 : 10,
              decoration: BoxDecoration(
                color: done ? color : context.colors.outlineVariant,
                shape: BoxShape.circle,
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(
          completed >= total
              ? 'Long break next'
              : '${plural(total - completed, 'session')} to the long break',
          style: context.texts.bodySmall?.copyWith(
            color: context.tokens.textMuted,
          ),
        ),
      ],
    );
  }
}

/// The Do Not Disturb status badge.
///
/// A moon in a soft filled circle rather than the fine-print text pill it
/// replaced: silencing someone's phone is a state they must be able to see at
/// a glance and undo in one tap, so the icon carries the weight and the label
/// only supports it. Tapping opts out of *this session only* - it never
/// quietly rewrites the user's setting.
class _DndBadge extends ConsumerWidget {
  const _DndBadge({required this.dimmed, this.compact = false});

  final bool dimmed;

  /// Icon only, for very short landscape screens. The moon still carries the
  /// status and the tap target keeps its full size.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(pomodoroProvider.notifier);
    return ValueListenableBuilder<bool>(
      valueListenable: controller.dndActive,
      builder: (context, active, _) {
        if (!active) return const SizedBox.shrink();
        final tint = context.colors.primary;
        return Semantics(
          button: true,
          label: 'Do Not Disturb is on for this session. Tap to turn it off.',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(100),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                await controller.suppressDndForThisSession();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Notifications are back on for this session.',
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: compact ? 44 : 52,
                      height: compact ? 44 : 52,
                      decoration: BoxDecoration(
                        color: tint.withValues(alpha: dimmed ? 0.14 : 0.20),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.bedtime_rounded,
                        size: compact ? 24 : 28,
                        color: dimmed ? tint.withValues(alpha: 0.7) : tint,
                      ),
                    ),
                    if (!compact) const SizedBox(width: 12),
                    if (!compact)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DND on',
                            style: context.texts.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: context.colors.onSurface,
                            ),
                          ),
                          Text(
                            'Tap to turn off',
                            style: context.texts.bodySmall?.copyWith(
                              color: context.tokens.textMuted,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
