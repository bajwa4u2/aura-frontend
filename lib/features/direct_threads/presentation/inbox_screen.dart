import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/interactions/direct_threads_repository.dart';
import '../../../core/auth/session_providers.dart';
import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/interactions/actor_context.dart';
import '../../../core/interactions/follows_repository.dart';
import '../../../core/media/aura_attachment_image.dart';
import '../../../core/product/product_language.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/identity/person_identity_model.dart';

/// Phase-3 Inbox — actor-aware list of every direct thread the active
/// actor participates in, sorted by last-message-at desc with unread
/// badges. Mounts at:
///   * `/messages`                     (member shell)
///   * `/institution/:id/messages`     (institution shell — same screen)
///
/// Domain 13 — `archived: true` renders the personal-archive view instead
/// (swipe restores rather than archives). Participant-scoped: archiving a
/// DM here never affects the other participant, matches
/// `capability/FOUNDER_ACCEPTANCE_REGISTER.md`'s Domain 13 resolution.
class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key, this.archived = false, this.institutionContextId});

  final bool archived;

  /// C3 — EXPLICIT institutional context, passed by the institution
  /// messages destination. Never inferred from the path: the route
  /// builder that OWNS the institution-inbox destination states it.
  final String? institutionContextId;

  /// C3 — explicit context, never path-inferred: the institution context
  /// exists ONLY when this surface was opened as the institution's inbox
  /// destination ([institutionContextId]) and the loaded workspace
  /// identity matches; otherwise the signed-in Person.
  ActorContext? _explicitActorContext(WidgetRef ref) {
    // F053/F116 — the same canonical reader the thread screen uses, so the
    // inbox and the thread it opens cannot disagree about who the viewer is.
    final me = AuraPersonIdentity.fromJson(
      ref.watch(authMeDataProvider).valueOrNull,
    );
    final uid = me.userId;
    final uname = me.displayName.isNotEmpty ? me.displayName : me.handle;
    final uavatar = me.avatarUrl;

    final instId = (institutionContextId ?? '').trim();
    if (instId.isNotEmpty) {
      final identity = ref.watch(institutionIdentityProvider);
      if (identity != null && identity.id == instId) {
        return ActorContext(
          type: ActorType.institution,
          userId: uid.isEmpty ? null : uid,
          institutionId: identity.id,
          displayName: identity.name,
          avatarUrl: identity.logoUrl,
          canSpeakAsInstitution: identity.canActAsInstitution,
        );
      }
    }
    if (uid.isEmpty) return null;
    return ActorContext(
      type: ActorType.user,
      userId: uid,
      displayName: uname,
      avatarUrl: uavatar,
    );
  }

  ActorRef? _actorRefFrom(ActorContext? actor) {
    if (actor == null) return null;
    if (actor.isInstitution) {
      final id = (actor.institutionId ?? '').trim();
      return id.isEmpty ? null : ActorRef.institution(id);
    }
    final uid = (actor.userId ?? '').trim();
    return uid.isEmpty ? null : ActorRef.user(uid);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actor = _explicitActorContext(ref);
    final actorRef = _actorRefFrom(actor);

    if (actorRef == null) {
      return AuraScaffold(
        showHeader: false,
        body: ListView(
          padding: const EdgeInsets.all(AuraSpace.s16),
          children: const [
            AuraEmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Sign in required',
              body: 'You need to be signed in to use messages.',
            ),
          ],
        ),
      );
    }

    final inboxAsync = archived
        ? ref.watch(archivedInboxThreadsProvider(actorRef))
        : ref.watch(inboxThreadsProvider(actorRef));
    void invalidateBoth() {
      ref.invalidate(inboxThreadsProvider(actorRef));
      ref.invalidate(archivedInboxThreadsProvider(actorRef));
    }
    return AuraScaffold(
      showHeader: false,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AuraSpace.s16,
                AuraSpace.s16,
                AuraSpace.s16,
                AuraSpace.s8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      archived ? 'Archived' : 'Messages',
                      style: AuraText.headline,
                    ),
                  ),
                  if (!archived)
                    IconButton(
                      tooltip: 'Archived conversations',
                      icon: const Icon(Icons.archive_outlined),
                      onPressed: () => context.push(
                        actor!.isInstitution
                            ? '/institution/${actor.institutionId}/messages/direct/archived'
                            : '/messages/direct/archived',
                      ),
                    ),
                  if (actor!.isInstitution)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AuraSpace.s8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AuraSurface.accentSoft,
                        borderRadius: BorderRadius.circular(AuraRadius.pill),
                        border:
                            Border.all(color: AuraSurface.accent.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        'as ${actor.displayName ?? "institution"}',
                        style: AuraText.micro.copyWith(
                          color: AuraSurface.accentText,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: inboxAsync.when(
                loading: () =>
                    const AuraLoadingState(message: 'Loading inbox…'),
                error: (e, _) => Center(
                  child: AuraErrorState(
                    title: 'Could not load inbox',
                    body: '$e',
                    action: AuraSecondaryButton(
                      label: ProductLabels.of(ProductAction.retry),
                      icon: Icons.refresh_rounded,
                      onPressed: invalidateBoth,
                    ),
                  ),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return Center(
                      child: AuraEmptyState(
                        icon: archived
                            ? Icons.archive_outlined
                            : Icons.chat_bubble_outline_rounded,
                        title: archived
                            ? 'No archived conversations'
                            : 'No conversations yet',
                        body: archived
                            ? 'Conversations you archive show up here.'
                            : 'Start a thread from a profile or post to see it here.',
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async => invalidateBoth(),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(AuraSpace.s12),
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AuraSpace.s8),
                      itemBuilder: (context, i) => _InboxTile(
                        thread: items[i],
                        actor: actor,
                        actorRef: actorRef,
                        archived: archived,
                        onArchiveChanged: invalidateBoth,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InboxTile extends ConsumerWidget {
  const _InboxTile({
    required this.thread,
    required this.actor,
    required this.actorRef,
    this.archived = false,
    this.onArchiveChanged,
  });

  final InboxThread thread;
  final ActorContext actor;
  final ActorRef actorRef;
  final bool archived;
  final VoidCallback? onArchiveChanged;

  /// Whichever participant is NOT the active actor — the "other side".
  DirectThreadParticipantWithEmbed _other() {
    final a = thread.participantA as DirectThreadParticipantWithEmbed;
    final b = thread.participantB as DirectThreadParticipantWithEmbed;
    if (actor.isInstitution) {
      return a.type == ActorType.institution &&
              a.institutionId == actor.institutionId
          ? b
          : a;
    }
    return a.type == ActorType.user && a.userId == actor.userId ? b : a;
  }

  String _route(BuildContext context) {
    if (actor.isInstitution) {
      return '/institution/${actor.institutionId}/direct/${thread.threadId}';
    }
    return '/direct/${thread.threadId}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final other = _other();
    final isInstitution = other.type == ActorType.institution;
    // F053/F116 — the counterpart is resolved once, through the canonical
    // model, and named by its canonical fallback order. The old inline
    // chain ended in the literal 'User', which is the F054 class of defect:
    // a surface inventing a label for someone it failed to resolve.
    final person = AuraPersonIdentity.fromJson(other.user);
    final name = isInstitution
        ? (other.institution?['name']?.toString() ?? 'Institution')
        : person.label;
    final logoUrl = isInstitution
        ? (other.institution?['logoUrl']?.toString() ?? '')
        : (person.avatarUrl ?? '');
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final unread = thread.unreadCount;
    final preview = (thread.lastMessageSnippet ?? '').trim();

    final tile = InkWell(
      onTap: () => context.push(_route(context)),
      borderRadius: BorderRadius.circular(AuraRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AuraSpace.s12),
        decoration: BoxDecoration(
          color: unread > 0 ? AuraSurface.accentSoft : AuraSurface.subtle,
          borderRadius: BorderRadius.circular(AuraRadius.md),
          border: Border.all(color: AuraSurface.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AuraSurface.accentSoft,
                border: Border.all(color: AuraSurface.divider),
              ),
              child: logoUrl.isNotEmpty
                  ? AuraAttachmentImage(
                      url: logoUrl,
                      attachmentId: 'thread:${thread.threadId}:partner',
                      fit: BoxFit.cover,
                      errorWidget: (_) => Center(
                        child: Text(
                          initial,
                          style: AuraText.body.copyWith(
                            color: AuraSurface.accentText,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        initial,
                        style: AuraText.body.copyWith(
                          color: AuraSurface.accentText,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: AuraSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AuraText.body.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (thread.lastMessageAt != null)
                        Text(
                          _formatRelative(thread.lastMessageAt!),
                          style: AuraText.micro
                              .copyWith(color: AuraSurface.faint),
                        ),
                    ],
                  ),
                  if (preview.isNotEmpty)
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AuraText.small
                          .copyWith(color: AuraSurface.muted),
                    ),
                ],
              ),
            ),
            if (unread > 0) ...[
              const SizedBox(width: AuraSpace.s8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpace.s8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AuraSurface.accent,
                  borderRadius: BorderRadius.circular(AuraRadius.pill),
                ),
                child: Text(
                  unread > 99 ? '99+' : '$unread',
                  style: AuraText.micro.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    // Domain 13 — personal organization state. Swipe to archive/unarchive
    // this actor's own view; the other participant is never affected.
    return Dismissible(
      key: ValueKey('dm-${thread.threadId}-$archived'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s16),
        margin: const EdgeInsets.only(bottom: 0),
        decoration: BoxDecoration(
          color: archived ? AuraSurface.accentSoft : AuraSurface.coRose.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(AuraRadius.md),
        ),
        child: Icon(
          archived ? Icons.unarchive_outlined : Icons.archive_outlined,
          color: archived ? AuraSurface.accentText : AuraSurface.coRose,
        ),
      ),
      confirmDismiss: (_) async {
        try {
          await ref.read(directThreadsRepositoryProvider).setArchived(
                threadId: thread.threadId,
                actor: actorRef,
                archived: !archived,
              );
          onArchiveChanged?.call();
          return true;
        } catch (_) {
          return false;
        }
      },
      child: tile,
    );
  }
}

String _formatRelative(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  final yyyy = dt.year.toString().padLeft(4, '0');
  final mm = dt.month.toString().padLeft(2, '0');
  final dd = dt.day.toString().padLeft(2, '0');
  return '$yyyy-$mm-$dd';
}
