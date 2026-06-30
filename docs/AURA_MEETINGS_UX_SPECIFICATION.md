# Aura Meetings UX Specification

This document converts the approved Aura Meetings Product Architecture into a screen-level UX/UI specification. It is implementation-ready and intentionally removes product ambiguity for design, frontend, backend, and QA.

It defines flows, layouts, hierarchies, controls, states, matrices, and failure behavior. It does not define code, data models, or implementation sequencing.

---

## 1. Complete Screen Flows

### 1.1 Availability Creation

Entry point:
- Institution Admin -> Booking Pages -> Availability Management

Actions:
- create availability window
- edit availability window
- delete availability window
- publish/save

Outcomes:
- availability is stored
- booking pages reflect the new schedule
- public booking slots update

Alternate paths:
- add exception
- change timezone
- update recurring pattern

Failure paths:
- validation error
- overlapping range
- save failure
- permission denied

Exit paths:
- back to booking page list
- back to institution meetings

### 1.2 Booking Page

Entry point:
- public URL
- institution booking URL

Actions:
- review identity
- inspect meeting details
- click Book a time

Outcomes:
- user enters slot selection

Alternate paths:
- open alternate booking page
- view host/institution details only

Failure paths:
- unavailable page
- invalid booking page

Exit paths:
- booking flow
- cancel/back

### 1.3 Booking Confirmation

Entry point:
- successful booking submission

Actions:
- confirm details
- copy link
- add to calendar
- proceed to join details

Outcomes:
- meeting is confirmed
- guest receives clear next-step information

Alternate paths:
- booking required confirmation email only

Failure paths:
- confirmation submit failure

Exit paths:
- guest dashboard or meeting link

### 1.4 Host Meetings Dashboard

Entry point:
- institution workspace -> Meetings
- member workspace -> Meetings if personal scope exists

Actions:
- inspect today
- inspect upcoming
- inspect past
- open detail
- start meeting
- enter room
- copy link
- create meeting
- join by code

Outcomes:
- host understands the day and acts immediately

Alternate paths:
- filter by status
- open missed meetings

Failure paths:
- loading failure
- empty state

Exit paths:
- meeting detail
- create meeting
- dashboard filters

### 1.5 Meeting Creation

Entry point:
- dashboard primary action
- booking page management

Actions:
- fill title
- choose date/time
- choose duration
- choose participants
- choose institution scope
- save or schedule

Outcomes:
- meeting appears in dashboard with lifecycle state

Alternate paths:
- draft
- instant meeting
- recurring meeting

Failure paths:
- validation failure
- schedule conflict

Exit paths:
- meeting detail
- dashboard

### 1.6 Meeting Detail

Entry point:
- dashboard card
- search/history
- booking source

Actions:
- review details
- start meeting
- enter room
- copy link
- cancel/reschedule
- review notes

Outcomes:
- host is prepared and can act

Alternate paths:
- missed review
- ended review

Failure paths:
- room unavailable
- meeting cancelled

Exit paths:
- host preparation workspace
- host room
- summary

### 1.7 Host Preparation Workspace

Entry point:
- meeting detail start/enter

Actions:
- review readiness
- inspect guest state
- enter room
- copy link

Outcomes:
- host moves into a stable waiting or live state

Alternate paths:
- retry if transport issue

Failure paths:
- connection issue

Exit paths:
- host waiting room
- live room

### 1.8 Host Waiting Room

Entry point:
- host enters before guest

Actions:
- wait
- invite manually
- copy link
- enter when guest arrives

Outcomes:
- host remains in the room without confusion

Alternate paths:
- host leaves temporarily

Failure paths:
- transport interruption

Exit paths:
- live room
- ended state

### 1.9 Host Live Room

Entry point:
- host enters active meeting

Actions:
- manage room
- monitor attendees
- mute/camera/share if available
- end meeting
- leave

Outcomes:
- conversation proceeds with stable control

Alternate paths:
- host only
- host + guest
- multiple devices

Failure paths:
- connection issue
- permission issue

Exit paths:
- ended
- summary

### 1.10 Guest Join Page

