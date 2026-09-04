package org.auraplatform.app

import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import android.util.Log
import java.io.File

/**
 * TURNS AN ANDROID SHARE INTENT INTO SOMETHING AURA CAN JUDGE.
 *
 * Its whole job is transport. It decides no destination, chooses no identity,
 * publishes nothing, and does not classify content — the class is decided in
 * Dart by `ContentIntake`, which reads the bytes. What arrives here is a set of
 * CLAIMS by the sharing application, and they are carried forward as claims.
 *
 * WHY IT COPIES THE CONTENT INSTEAD OF PASSING THE URI ALONG.
 * A `content://` URI arrives with a read grant scoped to THIS INTENT. It is
 * alive now and it is gone once the intent is finished with — which is long
 * before the person has looked at the preview, picked a conversation and
 * pressed a button. Handing the URI to Dart and reading it later is a share
 * that works in testing and fails as a permission error in someone's hand.
 * So the bytes are taken while the grant is alive, into Aura's own cache.
 *
 * WHY IT COPIES RATHER THAN READING INTO MEMORY.
 * A shared video can be a hundred megabytes. Reading that into a byte array and
 * pushing it across a method channel is an out-of-memory crash or an ANR on a
 * mid-range phone. A file copy is bounded work with a bounded buffer, and Dart
 * reads the copy when it actually needs the bytes.
 */
object ShareIntake {
    const val CHANNEL = "org.auraplatform.app/share_intake"

    private const val TAG = "AuraShareIntake"
    private const val CACHE_DIR = "share_intake"

    /**
     * The largest single item Aura will take in.
     *
     * MIRRORS `MediaCapacity._streamedEnvelope` (150 MiB) and the backend's
     * `maxBytesFor`. Deliberately the SAME number rather than a smaller one
     * chosen for this door: a second ceiling would mean a file Aura accepts
     * from the picker is refused from the share sheet, for a reason the person
     * could never work out. Anything above it is refused HERE, without being
     * read, so an enormous file costs a message rather than a crash.
     */
    private const val MAX_ITEM_BYTES = 150L * 1024 * 1024

    /**
     * Extract a share, or return null when this intent is not one.
     *
     * Never throws. A share that cannot be read must become a refusal a person
     * can see, not an exception on the way into the app.
     */
    fun extract(context: Context, intent: Intent?): Map<String, Any?>? {
        if (intent == null) return null

        val uris: List<Uri> = when (intent.action) {
            Intent.ACTION_SEND -> listOfNotNull(intent.getParcelableExtra(Intent.EXTRA_STREAM))
            Intent.ACTION_SEND_MULTIPLE ->
                intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM) ?: emptyList()
            else -> return null
        }

