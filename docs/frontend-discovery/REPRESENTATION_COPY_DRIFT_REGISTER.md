# Representation / Copy Drift Register

**No Representation content was edited.** Every proposed correction requires founder/reviewer adjudication first.

> ✅ **CANONICAL IDENTITY PRESENTATION — FROZEN 2026-08-15 (FD-11)** settles the *substance* behind the highest-severity rows below, while leaving copy open:
> - **"Verified"** must **not** be flattened to a boolean and backend enums must **not** leak — the three verification layers remain independently expressible. *(Exact presentation still open.)*
> - **Person / Institution / Membership / Acting Context / Presence** are frozen as **distinct** concepts; presence is a contextual projection, not identity.
> - Release Client copy must **not** independently redefine Person, Institution, Membership, Acting Context, verification or presence semantics.
> - **Any Representation conflict found during later implementation must be brought forward, never silently reconciled.**
>
> ✅ **FD-10 RESOLVED / FROZEN 2026-08-15.** Correspondence survives as a **distinct governed communication form** (its architecture is **not** protected); **Post** is canonical and **Works** may survive only as a curated projection; **Presence** survives as the domain concept (not renamed to Availability); **Follow ≠ Connect**, with Connect exposed only when the reciprocal capability exists; **verification is never flattened to one label**; `RETRY` is canonical; Cancel/Dismiss/Close/Discard are four distinct families. See `FD10_TERMINOLOGY_FROZEN.md`.
>
> Historical note: this register previously recorded FD-10 as OPEN. See `CANONICAL_IDENTITY_PRESENTATION_FROZEN.md`.

> ✅ **CANONICAL PRODUCT LANGUAGE AUTHORITY — FROZEN 2026-08-15** governs how this register is eventually closed:
> - The Release Client must **not** independently invent canonical language where Representation holds conflicting terminology or presentation doctrine.
> - During later language reconstruction: **inspect Representation → where genuine drift exists, bring it forward, resolve canonical meaning, then align repositories.**
> - **Do not silently choose one repository's terminology over the other.**
> - Rows whose drift reflects **duplicated architecture** cannot be closed by renaming — the screens must converge first.
>
> See `NAVIGATION_IA_PRODUCT_LANGUAGE_FROZEN.md`.

Method: 3,733 user-visible string literals extracted from `lib/`, compared against backend concept names and route/architecture vocabulary.

| Frontend term (user-visible) | Architecture / route term | Backend concept | Proposed product term | Classification | Founder decision |
|---|---|---|---|---|---|
| *(absent)* | **Correspondence** (`/me/correspondence/*`, feature dir) | correspondence orchestrator, thread | Conversation (user) / Correspondence (governance) | **BOTH DRIFTED** — architecture speaks a word the product never says | **Yes** |
| Conversation, Space | correspondence, spaces | thread, space | Conversation, Space | LEGITIMATE CONTEXTUAL DIFFERENCE if documented | Yes |
| *(absent)* | **Presence** (7 symbols) | device presence, availability | Availability (state) / Profile (page) | **FRONTEND WRONG** — one word, six meanings | **Yes** |
| Profile | `me/`, `profile/`, `institutions/profile/` | user, institution | Profile | FRONTEND WRONG — 3 implementations | No |
| Member (21) | member | `InstitutionMember` | Member | — | — |
| *(absent)* | participant | `InstitutionRoomParticipant`, `RealtimeSessionParticipant` | Participant | **FRONTEND WRONG** — backend makes member≠participant structural; product never says "participant" | **Yes** |
| Live (15) | realtime, live-rooms | `RealtimeSession` | *(pending live decision)* | FOUNDER DECISION | **Yes** |
| Meeting | meetings | `Meeting` | Meeting | PRESERVE | No |
| Room | live-rooms | `InstitutionRoom` | Room | REPRESENTATION CHECK NEEDED | Yes |
| Try again (29) / Retry (22) | — | — | pick one | FRONTEND WRONG | No |
| Cancel (21) / Dismiss (6) / Close (5) / Discard (3) | — | — | define the set | FRONTEND WRONG | No |
| Post (4) / Work (4) | posts | `Post` | Post | FRONTEND WRONG — noun/verb collision | Yes |
| Follow (12) | follow, followers/following | follow/relationship | Follow | — | — |
| Verified (4) | verification | **3 independent layers**: IDENTITY / INSTITUTION_AFFILIATION / ROLE_OR_CREDENTIAL | must not be one tick | **FRONTEND WRONG** — collapses a deliberately layered backend truth | **Yes** |
| *(absent)* | — | `E_OFFICIAL` official designation + institutional approval | *(new)* | **MISSING** — frozen backend concept with no product language | **Yes** |
| *(absent)* | — | device transfer, preferred-device ring | *(new)* | **MISSING** | Yes |

## Highest-severity entries

1. **"Verified" collapses three independent verification layers.** The backend deliberately keeps IDENTITY, INSTITUTION_AFFILIATION and ROLE_OR_CREDENTIAL independent and never collapses them. The client shows a single `'Verified'` label. This is not cosmetic — it can overstate what has actually been verified about a person or institution.

2. **"Correspondence" and "Presence" are architecture-only words.** Zero user-visible occurrences each. Engineers and the product speak different languages, and Representation adds a third.

3. **No product language exists for official publication.** The frozen E_OFFICIAL designation and institutional-approval floor are governance-visible concepts with no client vocabulary at all.

## Rule proposed for adjudication

A term is **canonical** only if the same word is used by backend concept, frontend label and Representation — **or** a deliberate two-layer split is documented (governance word vs product word). Anything else is drift by default.

**Nothing in Representation should be changed until the founder rules on the rows marked "Yes".**
