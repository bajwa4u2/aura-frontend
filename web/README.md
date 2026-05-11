# `aura_final/web/` — public web-build root

Anything in this folder is **served from the site root** after `flutter
build web`. Files here ship to every visitor and are crawlable.

## What belongs here

- `index.html`, `manifest.json`, `flutter_*.js` — required app shell.
- `favicon.*` and `icons/` — site icons.
- `push/` — service-worker and VAPID-bound push assets.
- `.well-known/` — public verification files (assetlinks, AASA). See
  the README inside that folder for the placeholder-replacement
  procedure before any production build.

## What does NOT belong here

- Investor documents (financials, governance, round details).
- Internal architecture docs.
- Credentials, sample env files, anything labelled "draft" or "internal".

A previous build of this folder included three investor PDFs:

- `Aura_Business_Model_Framework_v1.0_Mar2026.pdf`
- `Aura_Governance_Framework_v1.0_Mar2026.pdf`
- `Aura_Seed_Investment_Round_Mar2026.pdf`

Those were removed in the 2026-05 distribution-readiness pass. If you
need to keep them inside the repository for collaboration, move them
under `aura_final/assets/investor/` or `docs/investor/` — Flutter's
asset pipeline doesn't ship those paths to the web bundle.

If they must be shared externally, host them on a private surface
(internal share, signed S3 link) rather than the marketing domain.
