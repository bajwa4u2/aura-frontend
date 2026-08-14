import 'package:aura/core/interactions/actor_context.dart';
import 'package:aura/core/interactions/direct_threads_repository.dart';
import 'package:aura/core/tagging/mention_scope.dart';
import 'package:aura/core/tagging/mention_scope_providers.dart';
import 'package:aura/core/tagging/tag_entities.dart';
import 'package:aura/features/correspondence/data/spaces_repository.dart';
import 'package:aura/features/correspondence/data/threads_repository.dart';
import 'package:aura/features/institutions/data/institutions_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Domain 9 — Mention Target Eligibility, frontend contextual coherence.
// Proves threadMentionScopeProvider / directThreadMentionScope derive the
// exact same candidate sets aura-backend's assertMentionTargetsEligible
// enforces: private-Thread person eligibility = Thread membership;
// non-private (Space-owned) Thread person eligibility = the parent Space's
// active membership; institution eligibility (either case) = the parent
// Space's own owning institution only; a Personal Space offers none.

Map<String, dynamic> _memberRow(String userId, String name) => {
  'userId': userId,
  'user': {'id': userId, 'displayName': name, 'handle': name.toLowerCase()},
};

class _FakeThreadsRepository extends ThreadsRepository {
  _FakeThreadsRepository(this.thread) : super(Dio());
  final Map<String, dynamic> thread;

  @override
  Future<Map<String, dynamic>> getThread(
    String threadId, {
    bool forceRefresh = false,
  }) async => thread;
}

class _FakeSpacesRepository extends SpacesRepository {
  _FakeSpacesRepository(this.space) : super(Dio());
  final Map<String, dynamic> space;

  @override
  Future<Map<String, dynamic>> getSpace(String spaceId) async => space;
}

class _FakeInstitutionsRepository extends InstitutionsRepository {
  _FakeInstitutionsRepository(this.space) : super(Dio());
  final Map<String, dynamic> space;

  @override
  Future<Map<String, dynamic>> getInstitutionSpace(
    String institutionId,
    String spaceId,
  ) async => space;
}

List<TagSuggestion> _bounded(MentionScope scope) =>
    (scope as MentionScopeBounded).eligible;

