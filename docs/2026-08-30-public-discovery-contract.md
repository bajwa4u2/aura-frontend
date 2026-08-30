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
No native routes or app behavior are implemented by this contract.
