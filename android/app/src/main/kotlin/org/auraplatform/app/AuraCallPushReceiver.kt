package org.auraplatform.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Intercepts CALL pushes so an incoming call can be presented AS A CALL.
 *
 * ## Why a receiver, and not a FirebaseMessagingService
 *
 * The obvious move — subclassing `FirebaseMessagingService` — would have
 * broken the app. FCM binds exactly ONE service registered for
 * `com.google.firebase.MESSAGING_EVENT`, and that one is already claimed by
 * `io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService`.
 * Taking it would have silently killed every Dart-side message handler:
 * `FirebaseMessaging.onMessage`, the background handler, token refresh.
 *
 * The plugin, however, also registers a plain `BroadcastReceiver` on
 * `com.google.android.c2dm.intent.RECEIVE` — and a broadcast reaches EVERY
 * registered receiver. So this receiver sits alongside the plugin's rather
 * than in front of it: Dart keeps receiving everything it received before,
 * and native call presentation is added next to it, not instead of it.
 *
 * ## What it does
 *
 * Only two message types are claimed here, and only the parts of them that
 * concern ringing:
 *
 *  * `CALL_RINGING` — present the call ([IncomingCallPresenter.present]);
 *  * `CALL_CANCELLED` / `CALL_MISSED` — stop ringing.
 *
 * Everything else is left entirely alone.
 *
 * When the app is in the FOREGROUND nothing is presented natively: the Dart
 * incoming-call overlay is already on screen and already runs its own alert,
 * and two ringing surfaces for one call is the duplication this chapter has
 * been removing everywhere else.
 */
class AuraCallPushReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val data = readData(intent) ?: return
        if (data.isEmpty()) return

        when (data["type"]?.trim()?.uppercase()) {
            TYPE_RINGING -> {
                if (AuraApplication.isForeground) {
                    Log.i(TAG, "ringing: app foreground — Dart overlay owns presentation")
                    return
                }
                IncomingCallPresenter.present(context, data)
            }

            TYPE_CANCELLED, TYPE_MISSED -> {
                val sessionId = (data["sessionId"] ?: data["realtimeSessionId"] ?: "").trim()
                Log.i(TAG, "cancel: sessionId=$sessionId")
                IncomingCallPresenter.dismiss(context, sessionId)
            }

            else -> Unit
        }
    }

    /**
     * The message's data payload, read straight from the broadcast extras.
     *
     * Deliberately NOT via `RemoteMessage`: that class lives in
     * firebase-messaging, which reaches this app only as a transitive
     * dependency of the Flutter plugin and is not on the app module's compile
     * classpath. Pulling it in directly would pin a Firebase version here that
     * could then drift from the plugin's own.
     *
     * The transport is plain string extras, so the only work is separating the
     * app's data keys from FCM's own envelope — the `google.*` / `gcm.*`
     * namespaces and the handful of reserved top-level names.
     */
    private fun readData(intent: Intent): Map<String, String>? {
        val extras = intent.extras ?: return null
        val data = HashMap<String, String>()
        for (key in extras.keySet()) {
            if (key.startsWith("google.") || key.startsWith("gcm.")) continue
            if (key in RESERVED) continue
            val value = extras.get(key) as? String ?: continue
            data[key] = value
        }
        return data
    }

    companion object {
        private const val TAG = "AuraCallPush"

        /** FCM envelope fields that are not part of the app's data payload. */
        private val RESERVED = setOf(
            "from",
            "to",
            "collapse_key",
            "message_type",
            "message_id",
            "sent_time",
            "ttl",
            "priority",
            "original_priority",
        )
        private const val TYPE_RINGING = "CALL_RINGING"
        private const val TYPE_CANCELLED = "CALL_CANCELLED"
        private const val TYPE_MISSED = "CALL_MISSED"
    }
}
