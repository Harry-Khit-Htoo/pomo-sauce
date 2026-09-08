import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/app_settings.dart';
import 'models/timer_preset.dart';

/// Settings and presets live in SharedPreferences: small, synchronous to read
/// once loaded, and available to the foreground-service isolate.
class SettingsRepository {
  SettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static Future<SettingsRepository> open() async =>
      SettingsRepository(await SharedPreferences.getInstance());

  static const _kThemeMode = 'theme_mode';
  static const _kAlarmTone = 'alarm_tone';
  static const _kAlarmVolume = 'alarm_volume';
  static const _kSoundEnabled = 'sound_enabled';
  static const _kVibrationEnabled = 'vibration_enabled';
  static const _kKeepScreenOn = 'keep_screen_on';
  static const _kDimDuringFocus = 'dim_during_focus';
  static const _kAutoStartNext = 'auto_start_next';
  static const _kActivePreset = 'active_preset_id';
  static const _kOnboarding = 'onboarding_complete';
  static const _kPrimerShown = 'notification_primer_shown';
  static const _kDndDuringFocus = 'dnd_during_focus';
  static const _kDndExplainer = 'dnd_explainer_shown';
  static const _kPresets = 'presets_json';

  AppSettings load() {
    return AppSettings(
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == _prefs.getString(_kThemeMode),
        orElse: () => ThemeMode.system,
      ),
      alarmTone: AlarmTone.fromName(_prefs.getString(_kAlarmTone)),
      alarmVolume: _prefs.getDouble(_kAlarmVolume) ?? 0.8,
      soundEnabled: _prefs.getBool(_kSoundEnabled) ?? true,
      vibrationEnabled: _prefs.getBool(_kVibrationEnabled) ?? true,
      keepScreenOn: _prefs.getBool(_kKeepScreenOn) ?? true,
      dimDuringFocus: _prefs.getBool(_kDimDuringFocus) ?? false,
      autoStartNext: _prefs.getBool(_kAutoStartNext) ?? false,
      activePresetId: _prefs.getString(_kActivePreset) ?? 'study',
      onboardingComplete: _prefs.getBool(_kOnboarding) ?? false,
      notificationPrimerShown: _prefs.getBool(_kPrimerShown) ?? false,
      dndDuringFocus: _prefs.getBool(_kDndDuringFocus) ?? false,
      dndExplainerShown: _prefs.getBool(_kDndExplainer) ?? false,
    );
  }

  Future<void> save(AppSettings s) async {
    await _prefs.setString(_kThemeMode, s.themeMode.name);
    await _prefs.setString(_kAlarmTone, s.alarmTone.name);
    await _prefs.setDouble(_kAlarmVolume, s.alarmVolume);
    await _prefs.setBool(_kSoundEnabled, s.soundEnabled);
    await _prefs.setBool(_kVibrationEnabled, s.vibrationEnabled);
    await _prefs.setBool(_kKeepScreenOn, s.keepScreenOn);
    await _prefs.setBool(_kDimDuringFocus, s.dimDuringFocus);
    await _prefs.setBool(_kAutoStartNext, s.autoStartNext);
    await _prefs.setString(_kActivePreset, s.activePresetId);
    await _prefs.setBool(_kOnboarding, s.onboardingComplete);
    await _prefs.setBool(_kPrimerShown, s.notificationPrimerShown);
    await _prefs.setBool(_kDndDuringFocus, s.dndDuringFocus);
    await _prefs.setBool(_kDndExplainer, s.dndExplainerShown);
  }

  List<TimerPreset> loadPresets() {
    final raw = _prefs.getString(_kPresets);
    if (raw == null) return List.of(TimerPreset.defaults);
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      final presets = list.map(TimerPreset.fromJson).toList();
      return presets.isEmpty ? List.of(TimerPreset.defaults) : presets;
    } on FormatException {
      return List.of(TimerPreset.defaults);
    }
  }

  Future<void> savePresets(List<TimerPreset> presets) => _prefs.setString(
        _kPresets,
        jsonEncode(presets.map((p) => p.toJson()).toList()),
      );

  Future<void> resetPresets() => _prefs.remove(_kPresets);

  // --- persisted timer state -------------------------------------------
  // The running timer is written here on every transition so a cold start
  // after the process is killed can recover the session exactly.

  static const _kTimerState = 'timer_state_json';

  Map<String, dynamic>? loadTimerState() {
    final raw = _prefs.getString(_kTimerState);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } on FormatException {
      return null;
    }
  }

  Future<void> saveTimerState(Map<String, dynamic>? state) async {
    if (state == null) {
      await _prefs.remove(_kTimerState);
    } else {
      await _prefs.setString(_kTimerState, jsonEncode(state));
    }
  }

  Future<void> clearAll() => _prefs.clear();
}
