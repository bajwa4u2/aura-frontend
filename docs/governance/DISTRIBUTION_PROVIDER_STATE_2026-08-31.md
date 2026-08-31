# Distribution Provider State — Google Play + Apple App Store

**Date:** 2026-08-31
**Scope:** Provider-console truth for Aura Platform LLC's two Android products
(Aura, Orchestrate) and the Aura Platform iOS submission 1.4.0 (35).
**Authority:** PLATFORM / release governance. Evidence record, not a decision record.
**Constraint in force:** founder/management hold on creating, uploading, or
submitting any new native/store release. No build, binary, rollout, or
submission was created in producing this record.

---

## 1. Google — Android developer verification

**Deadline:** 2026-09-30 (apps not registered are removed from Google Play globally).

### Account

| Field | Value |
|---|---|
| Developer account | Muhammad Sakhawat |
| Account ID | 4989377768267877937 |
| Account type | **Personal** (not Organization) |
| Verification identity | Muhammad sakhawat, 40065 Eaton St Apt 101, CANTON 48187-4528, United States (US) |
| Identity source | Inherited from Play Console developer account; no pending action on the Identity tab |
| Account policy status | No issues found |
| Apps on account | 2 (Aura, Orchestrate) — no third Aura Platform LLC Android app exists |

### Package registration — both REGISTERED, auto-registered 2026-05-08

| App | Package | Status | Keys | Play App Signing |
|---|---|---|---|---|
| Aura | `org.auraplatform.app` | Registered | 3, all Verified | Enabled, one key In use |
| Orchestrate | `com.orchestrateops.app` | Registered | 2, all Verified | Enabled, one key In use |

### Signing-key reconciliation (fingerprints only; no private key material)

**Aura — `org.auraplatform.app`**

| Role | SHA-256 | Registered |
|---|---|---|
| Play app signing key (signs installed APKs) | `9D:20:D5:B2:27:9B:7C:1A:DC:E9:63:51:4F:D2:DF:B8:AE:66:D1:D4:D8:20:CF:99:99:B9:7F:8E:0D:7D:9D:61` | Yes |
| Play upload key = local `android/upload-keystore.jks`, alias `upload` | `84:39:92:54:A2:A1:CA:65:E2:35:17:4D:06:DF:EA:73:2A:B2:28:BB:B9:1A:1C:E9:3F:D8:1B:24:E3:6D:7B:8C` | Yes |
| Unattributed, Google-verified | `0F:AB:9F:B4:FC:68:6F:7C:22:59:BB:0C:F8:B5:41:E4:99:4B:F0:8A:30:28:F2:76:5D:CA:1F:9B:E3:A8:89:09` | Yes |

Local upload keystore: SHA-1 `BF:3F:14:2F:28:59:88:04:DB:AB:46:FC:2E:59:F8:77:EB:85:78:44`,
2048-bit RSA, SHA256withRSA, `CN=Muhammad Sakhawat, OU=Aura Platform LLC,
O=Aura Platform LLC, L=Canton, ST=Michigan, C=United States`, valid to 2053-07-28.
Confirmed identical to the upload key certificate Play holds for this app.

**Orchestrate — `com.orchestrateops.app`**

| Role | SHA-256 | Registered |
|---|---|---|
| Play app signing key (signs installed APKs) | `41:1D:20:19:5F:4A:E7:8B:96:79:A4:59:7D:9C:AF:88:AF:D7:E0:BF:59:DE:E5:B0:52:07:5E:8A:59:52:DA:E3` | Yes |
| Unattributed, Google-verified | `44:BD:A4:CB:DD:17:C8:7E:C3:55:A4:F0:C0:28:6E:A8:70:CE:2D:C0:43:64:9B:F7:C8:07:8E:F0:E8:2F:30:C2` | Yes |
| Play upload key = local `android/orchestrate-release.keystore`, alias `orchestrate` | `1E:91:61:8C:5F:CB:A5:55:00:A1:3C:6C:CA:9E:C4:A3:AB:C5:E4:F0:5C:A5:2A:66:CE:D6:70:53:B2:8C:70:C6` | **No** |

