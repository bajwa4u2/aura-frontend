import 'dart:async';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';

import '../../../../core/attachments/aura_media_upload.dart';
import '../../../../core/net/dio_provider.dart';
import '../../../../core/ui/aura_card.dart';
import '../../../../core/ui/aura_platform_components.dart';
import '../../../../core/ui/aura_radius.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_surface.dart';
import '../../../../core/ui/aura_text.dart';
import '../../data/messages_repository.dart';
import 'thread_utils.dart';

// ─────────────────────────────────────────────────────────────────────────────
// COMPOSER BAR
// ─────────────────────────────────────────────────────────────────────────────

class ThreadComposerBar extends ConsumerStatefulWidget {
  const ThreadComposerBar({
    super.key,
    required this.threadId,
    required this.onSent,
    this.currentUserId = '',
    this.onOptimisticSend,
    this.onSendFailed,
  });

  final String threadId;
  final VoidCallback onSent;
  final String currentUserId;

  /// Called immediately when the user taps Send so the thread can render an
  /// optimistic message before the network round-trip. The same
  /// [clientMessageId] is sent to the server (idempotency key) and is the
  /// stable handle the screen should use to reconcile or retry.
  final void Function({
    required String clientMessageId,
    required String body,
    required String senderId,
    required String senderName,
    required String senderHandle,
    required String senderAvatarUrl,
    required List<Map<String, dynamic>> attachments,
  })? onOptimisticSend;

  /// Called when the send round-trip fails so the screen can surface a retry
  /// affordance on the corresponding optimistic message.
  final void Function({
    required String clientMessageId,
    required Object error,
  })? onSendFailed;

  @override
  ConsumerState<ThreadComposerBar> createState() => _ThreadComposerBarState();
}

class _ThreadComposerBarState extends ConsumerState<ThreadComposerBar> {
  final _controller = TextEditingController();
  final _audioRecorder = AudioRecorder();
  final _picker = ImagePicker();

  final List<_DraftAttachment> _attachments = [];
  final Set<String> _dismissedSuggestionIds = <String>{};
  final Set<String> _applyingSuggestionIds = <String>{};

  bool _sending = false;
  bool _recordingAudio = false;
  DateTime? _recordingStartedAt;
  Timer? _recordingTicker;
  bool _assistBusy = false;
  String? _assistError;
  String? _assistSessionId;
  String? _assistSnapshot;
  List<Map<String, dynamic>> _suggestions = const [];

  bool _translationBusy = false;
  String? _translationError;
  String? _translationPreview;
  String? _translationSnapshot;
  String _translationTargetLanguage = 'ur';

  bool get _isMobileCapturePlatform {
    return !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
  }

  bool get _supportsCameraCapture => _isMobileCapturePlatform;
  bool get _supportsAudioRecording => _isMobileCapturePlatform;

  @override
  void dispose() {
    _recordingTicker?.cancel();
    _controller.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  bool get _canSend {
    if (_sending) return false;
    if (_recordingAudio) return false;
    if (_attachments.any((a) => a.uploading)) return false;
    if (_attachments.any((a) => a.error != null)) return false;
    return _controller.text.trim().isNotEmpty || _attachments.isNotEmpty;
  }

  bool get _hasText => _controller.text.trim().isNotEmpty;

  List<Map<String, dynamic>> get _visibleSuggestions {
    final out = <Map<String, dynamic>>[];
    for (final suggestion in _suggestions) {
      final id = firstNonEmpty(suggestion, const ['id', 'findingId']);
      if (id.isNotEmpty && _dismissedSuggestionIds.contains(id)) continue;
      out.add(suggestion);
      if (out.length >= 2) break;
    }
    return out;
  }

  Future<void> _pickImageFromGallery() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    await _addAttachment(file, kind: ThreadAttachmentKind.image);
  }

