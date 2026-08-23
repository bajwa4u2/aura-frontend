# Aura addressing register — human/public URL identity audit

**Release Client reconstruction record. 2026-08-23.** Founder ruling: internal
persistence identifiers must not become Aura's human-facing information
architecture by accident.

**No route migration has been performed.** This is the register, the proposed
canonical model, the continuity plan, and the founder decisions that remain.

---

## 0. Method and scope

155 registered client routes, extracted from `lib/router.dart` — not from
visible screens. **77 carry no identity component at all** (`/home`, `/search`,
`/settings/*`, `/admin/*`, marketing pages). Identity only becomes a question
where a route is parameterised, so the register below covers the **78
parameterised routes** plus every backend-generated address.

Classification, per the ruling:

| | |
|---|---|
| **A** | human/canonical identity (handle, slug) |
| **B** | legitimate opaque public resource identifier |
| **C** | internal persistence ID leak |
| **D** | private/operational address (not publicly distributable) |
| **E** | transitional/legacy, retirement already governed |

---

## 1. Class A — already canonical. The precedent.

| Route | Identity |
|---|---|
| `/u/:handle`, `/u/:handle/followers`, `/u/:handle/following` | person handle |
| `/author/:handle`, `/support/:handle` | person handle |
| `/institutions/:slug` | institution slug |
| `/institutions/:slug/units`, `/institutions/:slug/units/:unitSlug` | institution slug **+ unit slug** |
| `/institutions/sector/:classId` | curated ontology token |
| `/articles/:slug`, `/announcements/:slug`, `/spaces/:slug` | content slug |
| `/meet/:slug`, `/i/:institutionSlug/meet/:bookingSlug` | booking slug |

**`/institutions/:slug/units/:unitSlug` is the precedent the ruling names**: the
public surface already addresses both an institution *and* a unit by slug. The
architecture is not missing — it is not applied consistently.

## 2. Class B — legitimate opaque public identity

Opaque because the domain has **no meaningful human name**, not because the
router copied a column.

| Route | Why opaque is right |
|---|---|
| `/posts/:id`, `/posts/:postId/edit` | a post has no title-independent name; slugging free text is a naming system the product does not have. **45 persisted notification deeplinks** already use this shape |
| `/meetings/:id` and its lifecycle (`/prep`, `/room`, `/waiting`, `/live`, `/summary`, `/post-meeting`) | a meeting instance is not a named resource |
| `/media/:id/restricted`, `/media/:id/public`, `/media/:id/raw` | governed object identity; the id is the resource contract |
| `/articles/write/:articleId` | pre-publication draft; the slug does not exist yet |
| `/meetings/join/:code` | a code IS the credential shape |
| `/meet/cancel/:token`, `/meet/reschedule/:token`, `/i/:token` | capability URLs — deliberately unguessable, never human identity |

**Not to be converted.** An opaque identifier here is a designed public
contract, and the ruling explicitly warns against changing it for tidiness.

## 3. Class C — persistence identity leaked into human addresses

**The defect the founder observed, and it is systemic: ~40 workspace routes.**

| Family | Current | Canonical target |
|---|---|---|
| Institution workspace (all destinations) | `/institution/:institutionId/…` | `/institution/:slug/…` |
| Unit context | `/institution/:institutionId/units/:unitId` | `/institution/:slug/units/:unitSlug` |
| Institution space | `/institution/:institutionId/spaces/:spaceId` | institution slug + space identity |
| Shell-adaptation aliases | `/institution/:institutionId/u/:handle`, `/institution/:institutionId/institutions/:slug` | institution slug prefix |
| Admin | `/admin/institutions/:id/members` | platform-admin surface — see §7 |

### The Unit split is mine, and it is exactly the state the ruling forbids

Public: `/institutions/aura-platform-llc/units/orchestrate`
Workspace: `/institution/cmmg1ildu…/units/cmotiwyb…`

Two addresses, two identity systems, one resource. Introduced in the Unit
context work earlier today and named here rather than left for someone to find.

### It is persisted, not merely displayed

**23 production notification rows embed `/institution/<rawId>/…`.** These are
durable: an ID-shaped address that has already been written into people's
notification history is not fixed by changing route generation alone.

## 4. Class D — private/operational addresses

Not publicly distributable; the identity question is different.

| Route | Note |
|---|---|
| `/messages/c/:conversationId` | conversation identity is opaque **by design** — a human-readable conversation address would leak participants |
| `/realtime/:sessionId` | ephemeral session |
| `/me/*`, `/settings/*`, `/admin/*` | no identity component |
| `/institution/:institutionId/public-engagement/:recordId` | operational record (ruled member-context, not public) |

Class D routes may keep opaque identity **and** still need the institution
prefix converged — the two questions are independent.

## 5. Class E — legacy/convergence, retirement already governed

| Route | State |
|---|---|
| `/thread/:id`, `/direct/:threadId`, `/institution/:institutionId/direct/:threadId` | DirectThread lineage. **8 persisted notification deeplinks** use `/direct/<threadId>` |
| `/threads/:id/live/*` (backend) | **429 realtime sessions** — the dominant historical surface |
| `/threads/:id/invites` (backend) | **0** thread-bound invitations |
| `/me/correspondence/*` | retired. **62 persisted deeplinks** — already dead by founder ruling |

