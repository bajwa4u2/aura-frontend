package org.auraplatform.app

import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.Person

/**
 * A CALL IS NOT A NOTIFICATION.
 *
 * Founder ruling, 2026-08-25: "ring tied with notification — notification
 * missed or tapped its gone and call burried", and "notification naturally a
 * short tenure so if miss tap call burried immediately".
 *
 * That was an accurate description of what the app did. Incoming calls were
 * delivered as an ordinary FCM `notification` message, drawn by the Firebase
 * SDK itself, on a channel whose CHANNEL SOUND happened to be the system
 * ringtone. Nothing in the app built an incoming-call surface at all, and
 * every symptom followed from that single fact:
 *
 *  * the ring was a property of the notification, so dismissing the
 *    notification silenced a call that was still ringing on the other side;
 *  * tapping it auto-cancelled the notification, so the ring stopped while
 *    the person was still deciding whether to answer;
 *  * a notification has a short, self-dismissing tenure, and the call
 *    inherited it;
 *  * an SDK-drawn notification cannot carry a full-screen intent, so a call
 *    could never present itself AS a call.
 *
 * This presenter takes ownership of that surface. The ring's lifetime is now
 * the CALL's ring window, and it ends only for a reason a call actually ends:
 * answered, declined, cancelled by the caller, or the window expired.
 *
 * Three flags carry that, and each one is load-bearing:
 *
 *  * [Notification.FLAG_INSISTENT] — the ring REPEATS until the notification
 *    is cancelled. Without it Android plays the channel sound once and the
 *    "ring" is a single chime.
 *  * ongoing / [Notification.FLAG_NO_CLEAR] — the call cannot be swiped away.
 *  * `setTimeoutAfter(window)` — and it DOES end on its own, so an unanswered
 *    call can never leave a device ringing indefinitely.
 */
object IncomingCallPresenter {
    private const val TAG = "AuraIncomingCall"

    private const val NOTIFICATION_ID = 4471

    /** Ring windows outside this range are not trusted; see [resolveWindowMs]. */
    private const val MIN_WINDOW_MS = 15_000L
    private const val MAX_WINDOW_MS = 90_000L
    private const val DEFAULT_WINDOW_MS = 45_000L

    const val EXTRA_CALL_ACTION = "auraCallAction"
    const val EXTRA_CALL_DATA = "auraCallData"
    const val ACTION_ANSWER = "answer"
    const val ACTION_DECLINE = "decline"
    const val ACTION_OPEN = "open"

    fun present(context: Context, data: Map<String, String>) {
        val sessionId = data.firstNonBlank("sessionId", "realtimeSessionId")
        if (sessionId.isEmpty()) {
            Log.w(TAG, "present: refused — call push carried no sessionId")
            return
        }

        val manager = context.getSystemService(NotificationManager::class.java) ?: return

        // The caller identity the push already carries flat at top level
        // (measured 2026-08-25). Nothing is invented here: when identity is
        // genuinely absent the neutral label is the honest answer, and the
        // repair for that belongs upstream at the canonical actor model, not
        // in a per-surface fallback.
        val callerName = data
            .firstNonBlank("callerDisplayName", "callerHandle")
            .ifEmpty { "Incoming call" }
        val windowMs = resolveWindowMs(data["expiresAt"])
        val video = isVideo(data)

        val person = Person.Builder()
            .setName(callerName)
            .setKey(data.firstNonBlank("callerUserId", "actorUserId").ifEmpty { sessionId })
            .setImportant(true)
            .build()

        val answer = actionIntent(context, ACTION_ANSWER, sessionId, data)
        val decline = actionIntent(context, ACTION_DECLINE, sessionId, data)
        val open = actionIntent(context, ACTION_OPEN, sessionId, data)

        val builder = NotificationCompat.Builder(context, AuraApplication.CHANNEL_CALLS)
            .setSmallIcon(android.R.drawable.sym_call_incoming)
            .setContentTitle(callerName)
            .setContentText(if (video) "Incoming video call" else "Incoming call")
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setOnlyAlertOnce(false)
            .setShowWhen(true)
            .setTimeoutAfter(windowMs)
            .setContentIntent(open)
            // `true` = a genuine incoming-call interruption. Where the
            // permission is granted the call presents full-screen over the
            // lock screen; where it is not, Android degrades this to a
            // heads-up notification and the ring still behaves correctly,
            // because the ring no longer depends on how the call is drawn.
            .setFullScreenIntent(open, true)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setStyle(
                NotificationCompat.CallStyle.forIncomingCall(person, decline, answer)
            )
        } else {
            // CallStyle is API 31+. Below it the same two choices are ordinary
            // actions; the call still rings and still cannot be swiped away.
            builder
                .addAction(0, "Decline", decline)
                .addAction(0, "Answer", answer)
        }

