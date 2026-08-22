# The media derivative worker

**Date:** 2026-08-21
**Scope:** implementation of the derivative capability against the contract
Aura had already defined.

---

## 1. Architecture

A **separate process, same repository, same graph.**

Same repository because the worker must share the Prisma client, the R2 client
and the Media vocabulary — a second copy of any of those would be a second
authority, which is the outcome the design exists to prevent. Separate process
because image decoding is unbounded CPU and memory work that must never sit in
a request path.

```
API (main.ts)                    WORKER (worker.main.ts)
  POST /media/:id/confirm          claimNext()      atomic conditional UPDATE
    → status READY                 process()        read → decode → resize → encode
    → derivatives.enqueue()        putObject()      deterministic key
       records what is OWED        publish()        thumbUrl / displayUrl only
                                   reconcile()      backlog + superseded cleanup
```

**The API records what is owed; the worker produces it.** That division is the
whole point: `enqueue` writes rows saying a representation is missing, and it
is the API — the Media authority — that decides an object deserves one. The
worker never decides eligibility for anything except its own ability to decode.

`worker.main.ts` uses `NestFactory.createApplicationContext`, **not** `create`.
A worker that listened would be a second unguarded entry point to every
controller in `AppModule`, with nothing between it and the internet but nobody
having pointed a domain at it. A context gives the dependency graph and the
lifecycle hooks and no routes at all.

**Scheduling is polling, not a queue.** Aura has no queue infrastructure, and
adding one to make thumbnails would be an operational dependency bought for
very little. Claiming is a conditional `UPDATE` that names the status it
expects, which gives the one property a queue would have been for: two workers
cannot hold the same work.

## 2. Deployment boundary

| | |
| --- | --- |
| Entry point | `npm run start:worker` → `dist/src/worker.main.js` |
| Gate | `WORKER_ROLE=media-derivatives` — **two** gates, in the entry point and in the worker itself |
| Default | **off**. An API instance that accidentally derived is the exact failure this separation prevents |
| Build guard | `postbuild-entrypoints.cjs` now validates `worker.main.js`, so a missed build fails loudly instead of shipping an image that idles |
| Tunables | `MEDIA_DERIVATIVE_IDLE_MS` (15 s), `MEDIA_DERIVATIVE_RECONCILE_MS` (15 min) |

**Not deployed.** The code, migration and build are ready; provisioning the
Railway service and running `db:deploy` are operator actions.

## 3. Authorization

The existing boundary is used unchanged. `MEDIA_INTERNAL_TOKEN` /
`hasWorkerAccess` are untouched, and **no client can claim worker authority**
because the worker is not reachable over HTTP at all — it has no listener.

It writes to Media through Prisma in-process rather than calling its own API
over the network. The authority is the same code either way, and a self-call
would have needed the worker to hold a credential it can do without.

## 4. What it produces

| Kind | Longest edge | Quality |
| --- | --- | --- |
| `THUMBNAIL` | 480 px | 78 |
| `DISPLAY` | 2048 px | 85 |

Aspect ratio always preserved; **never upscaled** — a display copy larger than
its source would be bytes spent to deliver no additional detail. Output is
always JPEG. Dimensions and byte size are recorded on the derivative row.

**Library: `jimp` 1.6.1 — MIT across all 29 of its packages, pure JS, no native
build, no system libraries.** That matters for a Railway container and it
matters commercially: nothing here carries an LGPL obligation or a codec-patent
question.

The decoder set is composed **explicitly** (`createJimp({ formats: [...] })`)
rather than taken from the convenience bundle, which lazy-loads formats through
a dynamically imported sniffer. Naming them means the worker's capability is
visible in its imports and cannot silently grow when a dependency adds a format.

Decoding uses `fromBitmap` with the decoder chosen by the **content-verified**
mime on the row — deliberately not `Jimp.read`, which also accepts a URL or a
filesystem path. A decoder in a worker that would happily fetch a URL is an
SSRF waiting for a caller to pass the wrong string.

## 5. Storage and ownership

* **One owner per (source, kind)**, enforced by `@@unique([mediaId, kind])`.
  Duplicate derivative ownership is impossible, not merely unlikely.
* **Deterministic keys** — `derivatives/{mediaId}/{kind}-{producer}.jpg`. A
  retry overwrites its own previous output rather than orphaning it, and the
  producer version is in the key so changing what a thumbnail looks like cannot
  leave the old bytes in place.
