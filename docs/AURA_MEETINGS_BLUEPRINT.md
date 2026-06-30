# Aura Meetings Product Architecture

## Scope

This document is the implementation-ready product architecture for Aura Meetings.

It defines:
- product identity
- complete user journeys
- complete screen architecture
- information architecture
- lifecycle rules
- booking architecture
- room architecture
- post-meeting architecture
- Aura differentiation
- visual experience system
- parity audit
- implementation requirements
- acceptance tests

It does not include code, mockups, or patch instructions.

---

## 1. Product Identity

### What Aura Meetings is

Aura Meetings is the institutional meeting platform inside Aura. It lets organizations create availability, publish booking pages, receive requests, confirm meetings, host live rooms, and retain outcomes after the meeting ends.

It is a full meeting product, not a call screen and not a booking widget.

### What it is not

- Not a prototype
- Not a transport layer exposed as a product
- Not a call system with meeting labels
- Not a spreadsheet of booked slots
- Not a temporary workaround for live video

### Why it exists

Aura Meetings exists so institutions can manage real conversations with identity, scheduling, continuity, and accountability in one place.

It solves the gap between:
- scheduling tools that stop at booking
- meeting tools that stop at live video
- workflow tools that do not own the conversation itself

### Who it serves

- Institutional hosts and administrators
- Commercial teams and client-facing operators
- Professional users such as founders, investors, advisors, and executives
- Public-sector users who need identity, accountability, and continuity
- Guests who need a simple, trustworthy join experience without workspace complexity

### What makes it different

Aura Meetings combines:
- institutional ownership
- verified identity
- public and private booking
- waiting-room confidence
- post-meeting continuity
- attendance and accountability
- follow-up persistence

### Exact experience promise

First-time users should feel:

> This is a mature meeting platform where I can schedule, join, wait, conduct, and close a meeting with trust and context intact.

---

## 2. Complete User Journeys

### Host journey

#### 1. Create availability
Host intent:
- define when they can meet
- control public or institution booking access
- present availability professionally

Host actions:
- choose days and hours
- set duration and timezone
- publish or update booking page
- copy public link

Host decisions:
- which days are open
- whether booking is public or institution-owned
- what meeting type is offered

Host state:
- preparing availability
- validating booking setup
- confident that the page is ready

#### 2. Booking page exists
Host intent:
- verify the page looks correct
- understand what guests will see

Host actions:
- review title, description, host identity, institution identity
- verify meeting duration and time options

#### 3. Booking request arrives
Host intent:
- understand who booked and why
- know if action is needed

Host actions:
- review guest name/email
- review note or reason
- accept the meeting as scheduled context

#### 4. Meeting appears on dashboard
Host intent:
- see today, upcoming, and past meetings

Host actions:
- open meeting detail
- start or enter the room
- copy link
- cancel or reschedule if available

#### 5. Meeting detail review
Host intent:
- prepare for the conversation

Host actions:
- read meeting title and purpose
- review guest identity
- check scheduled time and timezone
- review source booking page
- prepare notes or agenda

#### 6. Host preparation workspace
Host intent:
- get ready before entering live

Host actions:
- review room readiness
- check time remaining
- copy link
- enter the room

#### 7. Host waiting room
Host intent:
- wait without wondering whether something is broken

Host actions:
- remain in room
- watch guest state
- copy link or invite manually

Host state:
- waiting
- calm
- stable

#### 8. Host live room
Host intent:
- conduct the meeting

Host actions:
- manage presence
- see attendance
- use room controls
- end the meeting explicitly when finished

#### 9. Post-meeting completion
Host intent:
- capture what happened

Host actions:
- review attendance
- add summary
- record decisions
- add commitments
- create follow-ups

#### 10. Follow-up recorded
Host intent:
- convert the meeting into durable institutional memory

Host actions:
- confirm next steps
- share summary if needed
- revisit the meeting later

### Guest journey

#### 1. Invitation received
Guest intent:
- understand what the meeting is
- know who it is with
- trust the link

