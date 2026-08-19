# CH-15 MODERATION POLICY — FOUNDER-AUTHORED

**Authority: FOUNDER RULING, 2026-08-18.** Every section below is founder-authored policy, not
engineering judgement and not a Claude recommendation. Where a recommendation was made in the decision
pack it is noted only as provenance; the ruling is what governs.

**Accounting unchanged: 143 findings + 308 obligations = 451 canonical units · 17 chapters.**
No canonical unit was created by these rulings. No Stage-0 evidence was rewritten.

---

## D1 — PROHIBITED-CONTENT TAXONOMY · **RESOLVED**

**Ruling.** Adopt a small, extensible, governed taxonomy with an explicit `OTHER`.
`ModerationReport.reason` must not remain unrestricted free text as the canonical policy classification
mechanism. Categories must derive **only** from shipped behaviour, frozen doctrine, canonical
findings/obligations, or evidenced corpus vocabulary — **not** from general moderation theory. Every
member records its canonical evidence. Expansion happens through governed policy change, not
application strings.

### The six canonical categories, each with its evidence

| Token | Label | Canonical evidence |
|---|---|---|
| `HARASSMENT_OR_ABUSE` | Harassment or abuse | `report_repository.dart` — `ReportReason.harassment.wire`, shipped |
| `HATE_OR_OFFENSIVE` | Hate or offensive content | `ReportReason.hate.wire`, shipped |
| `SEXUAL_CONTENT` | Sexual content | `ReportReason.sexual.wire`, shipped |
| `VIOLENCE_OR_THREAT` | Violence or threats | `ReportReason.violence.wire`, shipped |
| `SPAM_OR_SCAM` | Spam or scam | `ReportReason.spam.wire`, shipped |
| `OTHER` | Something else | `ReportReason.other.wire`, shipped — and required by the ruling so bounded governance never makes reportable conduct unreportable |

**Nothing was invented.** All six already existed in the shipped client
(`aura_final/lib/core/compliance/report_repository.dart:47-75`), which describes them as *"the standard
six reason categories Apple expects"* and keeps the wire tokens *"stable across releases."*

**The defect, exactly.** The taxonomy lived **only in the client**. The backend accepted any string up
to 200 characters, so the policy vocabulary was a convention one client happened to follow rather than a
governed contract — an older build, a second client or a direct API call could file in any vocabulary at
all.

**Verified before enforcing:** the shipped client sends `reason.wire` (`report_repository.dart:114`),
so the governed set matches production traffic exactly. **No existing reporting path breaks.**

### Enforced at the write boundary, not as a database enum — and why

`ModerationReport.reason` is an existing `String` column holding historical rows written before any
taxonomy was governed. Converting it to a database enum would require **rewriting those rows** — which
is production-data mutation, is not authorized, and collides with CH-15's own destructive boundary:
*adjudication data is evidence and must not be patched to tidy a queue.*

Enforcement therefore sits where policy is actually applied: the write boundary
(`CreateReportDto.reason`). History stays readable and unedited; nothing new enters ungoverned.

### Recorded, NOT resolved — a second taxonomy exists

`AIReportCategory` is a **separate, database-enforced** seven-member enum for reports about **AI
responses** (`POST /ai/reports`). Its vocabulary overlaps this one without matching it:

| Content report | AI report |
|---|---|
| `HARASSMENT_OR_ABUSE` | `HARASSMENT_OR_HATE` |
| `HATE_OR_OFFENSIVE` | *(folded into the above)* |
| `SEXUAL_CONTENT` | `SEXUAL_OR_INAPPROPRIATE` |
| `VIOLENCE_OR_THREAT` | `VIOLENCE_OR_SELF_HARM` |
| `SPAM_OR_SCAM` | `SPAM_OR_ABUSE` |
| — | `HARMFUL_OR_UNSAFE`, `FALSE_OR_MISLEADING` |

**They are not merged.** Whether reports about AI output fall inside CH-15's *"one authority"*
requirement — and if so which vocabulary survives — is a founder policy question that was **not asked
and has not been answered**. Merging them would be authoring policy by inference, which D1 forbids.
**Recorded for founder disposition. It blocks nothing today.**

---

## D2 — CONSEQUENCE LADDER · **RESOLVED**

**Ruling.** Ratify the existing shipped 14-action ladder as the canonical current consequence set. Do
not redesign it merely because CH-15 is being reconstructed. Preserve action identities, reversal
relationships, authority boundaries and auditability.

**The ratified ladder** (`ModerationActionType`): `NOTE` · `WARN` · `REQUEST_CLARIFICATION` ·
`REQUEST_REVISION` · `SOFT_DELETE_POST`/`RESTORE_POST` · `SOFT_DELETE_MESSAGE`/`RESTORE_MESSAGE` ·
`ARCHIVE_SPACE`/`RESTORE_SPACE` · `ARCHIVE_THREAD`/`RESTORE_THREAD` · `DISABLE_USER`/`RESTORE_USER`.

**Reversibility is satisfied structurally:** every destructive action has a corresponding restore path.
That is what CH-15's destructive boundary requires, and it is why no redesign was warranted.

**State change:** `IMPLEMENTED` → **`FOUNDER_RATIFIED_AS_POLICY`**. No code change. The ladder was
already correct; what it lacked was authorship.

---

## D3 — AUTOMATED VERDICT · QUARANTINE · APPEAL · **RESOLVED**

**The governed chain:**

```
AUTOMATED EXAMINATION
  → QUARANTINE when the governed verdict requires delivery to stop
  → NOTICE
  → HUMAN APPEAL / REVIEW
  → FINAL GOVERNED DISPOSITION
```

