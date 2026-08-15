import 'package:aura/core/authority/acting_context.dart';
import 'package:aura/core/authority/capability_projection.dart';
import 'package:flutter_test/flutter_test.dart';

InstitutionStanding standing({
  Set<InstitutionCapabilityToken> caps = const {},
  InstitutionRole? role,
  bool account = false,
}) =>
    InstitutionStanding(
      institutionId: 'inst-1',
      institutionName: 'Wayne County',
      effectiveCapabilities: caps,
      role: role,
      isInstitutionAccount: account,
    );

ActingContextAuthority authority({InstitutionStanding? inst}) =>
    ActingContextAuthority(
      personId: 'person-1',
      personDisplayName: 'Sam',
      institution: inst,
    );

void main() {
  _rulingSix();
  group('Acting Context — ordinary acts need no ceremony', () {
    test('a personal act resolves to the person with no choice', () {
      final r = authority().resolve(ConsequentialAct.sendDirectMessage)!;
      expect(r.isAvailable, isTrue);
      expect(r.recommended!.kind, ActingIdentityKind.person);
      expect(r.requiresExplicitChoice, isFalse);
      expect(r.isInstitutionalSpeech, isFalse);
    });

    test('personal acts do not require an institution', () {
      for (final act in [
        ConsequentialAct.publishPersonalPost,
        ConsequentialAct.replyPersonally,
        ConsequentialAct.sendDirectMessage,
      ]) {
        expect(authority().resolve(act)!.isAvailable, isTrue, reason: '$act');
      }
    });
  });

  group('Acting Context — institutional acts follow backend capability', () {
    test('no institution means the act is not offered at all', () {
      final r = authority().resolve(ConsequentialAct.publishAnnouncement)!;
      expect(r.isAvailable, isFalse);
      expect(r.recommended, isNull);
    });

    test('membership alone does not grant institutional speech', () {
      // A MEMBER with no delegated capability. Belonging is not authority.
      final r = authority(inst: standing(role: InstitutionRole.member))
          .resolve(ConsequentialAct.publishAnnouncement)!;
      expect(r.isAvailable, isFalse);
    });

    test('the capability the backend reports is what unlocks the act', () {
      final r = authority(
        inst: standing(
          caps: {InstitutionCapabilityToken.manageAnnouncements},
          role: InstitutionRole.member,
        ),
      ).resolve(ConsequentialAct.publishAnnouncement)!;
      expect(r.isAvailable, isTrue);
      expect(r.recommended!.kind, ActingIdentityKind.institution);
      expect(r.recommended!.availability,
          ActingAvailability.institutionalCapability);
      expect(r.isInstitutionalSpeech, isTrue);
    });

    test('an ADMIN role does not by itself grant a capability act', () {
      // The client must not re-derive ROLE_CAPABILITIES. If the backend did
      // not report the capability, the act is not offered — even for an admin.
      final r = authority(inst: standing(role: InstitutionRole.admin))
          .resolve(ConsequentialAct.manageMembers)!;
      expect(r.isAvailable, isFalse);
    });

    test('an institutional act always keeps the person attributable', () {
      final r = authority(
        inst: standing(caps: {InstitutionCapabilityToken.publishOfficial}),
      ).resolve(ConsequentialAct.publishInstitutionPost)!;
      expect(r.recommended!.isInstitution, isTrue);
      expect(r.recommended!.personId, 'person-1');
    });
  });

  group('Acting Context — the choice appears only when it is real', () {
    test('a surface offering both identities demands a choice', () {
      final r = authority(
        inst: standing(caps: {InstitutionCapabilityToken.publishOfficial}),
      ).resolve(ConsequentialAct.publishInstitutionPost,
          offerPersonalAlternative: true)!;
      expect(r.options.length, 2);
      expect(r.requiresExplicitChoice, isTrue);
      expect(r.options.first.isInstitution, isTrue);
      expect(r.options.last.isPerson, isTrue);
    });

    test('a single-purpose surface states attribution without a chooser', () {
      // The institution post composer publishes in the institution voice only.
      // Manufacturing a chooser it cannot honour would be worse than none.
      final r = authority(
        inst: standing(caps: {InstitutionCapabilityToken.publishOfficial}),
      ).resolve(ConsequentialAct.publishInstitutionPost)!;
      expect(r.options.length, 1);
      expect(r.requiresExplicitChoice, isFalse);
      expect(r.recommended!.isInstitution, isTrue);
    });

    test('managing members is institutional only — no choice to make', () {
      final r = authority(
        inst: standing(caps: {InstitutionCapabilityToken.manageMembers}),
      ).resolve(ConsequentialAct.manageMembers)!;
      expect(r.options.length, 1);
      expect(r.requiresExplicitChoice, isFalse);
    });
  });

  group('Governance is role authority, not capability', () {
    test('ownership transfer requires OWNER and is never delegable', () {
      // Even holding every capability does not grant governance.
      final everything = authority(
        inst: standing(
          caps: InstitutionCapabilityToken.all.toSet(),
          role: InstitutionRole.admin,
        ),
      );
      expect(everything.resolve(ConsequentialAct.transferOwnership)!.isAvailable,
          isFalse);
      expect(everything.resolve(ConsequentialAct.appointAdmin)!.isAvailable,
          isFalse);

      final owner = authority(inst: standing(role: InstitutionRole.owner));
      final r = owner.resolve(ConsequentialAct.transferOwnership)!;
      expect(r.isAvailable, isTrue);
      expect(r.recommended!.availability,
          ActingAvailability.institutionalGovernanceRole);
    });

    test('role ranking mirrors the backend', () {
      expect(InstitutionRole.owner.atLeast(InstitutionRole.admin), isTrue);
      expect(InstitutionRole.admin.atLeast(InstitutionRole.owner), isFalse);
      expect(InstitutionRole.member.atLeast(InstitutionRole.member), isTrue);
    });
  });

  group('Capability projection — presentation, never authorization', () {
    test('absent by default rather than a disabled dead end', () {
      const p = CapabilityProjection(null);
      expect(p.presentationFor(ConsequentialAct.manageMembers),
          ControlPresentation.absent);
    });

    test('explained only when the surface supplies a reason', () {
      final p = CapabilityProjection(standing(role: InstitutionRole.member));
      expect(
        p.presentationFor(ConsequentialAct.manageMembers,
            explainWhenUnavailable: 'Ask an administrator.'),
        ControlPresentation.explained,
      );
    });

    test('personal acts are always presentable', () {
      const p = CapabilityProjection(null);
      expect(p.presentationFor(ConsequentialAct.replyPersonally),
          ControlPresentation.available);
    });

    test('governance role check is available for governance acts only', () {
      final p = CapabilityProjection(standing(role: InstitutionRole.owner));
      expect(p.holdsGovernanceRole(InstitutionRole.owner), isTrue);
      expect(p.presentationFor(ConsequentialAct.transferOwnership),
          ControlPresentation.available);
    });
  });

  group('Backend parsing — no invention', () {
    test('unknown capability tokens are dropped, never guessed', () {
      final s = InstitutionStanding.fromBackend(
        institutionId: 'i',
        institutionName: 'n',
        capabilities: ['MANAGE_MEMBERS', 'TOTALLY_MADE_UP', ''],
        roleWire: 'ADMIN',
      );
      expect(s.effectiveCapabilities,
          {InstitutionCapabilityToken.manageMembers});
      expect(s.role, InstitutionRole.admin);
    });

    test('an empty backend capability set stays empty', () {
      // The previous implementation injected six invented capabilities here.
      final s = InstitutionStanding.fromBackend(
        institutionId: 'i',
        institutionName: 'n',
        capabilities: const [],
        roleWire: null,
        isInstitutionAccount: true,
      );
      expect(s.effectiveCapabilities, isEmpty);
      expect(s.isInstitutionAccount, isTrue);
    });

    test('an institution-account session is labelled, not fabricated', () {
      final s = InstitutionStanding.fromBackend(
        institutionId: 'i',
        institutionName: 'n',
        capabilities: const ['PUBLISH_OFFICIAL'],
        roleWire: null,
        isInstitutionAccount: true,
      );
      final r = authority(inst: s)
          .resolve(ConsequentialAct.publishInstitutionPost)!;
      expect(r.recommended!.availability,
          ActingAvailability.institutionAccount);
    });

    test('every capability token has a distinct wire value', () {
      final wires = InstitutionCapabilityToken.all.map((c) => c.wire).toList();
      expect(wires.toSet().length, wires.length);
      expect(wires.length, 22);
    });

    test('every consequential act declares exactly one requirement', () {
      for (final act in ConsequentialAct.values) {
        final r = act.requirement;
        final declared = [
          if (r.isPersonal) 'personal',
          if (r.capability != null) 'capability',
          if (r.minimumRole != null) 'governance',
        ];
        expect(declared.length, 1, reason: '$act declares $declared');
      }
    });
  });
}

