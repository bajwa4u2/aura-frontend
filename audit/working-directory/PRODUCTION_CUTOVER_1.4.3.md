# Aura 1.4.3 — Production Cutover

**Date:** 2026-09-11
**Authorisation:** founder — `MAIN_PUSH = AUTHORIZED`, superseding
`MAIN_PUSH = NOT YET AUTHORIZED FOR PRODUCTION CUTOVER`.

    PRODUCTION_BACKEND_COMMIT    07dcd29bc9f228396d08daaa96532878f7fcb242
    PRODUCTION_FRONTEND_COMMIT   109f0cc1fb4478af7ce0dd46c260067e6b8cf9c3
    DEPLOYMENT_IDS               backend  1dde31e4   SUCCESS
                                 frontend 95e35405   SUCCESS
    MIGRATIONS_APPLIED           3 (additive; 198 total, schema up to date)

**Production is no longer serving the September 10 pre-release commits.**
Backend moved `0b92237d` (Sep 10 05:05) → `07dcd29b`; frontend moved
`491db357` (Sep 10 04:48) → `109f0cc1`.

This is a **server/web production convergence, not a new client release.**
Apple build 38 was not rebuilt or modified.

## How the merge was done

Both repositories fast-forwarded: local `main` already carried the frozen
release lineage and `origin/main` was an ancestor of it, so the push was a
fast-forward with **no squash and no rewrite**. The frozen lineage is intact and
every release commit keeps its identity.

    aura-backend    0b92237..07dcd29  main -> main
    aura-frontend   491db357..109f0cc1  main -> main

## Backend gate — passed before the frontend was touched

    /health commit           07dcd29bc9f228396d08daaa96532878f7fcb242   MATCHES
    attributable             true
    not the Sep-10 commit    confirmed
    migrations               198 found, "Database schema is up to date!", none pending
    destructive SQL executed NONE — all three release migrations contain zero
                             DROP / TRUNCATE / DELETE statements
    auth endpoints           /v1/auth/me 401, /v1/auth/login 400 on bad input
    5xx anywhere             none

**The decisive proof the release code is actually serving**, rather than a
restart of the old build: two routes that returned `404` before the cutover now
return `401`, while a genuinely non-existent route still returns `404` as the
control.

    /v1/institutions/admin/verification/queue        404 -> 401
    /v1/institutions/<id>/verification               404 -> 401
    /v1/institutions/definitely-not-a-route-xyz      404 (control, unchanged)

## Frontend gate

    main.dart.js   sha256 0749d167bebf56d24c3fec48ef49267e1ffc8375e6caf7ecb37bae3c456b8b6a
    last-modified  Fri, 11 Sep 2026 10:55:20 GMT   (pinned at download time)
    cache-control  no-cache — an ordinary revisit gets the new build

Carries strings that exist **only** in today's work, which is how we know it is
the release artifact rather than a rebuild of the old one:

    "Verify my identity"             present   (the migration dead-end repair)
    "Does this institution exist?"   present

`institutionVerification` is absent, as expected — a Dart identifier does not
survive dart2js minification, and a marker string is only evidence when it is
user-facing text.

Re-run against the now-current backend: `/messages` loads, **0 failed requests
of 24**, auth refresh → me → notifications → institutions/me all clean.

## OPEN: production schema drift, pre-existing and NOT caused by this cutover

`prisma migrate diff --from-url <production> --to-schema-datamodel` is **not
empty**. It was checked because the founder asked for it, and it is recorded
here rather than quietly passed over.

    ALTER TABLE "InstitutionPost"    DROP then re-ADD authorUserId_fkey (ON DELETE NO ACTION)
    ALTER TABLE "MeetingParticipant" ADD COLUMN "guestToken" TEXT
    ALTER TABLE "TrustedDevice"      updatedAt SET DEFAULT CURRENT_TIMESTAMP
    ALTER TABLE "UserContactDiscoveryConsent"  same
    CREATE INDEX x3, RENAME INDEX x2

**Why this is not a cutover defect.** The diff from the MIGRATION HISTORY to the
schema is empty — that was closed earlier in this release. The diff from
PRODUCTION is not. So production's database has diverged from what replaying
the migrations would produce, at some point before today. None of these items
appear in the three migrations deployed today.

**Why it is not breaking.** `grep` finds **zero** references to `guestToken` in
`src/` — no query selects the missing column, so Prisma cannot fail on it. The
rest are indexes (performance), `updatedAt` defaults (the client sets these via
`@updatedAt`), an `onDelete` behaviour, and index names. Runtime confirms it:
`/v1/meetings`, `/v1/institutions/me`, `/v1/notifications`, `/v1/conversations`
all answer `401` — alive and refusing an unauthenticated caller — with no `5xx`
anywhere on the public surface.

**It must be closed deliberately, and never by letting Prisma generate the
migration it wants.** That script begins by dropping a foreign key, and this
estate has already had 28 generated DROP statements try to ride an unrelated
feature. It is a separate, reviewed piece of work.