**Both alternatives explicitly rejected.** Advisory-only is rejected — *a scanner whose verdict cannot
stop delivery is not an effective examination system.* Silent auto-final enforcement is rejected — *a
false automated verdict without a meaningful appeal route creates irreversible product harm.*

**Appeal standing.** The actor whose governed content was quarantined: the person who owns/published it,
the authorized institution actor for institution-owned content, or another canonical content authority
under Aura's existing authority model. **Standing is never created by possession of an object id, URL or
other reference** — the same principle D7 froze.

**Notice must state, in understandable product language:** what was quarantined · that use is restricted
· the applicable canonical category · that the verdict was automated where applicable · sufficient
non-sensitive context to understand it · whether the state is preliminary or final · how to appeal · the
current appeal status. **Detector internals, thresholds and anything enabling evasion are excluded.**

**Human review** is the authority for final disposition unless a separately frozen policy establishes
another. It may uphold, reverse/release, apply the appropriate governed consequence, or require further
evidence. Every outcome is auditable, and **no invisible permanent penalty may survive a successful
reversal.**

**Timing — deliberately no invented SLA.** No fixed 24/48/72-hour target is created without evidence
that operational review capacity exists. Instead: appeals enter a **prioritized queue**; status stays
**visible**; quarantine remains **explicit** while unresolved; and unresolved review must **neither**
silently become permanent removal **nor** silently auto-release on a timer. SLAs may be established later
through founder-authorized moderation operations policy once staffing exists.

---

## D4 — F137 MEDIA EXAMINATION SCOPE · **RESOLVED**

**Canonical end state:** examination coverage for **all** uploaded media classes within the governed
media scope.

**Authorized sequence:** **Phase 1 — image examination.** **Phase 2 — remaining uploaded media** —
document, audio, video and other governed classes identified by the canonical media matrix.

**Phase 2 is not optional and is not a future enhancement. It is a named CH-12 closure requirement.**

- CH-12 **may** begin and make progress with images first.
- **CH-12 MUST NOT CLOSE while applicable uploaded-media classes remain unexamined.**

**No arbitrary calendar date** is created for the appearance of certainty. The binding invariant is
stronger than a date:

> **ALL APPLICABLE F137 MEDIA CLASSES MUST BE COVERED BEFORE CH-12 CLOSURE.**

If a media class is proven technically or policy-wise outside F137's canonical scope, that evidence is
documented explicitly — never silently excluded.

**Carried adequacy requirements remain frozen and are not re-decidable:** coverage of every stored object
**including backfill** over the existing population · an explicit product-visible interim state for
unexamined objects · **quarantine as reversible retention, never deletion** · per-kind examination.

---

## D5 — F095 IN-LIVE MODERATION OWNERSHIP · **RESOLVED**

**CH-15 owns:** moderation policy · consequence semantics · policy/category contracts · the moderation
authority requirements applicable to Live.

**CH-15 does not own:** the in-Live product surface · Live presentation · Live interaction
implementation, merely because moderation applies there.

**The CH-15 `nonGoal` stands.** The conflicting `founderActions` wording asking whether the in-Live
surface is *"owned here"* is **superseded by this ruling** — the canonical tension is resolved by
founder authority, not by reading one line as beating the other.

F095 remains with the canonical Live/surface owner under its existing **HOLD IMPLEMENTATION** state.
When that surface executes, it **must consume CH-15's governed moderation contract** rather than
reimplement moderation policy locally.

**Blocks no current construction.**

---

## PROVIDER SELECTION — engineering, not founder authorship

Remains an engineering decision under the Provider Independence Doctrine. It returns to the founder
**only** if a proposed provider would violate provider independence, privacy/security policy, data
custody, deployment/governance constraints, or another founder-frozen architectural boundary.

---

## DERIVED IMPLEMENTATION OBLIGATIONS

| # | Obligation | Owner | From | Status |
|---|---|---|---|---|
| O1 | Governed category enforced at the report write boundary | CH-15 | D1 | **DONE** — `moderation-categories.ts`, `CreateReportDto`, 22 tests |
| O2 | Free-text context coexists with, never replaces, the category | CH-15 | D1 | **DONE** — `details` preserved; asserted by test |
| O3 | Ladder recorded as founder-ratified policy | CH-15 | D2 | **DONE** — this document |
| O4 | Quarantine as a reversible retention state | CH-12 | D3, F137 | **BLOCKED** — needs the examination mechanism |
| O5 | Notice carrying all eight required elements | CH-15 | D3 | **BLOCKED** — nothing to notify about until O4 |
| O6 | Appeal standing per the authority model, never from reference possession | CH-15 | D3 | **BLOCKED** — with O5 |
| O7 | Prioritized review queue; no silent removal, no silent auto-release | CH-15 | D3 | **BLOCKED** — with O5 |
| O8 | Phase 1 image examination | CH-12 | D4 | **BLOCKED** — G1 leg 5(B) |
| O9 | Phase 2 remaining media classes — **a closure requirement, not an enhancement** | CH-12 | D4 | **BLOCKED** — follows O8 |
| O10 | Backfill over objects uploaded before the scanner existed | CH-12 | D4, F137 | **BLOCKED** — follows O8 |
| O11 | Live surface consumes this contract rather than reimplementing it | CH-09 | D5 | **HELD** — F095 hold |
| O12 | AI-report taxonomy divergence disposition | — | D1 | **FOUNDER INPUT** — blocks nothing |

**O4–O10 are blocked by CH-12's real dependency, not by policy.** The policy is now complete enough to
specify them; the gate that holds them is G1 leg 5(B).
