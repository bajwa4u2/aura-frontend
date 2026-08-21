import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:dio/dio.dart' as dio_pkg;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../../core/attachments/aura_media_upload.dart';
import '../../../core/media/aura_attachment_card.dart';
import '../../../core/media/aura_voice_player.dart';
import '../../../core/media/aura_media_viewer.dart';
import '../../../core/media/aura_attachment_open.dart';
import '../../../core/compliance/report_content_sheet.dart';
import '../../../core/compliance/report_repository.dart';
import '../../../core/media/aura_attachment_image.dart';
import '../../../core/navigation/navigation_authority.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/product/product_language.dart';
import '../../../core/product/product_state.dart';
import '../../../core/product/product_state_view.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../institutions/spaces/institution_space_context.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/conversations_repository.dart';
import 'add_people_sheet.dart';
import 'conversation_avatar.dart';
import 'conversation_identity.dart';
import '../../realtime/application/realtime_providers.dart';
import '../../../core/composition/attachment_lifecycle.dart';
import '../../../core/composition/composition_authority.dart';
import '../../../core/composition/content_intake.dart';
import '../../../core/content_policy/content_length_policy.dart';
import '../../../core/media/attachment.dart';

/// Durable ringing/active-call truth for a conversation (founder charter
/// 2026-08-17). A call must never be reachable ONLY through an ephemeral
/// ring card: after a refresh, a dismissed notification, or a frozen
/// accept, the thread itself still answers "is there a call I can join?"
/// from the server. Re-fetched whenever local join state toggles so the
/// ribbon appears/clears without a manual reload.
final conversationActiveLiveProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, conversationId) async {
  ref.watch(realtimeControllerProvider.select((s) => s.isJoined));
  try {
    return await ref
        .read(conversationsRepositoryProvider)
        .activeLiveSession(conversationId);
  } catch (_) {
    return null; // never let a transient failure fake "no call"
  }
});

/// ONE Conversation screen (canon): talk immediately; CAPABILITIES ATTACH
/// when intention reaches them — photos, videos, voice notes, and
/// audio/video calls all ride the certified shared engines through the
/// CONVERSATION surface; screen share lives inside the active call
/// session; message reporting reaches the canonical moderation authority.
/// Nothing forks into a sibling product and no session/thread vocabulary
/// reaches the person.
class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({
    super.key,
    required this.conversationId,
    this.spaceContext,
  });
  final String conversationId;

  /// Present when this conversation IS an Institution Space's communication
  /// runtime (RC-C7 reconstruction, ruling D1). It changes what the header
  /// says and where Back goes — nothing else. There is exactly ONE
  /// conversation implementation in the product, and a Space consuming it is
  /// the point of the reconstruction, not an exception to it.
  final InstitutionSpaceContext? spaceContext;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

