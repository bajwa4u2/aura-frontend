# Representation → Frontend Canonical Alignment

**Date:** 2026-08-15 · **Status:** ✅ **FOUNDER APPROVED.** All five surfaced matters resolved and applied. Later chapters C1–C10 **must consume this artifact** rather than rediscovering the authority hierarchy.
**Pass type:** originally read-only; three founder-authorised reconciliations were subsequently applied to Representation — see section J.
**Purpose:** prove the Release Client's Product Language Authority was reconciled against the already-governed canonical body, rather than inventing a product language from the frontend outward.

---

## A. Representation sources reviewed, and why each is authoritative

| Source | Authority basis | Bearing on Product Language |
|---|---|---|
| `representation/REPRESENTATION_CONSTITUTION.md` | Constitutional authority for the `representation/` workspace | **Establishes the authority direction** — see the correction below |
| `representation/inventory/PRODUCT_IDENTITY_CANON.md` | *Sole* authority for Identity, Purpose, Governing Philosophy, Scope of four products. Founder decision 2026-07-30. "Where a conflict is found, this canon wins." | Highest-authority product vocabulary |
| `representation/inventory/AURA_REPRESENTATION_MODULE_INVENTORY.md` | Seven **FROZEN — Founder Approved** representation modules, with **Binding Framing Directives** | The canonical module/feature nouns |
| `representation/inventory/PUBLIC_REPRESENTATION_CANON.md` | Sole authority for public voice and argument structure. Founder decision 2026-07-31. | Banned lexicon; anti-reduction rule |
| `representation/inventory/AURA_LIFECYCLE_MODULE_AUDIT.md` | Evidence-based read of actual Prisma models and service code | Presence / Follow / Relationship reality |
| `representation/inventory/MODULE_ANALYSIS_AURA_INSTITUTIONAL_COMMUNICATION.md` | Frozen module's originating analysis | Correspondence composition |
| `representation/identity/PRODUCT_IDENTITY.md` | Representation's own identity | Confirms Representation ≠ product authority |
| `aura-backend/identity/PRODUCT_IDENTITY.md` | **Pointer only** — defers to the canon above | Confirms precedence |
| `aura-backend/capability/CAPABILITY_AUTHORITY.md` | Sole authority for Aura's capabilities | Capability-level nouns |
| `aura-backend/capability/INSTITUTION_SPACE_MEMBERSHIP_DOCTRINE.md` | **FOUNDER-APPROVED, FROZEN** | **Binding UI label semantics** |
| `aura-backend/capability/AURA_RELEASE_CLIENT_CONSOLIDATED_ROADMAP.md` | Founder Acceptance Register | The identity-projection invariant chain |

### The operative authority chain — founder-recorded 2026-08-15

The instruction originally framed the chain as `FROZEN DOCTRINE → REPRESENTATION → RELEASE CLIENT`. The Representation Constitution states the opposite for **product truth**: *"Representation cannot originate a fact about a product — it can only cite one."* The founder accepted this correction and recorded the accurate relationship:

| Layer | Owns | Does not own |
|---|---|---|
| **Implementation / product authority** (`aura-backend`) | product facts and capabilities | identity/purpose/scope framing |
| **Founder-frozen governance decisions** (FD-1…FD-13, named freezes) | later authoritative **semantic** decisions | day-to-day capability facts |
| **Representation** | reconciles and canonically **presents** product truth *within its authorised scope* | inventing product facts |
| **`PRODUCT_IDENTITY_CANON`** | centrally authoritative **only within the scope the Representation governance structure explicitly grants it** — Identity, Purpose, Governing Philosophy, Scope | capability, architecture, implementation |

**The nuance that matters for reconstruction:** the frontend consumes Representation's canonical presentation **where it is valid**, and **stale Representation wording never overrides later founder-frozen product truth**. Three matters in this document turned on exactly that rule.

`aura-backend/identity/PRODUCT_IDENTITY.md` is now a pointer that concedes the four central sections while keeping capability and implementation product-owned.

### Reading key for later chapters

| Marker | Meaning |
|---|---|
| ✅ **CANONICAL CURRENT AUTHORITY** | binding today; consume it |
| ⛔ **SUPERSEDED HISTORICAL AUTHORITY** | preserved for chronology; must not be reintroduced |
| 🔧 **IMPLEMENTATION-OWNED PRODUCT FACT** | `aura-backend` decides; Representation may only cite |
| 📣 **REPRESENTATION-OWNED PRESENTATION** | naming/framing, within granted scope |
| 🧊 **FOUNDER-FROZEN OVERRIDE** | a later decision that prevails over earlier wording |
| 💬 **LEGITIMATE CONTEXTUAL TERMINOLOGY** | valid in its context; not a canonical redefinition |

