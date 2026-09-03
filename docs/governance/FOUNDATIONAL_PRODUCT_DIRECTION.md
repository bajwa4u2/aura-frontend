# Foundational Product Direction — Aura — Flutter client

**Status:** AUTHORITATIVE. Read before planning, architecture, implementation,
refactoring, naming, route design, or client reconstruction.
**Repository role:** Aura frontend. Single Flutter codebase (iOS + Android + Web), four shells: Member, Institution, Admin, Public.
**Established:** 2026-09-03 by founder decision.

**Shared doctrine version: `FPD-2026-09-03.1`** — sections 0 and 2–10 below are a verbatim
mirror of the canonical source at
`representation/inventory/FOUNDATIONAL_PRODUCT_DIRECTION.md`. Edit there first,
advance the stamp, then resync mirrors. A mirror whose stamp differs from the
source is stale and must be resynced, never independently edited. The reason
this estate mirrors rather than references — against its usual convention — is
stated in §12 of the canonical source: these repositories are cloned and
deployed independently, and a governance rule an agent cannot read is not a
governance rule.

Section 1, and sections 11–12, are **specific to this product** and are authored
here.

---

## 0. Why this document exists

Every product in this estate already has strong governance: identity canon,
capability authorities, certification levels, architecture documents,
supersession ledgers. None of that prevented the failure this document is aimed
at.

The failure is quieter than a bad decision. It is an agent — Claude, Codex, or
any other — entering a repository, reading the code, and **silently concluding
that the product is what the implementation currently looks like.** Routes
become the product model. Controllers become the navigation. A payment provider
becomes the commerce authority. An AI capability becomes the product's headline.
A fundraising sentence becomes the architecture.

Nothing in that chain requires anyone to make a wrong choice. It only requires
each step to be locally reasonable. The result is a product that has drifted
from what it exists to do, with no single commit anyone can point at.

This document is read **before** planning, architecture, implementation,
refactoring, naming, route design, or client reconstruction — so that the
product's purpose is in view before its code is.

It is a **directional** authority, not a replacement one. It does not displace
the architectures, doctrines and authority models this estate already has; §5
states that boundary precisely, and it matters as much as the direction itself.
A governance layer that must be cited for every decision stops being read.

---

## 1. What Aura is

**Aura is human and institutional trust infrastructure.**

Its purpose begins with **real public and person communication and discourse
problems**. It creates purposeful, responsible, secure and continuous human
communication and collaboration. **Institutional participation follows as
accountability and responsibility infrastructure** — it is not the acquisition
premise and not the reason people arrive.

### What Aura must never be reduced to

social media · institutional messaging · a civic-tech portal · AI communication ·
meetings · a feed · chat.

Each of these may exist *inside* Aura. None is its governing identity. An agent
must refuse a change that flattens Aura into one of them.

### Relationship to the public-first causal doctrine

The public-first doctrine (`representation/inventory/AURA_PUBLIC_FIRST_CAUSAL_DOCTRINE.md`,
founder-frozen 2026-08-15) is **fully preserved and unchanged**. This document
does not replace it and does not re-open it.

What this document adds is the wider frame the doctrine already implied: Aura's
subject is **trust between humans, and between humans and institutions**. Public
communication and discourse are where that trust is built and tested; they are
not the whole of what Aura is for.

Read together: people and their need for purposeful, credible, continuous
communication are the originating force; institutions enter that environment
under accountable identity; and the thing being constructed across both is
**trust that can be relied upon over time**.

### Boundaries against sibling products

Aura is not an outbound-execution or CRM tool — that is Orchestrate's domain.
Aura is not a publishing or preservation platform for authored long-form work —
that is Bajwa Write's domain. Aura's identity does not reduce to any single
module it contains, and does not expand to claim capabilities it has not built.

## 2. Governing portfolio direction

**We do not organize Aura Platform or its products around fundraising optics,
valuation theater, feature count, superficial sophistication, deadline pressure,
or implementation convenience.**

We build **institution-grade products first**: grounded in durable purpose,
coherent architecture, governance, authority, provenance, continuity,
repairability, usability, real operational capability, real market relevance,
and long-term global significance.

**Capital, scale and valuation are consequences of demonstrated product
coherence and execution. They are not the organizing purpose of product
architecture.**

