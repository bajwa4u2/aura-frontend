# Decisions — aura_final

Last updated: 2026-07-31 UTC (Communication Integrity System, Milestone 1 — Institution Announcement Integration)

Founder-approved decisions governing this repository (recorded retroactively at continuity establishment, 2026-07-21).

## 2026-07-31: Orphaned Aura Editor sheet — retired (superseded, not abandoned)

`compose_screen.dart`'s `_openAuraEditorSheet`/`_runAuraEditor` (plus the sheet-only helpers `_spellingItems`, `_grammarItems`, `_legacySignals`, `_legacyRefinement`, `_listOfString`, and the `_auditBusy`/`_lastAuditAt`/`_auditResult`/`_auditError` state) have been deleted, along with the now-unused `ai/providers.dart` import. This was the March 2026 integrity-gate regression's dead remnant on the personal-post composer — discovered during the Communication Integrity System's editor-reconnection discovery to be completely unreachable (two references in the whole codebase: its own definition and its own recursive "run again" self-call; nothing external ever opened it).

**Sequenced correctly, not removed first:** per founder-approved retirement order, this was deleted only after the real replacement — Communication Integrity Review on institution announcements (`institution_announcement_composer.dart`, backed by `aura-backend`'s runtime-certified CIS pipeline) — was built and verified end to end (backend: 67 suites/799 unit tests + 21 real HTTP scenarios against a disposable database; client: full `flutter analyze` and `flutter test` clean). Confirmed zero routes or tests depended on the removed code before deleting it.

**This is a real capability moving to its correct, doctrine-governed home — not a feature abandoned.** The old sheet gated the wrong surface (personal posts, never institutional) against the wrong contract (legacy `/ai/editor-review` + `/ai/claim-audit`, not the certified Provider→Assessment→Policy→Publication pipeline) and conflated Writing Assistance with integrity review in one panel — exactly the confusion the new design (`lib/features/institutions/announcements/integrity/`) is built to keep separate. `claim_audit_screen.dart` (the standalone admin paste-box tool) is untouched — it's a separate, still-live tool, not part of this retirement.

Full record: `aura-backend/capability/COMMUNICATION_INTEGRITY_SYSTEM_ANNOUNCEMENT_INTEGRATION_PLAN.md`.

## 2026-07-21: AXR-1 closeout rulings

Decision, founder-issued to resolve the three items AXR-1's first delivery left open:

1. **No Meetings or Mentions nav destinations solely for badges.** Meeting notifications remain Activity-only until Profile → Participation → Meeting History exists. Mention notifications must deep-link to their referenced content instead of getting a dedicated tab — confirmed already true (see below), not a new build.
2. **Topic-seeded search is accepted as AXR-1's final behavior.** A dedicated topic-scoped view is future enhancement only, not required for this milestone.
3. **The institution post composer is in scope.** It is a real, routed, active production surface — inspected and confirmed, not assumed. It gets governed tagging like the other three composers. Meeting notes do not, because no meeting-notes composer exists yet; that's a future integration requirement, not a deferred build.

Verification for (1): `MENTION` notifications already carry `postId` (the reply/post containing the mention — backend `posts.service.ts`'s mention fanout: `postId: created.id`), and `notifications_screen.dart::_routeFor` already resolves `postId` → `/posts/:id`, a route that serves both posts and replies. No code change was needed — the deep-link requirement was already satisfied by existing infrastructure; verifying that first is what avoided building a redundant Mentions tab.

Reason: keeps the badge/nav surface exactly as large as real destinations justify (Single Intent Principle spirit — don't add a nav item whose only job is carrying a number), while confirming attention still reaches the user through Activity + the correct deep link.

Repository impact: `institution_post_composer_screen.dart` wired with `GovernedTagAutocomplete` (commit `a19547f`). No routing changes — the mention deep-link was verified, not built.

## 2026-07-21: Governed tagging is platform infrastructure, not a Post feature

Decision: `@member` / `@institution` / `#topic` tagging lives in `lib/core/tagging/` and is entity-agnostic (`TagKind` is an open enum). Any text-composing surface adopts it by wrapping its existing `TextEditingController`/`FocusNode` in `GovernedTagAutocomplete` — not by reimplementing autocomplete per surface.

Reason: the brief was explicit that tagging must generalize across posts, comments, replies, messages, announcements, meeting notes, Studio-generated content, and future editors without redesign per surface.

Alternatives considered: a Post-scoped mention widget extended ad hoc per surface — rejected; would recreate the exact per-surface drift the brief was trying to eliminate.

Repository impact: `lib/core/tagging/`; wired into post compose, thread messages, institution announcements (commit `39e3964`).

## 2026-07-21: Module attention derives from one source, never a parallel count

Decision: per-module unread badges (`module_attention.dart`) are a pure projection over the same notification rows the global Activity bell already polls. No module maintains its own unread count.

Reason: a second unread source is a second thing that can drift from the first — the exact "fragmented attention" defect the brief named as the problem to fix.

Repository impact: `moduleAttentionProvider`; wired into member shell side rail + bottom nav.

## 2026-07-21: Identity rendering precedence — canonical widget, not per-surface fallback logic

Decision: photo → institution logo → approved avatar → initials → placeholder, implemented once in `AuraAvatar` (`lib/core/ui/aura_platform_components.dart`). Surfaces rendering identity must delegate to it, not reimplement a `CircleAvatar`/initials fallback.

Reason: five surfaces had silently drifted from the canonical widget over time, each with its own incomplete fallback that skipped the image even when one existed. See `../aura-backend/audit/working-directory/DECISIONS.md` for the paired server-side decision (payloads must include the image field).

Repository impact: `admin_institution_members_screen.dart`, `new_conversation_screen.dart`, `space_screen.dart::_IdentityAvatar`, `meeting_detail_screen.dart`, `search_screen.dart::_InstitutionTile` — all five now delegate to `AuraAvatar` or an equivalent logo-with-fallback path (commit `39e3964`).

## 2026-07-11: No identity forms at meeting doors

The pre-join guest name/email form is deleted; identity renders from resolver outcomes only ("Invited as <name>", OTP verification, or login). Do not reintroduce.

## 2026-07-11: Member booking identity is read-only

Authenticated members see a read-only "Booking as" card; name/email fields render only for anonymous visitors.

## 2026-07-10/11: Live room internals are frozen

Meeting workspace surfaces migrated to AuraSurface tokens, but the live room's internals were explicitly left untouched and stay frozen.

## 2026-07-13: ROS Phase II verdict

VERIFIED WITH RESIDUAL FOUNDER EDITORIAL ITEMS. Audit and deployment were two separately authorized founder missions; follow the two-stage pattern.

## Frozen classification

Aura's product architecture was frozen 2026-07-12 (`AURA_REPRESENTATION_MODULE_INVENTORY.md`, `AURA_PLATFORM_ARCHITECTURE.md` — in `representation/inventory/`). When a later audit runs, Phase 1 is "confirm and cite," never "re-derive and re-freeze."
## 2026-07-21: Post editing reuses canonical composers

Decision: member and institution post editing must use deterministic edit modes in the canonical composer surfaces, not separate edit architectures or create-mode redirects.

Reason: public/member edit capability disappeared because the affordance was hidden and backend update rejected published posts. Institution edit routed into an unhydrated create-mode composer, risking duplicate/blank mutations. Edit mode must hydrate the existing row, preserve metadata, and save through update endpoints.

Repository impact: `ComposeScreen` accepts `editPostId` and saves through `PUT /posts/:id`; `InstitutionPostComposerScreen` loads `postId` through the single-post endpoint and saves through `PATCH /institutions/:institutionId/posts/:postId`.

## 2026-07-21: Topic selection is canonical state, not raw text

Decision: publishing/editing top-level posts requires selected `AuraTopic` state. Raw text that starts with `#` is tagging/autocomplete text only and does not satisfy topic selection.

Reason: backend routing and doctrine depend on canonical topic enum values. Text tokens can be incomplete, decorative, or stale.

## 2026-07-21: Mention selection is text plus canonical reference

Decision: governed mention autocomplete replaces the active text token and reports the selected canonical entity reference to the composer. The text remains the renderable source; the `mentions` payload carries selected member/institution ids for backend fanout.

Reason: plain `@handle` text is necessary for readable posts and normal editing, but selected autocomplete results must not lose their canonical identity before publish/update.
