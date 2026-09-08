import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Do Not Disturb, scoped to focus sessions and nothing else.
///
/// The order of operations is fixed by Play's device-settings policy and is
/// enforced by the call sites, not just documented here:
///
///   1. Show the in-app explainer ([DndExplainerScreen]) first. Notification
///      policy access is granted on a *system settings screen*, not a runtime
///      dialog, so sending the user there unannounced reads as hostile.
///   2. Only then open settings via [openPolicyAccessSettings].
///   3. Only silence the phone while a work interval is actually running, and
///      hand it straight back with [disable] when the interval ends, is
///      paused, or is cancelled.
///
/// The completion alarm stays audible because its notification channel sets
/// `bypassDnd`, not because the filter is weakened - the rest of the phone
/// stays properly quiet.
abstract final class DndService {
  static const _channel = MethodChannel('app.tomatofocus/dnd');

  static bool get isSupported => Platform.isAndroid;

  /// Has the user granted notification policy access?
  static Future<bool> isPolicyAccessGranted() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('isPolicyAccessGranted') ?? false;
    } on PlatformException catch (e) {
      debugPrint('Tomato Focus: DND access check failed ($e)');
      return false;
    }
  }

  /// Opens the system screen where policy access is granted. Never call this
  /// before the explainer has been shown.
  static Future<void> openPolicyAccessSettings() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('openPolicyAccessSettings');
    } on PlatformException catch (e) {
      debugPrint('Tomato Focus: could not open DND settings ($e)');
    }
  }

  /// Enters priority mode, remembering the user's own mode first.
  /// Returns false if access was not granted or the system refused.
  static Future<bool> enable() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('enable') ?? false;
    } on PlatformException catch (e) {
      debugPrint('Tomato Focus: could not enable DND ($e)');
      return false;
    }
  }

  /// Restores exactly the mode the user was in before we touched it.
  static Future<bool> disable() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('restore') ?? false;
    } on PlatformException catch (e) {
      debugPrint('Tomato Focus: could not restore DND ($e)');
      return false;
    }
  }

  /// Hands back a filter stranded by a previous run that was killed while
  /// holding DND. Called once at startup, before anything else touches the
  /// filter; a session that is still running simply re-enables afterwards.
  static Future<bool> reconcileAfterRestart() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('reconcile') ?? false;
    } on PlatformException catch (e) {
      debugPrint('Tomato Focus: DND reconcile failed ($e)');
      return false;
    }
  }

  /// True while this app is the one holding the phone in DND - drives the
  /// "tap to disable" chip on the focus screen.
  static Future<bool> isHoldingDnd() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('isHoldingDnd') ?? false;
    } on PlatformException {
      return false;
    }
  }
}
