/// Frontend registry of public discourse spaces.
///
/// Public-UX Phase 2: this file is the temporary source of truth for
/// the set of spaces visible to all viewers. Each entry has a stable
/// id + slug + tag so URLs, deep links, and tagged posts are stable
/// across releases. When a public `/spaces` discovery endpoint ships,
/// `publicSpacesProvider` swaps to call the backend and the registry
/// becomes a fallback.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/space.dart';

const List<PubSpace> _kCuratedSpaces = [
  PubSpace(
    id: 'CIVIC',
    slug: 'civic',
    name: 'Civic',
    description: 'Public policy, governance, and accountability.',
    icon: Icons.account_balance_outlined,
    tag: 'civic',
  ),
  PubSpace(
    id: 'CLIMATE',
    slug: 'climate',
    name: 'Climate',
    description: 'Climate response, environment, and energy.',
    icon: Icons.eco_outlined,
    tag: 'climate',
  ),
  PubSpace(
    id: 'TECHNOLOGY',
    slug: 'technology',
    name: 'Technology',
    description: 'Software, infrastructure, and the public web.',
    icon: Icons.memory_rounded,
    tag: 'technology',
  ),
  PubSpace(
    id: 'EDUCATION',
    slug: 'education',
    name: 'Education',
    description: 'Schools, research, and learning systems.',
    icon: Icons.school_outlined,
    tag: 'education',
  ),
  PubSpace(
    id: 'HEALTH',
    slug: 'health',
    name: 'Health',
    description: 'Public health, care systems, and advisories.',
    icon: Icons.local_hospital_outlined,
    tag: 'health',
  ),
  PubSpace(
    id: 'LOCAL',
    slug: 'local',
    name: 'Local',
    description: 'Discussions anchored in your region.',
    icon: Icons.place_outlined,
    tag: 'local',
  ),
];

/// All public spaces, in display order.
final publicSpacesProvider = Provider<List<PubSpace>>((_) => _kCuratedSpaces);

/// Lookup by slug. Returns null when no space matches — callers should
/// degrade gracefully (404-style empty state) rather than throw.
final publicSpaceBySlugProvider =
    Provider.family<PubSpace?, String>((ref, slug) {
  final s = slug.trim().toLowerCase();
  for (final space in ref.watch(publicSpacesProvider)) {
    if (space.slug.toLowerCase() == s) return space;
  }
  return null;
});
