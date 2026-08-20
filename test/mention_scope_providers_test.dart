import 'package:aura/core/interactions/actor_context.dart';
import 'package:aura/core/interactions/direct_threads_repository.dart';
import 'package:aura/core/tagging/mention_scope.dart';
import 'package:aura/core/tagging/mention_scope_providers.dart';
import 'package:aura/core/tagging/tag_entities.dart';
import 'package:aura/features/institutions/data/institutions_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Domain 9 — Mention Target Eligibility, frontend contextual coherence.
//
// CO-RC-C7-005 Phase 5 (2026-08-20): the `threadMentionScopeProvider` groups
// that stood here covered the legacy Thread/Space mention scope. That provider
// and the repositories it read were retired with the correspondence runtime,
// so those tests went with their subject rather than being kept alive against
// stand-ins for deleted code.
//
// `directThreadMentionScope` survives — a pure function over a thread object
// the caller already holds, with no legacy dependency — and its coverage is
// unchanged: a DM's mention scope is exactly its two participants, never the
// caller, never an unrelated institution.

List<TagSuggestion> _bounded(MentionScope scope) =>
    (scope as MentionScopeBounded).eligible;

void main() {
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
