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

    /**
     * A share that arrived before Dart was ready to hear it.
     *
     * The same cold-start ordering as a call action, and the same consequence
     * if it is dropped: someone shares a photograph, Aura opens, and the
     * photograph is not there. Held here and drained by Dart on startup.
     */
    private var pendingShare: Map<String, Any?>? = null

    private var shareChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        captureCallIntent(intent)
        captureShareIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureCallIntent(intent)
        captureShareIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.i(TAG, "configureFlutterEngine: registering $NOTIFICATIONS_CHANNEL")
        val methodChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATIONS_CHANNEL)
        channel = methodChannel

        // The session's credential store. Registered here so the handler
        // exists before TokenStore.load() asks for a token on the first
        // frame -- a missing handler there would read as "signed out".
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SecureStore.CHANNEL)
            .setMethodCallHandler { call, result ->
                SecureStore.handle(applicationContext, call, result)
            }

        // SHARE INTAKE — the single door every Android share comes through.
        // Registered here so the handler exists before Dart drains the pending
        // share on its first frame; a missing handler there would read as
        // "nothing was shared", which is the failure this whole track removes.
        val shares =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ShareIntake.CHANNEL)
        shareChannel = shares
        shares.setMethodCallHandler { call, result ->
            when (call.method) {
                // Returns at most once per share. Consuming it here is what
                // stops the same content being presented twice — which on that
                // surface would mean publishing it twice.
                "consumePendingShare" -> {
                    val pending = pendingShare
                    pendingShare = null
                    result.success(pending)
                }

                // Called once Dart has read the bytes it was given. The copies
                // live in Aura's cache and are the person's content; they are
                // not left lying there after the share is done with.
                "releaseSharedContent" -> {
                    ShareIntake.clearCache(applicationContext)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }

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
     * Hands the call over to the app — WITHOUT ending the ring, unless the
     * person actually decided something.
     *
     * This distinction is the founder finding of 2026-08-25: *"after tapping
     * notification goes to accept/decline overlay and ring dropped"*. Opening
     * a call is not answering it. Someone who taps to see who is calling is
     * still deciding, and silencing the ring at that moment is exactly the
     * behaviour that let a live call go quiet and get buried.
     *
     * So only ANSWER and DECLINE stop the ring here — they are decisions, and
     * they must take effect instantly rather than after the app has booted.
     * For `open` the ring continues, and it ends where every other outcome
     * ends: the bridge-removal choke point in AuraIncomingLiveLayer, which
     * sees accept, decline, remote cancel, another device answering, and
     * expiry alike.
     *
     * What is deliberately NOT decided here is whether to join. Founder ruling
     * 2026-08-14 — tapping a call must offer the same Accept/Decline choice a
     * foreground call gets, never join on the recipient's behalf. The action
     * is carried to Dart intact and the call layer decides.
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
        if (action == IncomingCallPresenter.ACTION_ANSWER ||
            action == IncomingCallPresenter.ACTION_DECLINE
        ) {
            IncomingCallPresenter.dismiss(this, sessionId)
        }

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
     * Take in whatever the share sheet handed over — and nothing more.
     *
     * SHARE ACQUISITION IS NOT PUBLICATION. This reads the content while the
     * intent's grant is alive and stops. It chooses no destination, resolves no
     * identity, and sends nothing. Where the share goes is decided afterwards,
     * in Aura, by the person, with the content in front of them.
     */
    private fun captureShareIntent(intent: Intent?) {
        val share = ShareIntake.extract(applicationContext, intent) ?: return

        // Consumed once. Without this, backgrounding and resuming the app
        // re-delivers the same launch intent and the share arrives again.
        intent?.action = null
        intent?.removeExtra(Intent.EXTRA_STREAM)
        intent?.removeExtra(Intent.EXTRA_TEXT)

        pendingShare = share
        // Warm start: push it straight through. The pending slot then covers
        // only the cold-start case where Dart is not listening yet.
        shareChannel?.invokeMethod("onShare", share)
        Log.i(TAG, "captureShareIntent: delivered")
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
