/// BLOCKED PEOPLE — the surface an existing authority never had.
///
/// ## THE GAP THIS CLOSES
///
/// Blocking worked. `POST /blocks/:userId` is reachable from a post's menu and
/// from a profile, `GET /blocks` is fetched on every feed render, and
/// `DELETE /blocks/:userId` has existed the whole time.
///
/// But `GET /blocks` was consumed ONLY to build a set of ids for hiding
/// content — the people were never shown — and `unblock()` had NO CALLER
/// ANYWHERE IN THE APP. So a person could block someone and then had no way
/// to see who they had blocked, and no way to undo it. A one-way door with no
/// handle on the inside, built on an authority that already supported the way
/// back.
///
/// That is what "missing from an existing authority" means, and it is why this
/// screen is part of a Preferences reconstruction rather than a new feature.
///
/// ## WHY IT LIVES UNDER PRIVACY
///
/// Blocking is a boundary a person draws around their own experience. It is
/// not moderation, not safety enforcement, and not an institutional act — the
/// backend models it as `UserBlock`, person to person, and Preferences names
/// it the way the person experiences it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/compliance/blocks_repository.dart';
import '../../../core/errors/app_error_mapper.dart';
import '../../../core/product/product_language.dart';
import '../../../core/product/product_state.dart';
import '../../../core/product/product_state_view.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import 'widgets/me_section.dart';

/// The people this account has blocked.
///
/// Its own provider rather than reusing `blockedUserIdsProvider`: that one
/// deliberately swallows errors and returns an empty set, because a network
/// failure must never hide the whole feed. Here an empty list and a failed
/// load are completely different things to show a person, so the failure has
/// to survive.
final blockedPeopleProvider = FutureProvider.autoDispose<List<BlockedUser>>(
  (ref) => ref.watch(blocksRepositoryProvider).listMine(),
);

class BlockedPeopleScreen extends ConsumerStatefulWidget {
  const BlockedPeopleScreen({super.key});

  @override
  ConsumerState<BlockedPeopleScreen> createState() =>
      _BlockedPeopleScreenState();
}

class _BlockedPeopleScreenState extends ConsumerState<BlockedPeopleScreen> {
  final _working = <String>{};

  Future<void> _unblock(BlockedUser person) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AuraSurface.card,
        title: Text('Unblock ${person.displayName}?', style: AuraText.title),
        // REVERSIBLE, and said so. The consequence is stated plainly because
        // the person is undoing a boundary they set deliberately, and they
        // should know exactly what returns.
        content: Text(
          'They will be able to see your public work and reach you again. '
          'You can block them again at any time.',
          style: AuraText.body.copyWith(color: AuraSurface.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _working.add(person.id));
    try {
      await ref.read(blocksRepositoryProvider).unblock(person.id);

      // BOTH caches. This list is what the person is looking at; the id set is
      // what every feed card consults to decide whether to render. Refreshing
      // one and not the other would show the block gone here and still hide
      // their posts everywhere else.
      ref.invalidate(blockedPeopleProvider);
      ref.invalidate(blockedUserIdsProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unblocked ${person.displayName}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppErrorMapper.from(e, feature: 'unblock this person').message,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _working.remove(person.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocked = ref.watch(blockedPeopleProvider);

    return AuraScaffold(
      title: 'Blocked people',
      maxWidth: 720,
      body: RefreshIndicator(
        color: AuraSurface.accent,
        onRefresh: () async => ref.invalidate(blockedPeopleProvider),
        child: blocked.when(
          // THROUGH THE STATE AUTHORITY, not a bare spinner. Loading, empty
          // and error are product states with settled meaning and wording;
          // deciding them locally is how the same condition came to look like
          // five different things across the app.
          loading: () => const AuraProductState(
            state: ProductState.loading,
            subject: ProductNoun.person,
          ),
          // A FAILED LOAD IS NOT AN EMPTY LIST. Showing "You have not blocked
          // anyone" when the request failed would tell a person something
          // false about their own boundaries — which is why this is the error
          // state and not an empty one.
          error: (e, _) => AuraProductState(
            state: ProductState.error,
            subject: ProductNoun.person,
            detail: AppErrorMapper.from(
              e,
              feature: 'load your blocked list',
            ).message,
            onRecover: () => ref.invalidate(blockedPeopleProvider),
          ),
          data: (people) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.s16,
              AuraSpace.s16,
              AuraSpace.s16,
              AuraSpace.s32,
            ),
            children: [
              Text(
                people.isEmpty
                    ? 'You have not blocked anyone.'
                    : 'People you have blocked cannot reach you, and their '
                        'work does not appear in your feed.',
                style: AuraText.small
                    .copyWith(color: AuraSurface.faint, height: 1.4),
              ),
              const SizedBox(height: AuraSpace.s20),
              if (people.isNotEmpty)
                MeSection(
                  title: '${people.length} blocked',
                  children: [
                    for (final p in people)
                      _BlockedRow(
                        person: p,
                        busy: _working.contains(p.id),
                        onUnblock: () => _unblock(p),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlockedRow extends StatelessWidget {
  const _BlockedRow({
    required this.person,
    required this.busy,
    required this.onUnblock,
  });

  final BlockedUser person;
  final bool busy;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    final handle = person.handle.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s16,
        vertical: AuraSpace.s12,
      ),
      child: Row(
        children: [
          AuraAvatar(
            name: person.displayName,
            imageUrl: person.avatarUrl,
            size: 36,
          ),
          const SizedBox(width: AuraSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person.displayName,
                  style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                ),
                if (handle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '@$handle',
                    style: AuraText.small.copyWith(color: AuraSurface.muted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AuraSpace.s12),
          if (busy)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            AuraSecondaryButton(label: 'Unblock', onPressed: onUnblock),
        ],
      ),
    );
  }
}