Guest questions:
- Who invited me?
- Why am I invited?
- When is this meeting?
- Do I need an account?

#### 2. Public join page
Guest intent:
- confirm they are in the right place

Guest actions:
- review host identity
- review institution identity
- review title and schedule
- enter name/email if required
- choose to join or wait

#### 3. Guest waiting
Guest intent:
- remain confident while early or while host is absent

Guest actions:
- wait
- leave
- retry if transport fails

#### 4. Guest live room
Guest intent:
- participate without friction

Guest actions:
- join the room
- use minimal controls
- follow host cues

#### 5. Guest ended page
Guest intent:
- understand closure

Guest actions:
- review ending state
- note next steps if any

### Admin journey

Admin intent:
- manage meeting availability, booking access, and institutional control

Admin actions:
- create or edit booking pages
- manage availability
- review hosted meetings
- oversee meeting history and accountability

---

## 3. Complete Screen Architecture

### 3.1 Availability Management

Purpose:
- configure booking windows and meeting availability

Audience:
- host, admin

Information hierarchy:
1. Availability calendar and rules
2. Booking page identity
3. Existing windows and exceptions
4. Publish/save actions

Primary actions:
- add availability
- edit availability
- delete availability
- publish changes

Secondary actions:
- copy booking link
- preview public page

Success state:
- availability is saved and reflected in booking pages

Failure state:
- validation error, save failure, or permission failure with clear guidance

Desktop layout:
- left: calendar/rules
- right: selected windows and booking page context

Mobile layout:
- stacked sections with fixed action bar

### 3.2 Booking Page

Purpose:
- present the public or institution-specific meeting offer

Audience:
- guest, visitor

Information hierarchy:
1. Host/institution identity
2. Meeting title and description
3. Availability summary
4. Call to action

Primary actions:
- book a time

Secondary actions:
- learn more
- inspect meeting details

Success state:
- guest chooses a meeting and proceeds to slot selection

Failure state:
- unavailable page, clear recovery path, no dead end

Desktop layout:
- summary-led page with obvious booking CTA

Mobile layout:
- identity, title, description, CTA stacked

### 3.3 Booking Confirmation

Purpose:
- reassure guest that booking succeeded

Audience:
- guest

Information hierarchy:
1. Meeting confirmation
2. Date/time/timezone
3. Host and institution identity
4. Join details and reminders

Primary actions:
- add to calendar
- open join page

Secondary actions:
- copy meeting link
- review details

Success state:
- guest knows the meeting is booked and what happens next

Failure state:
- confirmation error with retry guidance

Desktop layout:
- centered confirmation summary

Mobile layout:
- stacked confirmation card

### 3.4 Host Meetings Dashboard

Purpose:
- operate the host’s meeting day

Audience:
- host, admin

Information hierarchy:
1. Today’s meetings
2. Upcoming meetings
3. Missed or past meetings
4. Booking requests received

Primary actions:
- start
- enter
- view details

Secondary actions:
- copy link
- create meeting
- join by code

Success state:
- host can understand the day in seconds

Failure state:
- loading, empty, or error states without ambiguity

Desktop layout:
- dashboard sections with meeting cards

Mobile layout:
- stacked operational list with compact actions

### 3.5 Meeting Creation

Purpose:
- schedule or create a meeting directly

Audience:
- host, admin

Information hierarchy:
1. Title and purpose
2. Participants
3. Date/time and timezone
4. Duration and meeting type
5. Ownership

Primary actions:
- create
- schedule

Secondary actions:
- cancel
- save draft

Success state:
- meeting appears in dashboard with clear status

Failure state:
- validation and conflict errors

Desktop layout:
- form-led with preview summary

Mobile layout:
- stepwise form

### 3.6 Meeting Detail

Purpose:
- preparation, control, and reference

Audience:
- host, admin

Information hierarchy:
1. Title and status
2. Scheduled time
3. Guest identity
4. Host/institution identity
5. Join link
6. Notes, attendance, and source booking page

