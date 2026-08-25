# Global Navigation / Return-Path Authority — audit

> **STATUS: SUPERSEDED BY IMPLEMENTATION.** Founder authorized this audit on
> 2026-08-25 and the work is done. The counts below are the BEFORE state and
> are kept as the baseline; the after-state and the architecture as actually
> built are in `2026-08-25-return-path-implementation.md`. 83 defective
> surfaces → 0.

Founder ruling 2026-08-25. Audit, measure, classify, architect, plan. **No
implementation.** Evidence is committed beside this document:
`return_path_census.csv` (175 routes), `return_path_surfaces.csv` (86 non-route
surfaces), `return_path_census.json`. The findings are held by
`test/navigation/return_path_audit_gate_test.dart`.

---

## 0. Two premise corrections

**`navigation_exit_authority.dart` does not exist and never has** — no file, no
git history, no symbol. The RC4 governed redirect/preservation contract the
ruling means lives in **`lib/core/navigation/destination_continuity.dart`**. It
is intact and everything §5 lists is still valid there: `ExitKind.temporaryGate`
vs `terminalDenial`, `validatedReturnTarget`, `gateRedirect`,
`consumeReturnTarget`, loop prevention, the never-return-to gate set.

**The RC6 numbers have moved.** RC6 recorded 182 routes / 53 institution. The
router registers **175 / 59** today. The census is taken from
`router.configuration.routes` — the object the app navigates with — not from a
text scan, because a scan that drifts drops routes silently. It dropped three
before the tooling was corrected.

---

## 1. Population

| | count |
|---|---|
| registered routes | **175** |
| — render a screen | 156 |
| — redirect-only | 19 |
| institution routes | 59 |
| non-route navigable surfaces | **86** (51 dialogs, 29 modal sheets, 3 `MaterialPageRoute`, 2 `Navigator.push`, 1 `OverlayEntry`) |
| **total navigable surfaces** | **242** |
| routes attributed to their screen | 151 / 156 = **96.8%** |

The 5 unattributed are the institution shorthands (`/institution/profile`,
`/edit-profile`, `/domains`, `/dashboard`, `/request-verification`). They build
`Scaffold(body: AuraProductState(loading))` behind a redirect — placeholders,
not surfaces. **Population accounting is therefore 100%:** 151 attributed + 5
placeholders + 19 redirect-only = 175.

---

## 2. Classification — registered routes

| class | count |
|---|---|
| MISSING_RETURN_PATH | **47** |
| PROTECTED_BOUNDARY | 38 (30 Meetings/Live, 8 auth/boot) |
| DEEPLINK_ESCAPE_MISSING | **25** |
| NOT_A_SURFACE | 24 |
| COMPLIANT | **18** |
| ROOT_NO_RETURN_REQUIRED | 12 |
| WRONG_RETURN_SEMANTICS | **6** |
| HARDCODED_PARENT_RETURN | **5** |

**151 audited surfaces · 18 compliant · 83 defective · 50 root-or-protected.**

`HARDCODED_PARENT_RETURN` is a class the evidence forced. It is not in the
ruling's list; it is not "missing" either. Example, verified by hand:
`/institutions/:slug` draws `Icons.arrow_back_rounded` beside the word
"Institutions" and calls `context.go('/institutions')`. It reads as Back, it is
right only if you arrived from the directory, and because it is `go` it
*replaces* the stack rather than unwinding it. `/white-paper` does the same to
`/mission`.

### Defects by product area

| area | defects |
|---|---|
| other (public/marketing, saved, activity, security, devices, invite) | 29 |
| institution | 22 |
| admin | 14 |
| me/identity | 5 |
| discover | 4 |
| publication | 3 |
| directory/profile | 3 |
| conversation | 3 |

Deep-linkable defects (route carries a `:param`): **30**.

---

## 3. Root cause — three shared layers, not 83 screens

### 3.1 The shared page surface renders no header

`AuraScaffold` is composed by **104** routed screens. It accepts `title`,
`leading`, `actions`, `centerTitle`, `showHomeAction`, `showHeader` — and
renders **none of them**. Its own comment says so: *"AuraScaffold no longer
renders any header UI."*

**18 screens pass `leading:` into it.** Those authors believed they were
providing a return control. Nothing appears. This is the single largest reason
a screen has no visible way back, and it is one file.

### 3.2 No shell offers a return affordance

Five shells frame every routed surface — `AppShell` chooses between
`MemberShell`, `InstitutionShell`, `AdminShell`, `PublicShell`,
`GlobalPlatformShell`. **None draws a back control.** The only `maybePop()`
calls in any of them close the navigation drawer.

`AppShell` already resolves the current path and classifies it through
`NavigationAuthority.contextOf`. It is the one place that sees every surface.

### 3.3 The product navigates by REPLACING the stack

Literal in-app navigation call sites:

| verb | sites | effect |
|---|---|---|
| `context.go` | **153** | stack replaced — **no predecessor exists** |
| `context.push` | 95 | stack grows — a return exists |
| `context.replace` | 2 | |

