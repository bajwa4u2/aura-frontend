# Public-First Doctrine — Public Representation Reconciliation

**Date:** 2026-09-04 · **Status: CLOSED IN SOURCE across both repositories. Deployed. Zero residuals.**

Third and final pass of the public-first reconciliation begun on 2026-08-15.

| Pass | Date | Scope | Left behind |
|---|---|---|---|
| 1 | 2026-08-15 | Dart entry/auth/shell surfaces + `pubspec.yaml` | web metadata layer, publication surfaces, deck source, the white paper itself |
| 2 | 2026-09-04 | web metadata layer (`web/index.html`, `web/manifest.json`, route generator) | 3 rendered-content residuals, raised for authorisation |
| 3 | 2026-09-04 | those residuals + deck source + the white paper document + deploy | nothing |

Founder-authorised, pass 3, as a **bounded doctrine correction with deploy authority**. No layout,
no navigation, no visual system, no page architecture, no product features, no institution-specific
journeys.

Identity authority: `representation/inventory/PRODUCT_IDENTITY_CANON.md` (Aura section, founder-
approved public-first correction 2026-08-15) and `representation/inventory/AURA_PUBLIC_FIRST_CAUSAL_DOCTRINE.md`.
**No new positioning was invented in any pass.** The general expression below is a compression of
the canon's Aura Identity paragraph.

---

## Root cause

The 2026-08-15 gate (`test/doctrine/public_first_causal_gate_test.dart`) scans a **named list** of
general surfaces. The list was Dart entry surfaces plus `pubspec.yaml`. Three whole layers sat
outside it:

- **The web metadata layer** — the shell that every crawler, social preview and PWA install prompt
  reads, before a single Flutter frame renders.
- **Publication and company surfaces** — the white paper hero, the investors architecture block.
  These speak for Aura as loudly as the entry surfaces do.
- **Deck source and the white paper document** — the upstream copy that reseeds everything else.

There was also **no single general authority** in the web layer. `web/index.html` declared the
general defaults, and `tool/web/generate_route_metadata.dart` declared a *second* general default of
its own (`imageAlt ?? 'Aura Platform — institution operating infrastructure'`). Two defaults are two
authorities; correcting one would have left the other live on every route's social card.

## Surface classification

| Surface | Class | Disposition |
|---|---|---|
| `web/index.html` title · description · og:* · twitter:* (8 tags) | **GENERAL / PUBLIC-ENTRY** | Corrected |
| `web/index.html` JSON-LD Organization description | **COMPANY** (delivered on every route) | Aura identity clause corrected; corporate framing kept |
| `web/manifest.json` description | **GENERAL** (PWA install) | Corrected to the exact `pubspec.yaml` text |
| generator hardcoded `imageAlt` default | **GENERAL default** | **Removed.** Now inherits from the shell |
| `white_paper_screen.dart` hero + version chips | **GENERAL / PUBLICATION** | Corrected |
| `investors_hub_screen.dart` Aura tagline | **COMPANY** | Corrected |
| `aura_publication_hero.dart` doc-comment exemplar | **SHARED COMPONENT** | Corrected, after the surface it documents |
| `docs/business_deck/` (2 files) | **DECK SOURCE** | Reconciled **and** explicitly superseded |
| `aura-backend/mission/white-paper.md` | **PUBLICATION** | Reconciled as a versioned supersession, v1.1 → v1.2 |
| `/investors`, `/founder`, `/patrons` route metadata | **COMPANY** | Aura identity clause corrected only |
| `/institutions` route metadata | **INSTITUTION-SPECIFIC** | Institutional framing **preserved**; identity clause corrected |
| `/white-paper` route metadata | **GENERAL / PRODUCT** | Corrected |
| `/privacy`, `/terms` crawler-visible bodies | **LEGAL** | Identity clause corrected; legal meaning unchanged |
| `/mission`, `/supporters`, `/contact`, `/child-safety`, `/account-deletion` | COMPANY / LEGAL | No institution-first framing present. Untouched |
| `institution_post_composer_screen.dart:193` | **INSTITUTION-OWNED** | Untouched, as ruled on 2026-08-15 |

