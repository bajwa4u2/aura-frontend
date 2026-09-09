# Permanent Aura → Finance entry — certification

2026-09-09. Aura side. The protocol, the decisions and the configuration are in
`aura-backend/docs/2026-09-09-permanent-aura-finance-entry.md`; this is what was
executed and observed.

Everything below ran against the **isolated certification stack** (isolation
verified 8/8, database empty before any case) and a **relying-party stub** that
mirrors `aura-finance/backend/src/identity/auth.controller.ts` exactly. Never
production.

---

## The verdicts

| Definition-of-done item | Verdict | Where proven |
|---|---|---|
| `AURA_FINANCE_PROVIDER` | **PASS** | 55 unit, 38 e2e |
| `FINANCE_CONTRACT_ANTIDRIFT` | **PASS** | fixture byte-identical, sha256 pinned in both repos |
| `ISSUER_SINGLE_USE` | **PASS** | code and ticket, unit + e2e, mutation-verified |
| `ISSUER_EXPIRY` | **PASS** | unit + e2e |
| `PRINCIPAL_BINDING` | **PASS** | e2e: the document names Alice, never Bob |
| `AUDIENCE_BINDING` | **PASS** | unit + e2e |
| `FINANCE_ENTRY_INTROSPECTION` | **PASS** | live through the stub, both answers |
| `NO_GRANT_FINANCE_ABSENT` | **PASS** | Windows, Chrome, widget |
| `REVOKED_GRANT_FINANCE_ABSENT` | **PASS** | Windows: revoked mid-session, absent on next entry |
| `PROVIDER_FAILURE_AURA_STABLE` | **PASS** | 404/401/timeout/outage all fail closed, console unaffected |
| `NO_FINANCIAL_METADATA_LEAK` | **PASS** | rich payload leaks nothing; no figure or money on the doorway |
| `AURA_ADMIN_AUTHORITY_DOES_NOT_GRANT_FINANCE` | **PASS** | same grant answer, very different operators, identical outcome |
| `WEB_FINANCE_ENTRY` | **PASS** | Chrome, real console, journey completed |
| `WINDOWS_FINANCE_ENTRY` | **PASS** | 5/5 on the real Windows binary |
| `ANDROID_FINANCE_ENTRY` | **EVIDENCE_LIMITED** | the Pixel disconnected mid-session; see below |
| `IOS/IPADOS_FINANCE_ENTRY` | **EVIDENCE_LIMITED** | no macOS host; the lane is behind the push |
| `ACCESSIBILITY` | **PASS** | header semantics, button label, live-region failure, 48px target, autofocus |
| `RELEASE_CONFIGURATION` | **PASS** | unset is absent; nothing hardcoded |

Claude-3 confirming Finance-side compatibility is **owed and not yet given**.
The contract fixture is byte-identical and both suites pin the same hash, which
is evidence but is not the confirmation.

---

## 1. End to end, against the running stack — 38/38

`aura-backend/scripts/identity-certification/finance-doorway-proof.mjs`

Every case asserts the **reason the product gave**, not merely a status: a 400
from a validation slip and a 400 from a refused audience are the same number
and mean opposite things. Covered: destination disclosure and its
principal-independence; ticket issuance, refusal and single use; the start
leg's exact cookie attributes; native and web identification; the code's single
use, state binding, audience binding and expiry; principal binding; the client
credential's requirement and mismatch; malformed refusal; the open redirect
through **both** the happy path and the error path; that a refused attempt does
not consume the code it refused; and that no Aura credential or principal
identity appears in any redirect.

Verified non-vacuous: widening the entry cookie from `Path=/v1/auth/finance` to
`Path=/` made it 37/38, and restoring it made it 38/38 again.

## 2. In a real browser — 17/17

Chromium, real redirects, real cookies. The chain observed hop by hop:

    /api/auth/sign-in  →  /v1/auth/finance/authorize  →  /api/auth/callback

