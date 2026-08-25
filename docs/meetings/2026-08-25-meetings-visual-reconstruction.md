# Meetings — visual and interaction reconstruction

Founder ruling 2026-08-25 (second Meetings ruling). The structural
reconstruction was accepted; the founder then opened the product and returned a
correction that was correct:

> **The Meetings experience is structurally reformed, but visually it has
> barely changed.**

This document is the inventory that pass started from, what was rebuilt, and
what is honestly still owed.

---

## 1. The inventory — taken from the live product, not the source

Every item below was observed on `auraplatform.org` in Chrome at 1512×812,
signed in as the founder, before any code was written. §3 required looking at
the product rather than inferring quality from widget source, and looking
changed what I would have guessed.

| # | surface | what was actually there |
|---|---|---|
| 1 | Meetings landing, Create meeting | **The page title rendered twice** — once by the shared header, once by the screen's own heading |
| 2 | Meetings landing | Three buttons, **two of them filled purple**, so nothing was primary |
| 3 | Meetings landing | Subtitle "Host, attend, and manage your meetings." — describing the page to somebody already looking at it |
| 4 | Meetings landing | The **booking URL as a full-width card** directly under the actions: the most prominent thing on the page |
| 5 | Meetings landing | **Five sections rendered unconditionally**, each with its own grey box saying there was nothing in it |
| 6 | Meetings landing | Two **large centred spinners**, one per section, while anything loaded |
| 7 | Meeting record | Header read the generic word **"Meeting"** above the meeting's real name |
| 8 | Meeting record | One **880px column on a 1500px window**; attendance and the meeting's conversation sat below the fold |
| 9 | Booking flow | **Two return controls stacked**: the governed "✕ Cancel" and the screen's own "← Back" |
| 10 | Public booking page | ~9 s of **full-page spinner in an empty void** before anything appeared |
| 11 | Meeting record | 10–15 s of the same |
| 12 | Create meeting | Title field pre-filled with the literal word "Meeting", echoed as a checklist item in the Review panel |

**Item 1 was a regression I introduced.** Growing `AuraScaffold`'s header
during the navigation chapter meant every screen that already drew its own
heading drew two. It reached beyond Meetings: Invitations, Invite, Admin
workspace and Aura Editor were all doing it.

### One thing I got wrong while inventorying, and corrected

I recorded that the meeting record **would not scroll** — mouse wheel and Page
Down both did nothing, and content below "Keep talking" looked unreachable. I
wrote a widget test to pin it, and the test showed the scaffold scrolls
correctly; my first version of that test simply did not drag far enough.
Re-checked, the live behaviour was synthetic input not reaching Flutter's
canvas, not a product defect.

The test survives as `test/navigation/aura_scaffold_header_test.dart`, because
"does the shared header cost 104 screens their scroll" is worth an assertion
either way.

### The comparison that set the bar

**Members** and **Explore** render their title once, and **Create** — rebuilt
in the previous chapter — has a real subtitle, a card grid with icon tiles, and
an honest inline loading chip. The product already contained the standard
Meetings was missing.

---

## 2. What was rebuilt

### The landing

It now leads with **"Up next"** — or **"Happening now"** when something is live
— because that is the question a person opens Meetings to ask. Below it, only
sections that have something in them: Needs attention (with a count and a
marker), Upcoming, Invitations. On a desktop window a second column carries
Follow-up, the booking link and the past-meetings archive, so they are
permanently in view instead of a screen and a half down.

An account with genuinely nothing says so **once**, with an icon, a sentence
about what would appear here, and the action that makes it happen.

One primary action. "Start now" and "Join by code" are quiet text buttons.

### The card

`lib/features/meetings/presentation/widgets/meeting_card.dart`

The old card was seven stacked fragments — title, status pill, relationship
pill, institution pill, a `"$time · $host"` line, the action label as text, and
then the same label again as a button.

It is now an object, opening with a **calendar block**: DAY / NUMBER / MONTH,
fixed width so a column of them lines up and can be scanned for "when" without
reading a word. Then the title, one line of context, and exactly one action —
filled when the meeting is live, outlined when it is not. An instant meeting
shows **NOW** rather than an invented date.

### The record

