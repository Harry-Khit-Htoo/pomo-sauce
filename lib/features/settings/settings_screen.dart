import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/widgets.dart';
import '../../data/models/app_settings.dart';
import '../../providers.dart';
import '../../timer/exact_alarm_channel.dart';
import '../../timer/dnd_service.dart';
import '../../timer/foreground_service.dart';
import 'about_screen.dart';
import 'dnd_explainer_screen.dart';
import 'data_screen.dart';
import 'permissions_screen.dart';
import 'presets_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          const SectionHeader('Appearance'),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Theme',
                  style: context.texts.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Follows your system setting unless you pick one.',
                  style: context.texts.bodySmall
                      ?.copyWith(color: context.tokens.textMuted),
                ),
                const SizedBox(height: 14),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Light'),
                      icon: Icon(Icons.light_mode_outlined),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('Dark'),
                      icon: Icon(Icons.dark_mode_outlined),
                    ),
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('System'),
                      icon: Icon(Icons.brightness_auto_outlined),
                    ),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (s) => controller.setThemeMode(s.first),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionHeader('Timer'),
          SectionCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.tune_rounded),
                  title: const Text('Presets & durations'),
                  subtitle: const Text('Edit, add or reset your rhythms'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PresetsScreen()),
                  ),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.play_circle_outline_rounded),
                  title: const Text('Auto-start next interval'),
                  subtitle: const Text(
                    'Roll straight from focus into break and back',
                  ),
                  value: settings.autoStartNext,
                  onChanged: controller.setAutoStart,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.screen_lock_portrait_outlined),
                  title: const Text('Keep screen on while focusing'),
                  subtitle: const Text(
                    'Only while the focus display is open',
                  ),
                  value: settings.keepScreenOn,
                  onChanged: controller.setKeepScreenOn,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.brightness_2_outlined),
                  title: const Text('Start in desk mode'),
                  subtitle: const Text(
                    'Dimmed, still display for leaving on the table',
                  ),
                  value: settings.dimDuringFocus,
                  onChanged: controller.setDimDuringFocus,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionHeader('Focus mode'),
          const _DndSection(),
          const SizedBox(height: 22),
          const SectionHeader('Alarm'),
          const _AlarmSection(),
          const SizedBox(height: 22),
          const SectionHeader('Permissions'),
          const _PermissionSummary(),
          const SizedBox(height: 22),
          const SectionHeader('Data & about'),
          SectionCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: const Text('Export or reset data'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DataScreen()),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('About & privacy policy'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AboutScreen()),
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

class _AlarmSection extends ConsumerWidget {
  const _AlarmSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final timer = ref.read(pomodoroProvider.notifier);

