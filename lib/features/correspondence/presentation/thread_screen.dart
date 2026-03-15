import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../data/messages_repository.dart';
import '../data/threads_repository.dart';

final _threadDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, threadId) async {
  final repo = ref.watch(threadsRepositoryProvider);
  return repo.getThread(threadId);
});

final _messagesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      threadId,
    ) async {
      final repo = ref.watch(messagesRepositoryProvider);
      return repo.listMessages(threadId: threadId);
    });

final _currentUserProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/users/me');
  return _unwrapResponseMap(res.data);
});

class ThreadScreen extends ConsumerWidget {
  const ThreadScreen({super.key, required this.threadId});

  final String threadId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadAsync = ref.watch(_threadDetailProvider(threadId));
    final messagesAsync = ref.watch(_messagesProvider(threadId));
    final meAsync = ref.watch(_currentUserProvider);

    return AuraScaffold(
      title: 'Thread',
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(_threadDetailProvider(threadId));
                ref.invalidate(_messagesProvider(threadId));
                ref.invalidate(_currentUserProvider);
                await Future.wait([
                  ref.read(_threadDetailProvider(threadId).future),
                  ref.read(_messagesProvider(threadId).future),
                  ref.read(_currentUserProvider.future),
                ]);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  threadAsync.when(
                    loading: () => const AuraCard(
                      child: _LoadingBlock(label: 'Loading thread...'),
                    ),
                    error: (error, _) => AuraCard(
                      child: _ErrorBlock(
                        title: 'Could not load thread',
                        body: '$error',
                        onRetry: () =>
                            ref.invalidate(_threadDetailProvider(threadId)),
                      ),
                    ),
                    data: (thread) => _ThreadHeaderCard(
                      thread: thread,
                      onOpenSpace: () {
                        final spaceId = _pickString(
                          thread,
                          const ['spaceId', 'space_id'],
                        );
                        if (spaceId.isEmpty) return;
                        context.push('/me/correspondence/$spaceId');
                      },
                    ),
                  ),
                  const SizedBox(height: AuraSpace.s16),
                  Text('Messages', style: AuraText.title),
                  const SizedBox(height: AuraSpace.s10),
                  messagesAsync.when(
                    loading: () => const AuraCard(
                      child: _LoadingBlock(label: 'Loading messages...'),
                    ),
                    error: (error, _) => AuraCard(
                      child: _ErrorBlock(
                        title: 'Could not load messages',
                        body: '$error',
                        onRetry: () =>
                            ref.invalidate(_messagesProvider(threadId)),
                      ),
                    ),
                    data: (messages) {
                      if (messages.isEmpty) {
                        return const AuraCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('No messages yet', style: AuraText.title),
                              SizedBox(height: AuraSpace.s8),
                              Text(
                                'This thread has not started yet.',
                                style: AuraText.body,
                              ),
                            ],
                          ),
                        );
                      }

                      final currentUserId = meAsync.maybeWhen(
                        data: (me) => _pickString(
                          me,
                          const ['id', '_id', 'userId'],
                        ),
                        orElse: () => '',
                      );

