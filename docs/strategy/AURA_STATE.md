# AURA_STATE.md — Canonical Reality

> Canonical reference for Aura. Future work on the company website, investor
> materials, commercialization, decks, outreach, and positioning must
> reference this document first. It captures **observed implementation and
> validated audit findings** — facts, not aspirations.
>
> Note on location: `aura/` is not a git repository; the Aura repository is
> `aura_final` (origin: `bajwa4u2/aura-frontend`). This canonical doc
> therefore lives at `aura_final/docs/strategy/`.

## Product Reality

**What Aura is.** Verified-identity public-communication infrastructure for institutions. An institution gets a **domain-verified public presence** under its official identity plus an **accountable public record** — typed accountability (commitment → update → resolved) computed and shown in the open. A public *record*, not an engagement *feed*.

**What Aura is not.** Not a social network. Not a creator / creator-economy platform. Not a community platform. Not a startup idea. Not under-built.

**Institutional infrastructure posture.** Four distinct shells — **Public, Member, Institution, Admin** — a full institution workspace, a large multi-module backend, and a deployed public web build (per-route SEO / OpenGraph / schema.org). Distribution: live on web, published to the Microsoft Store, and distributed through Google Play closed testing (active); Apple App Store review in progress (TestFlight build processed). Release artifacts build for Web, Windows, Android, and iOS.

## Commercial Reality

- **Buyer:** the institution — governments, universities, agencies, regulators, professional associations, nonprofits, media organizations. **Members are free; institutions pay.**
- **Institution model:** four-tier plans `FREE → VERIFIED → PRO → TRUSTED`; member-limit enforcement (HTTP 402 `MEMBER_LIMIT_REACHED`); **official voice** (`canSpeakOfficially`) gated to PRO+.
- **Verification model:** DNS TXT domain verification (`_aura-verification.<domain>`), lifecycle `PENDING → CHALLENGE_ISSUED → VERIFIED / FAILED` with expiry/revocation and an audit log; verified badge; admin review upgrades `FREE → VERIFIED`.
- **Accountability model (AU-01):** `openCommitments = commitments − resolvedDistinct`, computed deterministically and rendered **publicly** on institution profiles and member home. Observational, **not gamified**, not ranked. Backed by the discourse-intelligence module.

## Existing Assets

- **Institution workspaces:** explore, activity, messages, spaces, announcements, live rooms, invites, members, join-requests, domains, profile (full CRUD + state machines).
- **Domain verification:** DNS-backed, lifecycle, audit, revocation.
- **Public profiles:** `/institutions/:slug` with a "Domains & Verification" section + open commitments + public posts.
- **Open commitments:** AU-01, public, computed.
- **Directory:** `/institutions`, verified-first, sector ontology (Class = GOVERNMENT / EDUCATION / HEALTHCARE …).
- **Governance:** 10-screen Admin shell (review queue, grants, audit logs, domains, policies, feature flags, communications); RBAC grants + audit trail.
- **Monetization:** plan tiers, member limits, billing.
- **Public marketing surfaces:** mission, founder, investors (+ deck), patrons, supporters, white-paper, transparency (`/aura/participation`).

## Public Record Accountability — Implemented (as of 2026-06-21)

The public record accountability system (Phase F1–F5) is **fully implemented and deployed**. This is not a future framework — it is running in production.

### What is live

**Backend (`https://api.auraplatform.org/v1`, commit `d34ae7c`):**
- `RoutedPublicRecord` model: every public post routed to one or more institutions by topic participation
- `RoutedPublicRecord.status`: `PENDING → RESPONDED → COMMITTED → RESOLVED` lifecycle driven by institution accountability tags
- `publicStatus` field on post detail: derives from the highest status across all routed records for that post; returned as `PENDING / RESPONDED / COMMITTED / RESOLVED`
- `AccountabilityTag` lifecycle: `COMMITMENT` tag advances status to `COMMITTED`; `RESOLVED` tag advances to `RESOLVED`; `UPDATE` tag does not advance status (informational only)
- Engagement workspace endpoints: `GET /institutions/:id/engagement`, `GET /institutions/:id/engagement/:recordId`, `GET /institutions/:id/engagement/summary` — returns all routed records with topic, intent, author, and status
- Institution participation declarations: `GOVERNMENT/ACCOUNTABLE`, `EDUCATION/RESPONDING`, `TECHNOLOGY/ACCOUNTABLE` — controls which topics route to which institutions
- Participation modes: `ACCOUNTABLE` (commits to responding) and `RESPONDING` (participates without commitment)