Entry point:
- invitation link
- booking confirmation link

Actions:
- review identity
- confirm name/email if required
- join
- wait

Outcomes:
- guest enters waiting room or live room

Alternate paths:
- guest early
- guest late
- invalid link

Failure paths:
- cancelled/ended meeting
- access denied

Exit paths:
- waiting room
- live room
- ended page

### 1.11 Guest Waiting Room

Entry point:
- guest arrives before host or before room opens

Actions:
- wait
- leave
- retry connection

Outcomes:
- guest stays informed and calm

Alternate paths:
- host arrives while guest waits

Failure paths:
- transport failure

Exit paths:
- live room
- ended

### 1.12 Guest Live Room

Entry point:
- guest joins active room

Actions:
- participate
- leave

Outcomes:
- guest shares same room as host

Alternate paths:
- guest on another device

Failure paths:
- disconnection

Exit paths:
- waiting
- ended

### 1.13 Meeting Ended

Entry point:
- explicit end
- expiration
- cancellation
- missed classification

Actions:
- review closure
- open summary

Outcomes:
- meeting ends cleanly and visibly

Alternate paths:
- summary available

Failure paths:
- loading closure details

Exit paths:
- dashboard
- detail
- summary

### 1.14 Meeting Summary

Entry point:
- ended meeting
- post-meeting panel

Actions:
- review attendance
- add decisions
- add commitments
- add actions

Outcomes:
- meeting becomes institutional record

Alternate paths:
- draft summary

Failure paths:
- save failure

Exit paths:
- post-meeting workspace
- dashboard

### 1.15 Post Meeting Workspace

Entry point:
- summary
- past meeting detail

Actions:
- manage follow-up
- revisit attendance
- revisit decisions

Outcomes:
- meeting remains active as memory and work context

Alternate paths:
- history lookup

Failure paths:
- permission failure

Exit paths:
- back to summary
- back to dashboard

---

## 2. Exact Screen Layouts

### 2.1 Availability Management

Desktop:
- Header: page title, publish/save, copy link
- Primary area: calendar, day picker, time windows
- Secondary area: rules, timezone, booking page identity
- Right rail: selected window editor, exceptions
- Bottom actions: save, cancel
- Navigation: back to booking pages, institution admin

Mobile:
- Top area: title, publish/save
- Content stack: calendar, windows, rules
- Primary actions: add, save
- Secondary actions: copy link, preview
- Bottom actions: sticky save bar

### 2.2 Booking Page

Desktop:
- Header: institution identity and top nav
- Primary area: meeting title, description, booking CTA
- Secondary area: host context and reassurance copy
- Right rail: summary card if needed
- Bottom actions: book a time
- Navigation: minimal public nav

Mobile:
- Top area: identity and title
- Content stack: description, host card, CTA
- Primary actions: book a time
- Secondary actions: learn more
- Bottom actions: sticky booking CTA if useful

### 2.3 Booking Confirmation

Desktop:
- Header: confirmation title
- Primary area: meeting summary and next step
- Secondary area: calendar/add link
- Right rail: join and reminder details
- Bottom actions: open join page, copy link
- Navigation: back to booking page or dashboard

Mobile:
- Top area: confirmation title
- Content stack: details, reminder, join link
- Primary actions: open join page
- Secondary actions: copy link, add to calendar
- Bottom actions: action buttons

### 2.4 Host Meetings Dashboard

Desktop:
- Header: Meetings, New Meeting, Join by Code, Copy Public Link
- Primary area: Today’s Meetings
- Secondary area: Upcoming Meetings
- Right rail: Booking Requests, quick stats if needed
- Bottom actions: dashboard-level actions
- Navigation: institution or member workspace nav

Mobile:
- Top area: title and actions
- Content stack: Today, Upcoming, Past, Requests
- Primary actions: start/enter/open details
- Secondary actions: copy link, create meeting
- Bottom actions: sticky primary action if appropriate

### 2.5 Meeting Creation

Desktop:
- Header: Meeting title, save
- Primary area: form
- Secondary area: preview summary
- Right rail: participant and schedule summary
- Bottom actions: schedule, save draft, cancel
- Navigation: back to dashboard

