import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_theme.dart';
import '../../core/constants.dart';
import '../../core/widgets.dart';
import '../../mascot/mascot_mood.dart';
import '../../mascot/tomato_mascot.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Center(
            child: Column(
              children: [
                const TomatoMascot(mood: MascotMood.happy, size: 150),
                const SizedBox(height: 10),
                Text(
                  'Productivity',
                  style: context.texts.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  AppConstants.appName,
                  style: context.texts.bodyLarge
                      ?.copyWith(color: context.tokens.textMuted),
                ),
                const SizedBox(height: 6),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    final info = snapshot.data;
                    return Text(
                      info == null
                          ? ''
                          : 'Version ${info.version} (${info.buildNumber})',
                      style: context.texts.bodySmall
                          ?.copyWith(color: context.tokens.textMuted),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your data stays on your phone',
                  style: context.texts.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pomo Sauce has no accounts, no analytics and no ads. '
                  'Your sessions, habits and settings are stored only in this '
                  'app on this device, and are deleted when you uninstall it.',
                  style: context.texts.bodyMedium
                      ?.copyWith(color: context.tokens.textMuted, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy policy'),
                  subtitle: const Text(AppConstants.privacyPolicyUrl),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                  onTap: () => _open(context, AppConstants.privacyPolicyUrl),
                ),
                ListTile(
                  leading: const Icon(Icons.mail_outline_rounded),
                  title: const Text('Contact support'),
                  subtitle: const Text(AppConstants.supportEmail),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                  onTap: () =>
                      _open(context, 'mailto:${AppConstants.supportEmail}'),
                ),
                const ListTile(
                  leading: Icon(Icons.favorite_outline_rounded),
                  title: Text('Credits'),
                  subtitle: Text(
                    'Built with Flutter. Mascot and alarm tones made for this '
                    'app - no third-party assets.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not open $url')),
      );
    }
  }
}
