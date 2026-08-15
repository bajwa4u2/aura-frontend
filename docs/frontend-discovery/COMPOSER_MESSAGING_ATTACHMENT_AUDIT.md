# Composer / Messaging / Attachment Audit

> ✅ **FD-5 (FROZEN):** Live audience voice is **lightweight reactions + governed questions only**. **Continuing discussion remains owned by the Thread/Space conversation** — there must be no second Live comments system competing with Thread and Space conversation. See `FD5_LIVE_THREAD_SPACE_FROZEN.md`.

> ✅ **FD-10 (FROZEN)** bars backend class names (`E_OFFICIAL`) and governance internals from product language, and requires human workflow language for designation, approval-pending and approval-invalidated-by-edit states. See `FD10_TERMINOLOGY_FROZEN.md`.

> ✅ **CONTENT INTAKE & RESOLUTION AUTHORITY — FROZEN 2026-08-15 (cross-product).** Founder-surfaced; **this audit did not identify it**. Paste/drop/selection must resolve what the person actually provided — **preserve richness, do not invent richness**; supported pasted images/files become attachments naturally; links resolve to governed previews; unsupported content fails **visibly and recoverably**. Not another composer — an input/resolution layer serving the canonical Composition System.
>
> **New measured discovery:** Clipboard in **25 files**, paste in **25 files**, **drag-and-drop in 0 files** — despite Windows/MSIX being a governed release target. See `CONTENT_INTAKE_RESOLUTION_AUTHORITY_FROZEN.md`.
>
> ✅ **THREADS/SPACES — FROZEN 2026-08-15:** Threads and Spaces **consume** the canonical Composition System; **no independent Thread/Space composer architectures**. See `THREADS_SPACES_PRODUCT_MODEL_FROZEN.md`.

> ✅ **RESOLVED — CANONICAL COMPOSITION SYSTEM + CONTEXT-GOVERNED EXPERIENCE, FROZEN 2026-08-15** (register **FD-6**; the founder instruction labelled it "FD-2", which in the register is a different, still-open decision).
>
> One canonical composition system + shared attachment/media lifecycle + context-governed semantics + capability-adaptive presentation. **Composition ≠ representation ≠ delivery/publication.** Owning domains keep their communication semantics. Default composer exposes only the immediate act; everything else is progressive disclosure. **6 composers + 11 upload pipelines = demolish/converge candidate — planning permission only.** See `CANONICAL_COMPOSITION_SYSTEM_FROZEN.md` and `CAPABILITY_ADAPTIVE_EXPERIENCE_FROZEN.md`.

## FINDING C1 — Six composers, capability distributed at random

**Evidence.** Measured presence of each capability per composer:

| Composer | Lines | mention | hashtag | link preview | attach | draft | rich text | paste | audience | upload state |
|---|---|---|---|---|---|---|---|---|---|---|
| `compose_screen` (personal post) | 3,385 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| `thread_composer` (DM/thread/space) | 2,209 | ✅ | ❌ | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ | ✅ |
| `institution_post_composer` | 2,068 | ✅ | ❌ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ❌ |
| `announcement_editor` | 1,490 | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| `institution_announcement_composer` | 996 | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| `public_composer` | 133 | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ✅ | ❌ |

**The distribution has no product logic.** Hashtags exist in exactly one composer. Upload progress state exists in exactly one — the other four that accept attachments have none. Rich text exists in three, and not in the two highest-volume ones.

**PRODUCT CONSEQUENCE.** A person who learns to compose in one place must relearn everywhere. Attaching a file to an announcement gives no progress feedback; attaching in a thread does. Publishing an institution post cannot use hashtags; a personal post can — with no stated reason.

**ROOT CAUSE.** Textbook patch accumulation: each composer was built for its surface, then capabilities were added to whichever composer the requesting feature touched.

**CLASSIFICATION.** DEMOLISH + REBUILD as one composition authority with context policy.

**OPTIONS.**
- **A. One Composition Authority (content model, attachment pipeline, mentions, link intelligence, draft, validation, send-state) + per-surface presentation and policy.**
- B. Two engines: short-form (message) and long-form (publication).
- C. Keep separate composers, extract only the attachment pipeline.