Mobile:
- Top area: title and save
- Content stack: form sections in order
- Primary actions: schedule/save
- Secondary actions: save draft
- Bottom actions: sticky submit

### 2.6 Meeting Detail

Desktop:
- Header: title, status badge, start/enter, copy link
- Primary area: summary card
- Secondary area: preparation notes and attendee details
- Right rail: source booking page and host context
- Bottom actions: cancel, reschedule, review missed
- Navigation: back to dashboard

Mobile:
- Top area: title and status
- Content stack: summary, attendees, source, notes
- Primary actions: start/enter
- Secondary actions: copy link, cancel
- Bottom actions: sticky primary action

### 2.7 Host Preparation Workspace

Desktop:
- Header: meeting title and status
- Primary area: readiness summary
- Secondary area: guest waiting indicator
- Right rail: notes and quick actions
- Bottom actions: enter room
- Navigation: back to detail

Mobile:
- Top area: title, status
- Content stack: readiness, guest state, notes
- Primary actions: enter room
- Secondary actions: copy link
- Bottom actions: sticky enter button

### 2.8 Host Waiting Room

Desktop:
- Header: meeting title, elapsed/scheduled time
- Primary area: calm waiting state
- Secondary area: participant list or waiting status
- Right rail: notes, participants, quick controls
- Bottom actions: end, leave, copy link
- Navigation: room only

Mobile:
- Top area: title and state
- Content stack: waiting message, participant state, notes
- Primary actions: wait / enter
- Secondary actions: copy link
- Bottom actions: control dock

### 2.9 Host Live Room

Desktop:
- Header: title, status, participant count, timer
- Primary area: meeting canvas
- Secondary area: participant list
- Right rail: notes, follow-up placeholder, controls
- Bottom actions: mute, camera, share placeholder, end, leave
- Navigation: room only

Mobile:
- Top area: title and timer
- Content stack: canvas, participant summary, notes
- Primary actions: end or leave
- Secondary actions: controls
- Bottom actions: persistent control dock

### 2.10 Guest Join Page

Desktop:
- Header: host/institution identity
- Primary area: meeting title, time, join card
- Secondary area: description and trust signals
- Right rail: guest identity entry if required
- Bottom actions: join, wait, leave
- Navigation: public only

Mobile:
- Top area: identity and title
- Content stack: time, identity confirmation, join action
- Primary actions: join
- Secondary actions: leave, copy info
- Bottom actions: sticky join button

### 2.11 Guest Waiting Room

Desktop:
- Header: “You’re in the right place”
- Primary area: waiting message
- Secondary area: host/institution/time
- Right rail: leave/retry
- Bottom actions: leave, retry
- Navigation: public only

Mobile:
- Top area: confirmation headline
- Content stack: waiting state, meeting details
- Primary actions: retry
- Secondary actions: leave
- Bottom actions: persistent leave/retry

### 2.12 Guest Live Room

Desktop:
- Header: meeting title and status
- Primary area: meeting canvas
- Secondary area: minimal identity/context
- Right rail: minimal controls only
- Bottom actions: mute, camera, leave
- Navigation: room only

Mobile:
- Top area: title and status
- Content stack: canvas, minimal controls
- Primary actions: leave
- Secondary actions: mute/camera
- Bottom actions: control dock

### 2.13 Meeting Ended

Desktop:
- Header: ended status
- Primary area: meeting closure
- Secondary area: summary or next steps
- Right rail: history
- Bottom actions: dashboard, summary
- Navigation: back to detail/dashboard

Mobile:
- Top area: ended headline
- Content stack: closure, summary, next steps
- Primary actions: view summary
- Secondary actions: dashboard
- Bottom actions: action buttons

### 2.14 Meeting Summary

Desktop:
- Header: meeting title and summary status
- Primary area: summary editor/view
- Secondary area: attendance, decisions
- Right rail: commitments, follow-ups
- Bottom actions: save, publish/share
- Navigation: back to ended/detail

Mobile:
- Top area: title and summary status
- Content stack: attendance, decisions, commitments, actions
- Primary actions: save
- Secondary actions: publish/share
- Bottom actions: sticky save bar

