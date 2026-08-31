# Aura Native Continuation & Acquisition — canonical record

**Status:** pre-release capability complete. No native build, store release or
rollout produced. Frozen 2026-08-31.

**Authority:** `contracts/native_continuation_contract.json`, vendored from
`company/platform-contracts/native-continuation/contract.json`. Also vendored
into `aura-backend/contracts/`. Byte-identity is enforced by
`company/tools/verify_vendored_contracts.py`.

---

## The doctrine this implements

> Every eligible public product URL is also a native-app acquisition and
> continuation surface. The canonical public URL is the identity.

```
CANONICAL PUBLIC URL
  -> PUBLIC OBJECT AUTHORITY   (aura-backend/src/share/shareable-objects.ts)
  -> SEARCH / SHARE            (/p/... crawler-reachable card)
  -> WEB RENDER                (share page, or the SPA route)
  -> OPEN / GET APP            (public_app_acquisition.dart)
  -> NATIVE APP                (App Links / Universal Links / App URI Handlers)
  -> SAME DESTINATION          (native_continuation.dart -> router redirect)
```

---

## What was actually wrong

The association layer was healthy and the product consequence was still broken.
That gap is the whole finding.

| # | Defect | Evidence |
|---|--------|----------|
| 1 | **Android claimed every URL on both hosts.** The intent filter had no path data, so private member surfaces were associated to the app. | manifest had `<data android:host=...>` with no path |
| 2 | **Flutter deep linking was off on both mobile platforms.** The OS handed the URL over and the framework dropped it, so every claimed link opened Aura **at home**. | `flutter_deeplinking_enabled` and `FlutterDeepLinkingEnabled` both absent |
| 3 | **iOS omitted `/p/*` entirely** — the family people actually share — while claiming `/threads/*`, retired long ago. | AASA components |
| 4 | **Windows had no association at all.** | no protocol, no App URI Handler, `main()` took no arguments |
| 5 | **The backend published `/join/:code`** as the destination for every shared meeting. No router declares that path, so it fell through to MEMBER and put a **login wall in front of an invited guest**. | one occurrence in `shareable-objects.ts`, zero in the client |
| 6 | **`/announcements/create` classified PUBLIC.** The broad `/announcements/` prefix swept in the composer — the same fault already fixed once for `/posts/:id/edit`. | `route_classification.dart` |
| 7 | **Open redirect at the auth boundary.** `?redirect=//evil.com/x` passed the "must start with `/`" guard; the authority also survived `uri.replace(path:)`. | `route_targets.dart` |
| 8 | **The web acquisition surface had its own eligibility list** of exact static paths — no dynamic family at all, so every shareable object page offered nothing while `/mission` offered the app. | `public_app_acquisition.dart` |

Digital Asset Links validated on both hosts throughout. **Association
infrastructure working is not continuation working**, and only #5 and #7 were
findable by reading a single file — the rest needed two authorities compared
against each other.

---

## Eligible route authority

Eligibility is `route_classification.dart` (founder ruling F069), never path
shape. `RouteClass.public`, `authAction` and `guestReachable` may be associated;
`member` may not.

**Canonical share families** (backend registry ↔ client resolver, both pinned to
the contract by test):

