import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/constants.dart';
import '../data/models/app_settings.dart';
import '../data/models/pomodoro_phase.dart';

/// One upcoming interval boundary that needs an alert.
class ScheduledAlert {
  const ScheduledAlert({
    required this.phase,
    required this.firesAt,
    required this.nextPhase,
  });

  /// The interval that is *ending*.
  final PomodoroPhase phase;
  final DateTime firesAt;
  final PomodoroPhase nextPhase;
}

/// Owns every OS-level notification.
///
/// The completion alert is not driven by a Dart timer: the whole upcoming
/// chain of interval boundaries is handed to the OS up front via
/// `zonedSchedule`, so alerts fire on time whether the app is foregrounded,
/// backgrounded, or has been killed outright. This is also the only mechanism
/// that works on iOS, which has no long-running background timers.
class NotificationService {
  NotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static Future<NotificationService> create() async {
    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (e) {
      // Falls back to UTC; scheduling still works because every fire time is
      // converted from an absolute DateTime.
      debugPrint('Pomo Sauce: could not resolve local time zone ($e)');
    }

    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_notification'),
        iOS: DarwinInitializationSettings(
          // Permissions are requested contextually, not on cold start.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    return NotificationService(plugin);
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  IOSFlutterLocalNotificationsPlugin? get _ios =>
      _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

  // --- permissions -----------------------------------------------------

  /// Android 13+ POST_NOTIFICATIONS / iOS alert authorisation. Called the
  /// first time the user starts a timer, never on cold start.
  Future<bool> requestNotificationPermission() async {
    if (Platform.isAndroid) {
      return await _android?.requestNotificationsPermission() ?? false;
    }
    return await _ios?.requestPermissions(alert: true, sound: true, badge: true) ??
        false;
  }

  Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      return await _android?.areNotificationsEnabled() ?? true;
    }
    return true;
  }

  /// Android 12+: can we post *exact* alarms? Without this the OS may delay
  /// the alert by minutes, which is useless for a Pomodoro.
  Future<bool> canScheduleExactAlarms() async {
    if (!Platform.isAndroid) return true;
    return await _android?.canScheduleExactNotifications() ?? true;
  }

  /// Sends the user to the system "Alarms & reminders" screen.
  Future<void> requestExactAlarmPermission() async {
    if (!Platform.isAndroid) return;
    await _android?.requestExactAlarmsPermission();
  }

  // --- channels --------------------------------------------------------

  /// Android bakes sound and vibration into the channel at creation time and
  /// will not let them change afterwards, so each distinct combination gets
  /// its own channel. Only combinations the user actually picks are created.
  /// Bumped when the channel definition changes: Android freezes a channel's
  /// sound, vibration and DND-bypass at creation and will not revise them, so
  /// a new definition needs a new id.
  static const _channelRevision = 2;

  String channelIdFor(AlarmTone tone, {required bool sound, required bool vibration}) =>
      'alarm_v${_channelRevision}_${tone.rawResource}'
      '_${sound ? 's' : 'ns'}_${vibration ? 'v' : 'nv'}';

  static const _alarmVibration = <int>[0, 400, 200, 400, 200, 600];

  Future<void> ensureChannel(
    AlarmTone tone, {
    required bool sound,
    required bool vibration,
  }) async {
    if (!Platform.isAndroid) return;
    final id = channelIdFor(tone, sound: sound, vibration: vibration);
    await _android?.createNotificationChannel(
      AndroidNotificationChannel(
        id,
        sound ? 'Timer alerts - ${tone.label}' : 'Timer alerts - silent',
        description:
            'Fires when a focus session or break finishes. Pomo Sauce is '
            'unusable without it.',
        importance: Importance.max,
        playSound: sound,
        sound: sound ? RawResourceAndroidNotificationSound(tone.rawResource) : null,
        enableVibration: vibration,
        vibrationPattern: vibration ? Int64List.fromList(_alarmVibration) : null,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        // The app silences the phone during a focus interval; this is what
        // lets the user still hear the interval end. Takes effect only once
        // notification policy access has been granted.
        bypassDnd: true,
      ),
    );
  }

