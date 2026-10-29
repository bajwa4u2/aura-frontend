package org.auraplatform.app

import android.Manifest
import android.app.Notification
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * A CALL THAT SURVIVES THE HOME BUTTON.
 *
 * ── THE DEFECT ───────────────────────────────────────────────────────────
 *
 * Measured, 2026-09-09 (`2026-09-09-thread-call-frozen-successful-state.md`):
 *
 *     03:13:13  HOME pressed
 *     03:13:56  Pixel transport CLOSED reason=EXPLICIT_LEAVE, tracks ENDED
 *     03:13:57  resumed
 *     03:17:26  call ended — NO SECOND TRANSPORT EVER CREATED
 *
 * Neither person could tell: the Pixel kept showing "Connected · 2 · 02:52"
 * while the other end painted its last frame forever. A frozen still reads as
 * a working call.
 *
 * Part of that chain was a lifecycle bug in the Dart transport (a detach that
 * stated no reason, and a recovery that then judged the torn-down stage
 * ineligible), repaired separately. This file addresses the other half, the
 * part no amount of Dart can fix: **from Android 14 an app with no foreground
 * service of the right type loses microphone and camera the moment it stops
 * being the app on screen.**
 *
 * ── WHY THE PERMISSIONS WERE REMOVED BEFORE, AND WHY THEY COME BACK NOW ──
 *
 * `FOREGROUND_SERVICE_*` permissions were declared in August and removed
 * again, correctly: nothing ever called `startForeground`, so they granted
 * nothing while obliging Aura to answer Play for a service it did not run.
 * The manifest's own comment set the condition for their return — "a real
 * foreground service with the matching type — a feature, implemented and
 * proven — and these permissions come back WITH it, not before it." This is
 * that service, and the permissions return in the same commit.
 *
 * ── WHAT IT DELIBERATELY IS NOT ──────────────────────────────────────────
 *
 * It holds no call state and makes no call decisions. It starts when a call
 * becomes active, it stops when that call is over, and everything it shows
 * comes from the call it was given. A second opinion about whether a call is
 * live is the last thing this system needs.
 *
 * It does not replace [AuraTelecom]: Telecom is how the call joins the
 * system's call stack (audio focus, routing, concurrency with the dialer).
 * Telecom is also allowed to REFUSE a call, and the Aura call carries on when
 * it does — which is exactly when this service is the only thing keeping
 * capture alive.
 *
 * ── IT MUST NOT OUTLIVE THE CALL ─────────────────────────────────────────
 *
 * Three independent stops, because a service that outlives its call holds the
 * microphone hostage:
 *
 *  * [ACTION_STOP] from Dart when the call ends, for any reason;
 *  * a stop for a DIFFERENT session supersedes rather than being ignored, so
 *    a stale stop cannot strand a live call and a live stop cannot be lost;
 *  * `onTaskRemoved` — the person swiped the app away, and a call they can no
 *    longer see is not a call.
 */
