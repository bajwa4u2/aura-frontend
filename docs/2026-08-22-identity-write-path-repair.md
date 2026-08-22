# Identity media — write-path repair, live

**Date:** 2026-08-22
**Status:** Fixed, deployed, data repaired, and proven with a NEW live write.
Founder visual certification still outstanding.

---

## 1. What changed

Two files, both inside the existing identity-media authority. No schema change,
no worker change, no variant-selection change, no client change.

### `identity-delivery.ts` — the missing half of the convergence

`mediaIdFromIdentityDeliveryUrl()` reads the Media id back out of a governed
name. A governed name does not need *matching* — it **contains** the id.
Reading it is exact where matching is a guess, which is why it is preferred
over the database lookup rather than added beside it. It tolerates a variant
query (`?v=thumb` names a representation, not a different object) and is
origin-agnostic, because the door has moved before.

### `identity-media.ts` — both directions of the boundary

**Resolving.** `resolveIdentityMediaId` now reads a governed name first and
confirms the row exists. Existence is still checked: the name is evidence, not
authority, and an id naming a missing row must resolve to nothing rather than
to a dangling pointer. The legacy storage-URL match is untouched as the
compatibility path.

**Storing.** `identityMediaPatch` now derives the durable value from the
resolved media id — the same conversion the one-time backfill performed,
applied where new values are born. An external avatar still resolves to
nothing and is stored exactly as given, because Aura cannot name what it does
not host.

## 2. The canonical representation

| | |
| --- | --- |
| **Stored** | `https://auraplatform.org/media/{mediaId}/raw` |
| **Never stored** | raw storage URLs · `uploads.auraplatform.org` · signed URLs · derivative URLs |

Stable across saves — a value that churned would invalidate caches and defeat
the point of a durable name. Pinned by a test.

## 3. Live identity census

Every identity field across every person and institution.

| Class | Before | After |
| --- | --- | --- |
| governed name + valid FK | 10 | **13** |
| governed name + **missing FK** | 1 | **0** |
| retired storage value + FK | 1 | **0** |
| retired storage value + no FK | 0 | 0 |
| legitimate external | 0 | 0 |
| no image | 64 | 63 |

Two rows needed repair and **both had unambiguous canonical evidence** — the
detached one carried the id inside its own governed name, and the retired one
already had a correct FK. No Media ownership was inferred from an ambiguous
URL, because none had to be.

**Backup:** taken verbatim before any write, into
`PlatformSetting['media.identity_write_path_repair.backup']` — 12 entries,
each recording table, row id, field, URL and FK as they stood.

A note on method: the first repair attempt used `RAISE EXCEPTION` to report its
counts, which **rolled the transaction back**. That was caught by re-running
the census rather than trusting the reported numbers, and the repair was
re-applied as plain statements. The rollback was harmless, and the habit of
verifying a mutation independently of what it claimed is what caught it.

## 4. The live write-path test

Run against the standing review account — the one place a live identity write
belongs. This is the test whose absence let the defect ship.

```
1. login                 OK
2. source image          4698 bytes image/png
3. presign               mediaId=cmt3rsfr9000dnw0cqqrnat2p
4. PUT to storage        http=200
5. confirm               status=READY mime=image/png
6. uploader returns      https://uploads.auraplatform.org/users/…   ← the capability
7. saved avatarUrl       https://auraplatform.org/media/cmt3rsfr…/raw ← the NAME
   governed name?        true
   retired capability?   false
8. re-saved avatarUrl    https://auraplatform.org/media/cmt3rsfr…/raw
   value stable?         true
```

Step 6 is the defect, unchanged and correctly so: the uploader still returns
the Media row's storage identity, because that is what a Media row *is*.
Step 7 is the repair — the boundary now converts.

**And the relationship survived both saves:**

```
fk=cmt3rsfr9000dnw0cqqrnat2p   matchesUrl=true
mediaStatus=READY  thumbPublished=yes  derivativeRows=2
```

The second save is the one that used to write NULL over a valid relationship
while the picture went on rendering. It no longer does.

The worker then picked the new media up on its own:

```
/media/cmt3rsfr…/raw            200  image/png    4,698 bytes
/media/cmt3rsfr…/raw?v=thumb    200  image/jpeg   6,913 bytes
/media/cmt3rsfr…/raw?v=display  200  image/jpeg  22,959 bytes
```

**One honest observation:** for this synthetic flat-colour test image the JPEG
thumbnail is *larger* than the PNG source, because flat colour is exactly what
PNG compresses best and JPEG worst. Real photographs go the other way — the two
repaired identity images dropped 23× and 61× — but "a derivative is always
smaller" is not universally true, and a future refinement could decline to
publish a derivative that exceeds its source. Recorded, not changed: variant
selection and the derivative model were explicitly out of scope for this repair.

## 5. The repaired rows, live

```
avatar  /media/cmsva7y9…/raw   200  976,449 → thumb 42,849  (23× lighter)
cover   /media/cmt3r2i4…/raw   200 1,178,912 → thumb 19,322 (61× lighter)
```

The cover is the one the founder watched disappear. It renders.

## 6. Stale-build finding — the mechanism is already correct

The 2 MiB observation was a pre-deployment bundle. The historical build
genuinely had a 2 MiB gate; the current one does not — `33554432` appears 8
times in the shipped bundle and every `2097152` is inside a Dart runtime
power-of-two table.

Checked whether a client can be stranded on an obsolete release:

* `flutter_bootstrap.js` carries a per-build `serviceWorkerVersion`, so the
  version does change with each release.
* The deployed `flutter_service_worker.js` is a **self-unregistering stub**: on
  activate it unregisters itself and then **navigates every open window client**
  to force a reload.
* `flutter_bootstrap.js` and `main.dart.js` are served `Cache-Control:
  no-cache`, so both revalidate on every request.

So release uptake works, and it self-heals. The one real window is transient: a
client that still had an *older* service worker registered can be served one
stale load immediately after a release, until the new stub activates,
unregisters and force-navigates it. That is precisely what was observed, and it
resolves itself.

**Disposition: no change.** Closing the remaining window would require a
release-notification mechanism — version polling plus a "new version available"
prompt — which belongs to release continuity, not to this repair. `Ctrl+Shift+R`
is not the fix and is not being proposed as one; the mechanism already in place
is.

## 7. What was deliberately not touched

Worker architecture · derivative model · variant selection · schema · HEVC
policy · Meetings/realtime · CH-14. The legacy `POST /uploads/avatar` door still
creates no Media row and is still unused by the released client — recorded
previously, still latent, still not a drive-by fix.
