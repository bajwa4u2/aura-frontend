# Meetings closeout — Create Meeting, and the "shared bootstrap hang"

**Date:** 2026-08-25
**Ruling:** founder — *FINAL MEETINGS CLOSEOUT BATCH: CREATE MEETING + SHARED
BOOTSTRAP HANG*
**Method:** open and experience the released product. Do not infer product
quality from source code or tests alone.

---

## Part B first, because it changes what Part A was allowed to assume

### `SHARED_BOOTSTRAP_HANG = DOES_NOT_EXIST — MEASUREMENT ERROR, MINE`

I previously reported that `GET /meetings/:id` never fires and that the meeting
record was release-critically broken. **That was wrong, and the error was
mine.**

Every one of those measurements was taken against a **background browser tab**:

```
document.visibilityState : "hidden"
framesInAbout1s          : 0
```

Chrome suspends `requestAnimationFrame` in a hidden tab. Flutter builds widgets
on the frame pipeline, so no frames means no rebuild, no provider watch, and no
request. The application was not hanging; it was not running. The repeated
`Injecting <script> tag` re-bootstraps in the console were my own automation
attaching, not the app restarting.

With frames flowing, the record loads normally:

```json
{"u":"/meetings/cmspg729e014fpb0cor0lr2ov","s":1801,"d":526}
```

`GET /meetings/:id` dispatched at 1801 ms, completed in 526 ms, record fully
rendered by ~3.3 s. Windows native never reproduced it either — dispatch at
+453 ms.

This is the exact trap already recorded in my own notes about Flutter web and
hidden tabs. I did not check the precondition before escalating.

**Consequences, deliberately:**

- No retries, timers, forced refreshes, delayed provider watches or other
  local workarounds were added to Meetings. The ruling forbade them, and there
  was nothing to work around.
- The diagnostic instrumentation was reverted in `a5a3bc4`.
- **No boundary was crossed into signaling, TURN, WebRTC/media transport, the
  camera/microphone engine, device selection, connection/reconnection
  architecture, call-session lifecycle, or Live Broadcast.** The measured cause
  sits outside the product entirely.

---

## Part A — Create Meeting

Audited by using the live form at
`/institution/aura-platform-llc/meetings/new`, signed in, in a **foreground**
tab. Seven defects, all of them things you only see by looking.

| # | What the released form did | Now |
|---|---|---|
| 1 | Title field arrived **pre-filled with the literal word "Meeting"**. Anyone who did not overwrite it created a meeting called Meeting — production has several. It was then echoed back as the last "Review" line, so the form ticked a green check at a title nobody chose. | No default. A placeholder that asks *"What is this meeting for?"*, and a helper: *"Everyone invited sees this first."* |
| 2 | Review panel was a flat list of strings, each carrying the same green check whether or not anything was satisfied. | A summary with a shape — title, **When**, **How long**, **Who**, **Convened by** — that shows what is still **missing** as missing. |
| 3 | The only signal that participants were required was a **snackbar on submit**, naming a "Host only" toggle several screens below the fold. | The **Who** row reads *"Choose who is in this meeting"* unmet, and resolves to *"Everyone at Aura Platform"* the moment it is satisfied. Before submit. |
| 4 | A **Booking page card** — duplicated from the Meetings landing, showing a raw URL — sat between the last field and the button that creates the meeting. | Gone. The booking page has its own place on the landing. |
| 5 | Subtitle read *"Internal participants are **bound at creation**."* — how the backend describes the write. | *"Give the meeting a purpose, decide who is in it, and choose when."* |
| 6 | Member picker's loading state was a spinner centred in a 220 px hole. | The shape of the list. |
| 7 | With **All active members ON**, the line beneath read **"No internal members selected"** — the meeting had everyone and the form said nobody. | The line has nothing to report in that mode, and does not appear. |

### Defects introduced by the reconstruction, and caught

Both were found in the deployed build. The suite was green for the first.

- **The question never appeared.** An empty, unfocused Material field draws its
  *label* inside the box and suppresses the *hint*, so the field I had just
  rebuilt to ask "What is this meeting for?" showed only "Meeting title".
  Fixed with `floatingLabelBehavior: always`, and pinned.
- **"Owning institution" was rendered as the convening institution's NAME** for
  as long as the record took to load — an internal placeholder standing in for
  a real name on the first frame. It now shows nothing until it knows.

Two more found while pinning the work:

- Removing the default title exposed that the panel had **no controller
  listener**, so it would have read "Untitled meeting" while you typed.
- The two invitee buttons **overflowed their card by 23 px** on a narrow
  window. `Row` → `Wrap`.

### C0 register

One full-surface spinner removed from `create_meeting_screen.dart`, so its line
leaves `test/product/c0_drift_baseline.txt`. The ratchet caught the reduction
in the good direction, which is what it is for.

---

## Open, named, not closed quietly

