# Aura — Maintenance Mode Policy

This document is the source of truth for how Aura puts the platform into
or out of maintenance. **There are two flags in the codebase that share
the word "maintenance". Only one is canonical.**

---

## TL;DR

| Flag | Status | Use it? |
|---|---|---|
| `ClientPolicy.maintenanceMode` (per distribution × channel) | **Canonical.** Drives `GET /v1/client/compatibility` → `UpdateGate`. | ✅ Yes — this is the operator control. |
| `featurePolicy.maintenanceMode` (one-flag-fits-all) | **Legacy.** Stored on the `admin.policies` `PlatformSetting` row. No code consumes it for runtime gating. | ❌ No — retained for backward compatibility with the existing settings record only. |

If you want a banner / blocking screen / maintenance page to appear for
real users, you change a `ClientPolicy` row. Touching
`featurePolicy.maintenanceMode` does nothing observable today.

---

## Why two flags exist

`featurePolicy.maintenanceMode` predates the cross-platform release
governance system. It was meant to be a one-flag global maintenance
switch. Slices B + C of the release governance work
(`docs/RELEASE_GOVERNANCE_DESIGN`, the `ClientPolicy` table, the
`UpdateGate` widget, the `/v1/client/compatibility` endpoint) replaced
it with a per-distribution / per-channel control because:

* a one-flag global switch can't express "show maintenance to web
  clients only while we re-deploy the API" or "block android-direct
  builds older than 1.0.5 only";
* the per-policy model carries the same maintenance/`forceUpdate`/
  `protocolGenerationsAccepted` axes the rest of governance needs;
* keeping a second global gate would create two contradictory truths
  about whether maintenance is on.

The `featurePolicy.maintenanceMode` field was left in the data model so
existing rows in the `PlatformSetting` table keep parsing. The toggle on
`/admin/policies` was retired (it now renders as an inert info card) so
operators are not encouraged to use a control that has no effect.

---

## How the canonical flag works

`ClientPolicy` rows are keyed `(distribution, channel)` and live in the
`ClientPolicy` table created by the
`20260510000001_client_policy` migration. Each row carries a
`maintenanceMode` boolean. When evaluating a client request,
`/v1/client/compatibility`:

1. Parses canonical headers into a `ClientIdentity` (distribution,
   channel, version, protocol).
2. Looks up the matching `ClientPolicy` row.
3. If the row exists, is `enabled`, and has `maintenanceMode = true`,
   the verdict's `status` is `maintenance` and `action` is
   `show_maintenance` regardless of the client's version.
4. The Flutter `UpdateGate` widget renders the maintenance screen.

Verified by: `aura-backend/src/platform/release-governance/
compatibility.evaluator.ts` (the `if (policy.maintenanceMode)`
short-circuit at line 65) and the tests in
`compatibility.evaluator.spec.ts` ("maintenance mode" describe block).

### Maintenance + admin override

`UpdateGate.build` checks `appAdminCachedDisplayProvider` AND the
current path. A confirmed admin on `/admin/*` BYPASSES the maintenance
screen so they can reach `/admin/client-policies` (or the API) to
disable maintenance during an incident. Non-admins, and admins not on
admin routes, see the maintenance screen as expected. See
`docs/admin_route_gating.md` (memory) for the full bypass contract.

---

## Operator runbook

### Putting `web-prod` into maintenance

```bash
ADMIN_TOKEN='<admin-jwt-from-secure-source>'

# 1. Identify the policy row id (or create one if missing).
curl -sS -H "Authorization: Bearer $ADMIN_TOKEN" \
  "https://api.auraplatform.org/v1/admin/client-policies?distribution=web-prod&channel=production" | jq

# 2. Flip maintenanceMode on (PATCH targets the existing row by id).
curl -sS -X PATCH -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"maintenanceMode": true, "message": "Brief upgrade — back at 21:30 UTC"}' \
  "https://api.auraplatform.org/v1/admin/client-policies/<id>" | jq
```

After the change, every `web-prod / production` client will receive
`status: "maintenance"` from `/v1/client/compatibility` on its next
poll (cadence = 10 min, or immediately on app resume).

### Taking `web-prod` out of maintenance

```bash
curl -sS -X PATCH -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"maintenanceMode": false, "message": null}' \
  "https://api.auraplatform.org/v1/admin/client-policies/<id>" | jq
```

### Maintenance for a specific distribution/channel only

`ClientPolicy` is per `(distribution, channel)`. To only block
`android-direct` while leaving `web-prod`, `android-play`, and
`windows-store` operating normally, only flip the `maintenanceMode` on
the `(android-direct, production)` row. Create one via `POST` if
needed.

Distributions Aura supports today (taxonomy from Slice A):
`web-prod`, `android-play`, `android-direct`, `windows-store`.
Channels: `production`, `beta`, `internal`, `development`.

### What happens to admins during maintenance

* Confirmed admins on `/admin/*` bypass the gate (see UpdateGate above).
* Confirmed admins on member routes still see the maintenance screen —
  navigate to `/admin` to operate.
* Non-admin users see the maintenance screen until the policy is
  flipped back.
* No probe of `/v1/admin/me` is triggered by the maintenance state
  itself (per the admin-route-gating contract).

### What about `featurePolicy.maintenanceMode`?

Leave it alone. It is harmless when stored as `true` (no code reads it)
and harmless when stored as `false`. The toggle on `/admin/policies`
has been retired specifically so this flag does not get accidentally
flipped. If you need to clear an existing stored `true`, the safest
path is to PUT the full `featurePolicy` object via `PUT
/v1/admin/policies` with `maintenanceMode: false` — this is operator
hygiene only, with no runtime effect.

---

## Hard rules

* **Do not wire `featurePolicy.maintenanceMode` to a runtime gate.** It
  is intentionally inert. Adding a global maintenance gate would create
  two contradictory truths.
* **Do not delete the field from the data model.** Existing
  `PlatformSetting` rows would fail to deserialize.
* **Do not add new admin UI surfaces for `featurePolicy.maintenanceMode`.**
  The only user-visible reference is the inert info card on
  `/admin/policies` that points operators here.
* **Do not patch the database directly to flip
  `ClientPolicy.maintenanceMode`.** The admin CRUD endpoints record an
  audit-log entry; direct DB writes do not.
* **Maintenance is not the place for force-update.** If you want
  blocking-update UX, set `forceUpdate: true` and a `minSupportedVersion`
  on the `ClientPolicy` row instead — that produces `status: "blocked"`
  with `action: "force_update"`, which the UpdateGate renders as a
  blocking screen with the correct per-distribution action button.

---

## Cross-references

* `aura-backend/src/platform/release-governance/compatibility.evaluator.ts`
  — the evaluator itself
* `aura-backend/src/platform/release-governance/admin-client-policies.controller.ts`
  — admin CRUD endpoints for `ClientPolicy`
* `aura_final/lib/core/release_governance/update_gate.dart`
  — the Flutter widget that renders the maintenance screen + admin bypass
* `aura_final/lib/features/admin/presentation/admin_policies_screen.dart`
  — the inert info card that replaced the legacy toggle
* `docs/ADMIN_RUNTIME_GOVERNANCE.md` — admin-workspace polling rules
* `docs/PRISMA_MIGRATION_RECOVERY.md` — the migration that introduced
  the `ClientPolicy` table
