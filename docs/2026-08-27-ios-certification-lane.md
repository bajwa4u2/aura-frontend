# Aura iOS Certification Lane

**Purpose:** retire `IOS = PENDING_MACOS_HOST` as a default answer.
**Date:** 2026-08-27

---

## 1. What the boundary actually was

Every chapter closed iOS as `PENDING_MACOS_HOST`. That was literal and correct:
the development machine is windows-arm64 and cannot build, boot, or exercise
anything iOS.

But it was never the whole truth. **Codemagic is a macOS host**, it has been one
all along, and it has produced 16 signed Aura builds. The boundary was not "no
Mac". It was "no Mac workflow that runs the certification suites".

That is now fixed. What remains is a narrower and more honest boundary:
**no physical iPhone**.

---

## 2. Two lanes, and the difference between them

| | Runs on | Certifies | Status label |
|---|---|---|---|
| **Codemagic simulator** | macOS host, iOS Simulator | properties of the **app** | `SIMULATOR_CERTIFIED` |
| **Physical iPhone** | real hardware | properties of the **device** | `RELEASE_CERTIFIED` |

A simulator run must never be reported as physical-device evidence. It cannot
see a camera, a microphone, a Bluetooth route, a real network transition, or a
push delivery — and those are precisely the things the A/V chapter needs.

### Lane A — Codemagic (established, working)

```
main branch
  → codemagic.yaml : ios-certification
  → mac_mini_m2, newest available iPhone runtime
  → integration_test suites
  → certification/ artifacts + run-manifest.txt
```

- **No signing.** A simulator build is unsigned, so this workflow carries no
  `ios_signing` block and no App Store Connect integration. No Apple credential
  is duplicated to reach a test runner.
- **Manual trigger, deliberately.** No `triggering:` block, matching the
  existing policy that a push must not start a build.
- The runtime is chosen **at run time**, not pinned — a pinned runtime silently
  stops existing when Codemagic updates Xcode, and the failure then looks like
  a test failure rather than an environment one.

### Lane B — physical iPhone (blocked, see §4)

```
codemagic.yaml : ios-testflight
  → signed IPA (App Store distribution, build 24 and rising)
  → AWS Device Farm  ← BLOCKED
  → physical iPhone
```

---

## 3. Codemagic — inspected

| | |
|---|---|
| App | `aura-frontend` → `github.com/bajwa4u2/aura-frontend` |
| Workflow | `ios-testflight` — "Aura iOS — TestFlight" |
| Instance | `mac_mini_m2`, Xcode latest, Flutter stable |
| Signing | **App Store Connect API key integration** ("Aura Platform LLC"), automatic managed signing |
| Certificate / profile | created and held by Codemagic from the API key — none committed, none exported |
| Bundle id | `org.auraplatform.app` |
| Distribution | `app_store` |
| Output | `aura.ipa`, **16 builds, latest #16 = build 24** (2026-08-05) |
| TestFlight | `submit_to_testflight: true` |
| Trigger | manual only, by design |

No Apple ID, no password, no `.p8`, no `.cer`, no `.mobileprovision` in the
repository. That posture is preserved unchanged.

---

## 4. AWS — inspected, and blocked

| | |
|---|---|
| Billing console | reachable |
| Credits | **$100.00 AWS Free Tier**, issued 2026-08-21, expires 2027-08-21, **$0.00 used** |
| Account plan | **Free plan / registration incomplete** |
| Device Farm console | **redirects to `signup.aws.amazon.com/billing/signup/incomplete`** |

AWS states: *"you have either not finished registering, or your account is
currently on free plan… Free account plans have limited access to certain
services and features."*

The redirect reproduced on every attempt and on two regions. **Device Farm is
not reachable on this account today.**

### What unblocks it — founder action, not delegable

Either completing registration (payment method + identity verification, with a
~$1 authorization hold) or upgrading to the Paid account plan. Both are
account-security and billing actions. I am not permitted to enter payment or
identity details, and this cannot be delegated.

**EC2 Mac was not provisioned and is not required.** Codemagic already supplies
every macOS capability this lane needs — Xcode, simulators, signing, IPA
export. Provisioning an EC2 Mac would incur the Apple-mandated 24-hour
dedicated-host minimum for nothing.

---

## 5. Apple secrets do NOT need to move to AWS

`APPLE_SIGNING_SECRETS_IN_AWS = NOT REQUIRED.`

Device Farm **re-signs** every iOS app it installs: it replaces the embedded
provisioning profile with a wildcard profile and signs with its own identity.
It therefore needs no Apple credential from us — only an `.ipa` built for the
**iOS Device** target, which `ios-testflight` already produces.

The simpler architecture holds: **Codemagic signs, Device Farm executes.**

### The cost of that re-signing, which matters for A/V

Re-signing **removes** entitlements: App Group, Associated Domains, Game
Center, HealthKit, HomeKit, Wireless Accessory Configuration, In-App Purchase,
Inter-App Audio, Apple Pay, **Push Notifications**, VPN Configuration.

Aura declares **Push Notifications** and **Associated Domains**. Both are
stripped on Device Farm public devices. Camera and microphone are *not*
entitlements — they are `Info.plist` usage descriptions — so they survive.

Skipping re-signing requires **private devices** (a dedicated paid device
arrangement), which is the only path to certifying push or universal links on
Device Farm.

---

## 6. A/V capability matrix

For the upcoming A/V → Meetings → Realtime work, against Device Farm public
devices once the account is unblocked.

