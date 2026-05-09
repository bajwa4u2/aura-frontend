import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/interactions/actor_context.dart';
import '../../../core/interactions/direct_threads_repository.dart';
import '../../../core/interactions/follows_repository.dart';
import '../../../core/media/aura_attachment_image.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';

/// Phase-3 Inbox — actor-aware list of every direct thread the active
/// actor participates in, sorted by last-message-at desc with unread
/// badges. Mounts at:
///   * `/messages`                     (member shell)
///   * `/institution/:id/messages`     (institution shell — same screen)
class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  ActorRef? _actorRefOf(ActorContext? actor) {
    if (actor == null) return null;
    if (actor.isInstitution) {
      final id = (actor.institutionId ?? '').trim();
      if (id.isEmpty) return null;
      return ActorRef.institution(id);
    }
    final uid = (actor.userId ?? '').trim();
    if (uid.isEmpty) return null;
    return ActorRef.user(uid);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actor = resolveActorContext(context, ref);
    final actorRef = _actorRefOf(actor);

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

    final inboxAsync = ref.watch(inboxThreadsProvider(actorRef));
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
                  const Expanded(
                    child: Text('Messages', style: AuraText.headline),
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
                      label: 'Try again',
                      icon: Icons.refresh_rounded,
                      onPressed: () =>
                          ref.invalidate(inboxThreadsProvider(actorRef)),
                    ),
                  ),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return const Center(
                      child: AuraEmptyState(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: 'No conversations yet',
                        body:
                            'Start a thread from a profile or post to see it here.',
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(inboxThreadsProvider(actorRef));
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.all(AuraSpace.s12),
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AuraSpace.s8),
                      itemBuilder: (context, i) => _InboxTile(
                        thread: items[i],
                        actor: actor,
                        actorRef: actorRef,
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
  });

  final InboxThread thread;
  final ActorContext actor;
  final ActorRef actorRef;

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
    final name = isInstitution
        ? (other.institution?['name']?.toString() ?? 'Institution')
        : (other.user?['displayName']?.toString() ??
            other.user?['handle']?.toString() ??
            'User');
    final logoUrl = isInstitution
        ? (other.institution?['logoUrl']?.toString() ?? '')
        : (other.user?['avatarUrl']?.toString() ?? '');
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final unread = thread.unreadCount;
    final preview = (thread.lastMessageSnippet ?? '').trim();

    return InkWell(
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
