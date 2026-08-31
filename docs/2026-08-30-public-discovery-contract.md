# Aura public discovery contract

Aura's product-owned discovery boundary is deliberately smaller than the
application route table. The canonical public host is `https://auraplatform.org`.

The static route resolver serves `/robots.txt`, `/sitemap.xml`, and
`/indexnow-key.txt` from the web deployment. The sitemap contains stable public
product, policy, and public-directory entry points only. Dynamic `/p/*`,
`/institutions/*`, and `/u/*` projections require the existing public-object
authority to establish that an object is stable, canonical, public,
non-sensitive, and discovery-worthy before they may be enumerated. `/media/*`
is an asset delivery surface, not a sitemap inventory.

Authenticated, account-specific, institution-private, operator/admin, message,
conversation, notification, saved, settings, and other private application
routes are excluded from discovery. Unknown query strings never create a new
canonical document; tracking parameters do not change canonical identity.

After a successful public deployment, run `node tool/notify_indexnow.mjs`.
The notifier hashes the canonical sitemap and suppresses unchanged
notifications. The public key file proves host ownership; the notification is
not an indexing or ranking claim.

## Native continuation readiness

The canonical public URL remains the destination identity for web, sharing,
search, and any future native continuation. The product public home and any
future `/p/*`, `/institutions/*`, or `/u/*` object may be marked eligible only
when its public-object authority establishes: `INDEXABLE`, `SHAREABLE`,
`NATIVE_CONTINUATION_ELIGIBLE`, `RELEASED_NATIVE_APP_EXISTS`,
`DESTINATION_IDENTITY_PRESERVABLE`, `AUTH_REQUIRED_AFTER_OPEN`, and
`RETURN_DESTINATION_REQUIRED`. Media remains an asset, not an object index.
The public web implementation exposes a quiet continuation affordance only on
the approved static public routes and only for a platform with verified native
continuation authority. It launches the same canonical HTTPS URL through the
platform external-link boundary; it does not perform installed-app detection,
store redirection, or native route handling. Dismissal is local-only and
non-repeating.

## Native handoff boundary

The shared web capability is product-configured, not route-reinvented. A
product configuration declares its canonical host, eligible public paths,
released platform capability, verified store destinations (when available),
and whether the web URL can be handed to the operating system. The resolver
never derives acquisition eligibility from arbitrary query parameters or from
public reachability alone.

For Aura today:

- Android public web entry is eligible on the static route inventory because
  the released Android application and `assetlinks.json` authority exist.
- iOS and Windows remain web-only in the public surface until their public
  association and acquisition destinations are verified.
- Dynamic `/p/*`, `/institutions/*`, and `/u/*` objects remain ineligible until
  the object authority establishes a stable, canonical, non-sensitive,
  native-continuation destination.

The native implementation owner must consume the same canonical URL and
destination identity for Android App Links, iOS Universal Links, Windows
association, authentication return, and install return. No duplicate app URL
system is permitted.
