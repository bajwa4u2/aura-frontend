# CH-15 — FOUNDER POLICY DECISION PACK

**This is analysis, not policy. Nothing here is founder-authored until you rule it.**
**Date:** 2026-08-18 · Baseline: 143 findings + 308 obligations = **451 units** · 17 chapters

CH-15 is the smallest chapter in the portfolio — **1 finding (F023), 1 obligation (`CO-RC-C10-019`,
`FOUNDER_ACTION_ONLY`)** — and almost all of it is yours to author. **Four decisions actually block
work. One more is real but blocks nothing yet. One item that looks like a decision is not one.**

### Dependency check, against canonical anchors

CH-15 `dependsOn` **CH-11** — *"a verdict needs to know what the content is."* That dependency binds
CH-15's **construction**, not its policy freeze. Stage 5 is explicit: the policy work *"has no
engineering prerequisite whatever, so nothing is gained by requesting it later and a wave is lost by
requesting it late."* **Nothing engineering-side is blocking you from ruling today.**

CH-11's side is in fact ready: the resolved type class exists (`content-truth.ts`, six-layer
resolution) and every ingestion door now passes a governed boundary.

### What already exists in code — the baseline your ruling constrains

| | |
|---|---|
| `ModerationReport` | `targetType`, `targetId`, `reporterId`, **`reason: String` (free text)**, `details`, `status`, `outcomeSummary`, `privateNote` |
| `ModerationAction` | 14-member `ModerationActionType`: `NOTE`, `WARN`, `SOFT_DELETE_POST`/`RESTORE_POST`, `DISABLE_USER`/`RESTORE_USER`, `REQUEST_CLARIFICATION`, `REQUEST_REVISION`, `SOFT_DELETE_MESSAGE`/`RESTORE_MESSAGE`, `ARCHIVE_SPACE`/`RESTORE_SPACE`, `ARCHIVE_THREAD`/`RESTORE_THREAD` |
| **Appeal** | **No model. No table. Nothing.** |
| Media scanning | **None.** F137: moderation is text-only; zero coverage on every axis |

---

# DECISION 1 — THE PROHIBITED-CONTENT TAXONOMY

**A. Question.** What categories of content are prohibited on Aura, and what is the governed vocabulary
a report and an automated verdict are expressed in?

**B. What creates it.** CH-15 `founderActions`: *"The content policy itself — what is prohibited."*
`ModerationReport.reason` is a **free-text String**, so today there is no taxonomy at all — every report
is prose and no verdict can be expressed in shared terms. `CO-RC-C10-019` carries the open checkpoint.

**C. Frozen, not open.**
- Reporting must **visibly do something**, on every surface a person can be harmed on (CH-15
  `worldClassObligations`).
- **One authority**: no surface resolves a report through a second path.
- CH-15 does **not** own the scanning pipeline, storage lifecycle or delivery gate (CH-12).

**D. Options.**
1. **Freeze a small governed enum now**, explicitly extensible, with a residual `OTHER` carrying free text.
2. **Author a full taxonomy now** covering every category you intend to enforce.
3. **Keep free text**, and let reviewer judgement be the policy.

**E. Consequences.**
1. CH-12's scanner gets categories to return verdicts against and CH-15 can build immediately. Categories
   added later are additive. Risk: an early enum shapes what people can report.
2. Most complete, and the slowest — it is the largest single piece of authorship in the chapter, and CH-12
   waits for all of it rather than the part it needs.
3. **Blocks CH-12 outright.** An automated verdict cannot emit free prose; a scanner with no category has
   nothing to say. It also makes "one authority" unenforceable, because two reviewers can classify the
   same harm differently with nothing to reconcile against.

**F. Recommendation — option 1.** It is the only option that unblocks CH-12 without asking you to author
the entire policy in one sitting, and the extensibility is real rather than promised: the enum is
additive and `OTHER` preserves the free-text path that exists today, so nothing currently reportable
becomes unreportable. Option 3 is not a policy; it is the absence of one, and it is what produced the gap.

**G. Blocks:** CH-12 **construction** · CH-15 **construction** · CH-15 **certification** (one-authority proof).

**H. Default if you decline.** No taxonomy is invented. `reason` stays free text, CH-12's examination
mechanism stays blocked, and CH-15 cannot begin. **I will not select a taxonomy.**

---