  Future<void> _pickImageFromCamera() async {
    if (!_supportsCameraCapture) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Camera capture is not available here. Choose a file instead.',
          ),
        ),
      );
      await _pickImageFromGallery();
      return;
    }
    final file = await _picker.pickImage(source: ImageSource.camera);
    if (file == null) return;
    await _addAttachment(
      file,
      kind: ThreadAttachmentKind.image,
      source: _AttachmentSource.camera,
    );
  }

  Future<void> _pickVideoFromGallery() async {
    final file = await _picker.pickVideo(source: ImageSource.gallery);
    if (file == null) return;
    await _addAttachment(file, kind: ThreadAttachmentKind.video);
  }

  Future<void> _pickVideoFromCamera() async {
    if (!_supportsCameraCapture) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Video capture is not available here. Choose a file instead.',
          ),
        ),
      );
      await _pickVideoFromGallery();
      return;
    }
    final file = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(seconds: 60),
    );
    if (file == null) return;
    await _addAttachment(
      file,
      kind: ThreadAttachmentKind.video,
      source: _AttachmentSource.camera,
    );
  }

  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.audio,
    );
    if (result == null || result.files.isEmpty) return;

    final picked = result.files.single;
    if (picked.bytes == null || picked.bytes!.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read selected audio file.')),
      );
      return;
    }

    final file = XFile.fromData(
      picked.bytes!,
      name: picked.name,
      mimeType: _inferMime(picked.name),
    );

    await _addAttachment(
      file,
      kind: ThreadAttachmentKind.audio,
      source: _AttachmentSource.upload,
    );
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return;

    final picked = result.files.single;
    if (picked.bytes == null || picked.bytes!.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read selected file.')),
      );
      return;
    }

    final mime = _inferMime(picked.name);
    final file = XFile.fromData(
      picked.bytes!,
      name: picked.name,
      mimeType: mime,
    );

    await _addAttachment(
      file,
      kind: _kindFromMime(mime),
      source: _AttachmentSource.upload,
    );
  }

  ThreadAttachmentKind _kindFromMime(String mime) {
    final lower = mime.toLowerCase();
    if (lower.startsWith('image/')) return ThreadAttachmentKind.image;
    if (lower.startsWith('video/')) return ThreadAttachmentKind.video;
    if (lower.startsWith('audio/')) return ThreadAttachmentKind.audio;
    return ThreadAttachmentKind.document;
  }

  Future<void> _toggleAudioRecording() async {
    if (_sending) return;

    if (_recordingAudio) {
      await _finishAudioRecording(keep: true);
      return;
    }

    if (!_supportsAudioRecording) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Audio recording is not available here. Upload an audio file instead.',
          ),
        ),
      );
      return;
    }

    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission is required.')),
      );
      return;
    }

    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: 'aura_msg_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );

    if (!mounted) return;
    _recordingTicker?.cancel();
    _recordingStartedAt = DateTime.now();
    _recordingTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_recordingAudio || _recordingStartedAt == null) return;
      setState(() {});
    });
    setState(() => _recordingAudio = true);
  }

  Future<void> _cancelAudioRecording() async {
    await _finishAudioRecording(keep: false);
  }

  Future<void> _finishAudioRecording({required bool keep}) async {
    if (!_recordingAudio) return;

    final startedAt = _recordingStartedAt;
    final path = await _audioRecorder.stop();
    if (!mounted) return;

    _recordingTicker?.cancel();
    _recordingTicker = null;
    _recordingStartedAt = null;

    setState(() => _recordingAudio = false);

    if (!keep) return;

    if (path == null || path.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save audio recording.')),
      );
      return;
    }

    final file = XFile(path, mimeType: 'audio/aac');
    final elapsed = startedAt == null
        ? null
        : DateTime.now().difference(startedAt);
    await _addAttachment(
      file,
      kind: ThreadAttachmentKind.audio,
      source: _AttachmentSource.recording,
      duration: elapsed,
    );
  }

  Future<void> _addAttachment(
    XFile file, {
    required ThreadAttachmentKind kind,
    _AttachmentSource source = _AttachmentSource.gallery,
    Duration? duration,
  }) async {
    final bytes = await file.readAsBytes();
    final mimeType = file.mimeType ?? _inferMime(file.name);

    // B3: client-side mime allow-list. Block unsupported types BEFORE the
    // upload (and before the optimistic preview tile is shown), so the user
    // is not surprised by a silent send-without-attachment when the server
    // rejects the presign.
    final mimeError = _validateMimeForKind(mimeType, kind);
    if (mimeError != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mimeError)),
      );
      return;
    }

    int? width;
    int? height;

    if (kind == ThreadAttachmentKind.image) {
      try {
        final size = await _decodeImageSize(bytes);
        width = size?['width'];
        height = size?['height'];
      } catch (_) {}
    }

    final attachment = _DraftAttachment(
      localId: '${DateTime.now().microsecondsSinceEpoch}_${file.name}',
      file: file,
      bytes: bytes,
      kind: kind,
      source: source,
      width: width,
      height: height,
      mimeType: mimeType,
      sizeBytes: bytes.length,
      durationSec: duration?.inSeconds,
    );
    attachment.uploading = true;

    setState(() {
      _attachments.add(attachment);
    });

    try {
      await _uploadAttachment(attachment);
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() {
        attachment.uploading = false;
        attachment.error = _toAttachmentError(e);
      });
    }
  }

  /// B3: client-side mime allow-list per attachment kind. Mirrors the backend
  /// check in `media.service.ts allowedMime()` so unsupported files are
  /// rejected before the upload starts. Returns null if [mimeType] is allowed,
  /// or a user-facing error message otherwise.
  String? _validateMimeForKind(String mimeType, ThreadAttachmentKind kind) {
    final mt = mimeType.trim().toLowerCase();
    if (mt.isEmpty) {
      return 'This file has no recognizable type. Choose a different file.';
    }
    // Server-side allow-list snapshot. Keep in sync with media.service.ts.
    const allowedImage = {
      'image/png',
      'image/jpeg',
      'image/webp',
      'image/gif',
    };
    const allowedVideo = {
      'video/mp4',
      'video/quicktime',
      'video/webm',
    };
    const allowedAudio = {
      'audio/mpeg',
      'audio/mp4',
      'audio/aac',
      'audio/wav',
      'audio/ogg',
      'audio/webm',
    };
    const allowedDocument = {
      'application/pdf',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/vnd.ms-excel',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'application/vnd.ms-powerpoint',
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'text/plain',
      'text/csv',
      'application/rtf',
      'application/zip',
    };

    bool ok;
    String label;
    switch (kind) {
      case ThreadAttachmentKind.image:
        ok = allowedImage.contains(mt);
        label = 'image';
        break;
      case ThreadAttachmentKind.video:
        ok = allowedVideo.contains(mt);
        label = 'video';
        break;
      case ThreadAttachmentKind.audio:
        ok = allowedAudio.contains(mt);
        label = 'audio';
        break;
      case ThreadAttachmentKind.document:
        ok = allowedDocument.contains(mt) ||
            allowedImage.contains(mt) ||
            allowedVideo.contains(mt) ||
            allowedAudio.contains(mt);
        label = 'file';
        break;
    }
    if (ok) return null;
    return 'This $label type is not supported ($mt). Choose a different file.';
  }

  Future<void> _uploadAttachment(_DraftAttachment attachment) async {
    final result = await uploadAuraMedia(
      dio: ref.read(dioProvider),
      bytes: attachment.bytes,
      fileName: attachment.file.name,
      mimeType: attachment.mimeType,
      kind: _mediaKindValue(attachment.kind),
      source: _mediaSourceValue(attachment.source),
      width: attachment.width,
      height: attachment.height,
      duration: attachment.kind == ThreadAttachmentKind.audio ||
              attachment.kind == ThreadAttachmentKind.video
          ? attachment.durationSec
          : null,
      metadataPatch: <String, dynamic>{
        if (attachment.width != null) 'width': attachment.width,
        if (attachment.height != null) 'height': attachment.height,
        'editDisclosure': false,
      },
      onProgress: (sent, total) {
        if (!mounted || total <= 0) return;
        setState(() {
          attachment.uploadProgress = sent / total;
        });
      },
    );

    attachment.mediaId = result.mediaId;
    attachment.storageKey = result.storageKey;
    attachment.url = result.url.isNotEmpty ? result.url : null;
    attachment.thumbUrl = result.thumbUrl.isNotEmpty ? result.thumbUrl : null;
    attachment.uploadProgress = 1.0;
    attachment.uploading = false;
    attachment.error = null;
  }

  Future<void> _runAssist() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _assistBusy) return;

    setState(() {
      _assistBusy = true;
      _assistError = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post(
        '/composition/review',
        data: {'text': text, 'surface': 'dm'},
      );

      final root = unwrapDataMap(res.data);
      final findings = extractFindings(root);
      final sessionId = pickDeepString(root, const [
        ['sessionId'],
        ['review', 'sessionId'],
        ['data', 'sessionId'],
        ['session', 'id'],
      ]);

      if (!mounted) return;
      setState(() {
        _assistBusy = false;
        _assistSessionId = sessionId;
        _assistSnapshot = text;
        _suggestions = findings;
        _dismissedSuggestionIds.clear();
        _assistError = findings.isEmpty ? 'Nothing urgent to revise.' : null;
      });
    } catch (e) {
      if (!context.mounted) return;
      setState(() {
        _assistBusy = false;
        _assistError = 'Could not review this draft right now.';
      });
    }
  }

  Future<void> _applySuggestion(Map<String, dynamic> suggestion) async {
    final suggestionId = firstNonEmpty(suggestion, const ['id', 'findingId']);
    final sessionId = (_assistSessionId ?? '').trim();
    if (suggestionId.isEmpty || sessionId.isEmpty) return;

    setState(() {
      _applyingSuggestionIds.add(suggestionId);
      _assistError = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final currentText = _controller.text;
      final res = await dio.post(
        '/composition/apply',
        data: {
          'sessionId': sessionId,
          'findingId': suggestionId,
          'currentText': currentText,
        },
      );

      final root = unwrapDataMap(res.data);
      final nextText = pickDeepString(root, const [
        ['text'],
        ['updatedText'],
        ['data', 'text'],
        ['data', 'updatedText'],
        ['result', 'text'],
      ], fallback: currentText);

      final selection = TextSelection.collapsed(offset: nextText.length);
      _controller.value = TextEditingValue(
        text: nextText,
        selection: selection,
        composing: TextRange.empty,
      );

      final findings = extractFindings(root);

      if (!mounted) return;
      setState(() {
        _assistSnapshot = nextText;
        _suggestions = findings.isNotEmpty
            ? findings
            : _suggestions.where((item) {
                final id = firstNonEmpty(item, const ['id', 'findingId']);
                return id != suggestionId;
              }).toList();
        _dismissedSuggestionIds.remove(suggestionId);
      });
    } catch (e) {
      if (!context.mounted) return;
      setState(() {
        _assistError = 'Could not apply that suggestion.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _applyingSuggestionIds.remove(suggestionId);
        });
      }
    }
  }

  Future<void> _translateDraft() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _translationBusy) return;

    setState(() {
      _translationBusy = true;
      _translationError = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post(
        '/composition/translate',
        data: {'text': text, 'targetLanguage': _translationTargetLanguage},
      );

      final root = unwrapDataMap(res.data);
      final translatedText = pickDeepString(root, const [
        ['translatedText'],
        ['translation', 'text'],
        ['data', 'translatedText'],
        ['data', 'text'],
      ]);

      if (!mounted) return;
      setState(() {
        _translationBusy = false;
        _translationSnapshot = text;
        _translationPreview = translatedText;
        if (translatedText.isEmpty) {
          _translationError = 'Translation was empty.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _translationBusy = false;
        _translationError = 'Could not translate this draft right now.';
      });
    }
  }

  void _applyTranslation() {
    final translatedText = (_translationPreview ?? '').trim();
    if (translatedText.isEmpty) return;

    _controller.value = TextEditingValue(
      text: translatedText,
      selection: TextSelection.collapsed(offset: translatedText.length),
      composing: TextRange.empty,
    );

    setState(() {
      _translationPreview = null;
      _translationError = null;
      _assistSnapshot = null;
      _suggestions = const [];
      _dismissedSuggestionIds.clear();
    });
  }

  void _restoreBeforeTranslation() {
    final snapshot = (_translationSnapshot ?? '').trim();
    if (snapshot.isEmpty) return;

    _controller.value = TextEditingValue(
      text: snapshot,
      selection: TextSelection.collapsed(offset: snapshot.length),
      composing: TextRange.empty,
    );

    setState(() {
      _translationPreview = null;
      _translationError = null;
    });
  }

  Future<void> _submit() async {
    // B1: defensive empty-send guard. _canSend already keeps the Send button
    // disabled when there's nothing to send, but we guard explicitly here too
    // so any future callsite (e.g. an enter-key handler) cannot bypass the
    // check and produce a 400 round-trip.
    if (!_canSend) return;

    final body = _controller.text.trim();
    final readyAttachments = _attachments
        .where(
          (a) => !a.uploading && a.error == null && a.storageKey.isNotEmpty,
        )
        .toList();

    if (body.isEmpty && readyAttachments.isEmpty) {
      return;
    }

    final attachmentsPayload =
        readyAttachments.map((a) => a.toMessagePayload()).toList();

    // B4: idempotency key generated client-side and propagated through both
    // the optimistic message and the network payload so a retry-after-failure
    // round-trip dedupes server-side. Format: cmsg_<microsTime>_<counter>.
    final clientMessageId = _newClientMessageId();

    // Fire optimistic message immediately before network call.
    widget.onOptimisticSend?.call(
      clientMessageId: clientMessageId,
      body: body,
      senderId: widget.currentUserId,
      senderName: '',
      senderHandle: '',
      senderAvatarUrl: '',
      attachments: readyAttachments
          .map((a) => {
                'storageKey': a.storageKey,
                'fileName': a.file.name,
                'mimeType': a.mimeType,
                'sizeBytes': a.sizeBytes,
                'url': a.url ?? '',
                'thumbUrl': a.thumbUrl ?? '',
                if (a.width != null) 'width': a.width,
                if (a.height != null) 'height': a.height,
                if (a.durationSec != null) 'durationSec': a.durationSec,
              })
          .toList(),
    );

    _controller.clear();
    setState(() {
      _attachments.clear();
      _sending = true;
      _suggestions = const [];
      _assistSnapshot = null;
      _assistError = null;
      _assistSessionId = null;
      _dismissedSuggestionIds.clear();
      _translationPreview = null;
      _translationSnapshot = null;
      _translationError = null;
    });

    try {
      await ref
          .read(messagesRepositoryProvider)
          .sendMessage(
            threadId: widget.threadId,
            body: body,
            attachments: attachmentsPayload,
            clientMessageId: clientMessageId,
          );

      if (!mounted) return;
      widget.onSent();
    } catch (e) {
      if (!mounted) return;
      // B2: notify the screen so it can mark the matching pending message as
      // failed and offer Retry/Dismiss. The screen retains the original body
      // and attachments under [clientMessageId] for retry.
      widget.onSendFailed?.call(clientMessageId: clientMessageId, error: e);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not send message: $e')));
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  static int _clientMessageIdCounter = 0;

  String _newClientMessageId() {
    final n = ++_clientMessageIdCounter;
    return 'cmsg_${DateTime.now().microsecondsSinceEpoch}_$n';
  }

  void _removeAttachment(_DraftAttachment attachment) {
    if (_sending) return;
    setState(() {
      _attachments.removeWhere((a) => a.localId == attachment.localId);
    });
  }

  Future<void> _retryAttachment(_DraftAttachment attachment) async {
    if (_sending || attachment.uploading) return;
    setState(() {
      attachment.uploading = true;
      attachment.error = null;
    });

    try {
      await _uploadAttachment(attachment);
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() {
        attachment.uploading = false;
        attachment.error = _toAttachmentError(e);
      });
    }
  }

  Future<void> _showAttachmentSheet() async {
    if (_sending) return;

    final width = MediaQuery.sizeOf(context).width;
    final desktopSheet = width >= 760;

    Widget buildSheet(BuildContext sheetContext) {
      Future<void> openAction(Future<void> Function() action) async {
        Navigator.of(sheetContext).pop();
        await Future<void>.microtask(action);
      }

      final actions = _attachmentActions(sheetContext, onTap: openAction);
      final body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AuraSurface.accentSoft,
                  borderRadius: BorderRadius.circular(AuraRadius.r12),
                  border: Border.all(color: AuraSurface.accent.withValues(alpha: 0.2)),
                ),
                child: const Icon(
                  Icons.attach_file_rounded,
                  size: 18,
                  color: AuraSurface.accentText,
                ),
              ),
              const SizedBox(width: AuraSpace.s10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add attachment',
                      style: AuraText.body.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Choose how you want to add media or files.',
                      style: AuraText.small.copyWith(color: AuraSurface.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Close',
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s12),
          ...actions,
        ],
      );

      if (desktopSheet) {
        return Dialog(
          alignment: Alignment.bottomCenter,
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: SizedBox(
            width: 460,
            child: AuraCard(
              padding: const EdgeInsets.all(16),
              child: body,
            ),
          ),
        );
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          child: AuraCard(
            padding: const EdgeInsets.all(12),
            child: body,
          ),
        ),
      );
    }

    if (desktopSheet) {
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black54,
        builder: buildSheet,
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: buildSheet,
    );
  }

  List<Widget> _attachmentActions(
    BuildContext context, {
    required Future<void> Function(Future<void> Function() action) onTap,
  }) {
    final children = <Widget>[];

    if (_supportsCameraCapture) {
      children.addAll([
        _AttachmentActionTile(
          icon: Icons.photo_camera_outlined,
          title: 'Take photo',
          subtitle: 'Open the camera',
          onTap: () => onTap(_pickImageFromCamera),
        ),
        _AttachmentActionTile(
          icon: Icons.image_outlined,
          title: 'Choose photo',
          subtitle: 'Pick from your library',
          onTap: () => onTap(_pickImageFromGallery),
        ),
        _AttachmentActionTile(
          icon: Icons.videocam_outlined,
          title: 'Record video',
          subtitle: 'Capture a short video',
          onTap: () => onTap(_pickVideoFromCamera),
        ),
        _AttachmentActionTile(
          icon: Icons.video_library_outlined,
          title: 'Choose video',
          subtitle: 'Pick a video file',
          onTap: () => onTap(_pickVideoFromGallery),
        ),
      ]);
    } else {
      children.addAll([
        _AttachmentActionTile(
          icon: Icons.image_outlined,
          title: 'Choose photo',
          subtitle: kIsWeb
              ? 'Upload an image from this browser'
              : 'Pick an image from this device',
          onTap: () => onTap(_pickImageFromGallery),
        ),
        _AttachmentActionTile(
          icon: Icons.videocam_outlined,
          title: 'Choose video',
          subtitle: kIsWeb
              ? 'Upload a video from this browser'
              : 'Pick a video from this device',
          onTap: () => onTap(_pickVideoFromGallery),
        ),
      ]);
    }

    if (_supportsAudioRecording) {
      children.add(
        _AttachmentActionTile(
          icon: _recordingAudio
              ? Icons.stop_circle_outlined
              : Icons.mic_none_rounded,
          title: _recordingAudio ? 'Stop audio recording' : 'Record audio',
          subtitle: _recordingAudio
              ? 'Finishing current recording'
              : 'Capture a voice note',
          onTap: () => onTap(_toggleAudioRecording),
        ),
      );
    } else {
      children.add(
        const _AttachmentActionTile(
          icon: Icons.mic_none_rounded,
          title: 'Audio recording unavailable',
          subtitle: 'This device or browser does not support recording.',
          enabled: false,
          onTap: null,
        ),
      );
    }

    children.add(
      _AttachmentActionTile(
        icon: Icons.audio_file_outlined,
        title: 'Upload audio',
        subtitle: 'Attach an audio file',
        onTap: () => onTap(_pickAudioFile),
      ),
    );

    children.add(
      _AttachmentActionTile(
        icon: Icons.attach_file_rounded,
        title: 'Upload document',
        subtitle: 'Attach a PDF, Office file, or any document',
        onTap: () => onTap(_pickDocument),
      ),
    );

    return children;
  }

  Future<void> _pickComposerLanguage() async {
    if (_translationBusy) return;
    final current = _translationTargetLanguage.trim().toLowerCase();

    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Translate to',
                  style: AuraText.body.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: AuraSpace.s12),
                Wrap(
                  spacing: AuraSpace.s10,
                  runSpacing: AuraSpace.s10,
                  children: kTranslationLanguageLabels.entries.map((entry) {
                    final active = entry.key == current;
                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: InkWell(
                        onTap: () => Navigator.of(ctx).pop(entry.key),
                        borderRadius: BorderRadius.circular(AuraRadius.pill),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AuraSpace.s12,
                            vertical: AuraSpace.s8,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? AuraSurface.overlay
                                : Colors.transparent,
                            border: Border.all(color: AuraSurface.divider),
                            borderRadius:
                                BorderRadius.circular(AuraRadius.pill),
                          ),
                          child: Text(
                            entry.value,
                            style: AuraText.small.copyWith(
                              fontWeight: FontWeight.w700,
                              color: active
                                  ? AuraSurface.ink
                                  : AuraSurface.muted,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selected == null || selected.trim().isEmpty) return;
    setState(() {
      _translationTargetLanguage = selected.trim().toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    final uploadingCount = _attachments.where((a) => a.uploading).length;
    final recordingElapsed = _recordingStartedAt == null
        ? Duration.zero
        : DateTime.now().difference(_recordingStartedAt!);

    // The host Scaffold already shifts the body for the keyboard via
    // resizeToAvoidBottomInset; adding `viewInsets.bottom` here on top
    // double-counts and pushes the composer above the keyboard by an
    // extra ~280 px on focus. Drop the second adjustment so the
    // composer sits flush against the top of the keyboard like other
    // Aura input surfaces.
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AuraCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Spacer(),
                      if (_attachments.isNotEmpty)
                        Text(
                          '${_attachments.length} attachment${_attachments.length == 1 ? '' : 's'}',
                          style: AuraText.small.copyWith(
                            color: AuraSurface.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AuraSpace.s10),
                  TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 6,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: _recordingAudio
                          ? 'Recording audio...'
                          : 'Write a message',
                      filled: true,
                      fillColor: AuraSurface.subtle,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AuraRadius.r16),
                        borderSide: const BorderSide(color: AuraSurface.divider),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AuraRadius.r16),
                        borderSide: const BorderSide(color: AuraSurface.divider),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AuraRadius.r16),
                        borderSide: const BorderSide(
                          color: AuraSurface.accent,
                        ),
                      ),
                    ),
                    onChanged: (_) {
                      setState(() {
                        if ((_assistSnapshot ?? '') != _controller.text.trim()) {
                          _suggestions = const [];
                          _assistError = null;
                          _assistSessionId = null;
                          _dismissedSuggestionIds.clear();
                        }
                        if ((_translationSnapshot ?? '') !=
                            _controller.text.trim()) {
                          _translationPreview = null;
                          _translationError = null;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: AuraSpace.s10),
                  if (_attachments.isNotEmpty) ...[
                    _AttachmentPreviewRow(
                      attachments: _attachments,
                      onRemove: _removeAttachment,
                      onRetry: _retryAttachment,
                    ),
                    const SizedBox(height: AuraSpace.s10),
                  ],
                  if (_recordingAudio) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AuraSurface.dangerBg,
                        borderRadius: BorderRadius.circular(AuraRadius.md),
                        border: Border.all(
                          color: AuraSurface.dangerInk.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.fiber_manual_record,
                            size: 14,
                            color: AuraSurface.dangerInk,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Recording audio ${_formatRecordingDuration(recordingElapsed)}',
                              style: AuraText.body.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          AuraGhostButton(
                            label: 'Cancel',
                            onPressed: _sending ? null : _cancelAudioRecording,
                          ),
                          const SizedBox(width: 6),
                          AuraPrimaryButton(
                            label: 'Stop',
                            icon: Icons.stop_rounded,
                            onPressed: _sending
                                ? null
                                : () => _toggleAudioRecording(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AuraSpace.s10),
                  ],
                  if (_visibleSuggestions.isNotEmpty || _assistError != null) ...[
                    _ComposerAssistPanel(
                      suggestions: _visibleSuggestions,
                      errorText: _assistError,
                      applyingIds: _applyingSuggestionIds,
                      onApply: _applySuggestion,
                      onDismiss: (suggestion) {
                        final id = firstNonEmpty(suggestion, const [
                          'id',
                          'findingId',
                        ]);
                        if (id.isEmpty) return;
                        setState(() => _dismissedSuggestionIds.add(id));
                      },
                    ),
                    const SizedBox(height: AuraSpace.s10),
                  ],
                  if (_translationPreview != null ||
                      _translationError != null) ...[
                    _ComposerTranslationPanel(
                      targetLanguage: _translationTargetLanguage,
                      preview: _translationPreview,
                      errorText: _translationError,
                      busy: _translationBusy,
                      onApply:
                          _translationPreview == null ? null : _applyTranslation,
                      onRestore: _translationSnapshot == null
                          ? null
                          : _restoreBeforeTranslation,
                    ),
                    const SizedBox(height: AuraSpace.s10),
                  ],
                  _ComposerFooter(
                    sending: _sending,
                    canSend: _canSend,
                    uploadingCount: uploadingCount,
                    hasText: _hasText,
                    assistBusy: _assistBusy,
                    translationBusy: _translationBusy,
                    onAddAttachment: _showAttachmentSheet,
                    onPolish: _runAssist,
                    onPickLanguage: _pickComposerLanguage,
                    onTranslate: _translateDraft,
                    onSend: _submit,
                    translationLabel: languageLabel(_translationTargetLanguage),
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

// ─────────────────────────────────────────────────────────────────────────────
// HELPER WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _AttachmentActionTile extends StatelessWidget {
  const _AttachmentActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final active = enabled && onTap != null;
    return ListTile(
      enabled: active,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AuraSurface.subtle,
          borderRadius: BorderRadius.circular(AuraRadius.r12),
          border: Border.all(color: AuraSurface.divider),
        ),
        child: Icon(
          icon,
          color: active ? AuraSurface.ink : AuraSurface.faint,
          size: 18,
        ),
      ),
      title: Text(
        title,
        style: AuraText.body.copyWith(
          fontWeight: FontWeight.w700,
          color: active ? AuraSurface.ink : AuraSurface.faint,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AuraText.small.copyWith(
          color: active ? AuraSurface.muted : AuraSurface.faint,
        ),
      ),
      onTap: onTap,
    );
  }
}

class _ComposerAssistPanel extends StatelessWidget {
  const _ComposerAssistPanel({
    required this.suggestions,
    required this.errorText,
    required this.applyingIds,
    required this.onApply,
    required this.onDismiss,
  });

  final List<Map<String, dynamic>> suggestions;
  final String? errorText;
  final Set<String> applyingIds;
  final void Function(Map<String, dynamic> suggestion) onApply;
  final void Function(Map<String, dynamic> suggestion) onDismiss;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Writing support', style: AuraText.title),
          if (errorText != null && errorText!.trim().isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s8),
            Text(errorText!, style: AuraText.body),
          ],
          for (final suggestion in suggestions) ...[
            const SizedBox(height: AuraSpace.s10),
            _ComposerSuggestionTile(
              suggestion: suggestion,
              busy: applyingIds.contains(
                firstNonEmpty(suggestion, const ['id', 'findingId']),
              ),
              onApply: () => onApply(suggestion),
              onDismiss: () => onDismiss(suggestion),
            ),
          ],
        ],
      ),
    );
  }
}

