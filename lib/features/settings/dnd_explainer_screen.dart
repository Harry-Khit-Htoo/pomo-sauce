import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../mascot/mascot_mood.dart';
import '../../mascot/mascot_speech.dart';
import '../../providers.dart';
import '../../timer/dnd_service.dart';

/// The one-time explainer that has to run *before* the user is ever sent to
/// the system notification-policy screen.
///
/// Notification policy access is granted on a system settings page, not a
/// runtime dialog. Redirecting someone there with no warning is exactly the
/// unexplained device-settings change Play's policy prohibits, so this screen
/// is a hard prerequisite, not a nicety. It states what will be changed, that
/// the alarm still gets through, and how to turn it off again.
///
/// Returns `true` from the route if the user ended up with DND enabled.
class DndExplainerScreen extends ConsumerStatefulWidget {
  const DndExplainerScreen({super.key, this.onFinished});

  /// Called with the outcome instead of popping, when hosted inside onboarding.
  final ValueChanged<bool>? onFinished;

  @override
  ConsumerState<DndExplainerScreen> createState() => _DndExplainerScreenState();
}

class _DndExplainerScreenState extends ConsumerState<DndExplainerScreen>
    with WidgetsBindingObserver {
  bool _awaitingGrant = false;

  static const _steps = <(IconData, String, String)>[
    (
      Icons.notifications_off_outlined,
      "I'll quiet your notifications",
      'While a focus session runs, your phone goes into priority mode. '
          'Breaks are left alone.',
    ),
    (
      Icons.alarm_on_outlined,
      'Your timer still gets through',
      "The session-end alarm is allowed past Do Not Disturb, so you won't "
          'miss the end of a session.',
    ),
    (
      Icons.tune_rounded,
      'You stay in charge',
      'Your normal mode comes straight back when the session ends, and you '
          'can turn this off any time in Settings.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user grants access on a system screen, so the only way to learn the
    // outcome is to re-check when they come back.
    if (state == AppLifecycleState.resumed && _awaitingGrant) {
      _awaitingGrant = false;
      _checkGrant();
    }
  }

  Future<void> _checkGrant() async {
    final granted = await DndService.isPolicyAccessGranted();
    if (!mounted) return;
    await ref.read(settingsProvider.notifier).setDndDuringFocus(granted);
    if (!mounted) return;
    _finish(granted);
    if (granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Focus sessions will now quiet your notifications.'),
        ),
      );
    }
  }

  Future<void> _grant() async {
    await ref.read(settingsProvider.notifier).markDndExplainerShown();
    _awaitingGrant = true;
    await DndService.openPolicyAccessSettings();
  }

  Future<void> _skip() async {
    // Declining is remembered so the explainer never nags again; the toggle
    // stays available in Settings.
    await ref.read(settingsProvider.notifier).markDndExplainerShown();
    if (!mounted) return;
    _finish(false);
  }

  void _finish(bool enabled) {
    final callback = widget.onFinished;
    if (callback != null) {
      callback(enabled);
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(enabled);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            final compact = box.maxHeight < 620;
            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: box.maxHeight - 150),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: compact ? 8 : 20),
                          MascotCoach(
                            mood: MascotMood.welcoming,
                            message: 'Want me to keep the noise down '
                                'while you focus?',
                            size: compact ? 120 : 160,
                          ),
                          SizedBox(height: compact ? 18 : 30),
                          Text(
                            'Quiet mode for focus sessions',
                            textAlign: TextAlign.center,
                            style: context.texts.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 18),
                          for (final (icon, title, body) in _steps)
                            _Step(icon: icon, title: title, body: body),
                          const SizedBox(height: 10),
                          Text(
                            'Android asks for this on its own settings screen. '
                            'We only use it to silence notifications during a '
                            'session, and for nothing else.',
                            textAlign: TextAlign.center,
                            style: context.texts.bodySmall?.copyWith(
                              color: context.tokens.textMuted,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 18),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _grant,
                          icon: const Icon(Icons.do_not_disturb_on_outlined),
                          label: const Text('Set it up'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _skip,
                        child: const Text('Not now'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
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
