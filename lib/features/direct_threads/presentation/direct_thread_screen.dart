import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/interactions/actor_context.dart';
import '../../../core/interactions/direct_threads_repository.dart';
import '../../../core/interactions/follows_repository.dart';
import '../../../core/interactions/presence_repository.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';

/// Phase-2 direct-message thread surface — works for both
/// `/direct/:threadId` (member shell) and
/// `/institution/:institutionId/direct/:threadId` (institution shell).
///
/// The `actor` for read + send is resolved from the route + active
/// institution identity via [resolveActorContext]. Messages render with
/// the institution name as headline when the row's `actorInstitutionId`
/// is set, with the human author shown as a "via @user" byline.
class DirectThreadScreen extends ConsumerStatefulWidget {
  const DirectThreadScreen({super.key, required this.threadId});

  final String threadId;

  @override
  ConsumerState<DirectThreadScreen> createState() =>
      _DirectThreadScreenState();
}

class _DirectThreadScreenState extends ConsumerState<DirectThreadScreen> {
  final _bodyCtrl = TextEditingController();
  bool _sending = false;
  String? _sendError;
  String? _seenForActorKey;

  @override
  void dispose() {
    _bodyCtrl.dispose();
    super.dispose();
  }

  /// Mark messages as seen the first time we render the screen with a
  /// resolved actor — and again every time the messages list rebuilds with
  /// new content. Best-effort: failures are silent.
  void _ensureSeen(ActorRef actor) {
    final key = '${actor.cacheKey}:${widget.threadId}';
    if (_seenForActorKey == key) return;
    _seenForActorKey = key;
    Future<void>(() async {
      try {
        await ref.read(directThreadsRepositoryProvider).markSeen(
              threadId: widget.threadId,
              actor: actor,
            );
      } catch (_) {}
    });
  }

