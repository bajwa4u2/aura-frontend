import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/product/product_language.dart';
import '../../../core/product/product_state.dart';
import '../../../core/product/product_state_view.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/conversations_repository.dart';
import 'add_people_sheet.dart';
import 'conversation_identity.dart';

/// ONE Conversation screen (canon): talk immediately; capabilities appear
/// when intention reaches them. Text v1; richer capabilities (attachments,
/// calls, screen share, Live) attach here as their conversation-surface
/// adapters land — they never fork sibling products.
class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key, required this.conversationId});
  final String conversationId;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _composer = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(conversationsRepositoryProvider)
          .send(widget.conversationId, text);
      _composer.clear();
      ref.invalidate(conversationMessagesProvider(widget.conversationId));
      ref.invalidate(conversationsListProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send — try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _menu(String action, Conversation c) async {
    final repo = ref.read(conversationsRepositoryProvider);
    switch (action) {
      case 'add':
        await showAddPeopleSheet(context, ref, widget.conversationId);
        return;
      case 'rename':
        final controller = TextEditingController(text: c.name ?? '');
        final name = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Name this conversation'),
            content: TextField(controller: controller, autofocus: true),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(controller.text),
                  child: const Text('Save')),
            ],
          ),
        );
        if (name != null) {
          await repo.rename(widget.conversationId, name.trim());
          ref.invalidate(conversationProvider(widget.conversationId));
          ref.invalidate(conversationsListProvider);
        }
        return;
      case 'mute':
        await repo.setMuted(widget.conversationId, !c.muted);
        ref.invalidate(conversationProvider(widget.conversationId));
        return;
      case 'archive':
        await repo.setArchived(widget.conversationId, !c.archived);
        ref.invalidate(conversationsListProvider);
        if (mounted) context.pop();
        return;
      case 'leave':
        await repo.leave(widget.conversationId);
        ref.invalidate(conversationsListProvider);
        if (mounted) context.pop();
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversationAsync =
        ref.watch(conversationProvider(widget.conversationId));
    final messagesAsync =
        ref.watch(conversationMessagesProvider(widget.conversationId));
    final myUserId = ref.watch(myUserIdProvider);

    // Reading the conversation marks it read (cursor truth server-side).
    ref.listen(conversationMessagesProvider(widget.conversationId),
        (prev, next) {
      next.whenData((_) {
        ref
            .read(conversationsRepositoryProvider)
            .markRead(widget.conversationId)
            .ignore();
      });
    });

    return conversationAsync.when(
      loading: () => AuraScaffold(
          body: const AuraProductState(
              state: ProductState.loading,
              subject: ProductNoun.conversation)),
      error: (e, _) => AuraScaffold(
        body: AuraProductState(
          state: ProductState.unavailable,
          subject: ProductNoun.conversation,
          detail: 'It may have been removed, or you may have left it.',
          action: AuraSecondaryButton(
              label: 'Back to Messages', onPressed: () => context.pop()),
        ),
      ),
      data: (c) => AuraScaffold(
        title: conversationDisplayName(c, myUserId),
        actions: [
          PopupMenuButton<String>(
            onSelected: (a) => _menu(a, c),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'add', child: Text('Add people')),
              const PopupMenuItem(value: 'rename', child: Text('Name')),
              PopupMenuItem(
                  value: 'mute', child: Text(c.muted ? 'Unmute' : 'Mute')),
              PopupMenuItem(
                  value: 'archive',
                  child: Text(c.archived ? 'Unarchive' : 'Archive')),
              const PopupMenuItem(value: 'leave', child: Text('Leave')),
            ],
          ),
        ],
        body: Column(
          children: [
            Expanded(
              child: messagesAsync.when(
                loading: () => const AuraProductState(
                    state: ProductState.loading,
                    subject: ProductNoun.message),
                error: (e, _) => AuraProductState(
                    state: ProductState.retryableError,
                    subject: ProductNoun.message,
                    onRecover: () => ref.invalidate(
                        conversationMessagesProvider(widget.conversationId))),
                data: (messages) => ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(AuraSpace.s12),
                  itemCount: messages.length,
                  itemBuilder: (_, i) => _MessageBubble(
                    message: messages[i],
                    mine: messages[i].senderUserId == myUserId,
                    conversation: c,
                  ),
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AuraSpace.s12, AuraSpace.s6, AuraSpace.s12, AuraSpace.s12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _composer,
                        minLines: 1,
                        maxLines: 5,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: 'Message…',
                          filled: true,
                          fillColor: AuraSurface.card,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: AuraSpace.s16,
                              vertical: AuraSpace.s10),
                        ),
                      ),
                    ),
                    const SizedBox(width: AuraSpace.s8),
                    IconButton.filled(
                      onPressed: _sending ? null : _send,
                      icon: const Icon(Icons.arrow_upward_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.mine,
    required this.conversation,
  });
  final ConversationMessage message;
  final bool mine;
  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) {
      final label = switch (message.systemKind) {
        'JOINED' => 'joined the conversation',
        'LEFT' => 'left the conversation',
        'RENAMED' => 'named the conversation',
        _ => message.body,
      };
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AuraSpace.s6),
        child: Center(
          child: Text(label,
              style: AuraText.micro.copyWith(color: AuraSurface.faint)),
        ),
      );
    }

    // DUAL ATTRIBUTION: institution as visible speaker, human attributable.
    final speakingFor = message.speakingForInstitutionId;
    final institutionName = speakingFor == null
        ? null
        : conversation.parties
            .where((p) => p.institutionId == speakingFor)
            .map((p) => p.displayName)
            .firstWhere((n) => n != null && n.isNotEmpty, orElse: () => null);

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s14, vertical: AuraSpace.s10),
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: BoxDecoration(
          color: mine ? AuraSurface.accentSoft : AuraSurface.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (institutionName != null) ...[
              Text(institutionName,
                  style: AuraText.micro.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AuraSurface.accentText)),
              const SizedBox(height: 2),
            ],
            Text(message.body,
                style: AuraText.body.copyWith(color: AuraSurface.ink)),
          ],
        ),
      ),
    );
  }
}
