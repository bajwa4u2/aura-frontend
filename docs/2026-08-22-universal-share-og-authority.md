# The universal external-share authority

**Date:** 2026-08-22
**Status:** Implemented, deployed, verified against production across every
object family.
**Trigger:** a founder shared a real, public Article and Facebook rendered
Aura's generic marketing card.

---

## 1. What was actually wrong

The origin was **already correct** for that URL. Proven first, before any
theory:

```
GET /p/art/what-we-build-after-the-idea-is-gone   (as facebookexternalhit)
  og:title  What We Build After the Idea Is Gone - M S Bajwa on Aura
  og:image  .../media/cmt2iloch.../raw?v=display   200 image/jpeg 323,221 B
```

The phrase the founder saw - *"Accountable public discourse"* - appears
**nowhere on either host today**. It is older marketing copy. So the card was a
Facebook cache of a scrape taken when `/p/art/` did not exist.

But the observation was right, and the diagnosis it points to is the real one:
**that failure mode was the platform's default**, not an accident.

### The structural fault

Aura had **two independent OG systems**:

| | families | crawler-reachable |
| --- | --- | --- |
| `/og/*` | 6 | **no** - never proxied by the marketing host |
| `/p/*` | 4 | yes |

`nginx` proxies `location /p/` and nothing else; everything else falls through
`location /` to the SPA, which serves the generic marketing card. So:

* **Person profiles** and **institution profiles** had working resolvers that
  no crawler could ever fetch.
* **Meetings** had no external representation at all.
* **Articles** had `/og/articles/:slug` for weeks with no `/p/` route - which
  is exactly what the founder observed from the outside.

The deeper fault is the one the translation work exposed a day earlier:
**participation was opt-in.** A new shareable object could ship, work perfectly
for humans, and silently have no external identity.

## 2. The convergence

One typed registry, `SHAREABLE_OBJECTS`, a
`Record<ShareableObjectType, ShareableObjectDefinition>` over seven families:
user post, institution post, announcement, article, person profile,
institution profile, meeting.

A family added to the union without a definition **does not compile**. Every
definition must state its canonical URL, how it resolves through its canonical
authority, how it describes itself, and how it selects its image.

Both controllers are now thin dispatchers into one `ShareResolutionService`, so
they cannot drift apart again. `/og/*` is kept as a published compatibility
surface - its `og:url` points at the canonical `/p/` address.

A test asserts **every canonical path begins with `/p/`**. That is the founder's
failure mode turned into an assertion: a path anywhere else is unreachable by a
crawler by construction.

New crawler-reachable routes: `/p/u/:handle`, `/p/org/:slug`, `/p/m/:code`.
`location /p/` is a prefix proxy, so **no infrastructure change was needed** -
verified in `nginx.conf`, not assumed.

## 3. Three real defects the matrix caught - none by reading code

Every one was found by running the certification matrix against **live
production data**. Each is the founder's exact failure, hiding one level deeper
than the last fix.

**(a) The mapped-DTO defect.** `firstImageMediaId` read `mediaLinks`, but the
canonical read paths return a mapped DTO whose attachments live under `media`.
Every personal post with a photograph rendered the generic card.

**(b) The envelope defect.** `getInstitutionBySlug` returns `{ ok, institution }`,
not a row. Read as a row, name/tagline/logo were all undefined, so **every**
institution profile card said *"Aura institution - Aura"*. Invisible until now
because the only institution card lived at unreachable `/og/*`.

**(c) The link-id trap.** Three read paths, three attachment contracts:

| source | id key | kind key |
| --- | --- | --- |
| raw Prisma row | `mediaLinks[].media.id` | `kind` |
| personal post DTO | `media[].id` *(is the media id)* | `type` |
| institution DTO | `media[].mediaId` *(`id` is the **link** id)* | `mediaType` |

Reading `id` on the third resolves to no media row, so an institution post with
a real photograph fell back to the generic card. This survived **two** earlier
rounds of fixing exactly that failure.

Converging those three DTOs is real work that belongs to their owners. Reading
all three honestly is what the share authority can do without reaching in.

## 4. Governed media, and a live dead-link defect

`firstSafeImage` returned `media.publicUrl ?? url ?? thumbUrl` - raw storage
addresses on `uploads.auraplatform.org`, **the host retired by the same-origin
cutover, which answers 401**. Every share card for a post with a picture has
been pointing crawlers at a dead link.

