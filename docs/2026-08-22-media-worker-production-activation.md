# Media derivative worker — production activation

**Date:** 2026-08-22
**Status:** Backend half ACTIVE in production and verified. Frontend half complete,
tested, and awaiting a release decision (see §8).

---

## 1. A correction to the previous report

I reported "two additive migrations pending". **They were not pending — they
were already applied.**

`scripts/railway-start.sh` runs `prisma migrate deploy` on **every container
start**, before Nest boots. Railway redeploys `aura-backend` on every push to
`main`, so pushing the schema change applied it. That is the repository's
designed deployment path working exactly as intended, but my earlier statement
was wrong and the correction matters more than the reassurance.

Verified through the governed path (`npm run db:status`, which routes through
`db-guard.cjs`):

```
145 migrations found in prisma/migrations
Database schema is up to date!
```

And confirmed by existence rather than by inference — `SELECT` against the live
database succeeds for `"MediaDerivative"`, for `"Media"."originalMimeType"`, and
for both new enum types.

`prisma migrate diff` shows **neither migration as missing**. It does show
pre-existing drift — four identity-media indexes and some Postgres identifier
truncation — which predates this work, has its own guarded reconciliation
script, and was deliberately **not touched**.

### The two migrations, and why they were safe to apply

| | |
| --- | --- |
| `20260911000000_media_original_mime_provenance` | `ALTER TABLE "Media" ADD COLUMN "originalMimeType" TEXT` |
| `20260912000000_media_derivatives` | two new enums, one new table, one FK |

Both are **purely additive**. No existing row is read or rewritten, and no
existing column changes. For `originalMimeType`, NULL is not merely a safe
default for historical rows — it is the **true** value, because every row
already in the table was stored exactly as it arrived.

**Compatibility in both directions.** Old code ignores a column it does not
know about, and new code requires it; because migration runs *before* Nest
boots, the ordering is always schema-then-app. **Rollback:** dropping either
object would be destructive to new data and is unnecessary — old code tolerates
their presence, so the safe rollback is to redeploy old code and leave the
schema alone.

`prisma migrate dev` was never run and is not reachable from any deploy path.

---

## 2. Deployment architecture — one image, two roles

The worker is a fifth service in the existing **Aura Platform** project,
production environment, built from **the same repository and the same
Dockerfile** as `aura-backend`.

Rather than give it a Railway-specific start-command override — which would let
its build drift from the API's — `railway-start.sh` now **dispatches on
`WORKER_ROLE`**. A container with no `WORKER_ROLE` takes the existing path
byte-for-byte unchanged, which is what made it safe to add to a live entrypoint.

The worker deliberately does **not** run `migrate deploy`. Two services racing
migrations on every boot is a hazard worth removing by construction rather than
leaving Prisma's advisory lock to arbitrate. **The API owns schema migration;
the worker owns nothing but its own loop.**

## 3. Configuration and credentials

**No secret value was copied, and none was printed.** Every shared value is a
Railway **variable reference** — `${{Postgres.DATABASE_URL}}`,
`${{aura-backend.R2_*}}` — so nothing passed through this session, and a
credential rotation on the source service propagates automatically.

The worker holds **10 variables against the API's 92**. It has no TikTok
credential, no APNs key, no Firebase key, no OpenAI key, no LinkedIn secret. It
has exactly what it needs: a database URL, R2 access, the delivery origin, and
its role.

**`JWT_ACCESS_SECRET` is its own generated value, not the API's.** The
`ConfigModule` requires one at boot, but the worker never issues or verifies a
token — it has no HTTP listener at all. Giving it the API's signing key would
have granted a capability it cannot use; giving it a distinct random one
satisfies boot and means a compromised worker still cannot mint an API token.
If it somehow did verify a token, it would reject it — which is the safe
direction.

**`MEDIA_INTERNAL_TOKEN` was deliberately NOT created.** The worker writes
through Prisma in-process, not over HTTP, so the token gates nothing it does.
Creating an unused credential is worse than not creating one.

## 4. Live verification — what was actually proven

The worker booted, reconciled the entire historical backlog and drained it.

| | |
| --- | --- |
| READY | **242** |
| SKIPPED | 28 |
| FAILED | 2 |
| Pending / processing | **0** |
| Published to `Media` | 121 thumbnails, 121 display copies |
| **Bytes saved (thumbnails alone)** | **160.5 MB** |

**Delivery, on one real avatar, through one governed door:**

```
/media/{id}/raw               200  image/png    2,937,363 bytes
/media/{id}/raw?v=thumb       200  image/jpeg      65,219 bytes   (45× smaller)
/media/{id}/raw?v=display     200  image/jpeg     222,357 bytes   (13× smaller)
```

