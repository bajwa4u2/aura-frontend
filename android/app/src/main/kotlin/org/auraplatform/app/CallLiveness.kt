package org.auraplatform.app

import android.content.Context
import android.util.Log
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/**
 * IS THIS CALL STILL WORTH RINGING?
 *
 * ── THE DEFECT ────────────────────────────────────────────────────────────
 *
 * Production, 2026-09-16, session `…8gdacp`: the ring pushes went out at
 * 04:23:22.8, the caller gave up and cancelled at 04:23:41, and the phone drew
 * an incoming call at 04:24:48.77 — 85 seconds after the ring and 67 seconds
 * after the call had ended. It then tried to join the dead session twice and
 * failed. A person was offered a call that no longer existed.
 *
 * Every guard between "a ringing payload arrived" and "an actionable call is
 * on screen" was LOCAL: an expiry that had not yet passed, and a precedence
 * rule that only knows the terminal events this device received while it was
 * awake. This device was asleep when the cancellation was sent, so it knew
 * nothing to weigh. Both guards passed, correctly, on the evidence they had.
 *
 * The Dart side asks the server before presenting. It cannot help here: when
 * the app is DEAD the push is handled by a broadcast receiver with no Flutter
 * engine, no session and no HTTP client. This file is that check, in the one
 * place that runs.
 *
 * ── AND THEN THE CHECK ITSELF COULD NOT AUTHENTICATE ──────────────────────
 *
 * This file used to read `aura_access_token` out of [SecureStore] and send it
 * as a Bearer token. Pixel 9a, 2026-09-20, app killed with `am kill`:
 *
 *     liveness: verdict=UNKNOWN reason=HTTP_401 retracted=false ms=297
 *     ack: sessionId=… code=401
 *
 * and no presentation record on the server at all. On a cold start the access
 * token has long expired, and a broadcast receiver has no refresh path. So the
 * guard that exists to stop a stale ring could never refuse in the only
 * situation it was built for, and the acknowledgement that decides whether the
 * call is later called "missed" or "never presented" was rejected too — which
 * is how a call that rang loudly came to read "tried to call you".
 *
 * ── THE AUTHORITY THIS FILE NOW CARRIES ───────────────────────────────────
 *
 * Founder invariant, 2026-09-20, frozen:
 *
 *   CALL PRESENTATION AUTHORITY IS CALL-SCOPED, NOT USER-SESSION-SCOPED.
 *
 * The server mints a capability scoped to ONE invitation on ONE device and
 * carries it in that device's push envelope, as `callAuth`. It authorises
 * three things and no others: ask whether this invitation is still
 * presentable, report that this phone presented it, report a decline. It is
 * not an Aura session, it is not stored, and it dies with the ring.
 *
 * Nothing here reads the person's credential any more. That is the point: the
 * ordinary access/refresh token belongs to the authentication subsystem, and a
 * receiver racing Flutter to refresh it is how somebody gets signed out.
 *
 * ── WHAT IT IS ALLOWED TO DO ──────────────────────────────────────────────
 *
 * It may STOP a ring for a call the server says is over. It may not start
 * one, delay one, or decide anything else about the call.
 *
 * FAILURE MEANS RING. A timeout, an unreachable server, a missing capability,
 * a device with no network — every one of them returns [Verdict.UNKNOWN], and
 * the ring stands. "Cannot tell" is not "gone": the cost of a wrong
 * suppression is a missed call, which is the whole failure this product is
 * repairing.
 *
 * But UNKNOWN is never laundered into LIVE. A ring shown on an unanswered
 * question is reported as [PRESENTED_WITHOUT_LIVENESS_CONFIRMATION], so the
 * server's own account of the call stays truthful about what was established.
 */
object CallLiveness {
    private const val TAG = "AuraCallLiveness"

    /** Flutter's own preference file, and the `flutter.` prefix it writes. */
    private const val FLUTTER_PREFS = "FlutterSharedPreferences"
    private const val PREFIX = "flutter."

    private const val KEY_DEVICE_ID = "aura_runtime_device_id"
    private const val KEY_API_BASE_URL = "aura_api_base_url"

