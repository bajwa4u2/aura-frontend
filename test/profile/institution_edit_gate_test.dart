import 'package:aura/core/authority/capability_projection.dart';
import 'package:flutter_test/flutter_test.dart';

/// C2 §9 — the institution editor gate asks the CAPABILITY question.
///
/// Backend truth: `PATCH /institutions/:id` is guarded by
/// `InstitutionCapability.MANAGE_BRANDING`, which is **owner-held and
/// delegable** — `ADMIN_CAPABILITIES` does not include it.
///
/// The defect pinned here: the old `identity.isAdmin` gate showed the full
/// Identity Studio to an ADMIN without the delegated grant, whose save then
/// 403'd. Role was standing in for a capability question (the C1 drift
/// pattern), and it over-promised.
void main() {
  InstitutionStanding standing({
    Set<InstitutionCapabilityToken> caps = const {},
    InstitutionRole? role,
  }) =>
      InstitutionStanding(
        institutionId: 'i1',
        institutionName: 'Wayne County',
        effectiveCapabilities: caps,
        role: role,
      );

  test('an ADMIN without MANAGE_BRANDING is not offered the editor', () {
    // This is the exact case the isAdmin gate got wrong.
    final p = CapabilityProjection(standing(
      role: InstitutionRole.admin,
      caps: {
        // A realistic admin set — operational capabilities, no branding.
        InstitutionCapabilityToken.manageMembers,
        InstitutionCapabilityToken.manageAnnouncements,
      },
    ));
    expect(
      p.presentationFor(ConsequentialAct.manageBranding),
      ControlPresentation.absent,
    );
  });

  test('a MEMBER with a delegated MANAGE_BRANDING grant IS offered it', () {
    // The inverse case isAdmin also got wrong: capability is delegable, so a
    // non-admin holder is legitimate.
    final p = CapabilityProjection(standing(
      role: InstitutionRole.member,
      caps: {InstitutionCapabilityToken.manageBranding},
    ));
    expect(
      p.presentationFor(ConsequentialAct.manageBranding),
      ControlPresentation.available,
    );
  });

  test('an OWNER (full capability set) is offered it', () {
    final p = CapabilityProjection(standing(
      role: InstitutionRole.owner,
      caps: InstitutionCapabilityToken.all.toSet(),
    ));
    expect(
      p.presentationFor(ConsequentialAct.manageBranding),
      ControlPresentation.available,
    );
  });

  test('no institutional context means the editor is absent, not broken', () {
    const p = CapabilityProjection(null);
    expect(
      p.presentationFor(ConsequentialAct.manageBranding),
      ControlPresentation.absent,
    );
  });

  test('manageBranding remains a capability act, never governance-role', () {
    // Guards the mapping itself: if someone re-expresses branding as a role
    // requirement, the backend contract (capability guard) and the client
    // would silently diverge again.
    final r = ConsequentialAct.manageBranding.requirement;
    expect(r.capability, InstitutionCapabilityToken.manageBranding);
    expect(r.minimumRole, isNull);
    expect(r.isPersonal, isFalse);
  });
}
