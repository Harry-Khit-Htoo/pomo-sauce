import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/app_database.dart';
import 'data/settings_repository.dart';
import 'providers.dart';
import 'timer/alarm_player.dart';
import 'timer/dnd_service.dart';
import 'timer/foreground_service.dart';
import 'timer/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    // Every screen is responsive; both orientations are supported on purpose
    // so the Focus Display works whichever way the phone is propped up.
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Lets the main isolate talk to the foreground-service isolate.
  FlutterForegroundTask.initCommunicationPort();
  TimerForegroundService.init();

  // If a previous run was killed while it had the phone silenced, give the
  // user their own mode back before the UI comes up.
  await DndService.reconcileAfterRestart();

  final database = await AppDatabase.open();
  final settings = await SettingsRepository.open();
  final notifications = await NotificationService.create();
  final alarm = await AlarmPlayer.create();

  runApp(
    ProviderScope(
      overrides: [
        bootstrapProvider.overrideWithValue(
          AppBootstrap(
            database: database,
            settings: settings,
            notifications: notifications,
            alarm: alarm,
          ),
        ),
      ],
      child: const TomatoFocusApp(),
    ),
  );
}
