package org.auraplatform.app

import android.os.Build

/**
 * WHAT AURA IS PERMITTED TO DO WITH THE SYSTEM CALL STACK ON THIS DEVICE.
 *
 * ── THIS IS NOT THE ANDROID TWIN OF THE iOS GATE, AND MUST NOT BECOME ONE ──
 *
 * `CallCapabilityPolicy.swift` exists because Apple issued a real,
 * storefront-specific instruction: MIIT requires CallKit to be inactive in apps
 * distributed through the China mainland App Store, and Apple enforced it
 * against Aura 1.4.0 (35) under Guideline 5. There is a rule, it names a
 * territory, and it attaches to the storefront. So iOS has a gate.
 *
 * **No equivalent Android restriction is known.** `MANAGE_OWN_CALLS` is the
 * ordinary permission a self-managed VoIP app needs for
 * `CallsManager.addCall()`. Play's special restrictions apply to the Call Log
 * permissions — `READ_CALL_LOG`, `WRITE_CALL_LOG`, `PROCESS_OUTGOING_CALLS` —
 * which Aura does not request and does not need, because Aura writes no
 * call-log rows.
 *
 * Founder ruling, 2026-09-04: `ANDROID_TELECOM_PLATFORM_JURISDICTION_GATE =
 * NONE`. The model is **no known restriction → feature available**, not
 * *unknown restriction → invent a gate*. Manufacturing an Android
 * jurisdiction rule out of caution would remove a system call experience from
 * territories nobody asked us to remove it from, on the strength of a rule
 * nobody has written.
 *
 * ── WHAT THIS IS INSTEAD ──────────────────────────────────────────────────
 *
 * A general capability policy, present and empty. It exists so that if Google,
 * Android, a jurisdiction or Aura's own product configuration ever DOES
 * establish a restriction, there is one place it lands and one predicate every
 * caller already asks — rather than a scramble to add gating to a shipped
 * calling feature. That is the lesson of the Apple rejection: the gate should
 * exist before the evidence does, and stay empty until it arrives.
 *
 * ── WHAT MUST NEVER BE USED HERE ──────────────────────────────────────────
 *
 * Locale, timezone, SIM country code and IP geography. Each of them describes
 * where a handset currently is, which is a different question from which
 * jurisdiction's rule binds the distribution — the exact reasoning the iOS
 * policy file sets out at length. If a real rule ever requires one of those
 * signals, it will say so, and then it may be read for that reason and no
 * other.
 */
object CallCapabilityPolicy {

    /** What the current policy permits of native Telecom participation. */
    enum class TelecomCapability {
        /** Nothing forbids it. The ordinary state. */
        AVAILABLE,

        /** A restriction applies. Nothing populates this today. */
        RESTRICTED,

        /** The platform cannot support it — genuinely a capability fact. */
        UNSUPPORTED;

        val allowsTelecom: Boolean get() = this == AVAILABLE
    }

    /**
     * Restrictions established by evidence. **Deliberately empty.**
     *
     * A restriction belongs here when there is a rule to cite — a store
     * policy, a platform requirement, a legal instruction, or a deliberate
     * Aura product configuration. Speculation does not qualify, and neither
     * does symmetry with another platform.
     */
    private val establishedRestrictions: List<Restriction> = emptyList()

    /**
     * One reason native Telecom participation is withheld.
     *
     * [evidence] is required, and is the point of the type: a restriction that
     * cannot name what established it is a restriction nobody can review,
     * revisit, or remove.
     */
    data class Restriction(
        val id: String,
        val evidence: String,
        val applies: () -> Boolean,
    )

    /**
     * Aura's own switch, independent of any external rule.
     *
     * Set false to take Aura off the system call stack entirely — a product
     * or incident control, not a jurisdiction one. The certified
     * notification ring is unaffected either way, because it is not built on
     * this.
     */
    var productEnabled: Boolean = true

    /** The only thing callers should ask. */
    fun telecomCapability(): TelecomCapability {
        // A platform fact rather than a policy: Core-Telecom needs the
        // self-managed Telecom stack, which arrived in Android 8.0.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return TelecomCapability.UNSUPPORTED
        }
        if (!productEnabled) return TelecomCapability.RESTRICTED
        if (establishedRestrictions.any { it.applies() }) {
            return TelecomCapability.RESTRICTED
        }
        return TelecomCapability.AVAILABLE
    }

    /** Why it is withheld, when it is. Null when it is not. */
    fun withheldBecause(): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return "This version of Android has no self-managed call support."
        }
        if (!productEnabled) return "Native call integration is turned off."
        return establishedRestrictions.firstOrNull { it.applies() }?.evidence
    }
}
