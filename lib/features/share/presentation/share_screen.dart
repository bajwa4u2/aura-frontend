/// SHARE — the content-first creation intention.
///
/// COMPOSE asks "what do you want to say?" and treats media as something you
/// may add to it. SHARE starts from the other end: the thing already exists,
/// or is one tap from existing, and everything after that is about getting it
/// somewhere. Both are legitimate, they coexist, and they must not become two
/// content systems.
///
/// SO THIS SURFACE OWNS ALMOST NOTHING. It defines no attachment type, no
/// upload, no preview widget, no renderer, no draft model. Every one of those
/// already exists and is already proved elsewhere:
///
///     acquisition   media_acquisition   capturePhoto / captureVideo /
///                                       acquireMultipleMedia
///     the door      ContentIntake       kind, mime, size, rejection
///     identity      Attachment          local file/bytes + width/height/duration
///     the draft     CompositionState    readiness, phases, DraftClaim
///     preview       AuraCompositionStrip local-source preview, per-item
///                                       progress, retry, remove
///     upload        uploadAuraMedia
///
/// A second Share-shaped copy of any of those would be the defect this whole
/// chapter has been removing, reintroduced by a new entrance.
///
/// ORDER IS THE PRODUCT. Capture comes before destination: nobody should have
/// to decide Feed-or-Conversation before they have taken the photograph. The
/// destination question is asked when there is something to answer it about.
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/attachments/aura_media_upload.dart';
import '../../../core/composition/attachment_lifecycle.dart';
import '../../../core/composition/composition_authority.dart';
import '../../../core/distribution/aura_destination.dart';
import '../../../core/distribution/feed_draft_publisher.dart';
import '../../../core/errors/app_error_mapper.dart';
import '../../../core/media/attachment.dart';
import '../../../core/media/aura_composition_strip.dart';
import '../../../core/media/media_acquisition.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/product/product_state.dart';
import '../../../core/product/product_state_view.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../conversation/data/conversations_repository.dart';

class ShareScreen extends ConsumerStatefulWidget {
  const ShareScreen({super.key});

