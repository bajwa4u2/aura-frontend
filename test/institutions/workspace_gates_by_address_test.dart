import 'dart:io';

import 'package:aura/app/route_classification.dart';
import 'package:aura/core/authority/capability_projection.dart';
import 'package:aura/core/institutions/institution_destination_authority.dart';
import 'package:flutter_test/flutter_test.dart';

/// PHASE 2 (2026-10-09): THE WORKSPACE ASKS ABOUT THE INSTITUTION IN THE
/// ADDRESS. The router's ambient gate read the person's oldest membership, so
/// an admin of B who is a plain member of A was refused B's leadership pages;
/// editing an announcement and creating a meeting had no check at all.
void main() {
  group('which paths name their institution', () {
    test('an addressed path is recognised', () {
      expect(institutionAddressedIn('/institution/masjid-al-noor/announcements'), isTrue);
      expect(institutionAddressedIn('/institution/masjid-al-noor'), isTrue);
      expect(institutionAddressedIn('/institution/abc123/domains?x=1'), isTrue);
    });

    test('shorthand, standing and other paths are not', () {
      expect(institutionAddressedIn('/institution/announcements'), isFalse);
      expect(institutionAddressedIn('/institution/dashboard'), isFalse);
      expect(institutionAddressedIn('/institution/standing'), isFalse);
      expect(institutionAddressedIn('/home'), isFalse);
    });
  });

  group('every leadership section names what it needs', () {
    test('leadership sections carry their own acts; reading stays open to members', () {
      for (final section in ['verification', 'edit-profile', 'domains']) {
        expect(institutionDestinationAuthority(section), isNotEmpty, reason: section);
      }
      for (final section in ['announcements', 'live-rooms']) {
        expect(institutionDestinationAuthority(section), isEmpty, reason: section);
      }
    });

    test('editing an announcement needs the authoring act, like composing one', () {
      expect(
        institutionDestinationAuthority('announcements/edit'),
        institutionDestinationAuthority('announcements/new'),
      );
    });

    test('creating a meeting needs hosting or meeting management', () {
      expect(
        institutionDestinationAuthority('meetings/new').toSet(),
        {ConsequentialAct.hostMeeting, ConsequentialAct.manageMeetings},
      );
    });

    test('an owner of an unverified institution can still reach verification', () {
      // Owners hold MANAGE_VERIFICATION from the start; verification must never
      // need verification.
      expect(institutionDestinationAuthority('verification'), contains(ConsequentialAct.manageVerification));
    });
  });

  group('the router and screens', () {
    final router = File('lib/router.dart').readAsStringSync();

    test('the ambient admin gates stand aside for addressed paths', () {
      expect(router.contains('!addressed && requiresInstitutionAdmin(path)'), isTrue);
      expect(router.contains('!addressed &&\n            requiresInstitutionAdminOrSpeaker(path)') ||
          router.contains('!addressed &&\r\n            requiresInstitutionAdminOrSpeaker(path)'), isTrue);
    });

    test('edit and new-meeting routes are checked against the address', () {
      expect(router.contains("'announcements/edit',"), isTrue);
      expect(router.contains("'meetings/new',"), isTrue);
    });

    test('the legacy create-account form is gone', () {
      expect(router.contains('InstitutionRequestVerificationScreen'), isFalse);
      expect(File('lib/features/institutions/verification/institution_request_verification_screen.dart').existsSync(), isFalse);
    });

    test('members, announcements and meetings ask about this institution', () {
      for (final path in [
        'lib/features/institutions/presentation/institution_members_screen.dart',
        'lib/features/institutions/announcements/institution_announcements_screen.dart',
        'lib/features/meetings/presentation/meetings_home_screen.dart',
      ]) {
        final src = File(path).readAsStringSync();
        expect(src.contains('capabilityProjectionForProvider('), isTrue, reason: path);
      }
    });

    test('the institution name in the rail opens the front door of this institution', () {
      final shell = File('lib/app/shell/member_shell.dart').readAsStringSync();
      expect(shell.contains("context.go('/institution/dashboard')"), isFalse);
      expect(shell.contains('institutionWorkspaceHome('), isTrue);
    });
  });
}
