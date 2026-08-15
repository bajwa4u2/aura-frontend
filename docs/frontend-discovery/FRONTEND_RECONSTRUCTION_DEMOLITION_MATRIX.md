# Frontend Reconstruction — Demolition Matrix

> **DEMOLITION ≠ DATA DELETION.** Every row separates **UI/surface demolition** from **data/state migration**. No valid user data is destroyed because a surface is rebuilt.

---

| Existing domain / surface | Classification | Why | What survives | What dies | Replacement authority/surface | Migration risk | Founder checkpoint |
|---|---|---|---|---|---|---|---|
| **Attention / inbox — 8 surfaces** (messages hub, notifications, activity, direct inbox, communications centre, correspondence hub, module attention, conversations) | **DEMOLISH + REBUILD** | six live surfaces answer one question with no rule for which; no authority to refactor toward | read/unread data · invitation state · notification preferences · delivery capability · `module_attention` + `notifications_controller` as seed | six competing hubs · locally cached unread with TTL · aggregated badge meaning several obligations | **C4** — Attention Authority + Hub (Conversations · Activity · Invitations · Actions) | **HIGH** — a wall of false unreads on migration would be a visible regression | ⚑ attention direction before retirement |
| **`conversations_screen.dart`** | **RETIRE** (proven dead) | zero router references; only self-references; 1,033 lines; holds the codebase's only `updatedAt` sort hazard | nothing | entire surface | none — superseded by C4 | **LOW** — unreachable | already approved (FD-12) |
| **6 composers** (compose_screen, thread_composer, institution_post, announcement_editor, institution_announcement, public_composer) | **DEMOLISH + REBUILD / CONVERGE** | capability distributed with no product logic — hashtags 1 of 6, upload progress 1 of 6 | **drafts and draft data** · content rendering · validation behaviour · accessibility behaviour · legitimate context differences | six content models · voice implied by route · per-composer paste handling | **C5** — Composition Authority + per-surface policy | **HIGH** — draft loss would be unacceptable | ⚑ composition direction |
| **11 upload pipelines** | **DEMOLISH + REBUILD** | eleven interpretations of one canonical backend MIME policy; no shared progress/cancel/retry | media rendering · attachment capabilities · backend contracts | eleven mechanics; local lifecycle interpretation | **C5** — Attachment Lifecycle + Content Intake | **MEDIUM** — orphan handling must be deliberate | ⚑ (⚑ orphan-window review) |
| **40 mirrored institution routes** + 27 corrective redirects | **DEMOLISH / CONVERGE** | context encoded as address space; contradicts frozen backend doctrine; every destination built twice | **all existing deep links must resolve** · shells · session continuity · redirects as temporary compatibility | route-carried acting context · literal route strings · module-oriented destinations | **C3** — Navigation/Surface Authority + registry | **HIGH** — external/shared links and notification destinations | ⚑ exact primary destinations |
| **3 profile implementations** (`profile/`, `me/`, `institutions/profile/`) | **DEMOLISH + REBUILD** | same human represented three ways; ~4,100 lines of parallel edit screens; "presence" carries six meanings | canonical identity data · relationships · public content · verification data · privacy controls · follow state · deep links | three architectures · "Member" identity type · institution-as-user · boolean verification · local presence inference | **C2** — Identity/Relationship/Presence/Verification/Action projections | **MEDIUM–HIGH** — privacy controls and verification display are trust-bearing | ⚑ verification labels · ⚑ presence privacy · ⚑ profile direction |
| **`institution_live_rooms_screen`** (1,078 lines) | **DEMOLISH + REBUILD** | imports neither realtime nor meetings; untyped `Map<String,dynamic>`; lists **sessions**, not `InstitutionRoom` | "what is live now" concept · card layout only | raw-map data path · session-as-room concept | **C8** — Institution Room client on canonical D5 contracts | **LOW** — no canonical model to migrate | ⚑ room experience direction |
| **3 `thread_screen` implementations** + 4 institution messaging entries | **MERGE / CONVERGE** | same concept implemented three ways; four entry points to one capability | communication histories · membership · drafts · deep links | duplicated conversation mechanics | **C7** — Thread/Space/Correspondence surfaces | **HIGH** — conversation history continuity | ⚑ Correspondence presentation + convergence verdict |
| **Correspondence architecture** | **CONVERGE (semantics preserved)** | word survives as a distinct governed form; **the architecture is not protected** | Correspondence **semantics** · histories · governance continuity | duplicate messaging mechanics if that is what it proves to be | **C7** — shared infrastructure, distinct semantics | **HIGH** — semantic + architectural change together | ⚑ verdict required |
| **Meetings live room** (3,890 lines, 0 of 5 shared widgets) | **REFACTOR / CONVERGE — presentation only** | duplicated participant/host/admission/consent presentation | **entire Meetings lifecycle** — booking, invitation, attendance, waiting/admission, prep, summary, follow-up | reimplemented participant grid, spotlight, remote tiles | **C6** — shared presentation family, context-supplied semantics | **HIGH** — certified surface | ⚑ **sign-off after each slice** |
| **Raw state patterns** (83 spinners, 68 blank empties) | **REFACTOR + ENFORCE** | shared system exists, adoption never finished | shared components (sound design) | raw spinners; blank-as-empty | **C0** — Product State Presentation | **LOW** | ⚑ product language |
| **Local temporal logic** (52 `.difference()`, 35 `toLocal()`, 22 sorts) | **REFACTOR / CONSOLIDATE — not demolition** | helpers sound; adoption 9 and 3 consumers; semantics collapsed onto `createdAt` | helpers as seed · displayed times | hand-rolled humanization · arbitrary conversion · wrong sort field | **C0** — Temporal Presentation | **MEDIUM** — sort-order changes are user-visible | ⚑ product language |
| **Shadow governance** (29 role checks, 20 `canX`) | **REFACTOR** | client re-derives backend-owned authority | legitimate presentation-state logic | invented authority | **C1** — Capability Projection | **MEDIUM** — some controls may appear/disappear | ⚑ acting-identity visibility |
| **Low-reference surfaces** (`InstitutionCorrespondenceScreen`, `PresenceScreen`, `LoginScreen`, `SupportScreen`) | **CANDIDATES — contextual disposition** | low reference ≠ dead; `LoginScreen` is a known false positive | whatever proves reachable/product-correct | only what is proven dead in context | C7 · C2 · C3 · **`SupportScreen`: OWNERSHIP UNDETERMINED → product disposition checkpoint (NOT C9)** | **MEDIUM** — deleting a reachable surface | disposition recorded per chapter |

---

## Data / state / route migration checklist (applies to every demolition row)

Each chapter must explicitly identify:

1. **Data to preserve** — content, histories, relationships, media
2. **State to map** — read/attention, invitation, participation, draft
3. **Route / deep-link migration** — old inventory → canonical destination → redirect policy → external-link compatibility
4. **Draft migration** where applicable
5. **Read / attention continuity**
6. **Media continuity**
7. **User preferences**
8. **Saved relationships**
9. **Accessibility expectations**

> **Redirects are a transition mechanism, not a resting place.** Corrective redirect chains must be eliminated over time, not preserved indefinitely behind the new IA.