void main() {
  group('threadMentionScopeProvider — private thread', () {
    test('Personal Space: person candidates = Thread membership, zero institution candidates', () async {
      final thread = {
        'id': 't1',
        'isPrivate': true,
        'spaceId': 's1',
        'space': {'institutionId': null},
        'members': [_memberRow('u1', 'Amina'), _memberRow('u2', 'Jamal')],
      };
      final container = ProviderContainer(
        overrides: [
          threadsRepositoryProvider.overrideWithValue(_FakeThreadsRepository(thread)),
        ],
      );
      addTearDown(container.dispose);

      final scope = await container.read(threadMentionScopeProvider('t1').future);
      final eligible = _bounded(scope);

      expect(eligible.where((e) => e.kind == TagKind.member).map((e) => e.canonicalId), ['u1', 'u2']);
      expect(eligible.where((e) => e.kind == TagKind.institution), isEmpty);
    });

    test('Institution Space: person = Thread membership, institution = the owning institution only', () async {
      final thread = {
        'id': 't2',
        'isPrivate': true,
        'spaceId': 's2',
        'space': {'institutionId': 'inst-1'},
        'members': [_memberRow('u1', 'Amina')],
      };
      final spaceDetail = {
        'id': 's2',
        'institution': {'id': 'inst-1', 'name': 'CivicOrg', 'slug': 'civicorg'},
        'members': [_memberRow('u1', 'Amina'), _memberRow('u3', 'NotAThreadMember')],
      };
      final container = ProviderContainer(
        overrides: [
          threadsRepositoryProvider.overrideWithValue(_FakeThreadsRepository(thread)),
          institutionsRepositoryProvider.overrideWithValue(_FakeInstitutionsRepository(spaceDetail)),
        ],
      );
      addTearDown(container.dispose);

      final scope = await container.read(threadMentionScopeProvider('t2').future);
      final eligible = _bounded(scope);

      // Private thread's own membership stays authoritative -- the Space's
      // wider roster ('u3') must NOT leak in as a person candidate here.
      expect(eligible.where((e) => e.kind == TagKind.member).map((e) => e.canonicalId), ['u1']);
      final institutions = eligible.where((e) => e.kind == TagKind.institution).toList();
      expect(institutions, hasLength(1));
      expect(institutions.single.canonicalId, 'inst-1');
      expect(institutions.single.display, 'CivicOrg');
    });
  });

  group('threadMentionScopeProvider — non-private (Space-owned) thread', () {
    test('Personal Space: person candidates = Space active membership, not the (possibly incomplete) Thread member list', () async {
      final thread = {
        'id': 't3',
        'isPrivate': false,
        'spaceId': 's3',
        'space': {'institutionId': null},
        'members': <Map<String, dynamic>>[], // deliberately incomplete, matches real non-private threads
      };
      final space = {
        'id': 's3',
        'members': [_memberRow('u1', 'Amina'), _memberRow('u2', 'Jamal'), _memberRow('u4', 'Sara')],
      };
      final container = ProviderContainer(
        overrides: [
          threadsRepositoryProvider.overrideWithValue(_FakeThreadsRepository(thread)),
          spacesRepositoryProvider.overrideWithValue(_FakeSpacesRepository(space)),
        ],
      );
      addTearDown(container.dispose);

      final scope = await container.read(threadMentionScopeProvider('t3').future);
      final eligible = _bounded(scope);

      expect(eligible.map((e) => e.canonicalId).toSet(), {'u1', 'u2', 'u4'});
      expect(eligible.where((e) => e.kind == TagKind.institution), isEmpty);
    });

    test('Institution Space: person = Space active membership, institution = the owning institution', () async {
      final thread = {
        'id': 't4',
        'isPrivate': false,
        'spaceId': 's4',
        'space': {'institutionId': 'inst-2'},
        'members': <Map<String, dynamic>>[],
      };
      final spaceDetail = {
        'id': 's4',
        'institution': {'id': 'inst-2', 'name': 'TownHall', 'slug': 'townhall'},
        'members': [_memberRow('u5', 'Rafiq')],
      };
      final container = ProviderContainer(
        overrides: [
          threadsRepositoryProvider.overrideWithValue(_FakeThreadsRepository(thread)),
          institutionsRepositoryProvider.overrideWithValue(_FakeInstitutionsRepository(spaceDetail)),
        ],
      );
      addTearDown(container.dispose);

      final scope = await container.read(threadMentionScopeProvider('t4').future);
      final eligible = _bounded(scope);

      expect(eligible.where((e) => e.kind == TagKind.member).map((e) => e.canonicalId), ['u5']);
      final institutions = eligible.where((e) => e.kind == TagKind.institution).toList();
      expect(institutions.single.canonicalId, 'inst-2');
    });
  });

  group('directThreadMentionScope', () {
    test('user-to-user DM offers the other participant, never the caller, never an institution', () {
      final info = DirectThreadInfo(
        threadId: 'dm1',
        participantA: const DirectThreadParticipantWithEmbed(
          type: ActorType.user,
          userId: 'u1',
          user: {'displayName': 'Amina', 'handle': 'amina'},
        ),
        participantB: const DirectThreadParticipantWithEmbed(
          type: ActorType.user,
          userId: 'u2',
          user: {'displayName': 'Jamal', 'handle': 'jamal'},
        ),
        route: '/dm/dm1',
        createdNow: false,
      );
      const actor = ActorContext(type: ActorType.user, userId: 'u1');

      final scope = directThreadMentionScope(info, actor);
      final eligible = _bounded(scope);

      expect(eligible, hasLength(1));
      expect(eligible.single.kind, TagKind.member);
      expect(eligible.single.canonicalId, 'u2');
    });

    test('user-to-institution DM offers the institution participant when the caller is the user side', () {
      final info = DirectThreadInfo(
        threadId: 'dm2',
        participantA: const DirectThreadParticipantWithEmbed(
          type: ActorType.user,
          userId: 'u1',
          user: {'displayName': 'Amina', 'handle': 'amina'},
        ),
        participantB: const DirectThreadParticipantWithEmbed(
          type: ActorType.institution,
          institutionId: 'inst-3',
          institution: {'name': 'CivicOrg', 'slug': 'civicorg'},
        ),
        route: '/dm/dm2',
        createdNow: false,
      );
      const actor = ActorContext(type: ActorType.user, userId: 'u1');

      final scope = directThreadMentionScope(info, actor);
      final eligible = _bounded(scope);

      expect(eligible, hasLength(1));
      expect(eligible.single.kind, TagKind.institution);
      expect(eligible.single.canonicalId, 'inst-3');
    });

    test('an institution unrelated to the DM is never offered (scope is exactly the two participants)', () {
      final info = DirectThreadInfo(
        threadId: 'dm3',
        participantA: const DirectThreadParticipantWithEmbed(type: ActorType.user, userId: 'u1'),
        participantB: const DirectThreadParticipantWithEmbed(type: ActorType.user, userId: 'u2'),
        route: '/dm/dm3',
        createdNow: false,
      );
      const actor = ActorContext(type: ActorType.user, userId: 'u1');

      final scope = directThreadMentionScope(info, actor);
      final eligible = _bounded(scope);

      expect(eligible.where((e) => e.kind == TagKind.institution), isEmpty);
    });
  });
}