    /** The header the call capability is presented in. Never a query param. */
    private const val HEADER_CAPABILITY = "X-Aura-Call-Capability"

    /** The push envelope key carrying it, and the version of that contract. */
    const val DATA_KEY_CAPABILITY = "callAuth"
    const val DATA_KEY_CAPABILITY_VERSION = "callAuthVersion"

    /** How the ring was established. Reported, never inferred by the server. */
    const val CONFIRMED_LIVE = "CONFIRMED_LIVE"
    const val PRESENTED_WITHOUT_LIVENESS_CONFIRMATION =
        "PRESENTED_WITHOUT_LIVENESS_CONFIRMATION"

    /**
     * Matches `AppConfig.apiBaseUrl`'s own default. Used only when Dart has
     * never recorded the value — a build that has not been opened since the
     * update. It is a fallback, not a second source of truth: the stored
     * value always wins, so a build pointed elsewhere is still followed.
     *
     * This is configuration, not a credential. Reading it here is not the
     * dependency the invariant above forbids.
     */
    private const val DEFAULT_API_BASE_URL = "https://api.auraplatform.org/v1"

    /** Bounded hard. A broadcast receiver has ~10s before Android calls it ANR. */
    private const val CONNECT_TIMEOUT_MS = 3_000
    private const val READ_TIMEOUT_MS = 3_000

    enum class Verdict {
        /** The server says this call can still be joined by this person. */
        LIVE,

        /** The server says it cannot — ended, cancelled, or never theirs. */
        NOT_LIVE,

        /** We could not find out. The ring stands, and says so. */
        UNKNOWN,
    }

    data class Result(val verdict: Verdict, val reason: String) {
        /**
         * What the acknowledgement must claim about this ring. Only a verdict
         * the server actually gave may be reported as confirmation; everything
         * else — including a capability this build never received — is an
         * unanswered question and is recorded as one.
         */
        val confirmation: String
            get() = if (verdict == Verdict.LIVE) CONFIRMED_LIVE
            else PRESENTED_WITHOUT_LIVENESS_CONFIRMATION
    }

    /**
     * Ask the server, with the capability minted for this exact invitation.
     * Blocking, so call it off the main thread.
     *
     * A push with no capability is an older server, or a ring for a device
     * that holds no invite row. There is nothing to ask with, and the previous
     * credential is deliberately not reachable from here any more, so the
     * answer is UNKNOWN and the ring stands.
     */
    fun check(context: Context, sessionId: String, capability: String?): Result {
        if (sessionId.isBlank()) return Result(Verdict.UNKNOWN, "NO_SESSION_ID")
        if (capability.isNullOrBlank()) return Result(Verdict.UNKNOWN, "NO_CAPABILITY")

        val base = apiBaseUrl(context)
        val url = "$base/realtime/sessions/$sessionId/invite/presentable"
        var connection: HttpURLConnection? = null
        return try {
            connection = (URL(url).openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                connectTimeout = CONNECT_TIMEOUT_MS
                readTimeout = READ_TIMEOUT_MS
                setRequestProperty(HEADER_CAPABILITY, capability)
                setRequestProperty("Accept", "application/json")
                deviceId(context)?.let { setRequestProperty("X-Aura-Device-Id", it) }
                setRequestProperty("X-Aura-Platform", "android")
            }
            val code = connection.responseCode
            if (code != 200) {
                // 401 included, and it means something different now: the
                // capability is dead, not the person's session. A device that
                // sees it must NOT go looking for a credential to refresh —
                // that is precisely the behaviour this design removed.
                Result(Verdict.UNKNOWN, "HTTP_$code")
            } else {
                val body = connection.inputStream.bufferedReader().use { it.readText() }
                val json = JSONObject(body)
                val payload = json.optJSONObject("data") ?: json
                val reason = payload.optString("reason").ifBlank { "UNSPECIFIED" }
                when {
                    // A body without the field is a contract this build does
                    // not recognise — an older or newer server. That is "we
                    // could not find out", not "the call is live": only one of
                    // the three verdicts may silence a ring, and it must be
                    // said explicitly.
                    !payload.has("joinable") -> Result(Verdict.UNKNOWN, "NO_VERDICT")
                    payload.optBoolean("joinable") -> Result(Verdict.LIVE, reason)
                    else -> Result(Verdict.NOT_LIVE, reason)
                }
            }
        } catch (t: Throwable) {
            // Offline, DNS, TLS, a malformed body — all the same answer.
            Result(Verdict.UNKNOWN, t.javaClass.simpleName)
        } finally {
            try {
                connection?.disconnect()
            } catch (_: Throwable) {
            }
        }
    }

