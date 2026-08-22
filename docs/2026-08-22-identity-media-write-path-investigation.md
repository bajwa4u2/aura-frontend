# Identity media — why a newly changed cover disappears

**Date:** 2026-08-22
**Status:** INVESTIGATION ONLY. Nothing changed, nothing deployed.
**Verdict:** one root cause, pre-existing, in the identity WRITE path. The
2 MB message is a separate and much smaller matter.

---

## The short version

**The two symptoms are independent.**

* **The disappearing image is real, serious, and pre-existing.** The identity
  write path stores a raw object-storage URL on a host that was retired. It has
  nothing to do with derivatives, the worker, variant selection, or anything
  shipped in CH-13.
* **The 2 MB message is not in the deployed build at all.** It is a cached
  pre-deployment bundle.

**No data was lost.** The bytes, the `Media` row, the foreign key and the
derivatives are all intact and correct. The only thing wrong is the *string*
persisted into the identity record.

---

## 1. The disappearing image

### What was observed in the database

The cover changed at 02:19 today:

| | |
| --- | --- |
| `User.coverUrl` | `https://uploads.auraplatform.org/users/…` |
| `User.coverMediaId` | `cmt3r2i4…` — **set correctly** |
| `Media.status` | **READY** |
| Derivatives | **present and valid** |

### What each URL actually answers

```
stored URL   https://uploads.auraplatform.org/…      → 401
door         /media/cmt3r2i4…/raw                    → 200   1,178,912 bytes
door ?v=thumb                                        → 200      19,322 bytes
door ?v=display                                      → 200     211,906 bytes
```

`uploads.auraplatform.org` is the public storage origin **retired by the
same-origin cutover**. `media.service.ts` already records what happens when
something still addresses it: *"every caller asking for a PUBLIC media URL
received a link that now answers 401."*

So the image is not missing. It is addressable, governed, and even has
derivatives waiting. The profile is simply pointing at a door that was closed.

### Why the write path does this

```
ProfileMediaEditor  → crop
uploadAuraMedia     → presign → PUT → PATCH /media/:id
                    → returns result.url  (from the media row's stored URL)
profile_media_pipeline._upload → ProfileMediaResult.success(result.url)
edit_profile_screen → identityMediaPatch → User.coverUrl = <raw storage URL>
```

`Media.url` / `displayUrl` are set at presign to `buildPublicUrl(key)` — a raw
object-storage URL. That is **correct for a Media row**: those columns *are* the
storage identity, and `keyFromPublicUrl` reverses them in order to sign. The
mistake is copying that value into an identity record, where it becomes a bearer
URL pointed at a closed door.

### Why this was not caught by the convergence

`identity-delivery.ts` converted identity URLs from storage capabilities into
governed names — and it did so as a **one-time value backfill** over the twelve
strings that existed at the time. Its own reasoning is sound: ~202 emission
sites all emit the same handful of values, so rewriting the values was the right
convergence point.

But **the write path was never converged with them.** The script fixed the past;
nothing taught new writes the new representation. So every identity image
uploaded after the cutover has been stored in the retired form.

**This predates CH-13 entirely.** Nothing in the composer work, the worker, the
variant selector or the provenance wiring touches which URL gets persisted here.

### The second face of the same bug — a silent detachment

The same user's **avatar** shows the opposite shape: the URL *is* a governed
door name, but `avatarMediaId` is **NULL**.

`resolveIdentityMediaId` matches a URL against `url`, `originalUrl`,
`displayUrl`, `playbackUrl`, `thumbUrl`, `thumbnailUrl` — all of which hold
**raw storage URLs**. A door name (`/media/{id}/raw`) matches none of them, so
resolution returns null, and `identityMediaPatch` writes `null` into the FK.

Which means: **saving a profile detaches an already-converged identity image
from its Media row.** The picture keeps rendering — the door still works — but
the relationship retention derives its decisions from is quietly erased. That is
the F139 shape, reintroduced through the ordinary act of saving a profile.

So one root cause produces both faces:

> **The identity write path speaks only the old representation — both when it
> stores a URL and when it reads one back.**

