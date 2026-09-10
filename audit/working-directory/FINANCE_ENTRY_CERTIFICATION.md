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
| `ANDROID_FINANCE_ENTRY` | **PASS** | 11/11 on the physical Pixel, plus a real OS background |
| `IOS/IPADOS_FINANCE_ENTRY` | **EVIDENCE_LIMITED** | no macOS host; the lane is behind the push |
| `ACCESSIBILITY` | **PASS** | header semantics, button label, live-region failure, 48px target, autofocus |
| `RELEASE_CONFIGURATION` | **PASS** | unset is absent; nothing hardcoded |

**Claude-3 has confirmed the Finance side directly**, workstream to workstream,
and the coordination found four further defects that neither suite could see —
three of them theirs, one of them mine:

* their exchange URL was composed with `new URL('/auth/finance/exchange', base)`,
  and an absolute path REPLACES the base's path, silently dropping the `/v1`
  this API requires;
* their `returnTo` named `{origin}/auth/callback` while the route they serve is
  `{origin}/api/auth/callback` — verified against the live origin as 404 and 401
  respectively. That dead address would have been reached AFTER a successful
  authorization;
* their callback ignored the `error=login_required` I introduced and reported
  "that sign-in link is no longer valid", sending the reader to the wrong
  system;
* **mine**: `POST /v1/auth/finance/exchange` was wrapped in Aura's global
  `{ok, data}` envelope while the shared fixture specifies a BARE document and
  their reader parses the body directly. Every real exchange would have failed
  at the subject identifier.

The golden fixture is now **version 2**, authored by the Finance workstream and
adopted here byte-identically rather than retyped, re-pinned in both suites at
`c24b7c53c5d652e8855135cce24774a46694fed82b498ed019a84ae1450c4128`. Version 1
pinned the identity DOCUMENT and was silent on the ENVELOPE, the join rule, the
redirect-must-be-routed rule and the introspection leg — a blind spot exactly
the size of the bug that bit three times.

**The joint live run is DONE** — three passes, both implementations, a real
FinanceGrant, a real Finance session and a real revocation. See §5b. A
cross-product contract is not PASS until both owners prove the same live
journey; this one now has.

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

## 5. Android — 11/11 on the physical Pixel, plus a real OS background

Pixel 9a, Android 17, the certification variant installed **alongside**
production Aura, which stayed at 1.4.2 (37) with `lastUpdateTime` unchanged
throughout and was left as found.

    with a grant, the destination is drawn
    without a grant it is ABSENT — not disabled, not explained, no teaser
    the handoff begins at AURA, and the URL is walked hop by hop to the workspace
    a duplicate tap does not strand the person
    an expired ticket is refused, without explaining itself
    a replayed ticket names nobody the second time
    a provider outage leaves Aura stable and the destination absent
    no financial metadata reaches the doorway
    a revoked grant removes the destination on the next entry
    the destination shown is the one AURA names
    background and resume does not lose or leak the doorway

**By hand, on the real device**, after signing in through the app's own form:
the drawer shows `Version 1.4.3-certification` and an `Aura Admin` entry; the
operator shell's mobile **More** sheet carries Finance with its own icon,
natively composed rather than bolted on; the doorway renders phone-shaped copy
and the destination line reads `http://localhost:35080` — the address **Aura
named**, which a client holding a compiled-in hostname could not have shown.

**The real OS background**, which the test harness cannot do: HOME to the
launcher (foreground became `NexusLauncherActivity`, the Aura process stayed
alive), then brought forward again — and the doorway came back intact, same
destination, same authority chip. Screenshots `android_01_more_sheet.png`,
`android_02_doorway.png`, `android_03_resumed.png`.

### Two Android findings, and they are different from each other

**The launch failed on this device, and it is the device.** Pressing *Open
Finance* produced "Finance could not be opened. Try again." — which is the
correct failure behaviour: one message, no cause named, no fallback to a weaker
path. The cause is that **this Pixel has no browser installed at all**:
`pm list packages` lists none, and `am start -a VIEW` fails from the SHELL,
which is not subject to package visibility. Not a product defect.

