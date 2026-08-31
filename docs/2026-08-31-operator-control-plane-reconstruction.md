# Operator Control Plane — Reconstruction

**Date:** 2026-08-31
**Scope:** `aura_final/lib/features/admin`, `aura-backend/src/admin`,
`aura-backend/src/institutions`, `aura-backend/src/moderation`
**Preceded by:** the operator hub migration (17 legacy routes → seven areas) and
the authenticated verification pass that followed it.

---

## Why this exists

The hub migration filed seventeen legacy routes under seven headings. Management
rejected the result and the framing that went with it — "four bounded causes, not
a reconstruction gap" — and ruled that the seven areas were a PRODUCT MODEL and
not a filing system.

> THE LEGACY ROUTES WERE ARCHAEOLOGY, NOT THE DESIGN.

What is preserved is authority, governance, records, audit, security, custody and
capability. What is not preserved is screen boundaries, backend-shaped forms,
queue fragmentation, raw payload presentation, developer terminology, old
interaction models, route ownership and UI composition.

---

## The method that changed first

Everything below rests on one correction, and without it the rest would have been
another confident pass:

> I proved the console against fixtures I wrote myself.

A fixture authored on the client side encodes what the client ALREADY BELIEVES,
so it cannot fail. Three shipped defects passed every green test:

* health has no `services` key — the client's model invented one, then reported
  "5 of 5 degraded" over a healthy platform;
* grants come back `status: 'ACTIVE'`, and the client compared lowercase;
* audit rows carry `actorUserId`, and the client read `actorId`.

**The contract pipeline** (`aura-backend/src/admin/contract/`) now builds every
fixture from the SERVER's own mappers, writes them to `contracts/admin/*.json`,
and vendors the same files into `aura_final/test/contracts/admin/`. The client is
tested against the server's statement of shape; the server asserts it still
produces it. 26 captures, 63 backend conformance tests, 46 client ones.

Two disciplines inside that pipeline earned their keep:

* **Stubs honour the query.** A Prisma stub that ignored `where` published a
  number no query produced. The subject and owner-continuity stubs interpret the
  clause, so "does the service ask the right question?" is what is under test.
* **Capture at the wire, not one layer below.** The work contracts were captured
  from the SERVICE, whose return value has no `totalOpen`. The CONTROLLER adds
  it. The client defaulted a missing `totalOpen` to zero and the WORK header read
  "All 0" above four open items. The captures now go through the controller.

---

## What each area became

### NOW — the situation, not a dashboard
Three independent sections, each failing alone: what needs attention (headline
number, queues with age rails), whether Aura is well (one line when healthy,
expanded when not), what changed (operator DECISIONS only — reads and refusals
belong to RECORD).

### WORK — one bench
The canonical `OperatorWorkItem` projection across seven sources with
`Promise.allSettled`, so a failed source is shown DISABLED with `—` and never as
a zero. A partial worklist is disclosed as the first row of the list rather than
presented as total.

### SUBJECTS — one subject, one answer
* **"6 members" vs "5" — resolved.** `listInstitutions` counted
  `_count: { members: true }` while every other member projection in Aura
  excludes removed rows. The operator directory was the one surface in the
  product that counted people who had been removed.
* **The directory hid subjects.** No status filter meant VERIFIED only, so every
  pending, suspended and rejected institution was absent from the console's one
  institution list, invisibly. Standing is now a facet the operator chooses.
* **A subject is resolved by id**, not found inside a status-filtered list — a
  suspended institution used to report "No such institution" on its own page.
* **Two shapes for one fact:** the directory sends `_count.members`, the by-id
  read sends `memberCount`. The client reads both.

### INTEGRITY — evidence before judgement
The report detail showed "Reported post" and a cuid. An operator was asked
whether Aura should act against content they had never been shown.
`resolveReportSubject` now serves WHAT was written, WHO is answerable, WHEN, and
whether it still exists — and refuses to manufacture any of it:

| case | answer |
|---|---|
| content present | the text (bounded to 600 chars), its author, when |
| content deleted | `exists: true`, `removedAt` set, **no excerpt** |
| person reported | no excerpt — the judgement is about the account |
| target gone | `exists: false`, the reference alone |

### PLATFORM — only what runtime consumes
The policy document (seven switches) and the Configuration dump are GONE. A grep
across the backend settles it: not one of those policy values is read by any
runtime path, and the maintenance switch read ON while Aura served every request.
Nothing was wired up to preserve them — wiring fake consequence would be the same
lie with more code behind it. What remains: health, released-client fleet, the
three flags the code genuinely reads, media retention.

