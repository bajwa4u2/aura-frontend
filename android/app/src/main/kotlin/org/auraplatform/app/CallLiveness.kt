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
 * The Dart side now asks the server before presenting. It cannot help here:
 * when the app is DEAD the push is handled by a broadcast receiver with no
 * Flutter engine, no session and no HTTP client. This file is that check, in
 * the one place that runs.
 *
 * ── WHAT IT IS ALLOWED TO DO ──────────────────────────────────────────────
 *
 * It may STOP a ring for a call the server says is over. It may not start
 * one, delay one, or decide anything else about the call.
 *
 * FAILURE MEANS RING. A timeout, an unreachable server, an expired session,
 * a missing token, a device with no network — every one of them returns
 * [Verdict.UNKNOWN], and the ring stands. "Cannot tell" is not "gone": the
 * cost of a wrong suppression is a missed call, which is the whole failure
 * this product is repairing. The cost of a wrong ring is what happens today.
 *
 * ── WHY THE TOKEN IS REACHABLE HERE ───────────────────────────────────────
 *
 * [SecureStore] keeps the session encrypted under an Android Keystore key
 * created WITHOUT `setUserAuthenticationRequired`, deliberately, so that a
 * call arriving on a locked phone can still refresh and join. Reading it here
 * therefore weakens nothing and adds no new exposure — the ring path this
 * file serves is already entitled to act on that session.
 */
object CallLiveness {
    private const val TAG = "AuraCallLiveness"

    /** Flutter's own preference file, and the `flutter.` prefix it writes. */
    private const val FLUTTER_PREFS = "FlutterSharedPreferences"
    private const val PREFIX = "flutter."

    private const val KEY_ACCESS_TOKEN = "aura_access_token"
    private const val KEY_DEVICE_ID = "aura_runtime_device_id"
    private const val KEY_API_BASE_URL = "aura_api_base_url"

    /**
     * Matches `AppConfig.apiBaseUrl`'s own default. Used only when Dart has
     * never recorded the value — a build that has not been opened since the
     * update. It is a fallback, not a second source of truth: the stored
     * value always wins, so a build pointed elsewhere is still followed.
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

        /** We could not find out. The ring stands. */
        UNKNOWN,
    }

    data class Result(val verdict: Verdict, val reason: String)

    /**
     * Ask the server. Blocking, so call it off the main thread.
     */
    fun check(context: Context, sessionId: String): Result {
        if (sessionId.isBlank()) return Result(Verdict.UNKNOWN, "NO_SESSION_ID")
        val token = SecureStore.readSecret(context, KEY_ACCESS_TOKEN)
        if (token.isNullOrBlank()) {
            // Signed out, or a session this device can no longer decrypt.
            // Nothing to ask with, so nothing is suppressed.
            return Result(Verdict.UNKNOWN, "NO_SESSION")
        }

        val base = apiBaseUrl(context)
        val url = "$base/realtime/sessions/$sessionId/callable"
        var connection: HttpURLConnection? = null
        return try {
            connection = (URL(url).openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                connectTimeout = CONNECT_TIMEOUT_MS
                readTimeout = READ_TIMEOUT_MS
                setRequestProperty("Authorization", "Bearer $token")
                setRequestProperty("Accept", "application/json")
                deviceId(context)?.let { setRequestProperty("X-Aura-Device-Id", it) }
                setRequestProperty("X-Aura-Platform", "android")
            }
            val code = connection.responseCode
            if (code != 200) {
                // 401 included, deliberately: an expired token is a question
                // we could not ask, not an answer that the call is over.
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
     * The dead-app case is exactly the one that has never been recorded: all
     * 44 acknowledgements in production history are ESTABLISHED from an app
     * that was already open, because only Dart ever reported. So a cold ring
     * looked identical to a phone that never rang at all.
     *
     * The state is ESTABLISHED because that is what happened — the device did
     * present. A retraction is NOT reported as LAPSED: that state means the
     * platform retired a presentation while the invitation was still live,
     * and here the invitation is precisely what was not. It rides in `detail`
     * instead, beside the verdict, with `appState` and `deviceWokeAt`
     * carrying the timing the 85 seconds could not be attributed without.
     *
     * Best-effort by construction: the ring does not depend on it.
     */
    fun reportPresented(
        context: Context,
        sessionId: String,
        appState: String,
        wokeAtMs: Long,
        detail: String,
        budgetMs: Int,
    ) {
        if (sessionId.isBlank() || budgetMs <= 0) return
        val token = SecureStore.readSecret(context, KEY_ACCESS_TOKEN)
        if (token.isNullOrBlank()) return
        val deviceId = deviceId(context)
        if (deviceId.isNullOrBlank()) {
            // The installation identity comes from the header or the report is
            // not recorded at all (NO_INSTALLATION_IDENTITY). Do not spend a
            // receiver's remaining time on a call the server will discard.
            Log.i(TAG, "ack skipped: no device id")
            return
        }

        val base = apiBaseUrl(context)
        val url = "$base/realtime/sessions/$sessionId/presentation"
        var connection: HttpURLConnection? = null
        try {
            val body = JSONObject()
                .put("state", "ESTABLISHED")
                .put("platform", "android")
                .put("appState", appState)
                .put("deviceWokeAt", iso8601(wokeAtMs))
                .put("detail", detail.take(300))
                .toString()
            connection = (URL(url).openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                connectTimeout = budgetMs
                readTimeout = budgetMs
                doOutput = true
                setRequestProperty("Authorization", "Bearer $token")
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("X-Aura-Device-Id", deviceId)
                setRequestProperty("X-Aura-Platform", "android")
            }
            connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            Log.i(TAG, "ack: sessionId=$sessionId code=${connection.responseCode}")
        } catch (t: Throwable) {
            Log.i(TAG, "ack failed: ${t.javaClass.simpleName}")
        } finally {
            try {
                connection?.disconnect()
            } catch (_: Throwable) {
            }
        }
    }

    private fun flutterPrefs(context: Context, key: String): String? = try {
        context
            .getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            .getString(PREFIX + key, null)
            ?.trim()
            ?.ifEmpty { null }
    } catch (t: Throwable) {
        null
    }

    private fun deviceId(context: Context): String? = flutterPrefs(context, KEY_DEVICE_ID)

    private fun apiBaseUrl(context: Context): String {
        val stored = flutterPrefs(context, KEY_API_BASE_URL) ?: DEFAULT_API_BASE_URL
        return stored.trimEnd('/')
    }

    private fun iso8601(ms: Long): String {
        val format = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
        format.timeZone = TimeZone.getTimeZone("UTC")
        return format.format(Date(ms))
    }
}
