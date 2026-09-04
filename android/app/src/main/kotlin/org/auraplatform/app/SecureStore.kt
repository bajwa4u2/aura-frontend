package org.auraplatform.app

import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * KEYSTORE-BACKED STORAGE FOR THE ONLY BYTES IN AURA THAT ARE A SESSION.
 *
 * The access and refresh tokens were persisted in ordinary SharedPreferences —
 * an XML file in the app's data directory, readable by anything that can read
 * the app container and by any backup that includes it. A bearer token there is
 * a session anyone holding the file can resume.
 *
 * Here the token is encrypted with AES-256-GCM under a key that lives in the
 * **Android Keystore** and never enters this process. Only the ciphertext
 * reaches disk. On a device with a hardware-backed keystore the key never
 * leaves the secure element at all.
 *
 * AURA-OWNED, AND DELIBERATELY NOT `androidx.security`. `EncryptedShared-
 * Preferences` would have done this in fewer lines, and it was written that way
 * first, but it arrives via `security-crypto`, whose only release carrying it is
 * an **alpha** — and the class is deprecated upstream. The most
 * security-sensitive bytes in the product should not depend on an alpha
 * artifact that its own maintainers are moving away from. The platform APIs
 * underneath it are stable, public, and used directly below.
 *
 * WHAT IS NOT REQUIRED, AND WHY THAT IS A CALL DECISION. The key is created
 * WITHOUT `setUserAuthenticationRequired` and WITHOUT `setUnlockedDeviceRequired`.
 * Aura receives calls on a locked phone: a token that cannot be decrypted until
 * someone unlocks is a token that cannot refresh while the incoming-call
 * surface is up, so the call would present and then fail to join. This is the
 * same reasoning that puts the iOS Keychain item at
 * `AfterFirstUnlockThisDeviceOnly` rather than `WhenUnlocked`.
 *
 * DEVICE-BOUND ON PURPOSE. A Keystore key is not backed up and does not travel.
 * Restoring this app's data onto a new device brings the ciphertext and not the
 * key, so the session cannot be resumed there — which is the intended answer
 * for a device-scoped session, and the Android counterpart of `ThisDeviceOnly`.
 *
 * DEGRADES RATHER THAN CRASHES. Every failure path returns null or does
 * nothing. Losing a session is recoverable — the person signs in again. Failing
 * app start is not.
 */
object SecureStore {
    const val CHANNEL = "org.auraplatform.app/secure_store"

    private const val TAG = "AuraSecureStore"
    private const val PREFS = "aura_session_v1"
    private const val KEY_ALIAS = "aura.session.key.v1"
    private const val KEYSTORE = "AndroidKeyStore"

    private const val TRANSFORMATION = "AES/GCM/NoPadding"
    private const val GCM_TAG_BITS = 128

    /** `iv.ciphertext`, both Base64. A dot cannot occur in Base64 NO_WRAP. */
    private const val SEPARATOR = '.'

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /**
     * Idempotent. A second caller during creation must not produce a second
     * key — that would render everything written under the first unreadable.
     */
    @Synchronized
    private fun key(): SecretKey? = try {
        val store = KeyStore.getInstance(KEYSTORE).apply { load(null) }
        val existing = store.getKey(KEY_ALIAS, null) as? SecretKey
        existing ?: generate()
    } catch (t: Throwable) {
        Log.w(TAG, "keystore unavailable: ${t.message}")
        null
    }

    private fun generate(): SecretKey {
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE)
        val spec = KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            // The system supplies a fresh IV per encryption and refuses a
            // caller-provided one. Reusing an IV under GCM is catastrophic, and
            // this makes reuse impossible rather than merely discouraged.
            .setRandomizedEncryptionRequired(true)
            .apply {
                // Ask for the secure element where there is one. Absent on
                // emulators and older hardware, where the key is still
                // Keystore-managed and simply not hardware-isolated.
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    setIsStrongBoxBacked(false)
                }
            }
            .build()
        generator.init(spec)
        return generator.generateKey()
    }

    private fun encrypt(value: String): String? = try {
        val secret = key() ?: return null
        val cipher = Cipher.getInstance(TRANSFORMATION).apply { init(Cipher.ENCRYPT_MODE, secret) }
        val ciphertext = cipher.doFinal(value.toByteArray(Charsets.UTF_8))
        val iv = Base64.encodeToString(cipher.iv, Base64.NO_WRAP)
        val body = Base64.encodeToString(ciphertext, Base64.NO_WRAP)
        "$iv$SEPARATOR$body"
    } catch (t: Throwable) {
        Log.w(TAG, "encrypt failed: ${t.message}")
        null
    }

    private fun decrypt(stored: String): String? = try {
        val at = stored.indexOf(SEPARATOR)
        if (at <= 0) {
            null
        } else {
            val secret = key()
            if (secret == null) {
                null
            } else {
                val iv = Base64.decode(stored.substring(0, at), Base64.NO_WRAP)
                val body = Base64.decode(stored.substring(at + 1), Base64.NO_WRAP)
                val cipher = Cipher.getInstance(TRANSFORMATION).apply {
                    init(Cipher.DECRYPT_MODE, secret, GCMParameterSpec(GCM_TAG_BITS, iv))
                }
                String(cipher.doFinal(body), Charsets.UTF_8)
            }
        }
    } catch (t: Throwable) {
        // The key is gone or no longer usable — a restore onto another device,
        // a factory-reset keystore. The ciphertext can never be read again.
        Log.w(TAG, "decrypt failed, session unrecoverable: ${t.message}")
        null
    }

    fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        val key = call.argument<String>("key")
        if (key.isNullOrEmpty()) {
            result.error("bad_args", "key required", null)
            return
        }

        when (call.method) {
            "read" -> {
                val stored = prefs(context).getString(key, null)
                if (stored == null) {
                    result.success(null)
                    return
                }
                val value = decrypt(stored)
                if (value == null) {
                    // Do not leave an unreadable blob behind to fail on every
                    // launch. It is not a session any more.
                    prefs(context).edit().remove(key).commit()
                }
                result.success(value)
            }

            "write" -> {
                val value = call.argument<String>("value")
                if (value == null) {
                    result.error("bad_args", "value required", null)
                    return
                }
                val sealed = encrypt(value)
                if (sealed == null) {
                    // Refusing to store is the honest outcome. Writing the
                    // token in the clear "so it works" is the defect this
                    // whole file exists to remove.
                    Log.w(TAG, "refusing to persist an unencrypted session")
                    result.success(null)
                    return
                }
                // commit(), not apply(): the caller awaits this, and a session
                // written asynchronously can be lost to a process death between
                // the write and the flush.
                prefs(context).edit().putString(key, sealed).commit()
                result.success(null)
            }

            "delete" -> {
                // A missing entry is a successful delete. Signing out must not
                // fail because there was nothing to sign out of.
                prefs(context).edit().remove(key).commit()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }
}
