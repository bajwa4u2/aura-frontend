# Aura — monetization switch-on plan (2026-10-07)

**Status: APPROVED by the founder 2026-10-07 ("good, I am in"; all §2 numbers approved as proposed, including population bands and the 90-day public-body pilot agreement). Nothing is built or switched on yet; work starts at WP0.**
Governing decisions: `DECISIONS.md`, entries of 2026-10-07 ("The public is free; institutions pay" — decisions 1–5; "Prices are public from day one; … 30-day grant"). Evidence: four research streams and two code audits of 2026-10-07 (app-store/payment rules, market practice, institutional buying, code readiness, public-vs-institution map).

## 1. The model (decided)

- **The public is free, permanently.** Reading, following, joining, posting, AI writing help, author-side translation, reader translation, calls. Protected by daily fair-use limits. No person is ever charged; no personal credits; no Patron/Sustainer tiers.
- **Institutions pay**, on the web (Stripe card or invoice/ACH). The apps sell nothing; they show "manage your plan on the web".
- **Tiers by staff seats.** Staff = Owner, Admin, or anyone holding a capability grant (speaks officially, runs spaces, hosts meetings). Community (plain members) and followers are unlimited and free at every tier.

| Tier | Monthly | Yearly (10×) | Staff seats |
|---|---|---|---|
| Community | $49 | $490 | 3 |
| Organisation | $249 | $2,490 | 15 |
| Public body | $1,490 | $14,900 | Unlimited |

- **Pro includes:** official voice; a monthly allowance for AI checks on institution posts and publish-time translation; meetings and rooms within a fair-use cap (not metered).
- **Discount:** 25% for nonprofits and schools — **only when the institution's CONFIRMED existence proof category is `NONPROFIT_COMMUNITY` or `EDUCATIONAL`** (self-edited profile fields are not proof).
- **Grant:** on request, founder approves; 30 days of Pro + 500 credits; once per institution; no card; nothing charged at the end; the institution keeps everything and returns to Free unless it subscribes.
- **Verification is never purchasable** (boundary test stays).

## 2. Numbers proposed for founder approval

| Item | Proposal | Reasoning |
|---|---|---|
| Public daily fair use | 30 AI writing checks, 30 author-side translations a day; reader translation keeps its existing rate limit; calls up to 8 people, 3 h per call | Generous for a real person; stops scripted abuse. AI lane cost is a fraction of a cent per use. |
| Monthly allowance (shown as "AI checks" and "translations", not "credits") | Community 1,000 · Organisation 5,000 · Public body 20,000 | Covers normal use so top-ups are rare. Typical cost on the AI lane: a few dollars a month even at Public-body volume. |
| Allowance behaviour | Resets monthly, no rollover; **purchased top-ups never expire** | Market norm; avoids the "credits vanish" resentment. |
| Top-ups (institutions only, web) | 1,000 for $19 · 5,000 for $79 | ~2–4¢ per use; ≥3× cost on the AI lane. |
| Meetings and rooms fair use | Community up to 50 people, 10 h/month · Organisation 300 people, 40 h/month · Public body 1,000 people, 120 h/month | Inside Cloudflare's free 1,000 GB at current scale. |
| Public body population bands | Under 10,000 residents: $490/mo or **$4,900/yr** · 10–50k: $990/mo or **$9,900/yr** · Over 50k: $1,490/mo or **$14,900/yr** | Matches how civic tools price; the smallest band sits under the common $5,000 no-bid limit. **Approved 2026-10-07.** |
| Public body pilot path | A written no-cost pilot agreement ending on a set date (up to 90 days), separate from the 30-day grant | Cities decide by council and budget (≈3-month cycles, July 1 budgets), not by one person. **Approved 2026-10-07.** |

## 3. Work, in order

### WP0 — Fix the six money defects first (with tests)
1. A voluntary cancellation keeps Pro forever (`stripe.provider.ts` ~491–512 downgrades only after 14 days past-due). → Downgrade at period end on `customer.subscription.deleted` regardless of past-due history.
2. Refunds never reverse credits; a refunded plan stays Pro. `PaymentTransaction.externalId` stores the checkout session id (~117–121) while the refund handler looks up charge/payment-intent (~581–593). → Store the payment intent; reverse credits; downgrade refunded plans.
3. Webhook events can be lost: recorded in `ProcessedWebhookEvent` before processing, outside a transaction (~198–223). → Record inside the same transaction as the effect, or mark-complete after success.
4. `.env.example` sets every cost to 0 and `amount<=0` skips all gates. → Refuse to start in `soft_enforce`/`enforce` with zero costs; fix the example.
5. `soft_enforce` with no credits: provider runs, debit throws, fallback calls the provider again, user gets nothing. → Check before calling; never call twice; public path never debits.
6. Two quick checkouts can both succeed before any webhook. → Idempotent checkout per institution (reuse open session / existing customer).
Plus: checkout must respect the monetization mode; subscription updates must not default a missing plan to PRO (~388, 397); add Stripe/entitlement tests (none exist today).

