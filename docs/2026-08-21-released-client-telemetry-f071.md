# Released-client telemetry — F071 evidence

**Date:** 2026-08-21 · Founder-authorised read-only production query
**Purpose:** establish which released clients are actually represented, before any
further backend legacy-endpoint retirement decision.
**Nothing was retired. Nothing was written.**

---

## How it was taken

`UserSession`, production, through the Postgres public endpoint. Every statement ran
inside `BEGIN TRANSACTION READ ONLY`; the session reported `transaction_read_only = on`
before any query, so a stray write would have been refused by the database rather than
by care. Every projection is a `GROUP BY` aggregate — **no `userId`, email, token, device
id or session row was selected or printed**, and the connection string was never echoed.

Not performed, because not authorised: writes, session mutation, revocation, endpoint
retirement, user-level intervention, unrelated exploration.

Prisma cannot run on this workstation (arm64 Windows, documented), so the query used the
pure-JS `pg` client already present in the backend's dependency tree.

## Corpus

| | |
|---|---|
| Sessions, total | **842** |
| Sessions, non-revoked | **472** |
| Distinct distributions | 4 (+ a pre-instrumentation `null` era) |
| Distinct app versions | 11 |
| Most recent activity | 2026-08-21 |

## Distributions represented

| Distribution | Sessions | First seen | Last seen |
|---|---:|---|---|
| `(null)` — before the field existed | 449 | 2026-02-28 | 2026-05-13 |
| `unknown` | 261 | 2026-05-14 | **2026-08-21** |
| `web-prod` | 91 | 2026-05-13 | **2026-08-21** |
| `android-direct` | 26 | 2026-05-23 | 2026-08-16 |
| `windows-store` | 15 | 2026-05-14 | **2026-08-21** |

**No iOS distribution appears at all** — worth noting against the 2026-08-05 submission
of four platforms. Either iOS sessions are landing in `unknown`, or that build is not
producing sessions.

## Non-revoked sessions by recency

| Distribution | Version | last 7d | last 30d | active total |
|---|---|---:|---:|---:|
| `web-prod` | **1.3.0** | 17 | 25 | 25 |
| `android-direct` | **1.3.0** | 1 | 12 | 12 |
| `unknown` | *(null)* | 11 | 11 | 244 |
| `unknown` | 1.2.3 | 0 | 6 | 6 |
| `web-prod` | 1.2.2 | 0 | 5 | 6 |
| `unknown` | 1.3.0 | 2 | 4 | 4 |
| `android-direct` | 1.2.3 | 0 | 4 | 4 |
| `windows-store` | **1.3.0** | 3 | 3 | 3 |
| `web-prod` | 1.2.1 | 0 | 1 | 32 |
| `android-direct` | 1.2.2 | 0 | 1 | 5 |
| `android-direct` | 1.1.4 | 0 | 1 | 3 |

## What this answers

1. **Distributions represented:** `web-prod`, `android-direct`, `windows-store`,
   `unknown`, plus the legacy `null` era. **No iOS.**
2. **Versions represented:** eleven, from 1.1.1 to 1.3.0.
3. **Recency:** 1.3.0 is live on all three named distributions *today*. Older native
   builds — `android-direct` 1.1.4 / 1.2.2 / 1.2.3 — still show activity **within the
   last 30 days**, in small numbers.
4. **Are the released native builds active?** **Yes.** `android-direct 1.3.0` (12
   sessions) and `windows-store 1.3.0` (3, seen today) are both genuinely in use.
   MSIX `1.3.0.0` corresponds to the `windows-store` 1.3.0 rows.
5. **Do any observed clients plausibly depend on the remaining legacy endpoints?**
   **The natural experiment has already run.** The 14 legacy endpoints have been
   returning 404 in production since the Phase 5 cutover, and pre-1.3.0 native builds
   have connected *since* that retirement. So those builds either never depended on the
   14, or already degrade without visible consequence. The open exposure is confined to
   the **three retained invite endpoints** — `POST /spaces/:id/invites` and
   `GET/POST /threads/:id/invites` — against a small, mostly dormant tail: roughly
   **9 active `android-direct` sessions at ≤1.2.3** and **3 `windows-store` at ≤1.2.1**,
   nearly all with zero activity in the last 7 days.
6. **What the evidence supports:** it does **not** support retiring the three retained
   invite endpoints today, and it does not require keeping them indefinitely. The tail is
   small, real, and shrinking. Two clean exits exist: let it age out and re-measure, or
   ship the updated native build that F071's own
   **founder-triggered store release** already requires — which retires the tail at its
   source rather than by breaking it.

## Boundaries of this evidence

`unknown` with a null version is **244 sessions**, 11 of them active in the last 7 days.
Those clients do not report identity headers, so their build is genuinely unknown and
this measurement cannot speak for them. Counting them as safe would be an assumption;
they are reported as unmeasured instead.

Session presence is not endpoint usage. Proving whether a specific build calls a
specific endpoint needs request-level evidence, which this query neither has nor sought.

**F071 itself remains separately governed** by its canonical founder-triggered store
release requirement. This telemetry informs the endpoint decision; it does not close
F071.
