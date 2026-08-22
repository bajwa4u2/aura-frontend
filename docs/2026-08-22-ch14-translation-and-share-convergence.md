# CH-14 — why a new content type could vanish from the platform

**Date:** 2026-08-22
**Status:** Implemented, tested, not yet deployed.
**Scope:** the two capability gaps that were answerable from existing doctrine.

---

## The question, and its answer

> **Why can a new readable Aura content type exist without automatically
> participating in translation?**

Because participation was **opt-in**, and it was opt-in in four places at once.

A canonical translation authority genuinely exists and is well built —
`CommunicationTranslationService` over `CompositionTranslateService` over
`AiProviderRegistry`, with fingerprint caching, server-resolved billing scope
and a real self-hosted tier-0 provider. Nothing about it needed replacing.

What it lacked was any mechanism that made a new content type *join* it. Object
support lived in an `if` chain, so adding a content type and never thinking
about translation compiled, shipped, and worked. Three further hand-maintained
copies of the type list existed — the request DTO, the Dart enum, and the
crawler's idea of what is shareable — and they were kept in agreement by a
comment reading *"keep both in sync."*

They did not stay in sync. The evidence is already in the tree:

* The backend gained `CONVERSATION_MESSAGE`. The Dart enum was never updated,
  so the conversation screen could not name the type it needed and sent a raw
  string instead. **The canonical client became the reason to route around the
  canonical server.**
* Articles were never added anywhere, so Aura's most substantial content type
  was its only untranslatable one.

So the answer is not neglect. It is that the architecture asked to be
remembered, and a platform cannot be held together by memory.

## What changed

**Participation is now structural.** `TRANSLATABLE_OBJECTS` is a registry keyed
by `CommunicationObjectType` itself. TypeScript requires every member of that
union to be present, so a content type added to the enum without a resolver
**does not compile**. This was verified by observation, not by assumption — the
first build of the registry failed with exactly that error before the client was
regenerated.

Everything downstream now derives from that one place:

| Was | Now |
| --- | --- |
| `if` chain in the service | registry keyed by the enum |
| DTO's own copy of the list | derived from the registry |
| Dart enum missing two members | complete; wire values exhaustive by `switch` |
| conversation sent a raw string | uses the shared type |
| `sourceText` capped at 20,000 chars | 100,000 — see below |

**Articles are the proving consumer**, and deliberately gained *nothing of their
own*: no `ArticleTranslationService`, no article translate button. The article
screen mounts the same `CommunicationTranslateAction` every other surface uses.

One genuine generalization was required. That shared action rendered
translations as plain text, which is right for a post and wrong for an article —
a translated article would have shown the reader raw `##` and `**` where the
original showed headings. Rather than fork the widget, it gained an optional
`translatedBodyBuilder` so a surface can supply its own renderer. Translation
stays one capability; only the final rendering step is delegated. The title
travels with the body as one Markdown document, because a reader who cannot read
the language cannot read the headline either.

### The 20,000-character limit

Raised to 100,000. That number was chosen when every translatable object was a
post, a reply or a message, and it would have made long articles the one class
of Aura content that cannot be translated — the exact failure this chapter
exists to remove, reintroduced as a number rather than as an `if`.

Recorded honestly: 100,000 is an abuse guard, not a product answer. Genuinely
unbounded text needs chunked translation with per-segment caching. Inflating a
constant is not a substitute for that work, and is not being presented as one.

## A defect found while converging: the cache could be poisoned

`CompositionTranslateService` reports `fallback: true` when every provider
declines — the response then carries the **source text, unchanged**. The
canonical service dropped that flag and **cached the result**.

The cache key is a content fingerprint, which does not change until the author
edits the text. So a single transient provider outage would have written the
reader's own untranslated words into the cache under a key that never expires,
and served them as a translation indefinitely. The reader would be told the text
had been translated. It would look like it had worked.

Fixed in both directions: a pass-through is never persisted, and the flag is
surfaced through the client model to the UI, which now says translation is
unavailable rather than presenting the original as a translation. Pinned by
test.

## Articles could not be shared

Separate finding, same shape — a capability that existed but that a new content
type never reached.

`GET /og/articles/:slug` was already producing *good* crawler markup. No crawler
could reach it: the marketing host proxies `/p/*` only, and the share controller
had routes for posts, institution posts and announcements but none for articles.
Sharing a real article link produced the generic Aura homepage card. The
client had no `canonicalArticleUrl` and the article screen had no share control,
so there was no path to the address even if it had existed.

Now `/p/art/:slug`, mirroring the announcement route. `location /p/` is a prefix
proxy, so **no infrastructure change was required** — verified in `nginx.conf`
rather than assumed.

### The cover, and a pre-existing lie in every share card

`subjectFromArticle` set `imageUrl: undefined`, so an article's cover — the one
piece of the author's own work a reader sees before deciding to open it — was
absent from its card. It now uses the cover's **display** derivative: the live
corpus holds a 2.3 MB cover against 339 KB for its display variant, and crawlers
fetch synchronously with tight timeouts. The governed door falls back to the
original when no derivative exists, so an unprocessed cover still produces a
card rather than nothing.

Fixing that surfaced something wider. The renderer hardcoded
`og:image:type=image/png` with `1200x630` — correct for the Aura default card,
and **false for every custom image the platform has ever shared**: avatars,
institution logos, post images. Crawlers lay out cards from the declared
dimensions, so a portrait avatar announced as landscape PNG is cropped or
dropped. Those hints are now emitted only for the default card. This was not an
article defect; articles are simply where it became visible.

## Deliberately not done

* **Engagement generalization** — the census is complete and the evidence is
  decisive, but it needs a data migration over live reactions and belongs in its
  own batch with its own backup.
* **Visibility checks on POST / INSTITUTION_POST / ANNOUNCEMENT translation** —
  absent today. Because the caller supplies the text, this does not leak
  content; it is a **billing** exposure, and billing scope is founder-owned
  policy. Raised, not changed.
* Meetings/realtime, HEVC licensing, AI provenance — all out of scope by
  standing instruction.