  @override
  ConsumerState<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends ConsumerState<ShareScreen> {
  final _context = TextEditingController();

  /// THE CANONICAL DRAFT, not a Share-shaped copy of one.
  ///
  /// `requiresBody: false` because a photograph is a complete share with
  /// nothing typed — the same judgement Conversation already makes about a
  /// message that is only a voice note.
  CompositionState _composition = const CompositionState(
    requiresBody: false,
  );

  List<Attachment> get _attachments => _composition.attachments;

  AuraDestination? _destination;
  bool _busy = false;
  bool _sending = false;

  /// The draft this share owns, once it has one.
  ///
  /// Kept across a failed publish so a retry continues with the SAME draft.
  /// Creating a second would leave the first behind as a stray DRAFT, and
  /// `getLatestHeld` returns the most recently updated DRAFT -- so the stray
  /// would become what Compose resumed the next time it opened.
  String? _feedDraftId;
  bool _published = false;

  int get _remainingSlots => kMaxComposableMedia - _attachments.length;
  bool get _hasContent => _attachments.isNotEmpty;

  /// Everything acquired is ready to leave.
  ///
  /// `AttachmentLifecycle` insists that only server identity proves an upload
  /// finished — "uploading went false" proves the attempt stopped, never that
  /// it worked. Share asks the same question rather than inventing a softer
  /// one.
  bool get _allReady =>
      _hasContent &&
      _attachments.every(
        (a) => AttachmentLifecycle.isComposable(
          AttachmentLifecycle.phaseOf(a),
        ),
      );

  @override
  void dispose() {
    // A DRAFT THIS SHARE CREATED AND NEVER PUBLISHED MUST NOT OUTLIVE IT.
    //
    // `getLatestHeld` returns the most recently updated DRAFT, so a row left
    // behind here would be what Compose resumed next -- the same collision in
    // the other direction. Named by id, best effort, and never a broad clear.
    final stray = _feedDraftId;
    if (stray != null && !_published) {
      unawaited(FeedDraftPublisher(ref.read(dioProvider)).discardDraft(stray));
    }
    _context.dispose();
    super.dispose();
  }

  // ── ACQUISITION ──────────────────────────────────────────────────────
  //
  // All three go through the canonical module. Share is the first caller of
  // its camera functions, which is why they now exist.

  Future<void> _capturePhoto() => _acquire(
        () => capturePhoto(remainingSlots: _remainingSlots),
      );

  Future<void> _captureVideo() => _acquire(
        () => captureVideo(remainingSlots: _remainingSlots),
      );

  Future<void> _chooseFromLibrary() => _acquire(
        () => acquireMultipleMedia(remainingSlots: _remainingSlots),
      );

  Future<void> _acquire(Future<MediaAcquisition> Function() run) async {
    if (_busy || _sending || _remainingSlots <= 0) return;
    setState(() => _busy = true);
    try {
      final acquired = await run();
      if (!mounted) return;

      final accepted = <Attachment>[];
      for (final r in acquired.resolutions) {
        final a = r.attachment;
        if (a == null) {
          // Refused at the door, and said so. Silence here is how an
          // unsupported file becomes a mysterious failure later.
          _say(r.rejectionMessage ?? 'That file could not be added.');
          continue;
        }
        accepted.add(a);
      }

      final limitNote = acquisitionLimitMessage(acquired.droppedForLimit);
      if (limitNote != null) _say(limitNote);
      if (accepted.isEmpty) return;

      setState(() {
        _composition = _composition.copyWith(
          attachments: [..._attachments, ...accepted],
        );
      });

      // UPLOAD RUNS BEHIND THE PREVIEW, NOT IN FRONT OF IT. The attachment is
      // already in the composition and already drawn from its local source by
      // the time this starts, so nobody waits on a round trip to recognise
      // what they just made.
      for (final a in accepted) {
        unawaited(_upload(a));
      }
    } catch (e) {
      if (mounted) _say(AppErrorMapper.from(e, feature: 'add this').message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _upload(Attachment attachment) async {
    final file = attachment.file;
    if (file == null) return;
    setState(() => attachment.uploading = true);
    try {
      final result = await uploadAuraMedia(
        dio: ref.read(dioProvider),
        bytes: await file.readAsBytes(),
        fileName: file.name,
        mimeType: attachment.mimeType!,
        originalMimeType: attachment.originalMimeType,
        kind: wireKind(attachment.kind),
        source: wireSource(attachment.source),
        width: attachment.width,
        height: attachment.height,
        duration: attachment.isVideo ? attachment.durationMs : null,
      );
      if (!mounted) return;
      setState(() {
        attachment.mediaId = result.mediaId;
        attachment.url = result.url.isNotEmpty ? result.url : null;
        attachment.thumbUrl =
            result.thumbUrl.isNotEmpty ? result.thumbUrl : null;
        attachment.uploading = false;
        attachment.error = null;
      });
    } catch (e) {
      if (!mounted) return;
      // FAILURE IS VISIBLE AND RECOVERABLE, never a silent drop. The strip
      // draws this item as failed with a retry, and the item keeps its local
      // source so retrying costs nothing but the upload.
      setState(() {
        attachment.uploading = false;
        attachment.error = AppErrorMapper.from(e, feature: 'upload this').message;
      });
    }
  }

  void _remove(String localId) {
    setState(() {
      _composition = _composition.copyWith(
        attachments:
            _attachments.where((a) => a.localId != localId).toList(),
      );
    });
  }

  // ── PUBLICATION ──────────────────────────────────────────────────────

  Future<void> _publish() async {
    final destination = _destination;
    if (destination == null || !destination.isActionable) return;
    if (!_allReady || _sending) return;

    setState(() => _sending = true);
    try {
      final mediaIds = _attachments
          .map((a) => (a.mediaId ?? '').trim())
          .where((id) => id.isNotEmpty)
          .toList(growable: false);
      final text = _context.text.trim();

      if (destination.isConversation) {
        // THE EXISTING SEND AUTHORITY, with the media Share already uploaded.
        // No second upload, no second composer, no reconstructed draft.
        await ref.read(conversationsRepositoryProvider).send(
              destination.conversationId!,
              text,
              mediaIds: mediaIds,
            );
      } else {
        await _publishToFeed(text: text, mediaIds: mediaIds);
      }

      if (!mounted) return;
      _say(destination.isConversation ? 'Sent.' : 'Published.');
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      // AN EXTERNAL FAILURE MUST NOT COST SOMEBODY THEIR CONTENT. The
      // composition is untouched here: nothing is removed, cleared or reset,
      // so the person can choose another destination or try again.
      _say(AppErrorMapper.from(e, feature: 'share this').message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _publishToFeed({
    required String text,
    required List<String> mediaIds,
  }) async {
    // THIS SHARE PUBLISHES ITS OWN DRAFT, NEVER "THE" DRAFT.
    //
    // The first version wrote `PUT /posts/draft` and `POST
    // /posts/draft/publish`, both keyed by author alone -- so somebody with an
    // unfinished post in Compose who then shared a photograph would have had
    // that unfinished post REPLACED by the photograph and published in its
    // place.
    final publisher = FeedDraftPublisher(ref.read(dioProvider));
    final draftId = _feedDraftId ??= await publisher.createDraft();
    await publisher.publish(
      draftId: draftId,
      text: text,
      mediaIds: mediaIds,
    );
    _published = true;
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ── SURFACE ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AuraScaffold(
      title: 'Share',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AuraSpace.s16,
          AuraSpace.s4,
          AuraSpace.s16,
          AuraSpace.s32,
        ),
        children: [
          if (!_hasContent) ...[
            Text(
              'Something you want to show. Take it, or choose it — then decide '
              'where it goes.',
              style: AuraText.body
                  .copyWith(color: AuraSurface.muted, height: 1.5),
            ),
            const SizedBox(height: AuraSpace.s20),
          ],
          _buildAcquisitionRow(),
          if (_hasContent) ...[
            const SizedBox(height: AuraSpace.s16),
            AuraCompositionStrip(
              attachments: _attachments,
              phaseOf: (a) => AttachmentLifecycle.phaseOf(a),
              onRemove: _remove,
              onRetry: (a) => unawaited(_upload(a)),
              tileSize: 108,
            ),
            const SizedBox(height: AuraSpace.s16),
            TextField(
              controller: _context,
              maxLines: 3,
              minLines: 1,
              enabled: !_sending,
              decoration: const InputDecoration(
                hintText: 'Say something about it (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AuraSpace.s20),
            _buildDestinationChooser(),
            const SizedBox(height: AuraSpace.s20),
            _buildAction(),
          ],
        ],
      ),
    );
  }

  Widget _buildAcquisitionRow() {
    final canAdd = _remainingSlots > 0 && !_busy && !_sending;
    return Wrap(
      spacing: AuraSpace.s10,
      runSpacing: AuraSpace.s10,
      children: [
        if (supportsCameraCapture) ...[
          AuraPrimaryButton(
            label: 'Photo',
            icon: Icons.camera_alt_outlined,
            onPressed: canAdd ? _capturePhoto : null,
          ),
          AuraSecondaryButton(
            label: 'Video',
            icon: Icons.videocam_outlined,
            onPressed: canAdd ? _captureVideo : null,
          ),
        ],
        AuraSecondaryButton(
          label: supportsCameraCapture ? 'Library' : 'Choose photo or video',
          icon: Icons.photo_library_outlined,
          onPressed: canAdd ? _chooseFromLibrary : null,
        ),
      ],
    );
  }

  Widget _buildDestinationChooser() {
    final d = _destination;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Where should it go?',
          style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AuraSpace.s10),
        Wrap(
          spacing: AuraSpace.s10,
          runSpacing: AuraSpace.s10,
          children: [
            ChoiceChip(
              label: const Text('Your feed'),
              selected: d?.isFeed ?? false,
              onSelected: _sending
                  ? null
                  : (_) => setState(
                        () => _destination = const AuraDestination.feed(),
                      ),
            ),
            ChoiceChip(
              label: Text(d?.isConversation == true ? d!.label : 'A conversation'),
              selected: d?.isConversation ?? false,
              onSelected: _sending ? null : (_) => _pickConversation(),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickConversation() async {
    // Deliberately the EXISTING conversation list rather than a Share-owned
    // picker: which conversations a person may send to is an access question
    // that already has an authority.
    final chosen = await showModalBottomSheet<Map<String, String>>(
      context: context,
      backgroundColor: AuraSurface.page,
      isScrollControlled: true,
      builder: (sheetContext) => const _ConversationPickerSheet(),
    );
    if (!mounted || chosen == null) return;
    setState(() {
      _destination = AuraDestination.conversation(
        id: chosen['id']!,
        title: chosen['title'],
      );
    });
  }

  Widget _buildAction() {
    final d = _destination;
    final ready = _allReady && d != null && d.isActionable && !_sending;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AuraSpace.s4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _allReady
                  ? (d == null ? 'Choose where it goes' : d.label)
                  : 'Preparing…',
              style: AuraText.small.copyWith(color: AuraSurface.muted),
            ),
          ),
          AuraPrimaryButton(
            label: _sending ? 'Working…' : (d?.actionVerb ?? 'Share'),
            onPressed: ready ? _publish : null,
          ),
        ],
      ),
    );
  }
}

/// The conversations a person may send into.
class _ConversationPickerSheet extends ConsumerWidget {
  const _ConversationPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: FutureBuilder<List<dynamic>>(
        future: _load(ref),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            // The state authority, not a bare spinner. A full-surface wait is
            // a product state with a voice, and the C0 gate exists to keep it
            // one rather than letting each new surface invent its own.
            return const Padding(
              padding: EdgeInsets.all(AuraSpace.s24),
              child: AuraProductState(state: ProductState.loading),
            );
          }
          final items = snap.data ?? const [];
          if (items.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(AuraSpace.s24),
              child: Text('No conversations yet.'),
            );
          }
          return ListView.builder(
            shrinkWrap: true,
            itemCount: items.length,
            itemBuilder: (context, i) {
              final c = items[i] as Map<String, dynamic>;
              final id = (c['id'] ?? '').toString();
              final title = (c['title'] ?? c['displayName'] ?? '').toString();
              return ListTile(
                leading: const Icon(Icons.forum_outlined),
                title: Text(title.isEmpty ? 'Conversation' : title),
                onTap: () => Navigator.of(context)
                    .pop(<String, String>{'id': id, 'title': title}),
              );
            },
          );
        },
      ),
    );
  }

  Future<List<dynamic>> _load(WidgetRef ref) async {
    try {
      final res = await ref.read(dioProvider).get('/conversations');
      final raw = res.data;
      if (raw is Map && raw['conversations'] is List) {
        return raw['conversations'] as List;
      }
      if (raw is Map && raw['data'] is List) return raw['data'] as List;
      if (raw is List) return raw;
      return const [];
    } on DioException {
      return const [];
    }
  }
}