  NotificationDetails _alarmDetails(
    AlarmTone tone, {
    required bool sound,
    required bool vibration,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelIdFor(tone, sound: sound, vibration: vibration),
        sound ? 'Timer alerts - ${tone.label}' : 'Timer alerts - silent',
        channelDescription: 'Focus session and break completion alerts.',
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
        channelBypassDnd: true,
        playSound: sound,
        sound: sound ? RawResourceAndroidNotificationSound(tone.rawResource) : null,
        enableVibration: vibration,
        vibrationPattern: vibration ? Int64List.fromList(_alarmVibration) : null,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        icon: '@drawable/ic_notification',
        color: const Color(0xFFE9503E),
        visibility: NotificationVisibility.public,
        autoCancel: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: sound,
        presentBanner: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
        // Add the three .wav files to the Runner target in Xcode for these to
        // play; iOS falls back to the default alert sound if they are absent.
        sound: sound ? '${tone.rawResource}.wav' : null,
      ),
    );
  }

  // --- scheduling ------------------------------------------------------

  static String _titleFor(PomodoroPhase phase) => switch (phase) {
        PomodoroPhase.focus => 'Focus session complete',
        PomodoroPhase.shortBreak => 'Break over',
        PomodoroPhase.longBreak => 'Long break over',
      };

  static String _bodyFor(PomodoroPhase ended, PomodoroPhase next) {
    if (ended == PomodoroPhase.focus) {
      return next == PomodoroPhase.longBreak
          ? 'Great run. Take a proper long break.'
          : 'Nicely done. Time for a short break.';
    }
    return 'Ready when you are - back to focus.';
  }

  /// Replaces every pending alert with [alerts].
  ///
  /// Called on every user action (start, pause, skip, stop) so the OS-side
  /// schedule can never drift from what the app believes.
  Future<void> scheduleChain(
    List<ScheduledAlert> alerts, {
    required AlarmTone tone,
    required bool sound,
    required bool vibration,
  }) async {
    await cancelAllAlerts();
    if (alerts.isEmpty) return;

    await ensureChannel(tone, sound: sound, vibration: vibration);
    final details = _alarmDetails(tone, sound: sound, vibration: vibration);

    // alarmClock survives doze but needs the exact-alarm permission;
    // exactAllowWhileIdle is the graceful fallback when it is not granted.
    final mode = await canScheduleExactAlarms()
        ? AndroidScheduleMode.alarmClock
        : AndroidScheduleMode.exactAllowWhileIdle;

    final now = DateTime.now();
    var index = 0;
    for (final alert in alerts) {
      if (!alert.firesAt.isAfter(now)) continue;
      if (index >= AppConstants.maxScheduledChainLength) break;
      try {
        await _plugin.zonedSchedule(
          id: AppConstants.alarmNotificationBaseId + index,
          scheduledDate: tz.TZDateTime.from(alert.firesAt, tz.local),
          title: _titleFor(alert.phase),
          body: _bodyFor(alert.phase, alert.nextPhase),
          notificationDetails: details,
          androidScheduleMode: mode,
          payload: 'phase_end:${alert.phase.name}',
        );
        index++;
      } catch (e) {
        // Most likely the exact-alarm permission was revoked between the
        // check above and this call. Retry once inexactly rather than losing
        // the alert entirely.
        debugPrint('Pomo Sauce: exact schedule failed ($e), falling back');
        try {
          await _plugin.zonedSchedule(
            id: AppConstants.alarmNotificationBaseId + index,
            scheduledDate: tz.TZDateTime.from(alert.firesAt, tz.local),
            title: _titleFor(alert.phase),
            body: _bodyFor(alert.phase, alert.nextPhase),
            notificationDetails: details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: 'phase_end:${alert.phase.name}',
          );
          index++;
        } catch (e2) {
          // Out of our hands - the in-app alarm and the foreground-service
          // notification still cover the user while the app is alive.
          debugPrint('Pomo Sauce: could not schedule alert at all ($e2)');
        }
      }
    }
  }

  /// Cancels alerts that have *not fired yet*.
  ///
  /// Deliberately not a blanket cancel: an alert that has already been
  /// delivered is sitting in the user's shade, and the app re-schedules the
  /// chain immediately after every completion. A blanket cancel would wipe
  /// the notification seconds after it appeared.
  Future<void> cancelAllAlerts() async {
    final pending = <int>{};
    try {
      for (final request in await _plugin.pendingNotificationRequests()) {
        pending.add(request.id);
      }
    } catch (e) {
      debugPrint('Pomo Sauce: could not read pending notifications ($e)');
      return;
    }
    for (var i = 0; i < AppConstants.maxScheduledChainLength; i++) {
      final id = AppConstants.alarmNotificationBaseId + i;
      if (pending.contains(id)) await _plugin.cancel(id: id);
    }
  }

  Future<List<PendingNotificationRequest>> pending() =>
      _plugin.pendingNotificationRequests();
}
