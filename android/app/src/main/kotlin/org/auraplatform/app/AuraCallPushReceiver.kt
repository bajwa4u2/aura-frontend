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
                verifyAndRetract(context, data)
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
     * RING FIRST, THEN CHECK — and retract if the call is already over.
     *
     * The order is the decision. Holding the ring for a network round trip
     * would tax every healthy call — the overwhelming majority — with the
     * latency of the rare stale one, on exactly the path where a phone has
     * just been woken and its radio is at its slowest. So the call is
     * presented at once, unchanged, and the server's answer can only ever
     * take a ring AWAY. This is the same shape the Dart side settled on.
     *
     * [goAsync] is what makes it possible at all: a broadcast receiver's
     * process may be killed the moment `onReceive` returns, and the work here
     * is network I/O. The pending result keeps the receiver alive until
     * `finish()`, which is why every path below runs inside one `try` and
     * finishes in `finally`. Android allows roughly ten seconds before this
     * counts as an ANR, so the budget is spent explicitly: the check first,
     * the acknowledgement only with what remains.
     *
     * The notification survives the process either way — it belongs to the
     * system once posted, so a kill after `finish()` leaves the call ringing.
     */
    private fun verifyAndRetract(context: Context, data: Map<String, String>) {
        val sessionId = (data["sessionId"] ?: data["realtimeSessionId"] ?: "").trim()
        if (sessionId.isEmpty()) return

        val wokeAtMs = System.currentTimeMillis()
        // The app was not on screen (checked by the caller). Whether its
        // process existed at all is what separates a cold start from a
        // backgrounded app, and it is the distinction the 85-second ring
        // could not be attributed without.
        val appState = if (AuraApplication.hasStarted) "background" else "cold"
        val pending = goAsync()

        Thread {
            val startedAt = System.currentTimeMillis()
            try {
                val result = CallLiveness.check(context, sessionId)
                val retracted = result.verdict == CallLiveness.Verdict.NOT_LIVE
                if (retracted) {
                    // The only authority that can say this, saying it.
                    IncomingCallPresenter.dismiss(context, sessionId)
                }
                Log.i(
                    TAG,
                    "liveness: sessionId=$sessionId verdict=${result.verdict} " +
                        "reason=${result.reason} retracted=$retracted " +
                        "ms=${System.currentTimeMillis() - startedAt}",
                )

                val spent = (System.currentTimeMillis() - startedAt).toInt()
                CallLiveness.reportPresented(
                    context = context,
                    sessionId = sessionId,
                    appState = appState,
                    wokeAtMs = wokeAtMs,
                    detail = "native ring ($appState); liveness=${result.verdict}:" +
                        "${result.reason}" + if (retracted) "; ring retracted" else "",
                    budgetMs = (ASYNC_BUDGET_MS - spent).coerceAtLeast(0),
                )
            } catch (t: Throwable) {
                // Never let the ring path take the process down with it.
                Log.w(TAG, "liveness failed: ${t.javaClass.simpleName}")
            } finally {
                pending.finish()
            }
        }.start()
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

        /**
         * What [goAsync] may spend in total. Android's broadcast timeout is
         * ~10s in the foreground queue and this is a high-priority call push;
         * 7s leaves headroom so a slow network costs a late acknowledgement
         * rather than an ANR.
         */
        private const val ASYNC_BUDGET_MS = 7_000

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
