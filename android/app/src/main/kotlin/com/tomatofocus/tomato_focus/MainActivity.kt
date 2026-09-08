package com.tomatofocus.tomato_focus

import android.app.AlarmManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the Flutter engine and bridges the parts of exact-alarm handling that
 * have no plugin coverage.
 *
 * The important one is ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED.
 * On Android 12+ the user (or the system) can revoke "Alarms & reminders" at
 * any moment, and doing so silently drops every exact alarm the app had
 * queued. The broadcast is only delivered to a running app and cannot be
 * declared in the manifest, so it is registered here at runtime and forwarded
 * to Dart, which immediately re-schedules the pending interval chain.
 */
class MainActivity : FlutterActivity() {

    private companion object {
        const val METHOD_CHANNEL = "app.tomatofocus/exact_alarm"
        const val EVENT_CHANNEL = "app.tomatofocus/exact_alarm_events"
    }

    private var permissionReceiver: BroadcastReceiver? = null
    private val dnd by lazy { DndController(applicationContext) }

    private val alarmManager: AlarmManager
        get() = getSystemService(Context.ALARM_SERVICE) as AlarmManager

    private fun canScheduleExactAlarms(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            alarmManager.canScheduleExactAlarms()
        } else {
            // Before Android 12 exact alarms needed no special access.
            true
        }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DndController.CHANNEL)
            .setMethodCallHandler { call, result -> dnd.handle(call, result) }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canScheduleExactAlarms" -> result.success(canScheduleExactAlarms())

                    "areAlarmsAllowed" -> result.success(canScheduleExactAlarms())

                    "openExactAlarmSettings" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            // Deep link straight to this app's entry rather than
                            // dumping the user in the global list.
                            val intent = Intent(
                                Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                                Uri.parse("package:$packageName")
                            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            runCatching { startActivity(intent) }.onFailure {
                                startActivity(
                                    Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                )
                            }
                        }
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return

                    val receiver = object : BroadcastReceiver() {
                        override fun onReceive(context: Context?, intent: Intent?) {
                            events?.success(canScheduleExactAlarms())
                        }
                    }
                    permissionReceiver = receiver

                    val filter = IntentFilter(
                        AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED
                    )
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
                    } else {
                        @Suppress("UnspecifiedRegisterReceiverFlag")
                        registerReceiver(receiver, filter)
                    }

                    // Emit the current value so Dart starts in a known state.
                    events?.success(canScheduleExactAlarms())
                }

                override fun onCancel(arguments: Any?) = unregisterPermissionReceiver()
            })
    }

    private fun unregisterPermissionReceiver() {
        permissionReceiver?.let { runCatching { unregisterReceiver(it) } }
        permissionReceiver = null
    }

    override fun onDestroy() {
        unregisterPermissionReceiver()
        // Never leave the user silenced because our process went away.
        dnd.releaseIfHeld()
        super.onDestroy()
    }
}
