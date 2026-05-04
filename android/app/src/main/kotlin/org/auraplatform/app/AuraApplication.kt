package org.auraplatform.app

import android.app.Application
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build

class AuraApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        registerNotificationChannels()
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
        const val CHANNEL_CALLS = "aura_calls"
        const val CHANNEL_MESSAGES = "aura_messages"
        const val CHANNEL_UPDATES = "aura_updates"
    }
}
