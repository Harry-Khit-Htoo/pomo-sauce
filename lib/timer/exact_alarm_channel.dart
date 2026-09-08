import 'dart:io';

import 'package:flutter/services.dart';

/// Bridge to the Android-only pieces of exact-alarm handling.
///
/// Android 12+ lets the user (and the system) revoke "Alarms & reminders" at
/// any time. When that happens the OS broadcasts
/// ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED, and any exact alarms
/// we had queued are dropped. [permissionChanges] surfaces that broadcast so
/// the app can re-schedule the pending chain the moment access comes back.
abstract final class ExactAlarmChannel {
  static const _methods = MethodChannel('app.pomosauce/exact_alarm');
  static const _events = EventChannel('app.pomosauce/exact_alarm_events');

  /// Emits the new "can schedule exact alarms" value whenever it changes.
  static Stream<bool> get permissionChanges {
    if (!Platform.isAndroid) return const Stream<bool>.empty();
    return _events.receiveBroadcastStream().map((event) => event == true);
  }

  static Future<bool> canScheduleExactAlarms() async {
    if (!Platform.isAndroid) return true;
    return await _methods.invokeMethod<bool>('canScheduleExactAlarms') ?? true;
  }

  /// Opens Settings > Apps > Pomo Sauce > Alarms & reminders.
  static Future<void> openExactAlarmSettings() async {
    if (!Platform.isAndroid) return;
    await _methods.invokeMethod<void>('openExactAlarmSettings');
  }

  /// Whether the OS will let a scheduled alarm wake the device at all.
  static Future<bool> areAlarmsAllowed() async {
    if (!Platform.isAndroid) return true;
    return await _methods.invokeMethod<bool>('areAlarmsAllowed') ?? true;
  }
}