Local keystore: SHA-1 `85:DD:2C:09:98:6F:5D:EA:28:3B:C9:3F:7F:89:10:5C:A6:D3:52:AA`,
4096-bit RSA, SHA384withRSA, `CN=Orchestrate, OU=Engineering, O=Aura Platform LLC,
L=New York, ST=New York, C=US`, valid to 2053-09-23. Confirmed identical to the
upload key certificate Play holds for this app.

**Assessment of the Orchestrate asymmetry.** Not a compliance gap. Android
developer verification governs the keys that sign APKs *installed on devices*.
Under Play App Signing that is the app signing key, which is registered for both
apps. An upload key never signs an installed artifact. It would require
registration only if a locally-signed release APK were distributed outside Play;
no such distribution channel exists (no direct-download APK reference in the
repos, no non-Play publishing target). Aura's upload key is registered only
because Google's automatic population happened to include it. Nothing was added
or removed to make the two apps symmetric — registering a key that signs no
distributed artifact adds no compliance value and widens what is declared.

**Assessment of the unattributed keys.** `0F:AB:…` (Aura) and `44:BD:…`
(Orchestrate) were populated by Google, carry Google's own **Verified** status,
and match neither the local upload keystores, the machine debug keystore
(`24:FE:AB:26:…`), nor the app signing keys. They are left in place. Removing a
Google-verified registered key is a distribution risk with no compliance upside.

### Google verdict

**COMPLIANT — no action required before 2026-09-30.** Both packages registered,
every key Verified, identity present and requiring no completion, no
account-level policy issue, no outstanding verification warning. The Aug 6
Play Console notification is the same generic reminder as the email; it names no
account-specific defect. **Nothing was registered, added, rotated, or changed —
because the console showed nothing left to complete.**

### Open item for the founder (not a verification blocker)

The Play developer account is a **Personal** account whose verified identity is
an individual and a residential address, while the email addressed Aura Platform
LLC, both signing certificates carry `O=Aura Platform LLC`, and the Apple
account is likewise individual (`MUHAMMAD SAKHAWAT`). Android developer
verification publishes the verified identity. Moving to an Organization account
requires a D-U-N-S number, new legal identity evidence, and is a material legal
and commercial decision — it is outside agent authority and is not required to
meet the 2026-09-30 deadline.

---

## 2. Apple — Aura Platform iOS 1.4.0 (35)

| Field | Value |
|---|---|
| App | Aura Platform (`6772071135`) |
| Version | 1.4.0 (35) — **Rejected** |
| Submission ID | `472dba81-4065-4648-8a29-12ff48549ce4` |
| Submitted | 2026-08-30 05:13 |
| Review date | 2026-08-31 |
| Guideline | **Guideline 5 — Legal**, item flagged `5.0.0 Legal: Preamble` |
| Live version | 1.3.0 (24), Ready for Distribution — unaffected |
| Also pending | 1.4.0 (26) Beta Build, Waiting for Review (TestFlight, submitted by API user RKJH5W6GLQ) |

### Exact reviewer finding

> Recently, the Chinese Ministry of Industry and Information Technology (MIIT)
> requested that CallKit functionality be deactivated in all apps available on
> the China App Store. During our review, we found that the app currently
> includes CallKit functionality and has China listed as an available territory
> in App Store Connect. … This app cannot be approved with CallKit functionality
> active in China.

Apple offers a reply path *only* if CallKit is already inactive in China.

### Both limbs verified against product truth

1. **CallKit is present and unconditional.** `ios/Runner/AppDelegate.swift`
   imports `CallKit` and `PushKit`, holds a `CXProvider`, a `CXCallController`
   and a `PKPushRegistry`, configures the provider in `didFinishLaunchingWith`
   and reports every VoIP push to CallKit. A source search for `region`,
   `country`, `locale`, `China`, `NSLocale` in that file returns **nothing** —
   there is no region gate of any kind. `ios/Runner/Info.plist` declares the
   `voip` `UIBackgroundMode`.