**These must not be re-canonicalised.** Converting `/direct/:threadId` to a
slug would freeze a storage identity Aura is actively retiring into a *new*
address contract. They stay as they are until the convergence sequence retires
them.

---

## 6. Continuity — the blocking finding

**No slug-history or alias mechanism exists anywhere in the schema.** Verified:
no `SlugHistory`, no `previousSlug`, no alias table, on any model.

`Institution.slug` is `@unique`, and slug is **absent from
`UpdateInstitutionProfileDto`** — so it cannot be edited today, which is
*why* nothing has broken yet.

Consequently:

> **Slug editing cannot be enabled before alias history exists.** Renaming
> `aura-platform-llc` → `aura-platform` today would silently strand every
> issued link, every OG `og:url`, and every persisted notification deeplink,
> with no mechanism to resolve the old address.

This is the ruling's condition 3, confirmed by evidence rather than assumed.

## 7. Authority boundary — unchanged and load-bearing

`_enforceCanonicalIdMatch` validates the path id against
`authorizedIds`, which are institution **IDs**. Slug addressing therefore needs
**resolve-then-authorise**: slug → canonical institution id → existing authority
check, unchanged.

> Resolving a slug identifies *which* institution is addressed. It never
> establishes that the viewer may see or act there. Destination projection and
> capability authority still govern access, exactly as frozen.

No authorization code may take the route value as proof of anything — and none
does today, because the value is compared against a resolved membership list
rather than trusted.

## 8. Generators and consumers

| Generator | Mints |
|---|---|
| `NavigationAuthority` / `institution_paths.dart` (client) | all workspace addresses |
| `canonical-destinations.ts` (backend) | `/institution/${id}/spaces/${id}`, `/messages/c/:id`, `/realtime/:id`, `/media/:id/restricted` |
| Share/OG authority | `/p/art/:slug`, `/p/...` — **already slug-based**, and `og:url` matches the browser URL |
| Notifications | persisted deeplinks (§3) |
| nginx front door | `/p/` proxy, media doors, `www` → apex |

Consumers: Web, Desktop, Android, iOS, plus every external crawler.

## 9. Proposed canonical model

```
PERSON        /u/:handle                       (already canonical)
INSTITUTION   /institutions/:slug              public — already canonical
              /institution/:slug/…             workspace — TO CONVERGE
UNIT          /institutions/:slug/units/:unitSlug   public — already canonical
              /institution/:slug/units/:unitSlug    workspace — TO CONVERGE
CONTENT       /articles/:slug, /announcements/:slug (already canonical)
OPAQUE        /posts/:id, /meetings/:id, /media/:id  (legitimate, keep)
PRIVATE       /messages/c/:id, /realtime/:id         (opaque by design, keep)
CAPABILITY    /meet/cancel/:token, /i/:token         (unguessable by design)
```

## 10. Compatibility and migration plan

1. **Alias history first.** `InstitutionSlugHistory(institutionId, slug, retiredAt)`, unique on slug across current+historical, so an old slug can never be reused by another institution. Nothing else can proceed safely without it.
2. **Resolver**, one place: slug → institution, consulting current slug then history; a historical hit yields a **301 to the canonical current address**.
3. **Router accepts both** during migration: an id-shaped segment resolves and **redirects** to the slug form, so old links and the 23 persisted notification deeplinks keep working and converge on arrival.
4. **Generation converges wholesale** — `institution_paths.dart` and `canonical-destinations.ts` together, never screen-by-screen.
5. **Unit split closed in the same pass** — the workspace unit address becomes slug-based, matching the public precedent.
6. **Retirement condition**: id-shaped acceptance is removed when no persisted deeplink and no inbound traffic uses it — measurable, since deeplinks are rows we can count.
7. **Slug editing enabled last**, once 1–3 exist, with normalization, reserved names, collision handling and availability feedback.

Class E addresses are **excluded** and follow the convergence sequence instead.

## 11. Founder decisions genuinely required

| # | Decision |
|---|---|
| **AD1** | Which capability owns **slug editing**? It is institution identity, adjacent to `MANAGE_BRANDING` (which already governs profile identity) and to `MANAGE_DOMAINS` (which governs external identity). Recovering rather than inventing means choosing between two existing capabilities — a product judgement, not a technical one. |
| **AD2** | Should the workspace prefix be `/institution/:slug` or converge on the public `/institutions/:slug`? Two prefixes for one institution is itself an addressing question. |
| **AD3** | **Reserved slugs** — the platform has none today. The list is a product decision (`admin`, `api`, `me`, `new`, `settings`, existing route segments…). |
| **AD4** | How long must a retired slug remain resolvable, and may it ever be re-issued to a **different** institution? Never re-issuing is safest; permanently reserving names has its own cost. |
| **AD5** | `/admin/institutions/:id/members` — platform-admin surface. Convert to slug for consistency, or keep IDs because it is an operator tool where the raw identity is the point? |

## 12. Not converting, deliberately

Every Class B and D identifier. The ruling is explicit that a stable opaque
identity is legitimate where no meaningful human name exists — and converting
`/posts/:id` or `/messages/c/:id` would invent a naming system the product does
not have, or leak participants into an address.
