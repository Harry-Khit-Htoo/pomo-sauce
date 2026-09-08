import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../core/formatting.dart';
import 'pomodoro_state.dart';

/// Entry point for the foreground-service isolate. Must be a top-level
/// function annotated with @pragma so it survives tree shaking in release.
@pragma('vm:entry-point')
void startTimerTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_TimerTaskHandler());
}

/// Runs in its own isolate for as long as a session is active.
///
/// It deliberately holds no state of its own: once a second it re-reads the
/// timer state the main isolate persisted and re-renders the notification
/// from it. Because that state is a set of absolute timestamps, the countdown
/// it shows stays correct no matter how long the isolate was starved.
class _TimerTaskHandler extends TaskHandler {
  String? _lastText;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) => _refresh();

  @override
  void onRepeatEvent(DateTime timestamp) => _refresh();

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onNotificationPressed() => FlutterForegroundTask.launchApp('/focus');

  Future<void> _refresh() async {
    final state = await _readState();
    if (state == null) return;

    final remaining = state.remainingAt(DateTime.now());
    // While ringing, state.phase is already the *next* interval, so name the
    // one that just ended rather than the one that is queued up.
    final title = switch (state.status) {
      TimerStatus.paused => '${state.phase.label} paused',
      TimerStatus.ringing =>
        state.phase.isBreak ? 'Focus complete' : 'Break over',
      _ => state.phase.label,
    };
    final text = state.status == TimerStatus.ringing
        ? 'Tap to open Pomo Sauce'
        : '${formatCountdown(remaining)} remaining';

    if (text == _lastText) return;
    _lastText = text;
    await FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: text,
    );
  }

  Future<PomodoroState?> _readState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final raw = prefs.getString('timer_state_json');
      if (raw == null) return null;
      return PomodoroStateJson.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('Pomo Sauce service: could not read timer state ($e)');
      return null;
    }
  }
}

/// Thin wrapper over the plugin so the controller does not care which
/// platform it is on. On iOS this is a no-op: iOS has no equivalent of a
/// foreground service, and the scheduled notification chain covers it.
abstract final class TimerForegroundService {
  static bool _initialised = false;

  static void init() {
    if (_initialised) return;
    _initialised = true;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'pomo_sauce_timer',
        channelName: 'Running timer',
        channelDescription:
            'Shows the live countdown while a focus session or break is '
            'running. Required to keep the timer accurate in the background.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
        showWhen: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(1000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  static Future<bool> get isRunning async {
    if (!Platform.isAndroid) return false;
    return FlutterForegroundTask.isRunningService;
  }

  static Future<void> start({
    required String title,
    required String text,
  }) async {
    if (!Platform.isAndroid) return;
    init();
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: text,
      );
      return;
    }
    final result = await FlutterForegroundTask.startService(
      serviceId: AppConstants.foregroundServiceId,
      // "specialUse" is the honest type for a user-facing countdown: it is not
      // media, location, or data sync. It must be declared in the manifest AND
      // justified in Play Console > App content > Foreground service permissions.
      serviceTypes: const [ForegroundServiceTypes.specialUse],
      notificationTitle: title,
      notificationText: text,
      callback: startTimerTaskCallback,
    );
    if (result is ServiceRequestFailure) {
      debugPrint('Pomo Sauce: foreground service refused (${result.error})');
    }
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }

  /// Android 13+ notification permission, asked through the same plugin that
  /// owns the service so the service can post its notification.
  static Future<bool> ensureNotificationPermission() async {
    if (!Platform.isAndroid) return true;
    final status = await FlutterForegroundTask.checkNotificationPermission();
    if (status == NotificationPermission.granted) return true;
    final result = await FlutterForegroundTask.requestNotificationPermission();
    return result == NotificationPermission.granted;
  }

  static Future<bool> get isIgnoringBatteryOptimizations async {
    if (!Platform.isAndroid) return true;
    return FlutterForegroundTask.isIgnoringBatteryOptimizations;
  }

  static Future<void> openBatteryOptimizationSettings() async {
    if (!Platform.isAndroid) return;
    await FlutterForegroundTask.openIgnoreBatteryOptimizationSettings();
  }
}
