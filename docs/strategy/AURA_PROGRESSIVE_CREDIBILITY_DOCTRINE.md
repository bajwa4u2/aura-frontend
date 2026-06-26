# Aura Progressive Credibility Doctrine

Date: 2026-06-20

Status: Documentation-only doctrine alignment. This file does not implement application code, create migrations, commit changes, or deploy anything.

Canonical references:

- `aura_final/docs/strategy/AURA_STATE.md`
- `aura_final/docs/strategy/AURA_ACCOUNTABILITY_ROUTING_IMPLEMENTATION_FRAMEWORK.md`
- `aura_final/docs/strategy/AURA_CONTEXT_OWNERSHIP_RESOLUTION_FRAMEWORK.md`
- `aura_final/docs/strategy/AURA_PRE_IMPLEMENTATION_LOCK.md`
- `aura_final/docs/strategy/AURA_INSTITUTION_PARTICIPATION_ACTIVATION_FRAMEWORK.md`

## Executive Summary

Aura's final onboarding philosophy is:

```txt
Identity is declared.
Participation is observed.
Credibility is earned.
Accountability is progressively accepted.
Trust accumulates through continuity.
```

This corrects an overly configuration-heavy interpretation of the earlier participation documents. Institutions should not be forced to know their full future participation, jurisdiction, and accountability model on day one. Aura should let a verified institution become present quickly, start communicating officially, and then earn credibility through observable behavior.

Participation can be declared, but credibility cannot be configured into existence. Accountability should not be reduced to a checkbox. It becomes meaningful through visible official responses, commitments, progress, resolution, dispute handling, and continuity.

The implementation consequence is:

- Patch 1 remains valid.
- Patch 2 remains valid.
- Patch 3 remains valid but should shrink and simplify onboarding.
- Patch 3 should create the foundation for participation and jurisdiction without requiring large up-front setup.
- Patch 4 routing remains blocked until schema/API review and until participation/credibility/accountability boundaries are explicit.

## Identity -> Participation -> Credibility -> Accountability -> Trust

### Doctrine Chain

| Stage | Meaning | Primary evidence | Public implication |
| --- | --- | --- | --- |
| Identity | Institution says who it is and verifies official presence | Profile, domain verification, admin approval, official representatives | "This is an official institution presence" |
| Participation | Institution begins taking part in public records and topics | Official posts, replies, declared topics, observed engagement | "This institution participates here" |
| Credibility | Institution builds a visible pattern of useful behavior | Response history, continuity, commitments, progress, resolved records | "This institution has a public record of behavior" |
| Accountability | Institution accepts responsibility in specific contexts | Official acknowledgment, commitment, progress, resolution, verification/dispute | "This institution has accepted accountable action here" |
| Trust | Public confidence accumulates through continuity over time | Durable institutional memory, consistent behavior, closed loops | "The record shows what happened" |

### Corrected Activation Philosophy

Replace:

```txt
Profile
-> Verification
-> Participation Setup
-> Accountability Setup
-> Routing
```

with:

```txt
Profile
-> Verification
-> Official Representatives
-> Participation Begins
-> Credibility Accumulates
-> Accountability Accepted
-> Trust Established
```

### Stage Model

| Stage | System expectations | Institution expectations | Capabilities unlocked | Credibility signals generated |
| --- | --- | --- | --- | --- |
| Profile | Store durable institution identity and public profile | Provide accurate name, domain, class/type when possible | Profile visibility, claim/verify path | None or minimal |
| Verification | Confirm official identity path | Verify domain or pass admin review | Verified presence, official badge eligibility | Verified identity signal |
| Official Representatives | Confirm who can speak officially | Assign official actors | Official posts/replies, workspace access | Official voice signal |
| Participation Begins | Let institution communicate and optionally declare initial topics | Start posting, replying, joining relevant public records | Public engagement presence, optional topic declarations | Participation signal |
| Credibility Accumulates | Record observable behavior without scores | Respond, clarify, update, follow through | Continuity history, response surfaces | Responsiveness and follow-through signals |
| Accountability Accepted | Allow institution to explicitly accept accountable action in context | Make commitments only when ready | Commitments, progress, resolution | Accountability signal |
| Trust Established | Preserve durable continuity across records | Maintain consistency over time | Trusted posture, public record depth | Continuity and closure signals |

## Participation vs Credibility

Participation is not credibility.

| Statement | Correct interpretation |
| --- | --- |
| Institution is verified | It is officially present; it is not automatically trusted |
| Institution declares participation | It has said it participates; it has not earned credibility yet |
| Institution responds | It has communicated officially; it has not necessarily committed |
| Institution commits | It has accepted a specific obligation; it has not resolved it yet |
| Institution resolves | It has claimed closure; verification/dispute may still matter |
| Institution has continuity | The public can inspect what happened over time |

### Explicit Progression

Recommended progression:

1. Verified Institution.
   - Identity has been confirmed.
   - Official representatives exist.

2. Participating Institution.
   - Institution has begun official communication or declared initial participation.
   - Participation can be observed or declared.