**Flutter frontend (commit `3dac187`):**
- Engagement workspace: list of routed records with status badge, topic, intent, author
- Status badges: `Needs Response / Official Response / Commitment / Resolved`
- Engagement detail: full post body, author, status, "View original post" deep link
- Institution participation screen: topic/mode declarations visible with status
- Summary card: total and `needsResponse` count

**Feature flags (both OFF — do not enable without explicit approval):**
- `PUBLIC_RECORD_INTENT_REQUIRED` — gates post visibility by intent; currently OFF so all posts surface
- `CAN_RAISE_ISSUE_GATE_ENABLED` — gates who can raise an issue; currently OFF

### What is not yet built

- "Reply Officially" action from engagement detail (next build: allows institution admin to compose and publish institution post reply with accountability tag directly from the engagement detail screen)
- Participation admin UX polish (topic descriptions, mode explanations, status transitions)
- LISTENING and REFERENCE_ONLY participation modes (explicitly deferred)
- Jurisdiction-aware routing refinement (deferred)
- Intent-required gate for public posts (flag off, not built out)

### Seeded institutions

- **Aura Platform LLC** (`aura-platform-llc`, ID `cmmg1ildu0000k201gtwg60rr`): verified, GOVERNMENT/ACCOUNTABLE + EDUCATION/RESPONDING + TECHNOLOGY/ACCOUNTABLE participations active. Has COMMITTED and RESOLVED engagement records in production demonstrating the full lifecycle end-to-end.

## Proven False Assumptions

- ❌ "Aura is a social network." → Verified-identity institutional accountability; a public record, not an engagement feed.
- ❌ "Aura is a creator platform." → No creator-economy model; the unit of value is institutional accountability.
- ❌ "Aura is under-built." → Four shells, a full institution workspace, a computed accountability engine, DNS verification, deployed multi-platform.
- ❌ "Aura's proof is missing." → DNS verification, the public accountability formula, the public directory, and the admin/audit surfaces are abundant proof. The real issues are that the proof surface is **unpopulated** and was previously framed **doctrinally** (since corrected by the institutional marketing-legibility pass).

## Current Bottlenecks (reality-backed)

1. **Cold-start / empty network** — the public proof surface (directory + accountability trails) is real but **unpopulated**; no verified institutions yet. For a public-communication platform, an empty surface is negative proof.
2. **No externally-verified institutions or usage** (market-assigned value).
3. **First-institution acquisition is relationship-driven** — warm-sourced, founder-operated; no inbound at zero population.
4. (Resolved) Commercial legibility — the public home hero and institutions directory now lead with the institutional offer before doctrine.

## Representation Doctrine (how to represent Aura)

- **Lead with the institutional offer** — verified public presence + official communication + accountable public record — **before** doctrine. The five pillars (Identity, Accountability, Continuity, Human Authority, Operational Memory) remain the **supporting** layer; they are never removed.
- **Buyer = the institution.** Frame **verification** and **open commitments** as institutional capabilities and trust assets, not setup details or doctrine examples.
- **Differentiator vs social:** verified identity + typed accountability + public record — "not a feed, a record."
- **Be honest:** no verified institutions yet; the path is founder-operated seeding of the directory so the proof surface is populated.
- **Doctrine is preserved**, intact and visible, beneath the legible offer.

## Progressive Credibility Doctrine

Aura's institution journey is progressive:

```txt
Identity is declared.
Participation is observed.
Credibility is earned.
Accountability is progressively accepted.
Trust accumulates through continuity.
```

Verified identity is the start of institutional presence, not the end state of
trust. Participation can be suggested or declared, but credibility comes from
observable behavior: official responses, commitments, progress, resolution,
dispute handling, and durable continuity. Accountability should not be treated
as an onboarding checkbox; it becomes meaningful through public institutional
action over time.
