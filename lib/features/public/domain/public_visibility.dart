/// Public-layer visibility: the two-state model the public composer
/// shows the user. Personal is intentionally absent from this enum —
/// the public composer never offers it.
///
/// Wire mapping:
///   * social  → backend `FOLLOWERS`  (existing PostVisibility.followers)
///   * public  → backend `PUBLIC`     (existing PostVisibility.public)
///
/// The Personal/Private layer is reachable only through other surfaces
/// (e.g. the legacy compose screen entered via a profile draft path);
/// the public surface refuses to expose it.
library;

enum PubVisibility {
  social,
  public,
}

extension PubVisibilityX on PubVisibility {
  /// Wire token used by the existing `/posts/draft` payload.
  String get postWire {
    switch (this) {
      case PubVisibility.social:
        return 'FOLLOWERS';
      case PubVisibility.public:
        return 'PUBLIC';
    }
  }

  String get label {
    switch (this) {
      case PubVisibility.social:
        return 'Social';
      case PubVisibility.public:
        return 'Public';
    }
  }

  /// One-line consequence rendered beneath the selector. Single source
  /// of truth for what each visibility means in the UI.
  String get consequence {
    switch (this) {
      case PubVisibility.social:
        return 'People you’re connected with can see this.';
      case PubVisibility.public:
        return 'Anyone on Aura can see this and reply.';
    }
  }
}
