# Aura 1.4.3 (38) — release regression matrix

2026-09-09. Verdicts are **PASS**, **FAIL**, **EVIDENCE_LIMITED**, or
**NOT_APPLICABLE**. There are no percentages and no inheritance: a surface
certified on one platform is not certified on another, and a surface that was
loaded but not used is EVIDENCE_LIMITED, not PASS.

Scope comes from `RELEASE_SOURCE_FREEZE_1.4.3.md` — 165 declared client routes
across 12 families, 689 backend route decorators across 95 controllers.

Platforms as exercised:

| Column | What it actually was |
|---|---|
| **Web** | Chromium 148, the frozen `build/web`, **live production API**, signed in through the app's own form |
| **Android** | Pixel 9a, Android 17 (API 37), the 1.4.3 certification variant on real hardware, **live production API**, signed in by hand |
| **Windows** | the 1.4.3 **release** `aura.exe` on this desktop, live production API, session restored from secure storage |
| **iOS** | nothing. No macOS host; Codemagic builds from GitHub and the push is blocked |

---

## A. Product surfaces

| Surface | Web | Android | Windows | iOS |
|---|---|---|---|---|
| App boots, renders | PASS | PASS | PASS | EVIDENCE_LIMITED |
| Public marketing / legal / trust (15 routes) | PASS | EVIDENCE_LIMITED | EVIDENCE_LIMITED | EVIDENCE_LIMITED |
| Sign in (real credentials, real API) | PASS | PASS | PASS (session restored) | EVIDENCE_LIMITED |
| Sign out | EVIDENCE_LIMITED | PASS | EVIDENCE_LIMITED | EVIDENCE_LIMITED |
| **Registration against today's production** | **FAIL** | **FAIL** | **FAIL** | **FAIL** |
| Registration against the merged backend | PASS | EVIDENCE_LIMITED | EVIDENCE_LIMITED | EVIDENCE_LIMITED |
| Age floor refuses an ineligible applicant | PASS | EVIDENCE_LIMITED | EVIDENCE_LIMITED | EVIDENCE_LIMITED |
| Identity: admitted, never walled | PASS | PASS | PASS | EVIDENCE_LIMITED |
| Identity through the shipped `IdentityState` computation | EVIDENCE_LIMITED | EVIDENCE_LIMITED | PASS | EVIDENCE_LIMITED |
| Finance doorway — drawn from a real FinanceGrant | PASS | PASS | PASS | EVIDENCE_LIMITED |
| Finance doorway — absent with no grant | PASS | PASS | PASS | EVIDENCE_LIMITED |
| Finance doorway — absent after revocation, identity intact | PASS | EVIDENCE_LIMITED | EVIDENCE_LIMITED | EVIDENCE_LIMITED |
| Finance handoff — completes into the Finance workspace | PASS | PASS (chain walked) | PASS (chain walked) | EVIDENCE_LIMITED |
| Finance handoff — expired, replayed and duplicate-tap refusals | PASS | PASS | PASS | EVIDENCE_LIMITED |
| Finance — provider outage leaves Aura stable | PASS | PASS | PASS | EVIDENCE_LIMITED |
| Profile — Location (City / Country / Website) | PASS | PASS (read) | EVIDENCE_LIMITED | EVIDENCE_LIMITED |
| Profile tabs (Identity/Authority/Participation/Network/Account) | PASS | PASS | EVIDENCE_LIMITED | EVIDENCE_LIMITED |
| Member core navigation (24 routes) | PASS | PASS | EVIDENCE_LIMITED | EVIDENCE_LIMITED |
| Messaging (8 routes) | EVIDENCE_LIMITED | EVIDENCE_LIMITED | EVIDENCE_LIMITED | EVIDENCE_LIMITED |
| Publishing — composer opens, modes offered | PASS | PASS | EVIDENCE_LIMITED | EVIDENCE_LIMITED |
| Publishing — an item actually published | EVIDENCE_LIMITED | EVIDENCE_LIMITED | EVIDENCE_LIMITED | EVIDENCE_LIMITED |
| Rich content — article editor with toolbar | PASS | EVIDENCE_LIMITED | EVIDENCE_LIMITED | EVIDENCE_LIMITED |
| Media rendering | EVIDENCE_LIMITED | PASS | PASS | EVIDENCE_LIMITED |
| Meetings — routes resolve | PASS | EVIDENCE_LIMITED | EVIDENCE_LIMITED | EVIDENCE_LIMITED |
| Meetings — a meeting actually held | EVIDENCE_LIMITED | EVIDENCE_LIMITED | EVIDENCE_LIMITED | EVIDENCE_LIMITED |
| Realtime / calls — media flowing | EVIDENCE_LIMITED | EVIDENCE_LIMITED | EVIDENCE_LIMITED | EVIDENCE_LIMITED |
| Institution space (41 routes) | EVIDENCE_LIMITED | EVIDENCE_LIMITED | EVIDENCE_LIMITED | EVIDENCE_LIMITED |
| Platform administration (16 routes) | PASS (refusal) | EVIDENCE_LIMITED | EVIDENCE_LIMITED | EVIDENCE_LIMITED |
| Notification permission granted | NOT_APPLICABLE | PASS | NOT_APPLICABLE | EVIDENCE_LIMITED |
| Notification actually delivered | EVIDENCE_LIMITED | EVIDENCE_LIMITED | EVIDENCE_LIMITED | EVIDENCE_LIMITED |
| Monetization is inert | PASS | PASS | PASS | PASS |
| UI interaction by synthetic input | PASS | PASS | **EVIDENCE_LIMITED** | EVIDENCE_LIMITED |