* Keys are sanitised, so nothing can be steered out of the `derivatives/`
  namespace.

## 6. Source → derivative provenance

Each row records `sourceMimeType`, `producedBy` (producer + version),
`attempts`, `claimedAt`, `completedAt` and `lastError`. The derivative points
at its source; the source is never rewritten to create one.

**Derivation reads `originalUrl` / `url` and never `displayUrl`** — the column
this service writes. Deriving from it would mean deriving from a previous
derivative, and each pass would compound the loss until the display copy was a
copy of a copy. That is the doctrine about derived representations never
becoming more authoritative than their source, made concrete.

## 7. Retry, idempotence, reconciliation

| Property | Mechanism |
| --- | --- |
| Idempotent enqueue | `createMany({ skipDuplicates: true })` on the unique constraint |
| Atomic claim | conditional `updateMany` naming the expected status; the loser updates 0 rows |
| Bounded retry | `attempts < 3`, then left FAILED **with its reason** rather than retried forever |
| Backlog repair | sweep finds READY images with no derivative rows — covers deploys mid-confirm and rows predating this capability |
| Superseded cleanup | derivatives whose parent is deleted or quarantined have their **objects** reclaimed; the row is kept with its reason, so the record of what was attempted survives the bytes |
| Truthful vocabulary | `SKIPPED` = policy (no decoder, too large). `FAILED` = something that should have worked did not. Conflating them would invite retries that can never succeed |
| No false READY | a derivative is READY only after its bytes are stored |

**A missing derivative is never an outage.** `Media.status` is untouched by
anything here — a READY image stays READY while its thumbnail is owed, being
made, or permanently failed, and delivery keeps answering from the canonical
object because `firstKeyFromMedia` falls back to the primary when no variant
key resolves. That is what makes this an enhancement rather than a dependency,
and it is why derivative state lives in its own table with its own vocabulary.

## 8. Security and examination

* **Examination stays upstream.** Only READY, un-quarantined images are
  derived, re-checked *at processing time* and not only at enqueue — an object
  can be quarantined between the two, and the later read is the one that counts.
* **Two bounds, covering different halves of one hazard.** `MAX_DERIVABLE_BYTES`
  (32 MiB, mirroring `MAX_EXAMINABLE_BYTES`) refuses before any allocation;
  `MAX_DECODED_PIXELS` (80 MP) refuses after the header is read, because
  compressed size says nothing about decoded size and a lying header is exactly
  the decompression-bomb attack.
* **Fails closed.** Malformed input is a verdict, never an exception that takes
  the loop down. A worker that dies on the first hostile image stops deriving
  for everyone.
* **Registered as a non-door.** The G1 leg 5(A) ingestion-door register caught
  the new `putObject` immediately, and it is recorded there with its reasoning:
  it admits no caller-supplied bytes, only a server-chosen Media id and kind.

## 9. Governed delivery

Derivative URLs are written into `thumbUrl` / `thumbnailUrl` / `displayUrl` —
the columns `governedMediaUrls` already maps to `/media/:id/raw`, and that the
door already reverses to a storage key when it signs. So **a derivative
inherits every access decision its parent makes**, reaching viewers through the
same governed door as the original. No public bypass is created, and no new
delivery path exists.

## 10. Capacity

**Unchanged, and now genuinely supportable.** Image acceptance stays at the
streamed-examination envelope (150 MiB); the worker does not own that
constraint and did not move it. What it changes is that a large image is no
longer *delivered* at full size — which was the stated reason for concern when
the ceiling was raised.

The 150 MiB video/clamd boundary is untouched: the worker does not derive from
video, so it proved nothing about that constraint and did not pretend to.

## 11. HEIC / HEIF

**Deliberately absent, and recorded as SKIPPED rather than FAILED** — a policy
boundary, not a fault. The worker is now the right architectural place for it,
which is why it exists; but decoding HEVC is a rights question and is not
smuggled in under a thumbnail feature. See the rights review in the completion
report.

## 12. Client / worker convergence

The client normalizes HEIC where a platform codec exists (iOS, macOS,
Android 28+) and the worker derives representations from what is stored. They
do not overlap and do not compete: the client answers *what may be stored*, the
worker answers *what may be shown*. A photograph that arrives already
normalized and one that arrives as JPEG reach identical stored + derived state.

The gap that remains is a HEIC arriving from **web or Android < 28**, where
neither side can decode it today. Closing it is the same single decision.