**The manifest was missing the browser query, and that IS a product fix.**
Separately from the above, the release manifest declared `<queries>` for
`PROCESS_TEXT` and `GET_CONTENT` and nothing for `VIEW`/`https`. Android 11 and
later filter which packages an app can see; without that declaration
`url_launcher` cannot resolve a browser. Added for `https` and `http`, and the
merge verified in the packaged manifest. Two separate facts — neither one
explains the other away, and reporting only the first would have shipped the
second.

### The harness limit, stated rather than hidden

Driving the binding's lifecycle on a physical handset detaches the test
harness: the run stalled at that line and never returned, costing four later
cases twice before it was understood. It is not `paused` alone — omitting that
transition did not help. On the device the test asserts the half that governs
the doorway's state on return; the full transition IS certified on desktop, and
the genuine background is the adb observation above. Ordering that case last was
not a fix and is not presented as one.

## 5b. THE JOINT RUN — two real implementations, one live journey

The founder's rule is that a cross-product contract is not PASS until both
owners prove the same live journey. This is that run. Not a stub of Finance
written from their controller: **their service, their database, their session,
their FinanceGrant**, against this stack, in a real Chromium.

Configuration, both directions, moved together — a stack that asks the real
service whether to draw the door and then sends the browser to a stub is a
third configuration nobody is certifying:

    FINANCE_SIGN_IN_URL          http://localhost:8081/api/auth/sign-in
    FINANCE_INTROSPECTION_URL    http://host.docker.internal:8081/api/access/introspect
    FINANCE_REDIRECT_URIS        …,http://localhost:8081/api/auth/callback

**Named deviation, agreed by both sides in advance:** Finance ran its API
directly rather than behind its front door. Including the proxy would have
tested their nginx-equivalent rather than the contract, and they verified it
separately. The 404 at `http://localhost:8081/` after redemption is that
deviation — their SPA is not served on an API-only instance — and is not a
failure in the chain.

### Pass 1 — identity succeeds, authority is absent

    localhost:8081/api/auth/sign-in            their service
    localhost:34999/v1/auth/finance/authorize  this service
    localhost:8081/api/auth/callback?code&state their service
    localhost:8081/                            their redirect after redemption

    cookies afterwards:  __Host-finance_state    (set, then cleared)
                         __Host-finance_session  (minted from this document)

Their own session endpoint:

    identityVerified   true
    hasFinanceAccess   false
    principal          prn_01M248YSY27XB6Z1KRX1H9RMGN
    books              []

**That is the architecture's whole point, observed rather than described.**
Identity succeeded and authority is absent, reported as two distinct facts. A
system that collapsed them would tell a founder Aura could not identify him,
and send him to debug the wrong system.

### Pass 2 — a real grant, and a real book — 10/10

With `grt_01M24933BT5129HVK1R6H04HFF` issued on their side:

    /v1/finance/entry   alice -> {"eligible":true}    their grant
                        bob   -> {"eligible":false}   no grant, same endpoint

Bob is the control that makes the rest mean anything: same endpoint, same
client, same code path, different answer, because their database says so.

    the console asked Finance whether to draw it, and Aura where Finance lives
    the destination appeared
    pressing it minted a browser-entry ticket
    the browser went to AURA first and Finance second
    identityVerified true · hasFinanceAccess TRUE
    books  bok_01M2492QGMM26DE79V29YQ23J1  STEWARD

Screenshot `joint_01_door_from_real_grant.png` — the door drawn by their grant,
with the destination line reading `http://localhost:8081`, their real address,
named by Aura's configuration and not compiled into any client.

### What the other side's evidence adds

Their audit trail recorded `auth.signed_in_without_grant` **twice as a SUCCESS
action**, not as a failure — the separation present in the audit surface and not
only in the API. And there is no `access.introspected` row despite many
successful probes including this stack's, which is their audit-polarity fix
holding under real traffic; without it a five-line trail a founder can read
would already be buried.

