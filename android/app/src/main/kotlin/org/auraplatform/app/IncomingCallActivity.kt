package org.auraplatform.app

import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import java.lang.ref.WeakReference
import java.net.HttpURLConnection
import java.net.URL

/**
 * A RINGING CALL, OVER THE LOCK SCREEN, AS A CALL.
 *
 * Founder, Pixel 9a on 1.7.0 (46), 2026-10-22: the call "indicated/ring in
 * locked screen as minimized … clicked to expand and answer then unlocked
 * prompt then in conversation and call … its not a call but messy flow of
 * multiple actions rather than a call full screen answered and talked".
 *
 * The full-screen intent used to open MainActivity. Android did launch it
 * (`START … CALL_OPEN`, `full_screen_intent` wake) and the lock screen came
 * straight back over it: MainActivity may only show above the keyguard once
 * it has run code saying so, and a stopped activity cannot run that code
 * until it is resumed — which the keyguard will not allow. The call was
 * demoted to a notification every time the app was already alive.
 *
 * This screen is declared `showWhenLocked` in the manifest, so it is above the
 * lock screen from its first frame, and it does nothing but present the call:
 * who is calling, voice or video, Decline and Accept (founder-approved design,
 * 2026-10-22). Accept goes straight to the call screen, still over the lock
 * screen. Nothing here decides what a call is — it carries the person's act to
 * the same Answer / Decline paths the notification's own buttons use.
 *
 * The notification's Answer and Decline buttons come through here too, with no
 * screen drawn, for the same reason: it is the one door above the keyguard.
 */
class IncomingCallActivity : Activity() {

    private var sessionId: String = ""
    private var callData: HashMap<String, String> = HashMap()
    private val handler = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        showOverLockScreen()
        if (!readCall(intent)) {
            finish()
            return
        }
        current = WeakReference(this)
        when (intent.getStringExtra(IncomingCallPresenter.EXTRA_CALL_ACTION)) {
            IncomingCallPresenter.ACTION_ANSWER -> accept()
            IncomingCallPresenter.ACTION_DECLINE -> decline()
            else -> present()
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (!readCall(intent)) return
        when (intent.getStringExtra(IncomingCallPresenter.EXTRA_CALL_ACTION)) {
            IncomingCallPresenter.ACTION_ANSWER -> accept()
            IncomingCallPresenter.ACTION_DECLINE -> decline()
            else -> present()
        }
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        if (current?.get() === this) current = null
        super.onDestroy()
    }

    private fun readCall(intent: Intent?): Boolean {
        val id = intent?.getStringExtra("sessionId")?.trim().orEmpty()
        if (id.isEmpty()) return false
        sessionId = id
        @Suppress("UNCHECKED_CAST", "DEPRECATION")
        callData = (intent?.getSerializableExtra(IncomingCallPresenter.EXTRA_CALL_DATA)
            as? HashMap<String, String>) ?: HashMap()
        return true
    }

    private fun showOverLockScreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    // ── The person said yes ─────────────────────────────────────────────

    private fun accept() {
        Log.i(TAG, "accept: sessionId=$sessionId")
        // Allow the app above the keyguard BEFORE it is asked to come forward.
        // A stopped MainActivity cannot do this for itself in time — that is
        // the whole failure this screen exists for.
        MainActivity.prepareForCall()
        startActivity(
            Intent(this, MainActivity::class.java).apply {
                action = "org.auraplatform.app.CALL_ANSWER"
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra(IncomingCallPresenter.EXTRA_CALL_ACTION, IncomingCallPresenter.ACTION_ANSWER)
                putExtra("sessionId", sessionId)
                putExtra(IncomingCallPresenter.EXTRA_CALL_DATA, HashMap(callData))
            },
        )
        IncomingCallPresenter.dismiss(this, sessionId)
        finish()
    }

    // ── The person said no ──────────────────────────────────────────────

    private fun decline() {
        Log.i(TAG, "decline: sessionId=$sessionId")
        IncomingCallPresenter.dismiss(this, sessionId)
        // The call's own capability declines it, so refusing a call never
        // needs an unlock or a running app. The server's decline reaches a
        // running Aura as the ordinary terminal event, which clears its card
        // and its system call. A backgrounded Flutter app draws no frames, so
        // handing it the act instead would leave the caller ringing until the
        // phone was next opened.
        val capability = callData[CallLiveness.DATA_KEY_CAPABILITY]?.trim().orEmpty()
        if (capability.isNotEmpty()) {
            val app = applicationContext
            val id = sessionId
            Thread { CallLiveness.reportDeclined(app, id, capability) }.start()
        } else if (!MainActivity.deliverCallAction(
                IncomingCallPresenter.ACTION_DECLINE,
                sessionId,
                callData,
            )
        ) {
            // No way to say no without the app. Hand it over; this is the one
            // path that still needs the phone unlocked.
            startActivity(
                Intent(this, MainActivity::class.java).apply {
                    action = "org.auraplatform.app.CALL_DECLINE"
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    putExtra(IncomingCallPresenter.EXTRA_CALL_ACTION, IncomingCallPresenter.ACTION_DECLINE)
                    putExtra("sessionId", sessionId)
                    putExtra(IncomingCallPresenter.EXTRA_CALL_DATA, HashMap(callData))
                },
            )
        }
        finish()
    }

    // ── The ring screen ─────────────────────────────────────────────────