Notes on the entries that are easy to misread:

* **Registration / today's production = FAIL on every platform.** This is one
  defect, not four: `POST /auth/register` carrying the 1.4.3 payload is refused
  by the deployed backend with *"property dateOfBirth should not exist"*. It is
  a property of the client-plus-backend pair, so it fails wherever the client
  runs. It is cleared by deploying the backend, not by changing the client.
* **Platform administration = PASS (refusal).** What was certified is that a
  non-operator is refused: `GET /v1/admin/me` returned 403. The operator
  surfaces themselves are untouched.
* **Messaging = EVIDENCE_LIMITED everywhere on purpose.** The routes resolve,
  but no message was sent, and the reviewer's correspondence was deliberately
  not opened or screenshotted.
* **Windows synthetic input.** Three scripted clicks on the left navigation
  produced no navigation. Reported as it happened rather than retried until it
  looked better, and not promoted from the Web column.
* **The Finance rows are the only ones proven against another product's real
  implementation.** Three passes with the Finance workstream — no grant, a real
  grant, and a revocation — using their service, their database, their session
  and their FinanceGrant. Every other row in this matrix is Aura proving
  something about Aura. The revocation row is Web-only because the grant can be
  revoked once per run and the browser is where the chain was observed
  end to end; the underlying refusal is proven on every platform by the
  outage and no-grant rows.
* **Windows carries the one PASS for the shipped identity computation.**
  `integration_test/identity_certification_test.dart` ran on the Windows
  desktop against the merged backend and passed 4/4, including *"and is NEVER
  held at a completion wall"* and *"an unrecognised admission reads as
  CONTINUITY, never PROSPECTIVE"*. Those assertions run the real
  `IdentityState` provider, not a restatement of it. Web and Android showed the
  same behaviour but observationally — a signed-in member reached Home rather
  than a wall — which is weaker evidence for the same fact, so they stay
  EVIDENCE_LIMITED on this row.
* **Media on Web = EVIDENCE_LIMITED**, and that is the harness: R2 presigned
  URLs do not allowlist `http://127.0.0.1:35143`. The same images render on
  Android and Windows, which is why those two are PASS.

## B. Artifacts and store legality

| Check | Verdict | Evidence |
|---|---|---|
| One frozen source for all artifacts | PASS | re-frozen after the Finance doorway; artifacts rebuilt, none submitted from the stale pair |
| AAB builds, signed, versionCode 38 | PASS | upload key, valid to 2053 |
| Android target API 36 | PASS | packaged release manifest |
| Certification cleartext absent from release | PASS | 0 occurrences of three markers |
| No Play Billing obligation | PASS | no BILLING permission, purchases off on mobile, monetization disabled in production |
| MSIX 1.4.3.0 > live 1.4.2.0, name verbatim | PASS | AppxManifest |
| Apple build 38 unused | PASS | App Store Connect |
| Play versionCode 38 unused | PASS | Play Console |
| iOS IPA exists | **FAIL** | never built |
| Backend deployed | **FAIL** | 30 commits unpushed; `git push` denied |
| Web app deployed | **FAIL** | 24 commits unpushed |
| Play production access granted | **FAIL** | Play Console: *"Apply for access to production"* |

## C. What was never in scope for this pass

Institution administration and the operator console — 57 of 165 routes — were
not exercised. They need an institution-authority holder and an operator
respectively, and the certification account is neither. This is stated as an
absence so it is not mistaken for coverage.
