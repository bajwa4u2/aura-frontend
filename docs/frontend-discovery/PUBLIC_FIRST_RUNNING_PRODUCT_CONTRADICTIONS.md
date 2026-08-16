# Public-First Doctrine — Running-Product Contradictions Found

**Date:** 2026-08-15 · **Status: C-1 → RESOLVED · C-2 → RESOLVED · C-3 → RESOLVED · C-4 → RESOLVED (no change required).**

Founder-authorised as a narrow **public-first general-entry product copy reconciliation** — copy only. No auth redesign, no account architecture, no layout, no navigation, no behaviour.

Canonical doctrine: `representation/inventory/AURA_PUBLIC_FIRST_CAUSAL_DOCTRINE.md`.

---

## Original disposition (superseded by founder ruling)

The running-product drift rule says correct within the owning task **if safe**, otherwise bring to founder review rather than silently defer. Every item below sits on **auth / register / shared shell** — which is **PD-2 (Authentication & Account Entry)**, an open founder disposition checkpoint with no owning chapter. Editing product copy there would be a product change made inside a doctrine-propagation task, which the task explicitly forbids.

**They are therefore raised, not deferred.**

---

## C-1 — Aura defined as institution operating infrastructure on the most general surfaces

> `Aura is institution operating infrastructure — one verified identity, one accountable record.`

Appears on **sign-in and register**, and the same framing is the repository's own `pubspec.yaml` description:

> `Aura — institution operating infrastructure: the system an institution runs its public and member-facing life on.`

**Why it contradicts:** it states Aura's *general* identity as institution-operating infrastructure. `PRODUCT_IDENTITY_CANON` defines Aura as the system through which institutions **and the public they serve** build a credible, accountable relationship **in both directions** — this copy drops the public side entirely, on the surfaces where a person first meets the product.

**Occurrences:** `shell_shared.dart` · `auth_screen.dart` · `register_screen.dart` · `institution_post_composer_screen.dart` · `founder_message_screen.dart` · `supporters_hub_screen.dart` · `pubspec.yaml`.

Institution-owned surfaces among these (e.g. the institution post composer) are legitimate. The **general** ones are not.

## C-2 — The registration value proposition is entirely institutional

All four benefit lines on `register_screen.dart` (lines 389–395):

- Access institutional resources and announcements
- Verify your affiliation with trusted institutions
- Post publicly and join institutional discussions
- Connect with institutions and build credentials

**Why it contradicts:** registration is the clearest **general/public** surface there is. Every stated reason to join is institutional — the prohibited reverse model, in which institutional arrival is the reason people participate. Even the one public-sounding line qualifies discourse as *institutional* discussions.

## C-3 — Two secondary issues inside those same lines

- **"trusted institutions"** — `PUBLIC_REPRESENTATION_CANON` B.5 bans trust claimed as an attribute ("trusted home", "trusted discovery"). This is the same construction.
- **"Connect with institutions and build credentials"** — **Connect** has no capability anywhere in Aura (C0 established zero Relationship/Connection model; it is gate-enforced absent from Product Language), and **credentials** brushes the credential boundary resolved in C2. This line offers two things the product does not do.

## C-4 — Sign-in continuation copy

> `Sign in to continue your work, conversations, institutions, and meetings.`
> `Continue to your institution`
> `Create your account first. After sign-in, Aura will continue to verify your institution.`

The last implies the personal account exists in service of institution verification — the inverted causal order.

---

## Founder decision required — ANSWERED 2026-08-15

1. *Correct now or fold into PD-2?* → **Correct now.** Do not defer into PD-2.
2. *pubspec description in the same pass?* → **Yes, same pass**; source reconciled, no release work.

The original state of this section is preserved above for chronology. See the RESOLUTION below for what actually changed.

---

# RESOLUTION — 2026-08-15

## One canonical general expression

Derived once from `AURA_PUBLIC_FIRST_CAUSAL_DOCTRINE.md`, `PRODUCT_IDENTITY_CANON.md` and
`PUBLIC_REPRESENTATION_CANON.md`, then adapted only for length. Semantics are identical across
shell, sign-in, registration and pubspec:

> Purposeful public and personal communication · conversations that keep their context ·
> one clear identity · institutions taking part under verified identity, accountable for what
> they say officially.

Register: plain, sentence case, no trust claims, no literary phrasing, no feature-dump.

## C-1 — general Aura identity · RESOLVED

| Surface | Before | After |
|---|---|---|
| `shell_shared.dart` (footer note) | *Aura is institution operating infrastructure. Institutions run their public and member-facing life on one verified identity and one accountable record.* | *Aura is a platform for purposeful public and personal communication, where conversations keep their context and people speak under a clear identity. Institutions take part under verified identity, so what they say officially stays attributable.* |
| `auth_screen.dart` (×2 — narrow + wide layout) | *Aura is institution operating infrastructure — one verified identity, one accountable record.* | *Aura is for purposeful communication and discourse — one clear identity, conversations that keep their context.* |
| `register_screen.dart` (general hero) | *Aura is institution operating infrastructure — verified identity, structured correspondence, and an accountable public record.* | *Aura is for purposeful communication and discourse — one clear identity, conversations that keep their context, and institutions accountable for what they say officially.* |
| `founder_message_screen.dart` | *…Aura is the institution operating infrastructure for the opposite: people and institutions speaking under verified identity…* | *…Aura is built for the opposite: people and institutions speaking under verified identity…* (founder voice otherwise untouched) |
| `supporters_hub_screen.dart` | *Invite thoughtful **users** and institutions who would benefit from institution operating infrastructure.* | *Invite thoughtful **people** and institutions who would benefit from communication that stays attributable and in context.* ("users" → Person is the canonical noun) |