One 880px column became a workspace: what the meeting **is** on the left
(identity, agenda, materials, aftermath), who and what surrounds it on the
right (attendance, the meeting's Conversation, the cancel action). The generic
"Meeting" header is gone — the card below it already says the status, the name
and who convened it.

This also makes R-3 visible as the product advantage §12 asks for: **"Keep
talking"** sits beside the attendance list, above the fold, instead of being
something you had to scroll to find.

### The states

`lib/features/meetings/presentation/widgets/meeting_surfaces.dart`

* **Skeletons** with the shape of what is coming, not centred spinners.
  Deliberately unanimated — a shimmer across five cards is motion for its own
  sake, which §18 rules out.
* **Empty states** with an icon, a headline, what would appear here, and the
  action that resolves it.
* **Errors** in the product's voice. The old one rendered
  `'Unable to load. $e'`, putting a raw `DioException` on screen.
* The follow-up card showed a spinner while the meeting it came from resolved,
  **hiding the outcome text it already had**. It reads immediately now.

---

## 3. Three things only the live product revealed

Deploying and looking again caught defects that reasoning about the source did
not:

1. **The two-column layout never appeared.** The page asked its own
   `LayoutBuilder` constraint, which is 1180 in isolation — but wrappers
   between the shell and the page narrow it on the live site, so a 1512px
   window resolved as *narrow* and the primary action stretched edge to edge.
   The breakpoint now asks the **viewport**, which is what "is this a desktop"
   actually means.
2. **The skeletons centred instead of filling their column**, so the
   placeholder did not stand in for the list — the one job a skeleton has.
3. **`AuraScaffold` clamps to 920px** by default, below this page's own
   breakpoint, so even the corrected layout could not have triggered.

None of these would have been found by reading the diff.

---

## 4. Also fixed

* The booking flow's second return control, retired (R-4: one governed way out).
* The **second** copy of the personal-meeting `/home` fallback — twin of the one
  fixed in the structural pass, in `_meetingPathFor`.
* Four non-Meetings screens that the header regression had also broken.

---

## 5. What is honestly not done

* **Physical Android screenshots.** The Pixel 9a is locked with a PIN. The app
  is installed and behavioural certification runs, but `screencap` is blocked
  on the secure screen and I did not attempt the PIN. Device screenshots need
  the founder to unlock it.
* **The active meeting workspace (§11)** got its controls labelled and its
  failure states corrected in the structural pass, but its visual composition
  is not reconstructed. It remains the largest surface still looking like what
  it was.
* **Create meeting (§4)** lost its duplicate heading; the form itself is
  unchanged.
* **Load time.** The record takes 10–15 s and the public booking page ~9 s
  before anything renders. Skeletons make that honest rather than empty; they
  do not make it fast. This is a data-path problem, not a visual one, and it is
  recorded rather than dressed over.

---

## 6. Certification

Harness: `integration_test/meetings_certification_test.dart`, extended with
three assertions about the reconstruction itself.

| | Windows native | Physical Pixel 9a | Web |
|---|---|---|---|
| result | **14/14 PASS**, real session | **14/14 PASS**, 10 exercised / 4 skipped (no session) | reconstruction **observed live** on production |
| reconstructed card renders | PASS | PASS | observed |
| skeleton, not spinner | PASS | PASS | observed |
| empty state is actionable | PASS | PASS | observed |
| primary action size | 35 px — pointer | **48 px — touch** | — |

That last row is the one worth keeping. It is the *same code*: Flutter compacts
controls on desktop, so the button is 48 px where a finger is the pointer and
35 px where a mouse is. An earlier version of this assertion demanded 44 px on
Windows and failed — it was measuring a touch rule against a pointer platform.
The corrected assertion proves the density adaptation is real rather than
assumed.

### Two harness defects found and fixed while certifying

1. **Cross-test exception bleed.** The integration binding shares one zone
   across the file, so a network error from an earlier test's still-running
   provider surfaced in `takeException()` of a later one — making a passing
   test report another test's problem.
2. **A token is not a session.** `/auth/refresh` issues single-use tokens, so a
   stored token can be present and already spent; the router then lands on the
   auth gate while the store still looks authed. The harness asked the store
   alone and asserted straight through a login screen. It now asks where the
   router actually landed.

Repeated certification runs also tripped the API's rate limiter, which
cascaded into unrelated failures. Those were my own doing and are recorded so
the run history is not mistaken for product instability.

```
MEETINGS_WINDOWS_VISUAL_CERTIFICATION = PASS
MEETINGS_ANDROID_VISUAL_CERTIFICATION = PASS_WITH_LIMITATIONS
MEETINGS_WEB_VISUAL_CERTIFICATION     = PASS (observed on production)
MEETINGS_IOS_CERTIFICATION            = NOT_EXECUTED
```

Android is `PASS_WITH_LIMITATIONS` for two honest reasons: the debug build has
no session, so four session-dependent assertions skipped; and the device is
locked with a PIN, so `screencap` is blocked and no device screenshots exist.
I did not attempt the PIN.

**Test health:** 1469 client tests green, `flutter analyze` unchanged at its
24-item baseline.