### RECORD — who did what to whom
Audit rows store a type word and a cuid; the record exists for people who were
NOT there. `withResolvedSubjects` resolves person and institution targets in one
batched query per class. Everything else stays a reference — a record that
invents a name for a deleted subject is worse than one showing an id. Column
headers were added because WHO DID IT and TO WHOM are both names, side by side.

### DISCOVERY — provenance survives an empty result
"Nothing on record" could not be told from "nothing that could look was able to
run". Those are opposite conclusions. The source panel now stays in the empty
state, and the empty state says which of the two it is.

---

## Front door

`GET admin/entry` is guarded by `JwtAuthGuard` ONLY — deliberately not
`AdminGuard` — so a non-operator gets a truthful `false` instead of an
audit-logged 403. `canEnterOperatorConsoleProvider` defaults FALSE on every
failure. The entrance appears in the header menu and the member drawer.
Capability determines visibility.

---

## Self-authority safety

`countActiveOwnerGrants` counted ROWS, and the continuity guard had two ways to
be satisfied by an owner who cannot act:

1. one person holding two active OWNER grants reads as "two owners";
2. an OWNER grant on a disabled or deleted account counts, while the person
   behind it cannot sign in.

`countActiveOwnerHolders` counts distinct users whose account is usable. The
guard is asked at revoke, at demote, and at disable.

The subject read publishes `otherOwnerHolders` so the CONSOLE can withhold the
control rather than offering a button whose only outcome is a 403 — and the RULE
is printed where the control would have been, because a missing button with no
explanation reads as a bug. Self-revocation stays available (an operator may
stand down) but is written in the first person and says the authority cannot be
restored by the person giving it up.

An unknown count never withholds a legitimate action. Only a positive zero does.

---

## Performance is product

Diagnosed, not masked:

* **Two authority bootstraps.** `appAdminAccessProvider` and `adminMeProvider`
  each fired `GET /v1/admin/me`. Every gated provider awaits the second one, so
  the whole data layer sat behind a round trip whose answer was already in
  memory — and entering the console wrote two audit events for one act.
  `adminMeProvider` now derives from the probe.
* **Shared readings were discarded on every transition.** NOW and WORK show the
  same numbers; moving between them disposed the worklist and re-fetched it
  behind a skeleton. `cacheOperatorReading` gives a reading a 20-second survival
  window, restarted from the last look, and an explicit invalidation after an
  operator DECISION still discards it immediately.

---

## State architecture

`OperatorSignal<T>` carries `OperatorReach` (pending / complete / partial / stale
/ unavailable / unauthorized) and `OperatorCondition` (healthy / attention /
degraded / failed / unknown). Unknown sits above healthy and below degraded, and
only degraded and failed are adverse. `OperatorSignalView` is the single place
the console decides what to draw per state; partial and stale reach the builder
WITH their value and a disclosure.

---

## Language

Stored enums stopped reaching the screen: `Report: HARASSMENT` → "Reported for
harassment"; `Feedback: DEFECT` → "Defect reported"; `Media cmomedia` (a
truncated cuid) → `brochure.pdf`; `missing_permission` → "The permission this
action requires was not held"; `ROLE_OR_CREDENTIAL` → "Role or credential";
`MODERATION could not be read` → "Moderation could not be read". Prose written by
an operator is never rewritten.

---

## Responsive

Six widths, rendered: **1440 / 1024 / 768 / 390 / 360 / 320**.

`kOperatorDesktopWidth` was 1180, so 1142 — an ordinary laptop viewport, and the
one actually reviewed on — fell into an icon-only rail: seven unlabelled glyphs.
The threshold is now 1000, and the compact rail (92px) stacks icon over label, so
every area is NAMED at every width. Three widths could never have shown this:
1440 was fine, 900 was fine, and the range between them was never looked at.

94 renders in `test/admin/goldens/operator/`. The harness is tagged `golden` so a
0.04% antialiasing difference does not fail the suite — it writes pictures for a
person to look at.

---

## What operating the real console found

Deployed, then opened as the operator against production. Everything below was
invisible to 2148 client tests, 4054 backend tests and 94 renders, and showed up
within minutes of using the thing.

### The worklist had never answered in production

`OperatorWorkController` carried no `@RequireAdminPermission`, deliberately: a
single permission gate would lock out a MODERATOR, and per-source filtering
already happens inside the service. That reasoning was right about the semantics
and wrong about the mechanism. `AdminGuard` **is** `AdminPermissionGuard`, whose
first statement is:

```ts
if (!required || !required.length) {
  throw new ForbiddenException('Admin permission not configured')
}
```