Primary actions:
- start meeting
- enter room
- copy link

Secondary actions:
- cancel
- reschedule
- review missed

Success state:
- host understands what this meeting is and what to do next

Failure state:
- meeting unavailable or ended with clear history remaining

Desktop layout:
- top summary card + preparation + attendance + source sections

Mobile layout:
- stacked summary, actions, context, notes

### 3.7 Host Preparation Workspace

Purpose:
- let the host get ready before the meeting goes live

Audience:
- host

Information hierarchy:
1. Meeting identity
2. Time remaining
3. Guest waiting status
4. Entry control

Primary actions:
- enter room

Secondary actions:
- copy link
- review notes

Success state:
- host can enter confidently

Failure state:
- connection issue shown without losing meeting identity

Desktop layout:
- preparation summary with concise controls

Mobile layout:
- compact readiness card

### 3.8 Host Waiting Room

Purpose:
- let the host wait in a calm, controlled state

Audience:
- host

Information hierarchy:
1. Meeting identity
2. Waiting status
3. Guest status
4. Room controls

Primary actions:
- remain in room
- enter when ready

Secondary actions:
- copy link
- invite guest manually

Success state:
- host remains in the meeting without confusion

Failure state:
- connection issue with retry inside the same meeting context

Desktop layout:
- room shell with waiting state

Mobile layout:
- vertical room shell with clear action stack

### 3.9 Host Live Room

Purpose:
- conduct the meeting

Audience:
- host

Information hierarchy:
1. Meeting identity
2. Live state
3. Participant count/list
4. Controls
5. Notes/follow-up context

Primary actions:
- end meeting
- manage room

Secondary actions:
- copy link
- leave

Success state:
- meeting runs with clear room control

Failure state:
- room stays visible with recovery, not a dead-end screen

Desktop layout:
- room canvas plus side panel

Mobile layout:
- vertical meeting canvas and control dock

### 3.10 Guest Join Page

Purpose:
- let the guest confirm the meeting and enter or wait

Audience:
- guest

Information hierarchy:
1. Host/institution identity
2. Meeting title
3. Scheduled time and timezone
4. Guest identity confirmation
5. Join/wait action

Primary actions:
- join
- wait

Secondary actions:
- leave
- copy info

Success state:
- guest knows they are in the right place

Failure state:
- meeting not found, cancelled, or ended with a clear message

Desktop layout:
- centered confirmation + action flow

Mobile layout:
- single-column join card

### 3.11 Guest Waiting Room

Purpose:
- reassure the guest while waiting

Audience:
- guest

Information hierarchy:
1. Right place confirmation
2. Host/institution identity
3. Meeting time
4. Waiting state
5. Leave/retry

Primary actions:
- stay
- leave
- retry

Success state:
- guest remains calm and informed

Failure state:
- connection issue stays within meeting identity

### 3.12 Guest Live Room

Purpose:
- allow the guest to participate

Audience:
- guest

Information hierarchy:
1. Meeting identity
2. Live status
3. Minimal controls

Primary actions:
- participate
- leave

Success state:
- guest is in the same room as the host when appropriate

Failure state:
- connection recovery without losing context

### 3.13 Meeting Ended

Purpose:
- close the meeting professionally

Audience:
- host, guest

Information hierarchy:
1. Meeting title
2. Status and end reason
3. Summary or next steps
4. History

Primary actions:
- review summary
- return to dashboard

Success state:
- the meeting feels complete, not broken

Failure state:
- none should be needed beyond retries for loading summary

### 3.14 Meeting Summary

Purpose:
- capture outcome

Audience:
- host, admin

Information hierarchy:
1. Attendance
2. Decisions
3. Commitments
4. Actions
5. Follow-up items

Primary actions:
- edit summary
- save follow-up

Success state:
- meeting becomes usable memory

Failure state:
- draft preserved

### 3.15 Post Meeting Workspace