  ActorRef? _actorRefFor(ActorContext? actor) {
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

  Future<void> _send(ActorRef actor, DirectThreadKey key) async {
    final body = _bodyCtrl.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      final repo = ref.read(directThreadsRepositoryProvider);
      await repo.sendMessage(
        threadId: widget.threadId,
        actor: actor,
        body: body,
      );
      _bodyCtrl.clear();
      ref.invalidate(directMessagesProvider(key));
      // Inbox snapshot (lastMessageAt/snippet/unread) updates server-side
      // on send; refresh the actor's inbox so /messages/direct shows this
      // thread at the top with the new preview without a manual reload.
      ref.invalidate(inboxThreadsProvider(actor));
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendError = 'Could not send message: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final actor = resolveActorContext(context, ref);
    final actorRef = _actorRefFor(actor);

    if (actorRef == null) {
      return AuraScaffold(
        showHeader: false,
        body: ListView(
          padding: const EdgeInsets.all(AuraSpace.s16),
          children: const [
            AuraEmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Sign in required',
              body: 'You need to be signed in to open direct messages.',
            ),
          ],
        ),
      );
    }

    final key = DirectThreadKey(threadId: widget.threadId, actor: actorRef);
    final threadAsync = ref.watch(directThreadProvider(key));
    final messagesAsync = ref.watch(directMessagesProvider(key));

    // Mark as seen once we have an actor; rerun when actor changes.
    _ensureSeen(actorRef);

    return AuraScaffold(
      showHeader: false,
      body: SafeArea(
        child: Column(
          children: [
            _ThreadHeader(threadAsync: threadAsync, actor: actor!),
            Expanded(
              child: messagesAsync.when(
                loading: () =>
                    const AuraLoadingState(message: 'Loading messages…'),
                error: (e, _) => Center(
                  child: AuraErrorState(
                    title: 'Could not load messages',
                    body: '$e',
                    action: AuraSecondaryButton(
                      label: 'Try again',
                      icon: Icons.refresh_rounded,
                      onPressed: () =>
                          ref.invalidate(directMessagesProvider(key)),
                    ),
                  ),
                ),
                data: (page) {
                  if (page.items.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AuraSpace.s24),
                        child: AuraEmptyState(
                          icon: Icons.chat_bubble_outline_rounded,
                          title: 'No messages yet',
                          body: 'Send the first message to start the thread.',
                        ),
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(directMessagesProvider(key));
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.all(AuraSpace.s12),
                      itemCount: page.items.length,
                      itemBuilder: (context, i) =>
                          _MessageBubble(message: page.items[i], actor: actor),
                    ),
                  );
                },
              ),
            ),
            if (_sendError != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpace.s14,
                  vertical: AuraSpace.s8,
                ),
                child: Text(
                  _sendError!,
                  style: AuraText.small
                      .copyWith(color: AuraSurface.dangerInk),
                ),
              ),
            _Composer(
              controller: _bodyCtrl,
              busy: _sending,
              actor: actor,
              onSend: () => _send(actorRef, key),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadHeader extends StatelessWidget {
  const _ThreadHeader({required this.threadAsync, required this.actor});

  final AsyncValue<DirectThreadInfo> threadAsync;
  final ActorContext actor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s14,
        vertical: AuraSpace.s10,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AuraSurface.divider)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: const Icon(
              Icons.arrow_back_rounded,
              size: 20,
              color: AuraSurface.muted,
            ),
          ),
          const SizedBox(width: AuraSpace.s10),
          Expanded(
            child: threadAsync.when(
              loading: () => Text(
                'Loading…',
                style: AuraText.body
                    .copyWith(color: AuraSurface.muted),
              ),
              error: (_, __) => Text(
                'Direct thread',
                style: AuraText.body
                    .copyWith(fontWeight: FontWeight.w800),
              ),
              data: (info) {
                final other = _otherSideLabel(info, actor);
                final otherActor = _otherSideActor(info, actor);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      other,
                      style: AuraText.body
                          .copyWith(fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (otherActor != null)
                      _PresenceLabel(actor: otherActor),
                    if (actor.isInstitution)
                      Text(
                        'Sending as ${actor.displayName ?? "your institution"}',
                        style: AuraText.micro
                            .copyWith(color: AuraSurface.faint),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  ActorRef? _otherSideActor(DirectThreadInfo info, ActorContext actor) {
    final candidates = [info.participantA, info.participantB];
    for (final p in candidates) {
      if (actor.isInstitution &&
          p.type == ActorType.institution &&
          p.institutionId == actor.institutionId) {
        continue;
      }
      if (actor.isUser &&
          p.type == ActorType.user &&
          p.userId == actor.userId) {
        continue;
      }
      if (p.type == ActorType.institution &&
          (p.institutionId ?? '').isNotEmpty) {
        return ActorRef.institution(p.institutionId!);
      }
      if (p.type == ActorType.user && (p.userId ?? '').isNotEmpty) {
        return ActorRef.user(p.userId!);
      }
    }
    return null;
  }

  String _otherSideLabel(DirectThreadInfo info, ActorContext actor) {
    final candidates = [info.participantA, info.participantB];
    for (final p in candidates) {
      if (actor.isInstitution &&
          p.type == ActorType.institution &&
          p.institutionId == actor.institutionId) {
        continue;
      }
      if (actor.isUser &&
          p.type == ActorType.user &&
          p.userId == actor.userId) {
        continue;
      }
      return p.type == ActorType.institution
          ? 'Institution thread'
          : 'Direct message';
    }
    return 'Direct thread';
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.actor});

  final DirectMessage message;
  final ActorContext actor;

  bool get _mine {
    if (actor.isInstitution &&
        message.actorType == ActorType.institution &&
        message.actorInstitutionId == actor.institutionId) {
      return true;
    }
    if (actor.isUser &&
        message.actorType == ActorType.user &&
        message.senderUserId == actor.userId) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isInstitution = message.isInstitutionVoice;
    final actorMap = isInstitution
        ? message.actorInstitution
        : message.senderUser;
    final actorName = actorMap?['name']?.toString() ??
        actorMap?['displayName']?.toString() ??
        actorMap?['handle']?.toString() ??
        '';
    final speakerName = isInstitution
        ? (message.senderUser?['handle']?.toString() ??
            message.senderUser?['displayName']?.toString() ??
            '')
        : null;

    final align = _mine ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor =
        _mine ? AuraSurface.accentSoft : AuraSurface.subtle;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: align,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s12,
            vertical: AuraSpace.s8,
          ),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(AuraRadius.md),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: Column(
            crossAxisAlignment: _mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actorName.isNotEmpty
                        ? actorName
                        : (isInstitution ? 'Institution' : 'User'),
                    style: AuraText.micro.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AuraSurface.muted,
                    ),
                  ),
                  if (isInstitution &&
                      speakerName != null &&
                      speakerName.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(
                      'via @$speakerName',
                      style: AuraText.micro
                          .copyWith(color: AuraSurface.faint),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                message.body,
                style: AuraText.body.copyWith(color: AuraSurface.ink),
              ),
              if (_mine) ...[
                const SizedBox(height: 4),
                Text(
                  message.seenAt != null
                      ? 'Seen'
                      : (message.deliveredAt != null ? 'Delivered' : 'Sending…'),
                  style: AuraText.micro.copyWith(
                    color: message.seenAt != null
                        ? AuraSurface.accentText
                        : AuraSurface.faint,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.busy,
    required this.actor,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool busy;
  final ActorContext actor;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.s12,
        AuraSpace.s10,
        AuraSpace.s12,
        AuraSpace.s12,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AuraSurface.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              style: AuraText.body,
              decoration: InputDecoration(
                hintText: actor.isInstitution
                    ? 'Send as ${actor.displayName ?? "institution"}…'
                    : 'Send a message…',
                hintStyle:
                    AuraText.body.copyWith(color: AuraSurface.faint),
                filled: true,
                fillColor: AuraSurface.subtle,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AuraRadius.md),
                  borderSide:
                      const BorderSide(color: AuraSurface.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AuraRadius.md),
                  borderSide:
                      const BorderSide(color: AuraSurface.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AuraRadius.md),
                  borderSide:
                      const BorderSide(color: Color(0xFF0D9488), width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AuraSpace.s12,
                  vertical: AuraSpace.s10,
                ),
              ),
            ),
          ),
          const SizedBox(width: AuraSpace.s10),
          AuraPrimaryButton(
            label: busy ? 'Sending…' : 'Send',
            icon: busy ? null : Icons.send_rounded,
            onPressed: busy ? null : onSend,
          ),
        ],
      ),
    );
  }
}

/// Renders the other-side actor's presence ("Active now" / "Active recently"
/// / dim "Offline"). Cheap autoDispose family — refreshed on rebuild.
class _PresenceLabel extends ConsumerWidget {
  const _PresenceLabel({required this.actor});

  final ActorRef actor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref
        .watch(presenceStateProvider(actor))
        .maybeWhen(data: (s) => s, orElse: () => null);
    if (state == null) return const SizedBox.shrink();
    final text = switch (state.status) {
      PresenceStatus.online => 'Active now',
      PresenceStatus.recent => 'Active recently',
      PresenceStatus.offline => '',
    };
    if (text.isEmpty) return const SizedBox.shrink();
    final color = state.status == PresenceStatus.online
        ? AuraSurface.goodInk
        : AuraSurface.faint;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: AuraText.micro.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
