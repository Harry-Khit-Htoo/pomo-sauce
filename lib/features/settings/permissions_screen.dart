import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/widgets.dart';

/// The in-app explanation of every permission the app declares.
///
/// Kept in sync with the manifest and with README.md, so the Play Console
/// declarations, the store listing and what the user is told all match.
class PermissionsScreen extends StatelessWidget {
  const PermissionsScreen({super.key});

  static const _entries = <(IconData, String, String, String)>[
    (
      Icons.notifications_active_outlined,
      'POST_NOTIFICATIONS',
      'Show alerts',
      'Android 13 and later require your permission before any app can post '
          'a notification. Without it we cannot tell you that a focus session '
          'or break has ended. Asked the first time you start a timer.',
    ),
    (
      Icons.alarm_on_outlined,
      'SCHEDULE_EXACT_ALARM',
      'Alert exactly on time',
      'A Pomodoro that rings four minutes late is useless. This lets the '
          'system wake the phone at the precise second your interval ends. '
          'If you decline, the app still works but the alert may be delayed.',
    ),
    (
      Icons.timer_outlined,
      'FOREGROUND_SERVICE',
      'Keep counting in the background',
      'While a session runs, the app posts an ongoing notification with the '
          'live countdown. That notification is what allows the timer to keep '
          'running accurately when you leave the app or lock your phone.',
    ),
    (
      Icons.screen_lock_portrait_outlined,
      'WAKE_LOCK',
      'Keep the screen on while you focus',
      'Only used while the focus display is open and only if you have turned '
          'on "Keep screen on". It is released the moment you leave the '
          'screen or the session ends.',
    ),
    (
      Icons.vibration_rounded,
      'VIBRATE',
      'Vibrate when an interval ends',
      'Used for the completion alert. You can turn vibration off in Settings.',
    ),
    (
      Icons.restart_alt_rounded,
      'RECEIVE_BOOT_COMPLETED',
      'Survive a restart',
      'Lets a pending completion alert be re-armed after the phone reboots, '
          'so a session you started before the restart still alerts you.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Permissions')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(
            'Tomato Focus asks for the smallest set of permissions that lets '
            'a timer be genuinely reliable. It requests no location, no '
            'contacts, no camera and no network access.',
            style: context.texts.bodyMedium
                ?.copyWith(color: context.tokens.textMuted, height: 1.5),
          ),
          const SizedBox(height: 20),
          for (final (icon, code, title, body) in _entries) ...[
            SectionCard(
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
                        const SizedBox(height: 2),
                        Text(
                          code,
                          style: context.texts.labelSmall?.copyWith(
                            color: context.tokens.textMuted,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          body,
                          style: context.texts.bodySmall?.copyWith(
                            color: context.tokens.textMuted,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