Purpose:
- continue the meeting in institutional memory

Audience:
- host, admin, possibly collaborators

Information hierarchy:
1. Summary
2. Action items
3. Commitments
4. Continuity references

Primary actions:
- assign follow-up
- review history

Success state:
- the meeting drives real work afterward

Failure state:
- none beyond loading and permission handling

---

## 4. Information Architecture

### Rules

- Show what helps the next decision.
- Hide technical internals.
- Keep status and identity visible everywhere.
- Never make the user infer the meeting state from transport state.

### Priority order by screen

#### Availability Management
1. Booking page identity
2. Availability schedule
3. Exceptions and publishing

Never show:
- transport state
- session IDs
- implementation vocabulary

#### Booking Page
1. Institution identity
2. Host identity
3. Meeting title and description
4. Schedule/availability
5. Booking CTA

#### Host Meetings Dashboard
1. Today’s meetings
2. Upcoming meetings
3. Past/missed meetings
4. Booking requests

#### Meeting Detail
1. Status
2. Time
3. Guest
4. Host/institution
5. Actions
6. Notes and history

#### Host Room
1. Meeting identity
2. Live/waiting status
3. Participant state
4. Controls
5. Notes/follow-up

#### Guest Join Page
1. Meeting identity
2. Host/institution
3. Scheduled time
4. Identity confirmation
5. Join or wait

#### Guest Waiting Room
1. Right place confirmation
2. Waiting status
3. Time
4. Leave/retry

#### Ended / Summary
1. Outcome
2. Attendance
3. Next steps

### What should never appear

- call-ended wording for scheduled meetings
- controller/bridge/session terminology
- endpoint or payload language
- internal route ownership language
- raw lifecycle strings not meant for users

---

## 5. Meeting Lifecycle

The same lifecycle must drive every screen.

### States

- Invited
- Scheduled
- Confirmed
- Preparing
- Arriving
- Waiting
- In Meeting
- Concluding
- Follow-Up
- Completed
- Missed
- Cancelled
- Connection Issue

### State meanings

- Invited: meeting offer sent or discovered
- Scheduled: meeting exists with date/time
- Confirmed: guest has accepted or booking is locked in
- Preparing: host is getting ready
- Arriving: guest is on the way or opening the link
- Waiting: one party is present and waiting for the other
- In Meeting: both sides are actively in the room
- Concluding: meeting is ending intentionally
- Follow-Up: summary or actions are being prepared
- Completed: meeting closed with history preserved
- Missed: time passed without meaningful attendance
- Cancelled: meeting was intentionally cancelled
- Connection Issue: meeting remains valid but transport is degraded

### Ownership

Lifecycle is owned by the meeting itself, not by the transport session.

### Visibility

The lifecycle must be represented consistently on:
- dashboard
- detail
- room
- guest join
- waiting room
- ended state
- fallback state

### Timing rules

- Before scheduled start: Scheduled or Preparing or Arriving
- Near start time: Starting soon / Preparing / Arriving
- During scheduled window: Waiting or In Meeting
- After scheduled end: Completed or Missed depending on meaningful activity

### Expiration rules

- A meeting should not remain live indefinitely.
- If time has passed without meaningful participation, classify it as Missed.
- If it has been intentionally ended, classify it as Completed or Ended.

### Cancellation rules

- Cancellation is explicit and terminal.
- Every surface should reflect it clearly.

### Reschedule rules

- Rescheduling preserves identity and history.
- Reschedule is not deletion.

### No-show rules

- If no meaningful meeting occurred by the end of the scheduled window, classify as Missed.

### Waiting rules

- Waiting is a valid state.
- Waiting is not failure.

### Host-late rules

- Guest can wait.
- Meeting remains valid.

### Guest-late rules

- Host can wait.
- Meeting remains valid.

### Transport-failure rules

- Transport failure does not erase the meeting.
- Transport failure should produce Connection Issue if the meeting still exists.
- Recovery should be possible without losing context.

