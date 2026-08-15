# FD-7 — ATTACHMENT SEND MODEL: UPLOAD ON SELECTION

# STATUS: FROZEN — FOUNDER APPROVED 2026-08-15
# SELECTED: OPTION A — UPLOAD ON SELECTION

---

## 1. Attachment send model

Upload begins when the person **selects, pastes, or drops** supported content.

```
SELECT / PASTE / DROP → VALIDATE → PREVIEW → UPLOAD → PROGRESS → READY → SEND / PUBLISH
```

**Send/Publish remains a separate deliberate communication/publication act.**

> **UPLOADING AN ATTACHMENT NEVER MEANS THE MESSAGE / POST / PUBLICATION HAS BEEN SENT OR PUBLISHED.**

## 2. Draft ownership

An uploaded-but-uncommitted attachment belongs to the **composition/draft state** — not to a message, post, publication or other final communication object.

| Event | Behaviour |
|---|---|
| Draft saved | attachment remains associated with the draft |
| Draft reopened | attachment remains available/prepared |
| Send/Publish succeeds | attachment reference becomes associated with the committed communication/publication **according to the owning domain** |

## 3. Explicit discard → deterministic immediate release

When the person **explicitly discards** the draft/composition, uploaded attachments are **released immediately**, provided they have no other legitimate reference.

> **Do not deliberately leave explicitly discarded attachments waiting for the orphan-cleanup window.**

## 4. Uncontrolled abandonment → cleanup safety net

For application termination · crash · lost connectivity · abandoned composition · interrupted lifecycle · any case where explicit discard does not occur, the **existing backend orphan-media cleanup** is the safety net.

> **EXPLICIT USER DISCARD → DETERMINISTIC IMMEDIATE RELEASE.**
> **UNCONTROLLED ABANDONMENT → EVENTUAL BACKEND CLEANUP.**

## 5. Composition readiness *(frozen invariant)*

> **ATTACHMENT READINESS IS PART OF COMPOSITION READINESS.**
> **ATTACHMENT UPLOAD IS NOT COMMUNICATION COMMITMENT.**

The user must **not** be allowed to believe a communication is ready for commitment while a required attachment is unresolved, failed or incomplete.

> **Do not silently introduce queued-send semantics.** If queued send while uploads remain pending is later considered desirable, it must be brought forward as a **separate product decision**.

## 6. User-facing state

Do not expose backend/developer lifecycle vocabulary unnecessarily. Ordinary experience:

```
attachment selected → progress → ready
```

or, where necessary:

```
failed → retry / remove
```

> **Do not make users reason about internal states** such as media-created, reference-pending, or upload-record status.

*(Consistent with the frozen Human Temporal Presentation and Product Language principles: internal vocabulary does not become product vocabulary.)*

## 7. No hybrid size/type model

> **Do not introduce different invisible upload timing according to file size or type.**

Context policy may legitimately govern allowed type · size · count · eligibility — but the **canonical attachment lifecycle remains coherent**. Option C is explicitly rejected: two invisible behaviours would leave users unable to model why one attachment behaved differently.

## 8. Orphan window review *(carry-forward)*

During reconstruction, review existing backend orphan-cleanup windows against the eventual canonical **draft lifetime**.

> **Do NOT change backend cleanup policy as part of this decision.** If the current windows conflict with the reconstructed draft model, **bring the conflict forward for adjudication rather than silently changing it.**

**Status: OPEN carry-forward item.** The backend already runs `MediaCleanupService` with stale-upload, orphan-age and deleted-retention windows, distinguishing referenced from unreferenced media — those windows were chosen without a client draft model.

---

## 9. Relationship to FD-6

FD-6 froze that **attachment lifecycle is distinct from communication/publication lifecycle** and that uploading never implies commitment. **FD-7 freezes when the upload happens** and what owns it until commitment. Together they close the attachment lifecycle question, apart from the carry-forward in §8.

## 10. Frozen doctrine

> **UPLOAD BEGINS ON SELECT / PASTE / DROP.**
> **SEND/PUBLISH REMAINS A SEPARATE DELIBERATE ACT.**
> **UPLOADED ≠ SENT / PUBLISHED.**
> **UNCOMMITTED ATTACHMENTS BELONG TO THE DRAFT, NOT TO A COMMUNICATION OBJECT.**
> **EXPLICIT DISCARD → IMMEDIATE RELEASE. UNCONTROLLED ABANDONMENT → CLEANUP SAFETY NET.**
> **ATTACHMENT READINESS IS PART OF COMPOSITION READINESS.**
> **NO SILENT QUEUED-SEND SEMANTICS.**
> **NO HYBRID SIZE/TYPE UPLOAD TIMING.**

## 11. Anti-drift guard

| ❌ Prohibited reading | Why it violates FD-7 |
|---|---|
| "Upload at send so nothing is orphaned" | §1 — option B was rejected |
| "Large files upload early, small ones at send" | §7 — option C explicitly rejected |
| "Upload finished, so the message is sent" | §1 (and FD-6) |
| "Attach the uploaded media to the message record before commit" | §2 — it belongs to the draft |
| "Discarded attachments can wait for cleanup" | §3 — explicit discard releases immediately |
| "Let send queue while uploads finish in the background" | §5 — no silent queued-send; separate decision required |
| "Allow send with a failed attachment; it will retry" | §5 |
| "Show 'reference-pending' so the user understands" | §6 |
| "Adjust the orphan windows to fit drafts" | §8 — bring the conflict forward, do not change policy here |