        val notification = builder.build()
        // THE RING ITSELF.
        notification.flags = notification.flags or
            Notification.FLAG_INSISTENT or
            Notification.FLAG_ONGOING_EVENT or
            Notification.FLAG_NO_CLEAR

        manager.notify(sessionId, NOTIFICATION_ID, notification)
        Log.i(
            TAG,
            "present: sessionId=$sessionId caller=$callerName windowMs=$windowMs video=$video",
        )
    }

    /**
     * Ends the ring. Every real outcome routes here — the caller cancelled,
     * the call was answered or declined on this device or another one, the
     * ring window closed, or the app came to the foreground and took over
     * presentation itself.
     */
    fun dismiss(context: Context, sessionId: String) {
        if (sessionId.isBlank()) {
            dismissAll(context)
            return
        }
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        manager.cancel(sessionId, NOTIFICATION_ID)
        Log.i(TAG, "dismiss: sessionId=$sessionId")
    }

    fun dismissAll(context: Context): Int {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return 0
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            manager.cancelAll()
            return -1
        }
        var cancelled = 0
        for (entry in manager.activeNotifications) {
            if (entry.notification.channelId == AuraApplication.CHANNEL_CALLS) {
                manager.cancel(entry.tag, entry.id)
                cancelled++
            }
        }
        Log.i(TAG, "dismissAll: cancelled=$cancelled")
        return cancelled
    }

    /**
     * The ring window belongs to the CALL, taken from the invite's own expiry,
     * so the device stops ringing exactly when the invite stops being
     * answerable. A missing or implausible value falls back to a bounded
     * default rather than ringing forever — or not at all.
     */
    private fun resolveWindowMs(expiresAt: String?): Long {
        val raw = expiresAt?.trim().orEmpty()
        if (raw.isEmpty()) return DEFAULT_WINDOW_MS
        val expiryMs = parseInstantMs(raw) ?: return DEFAULT_WINDOW_MS
        val remaining = expiryMs - System.currentTimeMillis()
        return remaining.coerceIn(MIN_WINDOW_MS, MAX_WINDOW_MS)
    }

    private fun parseInstantMs(raw: String): Long? {
        raw.toLongOrNull()?.let {
            // Tolerate both seconds and milliseconds since epoch.
            return if (it < 1_000_000_000_000L) it * 1000 else it
        }
        return try {
            java.time.Instant.parse(raw).toEpochMilli()
        } catch (error: Exception) {
            null
        }
    }

    private fun isVideo(data: Map<String, String>): Boolean =
        data.firstNonBlank("mediaMode", "sessionType", "mode", "callKind")
            .equals("video", ignoreCase = true)

    private fun actionIntent(
        context: Context,
        action: String,
        sessionId: String,
        data: Map<String, String>,
    ): PendingIntent {
        // ACTIVITY intents, deliberately — not broadcasts. A broadcast
        // receiver that then called startActivity would be a background
        // activity start, which Android 10+ blocks; and the full-screen
        // intent must be an activity by definition. Every one of the three
        // therefore lands in MainActivity, which stops the ring the moment it
        // takes over and hands the action to the Dart call layer that owns
        // accept/decline.
        val intent = Intent(context, MainActivity::class.java).apply {
            this.action = "org.auraplatform.app.CALL_" + action.uppercase()
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra(EXTRA_CALL_ACTION, action)
            putExtra("sessionId", sessionId)
            putExtra(EXTRA_CALL_DATA, HashMap(data))
        }
        return PendingIntent.getActivity(
            context,
            (sessionId + action).hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun Map<String, String>.firstNonBlank(vararg keys: String): String {
        for (key in keys) {
            val value = this[key]?.trim().orEmpty()
            if (value.isNotEmpty() && value != "null") return value
        }
        return ""
    }
}
