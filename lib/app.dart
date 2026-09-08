import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_theme.dart';
import 'core/constants.dart';
import 'features/focus/focus_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/shell/root_shell.dart';
import 'providers.dart';

class PomoSauceApp extends ConsumerWidget {
  const PomoSauceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    final onboarded =
        ref.watch(settingsProvider.select((s) => s.onboardingComplete));

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Defaults to following the system setting; Settings can override it.
      themeMode: themeMode,
      home: onboarded ? const RootShell() : const OnboardingScreen(),
      routes: {
        '/focus': (_) => const FocusScreen(),
      },
      builder: (context, child) {
        // Keep the app legible when the OS font scale is cranked right up,
        // without letting a 2.0x scale break the countdown layout.
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.4,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
