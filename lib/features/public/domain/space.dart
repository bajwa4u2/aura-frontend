/// Frontend space model.
///
/// Public-UX Phase 2: spaces are first-class discourse environments
/// with stable slugs, names, descriptions, and a tag used to filter
/// content from the existing global feed. The model is frontend-ready
/// so the same widgets bind 1:1 to a future backend `/spaces` public
/// endpoint without UI rework — only the data source changes.
///
/// Today the public-spaces registry ships a curated set of real
/// spaces (civic, climate, tech, education, health, local) hosted
/// entirely client-side. Each space carries a stable id and slug so
/// URLs and saved references survive across reloads.
library;

import 'package:flutter/material.dart';

class PubSpace {
  const PubSpace({
    required this.id,
    required this.slug,
    required this.name,
    required this.description,
    required this.icon,
    required this.tag,
  });

  /// Stable identifier — uppercase, snake-case. Survives reloads.
  final String id;

  /// URL-safe slug used in `/spaces/:slug` routes.
  final String slug;

  /// Display name (e.g. "Civic").
  final String name;

  /// One-line description rendered on cards + space header.
  final String description;

  /// Material icon shown on the tile + header.
  final IconData icon;

  /// Hashtag used to filter `globalPublicFeedProvider` items into this
  /// space. Lowercase, no leading `#`. e.g. `civic`. Posts with the
  /// tag in their body OR title surface in the space's discourse
  /// stream — frontend-only filtering until a backend endpoint lands.
  final String tag;

  /// Hashtag prefix (`#civic `) the composer will pre-pend when posting
  /// from inside the space, so frontend-filtered scoping survives the
  /// round-trip through the existing `/posts/draft` payload (which has
  /// no `space_id` field today).
  String get composeTagPrefix => '#$tag';
}
