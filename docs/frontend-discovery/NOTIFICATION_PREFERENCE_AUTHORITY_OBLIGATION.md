# Notification Preference Authority — Roadmap Obligation

**Founder-surfaced 2026-08-15, after C0 authorisation.** Recorded so it is not lost.

> **PRIMARY OWNER: C4 — ATTENTION.** Not implemented during C0. **C4 is not started.**
> **C0 scope is unchanged by this addition.**

---

## Why C4 owns it

Notification preferences govern **how attention is delivered and whether it interrupts**. They are not an Account Settings visual concern.

## Governing distinction *(frozen)*

> **ATTENTION EXISTENCE ≠ DELIVERY CHANNEL ≠ INTERRUPTION.**

Disabling email or push must **never erase the underlying governed Attention item**.

```
Meeting invitation exists      → remains in Attention
Email disabled                 → no email delivery
Push disabled                  → no push interruption
The underlying invitation/action → REMAINS
```

Preferences control **delivery and/or interruption** — never whether the domain event or obligation exists. FD-1/FD-2 remain authoritative: the primary badge still means **unresolved actionable obligations**.

## Scope for C4

A canonical **Notification Preference Authority** covering, where legitimately supported: in-app attention · native/mobile push · web push · **Windows/MSIX WNS** · email · future approved channels.

The model must be based on **meaningful product/attention semantics**, not raw implementation event names.

**Preference domains to investigate** (not frozen — audit the canonical notification taxonomy first): DM/messages · Thread/Space communication · mentions/replies · relationships/follows · Meeting invitations/changes · Institution Room invitations · future Live invitations/starts · institutional approvals · moderation/admin attention · publication attention · account/system/security.

## Account vs device — must not collapse

| Level | Meaning |
|---|---|
| **ACCOUNT-LEVEL PREFERENCE** | what kinds of attention/delivery the person wants generally |
| **DEVICE/PLATFORM STATE** | whether this device/channel can actually deliver it |

*"Push enabled for my account"* is **not** *"this browser/device currently has push permission and a valid subscription."*

## Account Settings surface

The Settings screen is a **CONSUMER** of the preference authority. **It must not own notification semantics.**

Audit for: duplicate preferences · stale switches · channel/event mismatches · settings with no runtime effect · runtime behaviour with no setting · personal vs institution ambiguity · device-specific settings shown as account-wide · account-wide settings stored per device · email/in-app/push inconsistencies.

Then classify the Settings surface itself: **PRESERVE / SIMPLIFY / REFACTOR / DEMOLISH + REBUILD** — from evidence. **No new roadmap chapter unless the broader Settings audit proves one is warranted.**

## Chapter relationships

| Chapter | Owns |
|---|---|
| **C4 — Attention** | **preference semantics** (primary owner) |
| **C3 — Navigation & IA** | where Settings live · how preferences are reached · account/profile/settings IA · contextual entry from notification/permission states. **Does NOT own preference semantics.** |
| **C9 — Cross-Platform** | platform delivery realities — WNS/OS permission (MSIX) · APNS/FCM/device permission/background (mobile) · browser push permission/subscription (web). **Must not invent per-platform preference semantics.** |
| **C1 / FD-9** | acting context where institution-specific preference semantics apply |

## Open questions for C4 *(do not decide silently)*

1. **Are preferences personal, institution-specific for an operator, institution-admin policy, device-level, or a governed combination?** Do not infer from today's Settings UI. If multiple legitimate models exist, **bring to founder during C4**.
2. **Which notification classes are not legitimately user-suppressible?** (account/security · critical lifecycle · legal/compliance · system-critical.) **Do not decide from UI convenience.** If backend/product doctrine does not already define them, surface the policy decision.

## Enforcement (FD-13)

Migrate all consumers · prevent local notification-channel preference logic reappearing · prevent surfaces independently deciding email/push/in-app behaviour · hard structural enforcement with narrow explicit exceptions · test preference-to-delivery behaviour.

## Item 17

Must later certify integrated preference behaviour across in-app · push/native · email · devices/platforms · account/settings UI · attention persistence · actionable resolution.
