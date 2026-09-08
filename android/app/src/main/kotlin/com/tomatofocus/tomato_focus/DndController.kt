package com.tomatofocus.tomato_focus

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Do Not Disturb control, used only to silence the phone for the length of a
 * focus session.
 *
 * ACCESS_NOTIFICATION_POLICY is a restricted permission under Play policy, so
 * this class is deliberately narrow:
 *
 *  - It can only move the phone into priority mode or put back exactly what
 *    was there before. It cannot set arbitrary filters.
 *  - [previousFilter] remembers the user's own mode at the moment we changed
 *    it, so [restore] returns the device to where the user left it rather
 *    than assuming "all".
 *  - Nothing here runs until the in-app explainer has been shown and the user
 *    has granted policy access from system settings.
 */
class DndController(private val context: Context) {

    companion object {
        const val CHANNEL = "app.tomatofocus/dnd"
        private const val PREFS = "tomato_focus_dnd"
        private const val KEY_PREVIOUS = "previous_filter"
        private const val NONE = -1
    }

    private val prefs
        get() = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /**
     * The user's own filter is written to disk the moment we change it.
     *
     * A killed process never runs onDestroy, so without this a crash or a
     * force-stop mid-session would strand the phone in Do Not Disturb with no
     * visible cause - the exact "changed my settings and left" behaviour the
     * policy exists to prevent. [reconcile] hands it back on next launch.
     */
    private fun rememberPrevious(filter: Int) {
        previousFilter = filter
        prefs.edit().putInt(KEY_PREVIOUS, filter).apply()
    }

    private fun forgetPrevious() {
        previousFilter = null
        prefs.edit().remove(KEY_PREVIOUS).apply()
    }

    private val notificationManager: NotificationManager
        get() = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    /** Non-null only while we are the ones holding the phone in DND. */
    private var previousFilter: Int? = null

    private fun hasPolicyAccess(): Boolean =
        notificationManager.isNotificationPolicyAccessGranted

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isPolicyAccessGranted" -> result.success(hasPolicyAccess())

            "openPolicyAccessSettings" -> {
                context.startActivity(
                    Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
                result.success(null)
            }

            "currentFilter" -> result.success(
                if (hasPolicyAccess()) notificationManager.currentInterruptionFilter else -1
            )

            // Enter priority mode - not ALARMS_ONLY, so a notification channel
            // with bypassDnd can still be heard. The timer's completion alert
            // is exactly that channel.
            "enable" -> {
                if (!hasPolicyAccess()) {
                    result.success(false)
                    return
                }
                if (previousFilter == null) {
                    rememberPrevious(notificationManager.currentInterruptionFilter)
                }
                runCatching {
                    notificationManager.setInterruptionFilter(
                        NotificationManager.INTERRUPTION_FILTER_PRIORITY
                    )
                }.onFailure {
                    forgetPrevious()
                    result.success(false)
                    return
                }
                result.success(true)
            }

            // Put back whatever the user had. Never blindly set "all".
            "restore" -> {
                val previous = previousFilter ?: prefs.getInt(KEY_PREVIOUS, NONE)
                    .takeIf { it != NONE }
                forgetPrevious()
                if (!hasPolicyAccess() || previous == null) {
                    result.success(false)
                    return
                }
                runCatching {
                    notificationManager.setInterruptionFilter(previous)
                }.onFailure {
                    result.success(false)
                    return
                }
                result.success(true)
            }

            /** True when this app is the one currently holding DND on. */
            "isHoldingDnd" -> result.success(
                previousFilter != null || prefs.getInt(KEY_PREVIOUS, NONE) != NONE
            )

            // Called once at startup: if a previous run died while holding
            // DND, give the user their mode back before anything else runs.
            // Safe to call always - a still-running session simply re-enables.
            "reconcile" -> {
                val stranded = prefs.getInt(KEY_PREVIOUS, NONE)
                if (stranded == NONE) {
                    result.success(false)
                    return
                }
                forgetPrevious()
                if (!hasPolicyAccess()) {
                    result.success(false)
                    return
                }
                runCatching { notificationManager.setInterruptionFilter(stranded) }
                result.success(true)
            }

            else -> result.notImplemented()
        }
    }

    /**
     * Safety net: if the activity goes away while we are holding DND, hand the
     * phone back rather than leaving the user silenced.
     */
    fun releaseIfHeld() {
        val previous = previousFilter ?: return
        forgetPrevious()
        if (!hasPolicyAccess()) return
        runCatching { notificationManager.setInterruptionFilter(previous) }
    }
}