3. Responsive Institution.
   - Institution has a visible pattern of official responses.
   - This is behavioral, not configured.

4. Accountable Institution.
   - Institution has accepted accountable workflows in specific contexts.
   - Accountability is expressed through official actions and commitments, not only setup.

5. Trusted Institution.
   - Institution has durable continuity showing follow-through over time.
   - Trust is accumulated, not assigned.

## Progressive Credibility Framework

### Non-Gamified Credibility

Aura should not design public scores, leaderboards, badges, rankings, streaks, or gamified trust mechanics.

Credibility should be represented as observable public behavior:

- official response exists
- commitment exists
- progress update exists
- resolved claim exists
- dispute or verification exists
- continuity record exists
- open commitments are visible

### Signals That Exist Today

Current reusable signals:

- institution verification status
- domain verification status and trust level
- official voice eligibility
- institution member roles
- official institution posts/replies
- accountability tags on institution posts
- open commitments computation in discourse intelligence
- public profiles
- activity/audit infrastructure
- institution units

### Future Signals

Future public-safe signals:

- official response count by public record context
- recent official response presence
- open commitments
- progress updates
- resolved commitments
- disputed/reopened records
- continuity timeline completeness

Future private/admin signals:

- routing attempts
- route failures
- routing confidence
- admin review decisions
- capability policy decisions
- internal notes
- private assignment
- identity verification evidence

### Public vs Private Credibility Signals

| Signal | Public | Institution workspace | Admin |
| --- | ---: | ---: | ---: |
| Verified identity | Yes | Yes | Yes |
| Official response | Yes | Yes | Yes |
| Commitment | Yes | Yes | Yes |
| Progress update | Yes | Yes | Yes |
| Resolution | Yes | Yes | Yes |
| Open commitments | Yes | Yes | Yes |
| Response pattern summary | Maybe, public-safe | Yes | Yes |
| Routing confidence | Never | No | Yes |
| Internal assignment | Never | Yes | Yes |
| Private notes | Never | Yes | Yes |
| Identity evidence details | Never | Restricted | Restricted |
| AI suggestions | Never as authority | Maybe as draft | Yes |

## Accountability Acceptance Model

### Options

| Option | Description | Strength | Weakness |
| --- | --- | --- | --- |
| A: Declaration-only | Institution declares accountability during setup | Clear routing input | Too brittle; turns onboarding into bureaucracy; can imply credibility before behavior |
| B: Behavior-only | Institution becomes accountable only through responses/commitments | Strongly aligned with earned trust | Harder to route first accountable records; needs observation period |
| C: Hybrid | Institution can declare availability, but accountability becomes meaningful through official behavior | Best balance | Requires careful language and state boundaries |

### Recommendation: Hybrid

Aura should use a hybrid model.

Institution setup may include lightweight declarations:

- topics it participates in
- where it operates
- whether it is open to listening/responding

But accountable status should be progressively accepted through behavior:

- official response
- acknowledgment
- explicit commitment
- progress update
- resolution
- verification/dispute handling
- continuity over time

### Locked Rule

Accountability is not a checkbox.

The system may store an internal participation mode for future routing, but public accountability should be demonstrated through visible institutional action. A configured `ACCOUNTABLE` mode is route eligibility, not earned credibility and not a fulfilled obligation.

## Simplified Institution Onboarding Model

### Preferred Experience

The onboarding experience should be:

1. Who are you?
2. Verify identity.
3. Who can speak officially?
4. Start participating.

Everything else should be progressively enabled.

### Required at Onboarding

Required:

- institution name
- official domain or approved verification path
- primary representative
- acceptance of institution terms/policy
- official voice eligibility where applicable

### Optional at Onboarding

Optional:

- institution class/type
- domain tags
- first topics
- first jurisdiction/scope
- units
- public profile enrichment
- participation mode
- response preferences

### Can Be Learned Later

Can be learned through activity:

- which topics the institution actually responds to
- which public spaces it engages in
- which units participate most
- whether official responses become commitments
- whether commitments receive progress updates
- whether resolutions are accepted or disputed

### Can Be Suggested Later

Can be suggested by system or AI:

- topics based on profile and activity
- likely jurisdictions from verified domain/profile
- unit suggestions from profile structure
- potential public spaces
- possible duplicate participation declarations

### Must Never Be Inferred as Authority

Never infer these as authoritative without explicit confirmation:

- legal jurisdiction
- accountable responsibility
- commitment
- resolution
- official representative authority
- age/identity assurance
- participation mode stronger than observed behavior

## Suggested vs Declared Participation

### Locked Principle

Suggested Participation is not Declared Participation.

Declared Participation is not Earned Credibility.

### Suggested Participation

Suggested participation may come from:

- institution class/type
- domain tags
- profile text
- website/domain
- public activity
- followed public spaces
- discourse intelligence
- AI suggestions

Suggested participation may be used for:

- onboarding prompts
- draft setup
- admin review
- workspace recommendations
- "complete your presence" prompts

Suggested participation must not:

- create routing
- create accountability
- appear publicly as accepted participation
- imply responsibility