Their bootstrap dry run reported the principal as *already known to Finance*
rather than *would be created* — the cleanest available proof that the Principal
came from **this** document rather than from their own tool.

Nothing was posted and nothing could be: both books are in SETUP and
`REAL_POSTED_JOURNAL_ENTRIES = 0` in the joint run and in production.

### Pass 3 — REVOCATION — 10/10

The claim neither owner had seen proven against the other's real
implementation. Finance revoked `grt_01M24933BT5129HVK1R6H04HFF` in its own
database. Nothing changed on the Aura side and nothing was restarted.

    /v1/finance/entry   alice -> {"eligible":false}      immediately
    /v1/auth/finance/destination  unchanged              the address is not the authority

    the founder is still signed in to Aura
    the console re-asked Finance on entry
    THERE IS NOTHING TO PRESS — no ticket minted, no handoff begun
    the journey still completes through Aura
    Finance still minted a session
    identityVerified  TRUE
    hasFinanceAccess  FALSE
    books             []
    the principal is still known by name

Screenshot `joint_03_revoked_absent.png`, and it is the single clearest frame in
this whole record. The Finance rail item is **gone** — the rail ends at
External. The header has fallen back to "Now · Aura operator" rather than
announcing Finance over a refusal, because header presentation is gated on the
same authority bit as the destination. The direct route says only *"Not
available. This area is not available for your account."* — nothing naming
Finance, no "request access", no teaser.

And the **`Owner 29`** chip is still sitting in the corner. The most powerful
principal this console can model, holding twenty-nine Aura permissions, and it
buys nothing. `AURA_ADMIN != FINANCE_AUTHORITY` in one frame.

### What the other side confirmed, which cannot be asserted from outside

    grant rows      1  (unchanged — nothing deleted)
    status          REVOKED
    revokedAt/ById  set
    grantedAt       preserved
    reason          preserved
    principal       disabledAt: null — still known, not disabled

Revoking removes FUTURE access and erases nothing, so what that holder
previously authorised stays attributable. Disabling a principal is a different
act for a different reason: that removes the person, this removed the authority.

Their audit trail did something neither of us designed. The ACTION NAME changes
with the authority state — `auth.signed_in_without_grant` before the grant,
`auth.signed_in` after, same person and same code path — so the trail
distinguishes "signed in with authority" from "signed in without" without anyone
reading metadata. It falls out of recording the distinction rather than a
boolean.

### Teardown, and one asymmetry worth recording

Both sides were torn down. They were **not** disposable in the same way, and
this record does not claim they were: the Aura stack's database was tmpfs and
died with its container, while the Finance instance sat on a named volume that
PERSISTS — its throwaway book, principal and revoked grant outlived the run and
were removed deliberately at teardown. The Finance workstream reported that its
first removal attempt failed (`volume is in use`, because the stack had been
stopped rather than brought down) and that its record briefly claimed the volume
was gone while it was not; corrected there, and noted here so the two records
agree on a joint fact.

Attributed to the Finance workstream rather than claimed here: production
Finance now holds **two** audit events — the canonical `book.bootstrapped`, and
an `auth.callback DENIED` from their own diagnostic probe of the live origin
while finding the `returnTo` defect. A callback arriving with no state is
malformed rather than ordinary, so recording it is correct; they disclosed it
rather than letting a reader wonder about it months from now. Nothing in this
run touched production on either side.

### Named deviation on the revocation

Finance executed it through `FinanceGrantService.revoke` from an operator shell
rather than through `DELETE /api/access/grants/:grantId`, because the HTTP path
is capability-gated on a Finance session that lives in a browser. So this run
proves the revocation SEMANTICS — atomic update requiring an active grant, row
preserved, doorway closed, identity intact. It does **not** prove the HTTP
endpoint's capability gate, which is proven separately in their suite against
real PostgreSQL. Recorded so no reader assumes this run covered it.

---

## 5a. iOS — stated, not inferred

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
