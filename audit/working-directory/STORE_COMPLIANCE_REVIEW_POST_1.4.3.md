# Store compliance review — carried out against Aura after 1.4.3 (38)

**Date:** 2026-09-11
**Trigger:** the Colophon session cleared four store blockers and passed them over,
on the reasoning that Aura ships to the same three stores under the same rules.
**Scope:** checks only. Nothing here was changed, and nothing here touches the
frozen 1.4.3 source or Apple build 38.

    APPLIES_TO_BUILD_38          NO — see finding 1, which is latent, not live
    CHANGES_MADE_THIS_REVIEW     NONE
    FROZEN_SOURCE_TOUCHED        NONE

---

## 1. External payment for digital goods — LATENT, NOT LIVE

    STATUS   REAL EXPOSURE, CURRENTLY UNREACHABLE IN PRODUCTION
    RISK     A SERVER-SIDE CONFIG FLIP MAKES A SHIPPED, APPROVED BINARY NON-COMPLIANT

Aura already implements the resolution the founder chose for Colophon:
`institution_billing_screen.dart` computes `_purchaseAllowed`, which is `false`
on iOS and Android and `true` on web and desktop. Mobile therefore mints no
checkout session.

What it renders *instead* on mobile is the problem. With monetization enabled,
an iOS or Android device shows:

  * `_MobilePurchaseNotice` — a card headed **"Manage your plan on the web"**
    whose body names **app.auraplatform.org** and instructs the reader to sign
    in there to update billing;
  * credit packs rendering `pack.displayPrice` — a real price — beside a
    disabled button labelled **"Web only"**.

Both are steering as Apple reads it (3.1.1 / 3.1.3) and as Play Billing policy
reads it. A price beside a disabled button is steering; a polite sentence
pointing at a website is the violation phrased politely. Orchestrate has already
taken a rejection in this family (3.1.2).

**Why build 38 is not exposed.** Production answers
`GET /v1/monetization/config` with `monetizationMode: "disabled"`, every credit
pack at `credits: 0` / `displayPrice: null`, and all four providers
`enabled: false`. The screen early-returns on `MonetizationMode.disabled` before
any of the above is built, and `_CreditPacksSection` filters `credits > 0` to
empty. A reviewer opening institution billing on build 38 sees the disabled
state. Verified by fetching the live config, not by reading the default.

**The actual defect is the coupling.** Store compliance of an already-approved
binary currently depends on a server-side configuration value that can be
changed without any build, review, or release gate. Whoever enables monetization
enables the steering copy on every installed iOS and Android client at the same
instant.

Fix belongs in the next release and is one file: on mobile, render neither a
price nor any copy naming another channel, whatever the config says. Keep the
rule in one place rather than a `kIsWeb` at each call site.

## 2. In-app account deletion — PASS

    BACKEND   DELETE /v1/users/me   (users.controller.ts:415)
    IN-APP    /account-deletion, reached from the Security screen
    WEB       https://auraplatform.org/account-deletion  — own route index, 200

Apple 5.1.1(v) wants in-app deletion wherever accounts can be created; Play wants
in-app *and* a web-reachable route. Both exist. The endpoint requires the current
password **and** a literal `confirmation: "DELETE"`, so a stolen JWT alone cannot
trigger it, and it soft-deletes, scrubs PII and revokes every session and device.

The modelling trap — promising "delete everything" over data that is append-only
or legally retained — is already handled: the privacy page states that deletion
removes account identity from public surfaces and that public records replied to
or referenced by other authors may be retained in anonymised form, and says why.

## 3. Privacy policy and terms at real URLs — PASS, and not by accident

Colophon's failure was an SPA fallback answering 200 for every path, so a real
document and a typo were indistinguishable to Play's automated policy checker.
Measured on Aura:

    /privacy                          200   12293 B   sha e8882043972f4d99
    /terms                            200   12064 B   sha bf6f1283e1ffe029
    /definitely-not-a-real-route-9182 200    9265 B   sha ec6aefc0c4996c82

Distinct bodies, distinct hashes. `/privacy` carries `<title>Privacy Policy —
Aura Platform</title>`, a canonical link, and the full policy prose inside a
`<noscript>` block — so a scanner that runs no JavaScript still reads a real
document. These are generated at build time by
`tool/web/generate_route_metadata.dart`.