### 2.15 Post Meeting Workspace

Desktop:
- Header: meeting title, date, status
- Primary area: summary and actions
- Secondary area: follow-ups and continuity
- Right rail: attendance and history
- Bottom actions: save, assign, revisit
- Navigation: back to dashboard

Mobile:
- Top area: title and status
- Content stack: summary, follow-ups, history
- Primary actions: assign or save
- Secondary actions: revisit
- Bottom actions: sticky action bar

---

## 3. Information Hierarchy

### Availability Management

Priority 1:
- schedule rules
- timezone
- active windows

Priority 2:
- exceptions
- booking page identity

Priority 3:
- preview and low-importance metadata

Never show first:
- internal IDs
- transport terms

### Booking Page

Priority 1:
- institution identity
- host identity
- meeting title
- meeting description

Priority 2:
- availability summary
- reassurance

Priority 3:
- technical details if any

### Booking Confirmation

Priority 1:
- booked meeting time
- host
- institution

Priority 2:
- join link
- calendar reminder

Priority 3:
- secondary references

### Host Meetings Dashboard

Priority 1:
- today’s meetings
- current status
- primary action

Priority 2:
- upcoming meetings
- booking requests

Priority 3:
- past meetings and metadata

### Meeting Creation

Priority 1:
- title
- time
- duration

Priority 2:
- participants
- institution scope

Priority 3:
- draft or advanced options

### Meeting Detail

Priority 1:
- status
- time
- guest
- host/institution

Priority 2:
- join link
- notes
- attendance

Priority 3:
- source page and supporting metadata

### Host Preparation Workspace

Priority 1:
- readiness state
- action to enter

Priority 2:
- guest status
- notes

Priority 3:
- auxiliary controls

### Host Waiting Room

Priority 1:
- waiting state
- meeting identity

Priority 2:
- guest status
- participant list

Priority 3:
- notes and extra controls

### Host Live Room

Priority 1:
- meeting identity
- live state
- participants

Priority 2:
- controls
- notes/follow-up

Priority 3:
- secondary diagnostics if healthy and helpful

### Guest Join Page

Priority 1:
- meeting title
- host
- institution
- scheduled time

Priority 2:
- identity confirmation
- join action

Priority 3:
- description and additional context

### Guest Waiting Room

Priority 1:
- “You’re in the right place”
- waiting state

Priority 2:
- host/institution/time

Priority 3:
- recovery details if needed

### Guest Live Room

Priority 1:
- meeting identity
- live state

Priority 2:
- minimal controls

Priority 3:
- extra metadata if needed

### Meeting Ended

Priority 1:
- ended state
- closure reason

Priority 2:
- summary or next step

Priority 3:
- history

### Meeting Summary

Priority 1:
- attendance
- decisions
- commitments

Priority 2:
- actions
- follow-ups

Priority 3:
- supplemental history

### Post Meeting Workspace

Priority 1:
- summary
- actions
- continuity

Priority 2:
- attendance
- decisions

Priority 3:
- archival metadata

---

## 4. Meeting Creation Specification

### Instant Meeting

Definition:
- a meeting created for immediate entry

Required fields:
- title
- host
- duration
- ownership scope

Optional fields:
- description
- guest
- institution
- notes

Defaults:
- immediate start
- host scope defaulted from workspace

Validation:
- title required
- duration required

Confirmation flow:
- show meeting created
- offer enter room
- offer copy link

Resulting lifecycle state:
- Preparing or In Meeting, depending on entry

### Scheduled Meeting

Definition:
- a meeting with explicit date/time

Required fields:
- title
- scheduled time
- timezone
- duration
- host

Optional fields:
- description
- guest
- institution
- notes

Defaults:
- timezone derived from user or institution
- duration from meeting type

Validation:
- time required
- timezone required
- duration required

Confirmation flow:
- show schedule summary
- show join link
- show reminder context

Resulting lifecycle state:
- Scheduled

### Recurring Meeting

Definition:
- a meeting series with repeated occurrences

