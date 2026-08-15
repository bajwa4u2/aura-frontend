# Frontend Reconstruction — Traceability Matrix

**No orphan obligations.** Every historical item, extended-scope item, frozen decision, named freeze and major discovery appears exactly once with a chapter home.

---

## A. Original Release Client Items 1–17

| Item | Chapter | Construction | Migration | Enforcement | Certification | Founder checkpoint |
|---|---|---|---|---|---|---|
| **1** Communication Runtime Lifecycle Authority | **C6** | shared realtime presentation over preserved transport | none (transport preserved) | no reimplementation of canonical primitives | Arch·Impl·Product-Behavior | participation direction |
| **2** Device Communication Presence Authority | **C6** (+C2 presence projection) | preferred-device visibility; presence projection | presence reads move to authority | no local presence inference | Arch·Impl | presence privacy ⚑ |
| **3** Notification Delivery Authority | **C4** (+**C9** native) | attention projection; native presentation | notification destinations re-pointed | no local notification delivery | Product-Behavior·Real-Boundary | attention direction ⚑ |
| **4** Identity Foundation | **C1** + **C2** | acting context, capability, identity projections | profile data preserved | no local role/identity derivation | Arch·Impl·Cross-System | verification labels ⚑ |
| **5** Compose Link Intelligence / OG Preview | **C5** | governed link previews via backend intelligence | preview behaviour preserved | no client-side metadata fetching | Product-Behavior | composition direction ⚑ |
| **6** Communication Timeline Authority | **C0** (temporal) + **C4** | temporal authority; attention ordering | 52 hand-rolled sites migrated | sorting declares its event | Arch·Impl | product language ⚑ |
| **7** Realtime Architecture Correction | **C6** (+**C9** device pass) | convergence; native/device behaviour | slice-by-slice | FD-3 semantics protected | Product-Behavior·Real-Boundary | per-slice sign-off ⚑ |
| **8** iOS Firebase/APNs | **C9** | native notification presentation | device registrations preserved | no per-platform semantic forks | Real-Boundary | desktop/mobile direction ⚑ |
| **9** Runtime Lifecycle Phase 2 | **C6** | lifecycle presentation on converged primitives | continuity preserved | as C6 | Product-Behavior | — |
| **10** Selection, Clipboard & Rich Paste | **C5** (+**C9** desktop) | content intake; **drag/drop** | intake unified from 25 files | no per-surface intake | Product-Behavior·Real-Boundary | composition direction ⚑ |
| **11** Legacy Global Runtime Overlay Cleanup | **C3** | IA reconstruction; overlay cleanup | deep links preserved | surface reachability registry | Product-Behavior | primary IA ⚑ |
| **12** Advanced Device Preference / Transfer | **C6** | **transfer UI + preferred-device behaviour** | none (new capability) | single transfer path | Product-Behavior·Real-Boundary | participation direction ⚑ |
| **13** External Link Representation / OG | **C5** | governed previews | rendering preserved | one link pipeline | Product-Behavior | — |
| **14** Internal Link Hydration | **C5** | internal link handling in intake | hydration preserved | one intake layer | Product-Behavior | — |
| **15** Rich-Text Composition | **C5** | rich composition + **preserve richness** rule | content rendering preserved | one composition authority | Product-Behavior | composition direction ⚑ |
| **16** Content-Length Expansion | **C5** | validation via context policy | limits preserved | one validation path | Product-Behavior | — |
| **17** Integrated Release-Client Certification | **C11** | **none — gate only** | — | — | **Item 17 / Release Gate** | acceptance ⚑ |

## B. Approved extended backend scope (client obligations)

| Extended scope | Chapter | Client obligation |
|---|---|---|
| Fail-closed authentication | **C1** | auth projection; no local bypass assumptions |
| Canonical person identity projection | **C2** | one identity projection, all consumers |
| **Layered person verification (3 independent layers)** | **C2** | **never flattened to one "Verified"** ⚑ |
| Multi-device authority | **C6** | device eligibility consumed, never re-derived |
| Preferred-first ring + stagger + fallback | **C6** | routing made visible, internals hidden |
| **Windows/MSIX native push (WNS)** | **C9** | native notification presentation |
| Durable media ownership | **C6** | ownership displayed, never mutated locally |
| **D2 transfer handshake** | **C6** | offer/accept/relinquish/failed UI |
| Account retention / disposition | **C2** | lifecycle states expressible |
| **Institution Room (D5)** | **C8** | full client rebuild against canonical contracts |
| **E_OFFICIAL designation** | **C5** | publish-flow designation only |
| **E institutional approval floor** | **C5** | consequence legible before commitment |
| §C adjudication outcomes | across | contracts consumed as frozen |
| Structural enforcement precedent | **all** | FD-13 gates per chapter |
| Migration-safety governance | **n/a (backend)** | referenced only |

