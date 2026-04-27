# Aura Compose — Final Responsive Polish

**Branch:** main  
**Date:** 2026-04-27  
**Files changed:** `lib/features/posts/presentation/compose_screen.dart`

---

## Priority A — Mobile fixes

### 1. Responsive header (`_buildPageTopBar`)
**Problem:** `AuraGradientHeader` uses a fixed `Row(leading + Expanded(title) + trailing)`. On 320-430 px screens the trailing Wrap (status chip + Review + Back buttons ≈ 230 px) consumed nearly all available width, leaving the `Expanded` title column ≤ 50 px — causing severe overflow or multi-line wrapping of the 28 px headline.

**Fix:** `_buildPageTopBar` now uses `LayoutBuilder`. At `maxWidth < 560`:
- `Column` layout: leading icon + title + Back button on the first `Row`, subtitle full-width below, Review button right-aligned on a third row.
- The gradient decoration is reproduced inline using `AuraGradients.header` + `AuraShadows.panel` (imported from `aura_design_system.dart`).
- Status chip removed from the narrow header — it is already shown in the editor status row and the desktop footer.

Above 560 px the original `AuraGradientHeader` with the full trailing is unchanged.

**Widths tested:** 320, 375, 390, 430 px — single-column, no overflow.

### 2. Remove duplicate translation card in narrow layout
**Problem:** `_buildMainCard` (narrow branch) contained an explicit `if (showTranslation)` block that re-rendered `_buildTranslationCard()` even though `belowEditorItems` already included it. On mobile with an active translation preview the card appeared twice.

**Fix:** Removed the redundant `if (showTranslation)` block from the narrow `Column`. `belowEditorItems` remains the sole source of the translation card for both wide and narrow layouts.

### 3. Responsive footer (`_buildBottomBar`)
**Problem:** The footer `Row` placed Discard + Save-draft + Publish side-by-side. On a 320 px screen with 32 px horizontal padding the three buttons totalled ≈ 310 px (plus the status `Expanded` text) — causing a render overflow.

**Fix:** `_buildBottomBar` now uses `LayoutBuilder`. At `maxWidth < 520`:
- **Row 1** (right-aligned): Discard, Save draft — ghost buttons.
- **Row 2** (right-aligned): Publish post — primary button at natural width.

Above 520 px the original wide Row with the status-text Expanded is unchanged.

**Safe area:** `bottomPad = MediaQuery.of(context).padding.bottom` already applied to the bottom padding — covers browser chrome and iOS home-bar on all breakpoints.

---

## Priority B — Desktop refinements

### 4. Replace composer hint text
`'What should this record carry?'` → `'Write for the record — your words, your voice.'`

Human-first phrasing that reinforces the publishing-for-the-record concept without the obtuse question format.

### 5. Lighter right rail status card
Removed `border: Border.all(color: AuraSurface.divider)` from the Draft/Response status container in `_buildSecondaryRail`. The `AuraSurface.elevated` fill already distinguishes the card from the page background; the border was redundant and added visual noise at desktop widths.

---

## What was not changed
- Routes, providers, repositories, auth logic — untouched.
- All features preserved: Save draft, Publish, Review, Translation, Attachments, Visibility, TikTok/LinkedIn integrations.
- Desktop layout unchanged above breakpoints (1080 px wide check, 560 px header check, 520 px footer check).
- `flutter analyze`: 0 issues.
- `flutter test`: all passed.
- `flutter build web`: succeeded.