Required fields:
- title
- recurrence rule
- timezone
- duration
- host

Optional fields:
- exceptions
- series description

Defaults:
- weekly if configured

Validation:
- recurrence rule valid
- no conflicting times

Confirmation flow:
- show series summary and first occurrence

Resulting lifecycle state:
- Scheduled for upcoming occurrence

### Institution Meeting

Definition:
- meeting owned by an institution workspace

Required fields:
- title
- institution
- host
- schedule or instant mode

Optional fields:
- department/context
- source booking page

Validation:
- host must belong to institution scope

Resulting lifecycle state:
- aligned with institution ownership

### Personal Meeting

Definition:
- meeting owned by a user rather than an institution

Required fields:
- title
- host

Optional fields:
- description
- guests

Validation:
- host ownership required

Resulting lifecycle state:
- personal meeting lifecycle

---

## 5. Attendance Model

Attendance is a user-facing and reportable concept.

### States

#### Invited
Meaning:
- participant was invited but has not responded

Trigger:
- invitation sent

Visibility:
- dashboard, detail, summary

Host view:
- invited but not confirmed

Guest view:
- invitation received

Reporting:
- counts as invited, not attended

#### Accepted
Meaning:
- participant acknowledged or confirmed attendance intent

Trigger:
- booking, RSVP, or explicit confirmation

Visibility:
- detail, summary

Host view:
- invitation accepted

Guest view:
- confirmed

Reporting:
- counts toward confirmed attendance intent

#### Declined
Meaning:
- participant cannot attend

Trigger:
- explicit decline

Visibility:
- detail, summary

Host view:
- declined

Guest view:
- declined successfully

Reporting:
- separate from no-show

#### Confirmed
Meaning:
- meeting is booked and expected

Trigger:
- booking success or explicit confirmation

Visibility:
- dashboard, detail, confirmation page

Host view:
- meeting is on calendar

Guest view:
- meeting booked

Reporting:
- expected attendance

#### Waiting
Meaning:
- participant has arrived but meeting is not yet fully started

Trigger:
- room entered early

Visibility:
- waiting room, room state

Host view:
- waiting for guest or host

Guest view:
- waiting for host

Reporting:
- indicates presence before meeting start

#### Joined
Meaning:
- participant is actively in the room

Trigger:
- room entry

Visibility:
- room, attendance, summary

Host view:
- participant present

Guest view:
- participant present

Reporting:
- counts as attendance

#### Left
Meaning:
- participant left the room

Trigger:
- leave action or disconnect

Visibility:
- room, history, summary

Host view:
- participant left

Guest view:
- left the room

Reporting:
- departure event, not necessarily failure

#### Rejoined
Meaning:
- participant returned after leaving

Trigger:
- re-entry

Visibility:
- room, attendance history

Host view:
- participant returned

Guest view:
- returned to meeting

Reporting:
- sequence preserved

#### No-show
Meaning:
- participant did not attend by meeting end

Trigger:
- meeting ends without attendance or participation

Visibility:
- summary, past meetings

Host view:
- no-show flag

Guest view:
- not typically shown unless relevant

Reporting:
- counts as missed attendance

#### Completed
Meaning:
- meeting finished and closed

Trigger:
- explicit end or valid closure

Visibility:
- ended page, summary, history

Host view:
- completed

Guest view:
- completed

Reporting:
- final attended/left/summary data preserved

---

## 6. Host Control Specification

### Start Meeting
Purpose:
- open the meeting when the host is ready

Visibility:
- meeting detail, preparation workspace, dashboard

Required state:
- scheduled, starting soon, waiting, connection issue

Permissions:
- host or authorized admin

Expected behavior:
- opens or reopens the room without losing meeting identity

### Enter Room
Purpose:
- join an already active or waiting meeting

Visibility:
- room-capable states

Required state:
- waiting, in progress, connection issue, starting soon

Permissions:
- host or permitted participant

Expected behavior:
- enters the room shell

### End Meeting
Purpose:
- close the meeting intentionally

Visibility:
- live room, host room, detail if supported

Required state:
- live or waiting

Permissions:
- host or admin

