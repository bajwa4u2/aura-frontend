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