---

## 6. Booking Architecture

### Availability

Availability defines when hosts can accept meetings.

Requirements:
- timezone-aware
- editable by host/admin
- institution-scoped if necessary
- supports recurring windows and exceptions

### Booking

Booking is the act of selecting a time and creating a meeting relationship.

Requirements:
- capture guest identity if required
- capture title/purpose
- capture schedule and timezone
- capture source booking page

### Confirmation

Confirmation must tell the guest:
- the meeting is booked
- when it is
- who hosts it
- how to join
- what happens next

### Reminder

Reminders should reinforce:
- time
- host identity
- join path
- timezone

### Reschedule

Reschedule should:
- preserve the meeting record
- update the time
- preserve identity and context

### Cancellation

Cancellation should:
- be explicit
- be visible to both host and guest
- preserve history

### Timezone handling

- Timezone must always be explicit to the guest and host.
- Display in local time and meeting timezone where appropriate.

### Guest experience

- Guests should be able to book without understanding institution internals.
- Guests should understand why the meeting matters.

### Host experience

- Hosts should see the source booking page, guest details, and follow-up context.

### Public booking pages

- Public booking pages should be polished, identity-forward, and easy to trust.

### Institution booking pages

- Institution booking pages should make ownership and affiliation obvious.

---

## 7. Room Architecture

### Host room

Host room is the authoritative live meeting room for the host.

Must provide:
- meeting title
- status
- participant count
- waiting state
- controls
- copy link
- end meeting

### Guest room

Guest room is the simplified participant view.

Must provide:
- meeting title
- host identity
- waiting state
- minimal controls
- leave path

### Waiting room

Waiting room is a valid, stable meeting state.

Must provide:
- confirmation of identity
- status of the other party
- calm recovery options

### Participant management

The room should surface:
- who is present
- who is waiting
- who joined
- who left

### Attendance

The room should support attendance awareness:
- host joined
- guest joined
- participant count
- no-show visibility

### Room controls

Controls should be role-aware:
- host controls
- guest controls
- shared controls

### Room persistence

The room should remain attached to the meeting record.

### Transport failure behavior

- preserve the room identity
- show recovery options
- do not convert to a generic dead-end error

### Rejoin behavior

- rejoin should be possible without confusion
- stale transport should not erase the meeting

### Multi-device behavior

- a user joining from another device should be handled clearly
- the room should preserve ownership rules

### Host-only controls

- end meeting
- admit or manage guests if applicable
- control host-side participation

### Guest controls

- join
- leave
- retry

---

## 8. Post-Meeting Architecture

Aura should not end at the room. Post-meeting is a core product surface.

### What is captured

- summary
- attendance
- decisions
- commitments
- actions
- issues
- follow-ups
- continuity references

### Where it appears

- meeting detail
- post-meeting workspace
- host dashboard in past meetings
- future retrieval from institutional history

### Who creates it

- host first
- collaborators if allowed

### How it is used

- to review what happened
- to track what was promised
- to convert conversation into action
- to support institutional memory

### Workspace integration

The post-meeting record should connect to:
- notes
- tasks
- follow-ups
- participants
- institution history

---

## 9. Aura Differentiation

Aura differentiation must be placed, not merely listed.

### Institution identity

Screen:
- booking page
- guest join page
- meeting detail

Moment:
- first impression

Value:
- establishes trust and legitimacy

### Preparation

Screen:
- host detail
- host preparation workspace

Moment:
- before entering room

Value:
- reduces uncertainty and improves readiness

### Continuity

Screen:
- post-meeting summary
- past meetings
- institutional history

Moment:
- after the meeting ends

Value:
- the meeting remains useful later

### Accountability

Screen:
- meeting detail
- summary
- follow-up workspace

Moment:
- during and after the meeting

Value:
- decisions and commitments do not disappear

### Commitments

Screen:
- meeting summary
- post-meeting workspace

Moment:
- immediately after the meeting

Value:
- the meeting leads to action

