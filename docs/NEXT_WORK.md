# Aura Release Client — Next Work

**As of 2026-08-15.** Roadmap frozen. **C0 implemented and fully adjudicated — awaiting final closeout review.**

---

## C0 — CROSS-CUTTING FOUNDATIONS ✅ IMPLEMENTED

Three authorities built, consumers migrated, hard gate in place, regression green.
Full record: `docs/frontend-discovery/C0_MIGRATION_REGISTER.md`.

> **The raw scope figures previously listed here were superseded by
> classification.** They over-counted, and acting on them directly would have
> produced the mass replacement the chapter forbids:
>
> | Raw figure | Actual |
> |---|---|
> | "83 files → shared loading state" | **26** full-surface sites; 91 spinner uses are legitimate inline progress |
> | "52 hand-rolled `.difference()`" | **41** human-facing; 28 are internal TTL/cooldown/debounce, and one was a `Set.difference` false positive |
> | "35 direct `toLocal()`" | **47** measured; 16 are Meetings |
> | "22 independent sorts" | **10** temporal; 16 non-temporal, out of scope |
> | "68 `SizedBox.shrink()` → empty states" | not adjudicated — most are legitimate conditional layout, and C0 did **not** convert them |

**In-chapter founder checkpoint: CLEARED.** The concrete vocabulary was
reviewed against the canonical Representation body and adjudicated on
2026-08-15. Final map: `C0_PRODUCT_LANGUAGE_VOCABULARY.md`.

**Obligations handed to later chapters by that adjudication**

| Chapter | Obligation |
|---|---|
| **C2** | Verification labels remain undecided — **no generic "Verified"**, now gate-enforced. Follow reconciliation (three inconsistent backend models). |
| **C5** | Official-designation and institutional-approval vocabulary, deliberately not pre-empted by C0. |
| **C7** | **Correspondence umbrella rename/migration** — choose the correct internal name, migrate safely, preserve compatibility and history. Paths may lag until then; documentation may not. |
| **C10** | Whether `Live` ever needs a plural form. |
| **All** | Re-verify `J`-basis G5 assignments against actual reconstruction scope before migrating. |

**Carried into later chapters as measured, enforced debt** — see
`test/product/c0_drift_baseline.txt`:
24 local elapsed-time sites · 47 `toLocal()` · 26 full-surface spinners
(**14 in Meetings, a protected certified surface**) · 181 direct
state-primitive constructions · 17 screen-declared time formatters.

**G5 ownership: ALL 181 sites assigned, zero unassigned** —
C1 42 · C2 21 · C3 44 · C4 26 · C5 16 · C7 26 · C8 3 · C9 3 · **C6 0**.
Full matrix with per-row basis codes: `C0_G5_OWNERSHIP_MATRIX.md`.

---

> **Every remaining chapter inherits the Aura Public-First Causal Doctrine.** Canonical
> source: `representation/inventory/AURA_PUBLIC_FIRST_CAUSAL_DOCTRINE.md`. Per-chapter inheritance is
> recorded in the roadmap. Roadmap ordering is unchanged by the doctrine.


## The next executable chapter

# C1 — ACTING CONTEXT & CAPABILITY PROJECTION ✅ COMPLETE

Founder approved / locally certified 2026-08-15. Registers:
`C1_AUTHORITY_ARCHITECTURE.md` · `C1_G5_DISPOSITION_MATRIX.md`.

**Two new product disposition checkpoints opened before C11:**
**PD-1 Platform Administration** (11 files / 34 G5 sites) and
**PD-2 Authentication & Account Entry** (2 files / 3 sites). Neither has an
owning chapter in the approved roadmap; both need a product decision.

---

## The next executable chapter

# C2 — IDENTITY, PRESENCE & PROFILE

**⛔ NOT STARTED. Awaiting explicit founder authorisation.** Roadmap approval is
**not** authorisation to start a chapter, and C1 closure is not authorisation for C2.

