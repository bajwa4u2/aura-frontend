import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../core/auth/session_providers.dart';
import '../../realtime/domain/call_state.dart';
import '../../correspondence/data/correspondence_live_service.dart';
import '../data/conversation_unread_authority.dart';
import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/attachments/aura_media_upload.dart';
import '../../../core/media/aura_attachment_card.dart';
import '../../../core/media/aura_stored_media.dart';
import '../../../core/errors/app_error_mapper.dart';
import '../../../core/media/aura_voice_player.dart';
import '../../../core/notifications/android_telecom.dart';
import '../../../core/notifications/ios_call_kit.dart';
import '../../../core/media/voice_note_capture.dart';
import '../../../core/media/stored_media.dart';
import '../../../core/media/aura_media_viewer.dart';
import '../../../core/media/aura_attachment_open.dart';
import '../../../core/compliance/report_content_sheet.dart';
import '../../updates/providers.dart';
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
import '../../share_intake/application/share_handoff.dart';
import '../data/conversations_repository.dart';
import 'add_people_sheet.dart';
import 'conversation_avatar.dart';
import 'conversation_identity.dart';
import 'message_interactions.dart';
import '../../realtime/application/realtime_providers.dart';
import '../../updates/incoming_call_bridge.dart';
import 'conversation_incoming_call.dart';
import '../../../core/composition/attachment_lifecycle.dart';
import '../../../core/composition/composition_authority.dart';
import '../../../core/composition/content_intake.dart';
import '../../../core/content_policy/content_length_policy.dart';
import '../../../core/media/attachment.dart';
import '../../../core/media/trace/aura_trace_mark.dart';
import '../../../core/media/trace/aura_trace_surface.dart';
import '../../../core/media/aura_composition_strip.dart';
import '../../../core/media/media_acquisition.dart';
import '../../../core/media/media_origin_disclosure.dart';
import '../../../core/tagging/governed_tag_field.dart';
import '../../../core/tagging/mention_scope.dart';
import '../../../core/tagging/tag_entities.dart';
import '../../../core/ui/aura_bounded_editor.dart';

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
  /// Whether this conversation is actually in front of the human right now.
  ///
  /// Two conditions, and both are needed. `isCurrent` answers "is this route
  /// on top" — a conversation sitting beneath a pushed profile or composer is
  /// not being read. The lifecycle state answers "is the app in front of
  /// them" — a backgrounded app can still receive messages, and marking those
  /// read would be the system asserting something about a person who was not
  /// there.
  bool _isVisiblyPresented() {
    if (!mounted) return false;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return false;
    }
    return ModalRoute.of(context)?.isCurrent ?? false;
  }

  /// The canonical Conversation runtime now announces its own messages, so a
  /// conversation open on screen receives what arrives in it. The payload is a
  /// trigger: this re-reads through the canonical endpoint rather than
  /// trusting a socket to carry message content.
  void _listenForIncoming() {
    _incomingSub?.cancel();
    _incomingSub = ref.read(correspondenceLiveServiceProvider).events.listen((
      event,
    ) {
      // A MESSAGE ARRIVED, OR ONE CHANGED.
      //
      // Both are triggers and both are answered the same way: re-read the
      // canonical projection. A reaction, an edit and a retraction all alter
      // what a message IS, and only the projection knows what this particular
      // viewer may now see of it — so the socket says that something moved and
      // never what it now says.
      const watched = {
        'conversation:message.created',
        'conversation:message.changed',
      };
      if (!watched.contains(event.name)) return;
      final id = (event.payload['conversationId'] ?? '').toString().trim();
      if (id != widget.conversationId) return;
      if (!mounted) return;
      ref.invalidate(conversationMessagesProvider(widget.conversationId));
    });
  }

  StreamSubscription<CorrespondenceLiveEvent>? _incomingSub;

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

  /// What the author says about the origin of the media they are attaching.
  ///
  /// Null by default — saying nothing records nothing. Applied to every item in
  /// this composition, because a person composing one message is making one
  /// statement about what they are sending, not one per file.
  OriginDeclaration? _originDeclaration;

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
  void initState() {
    super.initState();
    _listenForIncoming();
    _adoptSharedContent();
  }

  /// Pick up content the person shared from another application and chose to
  /// send here.
  ///
  /// It arrives ALREADY RESOLVED — through the same `ContentIntake` door as a
  /// picker or a paste — and it arrives UNSENT. Nothing about having come from
  /// a share sheet shortens the path: it lands in this composer, in the draft,
  /// and the person presses the same send button as always.
  ///
  /// Claimed by conversation id, so opening any other conversation cannot pick
  /// it up.
  void _adoptSharedContent() {
    final staged =
        ref.read(shareHandoffProvider.notifier).takeForConversation(widget.conversationId);
    if (staged == null) return;
    _composer.text = staged.body;
    setState(() {
      _composition = _composition.copyWith(
        body: staged.body,
        attachments: staged.attachments,
      );
    });
  }

  @override
  void dispose() {
    _incomingSub?.cancel();
    _linkDebounce?.cancel();
    _composer.dispose();
    _composerFocus.dispose();
    _recorder.dispose();
    super.dispose();
  }

  // ── Composer intelligence ─────────────────────────────────────────

  void _onComposerChanged(String text, Conversation c) {
    final sel = _composer.selection;
    final caret = sel.isValid
        ? sel.baseOffset.clamp(0, text.length)
        : text.length;
    final upto = text.substring(0, caret);
    final token = RegExp(r'@([^\s@]*)$').firstMatch(upto);
    List<ConversationParty> matches = const [];
    if (token != null) {
      final q = token.group(1)!.toLowerCase();
      matches = c.parties
          .where(
            (p) =>
                p.isPerson &&
                p.isActive &&
                (p.displayName ?? '').isNotEmpty &&
                p.displayName!.toLowerCase().contains(q),
          )
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
      const Duration(milliseconds: 600),
      () => _resolveDraftLink(text),
    );
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
    final caret = sel.isValid
        ? sel.baseOffset.clamp(0, text.length)
        : text.length;
    final upto = text.substring(0, caret);
    final token = RegExp(r'@([^\s@]*)$').firstMatch(upto);
    if (token == null) return;
    final next =
        '${upto.substring(0, token.start)}@$name ${text.substring(caret)}';
    _composer.text = next;
    _composer.selection = TextSelection.collapsed(
      offset: token.start + name.length + 2,
    );
    setState(() => _mentionMatches = const []);
  }

  /// Ctrl/Cmd+V with an image on the clipboard becomes an attachment
  /// through the same coherent intake as drag/drop; text paste untouched.
  /// Focus for the composer, required by the governed tag autocomplete so it
  /// can attach and dismiss its suggestion overlay.
  final FocusNode _composerFocus = FocusNode();

  /// Structured references chosen in this composer, kept until send.
  ///
  /// Collected rather than re-parsed from the text: a reference is an identity,
  /// and re-deriving it from what the text happens to say is how a rename or a
  /// duplicate display name turns into the wrong person.
  final List<TagReference> _selectedTagReferences = <TagReference>[];

  /// The references still genuinely present in the composed text.
  ///
  /// A reference whose text the person deleted is no longer a reference, so it
  /// is dropped rather than sent for text that is not there. Deduplicated by
  /// (kind, entity) so editing around a name cannot send the same person twice.
  List<Map<String, dynamic>> _currentTagPayload() {
    final text = _composer.text;
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final reference in _selectedTagReferences) {
      if (!reference.isMention) continue;
      if (!text.contains(reference.durableSourceText)) continue;
      final key = '${reference.kind.name}:${reference.durableEntityId}';
      if (!seen.add(key)) continue;
      out.add(reference.toJson());
    }
    return out;
  }

  void _rememberSelectedTag(TagReference reference) {
    if (!reference.isMention) return;
    final id = reference.durableEntityId;
    if (id.isEmpty || reference.durableSourceText.isEmpty) return;
    _selectedTagReferences.removeWhere(
      (existing) =>
          existing.kind == reference.kind && existing.durableEntityId == id,
    );
    _selectedTagReferences.add(reference);
  }

  /// The people and institutions actually in this conversation.
  ///
  /// Bounded scope, matching what the server will accept: referencing someone
  /// who is not here would be refused, so offering them would be a lie.
  List<TagSuggestion> _eligibleTagSuggestions(Conversation c) {
    final out = <TagSuggestion>[];
    for (final p in c.parties) {
      if (p.leftAt != null) continue;

      // Person and institution identity are read through their OWN
      // accessors -- the party model keeps them deliberately separate so no
      // path can read an institution's name through a person-shaped field.
      if (p.kind == 'INSTITUTION') {
        final id = (p.institutionId ?? '').trim();
        final label = (p.institutionName ?? '').trim();
        if (id.isEmpty || label.isEmpty) continue;
        out.add(
          TagSuggestion(
            kind: TagKind.institution,
            canonicalId: id,
            display: label,
            insertText: '@$label',
            imageUrl: p.institutionLogoUrl,
          ),
        );
        continue;
      }

      final person = p.person;
      if (person == null) continue;
      final label = person.displayName.trim();
      final handle = person.handle.trim();
      if (person.userId.trim().isEmpty || label.isEmpty) continue;
      // insertText is the sigil form written into the text; canonicalId is
      // the public key. A party with no handle stays referenceable by id
      // rather than silently absent from their own conversation.
      final publicKey = handle.isNotEmpty ? handle : person.userId;
      out.add(
        TagSuggestion(
          kind: TagKind.member,
          canonicalId: publicKey,
          display: label,
          insertText: '@$publicKey',
          subtitle: handle.isNotEmpty ? '@$handle' : null,
          imageUrl: person.avatarUrl,
        ),
      );
    }
    return out;
  }

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
        await _admit(
          await ContentIntake.resolveAndPrepareBytes(
            path: IntakePath.paste,
            bytes: bytes,
            fileName: 'pasted-image.png',
            declaredMimeType: 'image/png',
          ),
        );
      }
    } catch (_) {
      // No image on the clipboard — the native text paste proceeds.
    }
  }

  /// Reload the thread from the canonical projection.
  ///
  /// Every mutation ends here rather than patching a local copy: the
  /// projection is the only thing that knows what THIS viewer may see after a
  /// retract, an edit or a removal, and a locally-patched list would be a
  /// second answer.
  void _reloadMessages() {
    ref.invalidate(conversationMessagesProvider(widget.conversationId));
  }

  Future<void> _react(ConversationMessage msg, String type) async {
    await MessageActions(ref, widget.conversationId).react(context, msg, type);
    _reloadMessages();
  }

  /// EDIT — the author rewrites their own message.
  ///
  /// Prior versions are retained by the authority, so this is not a
  /// destructive overwrite even though it looks like one from here.
  Future<void> _startEdit(ConversationMessage msg) async {
    final controller = TextEditingController(text: msg.body);
    final next = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AuraSurface.card,
        title: const Text('Edit message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
          minLines: 1,
          decoration: const InputDecoration(hintText: 'Message'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (next == null || next.isEmpty || next == msg.body) return;
    await MessageActions(ref, widget.conversationId).edit(context, msg, next);
    _reloadMessages();
  }

  /// FORWARD — pick a destination from the conversations this person is in.
  ///
  /// Only conversations they are already party to are offered, because
  /// forwarding requires membership on BOTH sides. Offering one they are not
  /// in would produce a control that fails.
  Future<void> _forward(ConversationMessage msg) async {
    final all = await ref.read(conversationsRepositoryProvider).list();
    final options = all.where((c) => c.id != widget.conversationId).toList();
    if (!mounted) return;

    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('There is nowhere to forward this yet.')),
      );
      return;
    }

    final myUserId = ref.read(myUserIdProvider);
    final destination = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AuraSurface.card,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AuraSpace.s16),
              child: Row(
                children: [
                  Expanded(child: Text('Forward to', style: AuraText.title)),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final c in options)
                    ListTile(
                      leading: ConversationAvatar(
                        conversation: c,
                        myUserId: myUserId,
                        size: 36,
                      ),
                      title: Text(conversationDisplayName(c, myUserId)),
                      onTap: () => Navigator.of(sheetContext).pop(c.id),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (destination == null || !mounted) return;
    await MessageActions(
      ref,
      widget.conversationId,
    ).forward(context, msg, destination);
  }

  Future<void> _messageAction(String action, ConversationMessage msg) async {
    switch (action) {
      case 'reply':
        setState(() => _replyTo = msg);
        return;
      case 'copy':
        await Clipboard.setData(ClipboardData(text: msg.body));
        return;
      case 'edit':
        await _startEdit(msg);
        return;
      case 'retract':
        await MessageActions(ref, widget.conversationId).retract(context, msg);
        _reloadMessages();
        return;
      case 'removeForMe':
        await MessageActions(
          ref,
          widget.conversationId,
        ).removeForMe(context, msg);
        _reloadMessages();
        return;
      case 'forward':
        await _forward(msg);
        return;
      case 'translate':
        final target = Localizations.localeOf(context).languageCode;
        try {
          final t = await ref
              .read(conversationsRepositoryProvider)
              .translateMessage(msg.id, msg.body, target);
          if (mounted) {
            setState(
              () => _translations[msg.id] = t.trim() == msg.body.trim()
                  ? 'Already in your language'
                  : t,
            );
          }
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Translation is not available right now.'),
              ),
            );
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
    setState(
      () => _composition = _composition.copyWith(
        attachments: [..._composition.attachments, attachment],
      ),
    );
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
        // The author's declaration travels with the upload, so it is
        // recorded as attributed evidence at presign rather than becoming a
        // client-side label nothing else can see.
        originDeclaration: _originDeclaration == null
            ? null
            : originDeclarationWire(_originDeclaration!),
        dio: ref.read(dioProvider),
        bytes: attachment.bytes!,
        fileName: attachment.fileName ?? 'attachment',
        mimeType: attachment.mimeType!,
        originalMimeType: attachment.originalMimeType,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attachment failed — remove it and try again.'),
        ),
      );
    }
  }

  /// ONE PICKER, IMAGES AND VIDEOS TOGETHER.
  ///
  /// `_attachPhoto` and `_attachVideo` were both SINGULAR, so attaching four
  /// photographs meant opening the picker four times. That was never a policy
  /// anyone chose — it is the shape the old single-select API left behind.
  ///
  /// Selection order is author intent from the first moment, so items are
  /// admitted in the order they were chosen and never re-sorted.
  Future<void> _attachMedia() async {
    final remaining = kMaxComposableMedia - _composition.liveAttachments.length;
    final acquired = await acquireMultipleMedia(remainingSlots: remaining);
    if (acquired.isEmpty) return;

    for (final resolution in acquired.resolutions) {
      await _admit(resolution);
    }

    // The ceiling is REPORTED, never silent. Quietly dropping the fifth of
    // five chosen photographs is the exact class of silence this removes.
    final message = acquisitionLimitMessage(acquired.droppedForLimit);
    if (message != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// Move an item. Order is persisted against `MessageMedia.position`, so what
  /// the author arranges here is what is stored, returned and rendered.
  void _reorderAttachment(int oldIndex, int newIndex) {
    setState(() {
      _composition = _composition.reorderAttachment(oldIndex, newIndex);
    });
  }

  /// Remove an item, and make the removal stick.
  ///
  /// An upload already in flight may still complete afterwards; the authority
  /// records the id as cancelled so a late success cannot resurrect media the
  /// author has taken out.
  void _removeAttachment(String localId) {
    setState(() {
      _composition = _composition.removeAttachment(localId);
    });
  }

  /// Retry ONE failed item, leaving its successful siblings alone.
  ///
  /// Re-uploading everything to recover one failure would waste the person's
  /// bandwidth and time on work that already succeeded.
  Future<void> _retryAttachment(Attachment attachment) async {
    if (_composition.isWithdrawn(attachment.localId)) return;
    setState(() {
      attachment.error = null;
      attachment.uploading = true;
    });
    await _upload(attachment);
  }

  void _showAttachMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AuraSurface.page,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ONE entry, because it is ONE selection. Separate "Photo" and
            // "Video" rows existed only because the pickers behind them were
            // singular, and they forced a person attaching a photo and a video
            // to make two trips through the menu.
            ListTile(
              leading: const Icon(Icons.perm_media_outlined),
              title: const Text('Photos & videos'),
              onTap: () {
                Navigator.of(ctx).pop();
                _attachMedia();
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
    // A video MESSAGE sends itself — capture IS the send. It goes through the
    // same governed door as everything else; capture earns no exemption.
    //
    // Through the canonical acquisition now, rather than a private picker.
    // The hand-written version also carried `?? 'video/webm'`, which GUESSED a
    // container the phone had not claimed -- Android records mp4, and a wrong
    // declared type is exactly what the intake door exists to refuse rather
    // than invent.
    final acquired = await captureVideo(remainingSlots: 1);
    if (acquired.resolutions.isEmpty) return;
    await _uploadAndSendImmediately(acquired.resolutions.first);
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
        // The author's declaration travels with the upload, so it is
        // recorded as attributed evidence at presign rather than becoming a
        // client-side label nothing else can see.
        originDeclaration: _originDeclaration == null
            ? null
            : originDeclarationWire(_originDeclaration!),
        dio: ref.read(dioProvider),
        bytes: attachment.bytes!,
        fileName: attachment.fileName ?? 'attachment',
        mimeType: attachment.mimeType!,
        originalMimeType: attachment.originalMimeType,
        // This surface has always sent the semantic kind, and must keep
        // doing so: 'DOCUMENT' buys the 25 MiB document bucket, 'IMAGE'
        // would silently cut it to 10 MiB and start refusing PDFs that
        // attach today.
        kind: wireKind(attachment.kind, collapseDocumentToImage: false),
        source: wireSource(attachment.source),
      );
      await ref
          .read(conversationsRepositoryProvider)
          .send(widget.conversationId, '…', mediaIds: [result.mediaId]);
      ref.invalidate(conversationMessagesProvider(widget.conversationId));
      ref.invalidate(conversationsListProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send — try again.')),
        );
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
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    final file = result?.files.firstOrNull;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    await _admit(
      await ContentIntake.resolveAndPrepareBytes(
        path: IntakePath.picker,
        bytes: bytes,
        fileName: file.name,
        source: AttachmentSource.upload,
      ),
    );
  }

  // `_ingestBytes` used to live here. It resolved mime and kind itself and,
  // when neither the caller nor the filename answered, fell back to
  // `application/octet-stream` - a type the server's allow-list refuses at
  // presign. The attachment appeared in the composer, climbed, and failed
  // with a generic message, because the fallback moved the refusal later
  // rather than removing it. ContentIntake refuses at the door, truthfully,
  // and never manufactures a type it has no evidence for.

  /// Voice note: record → stop → the note joins the pending attachments.
  ///
  /// WHAT WAS WRONG HERE, AND WHY IT ONLY EVER WORKED IN A BROWSER.
  ///
  /// This asserted one container and one read-back mechanism for every
  /// platform, and `record` provides neither uniformly:
  ///
  ///   * `AudioEncoder.opus` writes WebM in Chrome and Firefox, **OGG** on
  ///     Android, **CAF** on iOS, and is **not supported at all** on Windows
  ///     or macOS. The declaration `audio/webm` was therefore true on exactly
  ///     one platform, and the backend's content-truth check refused the rest
  ///     — after the person had already spoken.
  ///   * `stop()` returns a `blob:` URL on the web but a FILESYSTEM PATH
  ///     natively, and this read it back with an HTTP client either way. On
  ///     every native build that failed before a single byte was uploaded.
  ///   * `path: 'voice-note.webm'` is relative, and native recorders need an
  ///     absolute one.
  ///
  /// [VoiceNoteCapture] now answers all three, per platform, and the format it
  /// reports is what the bytes genuinely are.
  Future<void> _toggleVoiceNote() async {
    if (_recording) {
      final handle = await _recorder.stop();
      setState(() => _recording = false);
      if (handle == null) return;
      try {
        final bytes = await VoiceNoteCapture.readCaptured(handle);
        final format = VoiceNoteCapture.format;
        // Messenger ergonomics (founder): a voice MESSAGE sends itself —
        // stop recording IS the send.
        await _uploadAndSendImmediately(
          await ContentIntake.resolveAndPrepareBytes(
            path: IntakePath.picker,
            bytes: bytes,
            fileName: format.fileName,
            declaredMimeType: format.mimeType,
            source: AttachmentSource.recording,
          ),
        );
        await VoiceNoteCapture.discardCaptured(handle);
      } catch (e) {
        // The swallowed error was the whole problem: three distinct native
        // failures all surfaced as one sentence that suggested trying again,
        // which never helped because nothing transient was wrong.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'The voice note could not be sent. ${AppErrorMapper.from(e).message}',
              ),
            ),
          );
        }
      }
      return;
    }
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is needed for voice notes.'),
          ),
        );
      }
      return;
    }
    try {
      final format = VoiceNoteCapture.format;
      await _recorder.start(
        RecordConfig(encoder: format.encoder),
        path: await VoiceNoteCapture.targetPath(format.extension),
      );
      setState(() => _recording = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Recording could not start. ${AppErrorMapper.from(e).message}',
            ),
          ),
        );
      }
    }
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
      await ref
          .read(conversationsRepositoryProvider)
          .send(
            widget.conversationId,
            text.isEmpty ? '…' : text,
            mediaIds: mediaIds,
            tagReferences: _currentTagPayload(),
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
        setState(
          () => _composition = _composition.copyWith(isSubmitting: false),
        );
      }
    }
  }

  /// Conversation → Call/Video: the session is an ephemeral capability of
  /// this conversation; the other parties receive the canonical incoming
  /// experience through the certified call-notification pipeline.
  Future<void> _startCall(String kind) async {
    if (_startingCall) return;

    // TAPPING CALL PLACES THE CALL.
    //
    // There used to be a device sheet in front of this: tap Call, wait while
    // the microphone and camera were checked, read a summary, then press a
    // second button to actually start. It was added for a real reason — before
    // it, the OS permission prompt arrived mid-join with nothing explaining it
    // — but it answered that by making every single call cost an extra screen
    // and an extra tap, including the overwhelming majority where the devices
    // were fine and nobody needed telling.
    //
    // No phone works that way, and it did not read as care. It read as the app
    // getting in the way of a phone call.
    //
    // The original concern is now met where it belongs, inside the call: the
    // permission prompt appears over the calling screen, which is its own
    // explanation, and a genuine device problem surfaces there with a real
    // action next to it instead of blocking the call from ever starting.
    // `CallReadiness` still owns that judgement and is unchanged; what is gone
    // is the gate.
    final video = kind == 'VIDEO';
    final conversation = ref
        .read(conversationProvider(widget.conversationId))
        .valueOrNull;
    final myUserId = ref.read(myUserIdProvider);
    final who = conversation == null
        ? null
        : conversationDisplayName(conversation, myUserId);

    setState(() => _startingCall = true);
    try {
      final sessionId = await ref
          .read(conversationsRepositoryProvider)
          .startLive(widget.conversationId, kind: kind);
      if (sessionId.isEmpty) throw Exception('no session');

      // TELL THE SYSTEM ABOUT A CALL AURA IS PLACING.
      //
      // The session exists and is Aura's; this only asks the OS to represent
      // it, which is what puts an outgoing call in the phone's call register
      // and lets it participate in audio routing and cellular-call
      // interaction. Deliberately after `startLive`, because the session id is
      // the identity both sides map by — and deliberately unawaited-on-failure:
      // the return value says whether the OS will show the call, never whether
      // the call happened. Where CallKit is prohibited by storefront or simply
      // absent, this is a no-op and the call proceeds unchanged.
      unawaited(
        IosCallKit.instance
            .reportOutgoingStarted(
              sessionId,
              displayName: (who ?? '').trim().isEmpty ? 'Aura call' : who!,
              video: video,
            )
            .catchError((_) => false),
      );
      // Track C — the same report to Android's call stack, from the same
      // line, with the same identity and the same indifference to the answer.
      // Each is a no-op off its own platform.
      unawaited(
        AndroidTelecom.instance
            .reportOutgoing(
              sessionId,
              displayName: (who ?? '').trim().isEmpty ? 'Aura call' : who!,
              video: video,
            )
            .catchError((_) => false),
      );

      if (mounted) {
        // Pressing Call IS the intent. Navigating to the bare session
        // address made the room ask the caller to join the call they had
        // just started — measured live 2026-08-22: the initiator sat on
        // "Ready to join" while the other side was already in the room
        // seeing a two-participant call with no remote media.
        context.push(NavigationAuthority.realtimeSessionJoinRoute(sessionId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not start the call — try again.'),
          ),
        );
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
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(controller.text),
                child: const Text('Save'),
              ),
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
    final conversationAsync = ref.watch(
      conversationProvider(widget.conversationId),
    );
    final messagesAsync = ref.watch(
      conversationMessagesProvider(widget.conversationId),
    );
    final myUserId = ref.watch(myUserIdProvider);

    // READING ADVANCES THE CANONICAL CURSOR, AND EVERY UNREAD CONSUMER IS
    // TOLD IMMEDIATELY.
    //
    // Two ledgers reach new truth here, and they are not the same ledger:
    //
    //   CONVERSATION READ STATE — the authority the Messages badge derives
    //   from. Invalidated deterministically, because a poll is reconciliation
    //   and must not be how the UI learns the result of a mutation the app
    //   itself just performed. Before this, a person read the messages and
    //   watched the badge keep counting them for up to two minutes.
    //
    //   ATTENTION — refreshed because the server clears the message-attention
    //   rows linked to this conversation as a CONSEQUENCE of the read. It is
    //   synchronised, never substituted: it no longer answers "are there
    //   unread messages".
    ref.listen(conversationMessagesProvider(widget.conversationId), (
      prev,
      next,
    ) {
      next.whenData((_) {
        // READ IS NOT INFERRED FROM DELIVERY (founder ruling §4).
        //
        // This fired whenever messages arrived, including while the route sat
        // beneath another screen or the app was backgrounded — which would
        // mark content read that no human had been shown. Read advancement
        // requires the content to actually be presented: this route on top,
        // and the app in the foreground.
        if (!_isVisiblyPresented()) return;
        advanceConversationRead(
          ref,
          widget.conversationId,
          markRead: () => ref
              .read(conversationsRepositoryProvider)
              .markRead(widget.conversationId),
          refreshAttention: () => ref
              .read(notificationsControllerProvider.notifier)
              .refresh(force: true),
        ).ignore();
      });
    });

    return conversationAsync.when(
      loading: () => AuraScaffold(
        body: const AuraProductState(
          state: ProductState.loading,
          subject: ProductNoun.conversation,
        ),
      ),
      error: (e, _) => AuraScaffold(
        body: AuraProductState(
          state: ProductState.unavailable,
          subject: ProductNoun.conversation,
          detail: 'It may have been removed, or you may have left it.',
          action: AuraSecondaryButton(
            label: 'Back to Messages',
            onPressed: () => context.pop(),
          ),
        ),
      ),
      data: (c) => _DropIntake(
        onFiles: (files) async {
          for (final f in files) {
            await _admit(
              await ContentIntake.resolveAndPrepareBytes(
                path: IntakePath.drop,
                bytes: await f.readAsBytes(),
                fileName: f.name,
                declaredMimeType: f.mimeType,
                source: AttachmentSource.upload,
              ),
            );
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
                  horizontal: AuraSpace.s8,
                  vertical: AuraSpace.s6,
                ),
                decoration: const BoxDecoration(
                  color: AuraSurface.card,
                  border: Border(
                    bottom: BorderSide(color: AuraSurface.divider),
                  ),
                ),
                child: Row(
                  children: [
                    // RETIRED 2026-08-25 — the way out is governed now.
                    //
                    // This control did exactly what ReturnPathAuthority now
                    // resolves: pop if there is history, otherwise Messages —
                    // and inside a Space, the Space's own `onBack`, which was
                    // itself `go('/institution/:id/spaces')`, the same answer
                    // the authority derives. Keeping it put two arrows on one
                    // screen, which is what the shared control exists to end.
                    //
                    // The governed one is also strictly better in a Space: it
                    // unwinds the real journey when there is one, where this
                    // replaced it unconditionally.
                    // F056: counterpart avatar for 1:1, bounded composite of
                    // canonical participant identities for a group.
                    ConversationAvatar(
                      conversation: c,
                      myUserId: myUserId,
                      size: 34,
                    ),
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
                                color: AuraSurface.ink,
                              ),
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
                      onPressed: _startingCall
                          ? null
                          : () => _startCall('AUDIO'),
                    ),
                    IconButton(
                      tooltip: 'Video',
                      icon: const Icon(Icons.videocam_rounded),
                      onPressed: _startingCall
                          ? null
                          : () => _startCall('VIDEO'),
                    ),
                    IconButton(
                      tooltip: 'Add people',
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      onPressed: () => showAddPeopleSheet(
                        context,
                        ref,
                        widget.conversationId,
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (a) => _menu(a, c),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'rename',
                          child: Text('Name'),
                        ),
                        PopupMenuItem(
                          value: 'mute',
                          child: Text(c.muted ? 'Unmute' : 'Mute'),
                        ),
                        PopupMenuItem(
                          value: 'archive',
                          child: Text(c.archived ? 'Unarchive' : 'Archive'),
                        ),
                        const PopupMenuItem(
                          value: 'leave',
                          child: Text('Leave'),
                        ),
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
              ConversationIncomingCall(conversationId: widget.conversationId),
              _ConversationLiveRibbon(conversationId: widget.conversationId),
              Expanded(
                child: messagesAsync.when(
                  loading: () => const AuraProductState(
                    state: ProductState.loading,
                    subject: ProductNoun.message,
                  ),
                  error: (e, _) => AuraProductState(
                    state: ProductState.retryableError,
                    subject: ProductNoun.message,
                    onRecover: () => ref.invalidate(
                      conversationMessagesProvider(widget.conversationId),
                    ),
                  ),
                  data: (messages) => ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(AuraSpace.s12),
                    itemCount: messages.length,
                    itemBuilder: (_, i) {
                      final m = messages[i];
                      // The list is REVERSED, so index + 1 is the message
                      // BEFORE this one in time.
                      final previous = i + 1 < messages.length
                          ? messages[i + 1]
                          : null;
                      return _MessageBubble(
                        message: m,
                        mine: m.senderUserId == myUserId,
                        conversation: c,
                        // WHO SAID THIS.
                        //
                        // Seen in a live institution Space, 2026-08-24: a
                        // three-party correspondence rendered an incoming
                        // message as a bare bubble with no author. In a
                        // conversation with more than two sides that is
                        // unreadable — the same defect as a participation
                        // event without its actor, one layer down.
                        //
                        // Only where it adds something: a direct
                        // correspondence already names the other party in
                        // the header, and a run of messages from one person
                        // is attributed by its first.
                        showSender: shouldNameSender(
                          conversation: c,
                          message: m,
                          previous: previous,
                          myUserId: myUserId,
                        ),
                        translation: _translations[m.id],
                        onAction: (a) => _messageAction(a, m),
                        onReact: (type) => _react(m, type),
                      );
                    },
                  ),
                ),
              ),
              // THE CANONICAL COMPOSITION STRIP.
              //
              // The hand-rolled Wrap it replaces removed items by filtering the
              // list directly, which left no record that the author had
              // withdrawn them — an upload still in flight could complete
              // afterwards and put the item back. Removal now goes through the
              // authority, which records the cancellation so a late success
              // cannot resurrect it.
              // Shown only when there is visual media to describe. Asking about
              // the origin of a voice note or a document would be noise.
              MediaOriginDisclosureControl(
                value: _originDeclaration,
                visible: _attachments.any(
                  (a) =>
                      a.kind == AttachmentKind.image ||
                      a.kind == AttachmentKind.video,
                ),
                onChanged: (v) => setState(() => _originDeclaration = v),
              ),
              if (_attachments.isNotEmpty)
                AuraCompositionStrip(
                  attachments: _attachments,
                  phaseOf: _composition.phaseOf,
                  onRemove: _removeAttachment,
                  onReorder: _reorderAttachment,
                  onRetry: _retryAttachment,
                ),
              if (_mentionMatches.isNotEmpty)
                Container(
                  width: double.infinity,
                  color: AuraSurface.card,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AuraSpace.s12,
                    vertical: AuraSpace.s6,
                  ),
                  child: Wrap(
                    spacing: AuraSpace.s6,
                    children: [
                      for (final p in _mentionMatches)
                        ActionChip(
                          avatar: AuraAvatar(
                            name: p.displayName ?? '',
                            imageUrl: p.avatarUrl,
                            size: 20,
                          ),
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
                    AuraSpace.s12,
                    AuraSpace.s6,
                    AuraSpace.s4,
                    AuraSpace.s6,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.reply_rounded,
                        size: 16,
                        color: AuraSurface.muted,
                      ),
                      const SizedBox(width: AuraSpace.s8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _partyName(c, _replyTo!.senderUserId),
                              style: AuraText.micro.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AuraSurface.accentText,
                              ),
                            ),
                            Text(
                              _replyTo!.body,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AuraText.micro.copyWith(
                                color: AuraSurface.muted,
                              ),
                            ),
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
                    AuraSpace.s12,
                    AuraSpace.s6,
                    AuraSpace.s4,
                    AuraSpace.s6,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _pendingPreview!['status'] == 'INTERNAL'
                            ? Icons.link_rounded
                            : Icons.public_rounded,
                        size: 16,
                        color: AuraSurface.muted,
                      ),
                      const SizedBox(width: AuraSpace.s8),
                      Expanded(
                        child: Text(
                          _draftPreviewLabel(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AuraText.micro.copyWith(
                            color: AuraSurface.muted,
                          ),
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
                    AuraSpace.s12,
                    AuraSpace.s6,
                    AuraSpace.s12,
                    AuraSpace.s12,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Attach',
                        icon: const Icon(Icons.attach_file_rounded),
                        onPressed: _showAttachMenu,
                      ),
                      IconButton(
                        tooltip: _recording ? 'Stop recording' : 'Voice note',
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
                          // TAGS ARE AUTHORED THROUGH THE ONE CANONICAL
                          // COMPOSER. This surface could render migrated tag
                          // references and had no way to create one -- the
                          // convergence must not leave Conversation less capable
                          // than the DirectMessage lineage it replaces.
                          //
                          // Bounded scope, like every other bounded surface:
                          // the candidates are this conversation's own parties,
                          // which is also exactly what the server will accept.
                          child: GovernedTagAutocomplete(
                            controller: _composer,
                            focusNode: _composerFocus,
                            onTagSelected: _rememberSelectedTag,
                            mentionScope: MentionScope.bounded(
                              _eligibleTagSuggestions(c),
                            ),
                            // Bounded on purpose — the composer sits below a
                            // conversation that scrolls past it, so unbounded
                            // growth would swallow the thread. AuraBoundedEditor
                            // keeps the bound without trapping the page: the
                            // composer scrolls its own text while it can, and
                            // releases the wheel at its top and bottom.
                            child: AuraBoundedEditor(
                              builder: (context, scrollController, physics) =>
                                  TextField(
                                    scrollController: scrollController,
                                    scrollPhysics: physics,
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
                                            if (data != null &&
                                                data.isNotEmpty) {
                                              await _admit(
                                                await ContentIntake.resolveAndPrepareBytes(
                                                  path: IntakePath.paste,
                                                  bytes: Uint8List.fromList(
                                                    data,
                                                  ),
                                                  fileName: 'pasted-image.png',
                                                  declaredMimeType:
                                                      content.mimeType,
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                    decoration: InputDecoration(
                                      hintText: _recording
                                          ? 'Recording…'
                                          : 'Message…',
                                      filled: true,
                                      fillColor: AuraSurface.card,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(24),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: AuraSpace.s16,
                                            vertical: AuraSpace.s10,
                                          ),
                                    ),
                                  ),
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
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xE6111827),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'Drop to attach',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
class _ConversationLiveRibbon extends ConsumerWidget {
  const _ConversationLiveRibbon({required this.conversationId});

  final String conversationId;

  /// What this ribbon is honestly allowed to say.
  ///
  /// Falls back to the old wording only when the session carries no call — a
  /// meeting or a stage — where "in progress" describes a room and is true.
  static String _liveRibbonLabel(
    CallProductState? state, {
    required bool isVideo,
  }) {
    switch (state) {
      // WHICH END OF THE CALL YOU ARE ON CHANGES THE WORDS.
      //
      // These three were lumped together and every one of them read "Incoming
      // call" — so the person who PLACED the call was told they were receiving
      // one. Caught on screen during the local two-party run.
      case CallProductState.calling:
        return 'Calling…';
      case CallProductState.ringing:
        return 'Ringing…';
      case CallProductState.incoming:
        return isVideo ? 'Incoming video call' : 'Incoming call';
      case CallProductState.connecting:
        return 'Connecting…';
      case CallProductState.connected:
        return isVideo ? 'Video call in progress' : 'Call in progress';
      case CallProductState.ended:
      case null:
        return isVideo ? 'Video call in progress' : 'Call in progress';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final joined = ref.watch(
      realtimeControllerProvider.select((s) => s.isJoined),
    );
    if (joined) return const SizedBox.shrink();

    // ONE RIBBON. This one answers "is there a call I could join?" from a
    // server poll; the projection above answers "you are being invited right
    // now" from the canonical invitation. When both are true they describe the
    // same call, and the invitation is the more urgent and more precise of the
    // two — so it wins, and this defers rather than stacking a second strip
    // saying nearly the same thing.
    final invitation = conversationIncomingCall(
      ref.watch(incomingCallBridgeProvider),
      conversationId,
    );
    if (invitation != null) return const SizedBox.shrink();

    final session = ref
        .watch(conversationActiveLiveProvider(conversationId))
        .maybeWhen(data: (s) => s, orElse: () => null);
    if (session == null) return const SizedBox.shrink();

    final sessionId = (session['id'] ?? '').toString().trim();
    if (sessionId.isEmpty) return const SizedBox.shrink();
    final status = (session['status'] ?? '').toString().toUpperCase();
    if (status != 'ACTIVE') return const SizedBox.shrink();
    final isVideo = (session['kind'] ?? '').toString().toUpperCase() == 'VIDEO';

    // WHAT THE RIBBON MAY CLAIM COMES FROM THE CALL, NOT THE SESSION.
    //
    // "Call in progress" was shown for any ACTIVE session — which is true the
    // instant a room opens, before anyone's phone has rung and long before
    // anyone has answered. It told a person a conversation was under way when
    // the caller was still waiting for them to pick up.
    final call = CallState.fromJson(session['call']);
    final me = ref.watch(currentUserIdProvider);
    final productState = call?.productStateFor(me);

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
              _liveRibbonLabel(productState, isVideo: isVideo),
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
              NavigationAuthority.realtimeSessionJoinRoute(sessionId),
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
    required this.onReact,
    this.showSender = false,
    this.translation,
  });
  final ConversationMessage message;
  final bool mine;

  /// Name the author above this message. Decided by the timeline, which is
  /// the only place that can see the neighbouring messages.
  final bool showSender;
  final Conversation conversation;
  final void Function(String action) onAction;

  /// Toggling a reaction. Separate from `onAction` because it carries a type
  /// and because it is the one act reachable without opening the sheet.
  final void Function(String reactionType) onReact;
  final String? translation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (message.isSystem) {
      // A PARTICIPATION EVENT WITHOUT ITS ACTOR IS NOT AN EVENT.
      //
      // Seen on a physical Pixel, 2026-08-24: a group correspondence read
      // "left the conversation", centred and alone, with no indication of who
      // had left. In a conversation with several parties that is unreadable —
      // and leaving is precisely the moment a reader needs to know WHO, since
      // it changes who can still see what is said next.
      //
      // The actor was always on the message. It simply was not asked for.
      final who = mine
          ? 'You'
          : _conversationSenderName(conversation, message.senderUserId);
      final label = switch (message.systemKind) {
        'JOINED' => '$who joined the conversation',
        'LEFT' => '$who left the conversation',
        'RENAMED' => '$who named the conversation',
        _ => message.body,
      };
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AuraSpace.s6),
        child: Center(
          child: Text(
            label,
            style: AuraText.micro.copyWith(color: AuraSurface.faint),
          ),
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

    // Dual attribution already names the visible speaker, so a second name
    // above it would state the same fact twice.
    final senderName = showSender && institutionName == null
        ? _conversationSenderName(conversation, message.senderUserId)
        : null;

    void openActions() => showMessageActionSheet(
          context,
          message: message,
          mine: mine,
          onAction: onAction,
          onReact: onReact,
        );

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        // The opener sits INBOARD — left of my own messages, right of
        // everyone else's — so it never crowds the screen edge and does not
        // move as bubbles change width.
        textDirection: mine ? TextDirection.rtl : TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Desktop only. A phone should not carry a control beside every line
          // it has ever received; there the long press is the affordance, and
          // the body gives it up so that it can arrive.
          if (_messageActionsNeedAButton)
            _MessageActionOpener(onPressed: openActions),
          Flexible(
            child: GestureDetector(
              // Both gestures stay: where they work they are the faster way
              // in. What changed is that neither is the ONLY way in any more.
              onLongPress: openActions,
              onSecondaryTap: openActions,
              child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s14,
            vertical: AuraSpace.s10,
          ),
          constraints: const BoxConstraints(maxWidth: 520),
          decoration: BoxDecoration(
            color: mine ? AuraSurface.accentSoft : AuraSurface.card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (senderName != null) ...[
                Text(
                  senderName,
                  style: AuraText.micro.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AuraSurface.accentText,
                  ),
                ),
                const SizedBox(height: 2),
              ],
              if (institutionName != null) ...[
                Text(
                  institutionName,
                  style: AuraText.micro.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AuraSurface.accentText,
                  ),
                ),
                const SizedBox(height: 2),
              ],
              if (message.replyTo != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AuraSpace.s10,
                    vertical: AuraSpace.s6,
                  ),
                  decoration: const BoxDecoration(
                    color: AuraSurface.subtle,
                    border: Border(
                      left: BorderSide(color: AuraSurface.accentText, width: 3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _conversationSenderName(
                          conversation,
                          message.replyTo!.senderUserId,
                        ),
                        style: AuraText.micro.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AuraSurface.accentText,
                        ),
                      ),
                      Text(
                        message.replyTo!.deleted
                            ? 'Message removed'
                            : message.replyTo!.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AuraText.micro.copyWith(
                          color: AuraSurface.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AuraSpace.s6),
              ],
              // FORWARDED — attribution travels, the source conversation does
              // not. The recipient learns who said it, never where.
              if (message.isForwarded) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.forward_rounded,
                      size: 11,
                      color: AuraSurface.faint,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'Forwarded from '
                      '${_conversationSenderName(conversation, message.forwardedFromSenderUserId!)}',
                      style: AuraText.micro.copyWith(color: AuraSurface.faint),
                    ),
                  ],
                ),
                const SizedBox(height: AuraSpace.s4),
              ],
              // RETRACTED — a truthful tombstone. The row survives so replies
              // to it stay valid, and the content is not shown, not even as
              // greyed-out text: the author took it back.
              if (message.deleted)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.block_rounded,
                      size: 13,
                      color: AuraSurface.faint,
                    ),
                    const SizedBox(width: AuraSpace.s6),
                    Text(
                      mine
                          ? 'You withdrew this message'
                          : 'This message was withdrawn',
                      style: AuraText.small.copyWith(
                        color: AuraSurface.faint,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                )
              else ...[
                for (final m in message.media) ...[
                  _ConversationAttachment(media: m),
                  const SizedBox(height: AuraSpace.s6),
                ],
                if (message.body.trim() != '…' || message.media.isEmpty)
                  // SELECTION AND ACTIONS BOTH WANT THE LONG PRESS.
                  //
                  // On a phone the actions win. They are the whole interaction
                  // surface of a message, and dragging to select a few words
                  // inside one bubble is a rare want that the sheet's own
                  // "Copy text" already answers.
                  //
                  // On desktop nothing is contested: the visible opener
                  // carries the actions, so the text stays selectable, which
                  // is what somebody with a mouse and a keyboard wants.
                  _messageActionsNeedAButton
                      ? SelectableText.rich(_conversationRichBody(
                          context, message.body, conversation))
                      : Text.rich(_conversationRichBody(
                          context, message.body, conversation)),
              ],
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
                Text(
                  translation!,
                  style: AuraText.micro.copyWith(
                    color: AuraSurface.muted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              // EDITED — said plainly, and only where it is true. A silently
              // rewritten message is a record nobody can rely on. Prior
              // versions are retained by the authority; showing them is a
              // separate product decision and would clutter ordinary reading.
              if (message.wasEdited && !message.deleted) ...[
                const SizedBox(height: 2),
                Text(
                  'Edited',
                  style: AuraText.micro.copyWith(color: AuraSurface.faint),
                ),
              ],
              // REACTIONS as actually recorded, with this viewer's own marked.
              // Tapping one toggles it through the same authority the sheet
              // uses, so a tap here and a tap there cannot disagree.
              MessageReactionBar(message: message, onToggle: onReact),
            ],
          ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Attachment renderer: resolves the visibility-checked delivery URL from
/// the canonical Media authority and renders by kind — inline image,
/// playable voice note, tap-to-play video — with an honest chip fallback.
/// WHETHER THIS PLATFORM NEEDS A VISIBLE WAY INTO A MESSAGE'S ACTIONS.
///
/// ── THE DEFECT BEHIND THIS ────────────────────────────────────────────────
///
/// Actions had only a long press and a right click. On a phone the long press
/// never arrived: the message body is `SelectableText`, and Flutter's text
/// selection claims that gesture for itself — so the operating system's
/// Copy / Share / Select all bar came up instead of Aura's sheet.
///
/// Everything behind it was unreachable on Android: Reply, Forward, Edit, Copy
/// text, Translate, Report, Retract for everyone, Remove for me, and all five
/// reactions. The entire interaction surface of a message, on the platform most
/// people will use it from. Desktop and web never showed it, because a right
/// click is not a gesture selection wants. Observed on a physical Pixel 9a,
/// 2026-09-05.
///
/// ── THE SPLIT, WHICH IS NOT A COMPROMISE ──────────────────────────────────
///
/// Founder ruling, same day: three dots on desktop, not on Android or iOS.
///
/// A phone already has a gesture meaning "do something with this", and should
/// not repeat a control beside every line ever received. So on touch the body
/// gives the long press back by not being selectable, and "Copy text" in the
/// sheet covers what that costs.
///
/// A desktop has no long press worth the name, and a right click is not
/// discoverable — nobody right-clicks a message to find out whether they may.
/// So there the actions get a small visible control, and because the control
/// carries them, the text stays selectable.
bool get _messageActionsNeedAButton {
  if (kIsWeb) return true;
  try {
    return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  } catch (_) {
    return false;
  }
}

/// THE OPENER. Deliberately small and quiet: it sits beside every message, so
/// anything louder would read as decoration on a busy thread.
class _MessageActionOpener extends StatelessWidget {
  const _MessageActionOpener({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(14),
      child: const Padding(
        padding: EdgeInsets.all(4),
        child: Icon(
          Icons.more_vert_rounded,
          size: 16,
          color: AuraSurface.faint,
        ),
      ),
    );
  }
}

class _ConversationAttachment extends ConsumerWidget {
  const _ConversationAttachment({required this.media});
  final MessageMediaRef media;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TR MOUNTS ONCE, AROUND THE WHOLE ATTACHMENT.
    //
    // It was previously added inside the VIDEO branch only, so an image
    // attachment — the kind that actually carries AI provenance on this
    // platform — showed nothing. Wrapping the renderer instead of one branch
    // means every kind gets it, including the ones added later.
    return _withTrace(context, _buildAttachment(context, ref));
  }

  Widget _withTrace(BuildContext context, Widget child) {
    if (media.trace.isEmpty) return child;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        child,
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: AuraTraceMark(
            trace: media.trace,
            compact: true,
            onSurface: true,
            onOpen: () => showAuraTrace(context, trace: media.trace),
          ),
        ),
      ],
    );
  }

  Widget _buildAttachment(BuildContext context, WidgetRef ref) {
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
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
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
                    trace: media.trace,
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
          // MIGRATED TO THE STORED-MEDIA AUTHORITY.
          //
          // Conversation had the product's only working inline video, in a
          // PRIVATE widget no other surface could reach — which is precisely
          // why a video shared here played while the same video in a post
          // rendered as a broken image. Conversation is a proving surface for
          // rich content, not its owner, so the capability moves to the shared
          // authority and Conversation becomes a consumer of it.
          //
          // Behaviour is preserved: a message CONTAINS its media, so it still
          // plays in place rather than pushing a fullscreen surface.
          // TR sits beside the message media rather than over it: a message
          // bubble is small, and an overlay would compete with the play
          // affordance a voice note and a video both need.
          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                AuraStoredMedia(
                  media: StoredMedia.fromParts(
                    mediaId: media.mediaId,
                    mimeType: media.mimeType,
                    declaredKind: media.kind,
                    sourceUrl: url,
                    fileName: media.fileName,
                    durationMs: media.durationMs,
                    sizeBytes: media.fileSizeBytes,
                  ),
                  context: StoredMediaContext.message,
                  borderRadius: BorderRadius.circular(12),
                  onOpenViewer: () => showAuraMediaViewer(
                    context,
                    items: [
                      AuraViewerItem(
                        originalUrl: url,
                        mediaId: media.mediaId,
                        isPublic: false,
                        isVideo: true,
                        caption: media.fileName,
                        trace: media.trace,
                        downloadContext: 'conversation-attachment',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
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

// The private `_MediaPlayback` fork that used to live here is RETIRED.
// Conversation's inline video now goes through the canonical stored-media
// authority, which every other surface also consumes — see §20's convergence
// target. Voice and audio already had their canonical player.

final _deliveryUrlProvider = FutureProvider.family<String?, String>((
  ref,
  mediaId,
) async {
  return ref.watch(conversationsRepositoryProvider).mediaDeliveryUrl(mediaId);
});

/// Message action sheet: the shared per-message capability surface.
// The old four-action sheet is retired. The full set — reactions, reply,
// forward, edit, retract, remove-for-me, copy, translate, report — lives in
// message_interactions.dart, so touch and pointer reach one implementation.

/// Does this incoming message need its author named above it?
///
/// [previous] is the message BEFORE this one in time (the timeline renders
/// reversed, so it is the next index, not the previous one).
///
/// Named here rather than inside the bubble because it is a fact about the
/// timeline, not about one message, and because the answer is the difference
/// between a readable group correspondence and a column of anonymous bubbles.
bool shouldNameSender({
  required Conversation conversation,
  required ConversationMessage message,
  required ConversationMessage? previous,
  required String? myUserId,
}) {
  // A direct correspondence has exactly one other side and its header already
  // names them; repeating it on every bubble says nothing.
  if (conversation.isDirect) return false;
  // Your own messages are attributed by their side of the timeline.
  if (myUserId != null && message.senderUserId == myUserId) return false;
  if (message.isSystem) return false;
  // A run from one person is attributed by its first message. A system event
  // in between breaks the run, because the reader's eye has left the sender.
  if (previous == null || previous.isSystem) return true;
  return previous.senderUserId != message.senderUserId;
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
  BuildContext context,
  String body,
  Conversation conversation,
) {
  final base = AuraText.body.copyWith(color: AuraSurface.ink);
  final spans = <InlineSpan>[];
  final mentionNames =
      conversation.parties
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
        spans.add(
          TextSpan(
            text: '@$hit',
            style: base.copyWith(
              fontWeight: FontWeight.w800,
              color: AuraSurface.accentText,
            ),
          ),
        );
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
    spans.add(
      TextSpan(
        text: url,
        style: base.copyWith(
          color: AuraSurface.accentText,
          decoration: TextDecoration.underline,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () => _openConversationUrl(context, url),
      ),
    );
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
    GoRouter.of(context).push(uri.path + (uri.hasQuery ? '?${uri.query}' : ''));
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
                    Text(
                      preview.siteName!,
                      style: AuraText.micro.copyWith(color: AuraSurface.faint),
                    ),
                  if (preview.title != null)
                    Text(
                      preview.title!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AuraText.micro.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AuraSurface.ink,
                      ),
                    ),
                  if (preview.description != null)
                    Text(
                      preview.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AuraText.micro.copyWith(color: AuraSurface.muted),
                    ),
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
                      Text(
                        'Aura \u00b7 $label',
                        style: AuraText.micro.copyWith(
                          color: AuraSurface.faint,
                        ),
                      ),
                    ],
                  ),
                  if (reference.title != null) ...[
                    const SizedBox(height: AuraSpace.s4),
                    Text(
                      reference.title!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AuraText.micro.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AuraSurface.ink,
                      ),
                    ),
                  ],
                  if (reference.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      reference.subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AuraText.micro.copyWith(color: AuraSurface.muted),
                    ),
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
          style: AuraText.body.copyWith(
            fontWeight: FontWeight.w800,
            color: AuraSurface.ink,
          ),
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
