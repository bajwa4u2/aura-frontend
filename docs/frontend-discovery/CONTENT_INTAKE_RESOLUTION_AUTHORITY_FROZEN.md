# CONTENT INTAKE & RESOLUTION AUTHORITY

# STATUS: FOUNDER DIRECTION FROZEN — 2026-08-15
# CROSS-PRODUCT OBLIGATION

**Founder-surfaced.** This was **not** identified by the original discovery audit — the audit measured composer capability but never tested intake quality. Recorded as a named cross-product obligation adjacent to the canonical Composition System (register **FD-6**). **No new FD number invented.**

---

## Measured evidence (gathered 2026-08-15)

| Signal | Measurement |
|---|---|
| Files touching `Clipboard` | **25** |
| Files with paste handling | **25** |
| Files implementing **drag-and-drop** (`DropTarget` / `onDragDone` / `DragTarget`) | **0** |

> **Drag-and-drop does not exist anywhere in the client** — despite the Windows/MSIX Release Client being a governed release target where drop is an expected input gesture. This is a **new discovery** surfaced while recording this obligation.

Combined with the composer audit (6 composers, 11 upload pipelines, upload progress in only 1 of 6), intake behaviour is decided independently in ~25 places.

---

## 1. Scope

Applies across appropriate composition surfaces: DM · Threads · Spaces · Posts · Correspondence · institutional communication · future composition surfaces. **Not a Thread/Space-specific problem.**

## 2. Governing principle

> **PASTE / DROP / SELECTION SHOULD RESOLVE THE CONTENT THE PERSON ACTUALLY PROVIDED.**

Preserve supported semantics rather than degrading rich input unnecessarily.

```
TYPE / SELECT / PASTE / DROP → DETECT → RESOLVE → PRESERVE SUPPORTED SEMANTICS
  → PREVIEW → VALIDATE → ATTACH / COMPOSE → SEND / PUBLISH
```

## 3. Rich text paste

Where the owning surface supports rich content, pasted formatted text should preserve supported source structure: headings · bold · emphasis · paragraphs · lists · supported inline structure · emoji already present in the source · other legitimate richness.

**Do NOT automatically flatten properly supported pasted content into plain text.**

> **PRESERVE RICHNESS. DO NOT INVENT RICHNESS.**

If ordinary plain text is pasted, do **not** invent headings, bold, icons, emoji or formatting that was never supplied or intended.

## 4. Image / file paste and drop

Where supported by the owning surface and backend media policy: pasted image → image attachment/media · supplied file → file attachment · dropped supported media → resolves predictably through the **canonical attachment lifecycle** (FD-6).

> **Do not require users to rediscover an Upload button when the input gesture itself expresses attachment intent.**

Unsupported content must **fail visibly and recoverably**. **Never silently discard clipboard/drop content.**

## 5. Link resolution

A pasted URL should be capable of resolving into a **governed** content preview where supported: title · source/domain · useful description · image/thumbnail where available · canonical destination.

Preview policy is **not frozen**. Investigate: security · privacy · metadata fetching · stale previews · malformed links · duplicate previews · internal Aura links · preview removal/editing · fallback when resolution fails.

> **The pasted URL must remain understandable even if rich preview resolution fails.**

*(Backend note: SSRF-safe link fetching and internal link hydration already exist as frozen backend capability — the client obligation is to consume it, not to reimplement fetching.)*

## 6. Multi-item / mixed content

Predictable handling of: text + image · text + file · multiple files · multiple images · links mixed with text · clipboard carrying both rich and plain representations.

> **Do not silently choose an arbitrary clipboard representation when doing so loses meaningful supported content.** The experience must stay simple despite richer underlying resolution.

## 7. Relationship to composition

**This is NOT another independent composer.** It is a governed input/resolution layer serving the canonical Composition System:

```
USER INPUT → CONTENT INTAKE & RESOLUTION → CANONICAL COMPOSITION
  → ATTACHMENT/MEDIA LIFECYCLE → OWNING DOMAIN DELIVERY/PUBLICATION
```

Exact technical boundaries to be validated during architecture design.

## 8. State-of-the-art requirement

Later research: rich clipboard handling · paste · drag/drop · image clipboard input · file attachment · rich-text preservation · link unfurling · preview removal/editing · mixed content · mobile share/input patterns · error recovery.

> **Do not copy another product. Extract interaction principles.**

---

## 9. Frozen doctrine

> **PASTE/DROP/SELECTION SHOULD PRESERVE AND RESOLVE SUPPORTED CONTENT NATURALLY.**
> **PRESERVE RICHNESS; DO NOT INVENT RICHNESS.**
> **SUPPORTED PASTED IMAGES/FILES SHOULD BECOME ATTACHMENTS NATURALLY.**
> **LINKS SHOULD RESOLVE TO USEFUL GOVERNED PREVIEWS WHERE SUPPORTED.**
> **UNSUPPORTED CONTENT FAILS VISIBLY AND RECOVERABLY — NEVER SILENTLY.**

## 10. Anti-drift guard

| ❌ Prohibited reading | Why it violates this obligation |
|---|---|
| "Flatten paste to plain text; it is predictable" | §3 |
| "Auto-format plain text into headings/emoji to look modern" | §3 — do not invent richness |
| "Pasted image? Tell them to use Upload" | §4 |
| "Unsupported paste can be ignored" | §4 — must fail visibly and recoverably |
| "Take the first clipboard representation" | §6 |
| "Build a paste handler per composer" | §7, §1 — 25 files already do this |
| "Fetch link metadata in the client" | §5 — consume the governed backend capability |
| "Drag-and-drop is desktop polish, defer it" | Evidence — 0 implementations, and MSIX is a governed release target |