class _ComposerSuggestionTile extends StatelessWidget {
  const _ComposerSuggestionTile({
    required this.suggestion,
    required this.busy,
    required this.onApply,
    required this.onDismiss,
  });

  final Map<String, dynamic> suggestion;
  final bool busy;
  final VoidCallback onApply;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final message = firstNonEmpty(suggestion, const [
      'message',
      'title',
      'finding',
    ]);
    final detail = firstNonEmpty(suggestion, const [
      'suggestion',
      'detail',
      'description',
    ]);

    return Container(
      padding: const EdgeInsets.all(AuraSpace.s12),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        border: Border.all(color: AuraSurface.divider),
        borderRadius: BorderRadius.circular(AuraRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.isNotEmpty)
            Text(
              message,
              style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
            ),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text(detail, style: AuraText.body),
          ],
          const SizedBox(height: AuraSpace.s10),
          Row(
            children: [
              AuraGhostButton(
                label: 'Dismiss',
                onPressed: busy ? null : onDismiss,
              ),
              const SizedBox(width: AuraSpace.s8),
              AuraPrimaryButton(
                label: busy ? 'Applying…' : 'Apply',
                onPressed: busy ? null : onApply,
                icon: Icons.check_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ComposerTranslationPanel extends StatelessWidget {
  const _ComposerTranslationPanel({
    required this.targetLanguage,
    required this.preview,
    required this.errorText,
    required this.busy,
    required this.onApply,
    required this.onRestore,
  });

  final String targetLanguage;
  final String? preview;
  final String? errorText;
  final bool busy;
  final VoidCallback? onApply;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final label = switch (targetLanguage) {
      'ur' => 'Urdu',
      'ar' => 'Arabic',
      _ => 'English',
    };

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Translation preview', style: AuraText.title),
          const SizedBox(height: AuraSpace.s8),
          Text('Target language: $label', style: AuraText.small),
          if (errorText != null && errorText!.trim().isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s8),
            Text(errorText!, style: AuraText.body),
          ],
          if ((preview ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s8),
            Directionality(
              textDirection: directionForText(preview!),
              child: Text(
                preview!,
                textAlign: alignForText(preview!),
                style: AuraText.body,
              ),
            ),
            const SizedBox(height: AuraSpace.s10),
            Row(
              children: [
                AuraGhostButton(
                  label: 'Restore original',
                  onPressed: busy ? null : onRestore,
                ),
                const SizedBox(width: AuraSpace.s8),
                AuraPrimaryButton(
                  label: 'Use translation',
                  onPressed: busy ? null : onApply,
                  icon: Icons.check_rounded,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AttachmentPreviewRow extends StatelessWidget {
  const _AttachmentPreviewRow({
    required this.attachments,
    required this.onRemove,
    required this.onRetry,
  });

  final List<_DraftAttachment> attachments;
  final void Function(_DraftAttachment attachment) onRemove;
  final void Function(_DraftAttachment attachment) onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: attachments.length,
        separatorBuilder: (_, _) => const SizedBox(width: AuraSpace.s10),
        itemBuilder: (context, index) {
          final attachment = attachments[index];
          return _AttachmentPreviewCard(
            attachment: attachment,
            onRemove: () => onRemove(attachment),
            onRetry: () => onRetry(attachment),
          );
        },
      ),
    );
  }
}

class _AttachmentPreviewCard extends StatelessWidget {
  const _AttachmentPreviewCard({
    required this.attachment,
    required this.onRemove,
    required this.onRetry,
  });

  final _DraftAttachment attachment;
  final VoidCallback onRemove;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final label = attachment.file.name;
    final progress = attachment.uploadProgress;
    final progressPct = progress != null ? (progress * 100).round() : null;

    final subtitle = attachment.uploading
        ? (progressPct != null && progressPct < 100
            ? 'Uploading $progressPct%'
            : 'Uploading…')
        : attachment.error != null
        ? (attachment.error!)
        : _attachmentKindLabel(attachment.kind);

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        border: Border.all(
          color: attachment.error != null
              ? AuraSurface.dangerInk.withValues(alpha: 0.25)
              : AuraSurface.divider,
        ),
        borderRadius: BorderRadius.circular(AuraRadius.md),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 70,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _AttachmentPreviewMedia(attachment: attachment),
                if (attachment.uploading && progress != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.black26,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AuraSurface.accent,
                      ),
                      minHeight: 3,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AuraSpace.s10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AuraText.small.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AuraSpace.s4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AuraText.small.copyWith(
                          color: attachment.error != null
                              ? AuraSurface.dangerInk
                              : AuraSurface.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (attachment.uploading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (attachment.error != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: onRemove,
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: 'Remove',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                      IconButton(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        tooltip: 'Retry upload',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ],
                  )
                else
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Remove',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentPreviewMedia extends StatelessWidget {
  const _AttachmentPreviewMedia({required this.attachment});

  final _DraftAttachment attachment;

  @override
  Widget build(BuildContext context) {
    switch (attachment.kind) {
      case ThreadAttachmentKind.image:
        if (attachment.bytes.isNotEmpty) {
          return Image.memory(
            attachment.bytes,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => const _AttachmentFallbackTile(
              icon: Icons.image_outlined,
              label: 'Image',
            ),
          );
        }
        return const _AttachmentFallbackTile(
          icon: Icons.image_outlined,
          label: 'Image',
        );
      case ThreadAttachmentKind.video:
        return const _AttachmentFallbackTile(
          icon: Icons.videocam_outlined,
          label: 'Video',
        );
      case ThreadAttachmentKind.audio:
        return const _AttachmentFallbackTile(
          icon: Icons.graphic_eq_outlined,
          label: 'Audio',
        );
      case ThreadAttachmentKind.document:
        return const _AttachmentFallbackTile(
          icon: Icons.description_outlined,
          label: 'Document',
        );
    }
  }
}

class _AttachmentFallbackTile extends StatelessWidget {
  const _AttachmentFallbackTile({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AuraSurface.overlay,
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: AuraSurface.muted),
          const SizedBox(width: 6),
          Text(label, style: AuraText.small.copyWith(color: AuraSurface.muted)),
        ],
      ),
    );
  }
}

class _ComposerFooter extends StatelessWidget {
  const _ComposerFooter({
    required this.sending,
    required this.canSend,
    required this.uploadingCount,
    required this.hasText,
    required this.assistBusy,
    required this.translationBusy,
    required this.onAddAttachment,
    required this.onPolish,
    required this.onPickLanguage,
    required this.onTranslate,
    required this.onSend,
    required this.translationLabel,
  });

  final bool sending;
  final bool canSend;
  final int uploadingCount;
  final bool hasText;
  final bool assistBusy;
  final bool translationBusy;
  final VoidCallback onAddAttachment;
  final VoidCallback onPolish;
  final VoidCallback onPickLanguage;
  final VoidCallback onTranslate;
  final VoidCallback onSend;
  final String translationLabel;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AuraSpace.s8,
      runSpacing: AuraSpace.s8,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Wrap(
          spacing: AuraSpace.s8,
          runSpacing: AuraSpace.s8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AuraSurface.subtle,
                borderRadius: BorderRadius.circular(AuraRadius.r14),
                border: Border.all(color: AuraSurface.divider),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: sending ? null : onAddAttachment,
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Add attachment',
              ),
            ),
            AuraSecondaryButton(
              label: assistBusy ? 'Polishing…' : 'Polish',
              icon: Icons.auto_fix_high_outlined,
              onPressed: !hasText || assistBusy ? null : onPolish,
            ),
            MouseRegion(
              cursor: translationBusy
                  ? SystemMouseCursors.basic
                  : SystemMouseCursors.click,
              child: InkWell(
                onTap: translationBusy ? null : onPickLanguage,
                borderRadius: BorderRadius.circular(AuraRadius.pill),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AuraSpace.s12,
                    vertical: AuraSpace.s8,
                  ),
                  decoration: BoxDecoration(
                    color: AuraSurface.subtle,
                    border: Border.all(color: AuraSurface.divider),
                    borderRadius: BorderRadius.circular(AuraRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.translate,
                        size: 14,
                        color: AuraSurface.muted,
                      ),
                      const SizedBox(width: AuraSpace.s6),
                      Text(
                        translationLabel,
                        style: AuraText.small.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: AuraSpace.s4),
                      const Icon(
                        Icons.arrow_drop_down_rounded,
                        size: 16,
                        color: AuraSurface.muted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AuraSecondaryButton(
              label: translationBusy ? 'Translating…' : 'Translate',
              icon: Icons.translate_outlined,
              onPressed: !hasText || translationBusy ? null : onTranslate,
            ),
          ],
        ),
        AuraPrimaryButton(
          label: sending
              ? 'Sending…'
              : uploadingCount > 0
              ? 'Uploading…'
              : 'Send',
          // B1: Send is disabled when there's nothing to send (no text, no
          // ready attachment) — prior behaviour was an enabled button that
          // silently no-op'd, leaving users unsure whether the tap registered.
          onPressed: (sending || !canSend) ? null : onSend,
          icon: Icons.send_rounded,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EDIT MESSAGE DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class ThreadEditMessageDialog extends ConsumerStatefulWidget {
  const ThreadEditMessageDialog({super.key, required this.message});

  final Map<String, dynamic> message;

  @override
  ConsumerState<ThreadEditMessageDialog> createState() =>
      _ThreadEditMessageDialogState();
}

class _ThreadEditMessageDialogState
    extends ConsumerState<ThreadEditMessageDialog> {
  late final TextEditingController _controller;
  bool _saving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: pickString(widget.message, const ['body', 'text', 'content']),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final messageId = pickString(widget.message, const ['id', 'messageId']);
    final body = _controller.text.trim();

    if (messageId.isEmpty || body.isEmpty) {
      setState(() {
        _errorText = 'Message body cannot be empty.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _errorText = null;
    });

    try {
      await ref
          .read(messagesRepositoryProvider)
          .editMessage(messageId: messageId, body: body);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _errorText = '$e';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit message'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'Message'),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: AuraSpace.s12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _errorText!,
                  style: AuraText.small.copyWith(color: AuraSurface.dangerInk),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        AuraGhostButton(
          label: 'Cancel',
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
        ),
        AuraPrimaryButton(
          label: _saving ? 'Saving…' : 'Save',
          onPressed: _saving ? null : _submit,
          icon: Icons.check_rounded,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────

class _DraftAttachment {
  _DraftAttachment({
    required this.localId,
    required this.file,
    required this.bytes,
    required this.kind,
    required this.source,
    required this.mimeType,
    required this.sizeBytes,
    this.width,
    this.height,
    this.durationSec,
  });

  final String localId;
  final XFile file;
  final Uint8List bytes;
  final ThreadAttachmentKind kind;
  final _AttachmentSource source;
  final String mimeType;
  final int sizeBytes;
  int? width;
  int? height;
  int? durationSec;

  // Populated after upload completes.
  String mediaId = '';
  String? url;
  String? thumbUrl;
  String storageKey = '';
  bool uploading = false;
  double? uploadProgress; // 0.0–1.0
  String? error;

  // Backend DTO: storageKey, fileName, mimeType, sizeBytes, width?, height?, durationSec?
  // Additional fields (mediaId, url, thumbUrl) are stored locally for preview.
  Map<String, dynamic> toMessagePayload() {
    return {
      'storageKey': storageKey,
      'fileName': file.name,
      'mimeType': mimeType,
      'sizeBytes': sizeBytes,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (durationSec != null) 'durationSec': durationSec,
    };
  }
}

enum _AttachmentSource { gallery, camera, upload, recording }

// ─────────────────────────────────────────────────────────────────────────────
// COMPOSER-LOCAL UTILITIES
// ─────────────────────────────────────────────────────────────────────────────

String _formatRecordingDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

String _attachmentKindLabel(ThreadAttachmentKind kind) {
  switch (kind) {
    case ThreadAttachmentKind.image:
      return 'Image';
    case ThreadAttachmentKind.video:
      return 'Video';
    case ThreadAttachmentKind.audio:
      return 'Audio';
    case ThreadAttachmentKind.document:
      return 'Document';
  }
}

String _mediaKindValue(ThreadAttachmentKind kind) {
  switch (kind) {
    case ThreadAttachmentKind.image:
      return 'IMAGE';
    case ThreadAttachmentKind.video:
      return 'VIDEO';
    case ThreadAttachmentKind.audio:
      return 'AUDIO';
    case ThreadAttachmentKind.document:
      return 'IMAGE';
  }
}

String _mediaSourceValue(_AttachmentSource source) {
  switch (source) {
    case _AttachmentSource.gallery:
      return 'GALLERY';
    case _AttachmentSource.camera:
      return 'CAMERA';
    case _AttachmentSource.upload:
      return 'UPLOAD';
    case _AttachmentSource.recording:
      return 'RECORDING';
  }
}

String _inferMime(String fileName) {
  final lower = fileName.toLowerCase();

  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.webp')) return 'image/webp';

  if (lower.endsWith('.mp4')) return 'video/mp4';
  if (lower.endsWith('.mov')) return 'video/quicktime';
  if (lower.endsWith('.webm')) return 'video/webm';
  if (lower.endsWith('.mkv')) return 'video/x-matroska';

  if (lower.endsWith('.mp3')) return 'audio/mpeg';
  if (lower.endsWith('.m4a')) return 'audio/mp4';
  if (lower.endsWith('.aac')) return 'audio/aac';
  if (lower.endsWith('.wav')) return 'audio/wav';
  if (lower.endsWith('.ogg')) return 'audio/ogg';

  if (lower.endsWith('.pdf')) return 'application/pdf';
  if (lower.endsWith('.doc')) return 'application/msword';
  if (lower.endsWith('.docx')) return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
  if (lower.endsWith('.xls')) return 'application/vnd.ms-excel';
  if (lower.endsWith('.xlsx')) return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  if (lower.endsWith('.ppt')) return 'application/vnd.ms-powerpoint';
  if (lower.endsWith('.pptx')) return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
  if (lower.endsWith('.txt')) return 'text/plain';
  if (lower.endsWith('.csv')) return 'text/csv';
  if (lower.endsWith('.rtf')) return 'application/rtf';
  if (lower.endsWith('.zip')) return 'application/zip';

  return 'application/octet-stream';
}

Future<Map<String, int>?> _decodeImageSize(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  return {'width': image.width, 'height': image.height};
}

String _toAttachmentError(Object error) {
  if (error is DioException) {
    // D2/B8: prefer the structured backend error.code over substring/status
    // matching. Aura backend envelope: { ok:false, error: { code, message, ... } }.
    final data = error.response?.data;
    String code = '';
    String message = '';
    if (data is Map) {
      final inner = data['error'];
      if (inner is Map) {
        code = (inner['code'] ?? '').toString().trim();
        message = (inner['message'] ?? '').toString().trim();
      }
      if (code.isEmpty) {
        code = (data['code'] ?? '').toString().trim();
      }
      if (message.isEmpty) {
        message = (data['message'] ?? '').toString().trim();
      }
    }
    switch (code.toUpperCase()) {
      case 'UNSUPPORTED_MIME_TYPE':
        return 'File type not supported';
      case 'FILE_TOO_LARGE':
        return 'File is too large';
      case 'DURATION_EXCEEDED':
        return 'Audio or video exceeds the allowed length';
      case 'IMAGE_HAS_DURATION':
        return 'Image attachments cannot include duration';
      case 'INVALID_FILE_SIZE':
        return 'Invalid file size';
      case 'CONTENT_TYPE_REQUIRED':
        return 'File type is missing';
    }
    final status = error.response?.statusCode;
    if (status == 415) return 'File type not supported';
    if (message.isNotEmpty) return message;
  }
  return 'Upload failed';
}
