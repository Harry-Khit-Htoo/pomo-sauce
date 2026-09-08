import 'package:flutter/material.dart';

/// The alarm tones bundled with the app. [rawResource] is the Android
/// `res/raw` name used for the notification channel sound; [assetPath] is the
/// same file played in-app while the app is in the foreground.
enum AlarmTone {
  analogBell('analog_bell', 'Analog bell', 'Soft mechanical cling-cling-cling'),
  softChime('soft_chime', 'Soft chime', 'A warm two-note chime'),
  digitalBeep('digital_beep', 'Digital beep', 'Short and dry');

  const AlarmTone(this.rawResource, this.label, this.description);

  final String rawResource;
  final String label;
  final String description;

  String get assetPath => 'sounds/$rawResource.wav';

  /// Each tone needs its own notification channel: Android bakes the sound
  /// into the channel at creation time and will not change it afterwards.
  String get channelId => 'tomato_focus_alarm_$rawResource';

  static AlarmTone fromName(String? name) => AlarmTone.values.firstWhere(
        (t) => t.name == name,
        orElse: () => AlarmTone.analogBell,
      );
}

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.alarmTone = AlarmTone.analogBell,
    this.alarmVolume = 0.8,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.keepScreenOn = true,
    this.dimDuringFocus = false,
    this.autoStartNext = false,
    this.activePresetId = 'study',
    this.onboardingComplete = false,
    this.notificationPrimerShown = false,
    this.dndDuringFocus = false,
    this.dndExplainerShown = false,
  });

  final ThemeMode themeMode;
  final AlarmTone alarmTone;
  final double alarmVolume;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final bool keepScreenOn;
  final bool dimDuringFocus;
  final bool autoStartNext;
  final String activePresetId;
  final bool onboardingComplete;
  final bool notificationPrimerShown;

  /// Silence notifications while a focus interval runs. Off until the user
  /// has seen the explainer and granted notification policy access.
  final bool dndDuringFocus;

  /// The explainer is shown once. If the user declines we leave the toggle in
  /// Settings and never ask again - no repeated nagging.
  final bool dndExplainerShown;

  AppSettings copyWith({
    ThemeMode? themeMode,
    AlarmTone? alarmTone,
    double? alarmVolume,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? keepScreenOn,
    bool? dimDuringFocus,
    bool? autoStartNext,
    String? activePresetId,
    bool? onboardingComplete,
    bool? notificationPrimerShown,
    bool? dndDuringFocus,
    bool? dndExplainerShown,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      alarmTone: alarmTone ?? this.alarmTone,
      alarmVolume: alarmVolume ?? this.alarmVolume,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      dimDuringFocus: dimDuringFocus ?? this.dimDuringFocus,
      autoStartNext: autoStartNext ?? this.autoStartNext,
      activePresetId: activePresetId ?? this.activePresetId,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      notificationPrimerShown:
          notificationPrimerShown ?? this.notificationPrimerShown,
      dndDuringFocus: dndDuringFocus ?? this.dndDuringFocus,
      dndExplainerShown: dndExplainerShown ?? this.dndExplainerShown,
    );
  }
}