### WP1 — Staff seats
- Seat = active `InstitutionMember` with role OWNER/ADMIN or any capability grant. Community members never count.
- Check seats when a role is raised or a grant is given (today the limit is checked only on invite-accept/join-approve and counts everyone; owner bootstrap and re-activation bypass it; count-then-create races).
- Downgrade or grant expiry over the seat limit: nobody is removed; new seats are blocked; owners get a notice.
- Existing institutions created with `memberLimit = null` get their plan's seat limit applied.

### WP2 — Plans and billing
- Tier identity (Community / Organisation / Public body + population band) separate from `memberLimit`; product codes and Stripe prices per tier and interval (monthly/yearly).
- Invoice + ACH for Public body (net-30, PO number field); card for the rest.
- Customer portal or change/cancel endpoints; proration on upgrade.
- Nonprofit/school discount as a Stripe coupon applied only from the confirmed proof category.
- Frozen FREE/PRO test updated by founder decision; verification boundary test unchanged.

### WP3 — Who is charged
- `/composition/review` and `/composition/translate` charge the **institution's allowance** when the writer acts for an institution (announcement editor, institution composer); otherwise they are free for the person under the daily fair-use counter.
- Retire person-side charging (`User.creditBalance` paths in `monetization-entitlement.service.ts`). Keep the ledger history.
- Reader translation stays platform-funded.
- **Verify production's translation lane** (code default is Google first, then OpenAI; Azure only if enabled). Make the AI lane the default for publish-time translation; Google only as a fallback.

### WP4 — Monthly allowance
- Two buckets: monthly allowance (granted on the 1st via `GRANT`, resets, no rollover) and purchased top-ups (never expire). Spend the allowance first.
- Usage meter on the institution billing screen; notices at 80% and 100%.

### WP5 — Institutional Grant
- Request form for institution owners; founder approve/decline surface; on approval: Pro (`TRIALING`) for 30 days + 500 credits (`GRANT`).
- Once per institution, and once per verified person across institutions they own (today one person can create many institutions in sequence).
- Expiry job; notices on day 23 and day 30; soft landing to Free with nothing lost.

### WP6 — Meetings and rooms fair use
- Caps per tier from §2 (participants per meeting, hours per month); clear message at the cap; no metering against the allowance.
- Remove the unused per-minute realtime credit costs from config and copy.

### WP7 — Remove person-side money surfaces
- Delete `support_screen.dart` (Patron $5 / Sustainer $20) and the Patrons hub; remove routes.
- Billing screens in the apps: plan, usage and "manage on the web" — no purchase buttons inside iOS/Android/Windows apps.

### WP8 — Words and documents
- Deck: remove "four payment providers implemented" (three are stubs), "paid by use in every plan", the person-side support tiers; publish the prices.
- `AGENTS.md` ("4 plan tiers"), `docs/strategy/AURA_STATE.md`, company finance docs (`subscription-models.md`, `pricing-philosophy.md`) aligned to the decided model.

### WP9 — Paperwork pack before selling to a public body
W-9; certificate of insurance (general liability + $1M cyber, $2M available); HECVAT Lite / K-12CVAT answers and a security summary; VPAT/ACR against WCAG 2.1 AA (ADA Title II deadlines 26 Apr 2027 / 26 Apr 2028); records statement (Michigan FOIA, retention, export; moderation consistent with *Lindke v. Freed*); Michigan NDPA v2.1 for schools; a government order form (Michigan law, non-appropriation clause); MITN registration; SAM.gov/UEI if federally funded buyers are expected.

### WP10 — Switch-on sequence
`disabled` → `visible` (prices and meters shown, nothing blocked) → `enforce`. Each step only after the previous WP's tests pass and the founder approves.

## 4. Decisions still open
None. All §2 numbers approved as proposed on 2026-10-07.
