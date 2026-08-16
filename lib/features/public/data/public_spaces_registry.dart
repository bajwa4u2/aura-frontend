/// Registry of public discourse spaces — the SPACES discovery domain's
/// single subject taxonomy (C3 post-closeout Discover correction,
/// 2026-08-16).
///
/// Ownership + extension path: this registry is the one source of truth
/// for the subject taxonomy — extending Spaces means adding an entry
/// HERE (stable id + slug + tag), never scattering subject literals
/// across surfaces. Every space is immediately real: its stream is the
/// tag-filtered public feed and its composer prefills the tag, so a new
/// subject starts as a genuine (initially quiet) discourse environment,
/// not a fabricated one. When a backend `/spaces` discovery endpoint
/// ships, `publicSpacesProvider` swaps to call it and this registry
/// becomes the fallback; ids/slugs/tags are frozen wire contracts so
/// URLs, deep links, and tagged posts survive that migration.
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
  // Taxonomy broadened by the C3 post-closeout Discover correction
  // (2026-08-16) — subjects, not audiences; same subject-based model.
  PubSpace(
    id: 'ECONOMY',
    slug: 'economy',
    name: 'Economy',
    description: 'Work, business, markets, and public finance.',
    icon: Icons.trending_up_rounded,
    tag: 'economy',
  ),
  PubSpace(
    id: 'SCIENCE',
    slug: 'science',
    name: 'Science',
    description: 'Research, evidence, and open scientific discourse.',
    icon: Icons.science_outlined,
    tag: 'science',
  ),
  PubSpace(
    id: 'CULTURE',
    slug: 'culture',
    name: 'Culture',
    description: 'Arts, media, heritage, and public life.',
    icon: Icons.palette_outlined,
    tag: 'culture',
  ),
  PubSpace(
    id: 'JUSTICE',
    slug: 'justice',
    name: 'Justice',
    description: 'Law, rights, and institutional accountability.',
    icon: Icons.gavel_rounded,
    tag: 'justice',
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
