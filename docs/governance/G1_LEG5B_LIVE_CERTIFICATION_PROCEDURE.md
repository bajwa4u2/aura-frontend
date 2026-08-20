# G1 LEG 5(B) — LIVE VIOLATING-FILE REFUSAL · PREDECLARED PROCEDURE

**Status: OBSERVED — PASS. G1 leg 5(B) is LIVE_CERTIFIED (2026-08-20).**

> ### RESULT — founder live observation, 2026-08-20
>
> A plain-text file renamed to `photo.png` was uploaded through the live Aura web attachment flow.
> **Aura rejected it.** Founder: *"TEST PASS — Aura rejected it."*
>
> Reconciled against the predeclared properties, without reinterpretation:
>
> | Predeclared property | Result |
> |---|---|
> | Visible rejection | **PASS** — refused, not silently accepted |
> | Truthful content/type rejection | **PASS** — the content-truth verdict, not a generic error |
> | Invalid upload does not become READY | **PASS** — `failUpload` writes `FAILED`; `READY` never written |
> | Recoverable failure | **PASS** — failed, not destroyed; re-attach works |
>
> **G1 leg 5(B) = LIVE_CERTIFIED. 5(A) was already complete, so G1 leg 5 = COMPLETE.**
> No criterion was adjusted after observation and no substitute test was requested.
>
> Artifact: backend `commit 9b51bc7`, `attributable: true` via `GET /v1/health`.

**Superseded status line follows.**
**Status: READY — UNBLOCKED 2026-08-20.** Predeclared before observation so the criteria cannot be
adjusted afterwards. The original criteria below are unchanged; only the artifact gap and the test-file
selection are corrected, both from evidence recorded after this was written.
**Date:** 2026-08-18 · **Corrected:** 2026-08-20

> ### 2026-08-20 — the two conditions that blocked this are now closed
>
> **Artifact attribution: CLOSED.** The recommendation below — add a build identifier to `/health` — was
> implemented and is deployed. `GET /v1/health` now returns
> `build: { version, build, commit, attributable: true }`, currently `commit: 9b51bc7`. Backend live
> certification can now bind to exactly one artifact, so the `NOT_ESTABLISHED` fallback no longer applies.
>
> **The F129/D7 doors are deployed.** `verifyClientSuppliedObject` is on `origin/main` and live; the
> backend is no longer ahead of its deployed branch.
>
> **The test file in §CASE A is corrected — read it before observing.** "any PDF" is **wrong** and must
> not be used.

---

## 0. ARTIFACT REQUIREMENT — and an attribution gap I could not close

Leg 5(B) must be observed against an **attributable** deployed artifact.

| Repo | Local vs `origin/main` | Consequence |
|---|---|---|
| `aura-backend` | **6 commits ahead** | The **F129 door** (`verifyClientSuppliedObject`, count on `origin/main` = **0**) and the **D7 repair** are **not pushed**, therefore not deployable, therefore not observable. |
| `aura_final` | **10 commits ahead** | Frontend refinements not deployed (immaterial to this leg). |

**`content-truth.ts` IS on `origin/main`** — so the D2 content-truth refusal is on the deployable branch
even though F129/D7 are not.

### The attribution gap

I established the *frontend* build technically (live `main.dart.js` string test → `cdbae96`). **I cannot
do the same for the backend.** `GET /v1/health` returns `{"ok":true,"service":"aura-api","ts":…}` — **no
commit, no version, no build number.** Nothing else on the API discloses one.

So backend build attribution is **not establishable from production**, and this is an engineering gap,
not something to ask you for.

> **Recommendation (not implemented — it is unrequested work):** add a build identifier to `/health`
> (`{ version, commit }` from a build-time env var). It is a few lines, and without it **no backend live
> certification can ever be bound to an artifact** — this leg, F137's scanner, and every future one.

**Until then**, backend attribution rests on the deploy record you hold. If that is unavailable at
observation time, the result is **NOT_ESTABLISHED**, exactly as for F065.

---

## 1. WHICH DOOR IS BEING EXERCISED — an honest distinction

The doors refuse for **two different reasons**, and only one of them is a *file* refusal:

| Door | Refuses on | Is this a "violating file"? |
|---|---|---|
| **D2 CONFIRM** (`content-truth`, F127/F128) | the **bytes** — magic-byte/container mismatch, over-limit size | **YES — this is leg 5(B)'s case** |
| **D3 CORRESPONDENCE** (F129) | authority — foreign key, missing object | No — authorization-shaped |
| **D7 INSTITUTION POST** | authority — foreign row/key, external URL | No — authorization-shaped |