# DECISION 2 — THE CONSEQUENCE LADDER

**A. Question.** Is the **existing 14-member `ModerationActionType`** ratified as the consequence ladder,
or does the policy require a different one?

**B. What creates it.** CH-15 `founderActions`: *"…and the consequence ladder."* The ladder exists in
code and has been shipped, but **shipped is not the same as authored** — nothing records it as policy.
The frozen distinction applies directly: `IMPLEMENTED ≠ VALIDATED ≠ LIVE_CERTIFIED`, and an
implementation is not a founder ruling.

**C. Frozen, not open.**
- A verdict removes or hides **real user content**; that is an irreversible product harm even when the
  bytes survive (CH-15 `destructiveBoundaries`).
- **Adjudication data is evidence** — it must not be patched or deleted to tidy a queue.
- Verdicts act on stored objects **through CH-12 only** (PB-07).

**D. Options.**
1. **Ratify the existing ladder as policy**, unchanged.
2. **Ratify with named amendments** (add/remove specific actions).
3. **Author a new ladder**, treating the existing enum as implementation debt.

**E. Consequences.**
1. Zero engineering change; CH-15 proceeds to the journey. The ladder is already reversible in the right
   places — every destructive action has a `RESTORE_*`/`ARCHIVE_*` counterpart, which is what the
   destructive boundary requires.
2. Bounded migration proportional to the amendments.
3. Largest change, and it touches shipped behaviour and existing adjudication records — which are
   **evidence** and may not be rewritten to fit a new vocabulary.

**F. Recommendation — option 1, ratify as-is.** Not from convenience: the ladder already satisfies the
frozen constraint that matters most, reversibility, and it graduates properly (`NOTE` → `WARN` →
`REQUEST_REVISION` → `SOFT_DELETE_*` → `DISABLE_USER`). **What is missing from CH-15 is not the ladder —
it is the appeal route, and that is Decision 3.** Rewriting a working ladder would consume the chapter
without addressing its actual gap.

**G. Blocks:** CH-15 **construction** and **certification**. Does **not** block CH-12.

**H. Default if you decline.** The ladder stays `IMPLEMENTED_NOT_RATIFIED`. CH-15 may not certify,
because a certification would assert as policy something you never authored. CH-12 is unaffected.

---

# DECISION 3 — APPEAL AND FALSE-POSITIVE ROUTE FOR AUTOMATED VERDICTS

**A. Question.** When an **automated** examination flags content, what happens to it, and how is a wrong
verdict corrected?

**B. What creates it.** CH-15 `founderActions`: *"Appeal and false-positive policy for automated media
verdicts (jointly with CH-12)."* CH-15 `certificationRequirements`: *"An appeal path exists and is
proven on a deliberately induced false positive."* **No appeal model exists in the schema.** F137's
carried adequacy requirement: **"QUARANTINE AS A REVERSIBLE RETENTION STATE rather than a deletion."**

**C. Frozen, not open.**
- *"A wrong automated verdict without an appeal route is an **irreversible product harm** even when the
  bytes survive"* — CH-15 `destructiveBoundaries`.
- *"A scanner whose verdict cannot stop bytes reaching a person is not an examination system"* — F137.
  **Detection-only is therefore already excluded as an end state.**
- Quarantine must be **reversible retention**, never deletion.
- Adjudication data is evidence.

**D. Options.**
1. **Quarantine + human appeal.** An automated verdict quarantines (reversibly); the person is told; they
   appeal; a human resolves.
2. **Advisory-until-confirmed.** Automated verdicts queue for a human; nothing is withheld until a human
   agrees.
3. **Auto-enforce with post-hoc appeal.** Content is withheld immediately; appeal follows.

**E. Consequences.**
1. Satisfies both frozen constraints simultaneously — bytes are stopped, and the stop is reversible.
   Requires an appeal model, a person-visible state and a notification. Largest build of the three.
2. Weakest protection: between flag and human review, flagged content **still reaches people**, which is
   exactly what F137 says an examination system must not permit. Cheapest to build.
3. Strongest protection, worst failure mode: a false positive silently removes someone's content and the
   burden of noticing falls on them.

**F. Recommendation — option 1.** It is the only option that satisfies both frozen constraints at once.
Option 2 contradicts F137's frozen statement about stopping bytes; option 3 contradicts CH-15's
destructive boundary about irreversible harm. This is the decision that **most needs your authorship**
and the one where I am least willing to guess: quarantine duration, who may appeal, how long an appeal
may take and what the person is told are product judgements with no canonical answer.