## The general expression

Compressed from `PRODUCT_IDENTITY_CANON` → Aura → Identity.

| Tag | After |
|---|---|
| `title` | Aura Platform — Public-First Communication and Civic Discourse |
| `description` | Aura is a public-first platform for civic discourse and accountable communication. People take part in purposeful communication that keeps its context, and institutions enter under clear identity, accountable for what they say officially. |
| `og:description` / `twitter:description` | A public-first platform for civic discourse and accountable communication. People take part in purposeful communication that keeps its context; institutions enter under clear identity. |
| `og:image:alt` / `twitter:image:alt` | Aura Platform — public-first civic discourse and accountable communication |
| `manifest` description | *(exact `pubspec.yaml` text, unchanged from the 2026-08-15 approval)* |
| white paper hero | **Public–institutional alignment.** — *How Aura keeps identity, authority, and outcomes connected on one accountable record, so public reality and institutional responsibility stay aligned in both directions.* |
| investors architecture, Aura | Public-first civic discourse and accountable communication — people take part, institutions enter under clear identity. |

## Authority fix, not a literal fix

`_RouteMeta.imageAlt` is now nullable and **null means inherit**: `_substitutions` omits the key,
`_applySubstitutions` leaves the tag untouched, and the route keeps whatever `web/index.html`
declares. The generator no longer holds a general default of any kind. Verified: `/institutions`
renders the shell's corrected alt text without declaring one.

## The white paper — superseded, not silently rewritten

`aura-backend/mission/white-paper.md` is a **versioned, dated publication**, and it was the deepest
source of the drift: correcting the page hero alone would have left the hero public-first and the
first paragraph below it institution-first.

It is now **v1.2 (September 4, 2026), superseding v1.1 (February 27, 2026)**, carrying an inline
note that states exactly what changed and why. Two sentences moved — the document subtitle and the
Executive Summary's identity sentence. **The argument, principles, architecture and conclusions are
untouched**, and they did not need touching: v1.1's own thesis was already symmetric ("align public
reality with institutional systems, and institutional systems with public reality"). Only the label
above the argument had drifted.

The screen's version chips and colophon, which still read **Version 1.0 · May 2026** against a
document that had said v1.1 since February, were reconciled to v1.2 · September 2026 in the same
pass.

> **`mission/white-paper.pdf` is NOT regenerated.** It is dated 21 May 2026 while the markdown was
> last edited 18 June 2026, so **the PDF was already stale before this pass** and no generator for
> it exists anywhere in the repository. This widens a divergence that already existed; it does not
> create one. Regenerating it needs a toolchain decision and is raised, not taken.

## Deck source cannot reseed

`docs/business_deck/README.md` and `docs/business_deck/source/aura_platform_business_deck_master.md`
were the upstream that fed institution-first language into investor and public material for three
weeks after the canon was corrected. Both now carry a header:

> **IDENTITY IS NOT AUTHORED HERE — SUPERSEDED 2026-09-04.**

They are reconciled *and* explicitly demoted: deck source, never positioning authority.

**One guardrail deliberately preserved.** The deck's line *"Aura should be presented as institution
operating infrastructure, not a consumer social media app"* carried a real boundary inside a wrong
identity. The identity was corrected; the boundary was kept and made explicit — public-first
describes who the product originates from, not a change of category, and consumer-social framing
remains wrong for Aura.

## Anti-drift gate, extended

`test/doctrine/public_first_causal_gate_test.dart` — now **5 tests**, all passing. Scope grew from
8 surfaces to 15.

- Added: `web/index.html`, `web/manifest.json`, `white_paper_screen.dart`,
  `investors_hub_screen.dart`, `mission_screen.dart`, `patrons_hub_screen.dart`,
  `aura_publication_hero.dart`.
- New test — **the route generator declares no general default of its own.** Asserts the
  `imageAlt ??` fallback is absent and the inherit-when-null substitution is present.
