package org.auraplatform.app

import android.app.Activity
import android.app.Application
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle

class AuraApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        registerNotificationChannels()
        trackForeground()
    }

    /**
     * Whether any Aura activity is currently resumed.
     *
     * [AuraCallPushReceiver] needs this to decide who presents an incoming
     * call. In the foreground the Dart overlay is already on screen and runs
     * its own alert; presenting natively as well would ring one call twice.
     * Counting resumed activities (rather than asking ActivityManager for
     * process importance) is the reading that matches what the person can
     * actually see.
     */
    private fun trackForeground() {
        registerActivityLifecycleCallbacks(object : ActivityLifecycleCallbacks {
            override fun onActivityResumed(activity: Activity) {
                resumedActivities++
                isForeground = true
            }

            override fun onActivityPaused(activity: Activity) {
                resumedActivities = (resumedActivities - 1).coerceAtLeast(0)
                isForeground = resumedActivities > 0
            }

            override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) = Unit
            override fun onActivityStarted(activity: Activity) = Unit
            override fun onActivityStopped(activity: Activity) = Unit
            override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) = Unit
            override fun onActivityDestroyed(activity: Activity) = Unit
        })
    }

    private fun registerNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = getSystemService(NotificationManager::class.java) ?: return

        val callsChannel = NotificationChannel(
            CHANNEL_CALLS,
            "Incoming calls",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Ringing notifications for incoming live calls."
            enableVibration(true)
            enableLights(true)
            setBypassDnd(true)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setShowBadge(true)
            val audioAttrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            setSound(
                RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE),
                audioAttrs,
            )
        }

        val messagesChannel = NotificationChannel(
            CHANNEL_MESSAGES,
            "Messages",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "New messages and replies."
            enableVibration(true)
            lockscreenVisibility = Notification.VISIBILITY_PRIVATE
        }

        val updatesChannel = NotificationChannel(
            CHANNEL_UPDATES,
            "Updates",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "General Aura activity and announcements."
        }

        manager.createNotificationChannel(callsChannel)
        manager.createNotificationChannel(messagesChannel)
        manager.createNotificationChannel(updatesChannel)
    }

    companion object {
        /** See [trackForeground]. Read from the FCM broadcast receiver. */
        @Volatile
        @JvmStatic
        var isForeground: Boolean = false
            private set

        private var resumedActivities = 0

        const val CHANNEL_CALLS = "aura_calls"
        const val CHANNEL_MESSAGES = "aura_messages"
        const val CHANNEL_UPDATES = "aura_updates"
    }
}
