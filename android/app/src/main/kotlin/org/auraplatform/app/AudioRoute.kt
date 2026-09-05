package org.auraplatform.app

import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * WHERE ANDROID IS ACTUALLY PLAYING THE CALL.
 *
 * flutter_webrtc can SELECT an output route and can list the routes it is able
 * to select, but it does not expose which one is in force — `selectedAudioDevice()`
 * exists in its Java and is not reachable from Dart. So a picker built on that
 * plugin alone could only ever show what it last asked for.
 *
 * That is precisely the thing not to build. A request can be refused, silently
 * substituted, or overridden by the system the moment a headset connects — and
 * on 2026-09-05 this device did exactly that: a paired headset took a call,
 * dropped its link, and left the call routed to nothing while the app believed
 * otherwise. A control that reports its own intentions would have shown a
 * confident, wrong answer.
 *
 * So this asks the OPERATING SYSTEM, through `AudioManager.getCommunicationDevice()`
 * — the platform's own account of where communication audio is going. Read
 * only. It changes no route and owns no policy; selection stays with the audio
 * stack the call already uses, and this reports what that stack achieved.
 *
 * Requires API 31 for the communication-device API. Below that it answers
 * "unknown" rather than guessing, and the picker degrades to what flutter_webrtc
 * alone can honestly support.
 */
object AudioRoute {
    const val CHANNEL = "org.auraplatform.app/audio_route"
    private const val TAG = "AuraAudioRoute"

    fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "currentRoute" -> result.success(currentRoute(context))
            "availableRoutes" -> result.success(availableRoutes(context))
            else -> result.notImplemented()
        }
    }

    /**
     * The route in force, as a category the product already speaks, or null when
     * the platform will not say.
     *
     * Null is a real answer and must stay distinguishable from "earpiece": one
     * means the OS has not told us, the other means it has.
     */
    private fun currentRoute(context: Context): Map<String, Any?>? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return null
        val audio = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            ?: return null
        return try {
            val device = audio.communicationDevice ?: return null
            mapOf(
                "id" to kindOf(device.type),
                "kind" to kindOf(device.type),
                "name" to safeName(device),
            )
        } catch (e: Throwable) {
            Log.w(TAG, "communicationDevice unavailable: ${e.message}")
            null
        }
    }

    /**
     * Routes the OS itself reports as usable for communication.
     *
     * Offered alongside the plugin's list rather than instead of it: this is the
     * truthful set, and the plugin's is the selectable set. A route the app
     * cannot select is not worth showing, and a route the OS does not have must
     * never be shown.
     */
    private fun availableRoutes(context: Context): List<Map<String, Any?>> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return emptyList()
        val audio = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            ?: return emptyList()
        return try {
            audio.availableCommunicationDevices.map { device ->
                mapOf(
                    "id" to kindOf(device.type),
                    "kind" to kindOf(device.type),
                    "name" to safeName(device),
                )
            }
        } catch (e: Throwable) {
            Log.w(TAG, "availableCommunicationDevices unavailable: ${e.message}")
            emptyList()
        }
    }

    /**
     * Android device types collapsed to the categories the product speaks.
     *
     * Deliberately the same vocabulary flutter_webrtc uses for selection, so a
     * route read from the OS and a route selected through the plugin are the
     * same thing and can be compared without translation.
     */
    private fun kindOf(type: Int): String = when (type) {
        AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> "earpiece"
        AudioDeviceInfo.TYPE_BUILTIN_SPEAKER,
        AudioDeviceInfo.TYPE_BUILTIN_SPEAKER_SAFE -> "speaker"
        AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
        AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
        AudioDeviceInfo.TYPE_BLE_HEADSET,
        AudioDeviceInfo.TYPE_BLE_SPEAKER -> "bluetooth"
        AudioDeviceInfo.TYPE_WIRED_HEADSET,
        AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
        AudioDeviceInfo.TYPE_USB_HEADSET -> "wired-headset"
        else -> "other"
    }

    /**
     * A name only where the platform supplies a meaningful one.
     *
     * Built-in outputs are named things like "Pixel 9a" by the system, which
     * says nothing a person needs when the label already reads "Earpiece". A
     * name is returned for the routes where it identifies something the person
     * recognises — their headset — and null elsewhere, so nothing downstream has
     * to guess whether a name is worth showing.
     */
    private fun safeName(device: AudioDeviceInfo): String? {
        val named = when (kindOf(device.type)) {
            "bluetooth", "wired-headset", "other" -> true
            else -> false
        }
        if (!named) return null
        val name = device.productName?.toString()?.trim().orEmpty()
        return name.ifEmpty { null }
    }
}
