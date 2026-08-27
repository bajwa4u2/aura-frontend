# Preferences Reconstruction

**Chapter:** bounded product-surface chapter before A/V → Meetings → Realtime
**Date:** 2026-08-27
**Status:** see Completion, below

---

## 1. The state that was found

Preferences was reached from two places, and both were mislabelled.

| Entry point | Label | Opened | What that screen is |
|---|---|---|---|
| Account menu | **Preferences** | `/me/settings/communications` | notification channel + frequency |
| Account menu | **Settings** | `/security` | sessions, password, sign-in history |
| Left drawer | **Preferences** | `/me/settings/communications` | (same) |
| Left drawer | **Settings** | `/security` | (same) |
| Profile "Settings" section | — | Security, Devices | never mentioned communications |
| Own-profile header | **Settings** | `/security` | *(found adversarially)* |
| `/settings` legacy alias | — | `/security` | *(found adversarially)* |

**There was no Preferences landing.** Three partial hubs each answered part of
the question and none answered *where do I change how Aura works for me*.

### Authorities that existed

| Authority | Endpoint | Real? | Had a surface? |
|---|---|---|---|
| CommunicationPreference — 12 categories × channel/frequency | `/communications/preferences/me` | yes, consumed by the routing service | yes |
| Sessions | `/auth/sessions` | yes | yes |
| Trusted devices | `/auth/trusted-devices` | yes | yes |
| Push/call devices | `/devices/me` | yes | yes (separate screen) |
| Sign-in history | `/auth/login-activity` | yes | yes, **unbounded** |
| **UserBlock** | `/blocks` GET/POST/DELETE | yes | **block only** |

**`unblock()` had no caller anywhere in the app.** `GET /blocks` was consumed
only to build an id set for hiding content; the people were never shown. A
person could block someone and then had no way to see the list or undo it —
a one-way door built on an authority that already supported the way back.

### Classified

- **Stale:** "Failed password", "Sign-in via trusted device", raw enum names
  printed at a person, `3d ago` / `12/8/2026` from two local formatters.
- **Duplicated:** two navigation entries for one idea; "Devices" meaning two
  different authorities in two places.
- **Misplaced:** communication preferences absent from the profile hub.
- **Dead:** none found — every control had a real authority behind it.
- **Missing from an existing authority:** unblock, and the blocked list.
- **UI-only with no authority:** none found.

---

## 2. New information architecture

```
Preferences  (/me/preferences)
├─ Account          Profile · Password
├─ Notifications    How Aura reaches you
├─ Security         Sign-in and access · Your devices
├─ Privacy          Blocked people          ← new surface, existing authority
└─ Data and account Delete your account
```

Derived from the authorities that persist. **No Appearance group**: Aura is
single-theme, so a theme control would be a row that changes nothing — the
exact failure this chapter exists to remove.

### Scope of every preference

| Preference | Scope | Correctly implemented as |
|---|---|---|
| Communication channel/frequency | ACCOUNT | account (server) |
| Blocks | ACCOUNT | account (server) |
| Sessions | ACCOUNT, per-session rows | account (server) |
| Trusted devices | ACCOUNT, per-device rows | account (server) |
| Push devices | ACCOUNT, per-device rows | account (server) |

Nothing device-local is presented as account-wide, and nothing account-wide is
implemented device-locally.

---

## 3. The three things called "device"

The word covered three authorities and nothing told them apart.

| Was | Is | Means |
|---|---|---|
| "Other active sessions" | **Where else you are signed in** | `/auth/sessions` |
| "Trusted devices" | **Devices that skip verification** | `/auth/trusted-devices` |
| "Devices" | **Your devices** | `/devices/me` — calls and notifications |

## 4. Sign-in history

Rendered **every** event the endpoint returned, inside a panel with no height
of its own. Bounded at six, with the remainder disclosed rather than hidden:
*"N older sign-ins not shown."* Elapsed time now goes through `AuraTemporal`.

---

## 5. Proof

### Lifecycle, against production

```
communication preference   read BOTH → write NONE → read back NONE → restored BOTH
block                      list 0 → block → listed WITH IDENTITY → unblock → list 0
```

Both round-trips ran against the live API with the review account and restored
the original state exactly. The consequence step is verified in code:
`communication-routing.service.ts` derives `inApp` from `channelFor`, so
`NONE` suppresses delivery, with transactional messages correctly overriding.

### Certification

| Client | Result |
|---|---|
| Windows | RELEASE_CERTIFIED — 6/6 on the real desktop client |
| Android | RELEASE_CERTIFIED — 6/6 on a physical Pixel 9a |
| Web | UNVERIFIED — deployed; the Flutter canvas does not respond to synthetic input under automation |
| iOS | PENDING_MACOS_HOST |

Suite: 1786 client tests green, including 16 Preferences tests.

---

## 6. Adversarial findings

Found by searching for what still pointed at the narrow screens, rather than by
trusting the two entries already changed:

1. **`/settings` legacy alias resolved to `/security`** — anyone following an
   old link went straight past everything except sessions.
2. **The own-profile header carried a FOURTH "Settings" action** to `/security`.

Both closed and pinned by test.

Also checked and clean: no dead controls; no persistence without a consumer;
no scope confusion; no institution/person authority mixing (Preferences is
person-only, per the public-first doctrine); no destructive action without
consequence stated on the row before it is tapped.

---

## 7. Gates obeyed

Four pre-existing architectural gates caught this work and were satisfied
rather than bypassed — the route-literal ratchet, the humanized-time ratchet,
the local-timezone ratchet, and the full-surface-spinner rule. Four burn-downs
recorded (`shell_header_tools` 4→2, `me_screen` 16→14, `author_profile_screen`
5→4, `security_screen` G2 6→3 / G3 2→1, `devices_screen` G2 3→0).

---

## 8. Residuals

- **`_PremiumPanel` / `_SectionedPanel`** are local duplicates of `AuraCard` in
  `security_screen.dart`. They use the same design tokens, so the divergence is
  structural rather than visual. Converging them means rewriting that screen's
  layout system, which is beyond a bounded chapter.
- **Web interaction unverified** — same automation boundary as the Trace chapter.
- **iOS** — no macOS host.

## 9. Deferred adjacent systems

Untouched, deliberately: authentication generally, profiles generally,
notification infrastructure, Follow, media, institutional administration,
**Meetings**, A/V, realtime topology, shell navigation beyond the two entry
points this chapter owns.
