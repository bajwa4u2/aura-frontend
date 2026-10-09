import 'package:aura/app/shell/member_shell.dart';
import 'package:aura/core/institutions/institution_access_provider.dart';
import 'package:aura/features/institutions/kind/kind_composition.dart';
import 'package:flutter_test/flutter_test.dart';

/// PER-KIND COMPOSITION (DD-42 phase 3, 2026-10-09): the kind decides words
/// and emphasis, never authority.
void main() {
  const kinds = [
    'GOVERNMENT_CIVIC',
    'EDUCATIONAL',
    'NONPROFIT_COMMUNITY',
    'RELIGIOUS',
    'CORPORATE_BUSINESS',
    'MEDIA',
    'HEALTHCARE',
  ];

  const owner = InstitutionIdentity(
    id: 'i1',
    name: 'Taylor Clinic',
    slug: 'taylor-clinic',
    isAuthorizedSpeaker: true,
    capabilities: {
      'MANAGE_MEMBERS', 'MANAGE_INVITATIONS', 'MANAGE_JOIN_REQUESTS', 'MANAGE_MEETINGS', 'MANAGE_AVAILABILITY',
      'MANAGE_SPACES', 'MANAGE_ANNOUNCEMENTS', 'MANAGE_BRANDING', 'MANAGE_DOMAINS', 'MANAGE_BILLING',
      'MANAGE_VERIFICATION', 'HOST_MEETINGS', 'OFFICIAL_REPRESENTATION', 'PUBLISH_OFFICIAL', 'START_LIVE',
    },
    role: 'OWNER',
    kind: 'HEALTHCARE',
  );

  test('the bundled catalogue composes all seven kinds, each with all three Today blocks', () {
    expect(kBundledKindCatalogue.keys.toSet(), kinds.toSet());
    for (final k in kinds) {
      expect(kBundledKindCatalogue[k]!.todayOrder.toSet(), {'public', 'meetings', 'announcement'}, reason: k);
    }
  });

  test('the guards the approved table names are carried', () {
    Set<String> keys(String k) => kBundledKindCatalogue[k]!.guards.map((g) => g.key).toSet();
    expect(keys('GOVERNMENT_CIVIC'), contains('official_speech'));
    expect(keys('EDUCATIONAL'), contains('minors'));
    expect(keys('HEALTHCARE'), contains('no_health_information'));
    expect(keys('MEDIA'), contains('corrections_on_record'));
  });

  test('a healthcare rail lets Live and Spaces recede and names its units Sites', () {
    final entries = buildInstitutionWorkspaceEntries(owner, composition: kBundledKindCatalogue['HEALTHCARE']!);
    final labels = entries.map((e) => e.label).toList();
    final community = labels.sublist(labels.indexOf('Members'), labels.indexOf('Members') + 3);
    expect(community, ['Members', 'Spaces', 'Live']);
    expect(labels, contains('Sites'));
    expect(labels, isNot(contains('Units')));
    // The section stays labelled on its (new) first entry.
    expect(entries.firstWhere((e) => e.label == 'Members').sectionLabel, 'COMMUNITY');
    expect(entries.firstWhere((e) => e.label == 'Spaces').sectionLabel, isNull);
  });

  test('the kind never adds or removes a destination', () {
    final neutral = buildInstitutionWorkspaceEntries(owner).map((e) => e.label).toSet()
      ..remove('Units');
    for (final k in kinds) {
      final c = kBundledKindCatalogue[k]!;
      final labels = buildInstitutionWorkspaceEntries(owner, composition: c).map((e) => e.label).toSet()
        ..remove(c.unitPlural);
      expect(labels, neutral, reason: k);
    }
  });

  test('a composition read from the server falls back sensibly', () {
    final c = KindComposition.fromJson({'kind': 'RELIGIOUS', 'publicWord': 'the congregation', 'unit': {'singular': 'Branch', 'plural': 'Branches'}});
    expect(c.todayOrder, ['public', 'meetings', 'announcement']);
    expect(c.publicWordCapitalized, 'The congregation');
    expect(KindComposition.neutral.guards, isEmpty);
  });
}