### Decisions

Screen:
- summary
- post-meeting workspace

Moment:
- during conclusion

Value:
- clear record of what was decided

### Workspace memory

Screen:
- host dashboard
- meeting detail
- post-meeting workspace

Moment:
- later retrieval

Value:
- institutions can revisit history without searching elsewhere

---

## 10. Visual Experience System

### How Aura Meetings should feel

- Professional
- Trustworthy
- Calm
- Prepared
- Institutional
- Operational
- Modern

### How Aura Meetings should behave

- Obvious
- Consistent
- Recoverable
- Context-preserving
- Role-aware
- Time-aware

### Hierarchy principles

- State first
- Identity second
- Action third
- Supporting details after that

### Navigation principles

- Host route should stay institution-owned when applicable
- Guest route should stay public and simple
- Room routes should preserve meeting context

### Status principles

- same status everywhere
- no contradictory labels
- no live-forever states
- no call-language leakage in scheduled meeting surfaces

### Desktop principles

- dashboard can use sections and cards
- detail should use a summary-first layout
- room should use a stable shell with a clear side panel or lower panel

### Mobile principles

- stacked layout
- obvious action button
- no hidden critical actions below the fold

### Accessibility principles

- readable contrast
- keyboard and screen-reader support
- clear focus order
- no status encoded only by color

### Trust principles

- the user should always know:
  - where they are
  - who owns the meeting
  - what state it is in
  - what they can do next

---

## 11. Parity Audit

### Calendly

Required parity:
- scheduling clarity
- booking confirmation
- timezone clarity
- simple guest booking flow

Desired parity:
- polished public booking trust

Aura-only advantages:
- institutional identity
- source booking context
- continuity into the workspace

### Zoom

Required parity:
- predictable joining
- waiting behavior
- room entry stability
- ending clarity

Desired parity:
- reliable live room feel

Aura-only advantages:
- host detail context
- post-meeting accountability

### Google Meet

Required parity:
- simple join
- clear live room
- graceful recovery

Desired parity:
- low-friction guest entry

Aura-only advantages:
- institutional continuity

### Microsoft Teams

Required parity:
- meeting ownership
- organizational context
- history and follow-up

Desired parity:
- room persistence and continuity

Aura-only advantages:
- booking + meeting + accountability in one institutional flow

### By workflow

#### Scheduling
Parity required:
- availability
- booking
- confirmation

Aura advantage:
- institution ownership and accountability

#### Joining
Parity required:
- simple entry
- waiting state

Aura advantage:
- clear identity and context

#### Waiting
Parity required:
- visible stable waiting room

Aura advantage:
- institutional trust cues

#### Running
Parity required:
- room control and predictable presence

Aura advantage:
- meeting memory and follow-up context

#### Ending
Parity required:
- explicit end and clear closure

Aura advantage:
- outcome capture and continuity

#### Follow-up
Parity required:
- review after the meeting

Aura advantage:
- institutional memory, decisions, commitments, and actions

---

## 12. Complete Implementation Specification

This section translates the architecture into buildable requirements without prescribing code.

### Availability Management

Frontend requirements:
- manage schedules by day/time
- show existing windows
- show timezone and publication state

Backend requirements:
- store availability windows
- support create/edit/delete
- validate conflicts

API requirements:
- list availability
- create availability
- update availability
- delete availability

Data requirements:
- institution or user ownership
- time range
- timezone
- active/inactive state

Lifecycle requirements:
- availability changes update booking behavior

Validation requirements:
- no invalid time ranges
- no overlapping rules unless explicitly allowed

Testing requirements:
- create/edit/delete works
- booking page reflects changes

### Booking Page

Frontend requirements:
- clear identity
- clear title and description
- clear booking CTA

Backend requirements:
- load booking page data
- surface ownership and availability

API requirements:
- get public page
- get slots

Data requirements:
- booking page metadata
- owner/institution context

Lifecycle requirements:
- booking page reflects active availability only