**One thing to confirm before the next submission.** `/privacy-policy` and
`/legal` are *not* route indexes — both return the 9265-byte fallback. If any
store listing, or the App Privacy section, points at one of those rather than at
`/privacy`, Aura has Colophon's defect at the URL that actually gets scanned.
The listing URLs were not read as part of this review.

## 4. UGC reporting — PASS on surface, FAIL on the enumeration trap

The four things Apple 1.2 wants are present: filtering, blocking
(`POST`/`DELETE /v1/blocks/:userId`), reporting (`POST /v1/moderation/reports`,
model `ModerationReport`), and published contact. Reports reach a reviewable
operator state — an admin queue gated on `MODERATION_READ`, with status
transitions gated on `MODERATION_WRITE` and audited.

**The trap the Colophon session named is present.**
`ModerationService.validateTarget` is a bare existence check across nine target
types — POST, USER, MESSAGE, SPACE, THREAD, INSTITUTION, INSTITUTION_POST,
ANNOUNCEMENT, CONVERSATION_MESSAGE — and performs **no reachability check** at
all. It throws `NotFoundException` when the row is absent and proceeds when it
is present.

Consequences, for any authenticated user:

  * **Existence oracle over private objects.** `POST /v1/moderation/reports`
    with a guessed or observed id answers "does this exist?" for a message,
    conversation message, thread, space or institution the caller has no access
    to. The refusal echoes both the type and the id back.
  * **A report can be filed against content the reporter cannot see**, which is
    also a way to put unreachable objects into the moderation queue.

The fix is the reachability check, not a status-code change: the not-reachable
and the not-found answers must be **byte-identical**, and the test must assert on
the MESSAGE rather than the status code, because the difference is the oracle
whichever code carries it.

Not a store blocker and not a 1.4.3 regression — it predates this release. It is
a backend-only change, which means it *could* ship without touching the frozen
client; whether to do that now is the founder's call, not this review's.

---

## The three implementation traps, checked

**flutter_svg ignoring CSS class selectors — NOT APPLICABLE.** Aura ships two
SVG assets and neither contains a `<style>` block or a `class=` attribute, so the
silent fall-back-to-black cannot occur. Re-check if an SVG is ever added from a
design tool that emits CSS classes.

**Relative URLs in `Image.network` — ALREADY SOLVED, DELIBERATELY.**
`identityDeliveryUrl` (`src/media/identity-delivery.ts`) builds an **absolute**
URL and returns `null` rather than a relative one when no API origin is
configured, with the reason written at the call site: *"A half-configured
environment must not rewrite live identity fields into relative paths that render
as broken images."* The relative `identityDeliveryPath` is an internal helper.

One residual, latent and unreached: `me_screen.dart:1920` resolves a schemeless
URL with `Uri.base.origin`, which on native is a `file:` URI and **throws** a
`StateError` rather than producing a wrong URL. It is unreachable today because
it returns early on `uri.hasScheme`, which every server-supplied URL satisfies.
It is also a second, divergent copy of the resolver in
`post_card.dart:193`, which uses `UPLOADS_BASE_URL` instead — two resolvers
disagreeing about the same question.

**nginx directory redirect — NOT PRESENT.** `/privacy` and `/privacy/` both
answer 200 directly with no 301, so the `$scheme://$host:$port` canonicalisation
that sent Colophon to `http://host:8080/` and a 522 does not occur here.

**Immutable cache on an unhashed root icon — PRESENT.**

    /favicon.ico   Cache-Control: max-age=2592000
                   Cache-Control: public, max-age=2592000, immutable
    /main.dart.js  Cache-Control: no-cache

The icon is unhashed and marked `immutable` for 30 days, so a rebrand or icon
change would be pinned at the edge and in browsers for up to a month after
deploy. Harmless until the icon changes — and invisible precisely when it
matters. Note also the **duplicated** `Cache-Control` header, which suggests an
nginx `add_header` and an edge rule both setting it.

---

## Disposition

    FINDING 1  external payment steering    NEXT RELEASE — latent today
    FINDING 2  account deletion             PASS
    FINDING 3  policy URLs                  PASS — confirm the listing URLs
    FINDING 4  reporting enumeration oracle NEXT RELEASE — backend-only fix
    TRAP       favicon immutable cache      fix before any icon change

Nothing here requires build 39, and nothing here was changed in this review.