## C. Frozen decisions FD-1 … FD-13

| Decision | Chapter(s) |
|---|---|
| **FD-1** Attention Hub + actionable attention | C4 |
| **FD-2** Obligation badge | C4 |
| **FD-3** Realtime product semantics | C6, C7, C8, C10 |
| **FD-4** Realtime presentation convergence | C6 |
| **FD-5** Live as a mode of Thread/Space | **C10** |
| **FD-6** Canonical composition system | C5 |
| **FD-7** Upload on selection | C5 |
| **FD-8** Pre-publication designation only | C5 |
| **FD-9** Contextual Acting Authority | C1, C3 |
| **FD-10** Canonical semantic vocabulary | C0, and every chapter's language checkpoint |
| **FD-11** Canonical identity presentation | C2 |
| **FD-12** Proven-dead retirement + surface reachability | C3 (registry), C4 (`conversations_screen`), C2/C7/C9 (candidates) |
| **FD-13** Enforcement ships with its authority | **every chapter** |

## D. Five named cross-product freezes

| Freeze | Chapter(s) |
|---|---|
| **Capability-Adaptive Experience** | every chapter (stated per chapter) |
| **Task/Domain-Oriented Adaptive Navigation + Canonical Product Language Authority** | C3 (navigation) · C0 (language) |
| **Threads / Spaces Product Model** | C7 (+C10 Live dependency) |
| **Content Intake & Resolution Authority** | C5 (+C9 drag/drop) |
| **Human Temporal Presentation Authority** | C0 (+C4 ordering) |

## E. Demolition candidates

| Candidate | Chapter |
|---|---|
| DR1 — attention/inbox (8 surfaces) | **C4** |
| DR2 — institution live rooms | **C8** |
| DR3 — 6 composers + 11 upload pipelines | **C5** |
| DR4 — mirrored routes, module navigation, CTA drift | **C3** (+C0 language) |
| DR5 — public/member profile (3 implementations) | **C2** |
| `conversations_screen.dart` — proven dead | **C4** |

## F. Low-reference surfaces (FD-12 §4 — contextual disposition)

| Surface | Chapter |
|---|---|
| `InstitutionCorrespondenceScreen` | **C7** |
| `PresenceScreen` | **C2** |
| `LoginScreen` | **C3** (auth/navigation review) |
| `SupportScreen` | **OWNERSHIP UNDETERMINED → PRODUCT DISPOSITION CHECKPOINT** — **not assigned to C9**. Cross-Platform is a *platform* concern; support/monetization is a *product-domain* concern. Determine from actual product purpose whether to PRESERVE / RELOCATE / RECONSTRUCT / MERGE / RETIRE. Until then: **do not delete, do not modernise in isolation, do not force into C9, do not treat low references as proof of death.** Explicitly tracked — **not backlog**. |

## G. Structural discoveries

| Discovery | Chapter |
|---|---|
| `AuraLoadingState` 63 vs raw spinner 83 | C0 |
| 68 files using `SizedBox.shrink()` as empty state | C0 |
| `relative_time` 9 consumers vs 52 hand-rolled | C0 |
| `createdAt` 295× vs `receivedAt` 0× | C0 |
| Shadow governance — 29 role checks + 20 `canX` | C1 |
| 40 mirrored institution routes · 27 redirects | C3 |
| 8 attention surfaces; 1 unreachable | C4 |
| 6 composers · 11 upload pipelines · 25 paste sites | C5 |
| **Drag-and-drop in 0 files** | **C5 + C9** |
| 3 live-room implementations; 5 shared widgets used 0× by Meetings | C6 |
| 3 thread screens · 4 institution messaging entries | C7 |
| Institution live rooms consuming untyped JSON | C8 |
| `PUBLIC_STAGE` declared but unconsumed | **C10** |