// ── Ruling 6 — institutional correspondence contract ────────────────────────
void _rulingSix() {
  group('Institutional correspondence — contract for C7', () {
    test('a person with no representation capability messages as themselves',
        () {
      final r = authority(inst: standing(role: InstitutionRole.admin))
          .resolve(ConsequentialAct.correspondAsInstitution)!;
      expect(r.isAvailable, isFalse,
          reason: 'ADMIN role must not imply institutional voice');

      final personal =
          authority().resolve(ConsequentialAct.sendDirectMessage)!;
      expect(personal.requiresExplicitChoice, isFalse,
          reason: 'one legitimate context means no chooser');
    });

    test('official representation unlocks the institutional context', () {
      final r = authority(
        inst: standing(
          caps: {InstitutionCapabilityToken.officialRepresentation},
        ),
      ).resolve(ConsequentialAct.correspondAsInstitution)!;
      expect(r.isAvailable, isTrue);
      expect(r.recommended!.isInstitution, isTrue);
      expect(r.recommended!.personId, 'person-1',
          reason: 'institutional correspondence stays person-backed');
    });

    test('both contexts resolving is what obliges C7 to ask', () {
      final a = authority(
        inst: standing(
          caps: {InstitutionCapabilityToken.officialRepresentation},
        ),
      );
      expect(a.resolve(ConsequentialAct.sendDirectMessage)!.isAvailable, isTrue);
      expect(a.resolve(ConsequentialAct.correspondAsInstitution)!.isAvailable,
          isTrue);
    });
  });
}