---

## 3. Purpose before technology

Begin from what the product exists to do, not from the technologies currently
implementing it.

Technology changes. Interfaces change. Providers change. Frameworks change. The
governing product purpose survives them.

An agent must **not** redefine product identity from any of the following. Each
is evidence of a current implementation, never authority over product meaning:

- current route structure
- current schema or table names
- Flutter package organization
- backend controller topology
- an AI capability that happens to exist
- the current payment provider
- the current customer-acquisition mechanism
- the current release surface

---

## 4. The fifteen non-drift rules

These bind every agent in every active repository.

| # | Rule |
|---|---|
| **ND-1** | **Purpose before implementation.** Current code is evidence of implementation, not authority over product meaning. |
| **ND-2** | **Architecture before local patching.** If a visible defect is caused by missing or unshared authority, fix the authority. Do not accumulate page-specific fixes. |
| **ND-3** | **Backend richness is not enough.** An endpoint or model existing does not mean the product has the capability. The human must be able to understand and legitimately operate it. |
| **ND-4** | **Client elegance must reveal depth without exposing complexity.** Do not mirror controllers and models into navigation. A model does not earn a tab. A controller does not earn a screen. |
| **ND-5** | **Simplicity means hierarchy, not hiding.** Do not remove meaningful capability merely to produce fewer screens. |
| **ND-6** | **No feature-count thinking.** Do not add visible features simply to make a product look sophisticated. |
| **ND-7** | **No fundraising-driven architecture.** Do not change the product merely because a framing sounds more investable. Capital follows demonstrated value. |
| **ND-8** | **No deadline-driven corruption.** Sequencing and operational urgency are legitimate. Calendar pressure is not authority to violate canonical architecture. |
| **ND-9** | **AI is an instrument.** Never let AI become sovereign product authority merely because the technology permits it. |
| **ND-10** | **Governance is product capability.** Authority, provenance, consequence, repairability, continuity and admission are not compliance decoration. |
| **ND-11** | **Historical truth is preserved.** Do not rewrite or delete provenance merely to make current state cleaner. |
| **ND-12** | **Honest incompleteness beats fabricated completion.** Use NOT VERIFIED, NOT IMPLEMENTED, UNRESOLVED where true. Never manufacture PASS. |
| **ND-13** | **Green tests do not override the product.** Render, interact, inspect and judge. |
| **ND-14** | **More capability must not automatically mean more navigation.** Prefer contextual depth and progressive disclosure. |
| **ND-15** | **Global relevance without genericization.** Build so the product can matter globally, but do not erase its governing purpose to imitate generic global SaaS. |

---

## 5. Scope and precedence — a directional authority, not a replacement authority

This document governs **strategic purpose and non-drift**. It does **not**
supersede, dilute, rewrite, or interfere with established product-specific
governance, architecture, doctrine, invariants, operational authority, or
implementation authority.

Existing governing documents remain **fully authoritative within the domains
they were created to govern** — including, without limitation: product-specific
canonical architecture; governance chapters; authority models; representation
doctrine; lifecycle semantics; data invariants; security boundaries;
release-client doctrine; preservation doctrine; commerce doctrine; and
workstream-specific implementation authority.

### The precedence rule

> **Where a more specific established governing authority controls a matter, the
> specific authority continues to govern.**

### When this document legitimately reaches into another domain

Only where materially necessary to:

- preserve the product's governing purpose;
- prevent strategic drift;
- resolve an interpretation that would reduce or mischaracterize the product;
- prevent fundraising optics, feature-count thinking, deadline pressure,
  implementation convenience, or generic industry patterns from silently
  overriding canonical product meaning.

### What this document must never become

- **Do not invoke it merely because it exists.**
- **Do not** rewrite established architecture to make it appear subordinate in
  every technical decision.
- **Do not** convert it into a universal policy layer that must be cited for
  routine implementation.
- **Do not** create precedence ambiguity.

A routine implementation decision inside a domain that already has an authority
is settled by that authority. Citing this document there adds ceremony, not
governance — and a doctrine cited for everything is quickly read for nothing.

### Classify before changing anything

Where an apparent conflict appears, classify it first:

| Class | Meaning | Action |
|---|---|---|
| **DIFFERENT DOMAIN — NO CONFLICT** | The other authority governs a matter this one does not address. | Leave it entirely alone. Link if useful. |
| **FOUNDATIONAL DIRECTION RELEVANT AS INTERPRETIVE LENS** | Both are correct; this document clarifies how to read the other. | Add the lens. Do **not** weaken the other authority. |
| **GENUINE STRATEGIC DRIFT** | The other document reduces or mischaracterizes the product. | Supersede the specific statement, classify the original, preserve it. |
| **TRUE AUTHORITY CONFLICT** | Two authorities genuinely contradict in the same domain. | Escalate and resolve explicitly. Never resolve silently. |

**Never silently supersede a specific governing authority merely because this
document is called "foundational."**

The governing principle: *govern your domain, preserve established authorities,
and intervene across domains only when necessary to prevent strategic drift.*

---

## 6. The institution-grade standard

Before considering major work complete, ask:

1. **Purpose** — Does this strengthen what the product exists to do?
2. **Coherence** — Does this belong to the canonical architecture, or create another parallel truth?
3. **Authority** — Who is legitimately allowed to cause the result?
4. **Provenance** — Can consequential truth explain where it came from?
5. **Continuity** — Will the human, object and history survive changes of screen, client and provider?
6. **Repairability** — Can incorrect state be superseded or repaired without erasing history?
7. **Operability** — Can a real human actually use the capability?
8. **Presentation** — Does the client reveal useful depth without surfacing implementation complexity?
9. **Global relevance** — Does this increase the product's ability to solve a real enduring problem, rather than merely make the interface busier?
10. **Capital independence** — Would we still make this architectural choice if no investor ever saw it?

If the answer to the last one is no, reconsider the choice.

---

## 7. Capital direction

**We are not building products to look fundable.**

We intend to build products sufficiently coherent, valuable, governed and
globally relevant that serious capital may eventually accelerate what is already
demonstrably working.

Investor narratives are **derived from** product truth, operating evidence,
users and customers, revenue, institutional credibility, and demonstrated market
relevance.

**Never reverse this order by modifying product architecture to manufacture an
investor story.**

---

## 8. Agent responsibility

**Coding agents are responsible for preserving product meaning, not merely
completing assigned code changes.**

Before making a change, understand:

- the product purpose;
- the applicable authority;
- whether the change is local or shared-system;
- whether it introduces another competing truth;
- whether documentation must change with it.

When uncertain, investigate repository authority first. **Do not default to
conventional SaaS patterns merely because they are familiar.**

---

## 9. Authority relationship

```
Founder product decisions      →  canonical product direction
Product architecture           →  governs interpretation, structure, acceptance
Engineering agent              →  technical investigation and implementation
                                  beneath those authorities
```

- An implementation report does not supersede architecture.
- A test result does not supersede product truth.
- A recent implementation does not become canonical merely because it exists.

---

## 10. The non-drift invariant

> Implementation convenience, current code shape, fundraising optics, valuation
> narratives, feature count, deadline pressure, or another agent's preferred
> framing may not supersede a product's governing purpose or canonical
> architecture.

> When implementation evidence conflicts with canonical product purpose,
> **investigate the conflict; do not silently redefine the product around the
> implementation.**

---

## 11. This repository's canonical architecture

| Authority | Path |
|---|---|
| Identity, Purpose, Philosophy, Scope | `representation/inventory/PRODUCT_IDENTITY_CANON.md` (external, authoritative) |
| Public-first causal doctrine | `representation/inventory/AURA_PUBLIC_FIRST_CAUSAL_DOCTRINE.md` (external, canonical — never restated) |
| Surface classification (general / person / institution-specific) | `../AGENTS.md` |
| Repository operating law | `AGENTS.md` (this repo) |
| Released-client family rules | `AGENTS.md`, `docs/` |

**ND-4 binds this repository hardest.** It is the client: the place where a
backend model most easily becomes a tab and a controller most easily becomes a
screen. Depth belongs in hierarchy and progressive disclosure, not in navigation
breadth.

## 12. Reading order in this repository

1. **This document** — foundational product direction.
2. `../AGENTS.md` — umbrella guide and the public-first interpretive lens.
3. `AGENTS.md` — this repository's operating law, category guardrail and architecture boundaries.
4. Implementation.