Then: Finance minted its own session cookie and cleared its state cookie;
**reloading the callback refuses cleanly** rather than replaying the code;
**going back** yields no second signed-in workspace; **two simultaneous taps**
both complete and neither strands the person; a browser with **no Aura session**
is told `login_required`, not given access; and no Aura bearer token appeared in
any URL.

## 3. Windows — 5/5, on the real binary

`integration_test/finance_doorway_certification_test.dart -d windows`

Real Windows binary, real networking stack, real plugin registration, real
widget tree, live backend, live relying party. With a grant the destination is
drawn; without one it is **absent** — not disabled, not explained, no teaser,
no mention that a Finance system exists. Pressing it mints a browser-entry
ticket and hands over a URL that begins at **Aura**, and that URL is then walked
hop by hop to the Finance workspace page. A grant revoked mid-session removes
the destination on the next entry.

**Not certified here:** it does not drive the operating system's browser. The
URL is captured and walked with an HTTP client, which proves the URL is right
and the chain completes; that this platform's browser renders it is a separate
human observation.

## 4. Chrome, in the real Admin console — 11/11

The 1.4.3 web client built against the certification stack, signed in, walked
into `/admin/finance`. Finance appears in the operator rail with its own icon;
the doorway renders its explanation and its action; the destination line reads
**`http://localhost:35080`** — the address **Aura named**, which a client
holding a compiled-in hostname could not have shown. Pressing it mints a ticket,
the tab goes to **Aura first and Finance second**, and arrives at the Finance
workspace signed in as the right principal with `admissionBasis: PROSPECTIVE ·
contract v1`. With no grant there is nothing to press.

Screenshots: `ui_02_finance_door.png`, `ui_03_arrived_in_finance.png`.

## 5. Android and iOS — stated, not inferred

**Android is EVIDENCE_LIMITED because the device is not attached**, not because
anything failed. The Pixel 9a was connected earlier in this session and
disconnected before this work reached it. The certification is one command once
it is plugged in, and needs no new code:

    adb reverse tcp:34999 tcp:34999
    adb reverse tcp:35080 tcp:35080
    flutter test integration_test/finance_doorway_certification_test.dart -d <device>

The debug source set already permits cleartext to `localhost` and to nothing
else, and the release manifest declares no `networkSecurityConfig` at all.

**iOS/iPadOS is EVIDENCE_LIMITED** for the standing reason: no macOS host here,
and Codemagic builds from GitHub, so the lane sits behind the unpushed commits.
iPad composition is proven at tablet geometry in the widget suite and by the
layout rule's own unit test, which is not the same as a simulator run and is not
reported as one.

---

## 6. What certification found that review had not

**The door could never have drawn.** The API answers `{ ok, data }`; the
Finance reads took `body['eligible']` off the envelope, always found null, and
resolved to "no destination". It would have been permanently absent in
production no matter what Finance answered. It survived review and a green suite
because both client fakes returned **unwrapped** bodies — so thirty-two tests
agreed with each other about a wire format that does not exist. Found on
Windows, against the real stack, in the first minute of running there.

**Two unit tests passed under mutation.** The single-use tests, because the
Prisma fake hard-coded `usedAt === null` and enforced single use no matter what
the query asked; and the open-redirect test, because it asserted a refusal that
a mutated build still produced through another path. Both were rewritten until
they failed.

**A source-shape assertion had gone quiet.** "The console reads exactly one
field from Finance" looked for `body['…']` and stopped matching when the read
was rewritten, so it was passing over a method it could no longer see.

**A layout rule was not monotonic.** Asserting that the doorway's measure never
decreases as the pane widens found that crossing 700 pixels took the content
from 690 wide to 604 — widening a window narrowed the text.

**The relying-party stub diverged from Finance.** It did not clear its state
cookie after the callback, which the browser certification caught on the reload
case. Fixed to mirror Finance's controller.