Expected behavior:
- marks meeting ended and preserves summary/history

### Leave Room
Purpose:
- exit the room without ending the meeting

Visibility:
- room

Required state:
- any live/waiting room

Permissions:
- current participant

Expected behavior:
- participant leaves, meeting may continue

### Copy Link
Purpose:
- share the meeting or booking link

Visibility:
- dashboard, detail, room, booking confirmation

Required state:
- any shareable meeting

Permissions:
- host or guest depending on context

Expected behavior:
- link copied to clipboard

### Invite Participant
Purpose:
- add or notify another participant

Visibility:
- host room, detail if supported

Required state:
- meeting active or scheduled

Permissions:
- host or admin

Expected behavior:
- invite sent without changing meeting state

### Participant Visibility
Purpose:
- show who is present and who is waiting

Visibility:
- room, detail, summary

Required state:
- any meeting with participants

Permissions:
- host always; guest limited to allowed view

Expected behavior:
- identities and statuses visible

### Waiting Participant Visibility
Purpose:
- show who is waiting before live entry

Visibility:
- host room and detail

Required state:
- waiting state

Permissions:
- host or admin

Expected behavior:
- host sees waiting people, guest sees waiting status

### Mute Controls
Purpose:
- control audio presence

Visibility:
- live room

Required state:
- live or waiting room if supported

Permissions:
- participant controlling self

Expected behavior:
- toggle mic state

### Camera Controls
Purpose:
- control video presence

Visibility:
- live room

Required state:
- live or pre-join if supported

Permissions:
- participant controlling self

Expected behavior:
- toggle camera state

### Screen Share Placeholder
Purpose:
- future support for presentation

Visibility:
- host live room, maybe guest room if allowed

Required state:
- live meeting

Permissions:
- host only unless explicitly allowed

Expected behavior:
- UI placeholder if not fully implemented

### Room Locking
Purpose:
- control whether new participants can enter

Visibility:
- host room only

Required state:
- live or waiting

Permissions:
- host or admin

Expected behavior:
- locked room blocks new entries

### Participant Removal
Purpose:
- remove a participant from the room

Visibility:
- host room

Required state:
- live room

Permissions:
- host or admin

Expected behavior:
- participant leaves and is informed

### Transfer Ownership
Purpose:
- move host control to another participant if supported

Visibility:
- host room only

Required state:
- live meeting

Permissions:
- host or admin

Expected behavior:
- ownership transfers without corrupting the meeting

---

## 7. Guest Control Specification

### Join
Purpose:
- enter the meeting

Visibility:
- join page, waiting room

Expected behavior:
- guest enters waiting or live room based on state

Permissions:
- guest or invited participant

### Wait
Purpose:
- remain in a valid state while host is absent

Visibility:
- waiting room

Expected behavior:
- guest sees reassurance, not failure

Permissions:
- guest

### Leave
Purpose:
- exit the room or waiting state

Visibility:
- join/wait/live

Expected behavior:
- guest can leave without affecting meeting lifecycle unless explicitly allowed

Permissions:
- guest

### Retry Connection
Purpose:
- re-establish a session after a transport issue

Visibility:
- waiting or failure recovery

Expected behavior:
- reconnect without losing context

Permissions:
- guest

### Mute
Purpose:
- control audio input

Visibility:
- live room

Expected behavior:
- mic toggles locally

Permissions:
- guest self-control

### Camera
Purpose:
- control video input

Visibility:
- live room

Expected behavior:
- camera toggles locally

Permissions:
- guest self-control

### Identity Confirmation
Purpose:
- confirm who the guest is

Visibility:
- join page

Expected behavior:
- guest can provide name/email if needed

Permissions:
- guest

---

## 8. Waiting Room Specification

### Host waiting room

What host sees:
- meeting title
- status
- time
- guest waiting indicator if relevant
- controls
- notes/context

What host does not see:
- guest-private controls
- transport internals

### Guest waiting room

What guest sees:
- “You’re in the right place”
- meeting title
- host/institution
- time
- waiting status
- leave option

What guest does not see:
- host admin controls
- internal transport details
- workspace navigation

