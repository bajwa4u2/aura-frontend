# Institution destinations — audit before freezing the IA

**2026-08-23.** The founder addendum requires every destination audited before
the institution information architecture is frozen. This enumerates all 39
id-bearing institution destinations and classifies each by what the
`institutionId` in its address actually *means*.

---

## 1. The distinction that governs everything here

`institutionId` in a path is **two different things**, and treating them alike
is what caused a real production regression.

**A membership claim.** The address asserts standing. A stale, removed or
foreign id must be refused through the canonical authority, because rendering
the workspace for an institution someone does not hold is a truthfulness
defect — even when the backend then refuses each request individually.

**A context.** The address names *whose* meeting, profile or public record this
is. The visitor may legitimately hold no membership at all. Validating these
would refuse the very people they exist for.

> **Frozen doctrine (2026-08-14): `institutionId`-in-path ≠ institution-actor
> identity.** Applying membership validation to Meetings previously redirected
> booked attendees to Institution Sign In. Blanket-validating all 39
> destinations would reintroduce exactly that defect, which is why this audit
> classifies rather than sweeps.

---

## 2. Standing-required destinations

The address is a membership claim. Validation belongs at the router.

| Destination | Validates | Note |
|---|---|---|
| `/dashboard` (Overview) | **yes — fixed this pass** | see §3 |
| `/domains` | yes | |
| `/edit-profile` | yes | |
| `/request-verification` | yes | |
| `/live-rooms` | yes | |
| `/members` | **yes — fixed this pass** | |
| `/invites` | **yes — fixed this pass** | |
| `/join-requests` | **yes — fixed this pass** | |
| `/billing` | **yes — fixed this pass** | |
| `/announcements`, `/announcements/new` | no | **recommended** |
| `/spaces`, `/spaces/:spaceId` | no | **recommended** |
| `/units` | no | **recommended** |
| `/activity` | no | **recommended** |
| `/messages`, `/messages/direct`, `/messages/direct/archived` | no | gated behind the DirectThread cutover — do not touch before it |
| `/explore` | no | entry destination; see §4 |
| `/posts/new`, `/posts/:postId/edit` | no | **recommended** (authoring) |

Before this pass, **five** of these validated. Now **nine** do. The rest are
named rather than swept, because each needs its own check that no legitimate
non-member path reaches it.

## 3. Overview was not addressable — fixed

`/institution/:institutionId/dashboard` **redirected to the id-less address**,
discarding the institution the URL named. Consequences, all real:

* A person holding two institutions could not bookmark, link or refresh
  institution B's Overview — every id-bearing address collapsed to whichever
  membership was ambient. This is precisely the substitution RC3 forbids.
* The route comment described the target as a "global institution selector";
  it is not a selector, it is the Overview.

The backend already answered per institution — `/institutions/me` takes an
optional `institutionId`, and the caller's own membership is what authorises
the answer. The client simply never passed it. The route now validates the id
and renders that institution's Overview, and the screen reloads when the
addressed institution changes.

## 4. Context destinations — deliberately unvalidated

| Destination | Why the id is context |
|---|---|
| `/meetings`, `/meetings/new`, `/meetings/:id`, `/prep`, `/room`, `/waiting`, `/live`, `/summary` | attendees are frequently non-members; the institution owns the lifecycle, the visitor's relationship is contextual |
| `/availability` | public booking surface |
| `/public-engagement` (+2) | public record by definition |
| `/profile` | validates today, but is a *public* identity surface — worth re-examining |
| `/u/:handle`, `/institutions/:slug` | shell-adaptation aliases, not institution destinations |

`/explore` is the **entry** destination and is currently unvalidated. Its public
scope genuinely serves unauthenticated callers (verified live: `scope=public`
returns content without a token, `scope=member` returns 403). So the address is
partly context and partly claim — the one destination where the classification
is genuinely ambiguous, and the one place the IA freeze should record a
deliberate decision rather than inherit an accident.

## 5. Redirect-only destinations

Three discard their address entirely: `/correspondence`, `/u/:handle`,
`/institutions/:slug`. The latter two are intentional shell aliases.
`/correspondence` is a retired surface whose links the founder ruled may expire
rather than earn a translator — consistent, and recorded here so its absence is
a decision.

## 6. Terminal denial shares an address with Overview

`kInstitutionDenialDestination` and `kInstitutionNoAffiliationDestination` are
both `/institution/dashboard`, which is also the Overview's id-less address. So
three distinct meanings — "you were refused", "you hold nothing", and "your
standing" — arrive at one place.

The founder ruled terminal denial is **independently governed**. That is not
closed by this pass and is not silently folded into the addressability fix:
Overview is now addressable *per institution*, while the id-less address keeps
its existing triple duty. Separating them is the remaining work, and it becomes
more pressing once Overview moves into ADMIN as ruled, since a refusal would
then land on an admin surface.

## 7. Not audited here

Per-destination capability/visibility semantics (the 15-question pass), and
per-platform behaviour. Android and iOS remain unexercisable on this host, so
their institution navigation stays UNVERIFIED regardless of what the router
does.
