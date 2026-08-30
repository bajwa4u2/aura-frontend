#!/usr/bin/env bash
# Google Play release automation — authenticated access, no exported key.
#
# WHY THERE IS NO KEY FILE HERE.
#
# The usual recipe for the Play Developer API is a service-account JSON key:
# a long-lived secret that must be downloaded, stored, rotated, and kept out
# of every repo and CI log forever. This uses short-lived impersonation
# instead. `aura-release-publisher` holds no key at all; an authorised human
# (or CI identity) with roles/iam.serviceAccountTokenCreator mints a token
# that expires in an hour.
#
# Nothing secret lives in this file, which is the point — it is safe to commit,
# and there is no credential to leak from it.
#
# The service account is granted access in PLAY CONSOLE, not through GCP IAM:
# it holds no project roles. Play authorises by identity, GCP only vouches for
# who that identity is. Granted permissions are deliberately narrow —
# app information (read), release to TESTING tracks, and manage testing
# tracks. It cannot release to production, cannot read financial data, and is
# not an admin. Promotion to production stays a human act.
#
#   ./play_release_api.sh tracks              # list tracks and their releases
#   ./play_release_api.sh bundles             # list uploaded bundles
#   ./play_release_api.sh get <path>          # any GET under the app resource
#
# Every command opens an edit and DISCARDS it. An edit is only a draft; Play
# changes nothing until it is committed, and this script never commits.
set -euo pipefail

SA="aura-release-publisher@aura-22b3a.iam.gserviceaccount.com"
PKG="org.auraplatform.app"
API="https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PKG}"

token() {
  # --scopes IS honoured on this path. gcloud prints a warning claiming it is
  # ignored for impersonated accounts; that warning is misleading — dropping
  # the flag yields "Request had insufficient authentication scopes" (403),
  # proven 2026-08-30. stderr is silenced so the warning text can never end up
  # inside the token when this runs in a command substitution.
  gcloud auth print-access-token \
    --impersonate-service-account="$SA" \
    --scopes=https://www.googleapis.com/auth/androidpublisher 2>/dev/null
}

TOKEN="$(token)"

new_edit() {
  curl -sf -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Length: 0" \
    "${API}/edits" | python -c 'import json,sys; print(json.load(sys.stdin)["id"])'
}

discard_edit() {
  # Best effort: an abandoned edit expires on its own, so a failure to discard
  # is untidy rather than dangerous. Never let it mask the real exit status.
  curl -sf -X DELETE -H "Authorization: Bearer $TOKEN" "${API}/edits/$1" >/dev/null 2>&1 || true
}

main() {
  local cmd="${1:-tracks}"
  local edit
  edit="$(new_edit)"
  trap 'discard_edit "$edit"' EXIT

  case "$cmd" in
    tracks)  curl -sf -H "Authorization: Bearer $TOKEN" "${API}/edits/${edit}/tracks" ;;
    bundles) curl -sf -H "Authorization: Bearer $TOKEN" "${API}/edits/${edit}/bundles" ;;
    get)     curl -sf -H "Authorization: Bearer $TOKEN" "${API}/edits/${edit}/${2:?path required}" ;;
    *)       echo "unknown command: $cmd" >&2; exit 2 ;;
  esac
}

main "$@"