Validation requirements:
- unavailable slots must not be bookable

Testing requirements:
- public page renders
- slots load
- guest can begin booking

### Booking Confirmation

Frontend requirements:
- show success clearly
- show time and timezone
- show host/institution

Backend requirements:
- create meeting/booking record
- send confirmation artifacts

API requirements:
- booking create
- confirmation payload

Data requirements:
- meeting record
- guest identity
- schedule

Lifecycle requirements:
- confirmation reflects booked state

Validation requirements:
- prevent duplicate or invalid submissions

Testing requirements:
- confirmation displays correct details

### Host Meetings Dashboard

Frontend requirements:
- today, upcoming, past
- clear status
- clear primary action

Backend requirements:
- list meetings by time and institution
- provide unified lifecycle snapshot

API requirements:
- list meetings
- filter by institution

Data requirements:
- lifecycle snapshot
- participant summary
- source booking page

Lifecycle requirements:
- dashboard status matches detail and room

Validation requirements:
- no stale live state for expired meetings

Testing requirements:
- current day is accurate
- past meetings move out of today

### Meeting Creation

Frontend requirements:
- create or schedule meeting
- capture title, time, duration, participants, institution context

Backend requirements:
- create meeting record
- attach ownership and join identity

API requirements:
- create meeting

Data requirements:
- host
- participants
- schedule
- join code

Lifecycle requirements:
- scheduled state is authoritative

Validation requirements:
- schedule time and duration required as applicable

Testing requirements:
- meeting appears in dashboard and detail

### Meeting Detail

Frontend requirements:
- summary-first layout
- clear actions
- attendance and notes placeholders

Backend requirements:
- provide room snapshot and source booking data

API requirements:
- get meeting by id

Data requirements:
- title, time, timezone, participants, source page, room state

Lifecycle requirements:
- detail mirrors dashboard and room state

Validation requirements:
- inaccessible meetings show clear errors

Testing requirements:
- detail matches lifecycle snapshot

### Host Preparation Workspace

Frontend requirements:
- show readiness and entry action

Backend requirements:
- provide room snapshot

API requirements:
- get meeting room snapshot

Data requirements:
- status, canStart, canEnter, canRetryTransport

Lifecycle requirements:
- preparing is a valid state

Validation requirements:
- room entry should respect meeting state

Testing requirements:
- early entry shows waiting rather than failure

### Host Waiting Room

Frontend requirements:
- calm waiting state
- waiting status for guest

Backend requirements:
- persist waiting state in snapshot

API requirements:
- room snapshot and join/start support

Data requirements:
- participant summary
- waiting count

Lifecycle requirements:
- waiting is not terminal

Validation requirements:
- transport failure must not erase waiting room

Testing requirements:
- host can remain in room while waiting

### Host Live Room

Frontend requirements:
- room shell
- controls
- participant visibility

Backend requirements:
- live meeting support
- attendance data

API requirements:
- room snapshot
- join/leave/end actions

Data requirements:
- active participants
- startedAt
- endedAt

Lifecycle requirements:
- live state stays stable until explicit end or valid expiration

Validation requirements:
- no auto-end just because participants change

Testing requirements:
- host and guest can be present together

### Guest Join Page

Frontend requirements:
- identity confirmation
- join or wait action

Backend requirements:
- public join flow

API requirements:
- get meeting by code
- join meeting by code

Data requirements:
- host/institution/title/time/state

Lifecycle requirements:
- guest join updates the meeting state consistently

Validation requirements:
- invalid or cancelled meetings are handled clearly

Testing requirements:
- guest can join without workspace requirement

### Guest Waiting Room

Frontend requirements:
- reassure
- display host/institution/time

Backend requirements:
- return waiting state in snapshot

API requirements:
- join and room snapshot

Data requirements:
- waiting state
- live state

Lifecycle requirements:
- waiting stays stable until host enters or meeting changes state

Validation requirements:
- waiting is not failure

Testing requirements:
- early guest remains in waiting state

