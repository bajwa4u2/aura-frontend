package org.auraplatform.app

import android.app.KeyguardManager
import android.app.NotificationManager
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var channel: MethodChannel? = null

    /**
     * A call action that arrived before Dart was ready to hear it.
     *
     * Cold-start ordering: tapping Answer on a ringing notification launches
     * this activity, and the Flutter engine is not attached yet. Dropping the
     * action there would send the person into an app that has forgotten the
     * call they just answered — the "call buried" failure in a new costume.
     * So it is held here and drained by Dart on startup.
     */
    private var pendingCallAction: Map<String, Any?>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        captureCallIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureCallIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.i(TAG, "configureFlutterEngine: registering $NOTIFICATIONS_CHANNEL")
        val methodChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATIONS_CHANNEL)
        channel = methodChannel
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "cancelCallNotifications" -> result.success(cancelCallNotifications())

                // Drained by the Dart call layer at startup and on resume. It
                // returns at most once per action — consuming it here is what
                // stops an answered call from being re-answered on the next
                // resume.
                "consumePendingCallAction" -> {
                    val pending = pendingCallAction
                    pendingCallAction = null
                    result.success(pending)
                }

                // Android 14+ does not grant USE_FULL_SCREEN_INTENT to every
                // app that asks. Reported honestly rather than assumed, so the
                // app can tell the difference between "the call presented
                // full-screen" and "Android degraded it to a heads-up".
                "canUseFullScreenIntent" -> result.success(canUseFullScreenIntent())

                else -> result.notImplemented()
            }
        }
    }

    /**
     * Takes over from the ring.
     *
     * Reaching this activity means the person acted on the call — answered,
     * declined, or opened it. The ring has done its job, so it stops HERE, at
     * the moment presentation transfers to the app, rather than being left to
     * whatever Dart does next.
     *
     * Note what is deliberately NOT decided here: whether to join. Founder
     * ruling 2026-08-14 — tapping a call must offer the same Accept/Decline
     * choice a foreground call gets, never join on the recipient's behalf. So
     * the action is carried to Dart intact and the call layer decides:
     * `answer`/`decline` are explicit acts on a call control and are honoured;
     * `open` (the notification body, and the full-screen intent) lands on the
     * Accept/Decline overlay.
     */
    private fun captureCallIntent(intent: Intent?) {
        val action = intent?.getStringExtra(IncomingCallPresenter.EXTRA_CALL_ACTION)
            ?.trim()
            .orEmpty()
        if (action.isEmpty()) return

        val sessionId = intent?.getStringExtra("sessionId")?.trim().orEmpty()

        @Suppress("UNCHECKED_CAST")
        val data = (intent?.getSerializableExtra(IncomingCallPresenter.EXTRA_CALL_DATA)
            as? HashMap<String, String>) ?: HashMap()

        showOverLockScreen()
        IncomingCallPresenter.dismiss(this, sessionId)

        val payload = mapOf(
            "action" to action,
            "sessionId" to sessionId,
            "data" to data,
        )
        pendingCallAction = payload
        // If the engine is already up (warm start / app already running) push
        // it straight through; the pending slot then covers only cold start.
        channel?.invokeMethod("onCallAction", payload)
        Log.i(TAG, "captureCallIntent: action=$action sessionId=$sessionId")
    }

    /**
     * A call answered from the lock screen must actually be visible. Applied
     * only when arriving through a call intent — an app that always shows over
     * the keyguard would be a security regression, not a feature.
     */
    private fun showOverLockScreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguard = getSystemService(KeyguardManager::class.java)
            keyguard?.requestDismissKeyguard(this, null)
        }
    }

    private fun canUseFullScreenIntent(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return true
        val manager = getSystemService(NotificationManager::class.java) ?: return false
        return manager.canUseFullScreenIntent()
    }

    // 2026-08-14 — the aura_calls channel uses USAGE_NOTIFICATION_RINGTONE
    // (see AuraApplication.registerNotificationChannels), which Android
    // treats as a genuine ringtone-style alert. Since 2026-08-25 the app
    // builds that ringing notification itself (IncomingCallPresenter) with
    // FLAG_INSISTENT, so the ring repeats for the call's whole ring window
    // and this cancel is the single act that ends it.
    private fun cancelCallNotifications(): Int {
        val cancelled = IncomingCallPresenter.dismissAll(this)
        Log.i(TAG, "cancelCallNotifications: cancelled=$cancelled")
        return cancelled
    }

    companion object {
        private const val TAG = "AuraNotifications"
        private const val NOTIFICATIONS_CHANNEL = "org.auraplatform.app/notifications"
    }
}