---

## B. Canonical product / identity findings

1. **Aura is an institutional platform for civic discourse.** Scope: institutional identity and authority; public discourse and civic participation; institutional communication *including announcements and correspondence*; meetings and live interaction; trust infrastructure.

2. **Seven frozen representation modules**, with Aura Identity as the architectural root:
   `Aura Identity → Institutional Identity → Discovery → Public Discourse → Institutional Communication → Meetings & Live → Public Engagement`

3. **Binding Framing Directives** (frozen 2026-07-11/12) constrain vocabulary directly:
   - Discovery — *never "directory," never "search technology"* (**superseded — see D-1**)
   - Public Discourse — *accountable public dialogue, not social networking or a traditional feed*
   - Institutional Communication — *trusted institutional communication, not messaging / email-marketing / broadcast / notification software*
   - Public Engagement — *not FOIA / government records / legislative tracking*
   - Aura Identity — *is **not** Authentication, Login, User Accounts, or Member Profiles; those are implementation mechanisms*

4. **Anti-reduction rule** (`PUBLIC_REPRESENTATION_CANON` B.8): Aura must not be reduced to meetings, membership, association management, institutional relationship management, institutional communication software, community software, or social media. Public institutional communication, publication, and public/civic discourse remain first-class.

5. **Identity-projection invariant** (backend, Founder Acceptance Register): `SPACE MEMBER → THREAD PARTICIPANT → DM PARTICIPANT → MESSAGE AUTHOR → CALLER/CALLEE → ACTIVE CALL PARTICIPANT` must remain recognizably connected to the same canonical identity. Explicitly **not acceptable**: *"generic platform ('Aura') identity substituting for human/institution identity."*

6. **Binding UI label semantics already frozen** (`INSTITUTION_SPACE_MEMBERSHIP_DOCTRINE`): **Add Member** ≠ **Invite Person** ≠ **Manage Invites**. *"The product must distinguish these operations honestly, never renaming one into the other as a shortcut fix."*

---

## D. Representation ↔ frozen-decision conflicts

### D-1 · "trusted discovery" vs "directory" — **REPRESENTATION STALE / DRIFTED**

| Source | Date | Says |
|---|---|---|
| `AURA_REPRESENTATION_MODULE_INVENTORY` Discovery directive | 2026-07-11 | *never "directory" … always "trusted discovery"* |
| `PRODUCT_IDENTITY_CANON` | 2026-07-30 | Aura has *"a **public institution directory**"* |
| `PUBLIC_REPRESENTATION_CANON` B.5 | 2026-07-31 | *"'trusted discovery' and similar constructions are **banned**"* |

The later canon **bans the exact phrase the earlier directive mandates**, and simultaneously uses the word the earlier directive forbids. By precedence rule A the two 2026-07-30/31 canons win.

**RESOLVED — founder decision 2026-08-15: supersession authorised and applied.** ⛔ The 2026-07-11 directive is now struck through and annotated in `AURA_REPRESENTATION_MODULE_INVENTORY.md` with superseding authority, reason and chronology. The original text was **not deleted**.

✅ **Current framing:** "public institution directory" is permitted; `public_institutions_directory_screen.dart` is correctly named. **Discovery remains a valid module name** and "Institution Discovery"/"Public Space Discovery" remain correct feature names — only the trust-claiming framing is superseded. "trusted discovery" is now **gate-enforced absent** from the client.

### D-2 · "Correspondence" means two different things — **FOUNDER DECISION REQUIRED**

| Layer | Meaning |
|---|---|
| Representation (frozen module, 2026-07-11) | Correspondence is a **capability bundle**: *"Spaces, threads, messages, direct threads, private communication hub"* |
| FD-10 (2026-08, later) | Correspondence is a **distinct governed formal form**, explicitly `CORRESPONDENCE != MESSAGE/DM` |

Both are founder-frozen. They are not obviously contradictory — one names a module, the other a product noun — but **one word now carries two governance meanings**, and the frontend has surfaces named for each (`correspondence_hub_screen` = the bundle; Correspondence-as-form = the FD-10 noun).

