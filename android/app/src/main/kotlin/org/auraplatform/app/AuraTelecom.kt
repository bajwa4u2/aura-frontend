package org.auraplatform.app

import android.content.Context
import android.net.Uri
import android.os.Build
import android.telecom.DisconnectCause
import android.util.Log
import androidx.annotation.RequiresApi
import androidx.core.telecom.CallAttributesCompat
import androidx.core.telecom.CallControlScope
import androidx.core.telecom.CallsManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.util.concurrent.ConcurrentHashMap

/**
 * AURA CALLS, ON ANDROID'S CALL STACK.
 *
 * ── WHAT THIS BUYS, AND WHAT IT DELIBERATELY DOES NOT ────────────────────
 *
 * Until now an Aura call on Android was a notification with a ringtone. It
 * rang, and it was certified, and it was invisible to everything else the
 * phone was doing: no audio focus, no routing decision, no relationship to a
 * cellular call arriving mid-conversation, no entry in any call register.
 *
 * Registering the call with Telecom is what makes it a CALL to the operating
 * system. Audio focus, Bluetooth and wired routing, and concurrency with the
 * dialer all become the system's job, done the way the system does them for
 * every other call on the device.
 *
 * **It does not replace Aura's ringing UI.** These are SELF-MANAGED calls: the
 * system does not draw an incoming-call screen for them, the app does. So
 * `IncomingCallPresenter` remains exactly what the person sees, unchanged and
 * still certified, and this sits underneath it. Founder ruling: Core-Telecom
 * is the native call lifecycle integration, not an excuse to discard working
 * Aura call UX.
 *
 * ── AND IT WRITES NOTHING TO THE CALL LOG ────────────────────────────────
 *
 * `DIRECT_CALLLOG_WRITES = 0`. Aura holds none of Play's restricted Call Log
 * permissions — `READ_CALL_LOG`, `WRITE_CALL_LOG`, `PROCESS_OUTGOING_CALLS` —
 * and there is no `CallLog` provider call anywhere in this file. System call
 * history is whatever Android chooses to record for a call it is managing.
 * Inserting rows to manufacture Recents entries would produce entries without
 * producing calls: a row in a table that looks like an integration.
 *
 * ── DEGRADES, NEVER BLOCKS ───────────────────────────────────────────────
 *
 * Every failure path here is silent to the product. Telecom can refuse a call
 * — another call is already in progress, the phone account is in a state we
 * did not anticipate — and when it does, the Aura call carries on exactly as
 * it did before this file existed. Nothing branches product behaviour on
 * whether the OS accepted the report; that result says only whether the call
 * appears in the system's own surfaces.
 */
object AuraTelecom {
    const val CHANNEL = "org.auraplatform.app/telecom"

    private const val TAG = "AuraTelecom"

    /**
     * Coroutine home for calls. `addCall` SUSPENDS FOR THE WHOLE CALL, which
     * is the shape of the API rather than a choice: the suspension IS the
     * call, and it resumes when the call ends.
     */
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    private var callsManager: CallsManager? = null
    private var registered = false

    /** Live calls, keyed by Aura's own session id. */
    private val calls = ConcurrentHashMap<String, LiveCall>()

    private var channel: MethodChannel? = null

    private class LiveCall(
        val job: Job,
        /** Resolves once the call is inside its control scope. */
        val control: CompletableDeferred<CallControlScope> = CompletableDeferred(),
    )

    fun attach(channel: MethodChannel) {
        this.channel = channel
    }

    // ── The Dart-facing surface ─────────────────────────────────────────

    fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(
                CallCapabilityPolicy.telecomCapability().allowsTelecom,
            )

            "withheldReason" -> result.success(CallCapabilityPolicy.withheldBecause())

            "reportIncoming" -> {
                report(context, call, result, CallAttributesCompat.DIRECTION_INCOMING)
            }

            "reportOutgoing" -> {
                report(context, call, result, CallAttributesCompat.DIRECTION_OUTGOING)
            }

            // Media is up. Moves the system call out of "connecting", which is
            // what gives an entry a real duration rather than none.
            "reportConnected" -> {
                val sessionId = call.argument<String>("sessionId").orEmpty()
                withControl(sessionId) { it.setActive() }
                result.success(null)
            }