**G. Blocks:** CH-12 **construction** (the examination mechanism is built *against* this route) · CH-15
**certification** (the false-positive proof is a named requirement) · **CH-12 closure**.

**H. Default if you decline.** No appeal route is designed. **CH-12's examination mechanism stays
blocked** — building a scanner whose verdicts have no appeal is explicitly forbidden by the destructive
boundary. CH-15's certification cannot be attempted.

---

# DECISION 4 — F137 MEDIA MODERATION SCOPE AND TIMING

**A. Question.** Which stored media kinds are examined, from when, and what is the product-visible state
of an object that has not been examined yet?

**B. What creates it.** F137 (`OPEN`, `ZERO_COVERAGE_SECURITY_GAP`), founder-reserved verbatim: *"Media
moderation (F137). Currently zero scanning of uploaded media. **Scope and timing is a governance
decision, not an engineering one.**"*

**C. Frozen, not open** (carried adequacy requirements — these are **not** re-decidable):
- Coverage of **every stored object, including a backfill** over the existing population. A go-forward
  filter is not sufficient.
- An **explicit product-visible interim state** for unexamined objects.
- **Quarantine as reversible retention**, not deletion.
- **Per-kind examination**, with documents (PDF, DOCX, PPTX) the **highest-risk and least-covered** kind.
- CH-12 owns the mechanism; CH-15 owns policy and consequence. Neither absorbs the other.

**D. Options.**
1. **All kinds from the start**, with backfill, documents included.
2. **Images first, documents in a named later phase**, with the interim state stating plainly that
   documents are unexamined.
3. **Defer scope**, keeping F137 open.

**E. Consequences.**
1. Matches the adequacy requirements exactly. Largest build; documents are the hardest kind precisely
   because they are the least covered.
2. Ships protection sooner on the easiest kind, but leaves the **highest-risk** kind uncovered — and
   F016 already records that the product does not honestly understand documents today. Defensible only
   if the interim state is genuinely honest to users.
3. Zero coverage continues on a gap already classified as a **security** gap.

**F. Recommendation — option 2, with the phase named and dated in the same ruling.** Option 1 is the
correct end state and I am not arguing against it; I am arguing against making the whole of it a
precondition. The frozen requirements are satisfied by option 2 *provided* the document phase is named
rather than implied — an unnamed later phase is how F137 nearly disappeared in the first place, which is
why the architecture pins it by identifier at four steps and two gates. **If you prefer option 1, nothing
in the evidence contradicts it.**

**G. Blocks:** CH-12 **construction** (scope determines what is built) · a **later policy consequence**
for the document phase. Does **not** block CH-15's own journey work.

**H. Default if you decline.** F137 stays `OPEN` at zero coverage, CH-12's examination mechanism is not
built, and the security gap persists. **I will not select a scope.**

---

# DECISION 5 — F095 IN-LIVE MODERATION OWNERSHIP *(real, but blocks nothing today)*

