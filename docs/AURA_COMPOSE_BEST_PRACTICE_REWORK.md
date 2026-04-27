# Aura Compose Screen — Creator UX Best Practices Rework

Zero behavior change. All state, payloads, API calls, providers, routes, and repositories are unchanged. Only the presentation layout was modified.

---

## Principles applied

1. **Writing area dominates the viewport** — editor card is the first and largest element; verbose section headers removed.
2. **Progressive disclosure** — translation and composition suggestions only surface when actively triggered.
3. **Sticky footer stays minimal** — bottom bar keeps Save draft + Publish + Discard; no competing content.
4. **Desktop layout keeps editor dominant** — secondary rail shrunk to 260px (was 352px), no summary card.
5. **Audience and media close to the editor** — audience chips and attachment controls now inline inside the editor card.
6. **Below-fold placement for advanced tools** — translation card, distribution toggles, and publishing context all appear after the editor in scroll order.
7. **Publish confidence** — audience selection is always visible with help text, status line in header and bottom bar.

---

## What changed

### `lib/features/posts/presentation/compose_screen.dart`

| Area | Before | After |
|---|---|---|
| `_buildMainCard()` | Editor column + 352px summary column | Editor column (flex:8) + 260px secondary rail; narrow: editor + below-fold tools |
| `_buildEditorSection()` | Editor only (no audience, no media) | Editor + inline audience chips + visibility help + attachments block |
| Secondary rail (wide) | Publish summary card + audience card + distribution card + intent card | Draft status indicator + distribution card + intent card |
| Audience | Separate card in summary column | Inline row inside editor card with compact chips + help text |
| Distribution (wide) | Separate card in summary column | Compact section inside 260px secondary rail |
| Distribution (narrow) | Below summary column | Below fold in main column |
| Translation | Always rendered above suggestions | Only rendered when `_translationBusy`, result present, or error |
| Suggestions | Always rendered inside assist card | Only rendered when `_compositionBusy`, suggestions present, or error |
| Discard button | Standalone `_buildActionRow()` row above main card | Moved into sticky `_buildBottomBar()` alongside Save + Publish |
| Verbose descriptions | Section subtitles on editor/media/assist cards | Removed |
| Attachment helper text | "Images and videos upload through the new Aura media system…" | Removed |

### Removed build methods (unused after rework)

| Method | Reason |
|---|---|
| `_buildActionRow()` | Discard moved to footer; Translate moved to translation card |
| `_buildAssistSection()` | Replaced by conditional inline suggestion/translation cards |
| `_buildMediaSection()` | Media now inline in editor card |
| `_buildPublishSummarySection()` | Replaced by compact status in secondary rail header |
| `_buildAudienceSection()` | Replaced by `_buildInlineAudienceRow()` inside editor card |
| `_buildAudienceBlock()` | Content folded into `_buildInlineAudienceRow()` |

### Added build methods

| Method | Purpose |
|---|---|
| `_buildInlineAudienceRow()` | Compact audience chips + visibility help text inside editor card |
| `_buildSecondaryRail()` | Desktop-only 260px rail: draft status + distribution + intent |

---

## Above-fold content (no scrolling required)

- Header with title, draft status chip, Review button, Back button
- Editor (composer box + character count + error)
- Audience chips + visibility description
- Attachments block (add button + grid)
- Sticky bottom bar: saved status · Discard · Save draft · Publish

## Below-fold content (requires scrolling)

- Composition suggestions card (only when review runs)
- Translation card (only when translation is in progress or result exists)
- Distribution toggles — narrow: below editor column; wide: in secondary rail
- Publishing context card — narrow: below distribution; wide: in secondary rail

---

## Desktop layout (≥ 1080px)

```
┌──────────────────────────────────┬──────────────┐
│  Editor card (flex: 8)           │  260px rail  │
│  ┌────────────────────────────┐  │  Draft status│
│  │ Composer (minLines: 10)    │  │  ──────────  │
│  │ ── Audience ── [chips]     │  │  Distribution│
│  │ ── Attachments ────────    │  │  ──────────  │
│  └────────────────────────────┘  │  Intent      │
│  [Suggestions card — if active]  │              │
│  [Translation card — if active]  │              │
└──────────────────────────────────┴──────────────┘
[Sticky footer: status · Discard · Save draft · Publish]
```

---

## What was NOT changed

- Routes (`go_router` configuration)
- Providers (Riverpod state)
- Repository or domain layer
- API payloads (`_buildComposePayload`, `_publish`, `_saveDraft`, etc.)
- Auth / realtime / integration logic
- All existing state fields and business logic methods
- `compose/compose_models.dart` and `compose/compose_widgets.dart`
