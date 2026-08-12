package org.auraplatform.app

import android.app.NotificationManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATIONS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "cancelCallNotifications" -> {
                        cancelCallNotifications()
                        result.success(null)
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
    private fun cancelCallNotifications() {
        val manager = getSystemService(NotificationManager::class.java) ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            for (entry in manager.activeNotifications) {
                if (entry.notification.channelId == AuraApplication.CHANNEL_CALLS) {
                    manager.cancel(entry.id)
                }
            }
        } else {
            // Pre-M has no per-notification channel introspection API.
            // Cancelling everything from this app is preferable to leaving
            // a ringing call notification stuck indefinitely.
            manager.cancelAll()
        }
    }

    companion object {
        private const val NOTIFICATIONS_CHANNEL = "org.auraplatform.app/notifications"
    }
}