**36 defective destinations are reached by `go()`.** For those, there is nothing
to return to even in principle: not a back control, not Android system back, not
a gesture. `/support/agent` (×6), `/mission` (×4), `/institutions` (×4),
`/announcements/:id` (×4), `/spaces` (×3), `/search` (×3), `/privacy` (×2),
`/security`, `/saved`, `/updates`, `/me/invitations`…

**This is why "add back arrows" would not fix it.** An arrow on a surface with
no stack has nowhere to go, and a hardcoded parent is how that gets papered
over — which is exactly the 5 `HARDCODED_PARENT_RETURN` findings.

### 3.4 The pattern exists — in the protected domain only

`GuestShell.showBackButton` renders `Icons.arrow_back_rounded` →
`Navigator.maybePop()`, and it is **adopted 14 times — every one of them a
Meetings guest surface**. `InstitutionPage.showBack` renders the same control
and defaults to `context.pop()`; it is adopted **once**, product-wide
(`institution_post_detail_screen.dart`).

So Aura already has a working return affordance. It is confined to the one
domain this chapter may not modify.

Note both are **unguarded**: `pop()` / `maybePop()` with no `canPop()` fallback.
On a deep-link entry there is nothing to pop, so the control is inert. **22
screens call `pop()` without a `canPop()` guard.**

---

## 4. Non-route surfaces

| kind | count | note |
|---|---|---|
| `showDialog` | 51 | 1 with `barrierDismissible: false` |
| `showModalBottomSheet` | 29 | **15 are `isScrollControlled: true`** — full-height, reads as a page, not a sheet |
| `MaterialPageRoute` | 3 | outside go_router entirely — the router cannot see the person |
| `Navigator.push` | 2 | as above |
| `OverlayEntry` | 1 | |

