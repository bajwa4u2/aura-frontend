# `/deck` and `/demo` — Aura readiness surfaces

*(Kept in `docs/` deliberately: everything under `web/` is copied into the served bundle.)*

Two durable, reusable pages served from `auraplatform.org`. **Readiness assets, not
application-specific pages** — they are not written for any one program, investor or submission,
and nothing on them should be edited to suit one.

| Path | File | What it is |
|---|---|---|
| `/deck` | `web/deck/index.html` | **Business and investment case**: the condition, the market, who pays, the monetization architecture, and the current commercial stage |
| `/demo` | `web/demo/index.html` | The product's own surfaces, rendered at real density |
| — | `web/shared/aura.css` | Page frame, tokens, the causal spine, typed chips |
| — | `web/shared/aura-surfaces.css` | The publication card and the other product surfaces |

## How they are served

**No nginx or Dockerfile change was needed.** The generated config's SPA fallback is
`try_files $uri $uri/index.html $uri/ /index.html`, so `/deck` resolves to `web/deck/index.html`
via the second term, and `/shared/aura.css` via the first. Neither path collides with a Flutter
route.

> `aura_final/nginx.conf` is in the repo but is **NOT deployed**. The Dockerfile deletes
> `default.conf` and generates the real template inline. Editing that file is a silent no-op that
> a local container test would still pass.

## Where the design comes from

Nothing here was invented.

- **Palette** — `lib/core/ui/aura_surface.dart`, the only live palette (imported by 268 files).
  `lib/core/ui/aura_theme.dart` is dead code and its lighter grey palette is **not** the product's.
- **Type, spacing, radii** — `aura_text.dart`, `aura_space.dart`, `aura_radius.dart`.
- **Publication card** — `lib/features/feed/presentation/unified_feed_card.dart`, including the
  details that carry meaning: an Announcement's 1.5px accent edge against a normal card's 1px, the
  13px top padding that keeps that edge load-bearing, the `OFFICIAL · ANNOUNCEMENT` eyebrow, and
  the time decay that drops border alpha 0.45 → 0.28 → plain divider and eyebrow opacity
  1.0 → 0.85 → 0.65 across ≤24h / 24–72h / >72h.
- **Identity chips** — `lib/shared/identity/aura_identity_badge.dart` tones, including the teal
  official and violet admin.
- **Engagement row** — `lib/core/engagement/aura_engagement_bar.dart`: React, breakdown, Save.
- **Typed state chips** — `lib/core/ui/substrate_chip.dart`: mono, uppercase, literal enum value,
  colour never the only signal.
- **Vocabulary** — `docs/frontend-discovery/C0_PRODUCT_LANGUAGE_VOCABULARY.md`. Person, Institution,
  Member, Participant, Thread, Space, Meeting, Live, Message, Correspondence, Post, Announcement.
  Never "user", never "Connect", never a generic verification label.
- **Narrative order** — `representation/inventory/AURA_PUBLIC_FIRST_CAUSAL_DOCTRINE.md`, and the
  identity statement is compressed from `representation/inventory/PRODUCT_IDENTITY_CANON.md`.
- **Register** — `company/visuals/visual-language/presentation-registers.md`: dark, mixed type,
  reveal-only motion, medium density. Product-level, so Aura's own accent, not company `co/teal`.

## /deck is the business case, not a second demo

It was a product brief until 2026-09-04, and the founder caught the flaw: five of its seven
sections restated `/demo` in prose. The two now do different jobs — **`/demo` is the product proof,
`/deck` is the commercial argument** — and nothing should push the deck back toward describing
capabilities.

**Everything commercial on it is audited, not asserted.** Sources, all first-hand:

- `aura-backend/src/monetization/` — the plan and credit architecture, four payment providers
  (Stripe, Apple IAP, Google Play, Microsoft Store) behind one internal product-code layer.
- `monetization-config.service.ts` — the **FREE + PRO taxonomy frozen 2026-08-16**, with `PRO`
  carrying exactly one capability, `canSpeakOfficially`, plus member capacity. The comment there
  also records that the final Free/Pro boundary is **not decided** and enforcement is not to be
  activated before founder adjudication.
- `monetization.types.ts` — the credit-metered features (AI composition, translation, realtime by
  the minute), and the deletion of `hasAiEditor` / `hasTranslation` / `hasRealtime` from the plan
  capability map so that "dead booleans" could never become accidental pricing doctrine.
- `monetization-verification-boundary.spec.ts` — the founder ruling that **verification is not
  purchasable and trust is not for sale**, pinned by a test that fails the build.
- `representation/inventory/COMMERCIAL_MARKET_SIZING_EVIDENCE.md` — the only numbers on the page:
  1,313 Michigan / 46,082 U.S. core, 73,065 U.S. expanded, all NAICS 813410 + 813910 + 813920
  (+ 813319 + 813990 expanded), 2023 County Business Patterns. That document also forbids calling
  73,065 a TAM without saying it is an expanded proxy, which the page does.
- `representation/inventory/COMMERCIALIZATION_AUDIENCE_BENEFIT_DOCTRINE.md` — the buyer definition
  and the canonical governing purpose, quoted verbatim.
- Production database and Railway configuration, read directly: `AURA_MONETIZATION_MODE` unset so
  the mode defaults to **disabled**, no payment-provider credential of any kind present, and zero
  rows in `InstitutionSubscription`, `PaymentTransaction`, `CreditTransaction` and
  `ProcessedWebhookEvent`. Three institutions, all `FREE`, all verified.

**No price appears anywhere on the deck**, and none should be added until the Free/Pro boundary is
adjudicated. The `$5` and `$20` tiers on `/support/:handle` are the person-side support surface,
whose own code says payments are a later integration; the deck describes it as a placed surface
rather than revenue, which is what it is.

## Rules these pages hold

- **`noindex, nofollow` on both**, and deliberately **no** `robots.txt` `Disallow` — a disallowed
  page is never crawled, so its noindex is never read. They are also kept out of `sitemap.xml`.
- **The reveal is opt-in.** `.rv` is hidden only under a `js-reveal` class that a head script adds,
  and only when scripting is available and motion is allowed. Hiding by default would mean a
  blocked or failed script leaves the page blank below the masthead. Verified: with the class
  removed, zero sections are hidden.
- **No horizontal scroll** at 345, 605 and 885 CSS px (measured in-page, not eyeballed), which
  covers 200% zoom on a 1280 viewport and ordinary mobile.
- **Illustrative content is labelled as such.** The names, text and timestamps in `/demo` are
  invented; the surfaces, states and rules are the product's. No real institution is depicted, and
  no number is stated without its source.
- **The stage is stated honestly.** `/deck` says plainly that Aura is pre-revenue with no pricing
  and no paying customers, and claims live status only for iOS and the web.

## Editing them

Change the client first, then these. If a token, chip tone or card rule moves in `lib/`, it has
moved here too and this page is now lying about the product. The comments at the top of both
stylesheets name the exact source file for every value.