- New test — **deck source cannot reseed the superseded identity.** Asserts both deck files still
  carry the supersession notice and still name the canon. They are deliberately *not* phrase-scanned,
  because a supersession notice must quote the retired wording in order to retire it.
- The generator itself is still deliberately **not** scanned — it legitimately carries
  institution-specific route copy for `/institutions`. The rule remains "fix the causality, not the
  vocabulary," and the out-of-scope test that proves the gate is scoped rather than global still
  passes.

## Verification

- Gate: **5/5 pass.**
- `dart analyze` on every changed Dart file: no new issues.
- `flutter build web --release` succeeds, then `dart run tool/web/generate_route_metadata.dart`
  against the real build: **13 route documents rendered, 0 institution-first hits.**
- Whitespace-normalised scan (`institution operating infrastructure`, `system an institution runs`,
  `member-facing life`, `continuity infrastructure for institutions`) across `.dart` / `.html` /
  `.json` / `.yaml` / `.md`: **0 hits outside the gate's own prohibition table, the audit records
  that quote the retired wording, and the one institution-owned code comment.** Two line-split
  occurrences (`/terms`, `/privacy`) that a single-line grep missed were found by the normalised
  scan.
- Live before-state captured 2026-09-04, ahead of deploy: `auraplatform.org/`, `/institutions/` and
  `/white-paper/` all served `Aura Platform — institution operating infrastructure`.

**App Store listing checked and found already compliant.** `Aura Platform` is live at **1.3.0 (24)**
(id `6772071135`), and its store description opens *"Aura is a public discourse and institutional
communication platform designed for meaningful participation, accountable publishing, and long-term
civic presence."* — people first, institutions second, no institution-first identity claim. **No
correction needed there.** Two observations recorded rather than acted on: the primary category is
`Social Networking`, which sits in tension with the deck guardrail above, and the seller name is the
individual `MUHAMMAD SAKHAWAT` rather than Aura Platform LLC.

## The failing suite was a corrupt cache, not a dependency problem

The first full run was 2030 passed / 58 failed, every failure a `Failed to load` compile error
inside pub-cache packages. That diagnosis was wrong in an instructive way.

Twenty package directories in the global pub cache (`AppData/Local/Pub/Cache/hosted/pub.dev`)
**existed but were empty** — `firebase_core-3.15.2`, `flutter_webrtc-1.4.1`,
`device_info_plus-11.5.0`, `wakelock_plus-1.3.3`, `desktop_drop-0.7.1`, `pasteboard-0.5.0` and every
`*_windows` / `*_linux` federated implementation. **`flutter pub get` sees the directory and assumes
the package is installed**, so it repairs nothing and `pubspec.lock` never changes. Two symptoms
followed: `flutter test` rewrote the desktop plugin registrants and **stripped every plugin** from
`windows/`, `linux/` and `macos/`, and `flutter build web` failed outright with
`Error reading … (The system cannot find the path specified)`.

**Repaired** by removing the twenty empty directories and re-running `flutter pub get`.
`pubspec.lock` is byte-identical before and after, so nothing was upgraded. The web build then
succeeded and the registrants stopped churning. Worth recognising on sight: an empty cache directory
presents as a dependency-version failure and is not one.

Remaining after the repair: **6 golden-image failures in `test/admin/operator_render_harness_test.dart`**
(for example `goldens/operator/integrity_report_w1024.png`, 0.01%, 82px). **Pre-existing and
untouched** — the failure artefacts under `test/admin/failures/` are dated 31 August 2026, days
before this work, no admin code was modified in any pass, and nothing changed here renders an
operator integrity report.

## Deployment

Both repositories auto-deploy from `main` on push (Railway). `aura_final`'s Dockerfile runs
`flutter build web` and then `dart run tool/web/generate_route_metadata.dart`, so the route variants
are produced in the image. `aura-backend`'s Dockerfile copies `mission/` into the final image and
`WhitepaperController` serves it from disk, so the white paper ships with the backend.

> **`aura_final/nginx.conf` is NOT the deployed config.** The Dockerfile deletes `default.conf` and
> generates the real template inline. Editing that file is a silent no-op. Nothing in this pass
> needed it.