                      return Column(
                        children: [
                          for (var i = 0; i < messages.length; i++) ...[
                            _MessageTile(
                              message: messages[i],
                              currentUserId: currentUserId,
                              onEdit: () => _showEditMessageDialog(
                                context,
                                ref,
                                messages[i],
                              ),
                              onDelete: () async {
                                final messageId = _pickString(
                                  messages[i],
                                  const ['id', 'messageId'],
                                );
                                if (messageId.isEmpty) return;
                                await ref
                                    .read(messagesRepositoryProvider)
                                    .deleteMessage(messageId);
                                ref.invalidate(_messagesProvider(threadId));
                              },
                            ),
                            if (i != messages.length - 1)
                              const SizedBox(height: AuraSpace.s10),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          _ComposerBar(
            threadId: threadId,
            onSent: () {
              ref.invalidate(_messagesProvider(threadId));
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showEditMessageDialog(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> message,
  ) async {
    final edited = await showDialog<bool>(
      context: context,
      builder: (_) => _EditMessageDialog(message: message),
    );

    if (edited == true) {
      ref.invalidate(_messagesProvider(threadId));
    }
  }
}

class _ThreadHeaderCard extends StatelessWidget {
  const _ThreadHeaderCard({
    required this.thread,
    required this.onOpenSpace,
  });

  final Map<String, dynamic> thread;
  final VoidCallback onOpenSpace;

  @override
  Widget build(BuildContext context) {
    final title = _pickString(thread, const ['title', 'name']);
    final kind = _pickString(thread, const ['kind', 'type']);
    final archived =
        thread['archived'] == true || thread['archivedAt'] != null;
    final description = _pickString(
      thread,
      const ['description', 'summary', 'subtitle'],
    );
    final spaceId = _pickString(thread, const ['spaceId', 'space_id']);

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Thread',
            style: AuraText.small.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AuraSpace.s8),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                title.isEmpty ? 'Untitled thread' : title,
                style: AuraText.title,
              ),
              if (kind.isNotEmpty) _Pill(label: kind),
              if (archived) _Pill(label: 'ARCHIVED'),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s8),
            Text(
              description,
              style: AuraText.body,
            ),
          ],
          if (spaceId.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s12),
            OutlinedButton(
              onPressed: onOpenSpace,
              child: const Text('Open space'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ComposerBar extends ConsumerStatefulWidget {
  const _ComposerBar({
    required this.threadId,
    required this.onSent,
  });

  final String threadId;
  final VoidCallback onSent;

  @override
  ConsumerState<_ComposerBar> createState() => _ComposerBarState();
}

class _ComposerBarState extends ConsumerState<_ComposerBar> {
  final _controller = TextEditingController();
  final _audioRecorder = AudioRecorder();
  final _picker = ImagePicker();

  final List<_DraftAttachment> _attachments = [];

  bool _sending = false;
  bool _recordingAudio = false;

  @override
  void dispose() {
    _controller.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  bool get _canSend {
    if (_sending) return false;
    if (_attachments.any((a) => a.uploading)) return false;
    return _controller.text.trim().isNotEmpty || _attachments.isNotEmpty;
  }

  Future<void> _pickImageFromGallery() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    await _addAttachment(file, kind: _AttachmentKind.image);
  }

  Future<void> _pickImageFromCamera() async {
    final file = await _picker.pickImage(source: ImageSource.camera);
    if (file == null) return;
    await _addAttachment(
      file,
      kind: _AttachmentKind.image,
      source: _AttachmentSource.camera,
    );
  }

  Future<void> _pickVideoFromGallery() async {
    final file = await _picker.pickVideo(source: ImageSource.gallery);
    if (file == null) return;
    await _addAttachment(file, kind: _AttachmentKind.video);
  }

  Future<void> _pickVideoFromCamera() async {
    final file = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(seconds: 60),
    );
    if (file == null) return;
    await _addAttachment(
      file,
      kind: _AttachmentKind.video,
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
      kind: _AttachmentKind.audio,
      source: _AttachmentSource.upload,
    );
  }

  Future<void> _toggleAudioRecording() async {
    if (_sending) return;

    if (_recordingAudio) {
      final path = await _audioRecorder.stop();
      if (!mounted) return;

      setState(() => _recordingAudio = false);

      if (path == null || path.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save audio recording.')),
        );
        return;
      }

      final file = XFile(path, mimeType: 'audio/aac');
      await _addAttachment(
        file,
        kind: _AttachmentKind.audio,
        source: _AttachmentSource.recording,
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
    setState(() => _recordingAudio = true);
  }

  Future<void> _addAttachment(
    XFile file, {
    required _AttachmentKind kind,
    _AttachmentSource source = _AttachmentSource.gallery,
  }) async {
    final bytes = await file.readAsBytes();

    int? width;
    int? height;

    if (kind == _AttachmentKind.image) {
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
      mimeType: file.mimeType ?? _inferMime(file.name),
      sizeBytes: bytes.length,
      uploading: true,
    );

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
        attachment.error = '$e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not upload attachment: $e')),
      );
    }
  }

  Future<void> _uploadAttachment(_DraftAttachment attachment) async {
    final dio = ref.read(dioProvider);
    final mime = attachment.mimeType;

    final pres = await dio.post(
      '/media/presign',
      data: {
        'fileName': attachment.file.name,
        'mimeType': mime,
        'bytes': attachment.sizeBytes,
        'kind': _mediaKindValue(attachment.kind),
        'source': _mediaSourceValue(attachment.source),
        if (attachment.width != null) 'width': attachment.width,
        if (attachment.height != null) 'height': attachment.height,
      },
    );

    final presigned = _unwrapDataMap(pres.data);
    final mediaMap = _asMap(presigned['media']);
    final upload = _asMap(presigned['upload']);
    final uploadUrl = _str(upload['url']);
    final headers = _asMap(upload['headers']);

    if (uploadUrl.isEmpty) {
      throw Exception('Upload URL missing from presign response.');
    }

    final uploadHeaders = <String, String>{};
    headers.forEach((k, v) {
      if (v == null) return;
      uploadHeaders[k.toString()] = v.toString();
    });
    if (!uploadHeaders.containsKey('Content-Type')) {
      uploadHeaders['Content-Type'] = mime;
    }

    final uploadDio = _cleanUploadDio();
    await uploadDio.put(
      uploadUrl,
      data: attachment.bytes,
      options: Options(
        headers: uploadHeaders,
        contentType: uploadHeaders['Content-Type'],
        responseType: ResponseType.plain,
        followRedirects: true,
        validateStatus: (code) => code != null && code >= 200 && code < 300,
      ),
    );

    final mediaId = _firstNonEmpty(mediaMap, const ['id', 'mediaId']);
    if (mediaId.isNotEmpty) {
      await dio.post('/media/$mediaId/confirm');
      await dio.post('/media/$mediaId/ready');

      final patch = await dio.patch(
        '/media/$mediaId',
        data: {
          if (attachment.width != null) 'width': attachment.width,
          if (attachment.height != null) 'height': attachment.height,
          'editDisclosure': false,
        },
      );

      final patched = _unwrapDataMap(patch.data);

      attachment.url = _firstNonEmpty(
        patched,
        const [
          'displayUrl',
          'url',
          'publicUrl',
          'signedUrl',
          'sourceUrl',
          'fileUrl',
        ],
      );
      attachment.thumbUrl = _firstNonEmpty(
        patched,
        const [
          'thumbnailUrl',
          'thumbUrl',
          'previewUrl',
          'displayUrl',
          'url',
        ],
      );

      attachment.storageKey = _firstNonEmpty(patched, const [
        'storageKey',
        'objectKey',
        'key',
        'path',
      ]);

      if (attachment.storageKey.isEmpty) {
        attachment.storageKey = _firstNonEmpty(mediaMap, const [
          'storageKey',
          'objectKey',
          'key',
          'path',
        ]);
      }
    }

    if (attachment.storageKey.isEmpty) {
      attachment.storageKey = _firstNonEmpty(upload, const [
        'objectKey',
        'storageKey',
        'key',
        'path',
      ]);
    }

    if (attachment.storageKey.isEmpty) {
      attachment.storageKey = _firstNonEmpty(presigned, const [
        'storageKey',
        'objectKey',
        'key',
        'path',
      ]);
    }

    if (attachment.storageKey.isEmpty) {
      throw Exception(
        'Storage key missing from upload response. Message attachment cannot be finalized yet.',
      );
    }

    attachment.uploading = false;
    attachment.error = null;
  }

  Future<void> _submit() async {
    if (!_canSend) return;

    final body = _controller.text.trim();
    final attachmentsPayload = _attachments
        .where((a) => !a.uploading && a.error == null && a.storageKey.isNotEmpty)
        .map((a) => a.toMessagePayload())
        .toList();

    setState(() => _sending = true);

    try {
      await ref.read(messagesRepositoryProvider).sendMessage(
            threadId: widget.threadId,
            body: body,
            attachments: attachmentsPayload,
          );

      _controller.clear();
      _attachments.clear();

      if (!mounted) return;
      widget.onSent();
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send message: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  void _removeAttachment(_DraftAttachment attachment) {
    if (_sending) return;
    setState(() {
      _attachments.removeWhere((a) => a.localId == attachment.localId);
    });
  }

  Future<void> _showAttachmentSheet() async {
    if (_sending) return;

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        void closeAnd(Future<void> Function() action) {
          Navigator.of(sheetContext).pop();
          Future<void>.microtask(action);
        }

        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take photo'),
                onTap: () => closeAnd(_pickImageFromCamera),
              ),
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('Upload image'),
                onTap: () => closeAnd(_pickImageFromGallery),
              ),
              ListTile(
                leading: const Icon(Icons.videocam_outlined),
                title: const Text('Record video'),
                onTap: () => closeAnd(_pickVideoFromCamera),
              ),
              ListTile(
                leading: const Icon(Icons.video_library_outlined),
                title: const Text('Upload video'),
                onTap: () => closeAnd(_pickVideoFromGallery),
              ),
              ListTile(
                leading: Icon(
                  _recordingAudio ? Icons.stop_circle_outlined : Icons.mic_none,
                ),
                title: Text(
                  _recordingAudio ? 'Stop audio recording' : 'Record audio',
                ),
                onTap: () => closeAnd(_toggleAudioRecording),
              ),
              ListTile(
                leading: const Icon(Icons.audio_file_outlined),
                title: const Text('Upload audio'),
                onTap: () => closeAnd(_pickAudioFile),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final uploadingCount = _attachments.where((a) => a.uploading).length;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.black12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_attachments.isNotEmpty) ...[
              _AttachmentPreviewRow(
                attachments: _attachments,
                onRemove: _removeAttachment,
              ),
              const SizedBox(height: AuraSpace.s10),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: _sending ? null : _showAttachmentSheet,
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Add attachment',
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 6,
                    decoration: InputDecoration(
                      hintText: _recordingAudio
                          ? 'Recording audio...'
                          : 'Write a message',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: AuraSpace.s10),
                FilledButton(
                  onPressed: _canSend ? _submit : null,
                  child: Text(
                    _sending
                        ? 'Sending...'
                        : uploadingCount > 0
                            ? 'Uploading...'
                            : 'Send',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentPreviewRow extends StatelessWidget {
  const _AttachmentPreviewRow({
    required this.attachments,
    required this.onRemove,
  });

  final List<_DraftAttachment> attachments;
  final void Function(_DraftAttachment attachment) onRemove;

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
  });

  final _DraftAttachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final label = attachment.file.name;
    final subtitle = attachment.uploading
        ? 'Uploading...'
        : attachment.error != null
            ? 'Failed'
            : _attachmentKindLabel(attachment.kind);

    return Container(
      width: 240,
      padding: const EdgeInsets.all(AuraSpace.s10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _AttachmentIcon(kind: attachment.kind),
          const SizedBox(width: AuraSpace.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AuraText.small.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AuraSpace.s4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AuraText.small,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: attachment.uploading ? null : onRemove,
            icon: const Icon(Icons.close),
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}

class _EditMessageDialog extends ConsumerStatefulWidget {
  const _EditMessageDialog({required this.message});

  final Map<String, dynamic> message;

  @override
  ConsumerState<_EditMessageDialog> createState() => _EditMessageDialogState();
}

class _EditMessageDialogState extends ConsumerState<_EditMessageDialog> {
  late final TextEditingController _controller;
  bool _saving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: _pickString(widget.message, const ['body', 'text', 'content']),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final messageId = _pickString(widget.message, const ['id', 'messageId']);
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
      await ref.read(messagesRepositoryProvider).editMessage(
            messageId: messageId,
            body: body,
          );

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
              decoration: const InputDecoration(
                labelText: 'Message',
              ),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: AuraSpace.s12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _errorText!,
                  style: AuraText.small.copyWith(
                    color: Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(_saving ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({
    required this.message,
    required this.currentUserId,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> message;
  final String currentUserId;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final body = _pickString(message, const ['body', 'text', 'content']);
    final authorMap = _extractAuthorMap(message);
    final author = _pickString(
      authorMap.isNotEmpty ? authorMap : message,
      const ['displayName', 'authorName', 'senderName', 'name', 'userName'],
    );
    final handle = _pickString(
      authorMap.isNotEmpty ? authorMap : message,
      const ['handle', 'authorHandle', 'senderHandle', 'username'],
    );
    final contextLine = _pickString(
      authorMap.isNotEmpty ? authorMap : message,
      const ['authorContext', 'senderContext', 'bio', 'tagline', 'headline'],
    );
    final createdAt = _pickString(
      message,
      const ['createdAt', 'sentAt', 'timestamp'],
    );
    final attachments = _listOfMap(message['attachments']);
    final senderId = _extractSenderId(message);
    final isMine =
        currentUserId.trim().isNotEmpty && senderId.trim() == currentUserId.trim();

    final bubbleColor = isMine ? Colors.black : Colors.white;
    final bubbleBorderColor = isMine ? Colors.black : Colors.black12;
    final textColor = isMine ? Colors.white : Colors.black87;
    final metaColor = isMine ? Colors.white70 : Colors.black54;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width > 900 ? 640 : 540,
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMine && author.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap:
                      handle.isEmpty ? null : () => context.push('/author/$handle'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          author,
                          style: AuraText.small.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (handle.isNotEmpty) ...[
                          const SizedBox(height: AuraSpace.s4),
                          Text('@$handle', style: AuraText.small),
                        ],
                        if (contextLine.isNotEmpty) ...[
                          const SizedBox(height: AuraSpace.s4),
                          Text(
                            contextLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AuraText.small,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
            Container(
              decoration: BoxDecoration(
                color: bubbleColor,
                border: Border.all(color: bubbleBorderColor),
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (body.isNotEmpty) ...[
                    Text(
                      body,
                      style: AuraText.body.copyWith(color: textColor),
                    ),
                    if (attachments.isNotEmpty) const SizedBox(height: AuraSpace.s10),
                  ],
                  if (attachments.isNotEmpty) ...[
                    _MessageAttachmentList(
                      attachments: attachments,
                      isMine: isMine,
                    ),
                    const SizedBox(height: AuraSpace.s10),
                  ] else if (body.isEmpty) ...[
                    Text(
                      '(empty message)',
                      style: AuraText.body.copyWith(color: textColor),
                    ),
                    const SizedBox(height: AuraSpace.s10),
                  ],
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (createdAt.isNotEmpty)
                        Flexible(
                          child: Text(
                            createdAt,
                            overflow: TextOverflow.ellipsis,
                            style: AuraText.small.copyWith(color: metaColor),
                          ),
                        ),
                      if (isMine) ...[
                        const SizedBox(width: AuraSpace.s8),
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.more_horiz,
                            size: 18,
                            color: metaColor,
                          ),
                          onSelected: (value) {
                            if (value == 'edit') {
                              onEdit();
                            } else if (value == 'delete') {
                              onDelete();
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem<String>(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                      ],
                    ],
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

class _MessageAttachmentList extends StatelessWidget {
  const _MessageAttachmentList({
    required this.attachments,
    required this.isMine,
  });

  final List<Map<String, dynamic>> attachments;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < attachments.length; i++) ...[
          _MessageAttachmentCard(
            attachment: attachments[i],
            isMine: isMine,
          ),
          if (i != attachments.length - 1)
            const SizedBox(height: AuraSpace.s8),
        ],
      ],
    );
  }
}

class _MessageAttachmentCard extends StatelessWidget {
  const _MessageAttachmentCard({
    required this.attachment,
    required this.isMine,
  });

  final Map<String, dynamic> attachment;
  final bool isMine;

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this attachment.')),
      );
      return;
    }

    final ok = await launchUrl(
      uri,
      mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );

    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this attachment.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = _pickString(attachment, const ['fileName', 'name']);
    final mimeType = _pickString(attachment, const ['mimeType', 'mime']);
    final sizeBytes = _pickInt(attachment, const ['sizeBytes', 'size']);
    final kind = _kindFromMime(mimeType);
    final url = _resolveAttachmentUrl(attachment);
    final thumbUrl = _resolveAttachmentThumbUrl(attachment);

    final borderColor = isMine ? Colors.white24 : Colors.black12;
    final surfaceColor = isMine ? Colors.white.withOpacity(0.08) : Colors.white;
    final primaryTextColor = isMine ? Colors.white : Colors.black87;
    final secondaryTextColor = isMine ? Colors.white70 : Colors.black54;

    Widget mediaSurface;
    switch (kind) {
      case _AttachmentKind.image:
        mediaSurface = _ImageAttachmentSurface(
          thumbUrl: thumbUrl,
          url: url,
          borderColor: borderColor,
          surfaceColor: surfaceColor,
          primaryTextColor: primaryTextColor,
          secondaryTextColor: secondaryTextColor,
          fileName: fileName,
          sizeBytes: sizeBytes,
        );
        break;
      case _AttachmentKind.video:
        mediaSurface = _VideoAttachmentSurface(
          thumbUrl: thumbUrl,
          url: url,
          borderColor: borderColor,
          surfaceColor: surfaceColor,
          primaryTextColor: primaryTextColor,
          secondaryTextColor: secondaryTextColor,
          fileName: fileName,
          sizeBytes: sizeBytes,
        );
        break;
      case _AttachmentKind.audio:
        mediaSurface = _AudioAttachmentSurface(
          url: url,
          borderColor: borderColor,
          surfaceColor: surfaceColor,
          primaryTextColor: primaryTextColor,
          secondaryTextColor: secondaryTextColor,
          fileName: fileName,
          sizeBytes: sizeBytes,
          mimeType: mimeType,
        );
        break;
    }

    if (url.isEmpty) return mediaSurface;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _openUrl(context, url),
      child: mediaSurface,
    );
  }
}

class _ImageAttachmentSurface extends StatelessWidget {
  const _ImageAttachmentSurface({
    required this.thumbUrl,
    required this.url,
    required this.borderColor,
    required this.surfaceColor,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.fileName,
    required this.sizeBytes,
  });

  final String thumbUrl;
  final String url;
  final Color borderColor;
  final Color surfaceColor;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final String fileName;
  final int? sizeBytes;

  @override
  Widget build(BuildContext context) {
    final imageUrl = thumbUrl.isNotEmpty ? thumbUrl : url;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imageUrl.isNotEmpty)
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _BrokenMediaFallback(
                      icon: Icons.image_outlined,
                      text: 'Image preview unavailable',
                      textColor: secondaryTextColor,
                    ),
                  )
                else
                  _BrokenMediaFallback(
                    icon: Icons.image_outlined,
                    text: 'Image unavailable',
                    textColor: secondaryTextColor,
                  ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: _OpenBadge(
                    label: 'Open',
                    dark: true,
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
                  child: Text(
                    fileName.isEmpty ? 'Image' : fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AuraText.small.copyWith(
                      fontWeight: FontWeight.w700,
                      color: primaryTextColor,
                    ),
                  ),
                ),
                if (sizeBytes != null)
                  Text(
                    _formatBytes(sizeBytes!),
                    style: AuraText.small.copyWith(color: secondaryTextColor),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoAttachmentSurface extends StatelessWidget {
  const _VideoAttachmentSurface({
    required this.thumbUrl,
    required this.url,
    required this.borderColor,
    required this.surfaceColor,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.fileName,
    required this.sizeBytes,
  });

  final String thumbUrl;
  final String url;
  final Color borderColor;
  final Color surfaceColor;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final String fileName;
  final int? sizeBytes;

  @override
  Widget build(BuildContext context) {
    final previewUrl = thumbUrl.isNotEmpty ? thumbUrl : url;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (previewUrl.isNotEmpty)
                  Image.network(
                    previewUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _BrokenMediaFallback(
                      icon: Icons.videocam_outlined,
                      text: 'Video preview unavailable',
                      textColor: Colors.white70,
                      dark: true,
                    ),
                  )
                else
                  _BrokenMediaFallback(
                    icon: Icons.videocam_outlined,
                    text: 'Video ready to open',
                    textColor: Colors.white70,
                    dark: true,
                  ),
                Container(color: Colors.black26),
                Center(
                  child: Container(
                    height: 56,
                    width: 56,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: _OpenBadge(
                    label: 'Open',
                    dark: true,
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
                  child: Text(
                    fileName.isEmpty ? 'Video' : fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AuraText.small.copyWith(
                      fontWeight: FontWeight.w700,
                      color: primaryTextColor,
                    ),
                  ),
                ),
                if (sizeBytes != null)
                  Text(
                    _formatBytes(sizeBytes!),
                    style: AuraText.small.copyWith(color: secondaryTextColor),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioAttachmentSurface extends StatelessWidget {
  const _AudioAttachmentSurface({
    required this.url,
    required this.borderColor,
    required this.surfaceColor,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.fileName,
    required this.sizeBytes,
    required this.mimeType,
  });

  final String url;
  final Color borderColor;
  final Color surfaceColor;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final String fileName;
  final int? sizeBytes;
  final String mimeType;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s12),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.graphic_eq_outlined,
              color: secondaryTextColor,
            ),
          ),
          const SizedBox(width: AuraSpace.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName.isEmpty ? 'Audio' : fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AuraText.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: AuraSpace.s4),
                Text(
                  [
                    if (mimeType.isNotEmpty) mimeType,
                    if (sizeBytes != null) _formatBytes(sizeBytes!),
                  ].join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AuraText.small.copyWith(color: secondaryTextColor),
                ),
                const SizedBox(height: AuraSpace.s6),
                Row(
                  children: [
                    Icon(
                      Icons.open_in_new,
                      size: 14,
                      color: secondaryTextColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      url.isNotEmpty ? 'Open audio' : 'Audio unavailable',
                      style: AuraText.small.copyWith(color: secondaryTextColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BrokenMediaFallback extends StatelessWidget {
  const _BrokenMediaFallback({
    required this.icon,
    required this.text,
    required this.textColor,
    this.dark = false,
  });

  final IconData icon;
  final String text;
  final Color textColor;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: dark ? Colors.black38 : Colors.black12,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: textColor),
          const SizedBox(height: 8),
          Text(
            text,
            style: AuraText.small.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }
}

class _OpenBadge extends StatelessWidget {
  const _OpenBadge({
    required this.label,
    this.dark = false,
  });

  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: dark ? Colors.black54 : Colors.white70,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.open_in_new,
            size: 12,
            color: dark ? Colors.white : Colors.black87,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AuraText.small.copyWith(
              color: dark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentIcon extends StatelessWidget {
  const _AttachmentIcon({required this.kind});

  final _AttachmentKind kind;

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (kind) {
      case _AttachmentKind.image:
        icon = Icons.image_outlined;
        break;
      case _AttachmentKind.video:
        icon = Icons.videocam_outlined;
        break;
      case _AttachmentKind.audio:
        icon = Icons.graphic_eq_outlined;
        break;
    }

    return Container(
      height: 40,
      width: 40,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon),
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: AuraSpace.s10),
        Text(label, style: AuraText.body),
      ],
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({
    required this.title,
    required this.body,
    required this.onRetry,
  });

  final String title;
  final String body;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AuraText.title),
        const SizedBox(height: AuraSpace.s8),
        Text(body, style: AuraText.body),
        const SizedBox(height: AuraSpace.s12),
        OutlinedButton(
          onPressed: onRetry,
          child: const Text('Try again'),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s10,
        vertical: AuraSpace.s6,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AuraText.small.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

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
    this.url,
    this.thumbUrl,
    this.storageKey = '',
    this.uploading = false,
    this.error,
  });

  final String localId;
  final XFile file;
  final Uint8List bytes;
  final _AttachmentKind kind;
  final _AttachmentSource source;
  final String mimeType;
  final int sizeBytes;
  int? width;
  int? height;
  int? durationSec;
  String? url;
  String? thumbUrl;
  String storageKey;
  bool uploading;
  String? error;

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

enum _AttachmentKind {
  image,
  video,
  audio,
}

enum _AttachmentSource {
  gallery,
  camera,
  upload,
  recording,
}

String _attachmentKindLabel(_AttachmentKind kind) {
  switch (kind) {
    case _AttachmentKind.image:
      return 'Image';
    case _AttachmentKind.video:
      return 'Video';
    case _AttachmentKind.audio:
      return 'Audio';
  }
}

String _mediaKindValue(_AttachmentKind kind) {
  switch (kind) {
    case _AttachmentKind.image:
      return 'IMAGE';
    case _AttachmentKind.video:
      return 'VIDEO';
    case _AttachmentKind.audio:
      return 'AUDIO';
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

_AttachmentKind _kindFromMime(String mime) {
  final lower = mime.toLowerCase();
  if (lower.startsWith('image/')) return _AttachmentKind.image;
  if (lower.startsWith('video/')) return _AttachmentKind.video;
  return _AttachmentKind.audio;
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

  return 'application/octet-stream';
}

Future<Map<String, int>?> _decodeImageSize(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  return {
    'width': image.width,
    'height': image.height,
  };
}

Dio _cleanUploadDio() {
  return Dio(
    BaseOptions(
      responseType: ResponseType.plain,
      followRedirects: true,
    ),
  );
}

Map<String, dynamic> _unwrapDataMap(dynamic raw) {
  if (raw is Map) {
    final map = Map<String, dynamic>.from(raw);
    final data = map['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return map;
  }
  return <String, dynamic>{};
}

Map<String, dynamic> _unwrapResponseMap(dynamic raw) {
  if (raw is Map<String, dynamic>) {
    const nestedKeys = [
      'data',
      'user',
      'item',
      'result',
      'payload',
    ];

    for (final key in nestedKeys) {
      final nested = raw[key];
      if (nested is Map<String, dynamic>) {
        return _unwrapResponseMap(nested);
      }
      if (nested is Map) {
        return _unwrapResponseMap(Map<String, dynamic>.from(nested));
      }
    }

    return raw;
  }

  if (raw is Map) {
    return _unwrapResponseMap(Map<String, dynamic>.from(raw));
  }

  return <String, dynamic>{};
}

Map<String, dynamic> _asMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _listOfMap(dynamic raw) {
  if (raw is! List) return const [];
  return raw.map((e) => _asMap(e)).toList();
}

String _str(dynamic value) => (value ?? '').toString().trim();

String _firstNonEmpty(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = _str(map[key]);
    if (value.isNotEmpty) return value;
  }
  return '';
}

int? _pickInt(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is int) return value;
    final parsed = int.tryParse('${value ?? ''}');
    if (parsed != null) return parsed;
  }
  return null;
}

String _pickString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = (map[key] ?? '').toString().trim();
    if (value.isNotEmpty) return value;
  }
  return '';
}

Map<String, dynamic> _extractAuthorMap(Map<String, dynamic> message) {
  const keys = [
    'author',
    'sender',
    'user',
    'member',
    'profile',
    'createdBy',
  ];

  for (final key in keys) {
    final value = message[key];
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
  }

  return const <String, dynamic>{};
}

String _extractSenderId(Map<String, dynamic> message) {
  final direct = _pickString(message, const [
    'authorId',
    'senderId',
    'userId',
    'createdById',
    'memberId',
  ]);
  if (direct.isNotEmpty) return direct;

  final author = _extractAuthorMap(message);
  if (author.isEmpty) return '';

  return _pickString(author, const [
    'id',
    '_id',
    'userId',
    'memberId',
  ]);
}

String _resolveAttachmentUrl(Map<String, dynamic> attachment) {
  return _pickString(
    attachment,
    const [
      'displayUrl',
      'url',
      'publicUrl',
      'signedUrl',
      'sourceUrl',
      'fileUrl',
      'href',
      'src',
      'downloadUrl',
    ],
  );
}

String _resolveAttachmentThumbUrl(Map<String, dynamic> attachment) {
  return _pickString(
    attachment,
    const [
      'thumbnailUrl',
      'thumbUrl',
      'previewUrl',
      'posterUrl',
      'displayUrl',
      'publicUrl',
      'signedUrl',
      'url',
    ],
  );
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
  final gb = mb / 1024;
  return '${gb.toStringAsFixed(gb >= 100 ? 0 : 1)} GB';
}