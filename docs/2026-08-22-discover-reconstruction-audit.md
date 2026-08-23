# Discover — Reconstruction Audit (audit only, no implementation)

**2026-08-22.** Founder addendum: DISCOVER — FULL RECONSTRUCTION is MUST-CLOSE before
AURA RECONSTRUCTION — CLOSED. The addendum requires the existing system to be audited
before anything is changed. This is that audit. **Nothing here has been implemented.**

---

## 1. What the root actually is today

`lib/features/discover/presentation/discover_screen.dart` — **215 lines**, and its entire
body is:

```
Discover  (display title)
"Find people, institutions, spaces, and conversations across Aura."
[ search entry -> pushes /search ]
[ 4-card facet grid ]
```

`kDiscoveryDomains` is a **const list of four records** (icon, title, body, route). The
grid renders them as tap targets. There is **not one discoverable object on the screen**
— no person, no institution, no space, no article. The founder's description ("a
taxonomy/directory router", "four large category doors but almost nothing to actually
discover") is exact.

### The root's own frozen doctrine is partly stale

Its header comment still says Articles is *"declared-not-available (Long-Form Publishing
is a founder-owned roadmap gap)"*. That is out of date: the Article lifecycle shipped,
CH-14 made Articles first-class publications, and they now appear in the feed with
covers and canonical engagement. The `kDiscoveryDomains` entry below the comment was
already corrected on 2026-08-16 and contradicts it. Worth correcting so the doctrine
does not authorise its own staleness.

---

## 2. Domain surfaces behind the four doors

| Domain | Surface | Size | Character |
|---|---|---|---|
| People | `discover/presentation/people_discovery_screen.dart` | 254 lines | real, personalized, paginated |
| Institutions | `public/presentation/public_institutions_directory_screen.dart` | 850 lines | large faceted directory |
| Spaces | `public/presentation/spaces_discovery_screen.dart` | 133 lines | **renders a static client registry** |
| Articles | `ArticlesDiscoveryScreen` (`/discover/articles`) | — | exists |

**Spaces is the regression the addendum warns about.** It renders
`public_spaces_registry.dart` and says so: *"the registry is small enough to render as a
simple grid"*. That is the artificially fixed small taxonomy, and it is client-side.

---

## 3. What real signals exist (measured live, reviewer account)

| Domain | Endpoint | Result |
|---|---|---|
| People | `GET /v1/discover/people` | **200, n=0** for this account |
| Spaces | `GET /v1/public-spaces` | **200, 6 real spaces** — `id, slug, name, description, iconKey, status, displayOrder` |
| Institutions | `GET /v1/public/institutions` | real directory, returns a `verified` split (the `/institutions?limit=` path 404s — that was my probe error, not a gap) |
| Articles | `GET /v1/articles` | **200, 3 real articles** — `slug, title, coverMediaId, coverUrl, author` |

### The important find: a real relevance authority already exists

`src/discovery/people-discovery.service.ts` describes itself as *"a deterministic,
explainable PROJECTION over canonical signals"*, with an explicit **forbidden-signal**
list (no private Conversation content or membership) and a rule that a reason must name
*"the actual signal that produced it — no fabricated personalization"*. It emits real
reason strings:

* `Followed by someone you follow`
* `Followed by N people you follow`
* `Participates in <space>`
* `Active on Aura recently`

**This is the primitive the reconstructed root should consume**, not a new one. It also
already encodes the addendum's own rule about never fabricating relevance.

### And the gap that follows from it

There is **one** discovery/relevance service, and it is People-only. Institutions,
Spaces and Articles have retrieval endpoints but **no relevance projection and no reason
codes**. Spaces additionally expose no activity signal in the list payload —
`participantCount` / `activeDiscussions` are absent there, though `/public-spaces/:slug/summary`
carries them (the live space page renders "1 active discussion · 1 participant").

So a root that wants to say *why* something is worth attention can do it truthfully for
People today, and cannot yet for the other three without either per-object summary calls
or a widened list contract.

---

## 4. Structural drift check (addendum §11)

Question the addendum poses — do multiple discovery consumers independently answer the
same question? Findings:

* **"What is this object?"** — Articles are projected by `feed-projection.service.ts`
  for the feed, and separately by the articles endpoints for readers. A Discover root
  must not add a third projection.
* **"Who authored it?"** — canonical `PERSON_REFERENCE_SELECT` / `projectPersonReference`
  exists and is already used by feed, conversations and notifications. Discover must
  consume it. (Article carries only a scalar `authorUserId` with no relation, so the
  author must be resolved explicitly — the feed already does this.)
* **"Why is it relevant?"** — only People answers this, via reason codes. This is the
  authority to extend, not to duplicate.
* **"Where does tapping it land?"** — `NavigationAuthority` owns addresses, and the C3
  integrity gate already asserts every emitted address is a registered route.
* **"Can this viewer see it?"** — media custody (CH-12) and publication visibility are
  canonical; a published Article has no visibility column (published + not deleted IS
  public), which the feed work established.

**Conclusion: Discover should create no new object, identity, visibility, publication or
navigation authority.** The only genuinely missing shared authority is *relevance beyond
People*.

---

## 5. Search (addendum §7)

Search is a separate mechanism (`/search`) reached by a push from the root. The root's
search entry is a tap target that navigates away rather than a working affordance.
Whether `/search` covers the four domains coherently, and whether its result object
model matches the discovery object model, is **not yet audited** — that is the first
thing to settle before the root is rebuilt, because the addendum forbids papering over a
mismatch in UI.

---

## 6. Not yet audited

Stated rather than implied: loading/empty/error states, pagination/cursor behaviour,
responsive composition, accessibility, and per-platform behaviour (Web / Android / iOS /
Desktop) for each domain surface. Android and iOS remain unexercisable on this host
(no AVD; iOS needs macOS), so their Discover behaviour will be UNVERIFIED regardless of
what is built until a device or emulator exists.

---

## 7. What this audit implies for the reconstruction

1. The four domains stay as **organizing domains** — the addendum freezes them — but the
   root must render **real objects**, which is possible today for Spaces (6), Articles
   (3, with covers and authors) and Institutions (directory with a verified split).
2. **People is the honest problem.** The relevance engine exists and returns nothing for
   an account with no relationships. A root section that claims "suggested for you" must
   therefore have a truthful empty state, and must not fall back to a leaderboard or to
   fabricated suggestions — its own service forbids that.
3. **Spaces must stop being a client-side registry** and read `/public-spaces`, with
   activity signals sourced rather than invented.
4. **Relevance is the missing shared authority.** If the root is to explain why anything
   is surfaced beyond People, that projection belongs at the shared boundary, modelled on
   the People service's reason contract.
5. Search and curated discovery must be reconciled at the object-model boundary before
   the UI is designed around either.

**No implementation has been performed. This document is the audit the addendum
required before any change.**