### Guest Live Room

Frontend requirements:
- simple, controlled room

Backend requirements:
- live room access

API requirements:
- join room

Data requirements:
- participant presence

Lifecycle requirements:
- guest and host share the same meeting room

Validation requirements:
- role-specific controls only

Testing requirements:
- guest reaches same room as host

### Meeting Ended

Frontend requirements:
- clear closure and next steps

Backend requirements:
- explicit ended state

API requirements:
- room/meeting ended snapshot

Data requirements:
- ended reason if available

Lifecycle requirements:
- ended is terminal unless rescheduled or reviewed history

Validation requirements:
- ended meetings cannot be reopened as if live

Testing requirements:
- ended state is shown consistently

### Meeting Summary

Frontend requirements:
- attendance, decisions, commitments, actions

Backend requirements:
- persist summary record

API requirements:
- create/update summary

Data requirements:
- summary fields
- attendance fields

Lifecycle requirements:
- summary belongs to completed or concluding meetings

Validation requirements:
- summary cannot overwrite ownership or time data

Testing requirements:
- summary persists and reopens

### Post Meeting Workspace

Frontend requirements:
- continued access to meeting memory

Backend requirements:
- retrieve meeting history

API requirements:
- list or fetch post-meeting artifacts

Data requirements:
- decisions, commitments, follow-ups

Lifecycle requirements:
- meeting history survives completion

Validation requirements:
- permissions respected

Testing requirements:
- meeting remains accessible after completion

---

## 13. Acceptance Tests

### Scheduling and booking

1. Host creates availability.
   Expected:
   - windows save
   - booking page updates
   - no invalid schedule appears

2. Guest books a meeting.
   Expected:
   - confirmation appears
   - host sees the meeting
   - timezone and identity are correct

3. Guest opens public booking page.
   Expected:
   - page is understandable
   - booking CTA is obvious
   - no workspace requirement appears

### Host behavior

4. Host opens dashboard.
   Expected:
   - today’s meetings are clear
   - upcoming and past are separated
   - primary action is obvious

5. Host opens meeting detail.
   Expected:
   - title, time, host, guest, and source context are visible
   - actions are appropriate for the lifecycle

6. Host arrives early.
   Expected:
   - host sees waiting or starting soon
   - meeting remains valid

### Guest behavior

7. Guest arrives early.
   Expected:
   - guest sees waiting room
   - clear reassurance
   - no failure or dead end

8. Guest arrives on time.
   Expected:
   - guest joins smoothly
   - live room opens

### Lifecycle behavior

9. Meeting starts.
   Expected:
   - dashboard, detail, room, and guest screens agree on state

10. Meeting ends explicitly.
    Expected:
    - ended state appears consistently
    - history remains accessible

11. Meeting expires without meaningful activity.
    Expected:
    - meeting becomes missed or completed, not live forever

12. Meeting is cancelled.
    Expected:
    - cancellation is visible everywhere
    - join is no longer treated as active

13. Meeting is rescheduled.
    Expected:
    - history remains
    - time updates
    - identity remains intact

### Transport failure behavior

14. Transport fails while the meeting is still valid.
    Expected:
    - meeting identity remains visible
    - recovery is possible
    - no dead-end error screen replaces the meeting

15. Guest rejoins from another device.
    Expected:
    - room state remains understandable
    - participant presence updates correctly

### Post-meeting behavior

16. Host records decisions and commitments.
    Expected:
    - summary persists
    - follow-up is visible later

17. Meeting becomes institutional record.
    Expected:
    - it can be reviewed from history
    - it is useful after the live room ends

---

## Final Acceptance

This architecture is complete when:

- a product designer can design the experience
- a frontend engineer can build the screens without inventing structure
- a backend engineer can build the data and lifecycle contract without inventing states
- a QA engineer can test the expected outcomes end-to-end
- a founder can understand what Aura Meetings is and why it exists

No additional product architecture document should be needed before implementation begins.