| Family | Canonical URL | In-app destination |
|---|---|---|
| USER_POST | `/p/:id` | `/posts/:id` |
| INSTITUTION_POST | `/p/i/:institutionId/:postId` | `/institutions/:institutionId/posts/:postId` |
| ANNOUNCEMENT | `/p/a/:slug` | `/announcements/:slug` |
| ARTICLE | `/p/art/:slug` | `/articles/:slug` |
| PERSON_PROFILE | `/p/u/:handle` | `/u/:handle` |
| INSTITUTION_PROFILE | `/p/org/:slug` | `/institutions/:slug` |
| MEETING | `/p/m/:code` | `/meetings/join/:code` *(was `/join/:code` — defect #5)* |

Two ordering hazards, both tested: `/p/:id` is a catch-all and must be matched
**last**; matching must be on whole **segments**, or `a` claims `/p/art/...`.

---

## Platform behaviour

| | Android | iOS | Windows |
|---|---|---|---|
| Mechanism | App Links, scoped intent filters | Universal Links, AASA components | App URI Handlers + `aura://` |
| Path scoping | `pathPrefix`, **no negation** | full, incl. `exclude` | **host only** |
| Link delivery | `flutter_deeplinking_enabled` | `FlutterDeepLinkingEnabled` | launch **argument** to `main()` |
| Exclusions enforced by | in-app classification | AASA + in-app | in-app only |

**Precise platform limits.** Android cannot express "`/posts/*` except
`*/edit`"; Windows cannot express paths at all. In both cases the contract's
exclusions are enforced in-app by route classification, which fails closed. This
is a real limit, not a shortcut: the OS will open the app for an excluded path
on those platforms, and the app then refuses to render it without authority.

**Windows package family name** `AuraPlatformLLC.AURAPLATFORM_4rrd19jbkq83a`,
derived from the repo's certified publisher. The algorithm was validated against
Microsoft's own published hash (`8wekyb3d8bbwe`) before use. **Confirm against
Partner Center → Product identity before the Windows association is relied on
in production** — a wrong family name fails silently.

---

## Same destination & auth return

A destination is preserved across the auth boundary in `?redirect=`, guarded by
`normalizeMemberFacingRoute`. After defect #7 the guard requires a
**site-relative** path: no scheme, no authority, no backslash.

Continuation resolves a **name**, never an authority. `/p/art/x` becomes
`/articles/x`; whether the visitor may read it is still decided by route
classification, the router's redirect, and the object's own visibility. Knowing
a URL has never been authorization here.

---

## Install return — what each platform can honestly do

| Platform | Reality |
|---|---|
| Android | Play does **not** provide install referrer to a web-originated install without Play Install Referrer wiring; exact post-install continuation is not available today. The destination stays on the web page the person came from, which remains fully usable. |
| iOS | The App Store provides **no** post-install destination channel. Same recovery: the web page. |
| Windows | Same. |

No platform is claimed to do more than it does. Where automatic continuation is
impossible the honest recovery is the public web page — which is why "public web
remains usable" is a contract term and not a nicety.

---

## Store review

Platform mechanisms only — Play In-App Review, `SKStoreReviewController`, and
the Microsoft Store listing for Windows, which has no in-app sheet. No custom
stars, no rewards, no gating, no sentiment filter. The platform APIs return no
outcome by design; an app that could observe one could act on it, and that is
manipulation.

Exactly **one** permitted moment (`settledAfterSuccessfulUse`). Every forbidden
moment is enumerated so it can be refused **by name**, and the moment is checked
before any usage threshold — no amount of happy use makes it acceptable to ask
during a call. Thresholds: 5 qualifying actions, 3 distinct days, 7 days since
first use, 120 days between prompts, 3 lifetime.

This is not the primary call to action and is subordinate to acquisition.

---

## Distribution truth

`Open` is offered only where a **released** client can route the destination.
Association being configured in this tree is a different fact, tracked
separately as `shippedInClient` — currently **false on all three platforms**,
because the released clients predate this work. Claiming `Open` now would open
the old client at home and lose the destination: the fake Open state the
contract forbids.

Android additionally offers **nothing**: Play production access has not been
granted, so a general visitor cannot install from that link.

---

## Release consequences (deferred by founder instruction)

- Every platform change here reaches people only through the next consolidated
  Aura build. Nothing was built.
- `shippedInClient` flips to `true` per platform **in the release that carries
  the capability**, not before.
- Confirm the Windows package family name against Partner Center.
- The AASA is served as `application/octet-stream`; Apple documents
  `application/json`. Served from the web deploy, not the app.
- **Separate debt, not Aura's:** the Orchestrate App Store icon is still the old
  two-arrow mark, correctable only by a future Orchestrate release candidate.
