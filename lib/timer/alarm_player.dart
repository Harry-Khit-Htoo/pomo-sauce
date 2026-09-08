import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';

import '../data/models/app_settings.dart';

/// Plays the alarm *inside* the app while the completion screen is showing.
///
/// The scheduled notification handles the case where the app is not on
/// screen; this is what makes the phone actually ring while the user is
/// looking at the mascot cheering.
class AlarmPlayer {
  AlarmPlayer._(this._player);

  final AudioPlayer _player;
  bool _ringing = false;

  static Future<AlarmPlayer> create() async {
    final player = AudioPlayer(playerId: 'pomo_sauce_alarm');
    await player.setReleaseMode(ReleaseMode.loop);
    // The alarm usage flag makes the tone follow the alarm volume slider and
    // sound through Do Not Disturb where the user has allowed alarms.
    await player.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: true,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.alarm,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {AVAudioSessionOptions.duckOthers},
        ),
      ),
    );
    return AlarmPlayer._(player);
  }

  bool get isRinging => _ringing;

  Future<void> start(
    AlarmTone tone, {
    required bool sound,
    required bool vibration,
    double volume = 0.8,
  }) async {
    await stop();
    _ringing = true;
    if (sound) {
      try {
        await _player.setVolume(volume.clamp(0.0, 1.0));
        await _player.play(AssetSource(tone.assetPath));
      } catch (e) {
        debugPrint('Pomo Sauce: alarm playback failed ($e)');
      }
    }
    if (vibration) {
      try {
        if (await Vibration.hasVibrator()) {
          await Vibration.vibrate(
            pattern: const [0, 400, 200, 400, 200, 600, 800],
            repeat: 0,
          );
        }
      } catch (e) {
        debugPrint('Pomo Sauce: vibration failed ($e)');
      }
    }
  }

  Future<void> stop() async {
    if (!_ringing) return;
    _ringing = false;
    try {
      await _player.stop();
    } catch (_) {}
    try {
      await Vibration.cancel();
    } catch (_) {}
  }

  /// Used by the Settings screen so the user can audition a tone.
  Future<void> preview(AlarmTone tone, {double volume = 0.8}) async {
    try {
      final preview = AudioPlayer(playerId: 'pomo_sauce_preview');
      await preview.setReleaseMode(ReleaseMode.release);
      await preview.setVolume(volume.clamp(0.0, 1.0));
      await preview.play(AssetSource(tone.assetPath));
      preview.onPlayerComplete.listen((_) => preview.dispose());
    } catch (e) {
      debugPrint('Pomo Sauce: preview failed ($e)');
    }
  }

  Future<void> dispose() async {
    await stop();
    await _player.dispose();
  }
}
