import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../mascot/mascot_mood.dart';
import '../../mascot/mascot_speech.dart';
import '../../mascot/tomato_mascot.dart';
import '../../data/models/timer_preset.dart';
import '../../providers.dart';
import '../../timer/foreground_service.dart';
import '../settings/dnd_explainer_screen.dart';
import '../shell/root_shell.dart';

/// One idea per screen, in the mascot's voice.
class _Beat {
  const _Beat({
    required this.mood,
    required this.line,
    required this.title,
    required this.body,
  });

  final MascotMood mood;

  /// What the tomato says, in the bubble.
  final String line;
  final String title;
  final String body;
}

const _beats = <_Beat>[
  _Beat(
    mood: MascotMood.welcoming,
    line: "Hi! I'm your focus buddy.",
    title: 'Nice to meet you',
    body: "I keep time so you don't have to watch the clock.",
  ),
  _Beat(
    mood: MascotMood.neutral,
    line: 'We work in short blocks, then rest.',
    title: 'Focus, then rest',
    body: 'One block at a time. I shout when each one is done.',
  ),
  _Beat(
    mood: MascotMood.happy,
    line: "Finish things and I'll keep score.",
    title: 'Streaks build themselves',
    body: 'Track a habit, link it to a session, and watch it fill in.',
  ),
];

/// First-run flow with the mascot as usher: greet, explain, pick a rhythm,
/// then hand over to the notification and Do Not Disturb explainers.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;
  bool _busy = false;

  /// Story beats, then the preset picker, then the permission primer.
  int get _pageCount => _beats.length + 2;
  bool get _isLast => _index == _pageCount - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _finish() async {
    setState(() => _busy = true);

    // Notifications first: the timer is useless without them. Asked here,
    // at the end of onboarding, with the reason still on screen.
    await TimerForegroundService.ensureNotificationPermission();
    await ref.read(notificationServiceProvider).requestNotificationPermission();
    await ref.read(settingsProvider.notifier).markPrimerShown();
    if (!mounted) return;

    // Then the DND explainer, which must run before the system settings
    // redirect it may lead to.
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const DndExplainerScreen()),
    );
    if (!mounted) return;

    await ref.read(settingsProvider.notifier).completeOnboarding();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const RootShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _busy ? null : _finish,
                child: const Text('Skip'),
              ),
            ),
            Expanded(
              // Tap anywhere to continue - the mascot is ushering, not
              // running a tutorial the user has to hunt through.
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _busy ? null : _next,
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pageCount,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) {
                    if (i < _beats.length) return _BeatPage(beat: _beats[i]);
                    if (i == _beats.length) return const _PresetPage();
                    return const _PermissionPrimer();
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pageCount, (i) {
                      final active = i == _index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active
                              ? context.colors.primary
                              : context.colors.outline,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _busy ? null : _next,
                      child: Text(
                        _isLast ? 'Allow notifications & start' : 'Next',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BeatPage extends StatelessWidget {
  const _BeatPage({required this.beat});

  final _Beat beat;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 520;
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                MascotCoach(
                  mood: beat.mood,
                  message: beat.line,
                  size: compact ? 130 : 190,
                ),
                SizedBox(height: compact ? 20 : 34),
                Text(
                  beat.title,
                  textAlign: TextAlign.center,
                  style: context.texts.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  beat.body,
                  textAlign: TextAlign.center,
                  style: context.texts.bodyLarge?.copyWith(
                    color: context.tokens.textMuted,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The one interactive beat: pick a starting rhythm. Pre-selected, so it is a
/// choice the user can make rather than a gate they have to clear.
class _PresetPage extends ConsumerWidget {
  const _PresetPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = ref.watch(presetsProvider);
    final selectedId = ref.watch(pomodoroProvider.select((s) => s.presetId));

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          const TomatoMascot(mood: MascotMood.alert, size: 120),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: const SpeechBubble(
              text: 'Which one suits you? You can change it later.',
              tailAlignment: Alignment.topCenter,
              compact: true,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Pick your first rhythm',
            textAlign: TextAlign.center,
            style: context.texts.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 18),
          for (final preset in presets)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PresetRow(
                preset: preset,
                selected: preset.id == selectedId,
                onTap: () {
                  ref.read(pomodoroProvider.notifier).selectPreset(preset.id);
                  ref.read(settingsProvider.notifier).setActivePreset(preset.id);
                },
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _PresetRow extends StatelessWidget {
  const _PresetRow({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final TimerPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = context.colors.primary;
    return Material(
      color: selected ? tint.withValues(alpha: 0.12) : context.colors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? tint : context.colors.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Text(preset.emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preset.name,
                      style: context.texts.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${preset.focusMinutes} min focus  ·  '
                      '${preset.shortBreakMinutes} min break',
                      style: context.texts.bodySmall
                          ?.copyWith(color: context.tokens.textMuted),
                    ),
                  ],
                ),
              ),
              if (selected) Icon(Icons.check_circle_rounded, color: tint),
            ],
          ),
        ),
      ),
    );
  }
}

/// The last page says, in plain language, exactly what the app is about to
/// ask the OS for - so the system dialog is never a surprise.
class _PermissionPrimer extends StatelessWidget {
  const _PermissionPrimer();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              const TomatoMascot(mood: MascotMood.welcoming, size: 130),
              const SizedBox(height: 24),
              Text(
                'One thing before we start',
                textAlign: TextAlign.center,
                style: context.texts.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 14),
              const _PermissionRow(
                icon: Icons.notifications_active_outlined,
                title: 'Notifications',
                body: 'So I can tell you the moment a session or break is '
                    'over, even when your screen is off.',
              ),
              const _PermissionRow(
                icon: Icons.alarm_on_outlined,
                title: 'Alarms & reminders',
                body: 'So the alert lands exactly on time instead of minutes '
                    'late. You can grant this later in Settings.',
              ),
              const _PermissionRow(
                icon: Icons.timer_outlined,
                title: 'A timer notification',
                body: 'While a session runs you will see a countdown in your '
                    'notification shade. That is what keeps the timer accurate '
                    'when the app is closed.',
              ),
              const SizedBox(height: 8),
              Text(
                'Nothing leaves your phone. There are no accounts and no '
                'analytics.',
                textAlign: TextAlign.center,
                style: context.texts.bodySmall
                    ?.copyWith(color: context.tokens.textMuted),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.colors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 20, color: context.colors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.texts.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: context.texts.bodySmall?.copyWith(
                    color: context.tokens.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