// `_PendingAttachment` used to live here: a FOURTH private attachment model,
// with a stringly-typed kind and a `failed` boolean, that survived the
// consolidation `Attachment` was written to finish. It is gone. This screen
// composes the canonical `Attachment` and reads its phase from
// `AttachmentLifecycle`, so it can no longer disagree with another composer
// about what a half-uploaded file means.

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _composer = TextEditingController();

  /// CH-13 - the canonical composition.
  ///
  /// This screen used to keep a private attachment model, its own `_uploading`
  /// derivation and its own `_sending` flag, then decide readiness from all
  /// three at the send site. Phase and readiness are now DERIVED by
  /// CompositionAuthority from the attachments themselves.
  CompositionState _composition = const CompositionState(
    maxLength: ContentLengthPolicy.message,
    // A conversation message legitimately has no body: a photo, a voice note
    // and a video message are each complete messages with nothing typed.
    requiresBody: false,
  );

  List<Attachment> get _attachments => _composition.attachments;

  final _recorder = AudioRecorder();
  bool _startingCall = false;
  bool _recording = false;

  /// Reply-to draft state: the quoted message the next send answers.
  ConversationMessage? _replyTo;

  /// On-demand translations shown under bubbles, keyed by message id.
  final Map<String, String> _translations = {};

  /// Draft link intelligence: debounce + last resolved preview.
  Timer? _linkDebounce;
  Map<String, dynamic>? _pendingPreview;
  String? _pendingPreviewUrl;
  bool _previewDismissed = false;

  /// @mention suggestions for the token at the caret.
  List<ConversationParty> _mentionMatches = const [];

  @override
  void dispose() {
    _linkDebounce?.cancel();
    _composer.dispose();
    _recorder.dispose();
    super.dispose();
  }

  // ── Composer intelligence ─────────────────────────────────────────

  void _onComposerChanged(String text, Conversation c) {
    final sel = _composer.selection;
    final caret =
        sel.isValid ? sel.baseOffset.clamp(0, text.length) : text.length;
    final upto = text.substring(0, caret);
    final token = RegExp(r'@([^\s@]*)$').firstMatch(upto);
    List<ConversationParty> matches = const [];
    if (token != null) {
      final q = token.group(1)!.toLowerCase();
      matches = c.parties
          .where((p) =>
              p.isPerson &&
              p.isActive &&
              (p.displayName ?? '').isNotEmpty &&
              p.displayName!.toLowerCase().contains(q))
          .take(4)
          .toList();
    }
    setState(() {
      // The authority measures the body; the controller only holds it.
      _composition = _composition.copyWith(body: text);
      _mentionMatches = matches;
    });

    _linkDebounce?.cancel();
    _linkDebounce = Timer(
        const Duration(milliseconds: 600), () => _resolveDraftLink(text));
  }

  Future<void> _resolveDraftLink(String text) async {
    final raw = RegExp(r'https?://[^\s]+').firstMatch(text)?.group(0);
    final url = raw == null ? null : _trimUrlToken(raw);
    if (url == null || url.isEmpty) {
      if (_pendingPreview != null || _pendingPreviewUrl != null) {
        if (mounted) {
          setState(() {
            _pendingPreview = null;
            _pendingPreviewUrl = null;
            _previewDismissed = false;
          });
        }
      }
      return;
    }
    if (url == _pendingPreviewUrl) return;
    _pendingPreviewUrl = url;
    _previewDismissed = false;
    try {
      final resolved = await ref
          .read(conversationsRepositoryProvider)
          .resolveLinkPreview(url);
      if (!mounted || _pendingPreviewUrl != url) return;
      setState(() => _pendingPreview = resolved);
    } catch (_) {
      // A preview is enrichment — never blocks composing or sending.
    }
  }

  void _insertMention(ConversationParty p) {
    final name = p.displayName ?? '';
    if (name.isEmpty) return;
    final text = _composer.text;
    final sel = _composer.selection;
    final caret =
        sel.isValid ? sel.baseOffset.clamp(0, text.length) : text.length;
    final upto = text.substring(0, caret);
    final token = RegExp(r'@([^\s@]*)$').firstMatch(upto);
    if (token == null) return;
    final next =
        '${upto.substring(0, token.start)}@$name ${text.substring(caret)}';
    _composer.text = next;
    _composer.selection =
        TextSelection.collapsed(offset: token.start + name.length + 2);
    setState(() => _mentionMatches = const []);
  }

  /// Ctrl/Cmd+V with an image on the clipboard becomes an attachment
  /// through the same coherent intake as drag/drop; text paste untouched.
  KeyEventResult _composerKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.keyV &&
        (HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed)) {
      _tryPasteImage();
    }
    return KeyEventResult.ignored;
  }

  Future<void> _tryPasteImage() async {
    try {
      final bytes = await Pasteboard.image;
      if (bytes != null && bytes.isNotEmpty) {
        await _admit(await ContentIntake.resolveAndPrepareBytes(
          path: IntakePath.paste,
          bytes: bytes,
          fileName: 'pasted-image.png',
          declaredMimeType: 'image/png',
        ));
      }
    } catch (_) {
      // No image on the clipboard — the native text paste proceeds.
    }
  }

  Future<void> _messageAction(String action, ConversationMessage msg) async {
    switch (action) {
      case 'reply':
        setState(() => _replyTo = msg);
        return;
      case 'copy':
        await Clipboard.setData(ClipboardData(text: msg.body));
        return;
      case 'translate':
        final target = Localizations.localeOf(context).languageCode;
        try {
          final t = await ref
              .read(conversationsRepositoryProvider)
              .translateMessage(msg.id, msg.body, target);
          if (mounted) {
            setState(() => _translations[msg.id] =
                t.trim() == msg.body.trim() ? 'Already in your language' : t);
          }
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Translation is not available right now.')));
          }
        }
        return;
      case 'report':
        if (mounted) {
          ReportContentSheet.show(
            context,
            targetType: ReportTargetType.conversationMessage,
            targetId: msg.id,
            contextLabel: 'this message',
          );
        }
        return;
    }
  }

  String _partyName(Conversation c, String userId) {
    for (final p in c.parties) {
      if (p.userId == userId && (p.displayName ?? '').isNotEmpty) {
        return p.displayName!;
      }
    }
    return 'Someone';
  }

  /// Take one resolved attachment into the composition, then upload it.
  ///
  /// A refusal is SHOWN and not added. An attachment the person can see is a
  /// promise it will be sent, and intake has already decided whether that
  /// promise can be kept.
  Future<void> _admit(IntakeResolution resolution) async {
    final attachment = resolution.attachment;
    if (attachment == null) {
      _refuse(resolution.rejection!);
      return;
    }
    setState(() => _composition = _composition.copyWith(
          attachments: [..._composition.attachments, attachment],
        ));
    await _upload(attachment);
  }

  void _refuse(AttachmentRejection rejection) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AttachmentLifecycle.rejectionMessage(rejection))),
    );
  }

  /// `Attachment` is mutable by design and the lifecycle reads it live, so
  /// setState is all that moves the phase - there is no stored phase that
  /// could fall out of step with the data.
  Future<void> _upload(Attachment attachment) async {
    setState(() {
      attachment.uploading = true;
      attachment.error = null;
    });
    try {
      final result = await uploadAuraMedia(
        dio: ref.read(dioProvider),
        bytes: attachment.bytes!,
        fileName: attachment.fileName ?? 'attachment',
        mimeType: attachment.mimeType!,
        // This surface has always sent the semantic kind, and must keep
        // doing so: 'DOCUMENT' buys the 25 MiB document bucket, 'IMAGE'
        // would silently cut it to 10 MiB and start refusing PDFs that
        // attach today.
        kind: wireKind(attachment.kind, collapseDocumentToImage: false),
        source: wireSource(attachment.source),
      );
      if (!mounted) return;
      setState(() {
        attachment.uploading = false;
        attachment.mediaId = result.mediaId;
        // Only an image needs its bytes kept, for the thumbnail. Holding a
        // video's bytes for the life of the composer is what the retired
        // model avoided by never storing them at all.
        if (attachment.kind != AttachmentKind.image) attachment.bytes = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        attachment.uploading = false;
        // An error with no server identity is the RETRYABLE phase, and it
        // keeps the attachment pending - which is what now stops the send
        // that used to drop it silently.
        attachment.error = 'upload-failed';
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Attachment failed — remove it and try again.')));
    }
  }

  Future<void> _attachPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    // The inline `.png ? image/png : image/jpeg` ladder that used to stand
    // here GUESSED, and guessed wrong for heic and webp. Intake infers from
    // the name when the platform declines to say, and refuses when neither
    // source of evidence answers.
    await _admit(await ContentIntake.resolveAndPrepareBytes(
      path: IntakePath.picker,
      bytes: await picked.readAsBytes(),
      fileName: picked.name,
      declaredMimeType: picked.mimeType,
      source: AttachmentSource.gallery,
    ));
  }

  Future<void> _attachVideo() async {
    final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (picked == null) return;
    await _admit(await ContentIntake.resolveAndPrepareBytes(
      path: IntakePath.picker,
      bytes: await picked.readAsBytes(),
      fileName: picked.name,
      declaredMimeType: picked.mimeType,
      source: AttachmentSource.gallery,
    ));
  }

  void _showAttachMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AuraSurface.page,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Photo'),
              onTap: () {
                Navigator.of(ctx).pop();
                _attachPhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Video'),
              onTap: () {
                Navigator.of(ctx).pop();
                _attachVideo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_camera_front_outlined),
              title: const Text('Record video message'),
              onTap: () {
                Navigator.of(ctx).pop();
                _recordVideoMessage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Document'),
              onTap: () {
                Navigator.of(ctx).pop();
                _attachDocument();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Video MESSAGE: capture from the camera (browser/device capture UI),
  /// then it joins the pending attachments like any media.
  Future<void> _recordVideoMessage() async {
    final picked = await ImagePicker().pickVideo(source: ImageSource.camera);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    // A video MESSAGE sends itself — capture IS the send. It goes through the
    // same governed door as everything else; capture earns no exemption.
    await _uploadAndSendImmediately(await ContentIntake.resolveAndPrepareBytes(
      path: IntakePath.picker,
      bytes: bytes,
      fileName: picked.name,
      declaredMimeType: picked.mimeType ?? 'video/webm',
      source: AttachmentSource.camera,
    ));
  }

  /// Voice/video MESSAGES are sent the moment capture completes (WhatsApp
  /// ergonomics); picked/dropped files stay reviewable before send.
  Future<void> _uploadAndSendImmediately(IntakeResolution resolution) async {
    final attachment = resolution.attachment;
    if (attachment == null) {
      _refuse(resolution.rejection!);
      return;
    }
    try {
      final result = await uploadAuraMedia(
        dio: ref.read(dioProvider),
        bytes: attachment.bytes!,
        fileName: attachment.fileName ?? 'attachment',
        mimeType: attachment.mimeType!,
        // This surface has always sent the semantic kind, and must keep
        // doing so: 'DOCUMENT' buys the 25 MiB document bucket, 'IMAGE'
        // would silently cut it to 10 MiB and start refusing PDFs that
        // attach today.
        kind: wireKind(attachment.kind, collapseDocumentToImage: false),
        source: wireSource(attachment.source),
      );
      await ref.read(conversationsRepositoryProvider).send(
            widget.conversationId,
            '…',
            mediaIds: [result.mediaId],
          );
      ref.invalidate(conversationMessagesProvider(widget.conversationId));
      ref.invalidate(conversationsListProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not send — try again.')));
      }
    }
  }

  // GO LIVE was removed from the conversation menu (founder charter
  // 2026-08-17): "LIVE IS NOT SOMETHING A USER CREATES. LIVE IS SOMETHING
  // AN EXISTING REALTIME HUMAN INTERACTION DELIBERATELY BECOMES."
  // NO ACTIVE REALTIME INTERACTION = NO GO LIVE ORIGINATION. The only
  // origination door lives inside the active call (realtime room, More
  // panel), where it escalates the CURRENT session's lifecycle state.

  Future<void> _attachDocument() async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.any, withData: true);
    final file = result?.files.firstOrNull;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    await _admit(await ContentIntake.resolveAndPrepareBytes(
      path: IntakePath.picker,
      bytes: bytes,
      fileName: file.name,
      source: AttachmentSource.upload,
    ));
  }

  // `_ingestBytes` used to live here. It resolved mime and kind itself and,
  // when neither the caller nor the filename answered, fell back to
  // `application/octet-stream` - a type the server's allow-list refuses at
  // presign. The attachment appeared in the composer, climbed, and failed
  // with a generic message, because the fallback moved the refusal later
  // rather than removing it. ContentIntake refuses at the door, truthfully,
  // and never manufactures a type it has no evidence for.

  /// Voice note: record → stop → the note joins the pending attachments.
  Future<void> _toggleVoiceNote() async {
    if (_recording) {
      final path = await _recorder.stop();
      setState(() => _recording = false);
      if (path == null) return;
      try {
        final res = await dio_pkg.Dio().get<List<int>>(
          path,
          options: dio_pkg.Options(responseType: dio_pkg.ResponseType.bytes),
        );
        final bytes = Uint8List.fromList(res.data ?? const []);
        if (bytes.isEmpty) throw Exception('empty recording');
        // Messenger ergonomics (founder): a voice MESSAGE sends itself —
        // stop recording IS the send.
        await _uploadAndSendImmediately(await ContentIntake.resolveAndPrepareBytes(
          path: IntakePath.picker,
          bytes: bytes,
          fileName: 'voice-note.webm',
          declaredMimeType: 'audio/webm',
          source: AttachmentSource.recording,
        ));
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Could not capture the recording — try again.')));
        }
      }
      return;
    }
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Microphone permission is needed for voice notes.')));
      }
      return;
    }
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.opus),
        path: 'voice-note.webm');
    setState(() => _recording = true);
  }

  Future<void> _send() async {
    // Readiness is the authority's answer, not this screen's. The guard that
    // stood here read `mediaId == null && !failed` as "still uploading", so a
    // FAILED attachment counted as finished: the send proceeded and
    // `whereType<String>()` quietly dropped it. The person watched a message
    // leave without the file they had attached to it.
    if (!_composition.canSubmit) return;
    final text = _composition.trimmedBody;
    final mediaIds = _composition.composableAttachments
        .map((a) => a.mediaId!)
        .toList();
    setState(() => _composition = _composition.copyWith(isSubmitting: true));
    try {
      final previewId = _previewDismissed
          ? null
          : _pendingPreview?['linkPreviewId'] as String?;
      await ref.read(conversationsRepositoryProvider).send(
            widget.conversationId,
            text.isEmpty ? '…' : text,
            mediaIds: mediaIds,
            replyToMessageId: _replyTo?.id,
            linkPreviewId: previewId,
          );
      _composer.clear();
      setState(() {
        _composition = const CompositionState(
          maxLength: ContentLengthPolicy.message,
          requiresBody: false,
        );
        _replyTo = null;
        _pendingPreview = null;
        _pendingPreviewUrl = null;
        _previewDismissed = false;
        _mentionMatches = const [];
      });
      ref.invalidate(conversationMessagesProvider(widget.conversationId));
      ref.invalidate(conversationsListProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send — try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() =>
            _composition = _composition.copyWith(isSubmitting: false));
      }
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
      if (mounted) {
        context.push(NavigationAuthority.realtimeSessionRoute(sessionId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not start the call — try again.')));
      }
    } finally {
      if (mounted) setState(() => _startingCall = false);
    }
  }

  String _draftPreviewLabel() {
    final p = _pendingPreview ?? const {};
    final internal = p['internalReference'];
    if (internal is Map<String, dynamic>) {
      final t = internal['title'] ?? internal['label'] ?? internal['name'];
      if (t != null && '$t'.isNotEmpty) return 'Aura · $t';
      return 'Aura link';
    }
    final title = p['title'];
    if (title != null && '$title'.isNotEmpty) return '$title';
    return '${p['canonicalUrl'] ?? p['sourceUrl'] ?? ''}';
  }

  Future<void> _menu(String action, Conversation c) async {
    final repo = ref.read(conversationsRepositoryProvider);
    switch (action) {
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
      data: (c) => _DropIntake(
        onFiles: (files) async {
          for (final f in files) {
            await _admit(await ContentIntake.resolveAndPrepareBytes(
              path: IntakePath.drop,
              bytes: await f.readAsBytes(),
              fileName: f.name,
              declaredMimeType: f.mimeType,
              source: AttachmentSource.upload,
            ));
          }
        },
        child: AuraScaffold(
        showHeader: false,
        body: Column(
          children: [
            // VISIBLE conversation header — AuraScaffold renders no chrome
            // of its own (the live "calls nowhere / add buried" defect), so
            // the conversation owns its bar: identity left, capabilities
            // right, messenger-grade.
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpace.s8, vertical: AuraSpace.s6),
              decoration: const BoxDecoration(
                color: AuraSurface.card,
                border:
                    Border(bottom: BorderSide(color: AuraSurface.divider)),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () {
                      final back = widget.spaceContext?.onBack;
                      if (back != null) {
                        back();
                        return;
                      }
                      context.canPop()
                          ? context.pop()
                          : context.go(NavigationAuthority.messagesRoute);
                    },
                  ),
                  // F056: counterpart avatar for 1:1, bounded composite of
                  // canonical participant identities for a group.
                  ConversationAvatar(
                      conversation: c, myUserId: myUserId, size: 34),
                  const SizedBox(width: AuraSpace.s10),
                  Expanded(
                    // In a Space, the SPACE names the surface. The
                    // conversation's own name is a mirror of the Space title,
                    // and reading it here instead would let a rename drift
                    // into two answers for one question.
                    child: widget.spaceContext != null
                        ? _SpaceHeading(context: widget.spaceContext!)
                        : Text(
                            conversationDisplayName(c, myUserId),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AuraText.body.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AuraSurface.ink),
                          ),
                  ),
                  if (widget.spaceContext?.onOpenMembers != null)
                    IconButton(
                      tooltip: 'Members',
                      icon: const Icon(Icons.group_outlined),
                      onPressed: widget.spaceContext!.onOpenMembers,
                    ),
                  IconButton(
                    tooltip: 'Call',
                    icon: const Icon(Icons.call_rounded),
                    onPressed:
                        _startingCall ? null : () => _startCall('AUDIO'),
                  ),
                  IconButton(
                    tooltip: 'Video',
                    icon: const Icon(Icons.videocam_rounded),
                    onPressed:
                        _startingCall ? null : () => _startCall('VIDEO'),
                  ),
                  IconButton(
                    tooltip: 'Add people',
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    onPressed: () => showAddPeopleSheet(
                        context, ref, widget.conversationId),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (a) => _menu(a, c),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'rename', child: Text('Name')),
                      PopupMenuItem(
                          value: 'mute',
                          child: Text(c.muted ? 'Unmute' : 'Mute')),
                      PopupMenuItem(
                          value: 'archive',
                          child:
                              Text(c.archived ? 'Unarchive' : 'Archive')),
                      const PopupMenuItem(
                          value: 'leave', child: Text('Leave')),
                    ],
                  ),
                ],
              ),
            ),
            // DURABLE CALL AFFORDANCE (founder charter 2026-08-17): a
            // ringing/active call is server truth, so the thread can always
            // offer it — after a refresh, a dismissed card, a missed
            // notification, or a frozen accept. Never "gone to never come
            // back".
            _ConversationLiveRibbon(conversationId: widget.conversationId),
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
                    translation: _translations[messages[i].id],
                    onAction: (a) => _messageAction(a, messages[i]),
                  ),
                ),
              ),
            ),
            if (_attachments.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AuraSpace.s12),
                  child: Wrap(
                    spacing: AuraSpace.s6,
                    runSpacing: AuraSpace.s6,
                    children: [
                      for (final a in _attachments)
                        _PendingAttachmentTile(
                          attachment: a,
                          phase: _composition.phaseOf(a),
                          onRemove: () => setState(() =>
                              _composition = _composition.copyWith(
                                attachments: _composition.attachments
                                    .where((x) => x.localId != a.localId)
                                    .toList(growable: false),
                              )),
                        ),
                    ],
                  ),
                ),
              ),
            if (_mentionMatches.isNotEmpty)
              Container(
                width: double.infinity,
                color: AuraSurface.card,
                padding: const EdgeInsets.symmetric(
                    horizontal: AuraSpace.s12, vertical: AuraSpace.s6),
                child: Wrap(
                  spacing: AuraSpace.s6,
                  children: [
                    for (final p in _mentionMatches)
                      ActionChip(
                        avatar: AuraAvatar(
                            name: p.displayName ?? '',
                            imageUrl: p.avatarUrl,
                            size: 20),
                        label: Text(p.displayName ?? ''),
                        onPressed: () => _insertMention(p),
                      ),
                  ],
                ),
              ),
            if (_replyTo != null)
              Container(
                color: AuraSurface.card,
                padding: const EdgeInsets.fromLTRB(
                    AuraSpace.s12, AuraSpace.s6, AuraSpace.s4, AuraSpace.s6),
                child: Row(
                  children: [
                    const Icon(Icons.reply_rounded,
                        size: 16, color: AuraSurface.muted),
                    const SizedBox(width: AuraSpace.s8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_partyName(c, _replyTo!.senderUserId),
                              style: AuraText.micro.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AuraSurface.accentText)),
                          Text(_replyTo!.body,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AuraText.micro
                                  .copyWith(color: AuraSurface.muted)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16),
                      onPressed: () => setState(() => _replyTo = null),
                    ),
                  ],
                ),
              ),
            if (_pendingPreview != null &&
                !_previewDismissed &&
                (_pendingPreview!['status'] == 'READY' ||
                    _pendingPreview!['status'] == 'INTERNAL'))
              Container(
                color: AuraSurface.card,
                padding: const EdgeInsets.fromLTRB(
                    AuraSpace.s12, AuraSpace.s6, AuraSpace.s4, AuraSpace.s6),
                child: Row(
                  children: [
                    Icon(
                        _pendingPreview!['status'] == 'INTERNAL'
                            ? Icons.link_rounded
                            : Icons.public_rounded,
                        size: 16,
                        color: AuraSurface.muted),
                    const SizedBox(width: AuraSpace.s8),
                    Expanded(
                      child: Text(
                        _draftPreviewLabel(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AuraText.micro
                            .copyWith(color: AuraSurface.muted),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16),
                      onPressed: () =>
                          setState(() => _previewDismissed = true),
                    ),
                  ],
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
                      onPressed: _showAttachMenu,
                    ),
                    IconButton(
                      tooltip:
                          _recording ? 'Stop recording' : 'Voice note',
                      icon: Icon(
                        _recording
                            ? Icons.stop_circle_rounded
                            : Icons.mic_none_rounded,
                        color: _recording ? AuraSurface.dangerInk : null,
                      ),
                      onPressed: _toggleVoiceNote,
                    ),
                    Expanded(
                      child: Focus(
                        onKeyEvent: _composerKeyEvent,
                        child: TextField(
                          controller: _composer,
                          minLines: 1,
                          maxLines: 5,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          onChanged: (t) => _onComposerChanged(t, c),
                          contentInsertionConfiguration:
                              ContentInsertionConfiguration(
                            onContentInserted: (content) async {
                              final data = content.data;
                              if (data != null && data.isNotEmpty) {
                                await _admit(await ContentIntake.resolveAndPrepareBytes(
                                  path: IntakePath.paste,
                                  bytes: Uint8List.fromList(data),
                                  fileName: 'pasted-image.png',
                                  declaredMimeType: content.mimeType,
                                ));
                              }
                            },
                          ),
                          decoration: InputDecoration(
                            hintText:
                                _recording ? 'Recording…' : 'Message…',
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
                    ),
                    const SizedBox(width: AuraSpace.s8),
                    IconButton.filled(
                      // The control reflects readiness now, instead of
                      // offering a send it would silently refuse.
                      onPressed: _composition.canSubmit ? _send : null,
                      icon: const Icon(Icons.arrow_upward_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/// Drag/drop intake: any file dropped anywhere on the conversation becomes
/// a pending attachment through the same coherent pipeline as the picker
/// and clipboard. A quiet highlight communicates the drop target.
class _DropIntake extends StatefulWidget {
  const _DropIntake({required this.onFiles, required this.child});
  final Future<void> Function(List<DropItemFile>) onFiles;
  final Widget child;

  @override
  State<_DropIntake> createState() => _DropIntakeState();
}

class _DropIntakeState extends State<_DropIntake> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragEntered: (_) => setState(() => _hovering = true),
      onDragExited: (_) => setState(() => _hovering = false),
      onDragDone: (detail) async {
        setState(() => _hovering = false);
        final files = detail.files.whereType<DropItemFile>().toList();
        await widget.onFiles(files);
      },
      child: Stack(
        children: [
          widget.child,
          if (_hovering)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: const Color(0x2210B981),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xE6111827),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text('Drop to attach',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pre-send attachment tile: real thumbnail for images, honest labeled
/// chips for audio/video, upload progress and failure states.
class _PendingAttachmentTile extends StatelessWidget {
  const _PendingAttachmentTile(
      {required this.attachment, required this.phase, required this.onRemove});
  final Attachment attachment;
  final AttachmentPhase phase;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final failed = phase == AttachmentPhase.failed;
    // Everything short of server identity, refusal aside, still reads as busy
    // - exactly what `mediaId == null && !failed` used to mean, now derived.
    final busy = AttachmentLifecycle.isPending(phase) && !failed;
    final preview =
        attachment.kind == AttachmentKind.image ? attachment.bytes : null;
    return Stack(
      children: [
        Container(
          width: 84,
          height: 84,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AuraSurface.subtle,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: failed ? AuraSurface.dangerInk : AuraSurface.divider),
          ),
          child: preview != null
              ? Image.memory(preview, fit: BoxFit.cover)
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        switch (attachment.kind) {
                          AttachmentKind.audio => Icons.mic_rounded,
                          AttachmentKind.video => Icons.videocam_rounded,
                          AttachmentKind.image => Icons.image_outlined,
                          AttachmentKind.document =>
                            Icons.insert_drive_file_outlined,
                        },
                        size: 22,
                        color: AuraSurface.muted,
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          attachment.fileName ?? 'Attachment',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AuraText.micro
                              .copyWith(color: AuraSurface.muted),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        if (busy)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x66000000),
              child: Center(
                child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
          ),
        Positioned(
          top: 2,
          right: 2,
          child: InkWell(
            onTap: onRemove,
            child: Container(
              decoration: const BoxDecoration(
                  color: Color(0xAA000000), shape: BoxShape.circle),
              padding: const EdgeInsets.all(2),
              child:
                  const Icon(Icons.close_rounded, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

/// The thread's own durable answer to "there is a call happening here".
/// Renders only from canonical server truth (an ACTIVE realtime session on
/// this conversation) and only while this client is not already in it.
class _ConversationLiveRibbon extends ConsumerWidget {
  const _ConversationLiveRibbon({required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final joined = ref.watch(
      realtimeControllerProvider.select((s) => s.isJoined),
    );
    if (joined) return const SizedBox.shrink();

    final session = ref
        .watch(conversationActiveLiveProvider(conversationId))
        .maybeWhen(data: (s) => s, orElse: () => null);
    if (session == null) return const SizedBox.shrink();

    final sessionId = (session['id'] ?? '').toString().trim();
    if (sessionId.isEmpty) return const SizedBox.shrink();
    final status = (session['status'] ?? '').toString().toUpperCase();
    if (status != 'ACTIVE') return const SizedBox.shrink();
    final isVideo = (session['kind'] ?? '').toString().toUpperCase() == 'VIDEO';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s16,
        vertical: AuraSpace.s10,
      ),
      decoration: const BoxDecoration(
        color: AuraSurface.subtle,
        border: Border(bottom: BorderSide(color: AuraSurface.divider)),
      ),
      child: Row(
        children: [
          Icon(
            isVideo ? Icons.videocam_rounded : Icons.call_rounded,
            size: 18,
            color: AuraSurface.coVerdant,
          ),
          const SizedBox(width: AuraSpace.s8),
          Expanded(
            child: Text(
              isVideo ? 'Video call in progress' : 'Call in progress',
              style: AuraText.small.copyWith(
                color: AuraSurface.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              // Decline is authoritative; the ribbon then clears from
              // server truth on the next fetch.
              try {
                await ref
                    .read(realtimeRepositoryProvider)
                    .declineInvite(sessionId);
              } catch (_) {}
              ref.invalidate(conversationActiveLiveProvider(conversationId));
            },
            child: Text(
              'Decline',
              style: AuraText.small.copyWith(color: AuraSurface.muted),
            ),
          ),
          const SizedBox(width: AuraSpace.s4),
          AuraPrimaryButton(
            label: 'Join call',
            onPressed: () => context.push(
              '${NavigationAuthority.realtimeSessionRoute(sessionId)}'
              '?action=join',
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends ConsumerWidget {
  const _MessageBubble({
    required this.message,
    required this.mine,
    required this.conversation,
    required this.onAction,
    this.translation,
  });
  final ConversationMessage message;
  final bool mine;
  final Conversation conversation;
  final void Function(String action) onAction;
  final String? translation;

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
        // Message actions — Reply/Copy/Translate for everyone; Report
        // (canonical moderation authority, frozen hook) for another
        // party's message. Long-press is the touch ergonomic; right-click
        // is the desktop one (messenger parity) — same sheet either way.
        onLongPress: () =>
            _showMessageActions(context, mine: mine, onAction: onAction),
        onSecondaryTap: () =>
            _showMessageActions(context, mine: mine, onAction: onAction),
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
              if (message.replyTo != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AuraSpace.s10, vertical: AuraSpace.s6),
                  decoration: const BoxDecoration(
                    color: AuraSurface.subtle,
                    border: Border(
                        left: BorderSide(
                            color: AuraSurface.accentText, width: 3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          _conversationSenderName(
                              conversation, message.replyTo!.senderUserId),
                          style: AuraText.micro.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AuraSurface.accentText)),
                      Text(
                        message.replyTo!.deleted
                            ? 'Message removed'
                            : message.replyTo!.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AuraText.micro
                            .copyWith(color: AuraSurface.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AuraSpace.s6),
              ],
              for (final m in message.media) ...[
                _ConversationAttachment(media: m),
                const SizedBox(height: AuraSpace.s6),
              ],
              if (message.body.trim() != '…' || message.media.isEmpty)
                SelectableText.rich(
                    _conversationRichBody(context, message.body, conversation)),
              if (message.linkPreview != null) ...[
                const SizedBox(height: AuraSpace.s6),
                _LinkPreviewCard(preview: message.linkPreview!),
              ],
              if (message.internalRef != null) ...[
                const SizedBox(height: AuraSpace.s6),
                _InternalRefCard(reference: message.internalRef!),
              ],
              if (translation != null) ...[
                const SizedBox(height: AuraSpace.s4),
                Text(translation!,
                    style: AuraText.micro.copyWith(
                        color: AuraSurface.muted,
                        fontStyle: FontStyle.italic)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Attachment renderer: resolves the visibility-checked delivery URL from
/// the canonical Media authority and renders by kind — inline image,
/// playable voice note, tap-to-play video — with an honest chip fallback.
class _ConversationAttachment extends ConsumerWidget {
  const _ConversationAttachment({required this.media});
  final MessageMediaRef media;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urlAsync = ref.watch(_deliveryUrlProvider(media.mediaId));
    return urlAsync.when(
      loading: () => Container(
        width: 220,
        height: media.isAudio ? 44 : 140,
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
      error: (e, _) => _unavailable(),
      data: (url) {
        if (url == null) return _unavailable();

        // F011 — the presentation kind comes from the RESOLVED mime, which
        // content truth has already corrected against the bytes. The coarse
        // canonical kind cannot tell a PDF from a zip (both are OTHER), which
        // is why every document used to collapse into one nameless pill.
        final kind = attachmentKindFrom(
          mimeType: media.mimeType,
          canonicalKind: media.kind,
        );

        if (kind == AttachmentPresentationKind.image) {
          // F011 — an image was renderable but not openable. It now opens in
          // the canonical viewer, which is what "seen but cannot be opened"
          // meant in the founder observation.
          return Semantics(
            button: true,
            label: media.fileName?.trim().isNotEmpty == true
                ? 'Open image ${media.fileName}'
                : 'Open image',
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => showAuraMediaViewer(
                context,
                items: [
                  AuraViewerItem(
                    originalUrl: url,
                    mediaId: media.mediaId,
                    isPublic: false,
                    caption: media.fileName,
                    downloadContext: 'conversation-attachment',
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AuraAttachmentImage(
                  url: url,
                  attachmentId: media.mediaId,
                  width: 260,
                  fit: BoxFit.cover,
                  // Even a failed image keeps its identity rather than
                  // degrading to the word "Attachment".
                  errorWidget: (_) => _card(kind, null),
                ),
              ),
            ),
          );
        }

        if (kind == AttachmentPresentationKind.audio) {
          // F014 — the canonical player. Conversation is the proving surface
          // for this capability, not its owner: the same widget serves
          // Correspondence, which previously had no inline playback at all.
          return AuraVoicePlayer(
            url: url,
            isVoiceMessage: isVoiceMessageSource(media.source),
            fileName: media.fileName,
            durationMs: media.durationMs,
          );
        }
        if (kind == AttachmentPresentationKind.video) {
          return _MediaPlayback(
              url: url, isVideo: true, mediaId: media.mediaId);
        }

        // Everything else — PDF, document, spreadsheet, presentation,
        // archive, text, unrecognised — is presented with its real identity
        // and the action appropriate to its kind.
        return _card(kind, () => openAuraAttachment(context, url: url));
      },
    );
  }

  Widget _card(AttachmentPresentationKind kind, VoidCallback? onOpen) {
    return AuraAttachmentCard(
      kind: kind,
      fileName: media.fileName,
      sizeBytes: media.fileSizeBytes,
      onOpen: onOpen,
    );
  }

  Widget _unavailable() {
    // Honest: this states that the attachment cannot be reached, and offers
    // no action that would fail. It keeps the file's identity where known.
    return AuraAttachmentCard(
      kind: attachmentKindFrom(
        mimeType: media.mimeType,
        canonicalKind: media.kind,
      ),
      fileName: media.fileName,
      sizeBytes: media.fileSizeBytes,
      unavailableReason: 'Unavailable',
    );
  }
}

/// Voice-note / video playback through the shared video_player engine
/// (HTML media element on web). Lazy: nothing initializes until played.
class _MediaPlayback extends StatefulWidget {
  const _MediaPlayback(
      {required this.url, required this.isVideo, required this.mediaId});
  final String url;
  final bool isVideo;
  final String mediaId;

  @override
  State<_MediaPlayback> createState() => _MediaPlaybackState();
}

class _MediaPlaybackState extends State<_MediaPlayback> {
  VideoPlayerController? _controller;
  bool _initializing = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_controller == null) {
      setState(() => _initializing = true);
      try {
        final controller =
            VideoPlayerController.networkUrl(Uri.parse(widget.url));
        await controller.initialize();
        setState(() => _controller = controller);
        await controller.play();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Could not play this attachment.')));
        }
      } finally {
        if (mounted) setState(() => _initializing = false);
      }
      return;
    }
    if (_controller!.value.isPlaying) {
      await _controller!.pause();
    } else {
      await _controller!.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final playing = _controller?.value.isPlaying ?? false;
    if (widget.isVideo && _controller != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 280,
          child: AspectRatio(
            aspectRatio: _controller!.value.aspectRatio == 0
                ? 16 / 9
                : _controller!.value.aspectRatio,
            child: GestureDetector(
              onTap: _togglePlay,
              child: VideoPlayer(_controller!),
            ),
          ),
        ),
      );
    }
    return InkWell(
      onTap: _initializing ? null : _togglePlay,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 220,
        padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s12, vertical: AuraSpace.s10),
        decoration: BoxDecoration(
          color: AuraSurface.subtle,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _initializing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(
                    playing
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded,
                    size: 26,
                    color: AuraSurface.accentText,
                  ),
            const SizedBox(width: AuraSpace.s10),
            Text(widget.isVideo ? 'Video' : 'Voice note',
                style: AuraText.small.copyWith(color: AuraSurface.ink)),
          ],
        ),
      ),
    );
  }
}

final _deliveryUrlProvider =
    FutureProvider.family<String?, String>((ref, mediaId) async {
  return ref.watch(conversationsRepositoryProvider).mediaDeliveryUrl(mediaId);
});


/// Message action sheet: the shared per-message capability surface.
void _showMessageActions(BuildContext context,
    {required bool mine, required void Function(String action) onAction}) {
  showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.reply_rounded),
            title: const Text('Reply'),
            onTap: () {
              Navigator.of(ctx).pop();
              onAction('reply');
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy_rounded),
            title: const Text('Copy text'),
            onTap: () {
              Navigator.of(ctx).pop();
              onAction('copy');
            },
          ),
          ListTile(
            leading: const Icon(Icons.translate_rounded),
            title: const Text('Translate'),
            onTap: () {
              Navigator.of(ctx).pop();
              onAction('translate');
            },
          ),
          if (!mine)
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Report'),
              onTap: () {
                Navigator.of(ctx).pop();
                onAction('report');
              },
            ),
        ],
      ),
    ),
  );
}

String _conversationSenderName(Conversation c, String userId) {
  for (final p in c.parties) {
    if (p.userId == userId && (p.displayName ?? '').isNotEmpty) {
      return p.displayName!;
    }
  }
  return 'Someone';
}

String _trimUrlToken(String u) {
  var out = u;
  while (out.isNotEmpty && '.,;:)]}\u2026'.contains(out[out.length - 1])) {
    out = out.substring(0, out.length - 1);
  }
  return out;
}

/// Body text with live links (internal Aura links stay inside the product,
/// external links open outside) and @mention highlighting.
TextSpan _conversationRichBody(
    BuildContext context, String body, Conversation conversation) {
  final base = AuraText.body.copyWith(color: AuraSurface.ink);
  final spans = <InlineSpan>[];
  final mentionNames = conversation.parties
      .where((p) => p.isPerson && (p.displayName ?? '').isNotEmpty)
      .map((p) => p.displayName!)
      .toList()
    ..sort((a, b) => b.length.compareTo(a.length));

  void addTextWithMentions(String t) {
    var i = 0;
    while (i < t.length) {
      final at = t.indexOf('@', i);
      if (at < 0) {
        spans.add(TextSpan(text: t.substring(i)));
        return;
      }
      if (at > i) spans.add(TextSpan(text: t.substring(i, at)));
      String? hit;
      for (final n in mentionNames) {
        if (t.startsWith('@$n', at)) {
          hit = n;
          break;
        }
      }
      if (hit != null) {
        spans.add(TextSpan(
            text: '@$hit',
            style: base.copyWith(
                fontWeight: FontWeight.w800,
                color: AuraSurface.accentText)));
        i = at + hit.length + 1;
      } else {
        spans.add(const TextSpan(text: '@'));
        i = at + 1;
      }
    }
  }

  var idx = 0;
  for (final m in RegExp(r'https?://[^\s]+').allMatches(body)) {
    if (m.start > idx) addTextWithMentions(body.substring(idx, m.start));
    final url = _trimUrlToken(m.group(0)!);
    spans.add(TextSpan(
      text: url,
      style: base.copyWith(
          color: AuraSurface.accentText,
          decoration: TextDecoration.underline),
      recognizer: TapGestureRecognizer()
        ..onTap = () => _openConversationUrl(context, url),
    ));
    final tail = m.group(0)!.substring(url.length);
    if (tail.isNotEmpty) spans.add(TextSpan(text: tail));
    idx = m.end;
  }
  if (idx < body.length) addTextWithMentions(body.substring(idx));
  return TextSpan(style: base, children: spans);
}

void _openConversationUrl(BuildContext context, String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  final host = uri.host.toLowerCase();
  final internal =
      host == 'auraplatform.org' || host.endsWith('.auraplatform.org');
  if (internal && uri.path.isNotEmpty && uri.path != '/') {
    // Internal Aura link: stay inside the product — the destination's
    // own authority decides what this viewer may see.
    GoRouter.of(context)
        .push(uri.path + (uri.hasQuery ? '?${uri.query}' : ''));
    return;
  }
  launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Rendered external-link preview card (canonical LinkPreview data).
class _LinkPreviewCard extends StatelessWidget {
  const _LinkPreviewCard({required this.preview});
  final LinkPreviewRef preview;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openConversationUrl(context, preview.url),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AuraSurface.subtle,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (preview.imageUrl != null)
              Image.network(
                preview.imageUrl!,
                height: 140,
                width: 340,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            Padding(
              padding: const EdgeInsets.all(AuraSpace.s10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (preview.siteName != null)
                    Text(preview.siteName!,
                        style: AuraText.micro
                            .copyWith(color: AuraSurface.faint)),
                  if (preview.title != null)
                    Text(preview.title!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AuraText.micro.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AuraSurface.ink)),
                  if (preview.description != null)
                    Text(preview.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AuraText.micro
                            .copyWith(color: AuraSurface.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// The direct counterpart's real identity image (person avatar or
/// institution logo) for header/list presentation.
// _counterpartAvatarUrl retired 2026-08-17 — it returned the first party
// with any avatar, so a group thread wore one member's photo. Canonical
// rule now lives in conversation_identity.dart
// (conversationDisplayAvatarUrl), shared with the Messages list.

/// Internal Aura reference card — the same visual grade as an external
/// preview, sourced from the object's OWN authority (real content, not
/// scraped). Tapping stays inside the product on the canonical route.
class _InternalRefCard extends StatelessWidget {
  const _InternalRefCard({required this.reference});
  final InternalRef reference;

  static const _kindLabels = <String, String>{
    'POST': 'Post',
    'INSTITUTION_POST': 'Institution post',
    'ANNOUNCEMENT': 'Announcement',
    'ARTICLE': 'Article',
    'USER_PROFILE': 'Profile',
    'INSTITUTION_PROFILE': 'Institution',
    'MEETING': 'Meeting',
    'THREAD': 'Thread',
    'SPACE': 'Space',
    'INSTITUTION_SPACE': 'Space',
    'DIRECT_THREAD': 'Direct message',
  };

  @override
  Widget build(BuildContext context) {
    final label = _kindLabels[reference.kind] ?? 'Aura';
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => GoRouter.of(context).push(reference.route),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AuraSurface.subtle,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (reference.imageUrl != null)
              Image.network(
                reference.imageUrl!,
                height: 140,
                width: 340,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            Padding(
              padding: const EdgeInsets.all(AuraSpace.s10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AuraSurface.accentText,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AuraSpace.s6),
                      Text('Aura \u00b7 $label',
                          style: AuraText.micro
                              .copyWith(color: AuraSurface.faint)),
                    ],
                  ),
                  if (reference.title != null) ...[
                    const SizedBox(height: AuraSpace.s4),
                    Text(reference.title!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AuraText.micro.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AuraSurface.ink)),
                  ],
                  if (reference.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(reference.subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AuraText.micro
                            .copyWith(color: AuraSurface.muted)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Space identity in the conversation header: the Space's name, and its
/// purpose when it has one. Two lines at most — the header is a place to know
/// where you are, not a place to read the charter.
class _SpaceHeading extends StatelessWidget {
  const _SpaceHeading({required this.context});
  final InstitutionSpaceContext context;

  @override
  Widget build(BuildContext ctx) {
    final purpose = (context.purpose ?? '').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AuraText.body
              .copyWith(fontWeight: FontWeight.w800, color: AuraSurface.ink),
        ),
        if (purpose.isNotEmpty)
          Text(
            purpose,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AuraText.micro.copyWith(color: AuraSurface.muted),
          ),
      ],
    );
  }
}