    return SectionCard(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 16),
      child: Column(
        children: [
          for (final tone in AlarmTone.values)
            ListTile(
              onTap: () async {
                await controller.setTone(tone);
                await timer.previewTone(tone);
              },
              leading: Icon(
                settings.alarmTone == tone
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: settings.alarmTone == tone
                    ? context.colors.primary
                    : context.tokens.textMuted,
              ),
              title: Text(tone.label),
              subtitle: Text(tone.description),
              trailing: IconButton(
                tooltip: 'Play',
                icon: const Icon(Icons.volume_up_outlined),
                onPressed: () => timer.previewTone(tone),
              ),
            ),
          const Divider(height: 20, indent: 16, endIndent: 16),
          SwitchListTile(
            secondary: const Icon(Icons.music_note_outlined),
            title: const Text('Play a sound'),
            value: settings.soundEnabled,
            onChanged: controller.setSound,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.vibration_rounded),
            title: const Text('Vibrate'),
            value: settings.vibrationEnabled,
            onChanged: controller.setVibration,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Icon(Icons.volume_down_rounded,
                    size: 20, color: context.tokens.textMuted),
                Expanded(
                  child: Slider(
                    value: settings.alarmVolume,
                    onChanged: settings.soundEnabled
                        ? (v) => controller.setVolume(v)
                        : null,
                    onChangeEnd: (v) => timer.previewTone(settings.alarmTone),
                  ),
                ),
                Icon(Icons.volume_up_rounded,
                    size: 20, color: context.tokens.textMuted),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Android plays the alarm through a notification channel. If you '
              'change the sound here and it does not take effect, check the '
              'channel in system notification settings.',
              style: context.texts.bodySmall
                  ?.copyWith(color: context.tokens.textMuted, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// A live read-out of the three permissions the timer depends on, with a
/// one-tap route to fix each. Play reviewers and users both want this
/// visible rather than buried.
class _PermissionSummary extends ConsumerStatefulWidget {
  const _PermissionSummary();

  @override
  ConsumerState<_PermissionSummary> createState() => _PermissionSummaryState();
}

class _PermissionSummaryState extends ConsumerState<_PermissionSummary> {
  bool? _notifications;
  bool? _exactAlarms;
  bool? _batteryExempt;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final notifications =
        await ref.read(notificationServiceProvider).areNotificationsEnabled();
    final exact = await ExactAlarmChannel.canScheduleExactAlarms();
    final battery = await TimerForegroundService.isIgnoringBatteryOptimizations;
    if (!mounted) return;
    setState(() {
      _notifications = notifications;
      _exactAlarms = exact;
      _batteryExempt = battery;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          _PermissionTile(
            icon: Icons.notifications_active_outlined,
            title: 'Notifications',
            body: 'Needed to alert you when an interval ends.',
            granted: _notifications,
            onFix: () async {
              await ref
                  .read(notificationServiceProvider)
                  .requestNotificationPermission();
              await _refresh();
            },
          ),
          _PermissionTile(
            icon: Icons.alarm_on_outlined,
            title: 'Alarms & reminders',
            body: 'Without it the alert can arrive minutes late.',
            granted: _exactAlarms,
            onFix: () async {
              await ExactAlarmChannel.openExactAlarmSettings();
              await _refresh();
            },
          ),
          _PermissionTile(
            icon: Icons.battery_saver_outlined,
            title: 'Unrestricted battery use',
            body: 'Optional. Stops aggressive power saving killing the timer.',
            granted: _batteryExempt,
            optional: true,
            onFix: () async {
              await TimerForegroundService.openBatteryOptimizationSettings();
              await _refresh();
            },
          ),
          ListTile(
            leading: const Icon(Icons.help_outline_rounded),
            title: const Text('Why does this app need these?'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PermissionsScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.body,
    required this.granted,
    required this.onFix,
    this.optional = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool? granted;
  final Future<void> Function() onFix;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final ok = granted == true;
    final colour = ok
        ? context.tokens.shortBreak
        : (optional ? context.tokens.textMuted : const Color(0xFFE8A33D));
    return ListTile(
      leading: Icon(icon, color: colour),
      title: Text(title),
      subtitle: Text(body),
      trailing: granted == null
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : ok
              ? Icon(Icons.check_circle_rounded, color: colour)
              : TextButton(onPressed: onFix, child: const Text('Fix')),
    );
  }
}


/// The Do Not Disturb toggle.
///
/// Turning it on always routes through the explainer the first time, and
/// through the system settings screen whenever policy access is missing -
/// there is no code path here that silences the phone without the user having
/// seen why.
class _DndSection extends ConsumerStatefulWidget {
  const _DndSection();

  @override
  ConsumerState<_DndSection> createState() => _DndSectionState();
}

class _DndSectionState extends ConsumerState<_DndSection>
    with WidgetsBindingObserver {
  bool? _granted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final granted = await DndService.isPolicyAccessGranted();
    if (!mounted) return;
    setState(() => _granted = granted);
    // Access can be revoked from system settings at any time; do not leave
    // the toggle claiming something that can no longer happen.
    if (!granted && ref.read(settingsProvider).dndDuringFocus) {
      await ref.read(settingsProvider.notifier).setDndDuringFocus(false);
    }
  }

  Future<void> _onChanged(bool value) async {
    if (!value) {
      await ref.read(settingsProvider.notifier).setDndDuringFocus(false);
      return;
    }
    if (_granted == true) {
      await ref.read(settingsProvider.notifier).setDndDuringFocus(true);
      return;
    }
    // Explainer first, always - then the system screen.
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const DndExplainerScreen()),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final supported = DndService.isSupported;

    return SectionCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.do_not_disturb_on_outlined),
            title: const Text('Silence notifications during focus sessions'),
            subtitle: Text(
              !supported
                  ? 'Available on Android only.'
                  : settings.dndDuringFocus
                      ? 'Your normal mode returns when the session ends.'
                      : 'Breaks are left alone, and your timer alarm still '
                          'gets through.',
            ),
            value: settings.dndDuringFocus,
            onChanged: supported ? _onChanged : null,
          ),
          if (supported && _granted == false && settings.dndExplainerShown)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 16, color: context.tokens.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Needs Do Not Disturb access, which is granted in system '
                      'settings.',
                      style: context.texts.bodySmall
                          ?.copyWith(color: context.tokens.textMuted),
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