        val text = intent.getStringExtra(Intent.EXTRA_TEXT)?.trim().orEmpty()
        val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT)?.trim().orEmpty()

        val payloads = ArrayList<Map<String, Any?>>()
        val refusals = ArrayList<String>()

        if (text.isNotEmpty()) {
            payloads.add(
                mapOf(
                    // "url" vs "text" is a SHAPE, not a judgement — it decides
                    // whether Aura offers a link preview, nothing more. The
                    // text is carried through whichever it is.
                    "kind" to if (looksLikeSingleUrl(text)) "url" else "text",
                    "text" to text,
                ),
            )
        }

        for (uri in uris) {
            val payload = copyIn(context, uri, refusals)
            if (payload != null) payloads.add(payload)
        }

        if (payloads.isEmpty() && refusals.isEmpty()) return null

        Log.i(TAG, "extract: ${payloads.size} payload(s), ${refusals.size} refusal(s)")
        return mapOf(
            "platform" to "android",
            "payloads" to payloads,
            "refusals" to refusals,
            "receivedAt" to System.currentTimeMillis(),
            "subject" to subject.ifEmpty { null },
        )
    }

    /**
     * Take one item into Aura's own cache while the grant is alive.
     *
     * Returns null and records a refusal when it cannot, because an item that
     * disappears between the share sheet and the composer looks exactly like
     * Aura having lost it.
     */
    private fun copyIn(
        context: Context,
        uri: Uri,
        refusals: MutableList<String>,
    ): Map<String, Any?>? {
        val resolver: ContentResolver = context.contentResolver
        var displayName: String? = null
        var declaredSize: Long = -1

        try {
            resolver.query(uri, null, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (nameIndex >= 0 && !cursor.isNull(nameIndex)) {
                        displayName = cursor.getString(nameIndex)
                    }
                    val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                    if (sizeIndex >= 0 && !cursor.isNull(sizeIndex)) {
                        declaredSize = cursor.getLong(sizeIndex)
                    }
                }
            }
        } catch (t: Throwable) {
            // Not fatal: a provider that will not describe its own item may
            // still let it be read.
            Log.w(TAG, "query failed for $uri: ${t.message}")
        }

        // Refused BEFORE a single byte is read. The size the provider states is
        // a claim like everything else here, so the copy below enforces the
        // same ceiling again on what actually arrives.
        if (declaredSize > MAX_ITEM_BYTES) {
            refusals.add(tooLarge(displayName))
            return null
        }

        val name = displayName
        val target = File(cacheDir(context), "${System.nanoTime()}-${safeName(name)}")

        var copied = 0L
        try {
            resolver.openInputStream(uri).use { input ->
                if (input == null) {
                    refusals.add(unreadable(name))
                    return null
                }
                target.outputStream().use { output ->
                    val buffer = ByteArray(64 * 1024)
                    while (true) {
                        val read = input.read(buffer)
                        if (read <= 0) break
                        copied += read
                        if (copied > MAX_ITEM_BYTES) {
                            // A provider that under-reported its own size, or
                            // did not report one at all. Stop and clean up
                            // rather than filling the cache.
                            output.close()
                            target.delete()
                            refusals.add(tooLarge(name))
                            return null
                        }
                        output.write(buffer, 0, read)
                    }
                }
            }
        } catch (t: Throwable) {
            Log.w(TAG, "copy failed for $uri: ${t.message}")
            target.delete()
            refusals.add(unreadable(name))
            return null
        }

        if (copied == 0L) {
            target.delete()
            refusals.add("One item arrived empty and was not kept.")
            return null
        }

        return mapOf(
            "kind" to "file",
            "filePath" to target.absolutePath,
            // WHAT THE SHARING APPLICATION CLAIMS. Passed on as a hint and
            // nothing more; Dart resolves the real type from the bytes.
            "declaredMimeType" to resolver.getType(uri),
            "fileName" to name,
            "sourceUri" to uri.toString(),
            "sizeBytes" to copied,
        )
    }

    /**
     * Aura's own cache, emptied on entry.
     *
     * Content someone shared and then abandoned must not sit on their device
     * indefinitely. Clearing on the way IN rather than on the way out means it
     * happens even when the app is killed mid-share, which is exactly when an
     * exit-time cleanup would not run.
     */
    private fun cacheDir(context: Context): File {
        val dir = File(context.cacheDir, CACHE_DIR)
        if (!dir.exists()) dir.mkdirs()
        return dir
    }

    fun clearCache(context: Context) {
        try {
            File(context.cacheDir, CACHE_DIR).listFiles()?.forEach { it.delete() }
        } catch (t: Throwable) {
            Log.w(TAG, "cache clear failed: ${t.message}")
        }
    }

    /** Keep it recognisable to the person, and safe as a filename. */
    private fun safeName(name: String?): String {
        val cleaned = (name ?: "item").replace(Regex("[^A-Za-z0-9._-]"), "")
        return if (cleaned.isEmpty()) "item" else cleaned.take(80)
    }

    private fun tooLarge(name: String?) =
        "${describe(name)} is too large to share into Aura."

    private fun unreadable(name: String?) =
        "${describe(name)} could not be read from the app that shared it."

    private fun describe(name: String?) =
        if (name.isNullOrBlank()) "One item" else name

    /**
     * Whether the shared text is a bare link.
     *
     * Deliberately strict: one token, and a scheme Aura would actually follow.
     * A sentence that happens to contain a URL is text a person wrote, and
     * treating it as a link would quietly discard their words.
     */
    private fun looksLikeSingleUrl(text: String): Boolean {
        if (text.contains(Regex("\\s"))) return false
        val lower = text.lowercase()
        return lower.startsWith("https://") || lower.startsWith("http://")
    }
}