**RECOMMENDATION.** A, with the explicit separation the task names: **composition authority ≠ surface presentation**. A DM composer should still look like a message bar and an announcement editor like an editor — they should not each own a different definition of "attachment" or "mention". B is a reasonable fallback if adjudication decides publication and messaging are genuinely different products.

**MIGRATION CONSEQUENCE.** Drafts must survive. Existing attachment references and post/announcement content models must render unchanged.

**FOUNDER DECISION.** ✅ **RESOLVED — see the frozen decision at the top of this document.** The approved direction is A, defined more fully as *Canonical Composition System + Context-Governed Experience*.

---

## FINDING C2 — Eleven independent upload implementations

**Evidence.** Files independently invoking `FilePicker` / `ImagePicker` / `MultipartFile` / `pickImage`:

`compose_screen` · `thread_composer` · `institution_post_composer_screen` · `announcement_editor_screen` · `institution_announcement_composer` · `institution_edit_profile_screen` · `me/edit_profile_screen` · `meeting_live_room_screen` · `meeting_assets_section` · `contact_import_screen` · `core/media/media_save_io`

**PRODUCT CONSEQUENCE.** Size limits, MIME handling, cancel/retry, orphan cleanup and error copy are decided eleven times. The backend has one canonical MIME policy (already corrected in a prior chapter); the client has eleven interpretations of it.

**CLASSIFICATION.** DEMOLISH + REBUILD as a single Attachment Pipeline authority.

**Pipeline stages that must be owned in one place:** select → preview → validate → upload → progress → cancel → retry → send/publish → display → open/download → remove → error.

**Known unresolved behaviours to specify during rebuild:** upload-before-send vs send-transaction; composer abandonment (orphaned uploads); drag/drop and clipboard attachment on desktop/MSIX; local path handling across mobile/web/MSIX.

**FOUNDER DECISION.** ✅ **FULLY RESOLVED.** Consolidation frozen by FD-6; **FD-7 frozen 2026-08-15 as UPLOAD ON SELECTION**.

Upload begins on select/paste/drop; **Send/Publish stays a separate deliberate act**; uncommitted attachments belong to the **draft**; **explicit discard releases immediately**, uncontrolled abandonment falls to the existing backend orphan cleanup. **Attachment readiness is part of composition readiness** — no silent queued-send. **No hybrid size/type timing.** Ordinary UI shows `selected → progress → ready` / `failed → retry/remove`, never internal lifecycle vocabulary.

This closes the finding that **upload progress state exists in only 1 of 6 composers** — progress, cancel and retry become meaningful before commitment. **Carry-forward:** orphan-window vs draft-lifetime review. See `FD7_ATTACHMENT_SEND_MODEL_FROZEN.md`.

---

## FINDING C3 — Institution voice is not a composer capability

**Evidence.** `institutionSpeechMode` / institutional-voice selection appears in only `compose_screen` and `substrate_chip`. The institution post composer and announcement composers do not carry a voice concept — voice is implied by which composer you opened.

**PRODUCT CONSEQUENCE.** "Who is speaking" is expressed by navigation rather than by an explicit, visible choice. With the frozen backend now distinguishing personal / institution-voice / **officially designated** publication, the client has no way to express the third at all.

**CLASSIFICATION.** SEPARATE — voice/authority selection must become an explicit composition input, not a consequence of route. **Now governed by the frozen composition decision (§2, representation) and FD-9:** acting context supplies representation; no composer implements its own post-as-institution selector.

**BACKEND DEPENDENCY.** E_OFFICIAL designation + institutional approval floor are frozen and unrepresented in the client.

**FOUNDER DECISION.** **RESOLVED — FD-8 PRE-PUBLICATION DESIGNATION ONLY, FROZEN 2026-08-15.**

Designation is expressed **in the publish flow, not in writing** — it belongs to the delivery/publication layer per FD-6. **Post-publication elevation is not permitted** (it would bypass the institutional approval floor). **Withdrawal is object-local and remains legitimate.** **Any content change after approval invalidates the approval.** The consequence — *official designation requires institutional approval before publication* — must be legible **before** commitment, never surfaced as an error at Publish. See `FD8_OFFICIAL_DESIGNATION_MOMENT_FROZEN.md`.