Images now resolve through the governed door, preferring the **DISPLAY**
derivative - crawlers fetch synchronously with tight timeouts, and the live
corpus holds a 2.3 MB cover whose display derivative is 339 KB. When no
derivative exists the door serves the original, so an unprocessed upload still
produces a card.

A media row that is not `READY` - uploading, failed, quarantined - yields **no**
image rather than a broken one. A derivative never creates visibility its
source does not have.

## 5. Truthful metadata

`og:image:type/width/height` were hardcoded to `1200x630 PNG` for every image
the platform has ever shared. Crawlers lay cards out from declared dimensions,
so a portrait photograph announced as landscape is cropped or dropped.

Each hint is now read from the representation actually linked - the DISPLAY
derivative's own recorded values, or the original's when there is no derivative
- and **omitted when unknown**. The default card may state `1200x630 PNG`
because it genuinely is one.

## 6. Visibility

Resolved only through canonical authorities. No parallel visibility system.
Missing, private, draft and deleted are deliberately **one** answer externally:
a crawler must not be able to tell a private post from a nonexistent one.

Meetings are handled **more strictly** than the existing boundary. Aura already
treats a meeting code as the credential the join link carries. A crawler
surface is different in kind - a link pasted into a chat is scraped and cached
by third parties who were never given the code deliberately - so only a
`PUBLIC` meeting gets a card. The link still works; its subject is simply not
broadcast. No realtime behaviour was touched.

## 7. Production verification

Every family, fetched as `facebookexternalhit`:

| family | title | image | declared |
| --- | --- | --- | --- |
| Article (founder's) | What We Build After the Idea Is Gone - M S Bajwa | `.../raw?v=display` | jpeg 1536x1024 |
| Article (other) | The Quiet Work That Holds People Together - Mrs Bajwa | `.../raw?v=display` | jpeg 1536x1024 |
| Personal post + image | We are teaching AI to reason. - M S Bajwa | `.../raw?v=display` | jpeg 1369x1149 |
| Personal post, no image | What's the one use case... - Craig B | default | png 1200x630 |
| Institution post | Aura Platform - Clear Communication... | `.../raw?v=display` | jpeg 1536x1024 |
| Announcement | Aura is now live in its initial public state | `.../raw?v=display` | jpeg 1536x1024 |
| Person profile | saad78 (@bajwa) - Aura | `.../raw?v=display` | jpeg 800x800 |
| Institution + logo | Aura Platform - Aura | logo, not cover | jpeg 800x800 |
| Institution, no logo | Bajwa Writes - Aura | default | png 1200x630 |

**Negative controls**, all returning the safe page with `noindex` and no
identifying data: non-public post, unpublished article, PRIVATE meeting,
nonexistent handle.

Every emitted image was fetched anonymously and returned `200` with real bytes.
No card anywhere references `uploads.auraplatform.org`.

## 8. Facebook disposition

Aura's origin is now proven correct for the founder's URL. What remains is a
**stale third-party cache** - category D, and only nameable as such because the
origin was proven first.

Canonical URLs were **not** changed to evade it. The legitimate remedy is a
re-scrape at `developers.facebook.com/tools/debug/` - paste the URL, then
**Scrape Again**. LinkedIn's equivalent is `www.linkedin.com/post-inspector/`.
Both need a signed-in human, so they are the founder's to run; nothing in Aura
needs changing for them to succeed.

Share responses now carry `Cache-Control: public, max-age=300` - long enough to
absorb a burst of crawlers on a freshly shared link, short enough that an
edited title is not frozen into every unfurl for a day.

## 9. What was retired

`share.controller.ts` and `crawler-og.controller.ts` no longer contain any
per-family logic; both are dispatchers. `share.controller.spec.ts` and
`share.e2e.spec.ts` were replaced by the certification matrix. Nothing that was
reachable was removed - `/og/*` remains published, because retiring a public
URL is a separate decision from converging its behaviour.

## 10. Still open

* **Meetings carry no governed cover.** They report no image and use the
  platform fallback, which is what a fallback is for. Fabricating imagery to
  avoid it would be worse. If meetings gain a real cover, one line changes.
* **The three attachment DTO contracts remain divergent.** The share authority
  reads all three; converging them belongs to their owners and is not share
  work.
* **`/og/*` is still published.** Converged in behaviour, but retiring the URL
  family is a separate decision.