Declaring nothing did not mean "any operator". It meant **403 for everyone**,
owner included, on every load, with an `admin.access.denied` audit row written
each time. Live, an OWNER holding 25 permissions was told across four surfaces
at once that they held no queue they could work.

`hasPermission` is a `.some()`, so listing every queue's READ permission states
the rule exactly: hold one queue and you are admitted; the service filters to
what you can read. `admin-route-authority.spec.ts` now asserts the declaration
exists, that no admin-guarded controller declares nothing anywhere, and that the
guard really does refuse an undeclared route — the behaviour that made this
silent. It looks at the seam between the decorator and the guard, because that
is the one place nothing else was looking: the service was tested directly, the
contracts were captured from the controller class rather than through the guard,
and the render harness supplied its own data.

### The rest

| finding | cause |
|---|---|
| "You do not hold **a queue you can work** authority." | a clause passed into a noun slot that fills "You do not hold ___ authority" |
| the previous area painted over the next, legibly, for the whole transition | `builder:` gives go_router a cross-fading page; two transparent operator areas are alive and stacked. They use `NoTransitionPage` now — an area switch is a mode change, not a journey |
| the people directory's authority column was always empty | it read a top-level `role`; the server sends `admin.roles`. The hand-written fixture filled it with `MEMBER` — an INSTITUTION role, a platform rank that does not exist |
| a queue whose oldest item arrived today showed a blank age | gated on `age > 0`; `OperatorAge` already says "today" and was never asked. Two places: NOW's queue rows and INTEGRITY's family rows |
| the queue filter clipped its last chip at 1440 | a horizontal scroller with no affordance. It wraps now |
| a "synthetic" fixture id resolved to a real account | `personRef` generated a pattern that collided with a live cuid |

### Confirmed working in production

* NOW: "4 waiting across 3 queues", oldest 171 days, queues ordered oldest-first
  with age rails, health collapsed to "All services healthy" — the canonical
  projection that used to report "5 of 5 degraded" over a healthy platform.
* WORK: the bench, live, for the first time. Real domain proofs at 171 and 75
  days, a moderation report, product feedback. `All 4` agreeing with the list.
* SUBJECTS: the founder's own subject page carrying "This is your own authority.
  Anything withdrawn here is withdrawn from you, immediately." and — because
  they are genuinely the only owner — "Nobody else can act as owner. Appoint
  another owner before withdrawing this one." with the Revoke control absent.
* INTEGRITY: three judgement families, each carrying its question in the
  operator's words and its own real counts — "1 waiting", "Nothing waiting",
  "3 days".
* PLATFORM: the canonical health projection with all five checks; the policy
  document and the Configuration dump confirmed GONE; the three flags the code
  really reads, in operator language; real retention figures. The fleet says
  "No client has reported in this window — that is not the same as a healthy
  fleet" rather than implying health from silence.
* DISCOVERY: an empty result that keeps its provenance — "Every source below
  reported, and found nothing", then "2 of 6 sources ran · 4 could not" with
  each source's own reason.
* RECORD: real decisions with actors and reasons.
* The area transition is now instant and clean: a screenshot taken at the
  moment of the click already shows the incoming area alone, with nothing of
  the outgoing one left on screen.

### Still open after this pass

* **Cold bootstrap is 25–40s** on a full page load and a first visit to an area
  still waits on the API behind a skeleton. The two structural causes named
  above are fixed; what remains is API latency, and it has not been measured
  per-endpoint against production. Not diagnosed, not claimed.
* The moderation row in the worklist names its subject `User` — the target TYPE,
  not the person. Resolving it would cost a lookup per row; RECORD resolves the
  same class because it is a detail read. Disclosed, not fixed.

---

## Verification state

| | |
|---|---|
| `dart analyze lib` | 0 issues |
| client suite | 2148 passing (`--exclude-tags golden`) |
| backend `tsc --noEmit` | clean |
| backend suite | 4054 passing, 325 suites |
| C0 anti-drift gate | passing (two violations introduced and fixed: a "Try again" label, a local time formatter) |

---

## Still uncovered by a contract

Honest list, not a claim of completeness. These surfaces still render from
fixtures written on the client side, and a defect in their shape would not be
caught:

`/admin/metrics`, `/admin/discovery/*`, `/admin/clients/overview`,
`/admin/media-cleanup/status`, `/admin/media/appeals`, `/admin/feedback`,
`/admin/support/cases`.

`/admin/users` came off this list during the pass, and immediately exposed a
defect that had been live the whole time — which is the argument for closing the
rest of it.