### When host arrives first
- host enters waiting room
- guest sees meeting as waiting or ready to join

### When guest arrives first
- guest enters waiting room
- host sees guest waiting if the room is open

### When both arrive
- room transitions to active/live

### When transport fails
- waiting state remains visible if meeting is still valid
- recovery is offered inline

### When meeting expires
- waiting state resolves to ended or missed depending on attendance

### When meeting is cancelled
- waiting room becomes cancelled/ended state

---

## 9. Room Behavior Specification

### Host only
- room remains valid
- host waits or begins preparation
- no failure state just because guest is absent

### Guest only
- room remains valid
- guest waits
- no dead end if host is late

### Host + guest
- room is active
- controls are available according to role

### Host leaves temporarily
- if meeting remains active, room remains valid
- guests may wait or remain connected depending on transport state

### Guest leaves temporarily
- host stays in room
- guest can rejoin if meeting remains valid

### Transport interruption
- room context remains visible
- recovery option appears
- meeting does not disappear

### Multiple devices
- participant presence is normalized
- room ownership and active view are kept clear

### Meeting end
- meeting transitions to ended/completed
- live controls stop

### Cancellation
- room becomes cancelled state
- no active meeting room should persist as if live

### Expiration
- meeting transitions to missed or ended according to lifecycle rules

---

## 10. Post-Meeting UX

### Meeting Summary

Who creates it:
- host first, optionally collaborators

When it appears:
- during concluding or after the meeting ends

Where it appears:
- summary screen
- meeting detail
- post-meeting workspace

How it connects:
- becomes the main record of what happened

### Decisions

Who creates it:
- host, note taker, admin if allowed

When it appears:
- during the meeting or immediately after

Where it appears:
- summary
- post-meeting workspace

How it connects:
- used as the authoritative list of outcomes

### Commitments

Who creates it:
- host or assigned collaborator

When it appears:
- during or after the meeting

Where it appears:
- summary
- follow-up workspace

How it connects:
- turns meeting talk into obligations

### Actions

Who creates it:
- host or collaborators

When it appears:
- after the meeting or during wrap-up

Where it appears:
- summary
- workspace task surfaces if integrated

How it connects:
- feeds follow-up and accountability

### Issues

Who creates it:
- host or reviewer

When it appears:
- after meeting or during summary

Where it appears:
- summary
- post-meeting workspace

How it connects:
- tracks unresolved concerns

### Follow-Ups

Who creates it:
- host, admin, or collaborators

When it appears:
- after the meeting ends

Where it appears:
- summary
- workspace follow-up surfaces

How it connects:
- drives future work and reminders

### Attendance

Who creates it:
- system plus host confirmation if needed

When it appears:
- during and after the room

Where it appears:
- detail
- summary
- history

How it connects:
- shows who attended, who left, and who no-showed

### Continuity

Who creates it:
- system and host workflow

When it appears:
- after meeting closure

Where it appears:
- post-meeting workspace
- institutional history

How it connects:
- keeps the meeting alive as useful context

### Institution memory

Who creates it:
- system via saved meeting record

When it appears:
- immediately after the meeting and later on demand

Where it appears:
- dashboard history
- meeting detail
- workspace memory surfaces

How it connects:
- preserves the meeting as part of institutional knowledge

---

## 11. Visual System

### Meeting cards
- compact, readable, action-forward
- title first, status second
- guest and time immediately visible
- primary action obvious

### Status badges
- use concise lifecycle labels
- avoid technical language
- must be consistent across screens

### Action buttons
- one primary action per screen section
- secondary actions visually subordinate
- destructive actions distinct

### Navigation patterns
- host navigation stays workspace-aware
- guest navigation stays public and minimal
- room navigation stays inside the meeting context

### Room layouts
- stable title/status top bar
- clear central meeting area
- side panel or lower panel for people/notes/controls

### Summary layouts
- summary first
- attendance next
- decisions and commitments after that

### Desktop principles
- use two-column or three-zone layouts where helpful
- keep the main action visible
- avoid hiding the meeting state below the fold

### Mobile principles
- use stacked sections
- keep primary action sticky when needed
- keep titles and status visible