Storing → persists a storage capability, which is now dead.
Resolving → only recognises storage capabilities, so a governed name resolves to
nothing.

### Person and institution share it

Both go through `ProfileMediaPipeline` and both call `identityMediaPatch`
(`users.controller.ts` for person, `institutions.service.ts` for institution).
One pipeline, one helper, one defect — which is why the founder saw identical
behaviour on both.

---

## 2. The 2 MB message — a stale bundle

The caps were raised to `MediaCapacity.profileSource` (32 MiB), and there is
exactly one call site each for person and institution.

The deployed bundle was fetched and inspected directly:

* `33554432` (32 MiB) — **present, 8 occurrences**
* `2097152` (2 MiB) — present 4 times, and **every one of them is inside a Dart
  runtime power-of-two table**: `…1048576,2097152,4194304,8388608,33554432…`

There is **no 2 MiB size gate in the shipped code**. The message is computed at
runtime from whatever `maxBytes` the caller passes, and the only callers now
pass 32 MiB.

`flutter_service_worker.js` is served (200), and Flutter's service worker caches
the app shell and `main.dart.js` aggressively. A browser holding the
pre-deployment bundle would show exactly the old message — and the old 2 MB
refusal, since that build genuinely had one.

**Independent of the disappearing image**, which is a server-side stored-value
problem and would occur on any build.

---

## 3. Answers to the twelve questions

| # | | |
| --- | --- | --- |
| 1 | Owner of the 2 MB restriction | `profile_media_pipeline.dart:142`, computed from the caller's `maxBytes`. Both callers now pass 32 MiB. Not in the deployed build. |
| 2 | Why convergence didn't remove it | It did. The observation is a cached pre-deployment bundle. |
| 3 | Shared private gate? | Yes — one pipeline for both, and it no longer gates at 2 MB. |
| 4 | Media rows intact and READY? | **Yes.** READY, bytes present, retrievable through the door. |
| 5 | FKs correct? | **Cover yes. Avatar NULL** — resolution cannot match a door name. |
| 6 | Derivatives exist and valid? | **Yes** — thumb 19 KB, display 212 KB, both 200. |
| 7 | Governed variant URLs correct? | **Yes**, all three variants resolve correctly for the affected media. |
| 8 | Original fallback works? | **Yes** — proven earlier and unaffected here. |
| 9 | Data/state or rendering failure? | **Neither.** A stored-value failure in the write path. |
| 10 | Editor preview and profile render same cause? | **Yes** — both read the same stored string. |
| 11 | One failing authority for person + institution? | **Yes** — `ProfileMediaPipeline` + `identityMediaPatch`. |
| 12 | Why technical verification missed it | **Because I only verified the READ path.** Every check used media that already existed and had already been converged by the one-time script. I never performed a new identity upload, so I never exercised the write path — which is the only place the defect lives. |

Point 12 is the honest lesson: proving that existing images deliver correctly
says nothing about what happens when a new one is created, and identity media
was exactly the case where those two paths disagree.

---

## 4. What is NOT the problem

* Not the worker — it produced correct derivatives for this very media.
* Not variant selection — `governedImageVariant` correctly no-ops on a
  non-door URL and would return the raw string untouched.
* Not the media authority, the delivery door, or the derivative model.
* Not softness, crop, or aspect. The founder could not evaluate those, because
  the image was not rendering at all.
* Not schema, and no data was lost.

## 5. Shape of a fix — for authorization, not yet applied

Two halves, matching the two faces:

1. **Store a governed name, not a capability.** The identity write path should
   persist `identityDeliveryUrl(mediaId, origin)` — the same value the
   convergence script produces — rather than the media row's storage URL. The
   media id is already known at that point.
2. **Resolve a governed name.** `resolveIdentityMediaId` should recognise a door
   name and read the id out of it directly, instead of only matching raw storage
   columns — so saving a profile stops detaching the relationship.

Both are small and sit inside the existing identity-media authority. Neither
requires touching the worker, the delivery door, the derivative model, the
schema, or variant selection.

**Existing broken rows** would also need re-converging; the convergence script
already exists, is reversible, and records a verbatim backup before writing.
