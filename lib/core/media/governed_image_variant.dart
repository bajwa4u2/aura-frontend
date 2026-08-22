// CHOOSING WHICH GOVERNED REPRESENTATION TO RENDER.
//
// Aura's identity images — a person's avatar and cover, an institution's logo
// and cover — are stored as GOVERNED NAMES rather than as storage capabilities.
// `identity-delivery.ts` on the server explains why: roughly 202 emission sites
// and 72 render sites all emit the same handful of stored values, so the
// convergence point is the VALUE, not the site. Each of those values addresses
// Aura's delivery door, which re-asks the authority model on every request.
//
// That leaves exactly one thing for the client to decide: WHICH representation
// of that name it wants. And that decision genuinely belongs here rather than
// in the stored value, because it differs by surface — a 32 px avatar and a
// full-bleed cover are the same identity and want very different bytes.
//
// ─────────────────────────────────────────────────────────────────────────────
// WHY THIS IS SAFE TO APPLY EVERYWHERE
//
// Asking for a variant is never a risk. The door falls through to the canonical
// object whenever the derivative it was asked for does not exist — missing, not
// produced yet, or permanently failed — so a surface that requests a thumbnail
// always gets a picture. That fall-through is what lets derivatives be an
// enhancement rather than a dependency.
//
// And it is a NO-OP for anything that is not a governed name: an external
// avatar, a legacy direct-storage URL, a data URI. Those are returned exactly
// as given, because appending a query parameter to a URL Aura does not serve
// would at best do nothing and at worst break it.
// ─────────────────────────────────────────────────────────────────────────────
//
// It deliberately does NOT introduce a second identity URL, a thumbnail field,
// or any durable string beside the canonical one. There is one name; this picks
// a representation of it at render time.

/// The representations Aura's delivery door can serve.
enum GovernedImageVariant {
  /// The canonical object, full resolution. What a download or a
  /// full-resolution viewer must ask for.
  original,

  /// Display-sized. For a picture that fills a region — a cover, a banner, a
  /// photograph opened in a reader.
  display,

  /// Small. For avatars, logos and list tiles, where the rendered box is a
  /// fraction of the source and the full object would be bytes spent on detail
  /// nobody can see.
  thumbnail,
}

extension _VariantWire on GovernedImageVariant {
  /// The `v` parameter the door understands. `original` sends nothing, because
  /// the door's default already means the canonical object.
  String? get wire {
    switch (this) {
      case GovernedImageVariant.original:
        return null;
      case GovernedImageVariant.display:
        return 'display';
      case GovernedImageVariant.thumbnail:
        return 'thumb';
    }
  }
}

/// Is this a name Aura resolves, rather than a URL someone else serves?
///
/// Matches the door's shape — `/media/{id}/raw` — the same test
/// `isIdentityDeliveryUrl` applies on the server. Deliberately structural
/// rather than host-based: the delivery origin differs between environments and
/// has been repointed before, and a check that hard-coded a host would quietly
/// stop recognising Aura's own images the next time it moved.
bool isGovernedImageUrl(String? url) {
  final value = (url ?? '').trim();
  if (value.isEmpty) return false;
  final withoutQuery = value.split('?').first;
  return RegExp(r'/media/[^/]+/raw$').hasMatch(withoutQuery);
}

/// Ask a governed name for a particular representation.
///
/// Returns [url] untouched when it is not a governed name, when it already
/// carries a variant, or when the caller wants the original.
String? governedImageVariant(String? url, GovernedImageVariant variant) {
  final value = (url ?? '').trim();
  if (value.isEmpty) return url;
  if (!isGovernedImageUrl(value)) return url;

  final wire = variant.wire;
  if (wire == null) return value;

  // Already carries a variant — an emission site that has made this choice
  // explicitly is not second-guessed here.
  if (value.contains('?')) return value;

  return '$value?v=$wire';
}