### Declared Participation

Declared participation requires explicit institution/admin confirmation.

Declared participation may include:

- topic
- jurisdiction/scope
- optional unit
- mode
- status
- actor
- timestamp

Declared participation may support route eligibility later, but only after Patch 4 schema/API review and feature flags.

### What Must Exist Before Routing

Before routing:

- public record intent
- author capability
- primary topic
- context priority resolution
- jurisdiction when location-dependent
- institution verification/activation
- declared participation or approved pilot participation
- participation mode
- idempotent route contract
- public/private/admin DTO boundary
- failure behavior
- tests

### What May Be Suggested

May be suggested:

- topic declarations
- jurisdiction/scope
- unit associations
- public spaces
- participation mode
- related records

### What Must Be Explicitly Confirmed

Must be explicitly confirmed:

- official institution identity
- official representative authority
- active participation declaration used for routing
- accountability acceptance stronger than response
- commitment
- resolution
- withdrawal of commitment

## Patch Impact Analysis

### Patch 1

Status: remains valid.

No doctrine change blocks Patch 1.

Patch 1 should still:

- persist public record intent
- require primary topic for top-level public records
- avoid complaint/case/ticket language
- treat intent as communication mode, not lifecycle

### Patch 2

Status: remains valid.

No doctrine change blocks Patch 2.

Patch 2 should still:

- use capabilities, not hard-coded verification fields
- gate Raise Issue through policy
- keep denial/upgrade language public-safe
- avoid exposing private assurance evidence

### Patch 3

Status: remains valid but should shrink and simplify.

Patch 3 should not force institutions through complete participation/accountability setup before they can feel active on Aura.

Patch 3 should focus on:

- lightweight participation foundation
- optional declared participation
- suggested vs declared participation boundary
- basic global jurisdiction primitives
- activation states that allow verified official presence before route readiness
- official representatives
- audit/history for declarations

Patch 3 should defer:

- detailed accountable scopes
- mandatory unit participation
- complex jurisdiction configuration
- public accountability labels based only on setup
- any routing behavior

### Patch 3 Onboarding Recommendation

Shrink onboarding to:

1. Profile.
2. Verification.
3. Official representatives.
4. Start participating.

Move these to progressive settings/prompts:

- topic declarations
- jurisdiction declarations
- unit participation
- participation modes
- accountability acceptance

### Patch 4

Status: remains blocked.

Patch 4 must consume declared participation and observable credibility carefully. It must not route based on suggested participation, weak signals, or credibility assumptions.

## Required Document Updates

### `AURA_STATE.md`

Required doctrine addition:

- Add progressive credibility as the institution growth doctrine.
- Clarify that verified identity is the starting point, not the final trust state.
- Clarify that trust accumulates through continuity, not setup.

### `AURA_ACCOUNTABILITY_ROUTING_IMPLEMENTATION_FRAMEWORK.md`

Required doctrine changes:

- Qualify participation modes as route eligibility, not earned credibility.
- Clarify `ACCOUNTABLE` mode is not public trust and not a commitment.
- Replace any setup-heavy reading of Patch 3 with progressive onboarding.
- Add distinction between suggested participation and declared participation.
- Clarify that routing must not consume suggested participation as authority.

### `AURA_CONTEXT_OWNERSHIP_RESOLUTION_FRAMEWORK.md`

Required doctrine changes:

- Clarify that ownership resolution evaluates declared participation and observed behavior separately.
- Replace language implying participating/accountable institutions are fully known at setup.
- Treat credibility signals as supporting context, not route authority.
- Preserve weak-signal rule: AI, social graph, and discourse intelligence cannot create accountability.

### `AURA_PRE_IMPLEMENTATION_LOCK.md`

Required doctrine changes:

- Add Progressive Credibility Doctrine as a required reference before Patch 3 and Patch 4.
- Update Patch 3 wording to allow simplified onboarding and optional declarations.
- Clarify Patch 4 remains blocked from using suggested participation.

### `AURA_INSTITUTION_PARTICIPATION_ACTIVATION_FRAMEWORK.md`

Required doctrine changes:

- Replace activation flow with Profile -> Verification -> Official Representatives -> Participation Begins -> Credibility Accumulates -> Accountability Accepted -> Trust Established.
- Soften "required participation setup" language.
- Move accountability declaration from onboarding to progressive acceptance.
- Add `Participation != Credibility`.
- Add suggested vs declared participation.
- Keep global jurisdiction and units, but make detailed configuration progressive.

## Final Recommendation

Adopt progressive credibility as the controlling doctrine for Patch 3 and all later routing work.

Patch 3 should make institutions able to become meaningful participants without forcing a large setup ceremony. The first institution experience should be fast:

```txt
Who are you?
Verify identity.
Who can speak officially?
Start participating.
```

Then Aura should progressively help the institution declare topics, define scope, add units, accept accountable workflows, and build public credibility through continuity.

The final implementation rule is:

```txt
Setup can declare identity and initial participation.
Only behavior creates credibility.
Only official action creates accountability.
Only continuity creates trust.
```

