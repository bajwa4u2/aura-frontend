import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/attachments/aura_media_upload.dart';
import '../../../core/compliance/report_content_sheet.dart';
import '../../../core/compliance/report_repository.dart';
import '../../../core/media/aura_attachment_image.dart';
import '../../../core/net/dio_provider.dart';
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

/// ONE Conversation screen (canon): talk immediately; CAPABILITIES ATTACH
/// when intention reaches them — attachments and audio/video calls ride
/// the certified shared engines through the CONVERSATION surface; screen
/// share lives inside the active call session; message reporting reaches
/// the canonical moderation authority. Nothing forks into a sibling
/// product and no session/thread vocabulary reaches the person.
class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key, required this.conversationId});
  final String conversationId;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _PendingAttachment {
  _PendingAttachment({required this.name});
  final String name;
  String? mediaId;
  bool failed = false;
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _composer = TextEditingController();
  final List<_PendingAttachment> _attachments = [];
  bool _sending = false;
  bool _startingCall = false;

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  bool get _uploading =>
      _attachments.any((a) => a.mediaId == null && !a.failed);

  Future<void> _attachImage() async {
    final picked =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final pending = _PendingAttachment(name: picked.name);
    setState(() => _attachments.add(pending));
    try {
      final Uint8List bytes = await picked.readAsBytes();
      final mime = picked.mimeType ??
          (picked.name.toLowerCase().endsWith('.png')
              ? 'image/png'
              : 'image/jpeg');
      final result = await uploadAuraMedia(
        dio: ref.read(dioProvider),
        bytes: bytes,
        fileName: picked.name,
        mimeType: mime,
        kind: 'IMAGE',
        source: 'GALLERY',
      );
      if (mounted) setState(() => pending.mediaId = result.mediaId);
    } catch (_) {
      if (mounted) {
        setState(() => pending.failed = true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Attachment failed — remove it and try again.')));
      }
    }
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    final mediaIds = _attachments
        .map((a) => a.mediaId)
        .whereType<String>()
        .toList();
    if ((text.isEmpty && mediaIds.isEmpty) || _sending || _uploading) return;
    setState(() => _sending = true);
    try {
      await ref.read(conversationsRepositoryProvider).send(
            widget.conversationId,
            text.isEmpty ? '…' : text,
            mediaIds: mediaIds,
          );
      _composer.clear();
      setState(() => _attachments.clear());
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

  /// Conversation → Call/Video: the session is an ephemeral capability of
  /// this conversation; the other parties receive the canonical incoming
  /// experience through the certified call-notification pipeline.
  Future<void> _startCall(String kind) async {
    if (_startingCall) return;
    setState(() => _startingCall = true);
    try {
      final sessionId = await ref
          .read(conversationsRepositoryProvider)
          .startLive(widget.conversationId, kind: kind);
      if (sessionId.isEmpty) throw Exception('no session');
      if (mounted) context.push('/realtime/$sessionId');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not start the call — try again.')));
      }
    } finally {
      if (mounted) setState(() => _startingCall = false);
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
          IconButton(
            tooltip: 'Call',
            icon: const Icon(Icons.call_rounded),
            onPressed: _startingCall ? null : () => _startCall('AUDIO'),
          ),
          IconButton(
            tooltip: 'Video',
            icon: const Icon(Icons.videocam_rounded),
            onPressed: _startingCall ? null : () => _startCall('VIDEO'),
          ),
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
            if (_attachments.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AuraSpace.s12),
                  child: Wrap(
                    spacing: AuraSpace.s6,
                    children: [
                      for (final a in _attachments)
                        InputChip(
                          avatar: a.failed
                              ? const Icon(Icons.error_outline_rounded,
                                  size: 16)
                              : a.mediaId == null
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.image_outlined,
                                      size: 16),
                          label: Text(a.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          onDeleted: () =>
                              setState(() => _attachments.remove(a)),
                        ),
                    ],
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
                    IconButton(
                      tooltip: 'Attach',
                      icon: const Icon(Icons.attach_file_rounded),
                      onPressed: _attachImage,
                    ),
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
                      onPressed: (_sending || _uploading) ? null : _send,
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

class _MessageBubble extends ConsumerWidget {
  const _MessageBubble({
    required this.message,
    required this.mine,
    required this.conversation,
  });
  final ConversationMessage message;
  final bool mine;
  final Conversation conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      child: GestureDetector(
        // Message → Report → canonical moderation authority (frozen hook).
        onLongPress: mine
            ? null
            : () => ReportContentSheet.show(
                  context,
                  targetType: ReportTargetType.conversationMessage,
                  targetId: message.id,
                  contextLabel: 'this message',
                ),
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
              for (final mediaId in message.mediaIds) ...[
                _ConversationAttachment(mediaId: mediaId),
                const SizedBox(height: AuraSpace.s6),
              ],
              if (message.body.trim() != '…' || message.mediaIds.isEmpty)
                Text(message.body,
                    style: AuraText.body.copyWith(color: AuraSurface.ink)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Attachment renderer: resolves the visibility-checked delivery URL from
/// the canonical Media authority, renders images inline, and falls back to
/// an honest file chip when the media is not an inline-renderable image.
class _ConversationAttachment extends ConsumerWidget {
  const _ConversationAttachment({required this.mediaId});
  final String mediaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urlAsync = ref.watch(_deliveryUrlProvider(mediaId));
    return urlAsync.when(
      loading: () => Container(
        width: 220,
        height: 140,
        decoration: BoxDecoration(
          color: AuraSurface.subtle,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
            child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))),
      ),
      error: (e, _) => _fileChip(),
      data: (url) => url == null
          ? _fileChip()
          : ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AuraAttachmentImage(
                url: url,
                attachmentId: mediaId,
                width: 260,
                fit: BoxFit.cover,
                errorWidget: (_) => _fileChip(),
              ),
            ),
    );
  }

  Widget _fileChip() {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s10, vertical: AuraSpace.s8),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insert_drive_file_outlined,
              size: 16, color: AuraSurface.muted),
          const SizedBox(width: AuraSpace.s6),
          Text('Attachment',
              style: AuraText.micro.copyWith(color: AuraSurface.muted)),
        ],
      ),
    );
  }
}

final _deliveryUrlProvider =
    FutureProvider.family<String?, String>((ref, mediaId) async {
  return ref.watch(conversationsRepositoryProvider).mediaDeliveryUrl(mediaId);
});
