# CH-14 SLICE 1 — LIVE CERTIFICATION PROCEDURE *(prepared, not executed)*

**Preparation is not certification.** Predeclared before observation so criteria cannot be adjusted
afterwards. **Not executed.**
**Date:** 2026-08-18 · **Site:** `https://auraplatform.org`

**Bounded deliverable (Stage 5):** *"Exercise each Create path and the People-surface residue removal
LIVE — both are recorded as shipped and NEVER exercised."*

---

## 0. ARTIFACT ATTRIBUTION — establishable, unlike the backend case

This slice exercises **frontend** behaviour, and frontend builds **are** attributable from production
without asking anyone:

1. `GET https://auraplatform.org/version.json` → `{version, build_number}`, comparable to `pubspec.yaml`.
2. `HEAD .../main.dart.js` → `last-modified`, bounding the build time.
3. String-presence test in the bundle for a literal introduced by a known commit.

That method already established `v1.3.0+24 / code cdbae96` for the F065 certification. **I will
establish the artifact myself at observation time; it is not something to ask the founder for.**

If the live bundle predates the commit carrying a behaviour under test, the result is
**NOT_ESTABLISHED**, not FAIL.

---

## 1. WHAT THIS PROCEDURE MAY AND MAY NOT PROVE

**Targets — the three findings that are genuinely unexercised:**

| Finding | State | What is actually unproven |
|---|---|---|
| **F001** People surface institution residue | `IMPLEMENTED_NOT_LIVE_CERTIFIED` | Task #168 is recorded complete, but the People list contents were **never exercised live** |
| **F002** Create legacy creation model | `PARTIALLY_VALIDATED` | The Discover taxonomy and 4 primaries **were** observed live; the **Create migration itself** was not |
| **F005** Conversation creation | `PARTIALLY_VALIDATED` | Messages list and New conversation **were** observed; the **full creation journey** was not |

**Explicitly NOT targets.** F003, F004, F028 and F029 are already `LIVE_CERTIFIED`. This procedure
**does not re-prove them and may not be reported as evidence for them.**

**Provenance caution, carried from the chapter's certification requirements:** F003, F004 and F024 rest
on **WEAK** provenance. Nothing observed here strengthens them, and no conclusion about them may draw
structural weight from this procedure.

**Not exercised at all by this procedure:** publication, official designation, revision (CH-14 slice 2,
W5). Observing a Create path proves nothing about designation legibility before commitment.

---

## CASE A — F001 · PEOPLE SURFACE RESIDUE REMOVAL

1. Sign in on the live site.
2. Navigate to the **People** discovery surface (`/discover/people`).
3. Read the full list as rendered — every entry, not the first screen.

| | |
|---|---|
| **Expected** | Every entry is a **person**. No institution appears as a People entry. |
| **PASS** | The list renders, contains at least one person, and contains **no** institution entry |
| **FAIL** | Any institution appears in the People list |
| **NOT_ESTABLISHED** | The list fails to load, is empty, or the artifact cannot be identified |

### Counter-check A2 — *the test must not pass by the surface being broken*

4. Navigate to the **Institutions** discovery surface.

| | |
|---|---|
| **PASS** | Institutions render there |
| **FAIL** | Institutions render nowhere — then People is "clean" because discovery is broken, not because residue was removed |

> Without A2, an empty or broken People list would score PASS. That is the difference between proving
> removal and proving absence.

---

## CASE B — F002 · CREATE FOLLOWS THE DISCOVER TAXONOMY

5. Open the **Create** entry point.
6. Record every option it offers, in order.

| | |
|---|---|
| **Expected** | Create reflects the **Discover taxonomy** — People / Institutions / Spaces / Articles as the governing frame — rather than the legacy creation model |
| **PASS** | The offered options correspond to the taxonomy; no legacy-model-only option remains that the taxonomy does not account for |
| **FAIL** | Create still presents the legacy model |
| **NOT_ESTABLISHED** | Create does not open, or the artifact cannot be identified |

### Counter-check B2 — *each primary must actually lead somewhere*

7. Enter **each** offered Create path far enough to see its first real screen. **Do not complete or
   publish anything.**

| | |
|---|---|
| **PASS** | Every path opens its own surface |
| **FAIL** | Any path dead-ends, errors, or lands on the same generic screen as another |

> Listing four options proves a menu. B2 is what proves a migration.

### Counter-check B3 — F003/F004 boundary, observed but not re-certified

8. Confirm **"Add Institution"** appears in the **header** and **not** as a Create/Discover domain.

Record the observation. **This does not re-certify F003/F004** — they are already `LIVE_CERTIFIED` and
carry WEAK provenance. It is recorded only to detect a regression, and a negative result here is a **new
finding**, not a failure of this slice.

---

## CASE C — F005 · CONVERSATION CREATION STAYS SIMPLE HUMAN MESSAGING

9. Open **New conversation**.
10. Walk the **full** creation journey to a created conversation — select a counterpart, create it, land
    in it. *(A real conversation with a real person; nothing is published.)*

| | |
|---|---|
| **Expected** | The journey stays simple human messaging — choose who, then talk. No publication semantics, no designation step, no institution-actor ceremony where none was chosen. |
| **PASS** | The conversation is created and you land in it, and nothing outside simple messaging was required |
| **FAIL** | The journey demands publication-shaped or designation-shaped steps, or does not complete |
| **NOT_ESTABLISHED** | Cannot be attempted, or the artifact cannot be identified |

### Counter-check C2 — the identity doctrine actually renders

11. In a **group** conversation (three or more parties), observe the header.

| | |
|---|---|
| **Expected** | A **composite** group avatar — not one member's photo, not a letter tile — and participant order beginning with the founding counterpart |
| **Records against** | **F056** (composite avatar) and **F055** (immutable admission chronology), both founder-ruled 2026-08-17 |
| **Note** | **F056 may not be recorded LIVE_CERTIFIED while F058/CORS blocks image delivery.** If faces do not load, that is `NOT_DISCHARGED_BLOCKED_EXTERNAL`, **never FAIL** |

---

## RETURNING RESULTS

```
A  PASS/FAIL/NOT_ESTABLISHED — what you saw
A2 PASS/FAIL
B  …   B2 …   B3 …
C  …   C2 …
```

I will establish the artifact myself, adjudicate against exactly these predeclared criteria, and record
each observation **only against the finding it actually exercises** — F001, F002 and F005. Nothing here
certifies publication, designation or revision, and nothing here strengthens F003, F004 or F024.