C1 unblocks it. C2 inherits: verification labels (open checkpoint, **no generic
"Verified"**, gate-enforced) · Presence retirement of its six-meaning overload,
now that presence is correctly the person · Follow reconciliation across three
inconsistent backend models · 21 assigned G5 sites (`J` basis — re-verify before
migrating, as C1 did).

**Unlocks.** C1.

---

## Chapter sequence

`C0 → C1 → {C2 ∥ C3} → {C4 ∥ C5 ∥ C6} → {C7 ∥ C8} → C10 → C11`, with **C9 overlapping where its dependencies permit**.

| Chapter | Blocked until |
|---|---|
| C1 Acting Context & Capability | C0 |
| C2 Identity, Presence & Profile | C1 |
| C3 Navigation & IA | C1 |
| C4 Attention | C2 + C3 |
| C5 Composition, Intake & Attachments | C2 + C3 |
| C6 Realtime Presentation Convergence | C2 |
| C7 Threads, Spaces & Correspondence | C4 + C5 + C6 |
| C8 Institution Room | C6 |
| C9 Cross-Platform | C4 + C5 (may overlap C10) |
| **C10 LIVE (cross-repository)** | **C0–C8 all stable** |
| C11 Item 17 | all chapters |

## Open implementation checkpoints — tracked, not backlog

| Item | Owning chapter |
|---|---|
| Orphan-cleanup windows vs draft lifetime | C5 |
| Presence privacy/visibility policy | C2 ⚑ |
| Verification label mapping | C2 ⚑ |
| Live moderation policy | C10 ⚑ |
| Live audience-scale topology/provider | C10 |
| `InstitutionCorrespondenceScreen` · `PresenceScreen` · `LoginScreen` | C7 · C2 · C3 |
| **`SupportScreen`** | **ownership undetermined → product disposition checkpoint** |
| Exact primary navigation destinations | C3 ⚑ |
| Thread vs Space Live differences | C10 |
| Drag/drop (0 implementations) | C5 + C9 |

## Explicitly NOT next

Live (C10) · Item 17 (C11) · any demolition · any route change · Representation edits before wording is frozen.

---

## 2026-08-18 — Wave 1 Parts 1 & 2 complete; what is next

**Done (nothing closed).** W1-000 PBCR 7+8 discharged · W1-A CH-17 governance mechanism (both repos) ·
W1-B CH-01 ratchets, 11/11 proven ENFORCING by seeded failure · W1-F 335-consumer identity audit ·
W1-C/D/E the CH-02 keystone S1–S3 with the PD-2 seam published and gated.

**Owed before CH-02 can close — none of it is optional:**

1. **F065 LIVE REFRESH PROOF.** The chapter's own first gate. A live authenticated session that
   survives a browser refresh without dropping to unauthenticated. Requires a running app and
   **PB-11 founder observation** of the authentication behaviour change. Until it passes, no
   downstream continuity finding may be claimed closed.
2. **Live signed-out probe** for the route-classification contract (S2). Fail-closedness is proven by
   gate, not yet on a live browser.
3. **F103 / F104** remain `OPEN`, gated by F065.
4. **CH-02 S4** (draft identity/ownership contract) still refused — it consumes CH-03's conformance
   gate, which is W2.

**Blocked on a founder decision:** W1-X1 (CH-11) needs the **RC-C5 scope ratification** — does the
BIFURCATED ruling answer CH-11's recorded scope question? Fail-closed default is *treat as gated*, so
CH-11 has not been started.

**Assigned but not scheduled:** DEFECT-1 — `realtime_room_golden_test.dart` is skipped for
pre-existing rot, so realtime *rendered* presentation has no automated visual proof. Assigned to
CH-04, not waived; restoration/replacement is a CH-04 closure requirement. The 333-pass realtime suite
must never be represented as covering it.

---

## 2026-08-19 — CH-03 typed-person convergence complete; two founder decisions owed

**Done.** The two instrument rulings executed (domain-aware detector · enforcing
`NON_CANONICAL_PERSON_DESERIALIZATION`, proven enforcing by a seeded violation), then the typed
boundaries migrated: **62 -> 18 typed-person sites**, three measurements kept separate. Full record:
`docs/portfolio/run/stage0-2026-08-18/05-execution/ch03-f116-typed-person-convergence.json`.