### Spacing philosophy
- calm density
- enough whitespace for trust
- no cramped record-like tables for primary experience

### Institution identity presentation
- show institution name and branding early on public pages and meeting detail

### Host identity presentation
- show host name and role clearly

### Guest identity presentation
- show guest identity when relevant and appropriate

---

## 12. State Matrix

Legend:
- D = Dashboard
- Det = Detail
- Prep = Preparation
- Wait = Waiting
- Room = Live Room
- End = Ended
- Sum = Summary

| Lifecycle State | Dashboard | Detail | Prep | Wait | Room | End | Sum |
|---|---|---|---|---|---|---|---|
| Invited | invitation/request | info only | no | no | no | no | no |
| Scheduled | scheduled card | scheduled summary | prepare CTA | no | no | no | no |
| Confirmed | confirmed card | confirmed summary | prepare CTA | possible | no | no | no |
| Preparing | upcoming/today | preparation card | active | maybe | no | no | no |
| Arriving | upcoming/today | arrival card | active | possible | no | no | no |
| Waiting | waiting card | waiting summary | enter CTA | visible | visible | no | no |
| In Meeting | live card | live summary | enter CTA | visible if needed | visible | no | no |
| Concluding | ending card | concluding summary | no | no | visible/closing | yes | yes |
| Follow-Up | past card | post-meeting detail | no | no | no | yes | yes |
| Completed | past card | completed summary | no | no | no | yes | yes |
| Missed | missed card | missed summary | review missed | no | no | yes | yes |
| Cancelled | cancelled card | cancelled summary | no | no | no | yes | no |
| Connection Issue | issue card | issue detail | retry CTA | retry visible | retry visible | maybe | maybe |

Rules:
- Dashboard must never show a live state for a clearly expired meeting.
- Detail must always match dashboard lifecycle.
- Wait and Room can coexist only when the room is open but not fully active.
- End and Sum should preserve historical access.

---

## 13. Failure Matrix

| Scenario | User Sees | Available Actions | Recovery Path | Final State |
|---|---|---|---|---|
| Connection issue | meeting identity + issue message | retry, leave, copy link | retry transport or re-enter | connection issue or active |
| Host absent | waiting room | wait, leave, retry | host joins later | waiting -> live or expired |
| Guest absent | host waiting room | wait, invite, leave | guest joins later | waiting -> live or missed |
| Meeting expired | ended/missed state | view summary, return | no active join unless rescheduled | missed/completed |
| Meeting cancelled | cancelled state | view details, exit | none; use reschedule if available | cancelled |
| No-show | missed state | review missed, archive | follow-up or reschedule | missed |
| Rejoin | room with existing context | re-enter, wait, leave | reconnect to same meeting | same lifecycle state |
| Transport failure | same meeting shell + issue | retry, leave, copy link | re-establish transport | connection issue or active |
| Permission issue | access denied or restricted state | request access, exit | correct permissions, reopen | restricted or active |
| Invalid link | not found / invalid link | go back, open correct link | use valid booking or join URL | no active meeting |

Rules:
- failure must preserve meeting identity when possible
- failure must not default to generic call language
- failure must not hide the next action

---

## 14. Implementation Readiness Review

### Can a frontend engineer build every screen?
Yes, if the screen contracts above are followed exactly.

### Can a backend engineer build every lifecycle?
Yes, because the lifecycle states, transitions, and failure rules are explicit.

### Can QA test every state?
Yes, because the state matrix and failure matrix define expected behavior.

### Can design create mockups without asking questions?
Yes, because layouts, hierarchy, and visual principles are specified.

### If any answer were no
This document would be incomplete.

It is intended to be complete.

---

## Final Acceptance

This UX specification is complete when:

- every screen has a defined purpose
- every screen has explicit layout
- every screen has explicit hierarchy
- every screen has explicit actions
- every lifecycle state has a visible meaning
- every failure path has a recovery path
- host, guest, and admin journeys are fully defined
- post-meeting continuity is part of the product

Aura Meetings is now specified at the level required for implementation to begin immediately afterward.