**33 have no dismissal evidence in their own call neighbourhood.** That is a
weaker signal than the route findings (a sheet may be dismissed by drag, and the
scan reads only the opener's window) and is recorded as *needs inspection*, not
as a defect count.

The 3 `MaterialPageRoute` + 2 `Navigator.push` sites are the sharpest of these:
a surface pushed outside go_router has no URL, so on web a refresh loses it, and
`GoRouterState` cannot describe where the person is.

---

## 5. Protected boundary — Meetings / Live

**30 routes audited, none modified.**

* 19 expose no return affordance of their own.
* 13 compose `GuestShell`, and 14 `showBackButton: true` adoptions live in this
  domain — the only consistent return pattern in the product.
* `realtime_room_screen.dart` is one of only two `PopScope` users product-wide;
  the other is `edit_profile_screen.dart`. Both are flow-exit guards.

**Finding for the founder, no action taken:** the Meetings guest flow is the
reference implementation the rest of the product should converge on, and it sits
inside the boundary this chapter may not touch. Any canonical authority must be
able to *describe* it without changing it.

---

## 6. Architecture

### What exists

| authority | owns |
|---|---|
| `navigation_authority.dart` (C3) | destination identity, canonical route generation, path→destination matching incl. legacy aliases, shell-context classification |
| `canonical_destinations.dart` | minting a FORWARD destination from an identifier (mirrors the backend `canonical-destinations.ts`) |
| `destination_continuity.dart` (RC4) | gate exit/return: preserve → validate → consume, temporary vs terminal, loop prevention, open-redirect refusal |
| `route_classification.dart` (F069/RC6) | reachability and policy per route |

### What is missing

Nothing owns **"given where I am and how I got here, where does OUT go, and what
control shows it."** RC4 answers it for *gates* only — the destructive-exit
case. Ordinary hierarchical return has no owner, which is precisely why it was
answered 83 different times, 47 of them by not answering.

### Proposed: `ReturnPathAuthority` — a SIBLING contract, not an extension

A sibling, for one reason that comes out of the evidence: RC4's subject is a
*gate refusing a destination*, and its vocabulary is `ExitKind` — can this
person pass. Return's subject is *a person standing somewhere wanting out*. They
compose (return consumes RC4's `validatedReturnTarget` and its terminal/
temporary distinction), but folding return into RC4 would make one file answer
two different questions, which is the shape RC6 was written about.

```
ReturnPathAuthority.resolve(
  current:      destination identity      (from C3)
  provenance:   how it was entered        (push / go / deep-link / notification)
  stack:        can the router pop        (context.canPop)
  acting:       person / institution      (C1 — per-act, never route-derived)
  context:      institution / person      (from the path, presentation only)
  flow:         unsaved-work state        (owned by the flow, queried here)
  platform:     web / android / ios / desktop capability
) -> ReturnAction { semantic, destination?, affordance }
```

Semantics, all present in the census: `STACK_RETURN`, `PARENT_RETURN`,
`CONTEXT_RETURN`, `FLOW_CANCEL`, `FLOW_COMPLETE`, `MODAL_DISMISS`,
`ROOT_NO_RETURN`, `DEEP_LINK_FALLBACK`, `TERMINAL_EXIT`, plus
`HARDCODED_PARENT_RETURN` as a defect class the authority exists to eliminate.

**The parent map is derivable, not invented.** 59 institution routes are
`/institution/:id/<section>[/...]`; the canonical parent of a detail is its
section root, and of a section root the workspace. `canonical_destinations.dart`
already mints those addresses. This is why a `DEEP_LINK_FALLBACK` can be
truthful rather than a hardcoded `/home`.

### Where it renders

`AppShell` — the one widget that frames every routed surface and already knows
the path and the shell context. One integration point corrects the 104
`AuraScaffold` screens without touching them.

`AuraScaffold` then either grows the header it already takes arguments for, or
formally drops those arguments. **Both are defensible; the founder should
choose.** Keeping arguments that render nothing is not.

---

## 7. Proposed implementation batches (NOT started)

| # | batch | blast radius | why first |
|---|---|---|---|
| 0 | Freeze the audit (this document + gate test) | none | done |
| 1 | `ReturnPathAuthority` + tests, wired to nothing | none | the contract can be reviewed before anything moves |
| 2 | Shell integration in `AppShell`, behind the authority | every routed surface — **highest risk, highest yield** | corrects 104 screens at one site |
| 3 | `AuraScaffold` header decision | 104 screens | resolves the 18 dropped `leading:` |
| 4 | `go` → `push` correction for the 36 stack-replacing defective destinations | navigation semantics platform-wide | without this, batch 2 has nothing to return to |
| 5 | `canPop()` guards on the 22 unguarded `pop()` calls | 22 screens | deep-link entry |
| 6 | The 5 `HARDCODED_PARENT_RETURN` sites | 5 screens | mechanical once 1–4 land |
| 7 | Non-route surfaces: the 5 outside go_router first | 5 sites | they have no URL at all |
| 8 | Meetings/Live — **founder authorization required** | 30 routes | protected |

Batch 4 is the one that will look like unrelated churn in review and is the one
the others depend on.

---

## 8. Findings accounting

**A. Executable under the eventual approved implementation, no decision needed**
— the 47 MISSING, 25 DEEPLINK_ESCAPE_MISSING, 6 WRONG_RETURN_SEMANTICS, 5
HARDCODED_PARENT_RETURN, the 22 unguarded `pop()`, the 18 dropped `leading:`.

**B. Requires a founder / product decision**

1. **`AuraScaffold`: grow a header, or drop the arguments?** 104 screens either way.
2. **Does a return affordance belong in the shell chrome or on the page?** The
   ruling separates semantics from presentation; this is the presentation call.
3. **`go` → `push`:** correcting 36 destinations changes URL/history behaviour
   product-wide and interacts with the frozen REFRESH-IS-NOT-NAVIGATION contract.
4. **Public/marketing surfaces (29 defects in "other").** On web these lean on
   browser chrome. Are `/privacy`, `/terms`, `/mission` first-class app
   destinations on Android/iOS, or web-only?
5. **The 15 full-height modal sheets** — should a sheet that fills the screen be
   a route instead? That is an IA decision, not a navigation fix.

**C. Protected-boundary** — the 30 Meetings/Live routes, and the fact that the
product's only consistent return pattern lives inside them.

**D. External blockers** — none. The audit needed no unavailable capability.

---

## 9. Classification

| | |
|---|---|
| `GLOBAL_NAVIGATION_RETURN_PATH` | **SYSTEMIC_DEFECT** |
| `RETURN_PATH_CENSUS` | **COMPLETE** (175/175 routes, 86/86 non-route surfaces, 96.8% attributed with the remainder accounted for) |
| `MOBILE_NAVIGATION_VIABILITY` | **FAIL** (78 of 151 audited surfaces not mobile-viable) |
| `DEEPLINK_RETURN_AUTHORITY` | **FAIL** (30 deep-linkable defects; no `DEEP_LINK_FALLBACK` mechanism exists) |
| `CANONICAL_RETURN_ARCHITECTURE` | **MISSING** (the neighbouring authorities exist and are sound; return has no owner) |

---

## 10. Method note

Every count here is re-derivable. `test/navigation/return_path_census_dump_test.dart`
walks the live router and writes `_route_census.json`; the tooling in the job
scratch directory joins it to per-screen source evidence and emits the CSVs.

Two tooling errors were found and corrected during the audit, both by
hand-checking results rather than trusting them:

* a structural parser silently dropped 3 routes and mis-attributed 5 to
  `Scaffold` and 1 to an enum;
* attribution initially named `InstitutionRouteScope` — the route *boundary* —
  as the screen for the entire institution population, which would have reported
  every institution route as having no way back. Correcting it moved COMPLIANT
  14 → 18 and institution defects 26 → 22.

A third correction is recorded in the gate test: "exactly one screen opts into
the shared back control" was wrong. One opts into `InstitutionPage.showBack`;
fourteen opt into `GuestShell.showBackButton`, all inside Meetings.