**Left unchanged, deliberately:** `institution_post_composer_screen.dart:160` — a code comment
inside an **institution-owned** surface describing institution publishing. Legitimate under the
general-vs-institution-specific distinction; the problem is reversed causality, not the word.

## C-2 — registration reasons to join · RESOLVED

**Correction to my own earlier report:** the benefit lines are **conditional**, not one list of four.
`isInstitution == true` renders an institution-entry list; `false` renders the general list. I had
conflated them. Only the **general** list was inverted.

| General registration (`isInstitution == false`) | Before | After |
|---|---|---|
| 1 | Post publicly and join **institutional** discussions | **Post publicly and take part in discussions** |
| 2 | **Connect with institutions and build credentials** | **Keep conversations in context with Threads and Spaces** |
| 3 | Structured correspondence with the people that matter | *unchanged — already person-facing, uses a canonical capability name* |

Every line is current capability truth: Public Discourse (Public Posts, Replies); Threads and Spaces;
Correspondence. **No future Live, no network-effect claim, no feature-dump, no institutional
prerequisite for value.**

**Institution-entry list preserved** — institution framing there is legitimate (§7). Only the trust
claim inside it was corrected (C-3).

## C-3 — false semantics · RESOLVED

| Removed | Why | Replacement |
|---|---|---|
| *trusted institutions* (institution-entry list) | `PUBLIC_REPRESENTATION_CANON` B.5 — trust is never claimed as an attribute | *Verify your affiliation with an institution* |
| *Connect with institutions* | **No Connect capability exists anywhere in Aura.** C0 found zero Relationship/Connection model; gate-enforced absent from Product Language. Not replaced with any reciprocal-relationship synonym. | replaced by the Threads/Spaces line |
| *build credentials* | Implies portable/verifiable credentials. Aura issues nothing portable — `ROLE_OR_CREDENTIAL` is an internal governed attestation only (C2 forensic). | removed |

## C-4 — institution verification after sign-in · RESOLVED, NO CHANGE REQUIRED

**Correction to my own earlier report.** I described this as general entry copy. It is not — the code
gates it on `isInstitutionEntry`:

```dart
final title = isInstitutionEntry ? 'Continue to your institution' : 'Join Aura';
final subtitle = isInstitutionEntry
    ? 'Create your account first. After sign-in, Aura will continue to verify your institution.'
    : "Create your account. We'll email you a verification link.";
```

It appears **only** in a genuine institution-entry context, and it already states the correct order:
the person's account first, institution verification after. Per §4 ("preserve or relocate it only
there"), it is **preserved unchanged**. Institution verification is not weakened.

Also re-assessed: *"Sign in to continue your work, conversations, institutions, and meetings."* is a
neutral enumeration, not a causal claim. Left unchanged rather than churned.

## pubspec.yaml · RESOLVED — **two** occurrences, not one

| | Before | After |
|---|---|---|
| package `description` | *Aura — institution operating infrastructure: the system an institution runs its public and member-facing life on.* | *Aura — a platform for purposeful public and personal communication, where conversations keep their context and people and institutions speak under clear, accountable identity.* |
| `msix_config.description` | same stale text | same corrected text |

The MSIX description was a second occurrence my original report missed.

> **PUBSPEC SOURCE DESCRIPTION → reconciled.**
> **APP STORE / STORE-LISTING RELEASE → not performed, not authorized.** No release work initiated.

## Anti-drift gate

`test/doctrine/public_first_causal_gate_test.dart` — hard build failure, 3 tests.

Scoped to a **named list of general/shared/auth surfaces**. It does **not** ban the word
"institution", and institution-owned surfaces are explicitly out of scope — one test asserts that
exclusion so the gate cannot silently become a global vocabulary ban. Proven to fire by
reintroducing the stale phrase into `shell_shared.dart`; probe reverted.

## Verification

`flutter analyze lib/ test/` clean · `flutter test` **508 passed**, 1 skipped, 0 failed.

Two `shell_footer_composition_test.dart` finders pinned the old copy string and were updated to the
new text — **finder text only**; the layout assertions (wide/stacked geometry) are unchanged and
still pass, which is itself the evidence that footer layout did not move.

## PD-2

> **PD-2-ADJACENT PUBLIC-FIRST COPY DRIFT → RESOLVED.**
> **PD-2 STRUCTURAL DISPOSITION → STILL OPEN.**

PD-2 remains the future Authentication & Account Entry structural checkpoint. Nothing about its
structural question was decided here.