    private fun present() {
        val name = callData.firstNonBlank("callerDisplayName", "callerHandle").ifEmpty { "Incoming call" }
        val video = callData.firstNonBlank("mediaMode", "sessionType", "mode", "callKind")
            .equals("video", ignoreCase = true)

        window.statusBarColor = INK
        window.navigationBarColor = INK

        val root = FrameLayout(this).apply { setBackgroundColor(INK) }

        val centre = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
        }
        val avatarSize = dp(128)
        val avatar = FrameLayout(this).apply {
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(SURFACE)
                setStroke(dp(2), GOLD)
            }
            clipToOutline = true
            outlineProvider = android.view.ViewOutlineProvider.BACKGROUND
        }
        val initial = TextView(this).apply {
            text = name.trim().take(1).uppercase()
            setTextColor(GOLD)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 48f)
            gravity = Gravity.CENTER
        }
        val photo = ImageView(this).apply {
            scaleType = ImageView.ScaleType.CENTER_CROP
            visibility = View.GONE
        }
        avatar.addView(initial, FrameLayout.LayoutParams(avatarSize, avatarSize))
        avatar.addView(photo, FrameLayout.LayoutParams(avatarSize, avatarSize))
        centre.addView(avatar, LinearLayout.LayoutParams(avatarSize, avatarSize))

        centre.addView(
            TextView(this).apply {
                text = name
                setTextColor(TEXT)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 30f)
                typeface = Typeface.create(Typeface.SERIF, Typeface.NORMAL)
                gravity = Gravity.CENTER
                maxLines = 2
            },
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply { topMargin = dp(28) },
        )
        centre.addView(
            TextView(this).apply {
                text = if (video) "Aura video call" else "Aura voice call"
                setTextColor(MUTED)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 17f)
                gravity = Gravity.CENTER
            },
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply { topMargin = dp(8) },
        )
        root.addView(
            centre,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER_HORIZONTAL or Gravity.TOP,
            ).apply {
                leftMargin = dp(24)
                rightMargin = dp(24)
                topMargin = dp(140)
            },
        )

        val actions = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }
        actions.addView(
            actionButton("Decline", DECLINE, Color.WHITE, hangUp = true) { decline() },
            LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f),
        )
        actions.addView(
            actionButton("Accept", GOLD, INK, hangUp = false) { accept() },
            LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f),
        )
        root.addView(
            actions,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM,
            ).apply { bottomMargin = dp(88) },
        )

        setContentView(root)
        loadPhoto(callData.firstNonBlank("callerAvatarUrl"), photo, initial)

        // The ring has a window; so does this screen. Answered, declined,
        // cancelled or expired, IncomingCallPresenter.dismiss closes it too.
        handler.removeCallbacksAndMessages(null)
        handler.postDelayed({ finish() }, IncomingCallPresenter.windowMsFor(callData))
    }

    private fun actionButton(
        label: String,
        fill: Int,
        iconTint: Int,
        hangUp: Boolean,
        onTap: () -> Unit,
    ): View {
        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
        }
        val size = dp(76)
        val circle = FrameLayout(this).apply {
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(fill)
            }
            contentDescription = label
            isClickable = true
            isFocusable = true
            setOnClickListener { onTap() }
        }
        val icon = ImageView(this).apply {
            setImageResource(android.R.drawable.sym_action_call)
            setColorFilter(iconTint)
            // The hang-up glyph is the handset turned down, as on every phone.
            if (hangUp) rotation = 135f
        }
        circle.addView(
            icon,
            FrameLayout.LayoutParams(dp(34), dp(34), Gravity.CENTER),
        )
        column.addView(circle, LinearLayout.LayoutParams(size, size))
        column.addView(
            TextView(this).apply {
                text = label
                setTextColor(TEXT)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
                gravity = Gravity.CENTER
            },
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply { topMargin = dp(10) },
        )
        return column
    }

    /** Best-effort: the initial stays if the photo cannot be fetched. */
    private fun loadPhoto(url: String, target: ImageView, initial: TextView) {
        if (!url.startsWith("https://")) return
        Thread {
            var connection: HttpURLConnection? = null
            val bitmap: Bitmap? = try {
                connection = (URL(url).openConnection() as HttpURLConnection).apply {
                    connectTimeout = 3_000
                    readTimeout = 3_000
                }
                connection.inputStream.use { BitmapFactory.decodeStream(it) }
            } catch (t: Throwable) {
                null
            } finally {
                connection?.disconnect()
            }
            if (bitmap != null) {
                runOnUiThread {
                    if (isFinishing) return@runOnUiThread
                    target.setImageBitmap(bitmap)
                    target.visibility = View.VISIBLE
                    initial.visibility = View.GONE
                }
            }
        }.start()
    }

    private fun dp(value: Int): Int = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP,
        value.toFloat(),
        resources.displayMetrics,
    ).toInt()

    private fun Map<String, String>.firstNonBlank(vararg keys: String): String {
        for (key in keys) {
            val value = this[key]?.trim().orEmpty()
            if (value.isNotEmpty() && value != "null") return value
        }
        return ""
    }

    companion object {
        private const val TAG = "AuraIncomingScreen"

        // Aura's Member palette, Night Chamber (DD-25).
        private val INK = Color.parseColor("#0E1116")
        private val SURFACE = Color.parseColor("#1A1F27")
        private val GOLD = Color.parseColor("#D2AC62")
        private val TEXT = Color.parseColor("#F2EDE4")
        private val MUTED = Color.parseColor("#9AA0A8")
        private val DECLINE = Color.parseColor("#D9534F")

        @Volatile
        private var current: WeakReference<IncomingCallActivity>? = null

        /** The ring is over, for whatever reason: the screen goes with it. */
        fun close(sessionId: String?) {
            val screen = current?.get() ?: return
            if (sessionId == null || sessionId == screen.sessionId) {
                screen.runOnUiThread { screen.finish() }
            }
        }
    }
}
