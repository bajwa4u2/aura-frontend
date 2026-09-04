package org.auraplatform.app

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * KEYSTORE-BACKED STORAGE FOR THE ONLY BYTES IN AURA THAT ARE A SESSION.
 *
 * The access and refresh tokens were persisted in ordinary SharedPreferences —
 * an XML file in the app's data directory, readable by anything that can read
 * the app container and by any backup that includes it. A bearer token there is
 * a session anyone holding the file can resume.
 *
 * `EncryptedSharedPreferences` encrypts both keys and values with a master key
 * held in the Android Keystore, which never leaves the secure hardware where
 * the device has it.
 *
 * FIRST-PARTY RATHER THAN A PLUGIN, deliberately. The equivalent package's
 * Windows implementation compiles against `<atlstr.h>` and would have added a
 * Visual Studio component to Aura's release prerequisites in order to build a
 * file it no longer uses at runtime. The surface actually needed is three
 * operations, and this is them.
 *
 * DEGRADES RATHER THAN CRASHES. A Keystore can be unavailable — a device with a
 * corrupted key, a work profile under policy. Losing a session is recoverable;
 * failing app start is not, so every path here returns null or does nothing.
 */
object SecureStore {
    const val CHANNEL = "org.auraplatform.app/secure_store"

    private const val TAG = "AuraSecureStore"
    private const val FILE = "aura_secure_session"

    @Volatile
    private var prefs: SharedPreferences? = null

    private fun store(context: Context): SharedPreferences? {
        prefs?.let { return it }
        return synchronized(this) {
            prefs ?: try {
                val key = MasterKey.Builder(context)
                    .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                    .build()
                EncryptedSharedPreferences.create(
                    context,
                    FILE,
                    key,
                    EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                    EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
                ).also { prefs = it }
            } catch (t: Throwable) {
                Log.w(TAG, "encrypted store unavailable: ${t.message}")
                null
            }
        }
    }

    fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        val key = call.argument<String>("key")
        if (key.isNullOrEmpty()) {
            result.error("bad_args", "key required", null)
            return
        }

        when (call.method) {
            "read" -> result.success(store(context)?.getString(key, null))

            "write" -> {
                val value = call.argument<String>("value")
                if (value == null) {
                    result.error("bad_args", "value required", null)
                    return
                }
                // commit(), not apply(): the caller awaits this and a session
                // written asynchronously can be lost to a process death that
                // happens between the write and the flush.
                store(context)?.edit()?.putString(key, value)?.commit()
                result.success(null)
            }

            "delete" -> {
                // A missing entry is a successful delete. Signing out must not
                // fail because there was nothing to sign out of.
                store(context)?.edit()?.remove(key)?.commit()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }
}