            "reportEnded" -> {
                val sessionId = call.argument<String>("sessionId").orEmpty()
                val reason = call.argument<String>("reason").orEmpty()
                end(sessionId, reason)
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun report(
        context: Context,
        call: MethodCall,
        result: MethodChannel.Result,
        direction: Int,
    ) {
        val sessionId = call.argument<String>("sessionId").orEmpty()
        if (sessionId.isEmpty()) {
            result.success(false)
            return
        }
        val displayName = call.argument<String>("displayName").orEmpty()
        val video = call.argument<Boolean>("video") ?: false
        result.success(addCall(context, sessionId, displayName, video, direction))
    }

    // ── Telecom ─────────────────────────────────────────────────────────

    /**
     * Register Aura with Telecom, once.
     *
     * Idempotent because it is called from the first call of the session
     * rather than at app start: registering a calling account for someone who
     * never makes a call would put Aura in the system's calling-account
     * settings for no reason.
     */
    @RequiresApi(Build.VERSION_CODES.O)
    @Synchronized
    private fun manager(context: Context): CallsManager? {
        if (!CallCapabilityPolicy.telecomCapability().allowsTelecom) return null
        val existing = callsManager
        if (existing != null && registered) return existing
        return try {
            val created = existing ?: CallsManager(context.applicationContext)
            if (!registered) {
                // BASELINE only. Video calling and call streaming are separate
                // capabilities Aura has not certified through this path, and
                // declaring a capability the app does not honour is a promise
                // to the system it cannot keep.
                created.registerAppWithTelecom(CallsManager.CAPABILITY_BASELINE)
                registered = true
            }
            callsManager = created
            created
        } catch (t: Throwable) {
            Log.w(TAG, "telecom registration unavailable: ${t.message}")
            null
        }
    }

    private fun addCall(
        context: Context,
        sessionId: String,
        displayName: String,
        video: Boolean,
        direction: Int,
    ): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        val manager = manager(context) ?: return false

        // A second report for a live call is a duplicate delivery, not a
        // second call. Adding it again would put two system calls behind one
        // Aura session and leave one of them stranded.
        if (calls.containsKey(sessionId)) return true

        val attributes = CallAttributesCompat(
            displayName.ifEmpty { "Aura" },
            // Telecom wants an address. Aura calls are not dialled, so this is
            // the session's own canonical address rather than a phone number
            // invented to satisfy the type.
            Uri.parse("aura:$sessionId"),
            direction,
            if (video) {
                CallAttributesCompat.CALL_TYPE_VIDEO_CALL
            } else {
                CallAttributesCompat.CALL_TYPE_AUDIO_CALL
            },
            // Holding is what lets a cellular call arrive during an Aura call
            // and be answered without the Aura call simply dying.
            CallAttributesCompat.SUPPORTS_SET_INACTIVE,
        )

        val live = LiveCall(job = Job())
        val job = scope.launch {
            try {
                manager.addCall(
                    attributes,
                    // THE SYSTEM ANSWERED. A Bluetooth headset button, a car,
                    // a wearable. Carried to Dart, which decides — the same
                    // rule the notification path already keeps: never join on
                    // the recipient's behalf without the app's own lifecycle
                    // agreeing.
                    { _ -> emit("onAnswer", sessionId) },
                    // THE SYSTEM DISCONNECTED. A cellular call took priority,
                    // or the person ended it from a system surface.
                    { cause -> emit("onDisconnect", sessionId, cause.code.toString()) },
                    { emit("onSetActive", sessionId) },
                    // Held. The Aura call must go quiet rather than carry on
                    // into a conversation the person is no longer in.
                    { emit("onSetInactive", sessionId) },
                ) {
                    live.control.complete(this)
                }
            } catch (t: Throwable) {
                // Telecom refused, or the call ended abnormally. The Aura call
                // is untouched; only its system representation is missing.
                Log.w(TAG, "addCall failed for $sessionId: ${t.message}")
            } finally {
                calls.remove(sessionId)
            }
        }
        calls[sessionId] = LiveCall(job = job, control = live.control)
        return true
    }

    /**
     * End the system's copy of a call, with a truthful cause.
     *
     * The cause is carried through because system call history is
     * user-visible: a call answered on another device must not be recorded as
     * declined, and one that expired must not be recorded as ended by the
     * caller. Where Aura genuinely cannot tell the difference, the honest
     * default is a plain local disconnect, and nothing here invents it.
     */
    private fun end(sessionId: String, reason: String) {
        val cause = when (reason) {
            "declined" -> DisconnectCause.REJECTED
            "expired", "missed" -> DisconnectCause.MISSED
            "cancelled" -> DisconnectCause.REMOTE
            "failed" -> DisconnectCause.ERROR
            "answered_elsewhere" -> DisconnectCause.OTHER
            else -> DisconnectCause.LOCAL
        }
        withControl(sessionId) { it.disconnect(DisconnectCause(cause)) }
    }

    /**
     * Run something against a live call's control scope.
     *
     * Awaits the scope rather than requiring it: `addCall` and the first
     * report-connected can race on a fast answer, and dropping the second
     * because the first had not finished starting would leave a call showing
     * as connecting for its whole duration.
     */
    private fun withControl(
        sessionId: String,
        action: suspend (CallControlScope) -> Unit,
    ) {
        if (sessionId.isEmpty()) return
        val live = calls[sessionId] ?: return
        scope.launch {
            try {
                action(live.control.await())
            } catch (t: Throwable) {
                Log.w(TAG, "call control failed for $sessionId: ${t.message}")
            }
        }
    }

    private fun emit(event: String, sessionId: String, detail: String? = null) {
        val payload = mutableMapOf<String, Any?>("sessionId" to sessionId)
        if (detail != null) payload["detail"] = detail
        channel?.invokeMethod(event, payload)
    }
}