**Owed before F116 / F053 can move past PARTIALLY_VALIDATED — both are founder decisions, not work:**

1. **NARROW RULING — the `'Guest'` default in `MeetingIdentityRef`.** Legitimate on the GUEST branch
   (an external non-Aura contact; GUEST is a meeting ROLE). The F054 invented-label defect on the
   **AURA_USER** branch, where an identifiable Aura person is named by a role they do not hold.
   Correcting it decides what an unnamed Aura participant is called in the meeting UI — protected
   Meetings semantics, so it was returned rather than changed.
2. **AUTHORIZATION — the four protected Meetings domain models** (`meeting_identity`, `meeting`,
   `availability_profile`, `meeting_entry_resolution`, **16 sites**). They are the remaining half of
   F116 criterion 2. Measured, not excluded; no Meetings file was modified.

**Retained by design, not owed:** 2 polymorphic feed actors (`FeedSignalActor`, `FeedReplyAuthor`)
consume the union projection (`handleOrSlug` / `avatarOrLogoUrl`) emitted for a user OR an
institution. Composing person identity onto them would force person semantics onto institutions.
They stay measured so the decision stays visible.

## 2026-08-19 — CH-03 CLOSED: the protected Meetings pass, Guest semantics, and the feed actors

Both decisions above were granted. Both are now executed, and **typed-person debt is zero**.

**The founder ruling, on both sides of the wire.** An AURA_USER is never named `'Guest'` — the client
delegates that branch to `AuraPersonIdentity` and `buildAuraUserBookerIdentity` stops emitting the
string, which is the only backend change in the pass and the only one that could work (no client fix
undoes a literal `'Guest'` already written into a person's `displayName`). A genuine external CONTACT
or GUEST **keeps** `'Guest'`, because for them it is a truthful statement of what they are.
**PERSON IDENTITY ≠ MEETING ROLE / EXTERNAL PARTICIPANT TYPE.**

**All 16 Meetings sites dispositioned** — 14 converged outright, 2 split (one line each in
`meeting_identity` and `meeting_entry_resolution` was serving both a person branch and an external
branch). Every public accessor kept its type and nullability, so no Meetings surface changed:
**MEETINGS BEHAVIOR PRESERVED.**

**The two feed actors were classified from their producers, not their field names** — and the brief's
premise needed one correction: `handleOrSlug` / `avatarOrLogoUrl` are emitted by
`feed-projection.service.ts` for the **post author**, not for either of these DTOs, both of which carry
plainly named fields. `FeedSignalActor` is a **true PERSON | INSTITUTION union** (two backend builders,
`userActor` / `institutionActor`): union retained, person branch delegated, institution identity kept in
institution terms so no slug can be read through a person-shaped accessor. `FeedReplyAuthor` is a
**person model** — every reply author comes from one builder, `userAuthor`, routed to `/u/:handle` — that
had been accepting institution aliases it is never sent. Fully converged.

**One governed non-promotion, recorded not hidden.** `MeetingEntryResolution.identityName` delegates its
parsing but deliberately does not answer with the canonical label: the pre-join screen pre-fills the
entrant's own name box from it, so 'Someone' would be typed into a stranger's name field.

**States.** F116 and F053 both advance **PARTIALLY_VALIDATED → IMPLEMENTED_NOT_LIVE_CERTIFIED**; all six
F116 criteria met. F052 gains structural evidence without promotion. F054 gains implementation evidence
only — not promoted from association. F055–F057 unaffected. **F051 preserved untouched as a conflict.**

**Next executable frontier: the 19 SURFACE sites across 11 files** — widgets reading person fields off
untyped maps. Separately measured, separately ratcheted, and the last named residue on F053.

Record: `docs/portfolio/run/stage0-2026-08-18/05-execution/ch03-f116-meetings-guest-and-feed-actor-closeout.json`.
Ratchet proof: `tool/meetings_person_ratchet_proof.mjs` (PASS both directions).