    /**
     * Tell the server this device put the call on screen, and what the check
     * said about it.
     *
     * The dead-app case is exactly the one that had never been recorded: every
     * acknowledgement in production history was ESTABLISHED from an app that
     * was already open, because only Dart ever reported and the native attempt
     * was answered 401. So a cold ring looked identical to a phone that never
     * rang at all, and the call derived as NOT_PRESENTED.
     *
     * The state is ESTABLISHED because that is what happened — the device did
     * present. A retraction is NOT reported as LAPSED: that state means the
     * platform retired a presentation while the invitation was still live,
     * and here the invitation is precisely what was not. It rides in `detail`
     * instead, beside the verdict, with `appState` and `deviceWokeAt`
     * carrying the timing the 85 seconds could not be attributed without.
     *
     * No installation header is required any more. The server resolves the
     * physical endpoint from the `UserDevice` the push was addressed to, which
     * closes a second gap: an install where Dart had never run held no
     * `aura_runtime_device_id`, so it could ring and be structurally incapable
     * of saying so.
     *
     * Best-effort by construction: the ring does not depend on it.
     */
    fun reportPresented(
        context: Context,
        sessionId: String,
        capability: String?,
        appState: String,
        wokeAtMs: Long,
        detail: String,
        confirmation: String,
        budgetMs: Int,
    ) {
        if (sessionId.isBlank() || budgetMs <= 0) return
        if (capability.isNullOrBlank()) {
            // Nothing to speak with. Deliberately not falling back to the
            // person's credential — that path is what this file removed.
            Log.i(TAG, "ack skipped: no capability")
            return
        }

        val base = apiBaseUrl(context)
        val url = "$base/realtime/sessions/$sessionId/invite/presented"
        var connection: HttpURLConnection? = null
        try {
            val body = JSONObject()
                .put("platform", "android")
                .put("appState", appState)
                .put("deviceWokeAt", iso8601(wokeAtMs))
                .put("detail", detail.take(300))
                .put("livenessConfirmation", confirmation)
                .toString()
            connection = (URL(url).openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                connectTimeout = budgetMs
                readTimeout = budgetMs
                doOutput = true
                setRequestProperty(HEADER_CAPABILITY, capability)
                setRequestProperty("Content-Type", "application/json")
                deviceId(context)?.let { setRequestProperty("X-Aura-Device-Id", it) }
                setRequestProperty("X-Aura-Platform", "android")
            }
            connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            Log.i(
                TAG,
                "ack: sessionId=$sessionId code=${connection.responseCode} " +
                    "confirmation=$confirmation",
            )
        } catch (t: Throwable) {
            Log.i(TAG, "ack failed: ${t.javaClass.simpleName}")
        } finally {
            try {
                connection?.disconnect()
            } catch (_: Throwable) {
            }
        }
    }

    /**
     * The API base Dart recorded, or the build's own default.
     *
     * Configuration, not a credential — an ordinary preference, deliberately
     * not in [SecureStore], and reading it implies no session.
     */
    private fun apiBaseUrl(context: Context): String {
        val stored = flutterPref(context, KEY_API_BASE_URL)
        val base = if (stored.isNullOrBlank()) DEFAULT_API_BASE_URL else stored
        return base.trimEnd('/')
    }

    private fun deviceId(context: Context): String? = flutterPref(context, KEY_DEVICE_ID)

    private fun flutterPref(context: Context, key: String): String? = try {
        context
            .getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            .getString(PREFIX + key, null)
            ?.trim()
            ?.ifBlank { null }
    } catch (_: Throwable) {
        null
    }

    private fun iso8601(ms: Long): String {
        val format = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
        format.timeZone = TimeZone.getTimeZone("UTC")
        return format.format(Date(ms))
    }
}