An avatar was being served as a **2.8 MB PNG**. It is now 64 KB.

**And the property that matters most, proven live:** a RESTRICTED non-identity
media returns **403 to an anonymous caller on all three variants**. The
derivative is refused by exactly the same gate as the original. Derivative
generation did not create a second visibility system.

### The failures were correct

Both FAILED rows are the **same** object — a 2,140-byte `image/png` the decoder
rejects as truncated. It was retried to the attempt ceiling, then left FAILED
with its reason rather than retried forever. `Media.status` was never touched,
so that object still delivers from its canonical URL. The failure path was
exercised in production and behaved as designed.

### The skips exposed something real

All 28 skips are documents — PDF, DOCX, ZIP. They are stored as
`MediaType.IMAGE` because **`wireKind` collapses DOCUMENT to `'IMAGE'` for the
released client**. So `MediaType.IMAGE` does not mean "an image", and enqueueing
on type alone created 22 rows that could only ever be skipped.

Fixed: `isDerivable` now consults the mime as well, and the reconciliation sweep
narrows on it in the query. **The existing SKIPPED rows were left exactly as
they are** — they are the truthful record of what was attempted, and rewriting
history to tidy a count would be the wrong instinct.

## 5. A defect found and fixed during activation

The DISPLAY derivative was **produced and unreachable**. `firstKeyFromMedia`'s
primary order reaches `url` — the original — before `displayUrl`, so every
request got the full object. A variant that is produced and never served is
worse than one not produced at all.

`display` is now a variant of its own. **`primary` still means the original and
must keep meaning that**: a download, a save and the full-resolution viewer all
ask for it, and quietly handing them a downscaled copy would lose detail nobody
asked to lose. Each variant prefers its own representation and falls through to
the primary order, so a missing derivative still delivers.

## 6. Identity convergence — the design, and why it is small

The census found ~152 emission sites across 58 files, and **not one** selects
the `*MediaId` FK. Converging them all would have been the wrong move anyway,
because `identity-delivery.ts` already established the right one: **the
convergence point is the VALUE, not the site.**

Production confirms that convergence is already live — **5/6 avatars, 5/5 person
covers, 1/1 logo, 1/1 institution cover** are governed door names. The single
exception is an external URL the convergence correctly left alone, because Aura
cannot sign what it does not host.

So the only remaining decision is **which representation** to render, and that
belongs at the rendering surface because it differs by surface. A 32 px avatar
and a full-bleed cover are the same identity and want very different bytes.

`governedImageVariant` does exactly that and nothing else. It invents **no**
second identity URL, **no** thumbnail field, **no** durable string beside the
canonical one — what it returns still addresses the same media id through the
same door. Avatars ask for the thumbnail (480 px, sharp at any avatar size);
covers ask for the display copy (2048 px). Two properties make it safe
everywhere, both pinned by tests: a URL Aura does not serve is returned
untouched, and asking for a derivative that does not exist still yields a
picture.

## 7. Write-side defects found by the census

Two live paths — self-serve deletion and retention disposition — nulled
`avatarUrl`/`coverUrl` while leaving `avatarMediaId`/`coverMediaId` behind.
`identity-media.ts` states the invariant plainly, and it matters beyond
tidiness: **retention derives what is still referenced from those keys**, so a
scrubbed account went on protecting the very media the scrub existed to release.
Fixed.

**Recorded, not fixed:** `POST /uploads/avatar` writes `User.avatarUrl` directly
and creates no `Media` row at all, so an avatar taken through it can have no
relationship and no derivative — the F139 shape, still latent. The released
client does not use that endpoint (it uploads through presign), and changing an
ingestion door is a governed act rather than a drive-by.

## 8. What remains — a release decision, not unfinished work

The frontend half is **complete, analyzer-clean and passing 965 tests**, but it
sits on branch `realtime-negotiation-certification` while `aura-frontend`
deploys from `main`. The branch is **22 commits ahead**, and merging it would
deploy the entire CH-13 frontend chapter — composer convergence, HEIC
normalization, content sniffing, capacity changes — none of which has had
founder live observation.

It also carries four **realtime-certification** commits from a chapter that is
explicitly closed and protected. Those are tests, docs and a single additive
`@visibleForTesting` accessor that mutates nothing, so the risk is low — but
they are that chapter's commits, and merging them is not my call to make
silently.

**Until that merge happens, production generates identity derivatives that the
web client does not yet request.** That is harmless — every surface keeps
rendering the canonical object exactly as it does today — but it is the gap
between what the worker produces and what the product consumes.