**RESOLVED — founder decision 2026-08-15: ONE canonical meaning.** 🧊 **Correspondence = a distinct governed formal/deliberate communication form** (FD-10). ⛔ The umbrella sense is classified **LEGACY / ARCHITECTURAL NAMING DRIFT** and has lost canonical product status.

No broad module/path rename during C0 — that would be unrelated churn. **C7 obligation recorded:** determine the correct umbrella/internal name and migrate safely, preserving compatibility and history. Filesystem and package naming (`lib/features/correspondence/`, `CorrespondenceIdentity`, `correspondence_hub_screen`) may retain the legacy sense until C7; **documentation and the Product Language Authority may not.**

### D-3 · "not messaging software" vs `Message` / `DM` as product nouns — **LEGITIMATE CONTEXTUAL DIFFERENCE**

The Institutional Communication directive forbids representing *Aura* as messaging software. It does not forbid a message object existing in-product; the same frozen module lists *"messages, direct threads"* as its own evidence. **Aligned — no change.** The constraint binds public representation, not UI nouns.

### D-4 · Scope boundary of the public voice canon — **NOT A CONFLICT, recorded to prevent one**

`PUBLIC_REPRESENTATION_CANON` Non-Goals: it applies to `company.auraplatform.org` and the product pages it hosts — *"not the separate product-app domains' own independent marketing surfaces."*

**The Release Client UI is therefore not governed by that canon's voice rules.** Its banned-lexicon and register rules must **not** be imported wholesale into product UI copy. What *does* bind the client is the anti-reduction rule (B.8), because that protects product identity rather than voice.

---

## E. Frontend implementation drift found

| # | Drift | Severity |
|---|---|---|
| **E-1** | **RESOLVED — implemented in C0 by founder decision 2026-08-15.** `ProductAction.addMember` / `invitePerson` / `manageInvites` added with distinct canonical labels, plus a gate proving they cannot collapse into one another or into the generic `invite`. | RESOLVED |
| **E-2** | **RESOLVED.** 🧊 Founder decision 2026-08-15: **PERSON = canonical human identity; MEMBER = contextual relationship status.** Both nouns now carry that doctrine in their own documentation and are gate-enforced un-flattened. *Correction to my earlier report: I attributed the "Aura member" wording to `PRODUCT_IDENTITY_CANON`. It is not there — that document contains no instance of "member". The wording is in `AURA_REPRESENTATION_MODULE_INVENTORY.md` only, and that is where the reconciliation note was applied.* | RESOLVED |
| **E-3** | `ProductNoun.live` has `singular == plural == 'Live'`, a placeholder rather than a decision. Representation records *"'Live' founder-asserted, evidence thinner."* | **OPEN — carried to C10.** Not raised as a blocking decision: FD-5 already froze Live as a governed *mode/state* of a Thread or Space, so a plural form may legitimately never be needed. |

## F. Representation drift found

| # | Drift | Classification |
|---|---|---|
| **F-1** | Discovery framing directive mandates a phrase later canon bans (D-1) | REPRESENTATION STALE / DRIFTED |
| **F-2** | **MY OWN AUTHORING ERROR — now corrected across three repositories.** I had written `2026-08-16` into documents and source comments over several sessions. Founder confirmed the cause; corrected per `docs/DATE_CORRECTION_2026-08-15.md`. | **CORRECTED** |

---

## G. Representation → Frontend authority map

| Representation authority | Frontend authority | Chapter(s) | Expected consumer surfaces | Alignment check |
|---|---|---|---|---|
| `PRODUCT_IDENTITY_CANON` — Aura identity/scope | Product Language Authority | **C0** | all | anti-reduction rule B.8 holds |
| Aura Identity module (root) + *"not Authentication/Login/User Accounts"* | Identity Projection | **C2** | profile, me, auth | platform identity never presented as an account record |
| Institutional Identity module | Institution identity presentation | **C1 · C2** | institution profile/detail | institution ≠ user |
| Institution authority *"delegated narrowly … never an undifferentiated admin role"* | Capability Projection | **C1** | every gated control | no generic "Admin" label for a delegated capability |
| Discovery module (D-1 resolved) | Discovery/IA naming | **C3** | directory, sector, units, search | "directory" permitted; "trusted discovery" banned |
| Public Discourse — Public Posts · Institution Posts · Replies · Unified Feed | Post/Reply vocabulary | **C3 · C5** | feed, post detail, thread | Post is the canonical publication object |
| Institutional Communication — Announcements · Communications Center · Correspondence | Correspondence/Announcement vocabulary | **C4 · C5 · C7** | announcements, comms centre, correspondence | D-2 collision flagged |
| `INSTITUTION_SPACE_MEMBERSHIP_DOCTRINE` UI semantics | **Missing — see E-1** | **C0 → C7** | space members, invites | Add Member ≠ Invite Person ≠ Manage Invites |
| Identity-projection invariant chain | Identity Projection | **C2 · C6 · C7** | member/participant/author/caller | no generic "Aura" identity substitution |
| Meetings & Live module | Realtime presentation | **C6 · C10** | meetings, live | "Live" evidence thinner — do not over-claim |
| Public Engagement — *not FOIA* | Public record presentation | **C5 · C10** | public record surfaces | framing directive holds |
| Aura Identity evidence boundary (no portable reputation / cross-institution aggregation / verifiable credentials) | Verification Projection | **C2** | profile, badges | must not imply an unbuilt layer |