| Behaviour | Classification | Why |
|---|---|---|
| Microphone permission prompt | AUTOMATABLE | usage description survives re-signing |
| Camera permission prompt | AUTOMATABLE | as above |
| Front / rear camera selection | AUTOMATABLE (capture only) | device has cameras; the scene is a rack |
| Camera switch | AUTOMATABLE | a UI + capture-session assertion |
| Mute / unmute | AUTOMATABLE | app state, not acoustics |
| Video toggle | AUTOMATABLE | app state |
| Call accept / decline / leave | AUTOMATABLE | app + signalling |
| Meeting join / leave / cleanup | AUTOMATABLE | app + signalling |
| Remote media rendering | AUTOMATABLE | needs a second synthetic participant |
| Multi-participant media | AUTOMATABLE, hard | needs orchestrated peers, not two farm devices |
| Background / foreground / resume | AUTOMATABLE | lifecycle events |
| Network change | AUTOMATABLE | Device Farm supports network shaping profiles |
| **Audio output routing** | INTERACTIVE_ONLY | no human ear; no speaker verification |
| **Bluetooth / AirPods** | DEVICE_FARM_LIMITATION | no pairable accessories in the fleet |
| **Real call interruption** | DEVICE_FARM_LIMITATION | no SIM / cellular voice |
| **Push notification delivery** | DEVICE_FARM_LIMITATION | entitlement stripped by re-signing |
| **Universal links** | DEVICE_FARM_LIMITATION | Associated Domains stripped |
| **Actual audio/video quality** | REQUIRES_FOUNDER_IPHONE | a human has to watch and listen |

**Nothing in the left column is certified by an automated run alone.** An
automated pass says the app did not crash and the state machine behaved. It
does not say a person could hear the other side.

---

## 7. Roles — all three coexist

| | Role |
|---|---|
| **Codemagic** | build and sign authority; simulator certification |
| **AWS Device Farm** | repeatable hosted physical-device certification *(pending account)* |
| **TestFlight + founder iPhone** | founder-visible acceptance, and the only route today for anything a person must see or hear |

TestFlight is **not** retired. It is the acceptance lane, and for audio quality
and Bluetooth it is the *only* lane.

---

## 7a. FALSE-GREEN INCIDENT — recorded, not quietly fixed

**2026-08-27, first 15-suite run.** Three suites were recorded `PASS` having
certified nothing:

| Suite | What it printed | Recorded | Truth |
|---|---|---|---|
| `sfu_multiparty` | certification identities not provided | ~~PASS~~ | **NO_COVERAGE** |
| `sfu_thread_call_parity` | certification identities not provided | ~~PASS~~ | **NO_COVERAGE** |
| `sfu_transport_seam` | certification identities not provided | ~~PASS~~ | **NO_COVERAGE** |

Each skipped every substantive test and exited 0. The lane read the exit code.

**The rule this froze:**

> CERTIFICATION STATUS DERIVES FROM DEMONSTRATED COVERAGE, NOT COMMAND SUCCESS.

`scripts/certify_suite.py` now parses the runner's JSON stream and derives
status from what executed. Hidden bookkeeping entries — the loading and
setUp/tearDown records the runner emits, which always succeed — are excluded
from every count, because counting them is exactly how an all-skipped suite
looks green.

| Status | Meaning |
|---|---|
| `PASS` | at least one substantive test ran, and all of them passed |
| `FAIL` | at least one failed or errored |
| `NO_COVERAGE` | applicable, ran, asserted nothing |
| `SKIPPED_PLATFORM` | deliberately inapplicable to this client |

Counts captured per suite: discovered, executed, passed, failed, skipped, and
the skip reasons. A run containing any `NO_COVERAGE` is `INCOMPLETE`, never a
pass — a hole is not a success.

**Proven against both controls**, not assumed: a real suite reports
`PASS (discovered 6, executed 6)` and exits 0; a suite whose every test skips
with "certification identities not provided" reports
`NO_COVERAGE (discovered 2, executed 0, skipped 2)` and exits 2, where the old
lane reported PASS and exited 0.

---

## 8. Certification artifacts

Every `ios-certification` run seals `certification/run-manifest.txt`:

```
build_commit, build_number, branch,
runtime, device_type, simulator_udid,
xcode version, flutter version,
started_at, finished_at
```

plus per-suite logs. That makes the required sentence answerable: *this exact
Aura build ran on this exact iOS runtime and produced this result.*

Device Farm adds video, device logs and crash output per run, and records
video for interactive sessions (150-minute maximum).

---

## 9. Security posture

- Apple signing stays in Codemagic's secure environment. Not exported, not
  mirrored, not downloaded.
- The certification workflow holds no credential of any kind.
- No secret is committed, printed, or moved between providers.
- AWS resources stay under AWS IAM.

---

## 10. Status

```
CODEMAGIC_IOS_WORKFLOW            = ESTABLISHED (build + certification)
APPLE_SIGNING_AUTHORITY           = Codemagic, App Store Connect API key
SIGNED_IPA                        = PROVEN (16 builds, latest build 24)
APPLE_SECRET_MIRROR_TO_AWS        = NOT REQUIRED
AWS_DEVICE_FARM                   = BLOCKED — account plan / registration
EC2_MAC                           = NOT REQUIRED, not provisioned
IOS_SIMULATOR_CERTIFICATION       = see §11 of the chapter return
PHYSICAL_IPHONE_PROOF             = NOT YET
```

**`IOS = PENDING_MACOS_HOST` is retired.** It is replaced by two precise
statuses: `SIMULATOR_CERTIFIED` where the simulator is sufficient, and
`PENDING_PHYSICAL_IPHONE` where it is not.
