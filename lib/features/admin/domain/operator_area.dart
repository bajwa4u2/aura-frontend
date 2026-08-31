/// THE SEVEN OPERATOR AREAS.
///
/// Frozen architecture: NOW → WORK → SUBJECTS → INTEGRITY → PLATFORM → RECORD
/// → DISCOVERY.
///
/// Each area is a RESPONSIBILITY an operator would name, not a backend module.
/// The console it replaces was a flat list of fourteen nouns — Queue, Appeals,
/// Grants, Domains, Flags, Migrations — which required an operator to know
/// Aura's service structure in order to operate Aura.
///
/// Every area declares the capabilities that make it real. An operator who
/// holds none of them does not see the area, because a door you cannot open is
/// worse than no door: it reads as a fault in the product rather than a fact
/// about your authority.
library;

import 'package:flutter/material.dart';

import 'operator_capability.dart';

enum OperatorArea {
  /// What is happening, what needs attention, what changed. Replaces the
  /// launcher grid that used to occupy `/admin`.
  now(
    id: 'now',
    path: '/admin',
    label: 'Now',
    icon: Icons.radar_rounded,
    // NOW is a situation view assembled from whatever the operator can
    // legitimately see. Any operator authority at all earns it; the surface
    // itself renders only the sections they hold.
    anyOf: [],
  ),

  /// The single worklist across every queue authority.
  work(
    id: 'work',
    path: '/admin/work',
    label: 'Work',
    icon: Icons.inbox_rounded,
    anyOf: [
      OperatorCapability.moderationRead,
      OperatorCapability.verificationRead,
      OperatorCapability.identityVerificationRead,
      OperatorCapability.productFeedbackRead,
      OperatorCapability.supportRead,
    ],
  ),

  /// People and institutions as coherent subjects.
  subjects(
    id: 'subjects',
    path: '/admin/subjects',
    label: 'Subjects',
    icon: Icons.account_tree_rounded,
    anyOf: [
      OperatorCapability.usersRead,
      OperatorCapability.institutionsRead,
      OperatorCapability.identityVerificationRead,
    ],
  ),

  /// Moderation, appeals, media custody, publication and communication
  /// governance.
  integrity(
    id: 'integrity',
    path: '/admin/integrity',
    label: 'Integrity',
    icon: Icons.shield_rounded,
    anyOf: [
      OperatorCapability.moderationRead,
      OperatorCapability.communicationsRead,
      OperatorCapability.announcementsRead,
    ],
  ),

  /// Health, the released-client fleet, release governance, configuration.
  platform(
    id: 'platform',
    path: '/admin/platform',
    label: 'Platform',
    icon: Icons.dns_rounded,
    anyOf: [
      OperatorCapability.systemHealthRead,
      OperatorCapability.analyticsRead,
      OperatorCapability.settingsRead,
    ],
  ),

  /// The governed record: who did what, under what authority, and why.
  record(
    id: 'record',
    path: '/admin/record',
    label: 'Record',
    icon: Icons.receipt_long_rounded,
    anyOf: [OperatorCapability.auditRead],
  ),

  /// Is what we published reachable, and is it being found?
  discovery(
    id: 'discovery',
    path: '/admin/discovery',
    label: 'Discovery',
    icon: Icons.travel_explore_rounded,
    anyOf: [OperatorCapability.discoveryRead],
  );

  const OperatorArea({
    required this.id,
    required this.path,
    required this.label,
    required this.icon,
    required this.anyOf,
  });

  final String id;
  final String path;
  final String label;
  final IconData icon;

  /// Holding ANY of these admits the operator to the area. Empty means the
  /// area is available to any operator with admin authority at all.
  final List<OperatorCapability> anyOf;

  bool isVisibleTo(OperatorAuthority authority) {
    if (!authority.isOperator) return false;
    if (anyOf.isEmpty) return true;
    return authority.canAny(anyOf);
  }

  /// The area a path belongs to. Longest match wins so `/admin/work/...`
  /// resolves to WORK rather than to NOW's bare `/admin`.
  static OperatorArea? forPath(String path) {
    OperatorArea? best;
    for (final area in OperatorArea.values) {
      if (path == area.path || path.startsWith('${area.path}/')) {
        if (best == null || area.path.length > best.path.length) best = area;
      }
    }
    return best;
  }

  /// Areas this operator may see, in frozen order.
  static List<OperatorArea> visibleFor(OperatorAuthority authority) =>
      OperatorArea.values
          .where((a) => a.isVisibleTo(authority))
          .toList(growable: false);
}