---

## H. Later roadmap chapter impacts

| Chapter | Must consume |
|---|---|
| **C0** | E-1 correction; D-2 flagged; anti-reduction rule |
| **C1** | *authority delegated narrowly, never an undifferentiated "admin" role* — a labelling constraint, not only a model constraint |
| **C2** | Aura Identity ≠ Authentication/Login/User Accounts; the evidence boundary (⚑ this constrains the already-open **verification label** checkpoint — see I-2); Presence has **no** canonical representation status, only a heartbeat implementation |
| **C3** | D-1 resolution; Public Discourse *"not a traditional feed"* while the frozen feature is literally "Unified Feed" |
| **C4** | Institutional Communication *"not notification software"* — attention language must not read as a notification product |
| **C5** | Announcements ≠ Posts ≠ Correspondence as three frozen capabilities; E_OFFICIAL/approval language |
| **C7** | D-2 must be resolved before Correspondence surfaces are rebuilt; E-1 label semantics land here |
| **C8** | "Institution Room" has **no** canonical Representation source — it is a backend (D5) construct |
| **C10** | *"Live" founder-asserted, evidence thinner* — Live language must not outrun evidence |

---

## I. Founder decisions required

- **I-1 — E-1.** Should `ProductAction` encode `addMember` / `invitePerson` / `manageInvites` as three distinct canonical actions now (C0), or is this C7's to land? *My recommendation: encode in C0 now — a frozen doctrine with a known shipped defect should not wait behind six chapters.*
- **I-2 — E-2.** Is the canonical noun for a platform person **Member** (canon's "every Aura member") or **Person** (FD-10's `PERSON != … MEMBERSHIP`)? If Member, "institution member" needs a distinguishing term.
- **I-3 — D-2.** Does "Correspondence" remain both a module name and a distinct product noun?
- **I-4 — F-1.** Authorise marking the Discovery framing directive superseded.
- **I-5 — F-2.** Confirm the 2026-08-16 date stamps.

---

## J. Representation changes recommended — NONE EXECUTED

| Change | Type | Status |
|---|---|---|
| Mark Discovery framing directive superseded by the two later canons | **Semantic** — edits a frozen module record | Awaiting I-4 |
| Record the D-2 word collision | Semantic | Awaiting I-3 |
| Confirm/correct 2026-08-16 stamps | Non-semantic | Awaiting I-5 |

No mechanically-required, unquestionably non-semantic correction was found, so **nothing was edited**.

---

## L. Minimum practical enforcement

Per the instruction not to build a cross-repository governance platform, the enforcement added is **one gate rule in the existing C0 gate** — no new infrastructure, no cross-repo tooling:

Two tests were added to `test/product/c0_anti_drift_gate_test.dart`:

1. **Representation-backed nouns keep their canonical terms.** Pins only the nouns a frozen founder-approved module actually names — Institution, Space, Meeting, Post, Announcement, Participant, and the `Reply` action. Renaming one of these is renaming canon, and now fails the build.
2. **Concepts with no canonical existence never enter the vocabulary.** `connect` / `connection` / `works` are asserted absent, because the lifecycle audit found *zero* matches for a Relationship or Connection model and the canonical body has no "Works". This is the rule most likely to be violated by a later chapter reaching for a familiar social-product word.

**The membership-operation labels (Add Member / Invite Person / Manage Invites) are deliberately NOT enforced yet**, because they are not implemented — that change is product-significant and is reported for decision **I-1** rather than applied silently. The gate will be extended when the decision lands.

Everything else in this document is a **register consumed by later chapters**, not a runtime check — deliberately.