**A. Question.** Is F095's in-Live moderation surface delivered by **CH-09 consuming CH-15's authority**
(the architecture's proposal), or **owned by CH-15**?

**B. What creates it.** CH-15 `founderActions` item 4. `CO-RC-C10-019` "Live moderation policy" is CH-15's
one obligation, `FOUNDER_ACTION_ONLY`.

**C. A canonical tension I am surfacing rather than resolving.** CH-15's `nonGoals` already says *"Does
not own the in-Live moderation surface (CH-09)"* — while `founderActions` still asks whether it is
*"owned here"*. Those two lines of the same chapter record disagree. I am **not** resolving that by
reading one as superseding the other.

**D. Options.** 1. Ratify CH-09-consumes (matches `nonGoals`). 2. Assign to CH-15. 3. Defer.

**E. Consequences.** 1. Removes the tension; CH-15 stays small and policy-shaped. 2. Enlarges CH-15 into
a surface owner, contradicting its own `nonGoals`. 3. Tension persists in the record.

**F. Recommendation — option 1**, on the strength of `nonGoals` and the fact that CH-15 is explicitly
"deliberately small and deliberately not the owner of the scanning pipeline."

**G. Blocks: NOTHING today.** F095 is `OPEN` under your standing instruction **"LIVE — HOLD
IMPLEMENTATION FOR NOW."** This is *only a later policy consequence*.

**H. Default if you decline.** The tension stays recorded and unresolved; nothing is blocked.

---

# NOT RETURNED AS A DECISION — media examination provider selection

Stage 5 lists *"Media examination provider selection"* among CH-15/CH-12's open founder inputs. **I am
not returning it**, because it is already determined by frozen doctrine: the **Provider Independence
Doctrine** requires a **self-hosted tier-0 default** for every pluggable-provider capability, with
external providers as **tier-1 enrichment only**. That fixes the architecture. Which specific tier-0
engine is chosen inside that constraint is an engineering selection, not founder authorship.

Returning it would be elevating an implementation detail into a founder decision, which you asked me not
to do. **If you disagree and want to select the engine yourself, say so and I will treat it as open.**

---

# WHAT BECOMES EXECUTABLE — per ruling, without selecting any ruling

| Your ruling | Becomes executable immediately |
|---|---|
| **D1 taxonomy** (any option ≠ "keep free text") | CH-15 report-vocabulary construction; the governed reason enum + migration; CH-12 gains the verdict vocabulary it needs |
| **D2 ladder** (any option) | CH-15 consequence construction and its one-authority certification prep |
| **D3 appeal route** (any option) | CH-12 examination-mechanism construction — **this is the single highest-leverage unblock in the pack**; CH-15 false-positive certification design |
| **D1 + D3 together** | CH-12's examination mechanism becomes fully specifiable: categories to emit, and a consequence to apply |
| **D4 scope** | CH-12 per-kind scanner scope and the backfill obligation become buildable |
| **D5** | Nothing today (F095 is held) |

**CH-12 needs D1, D3 and D4.** D2 and D5 do not gate it.

Acceptance criteria I can prepare **without prejudging policy** (and have not written, because writing
them would encode an option): the one-authority proof, the report-journey end-to-end exercise, and the
backfill-coverage proof are all specifiable from frozen requirements alone once the vocabulary exists.

---

# COMPACT STATUS

**G1 leg 5(B) procedure: READY** — `docs/governance/G1_LEG5B_LIVE_CERTIFICATION_PROCEDURE.md`.
Blocked on deployment: the **F129 and D7 doors are not pushed** (`origin/main` has zero occurrences of
`verifyClientSuppliedObject`; backend is 6 commits ahead). The **D2 content-truth door is** on the
deployable branch, so Case A may be observable on the current deployment.

**One gap I could not close myself:** `GET /v1/health` returns no build identifier, so **backend live
certification cannot currently be bound to an artifact**. I recommend adding `{version, commit}` to it —
a few lines — but did not implement it, as it is unrequested work.

### Frontier by blocker

| Class | Units |
|---|---|
| **FOUNDER_INPUT_REQUIRED** | CH-15 (D1–D4) · CH-12 (via D1/D3/D4) |
| **EXECUTION_BLOCKED** | CH-12 (also leg 5(B)) · CH-05 (leg 3) · CH-04 (AD-CON-5, SU-5, VS-02, devices) |
| **CERTIFICATION_PREPARABLE** | G1 leg 5(B) ✅ done · CH-14 slice 1 live procedure · backend build attribution *(recommended, not built)* |
| **ANALYSIS_AVAILABLE** | this pack ✅ done · CH-15 dependency verification ✅ done |

### Work completed while blocked

1. G1 leg 5(B) procedure predeclared, with the door distinction made honestly — the **file** refusal is
   D2's, not F129/D7's, and I said so rather than letting the leg's wording imply otherwise.
2. Backend deployment state established technically (6 ahead; F129/D7 not pushed; content-truth is).
3. Backend build-attribution gap identified, with a recommendation.
4. CH-15 canonical evidence fully extracted; dependency on CH-11 verified as binding **construction, not
   the policy freeze**.
5. Existing moderation implementation inspected — the ladder exists and is reversible; **the appeal route
   does not exist at all**, which is the chapter's real gap.
6. Provider selection tested against frozen doctrine and **excluded** from the pack.

**After your CH-15 rulings** I will encode them as founder-authored policy with provenance, derive the
implementation obligations, update the canonical artifacts, rerun reconciliation, recalculate the
frontier and continue directly into whatever becomes executable — without stopping to ask again.