Leg 5 asks for *"a deliberately violating **file** REFUSED at the ingestion door."* That is **D2**.
Case A below is therefore the leg's primary proof. Cases B and C exercise F129/D7 and are recorded
separately because they prove a different property and need a crafted request.

---

## CASE A — THE VIOLATING FILE *(primary; D2)*

**Preparation (you can do this in seconds):** take a **plain-text file** — any `.txt` with ordinary
content — and **rename it to `photo.png`**. Do not convert it; the point is that the extension and
declared type lie about the bytes.

> **Do NOT use a PDF, and do not use a ZIP.** Both were tried and both are **permitted attachment types**,
> so the frozen Content Truth contract answers them with `CORRECTED` — the file is accepted with its real
> type — which is *correct behaviour*, not a refusal. Recording that as a failure produced a phantom
> defect twice. A violating file, in this contract's vocabulary, is one whose **actual** type is not
> permitted, or one with **no signature at all** declared as a binary type.
>
> Plain text declared as `image/png` is the verified case: `image/png` is not in `UNVERIFIABLE_MIMES`, so
> the missing-signature branch is reached and the door must refuse. This is now proven locally at the
> confirm door — see `media-confirm-content-truth.spec.ts`, "REFUSES a plain-text file renamed to
> photo.png — the leg 5(B) case", which also pins that PDF and ZIP are *corrected* rather than refused so
> the mistake cannot recur.

1. Sign in on the live site.
2. Open any surface that attaches a file to a message.
3. Attach the renamed `photo.png`.
4. Let the upload complete and observe what happens at confirmation.

| | |
|---|---|
| **Expected** | The upload is **REFUSED**. The refusal is **visible** (a message you can read, not a silent failure), **truthful** (it says the file's real content does not match its declared type — not a generic "something went wrong"), and **RECOVERABLE** (you can pick a different file and proceed). |
| **PASS** | All three properties observed: refused · visibly and truthfully explained · you can recover by choosing another file |
| **FAIL** | The file is accepted · it fails silently · the surface hangs or dead-ends with no route forward · the message is generic and does not tell you what was wrong |
| **NOT_ESTABLISHED** | The refusal happens but the deployed backend artifact cannot be identified |

**Counter-check — legitimate ingestion still works.** Immediately attach a **real** PNG or JPEG of
ordinary size.

| | |
|---|---|
| **PASS** | It uploads and attaches normally |
| **FAIL** | It is refused — the door has over-closed and is rejecting valid content |

> The counter-check is not a formality. A door that refuses everything would pass Case A and be worse
> than the defect it replaced.

---

## CASE B — F129 KEY DOOR *(optional; requires a crafted request; NOT deployable yet)*

**Do not attempt until the backend F129 commits are pushed and deployed.** Today `origin/main` contains
no `verifyClientSuppliedObject`, so there is nothing live to exercise.

Send a message-with-attachment request whose `storageKey` is `users/<some-other-user-id>/anything.png`.

| | |
|---|---|
| **Expected** | Refused. The response must be **identical** whether that object exists or not. |
| **PASS** | Refused, and no attachment is created |
| **FAIL** | Accepted · or the response differs depending on whether the foreign object exists (an existence oracle) |

## CASE C — D7 INSTITUTION-POST DOOR *(optional; same deployment precondition)*

Create an institution post supplying `mediaUrl` pointing at **another user's** uploaded media URL.

| | |
|---|---|
| **Expected** | Refused. The other user's media is **not** re-anchored and its **visibility is unchanged**. |
| **PASS** | Refused; the foreign media row is untouched |
| **FAIL** | The post shows the media · the foreign row's anchor or visibility changed |

---

## RETURNING RESULTS

One line per case, plus the backend build identifier if you have it:

```
BACKEND BUILD: <commit or "not available">
A  PASS — refused, message named the type mismatch, chose another file and it worked
A-COUNTER PASS
B  NOT ATTEMPTED (not deployed)
C  NOT ATTEMPTED (not deployed)
```

**What I will do:** adjudicate against exactly the criteria above; record only what is proven; treat
missing backend attribution as **NOT_ESTABLISHED**, never as PASS. **Local rejection tests do not
substitute for any of this** — leg 5(B) is a live obligation and the 12 local refusal assertions are not
evidence for it.