- **`CREATE_REVIEW_PANE_WIDE_LAYOUT = SCROLLS_OUT_OF_VIEW`.** In the two-column
  layout the summary is inside the page's `ListView`, so it leaves the top of
  the window once you reach Participants — the point at which the thing it is
  telling you is missing is the thing you are supplying. The narrow layout is
  unaffected: the panel sits directly above the button. A correct fix moves the
  wide layout's left column into its own scrollable so the right column can be
  pinned; that is a restructure of the screen's scroll architecture, not a
  wrapper. I did not ship a wrapper that does nothing.
- **`CREATE_SUBMIT_PRODUCTION = NOT_EXECUTED`.** Certified to the point of
  submit. Pressing it writes a real meeting into the founder's production
  institution, which is the founder's data and not mine to create for a test.
  The submit path itself is unchanged by this batch.
- **`SHARED_BOOTSTRAP_LOADING_COPY = SHARED_SURFACE`.** The bare "Loading" and
  "Loading institutions" seen entering Create come from the route boundary in
  `lib/core/product/product_state.dart`, not from Meetings. Patching it inside
  Meetings would be the local workaround the ruling forbids. It belongs to
  whichever chapter owns the product-state surface.
- **Android and iOS: `NOT_EXECUTED`.** Android screenshots are still blocked by
  the PIN-locked handset, and the PIN was not requested. iOS has had no device
  execution. Neither is certified, and browser verification is not a proxy for
  either.

---

# Closeout correction (same day)

Founder ruling: fix the wide-layout scroll architecture properly, fix the
shared entry loading at its canonical owner, and run ONE controlled production
creation.

## 1. `CREATE_REVIEW_PANE_WIDE_LAYOUT`

The whole screen was one `ListView` with the review pane inside it. No wrapper
could fix that, so the scroll architecture changed.

On wide layouts the form and the review rail are now **sibling scrollables** in
a bounded `Row`: the form scrolls, the rail does not move with it. Height is
tight, taken from the body constraints via `LayoutBuilder`, so there is no
unbounded Row-of-scrollables ambiguity. The pair is centred **as a pair**, so a
wide monitor gets no gutter between them. The primary action moved into the
rail beneath the summary — what you are about to create, and the button that
creates it, together and not moving.

Narrow is unchanged: one column, review directly above the button.

**A nested-scroll trap was found while proving it.** The member picker was a
fixed 220px well containing its own `ListView`. On a narrow window it sat across
the middle of the form and swallowed the page's scroll gestures — dragging
anywhere over the member area moved nothing, so the form below it and the
create button were **unreachable by touch**. Members now lay out inline, the
page scrolls as one surface, and the search field is what narrows a long list
(first 8, then a count).

## 2. `SHARED_CREATE_ENTRY_LOADING`

Fixed at the canonical shared owner. No Meetings branching.

* **Copy** (`core/product/product_state.dart`): "Loading" is what the code is
  doing, not what the person is waiting for. The headline is now constant and
  calm; the **subject moves into the detail**, which keeps the C0 distinction
  (three stacked waits still read differently) without putting an
  implementation word in the largest text on screen.
* **Rendering** (`core/ui/aura_platform_components.dart`): `AuraLoadingState`
  is a 16px spinner beside a word — right inline, wrong centred in an empty
  page, where it reads as a *stalled* screen. `AuraLoadingSurface` is the
  surface-scope counterpart and is deliberately the same shape as the content
  that replaces it, so the page does not jump. It is static by design: a
  repeating animation would hang `pumpAndSettle` in every test that waits on a
  loading screen.

Regression-tested against non-Meetings consumers.

## 3. `CREATE_SUBMIT_PRODUCTION` — the one authorized creation

Created **"Aura Meetings Certification — Temporary"** in Aura Platform LLC,
**Host only**, so nobody was invited and nothing was notified.

| Step | Result |
|---|---|
| Create | Submitted from the rail button |
| Persistence | `cmt963zjv0096li0c1d2qm1h5` |
| Navigation | Straight to the record |
| Record | Scheduled · Hosted by M S Bajwa · Tue 25 Aug 2026, 6:18 PM (your time) · 60 min · Start meeting / Invite / Add to calendar / Edit · Agenda · Participants 1 (Host, Not joined yet) · Keep talking (R-3 continuity) · Cancel meeting |
| Landing | Appears under **Up next** with the calendar block |

### A defect the creation itself exposed

The new meeting rendered **twice** on the landing — once under "Up next" and
again under "Needs attention". Both were defensible on their own terms: a
meeting starting within three hours does need attention, and it was also the
most imminent one. But the same card twice on one screen reads as two meetings,
and the count beside "Needs attention" counts it again.

`rest` already excluded the up-next meeting; `attention` was computed from the
whole list and did not. Up next is the strongest placement the page has, so it
wins. Pinned in `test/meetings/meetings_landing_sections_test.dart`.

**This is exactly what the authorized production creation was for.** No amount
of reading found it.