class AuraCallService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val sessionId = intent.getStringExtra(EXTRA_SESSION_ID).orEmpty()
                if (sessionId.isEmpty()) {
                    // Nothing to keep alive, and a foreground service with no
                    // call behind it is the thing this must never become.
                    stopSelf(startId)
                    return START_NOT_STICKY
                }
                val video = intent.getBooleanExtra(EXTRA_VIDEO, false)
                val title = intent.getStringExtra(EXTRA_TITLE).orEmpty()
                // ALREADY DOING EXACTLY THIS. A repeat for the same call and
                // type re-ran startForeground every time it arrived (the call
                // screen asked on every rebuild), and a background refusal of
                // a repeat stopped protection that was already working
                // (2026-10-22 audit).
                if (sessionId == activeSessionId && video == activeVideo) {
                    return START_NOT_STICKY
                }
                activeSessionId = sessionId
                startInForeground(sessionId, title, video)
            }

            ACTION_STOP -> {
                val sessionId = intent.getStringExtra(EXTRA_SESSION_ID).orEmpty()
                // An empty session id means "stop whatever is running" — the
                // teardown path that cannot name the call it is ending.
                if (sessionId.isEmpty() || sessionId == activeSessionId) {
                    activeSessionId = null
                    activeVideo = false
                    stopForegroundCompat()
                    stopSelf()
                    // The call is over: Aura stops being allowed above the
                    // lock screen now, not when it next leaves the screen.
                    MainActivity.onCallEnded()
                } else {
                    Log.i(TAG, "stop ignored: for $sessionId, running $activeSessionId")
                }
            }

            else -> {
                // Restarted by the system with no intent: there is no call to
                // represent, so do not invent one.
                stopSelf(startId)
                return START_NOT_STICKY
            }
        }
        // NOT sticky: if Android kills this process the call is gone with it,
        // and a service restarted without its call would show a notification
        // for a conversation that ended.
        return START_NOT_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        activeSessionId = null
        activeVideo = false
        stopForegroundCompat()
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }

    private fun startInForeground(sessionId: String, title: String, video: Boolean) {
        val open = PendingIntent.getActivity(
            this,
            sessionId.hashCode(),
            Intent(this, MainActivity::class.java).apply {
                action = "org.auraplatform.app.CALL_OPEN"
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra(IncomingCallPresenter.EXTRA_CALL_ACTION, IncomingCallPresenter.ACTION_OPEN)
                putExtra("sessionId", sessionId)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification: Notification = NotificationCompat.Builder(this, AuraApplication.CHANNEL_CALLS)
            .setSmallIcon(android.R.drawable.sym_call_incoming)
            .setContentTitle(title.ifEmpty { "Aura call" })
            .setContentText(if (video) "Video call in progress" else "Call in progress")
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            // SILENT, unlike the ring on this same channel. An in-call
            // notification that alerts would ring at a person mid-sentence.
            .setSilent(true)
            .setContentIntent(open)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                // THE TYPE IS THE PERMISSION. Declaring microphone without
                // using it, or using the camera under a microphone-only type,
                // is what Android 14 refuses — so the type states exactly what
                // this call is doing.
                var type = ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
                if (video) type = type or ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA
                startForeground(NOTIFICATION_ID, notification, type)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            activeVideo = video
            Log.i(TAG, "foreground: sessionId=$sessionId video=$video")
        } catch (t: Throwable) {
            // THE CAMERA TYPE CAN BE REFUSED WHERE THE MICROPHONE IS NOT —
            // camera permission denied, or a camera start from the background.
            // That used to stop the service entirely and take the microphone's
            // protection with it. Fall back to microphone only.
            if (video && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                try {
                    startForeground(
                        NOTIFICATION_ID,
                        notification,
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE,
                    )
                    activeVideo = false
                    Log.w(TAG, "camera type refused, microphone kept: ${t.message}")
                    return
                } catch (micRefused: Throwable) {
                    Log.w(TAG, "microphone type refused too: ${micRefused.message}")
                }
            }
            // A refused foreground start must not take the call with it. The
            // call continues exactly as it did before this service existed —
            // it simply loses the background protection.
            Log.w(TAG, "startForeground refused: ${t.message}")
            activeSessionId = null
            activeVideo = false
            stopSelf()
        }
    }

    @Suppress("DEPRECATION")
    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            stopForeground(true)
        }
    }

    companion object {
        private const val TAG = "AuraCallService"
        private const val NOTIFICATION_ID = 4472

        const val CHANNEL = "org.auraplatform.app/call_service"

        private const val ACTION_START = "org.auraplatform.app.CALL_SERVICE_START"
        private const val ACTION_STOP = "org.auraplatform.app.CALL_SERVICE_STOP"
        private const val EXTRA_SESSION_ID = "sessionId"
        private const val EXTRA_VIDEO = "video"
        private const val EXTRA_TITLE = "title"

        /** The call this service is currently representing, if any. */
        @Volatile
        private var activeSessionId: String? = null

        /** Whether the running foreground type includes the camera. */
        @Volatile
        private var activeVideo: Boolean = false

        /** Whether a call is being represented right now (for the activity). */
        fun hasActiveCall(): Boolean = activeSessionId != null

        /** The Dart-facing surface. Every answer is a plain boolean. */
        fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
            when (call.method) {
                "start" -> {
                    val sessionId = call.argument<String>("sessionId").orEmpty()
                    if (sessionId.isEmpty()) {
                        result.success(false)
                        return
                    }
                    // NO MICROPHONE, NO SERVICE — AND SAY SO. A first call
                    // asks for the microphone while it joins, and a start sent
                    // while that prompt was open was refused inside the
                    // service after this had already answered true. Dart then
                    // believed the call protected and never asked again (S24,
                    // 2026-10-28 12:05:33). Answering false lets it retry once
                    // the grant lands.
                    if (!granted(context, Manifest.permission.RECORD_AUDIO)) {
                        Log.i(TAG, "start deferred: microphone not granted")
                        result.success(false)
                        return
                    }
                    val intent = Intent(context, AuraCallService::class.java).apply {
                        action = ACTION_START
                        putExtra(EXTRA_SESSION_ID, sessionId)
                        putExtra(EXTRA_VIDEO, call.argument<Boolean>("video") ?: false)
                        putExtra(EXTRA_TITLE, call.argument<String>("title").orEmpty())
                    }
                    result.success(startCompat(context, intent))
                }

                "stop" -> {
                    val sessionId = call.argument<String>("sessionId").orEmpty()
                    // Nothing running: answering true would claim a stop that
                    // never had anything to stop.
                    if (activeSessionId == null) {
                        result.success(false)
                        return
                    }
                    val intent = Intent(context, AuraCallService::class.java).apply {
                        action = ACTION_STOP
                        putExtra(EXTRA_SESSION_ID, sessionId)
                    }
                    result.success(startCompat(context, intent))
                }

                "isRunning" -> result.success(activeSessionId != null)

                else -> result.notImplemented()
            }
        }

        private fun granted(context: Context, permission: String): Boolean =
            ContextCompat.checkSelfPermission(context, permission) ==
                PackageManager.PERMISSION_GRANTED

        private fun startCompat(context: Context, intent: Intent): Boolean = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            true
        } catch (t: Throwable) {
            // Android refuses a background start in states the app does not
            // control. The call is untouched; only its protection is missing.
            Log.w(TAG, "service start refused: ${t.message}")
            false
        }
    }
}
