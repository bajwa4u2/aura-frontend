package org.auraplatform.app

import android.app.NotificationManager
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.i(TAG, "configureFlutterEngine: registering $NOTIFICATIONS_CHANNEL")
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATIONS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "cancelCallNotifications" -> {
                        val count = cancelCallNotifications()
                        result.success(count)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // 2026-08-14 — the aura_calls channel uses USAGE_NOTIFICATION_RINGTONE
    // (see AuraApplication.registerNotificationChannels), which Android
    // treats as a genuine ringtone-style alert, not a one-shot notification
    // sound: it keeps sounding until the notification is explicitly
    // cancelled. Nothing previously cancelled it (no
    // flutter_local_notifications, no custom FirebaseMessagingService), so
    // the ring could keep going well after the user had already tapped the
    // notification or accepted/declined the call from within the app.
    //
    // Diagnostic logging added deliberately (not left permanently) to prove
    // exactly what's happening rather than guess: whether this method runs
    // at all, what channel every currently-active notification actually
    // reports, and how many this cancels.
    private fun cancelCallNotifications(): Int {
        val manager = getSystemService(NotificationManager::class.java)
        if (manager == null) {
            Log.w(TAG, "cancelCallNotifications: no NotificationManager")
            return 0
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            Log.i(TAG, "cancelCallNotifications: pre-M, cancelAll()")
            manager.cancelAll()
            return -1
        }
        val active = manager.activeNotifications
        Log.i(TAG, "cancelCallNotifications: ${active.size} active notification(s)")
        var cancelled = 0
        for (entry in active) {
            val channelId = entry.notification.channelId
            Log.i(TAG, "  id=${entry.id} tag=${entry.tag} channelId=$channelId")
            if (channelId == AuraApplication.CHANNEL_CALLS) {
                manager.cancel(entry.tag, entry.id)
                cancelled++
            }
        }
        Log.i(TAG, "cancelCallNotifications: cancelled=$cancelled")
        return cancelled
    }

    companion object {
        private const val TAG = "AuraNotifications"
        private const val NOTIFICATIONS_CHANNEL = "org.auraplatform.app/notifications"
    }
}
