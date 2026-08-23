import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// NO HUMAN-FACING WORKSPACE URL MAY BE MINTED FROM A PERSISTENCE ID.
///
/// Founder ruling AD2 (2026-08-23), structural gate. The register found ~40
/// workspace routes carrying a raw institution id, and 23 production
/// notification rows with that shape already persisted. The router now
/// canonicalizes an id on arrival, so those links keep working — but nothing
/// may GENERATE one any more, or the two forms live side by side forever.
///
/// This walks the generators rather than the screens, because a screen that
/// looks correct today can start minting ids the moment someone reaches for
/// `identity.id` instead of `identity.workspaceAddress`.
void main() {
  /// WHAT COUNTS AS MINTING.
  ///
  /// Re-emitting a ROUTE-SUPPLIED segment is not a defect: the router resolves
  /// and canonicalizes an address before any screen sees it, so
  /// `widget.institutionId` already holds the slug. Flagging that would be
  /// flagging a parameter's NAME rather than a behaviour.
  ///
  /// The defect is building an address out of PERSISTENCE identity — reading
  /// `.id` off an identity or a model and interpolating it into a path. That
  /// is where database identity enters the address space, and it is what this
  /// matches.
  final mintsRawId = RegExp(
    r"""'/institution/\$\{[\w.!?]*\.id[\w.!?]*\}/|'/institution/\$identity[!?]?\.id""",
  );

  /// Reading `identity.id` INTO one of the sanctioned builders — the other way
  /// a persistence id reaches the address space.
  final passesIdToBuilder = RegExp(
    r'institution(WorkspacePath|UnitContextPath)\(\s*[\w.!?]*\bid\b',
  );

  /// EXPLICITLY REGISTERED COMPATIBILITY. These PARSE or REDIRECT a legacy
  /// address; they do not mint one. Anything not listed here is new drift, and
  /// the list is deliberately short so additions are visible in review.
  const allowedCompatibility = <String>{
    // Resolves any address form (slug, historical slug, id) and canonicalizes.
    'lib/core/institutions/institution_route_authority.dart',
    // Route DEFINITIONS carry ':institutionId' as a parameter name, and the
    // redirect that canonicalizes legacy forms lives here.
    'lib/router.dart',
    // Route classification matches on path shape; it generates nothing.
    'lib/app/route_classification.dart',
  };

  /// PRE-EXISTING GENERATORS, FROZEN — not forgiven.
  ///
  /// These build `/institution/<id>/meetings/...` for the ATTENDEE flows, where
  /// the viewer may legitimately hold no membership (frozen doctrine
  /// 2026-08-14: institutionId in a meeting path is CONTEXT, not a membership
  /// claim). They cannot mint a slug today because the meeting payload carries
  /// the institution slug only on the booking path.
  ///
  /// RETIREMENT CONDITION: the meeting projection exposes the owning
  /// institution's slug generally; these then mint it and leave this list. The
  /// count is asserted below so the debt can shrink but never grow.
  const knownLegacyGenerators = <String>{
    'lib/features/meetings/presentation/meeting_detail_screen.dart',
    'lib/features/meetings/presentation/meeting_live_room_screen.dart',
    'lib/features/realtime/presentation/realtime_room_screen.dart',
  };

  test('no generator mints /institution/<rawId>/', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final rel = entity.path.replaceAll(r'\', '/');
      if (allowedCompatibility.any(rel.endsWith)) continue;
      if (knownLegacyGenerators.any(rel.endsWith)) continue;

      final source = entity.readAsStringSync();
      final lines = source.split('\n');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (mintsRawId.hasMatch(line) || passesIdToBuilder.hasMatch(line)) {
          offenders.add('$rel:${i + 1}  ${line.trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'These build a workspace address from a persistence id. Use the '
          'institution\'s canonical address (InstitutionIdentity.workspaceAddress '
          'or MemberAffiliation.slug) instead. A raw id still RESOLVES — the '
          'router canonicalizes it — but generating one keeps two address '
          'forms alive indefinitely:\n  ${offenders.join('\n  ')}',
    );
  });

  test('the legacy generator debt shrinks, never grows', () {
    // A frozen count: adding a file here would need this number changed, which
    // is exactly the review moment the gate exists to force.
    expect(knownLegacyGenerators.length, 3);
    for (final path in knownLegacyGenerators) {
      expect(File(path).existsSync(), isTrue, reason: "$path no longer exists");
    }
  });

  test('the compatibility allow-list stays small and real', () {
    // A growing allow-list is how a gate stops meaning anything. Every entry
    // must still exist, so a stale exemption cannot silently cover new code.
    for (final path in allowedCompatibility) {
      expect(File(path).existsSync(), isTrue, reason: '$path no longer exists');
    }
    expect(allowedCompatibility.length, lessThanOrEqualTo(4));
  });
}