2. **China mainland is an available territory.** App Availability = 175
   countries or regions; *China mainland — Available* (Hong Kong and Macau
   likewise, though MIIT applies to mainland).

This capability is new in 1.4.0. 1.3.0 (24) passed review because the binary
had no CallKit — the `Info.plist` comment records `voip` as newly added
("NOW EARNED, AND ONLY NOW").

### Consequence

**A reply to App Review asserting CallKit is inactive in China would be false.**
That path is closed. No reply was sent.

### The two legitimate remediations — this is a founder decision

| | A. Non-binary | B. Binary |
|---|---|---|
| Action | Set *China mainland* to unavailable in App Store Connect | Region-gate CallKit so it is inactive on the China storefront |
| New build required | No | **Yes** — blocked by the release hold |
| Clears rejection | Yes | Yes |
| Cost | Removes a market; delists live 1.3.0 from China, affecting any existing users there | Preserves all 175 markets; Apple states CallKit may continue outside China |
| Character | Material distribution-policy decision | Engineering change |

**Neither was executed.** A is a market decision, not an agent decision, and the
standing instruction is to preserve existing distribution state. B is barred by
the release hold at the build step, and implementing the gate in source now
would silently pre-commit the founder to B.

If B is chosen, the correction is bounded and known: gate `configureCallKit()`
and the `PKPushRegistry` `didReceiveIncomingPushWith` handler in
`ios/Runner/AppDelegate.swift` on storefront/region, falling back to the
existing in-app call surface when the gate is closed. Release consequence: a new
build and a new submission, i.e. the hold must be lifted first.

### Apple verdict — SUPERSEDED 2026-08-31

Founder/management ruled the same day: **Option B authorized**, China mainland
stays in distribution, correct the capability boundary. The source correction is
complete and recorded in
`CHINA_CALLKIT_JURISDICTION_REMEDIATION_2026-08-31.md`; CallKit is now gated on
the App Store storefront, and no build, binary, submission or territory change
was made. Build 35 remains rejected — the correction is in source only, and
clearing the rejection needs a new build the release hold still bars.

### Not affected

Orchestrate Operations (iOS 0.2.1, Ready for Distribution) has no CallKit,
no PushKit, and no `UIBackgroundModes` at all. No same-class exposure.

---

## 3. Governance gap — recorded for PLATFORM

**Finding.** Both of these deadline-bearing provider states — a Google removal
deadline of 2026-09-30 and an App Store rejection dated 2026-08-31 — reached
Aura only because the founder happened to read two emails. Aura has no
governed surface that carries:

- store review status and rejection/issue state per platform;
- provider compliance deadlines;
- developer verification state;
- signing-key registration state per package;
- required operator attention on a distribution account.

The release-governance authority currently records what Aura *ships*. It does
not record what the *providers say about what Aura has shipped*. Every fact in
this document had to be re-derived by hand from two consoles.

**Not built.** No monitoring system was created; this instruction did not
authorize one. This is recorded as an input to the ongoing Admin reconstruction,
where provider evidence — App Store Connect submission state, Play Console
verification and policy state — is exactly the kind of operational truth
PLATFORM should make visible if it can be governed from legitimate provider
evidence.

---

## 4. Distribution state preserved

Verified unchanged by this work: Play closed-testing state for both apps
(Aura 8 testers, Orchestrate 6, both Production Inactive); App Store release
state (1.3.0 live, 1.4.0 (35) rejected, 1.4.0 (26) beta awaiting review);
all signing authority; the release hold; every existing native binary; store
listing identity; App Store availability (175 territories, unmodified).

`NEW_BUILD_CREATED=NO · NEW_BINARY_UPLOADED=NO · NEW_RELEASE_SUBMITTED=NO · ROLLOUT_STARTED=NO`
