# Aura 1.4.3 announcement — DRAFT FOR FOUNDER APPROVAL

**Not published. Not publishable by me.** Publishing is a founder act, and this
is a public communication governed by the public-voice rules: the company is the
subject, and governance is never explained to the reader.

## Why this is on the critical path

The store listing's hero screenshot renders the pinned announcement card. Today
that card reads **"Aura 1.4.2 — Communication Should Be Able to Continue"**, so
a 1.4.3 submission would advertise 1.4.2 in the first image a reviewer sees. The
card is server-driven, so a re-capture today reproduces it. The order is fixed:

    publish this  ->  re-capture Home on iOS and Android  ->  G5 can clear
                  ->  Apple and Microsoft unblocked

## The draft

**Slug**

    aura-1-4-3-what-aura-knows-about-you-stays-private

**Title**

    Aura 1.4.3 — What Aura Knows About You Stays Private

**Summary / excerpt**

    What Aura Knows About You Stays Private

**Body**

> Aura 1.4.3 asks for two things when you join — your date of birth and the
> country you are in — and keeps both of them to itself.
>
> Neither appears on your profile. They are used for one purpose: applying the
> age rules that actually govern where you are, rather than a single rule
> applied everywhere regardless of the law that covers you.
>
> This release also brings your personal details together in one place, so you
> can see exactly what Aura holds about you and change it whenever you like, and
> it lets your public profile carry where you are and where to find you when you
> choose to share that.
>
> Members already on Aura stay signed in and keep working. Nothing is withheld
> from you while you decide what to fill in.
>
> Version 1.4.3 is about Aura knowing enough to apply the right rules, and no
> more than that.

## What this draft deliberately does not say

* **Nothing about Finance.** The doorway ships in 1.4.3 but is dormant — no
  grants exist, so it is available to nobody. Announcing a capability the reader
  cannot reach would be false, and it would be the first public statement about
  the company's own books.
* **Nothing about the age numbers.** 13 in the United States, 16 in the EU/EEA
  and the rest of the world are real and correct, but publishing a threshold
  table invites people to shop for a jurisdiction. The paragraph says the rules
  fit where you are; it does not print the table.
* **Nothing about admission versus completeness.** "Members already on Aura stay
  signed in" is the reader-facing consequence. The doctrine behind it is
  governance and is not the reader's business.
* **No apology and no changelog.** The 1.4.2 entry is three short paragraphs
  about what the release is for. This matches that shape.

## One defect found while reading the 1.4.2 record

The published 1.4.2 announcement carries:

    canonicalUrl  https://app.auraplatform.org/announcements/aura-1-4-2-…

`app.auraplatform.org` **301-redirects to `auraplatform.org`** — verified live.
So the canonical URL of every announcement points at a redirect rather than at
the document. Canonical URLs are what search engines and link previews trust, and
a canonical that redirects is a canonical that is wrong.

Not fixed here, because changing it touches published records and is a
communications decision, not an engineering one. Recorded so it is decided rather
than inherited: 1.4.3 should be published with

    https://auraplatform.org/announcements/aura-1-4-3-…

and the 1.4.2 record's canonical should probably be corrected in the same pass.

## After approval

The founder publishes. Then, and only then:

1. Re-capture Home on a real iPhone and a real Android device — the hero shot on
   both stores, showing the 1.4.3 card.
2. Supersede `STORE_LISTING_RECORD_2026-09-06.md` with a 2026-09-10 successor
   rather than editing it.
3. Re-run the G5 check in `STORE_RELEASE_GATE_1.4.3.md`.
