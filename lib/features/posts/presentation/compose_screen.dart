import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../post_repository.dart';

enum _AttachKind { none, image, video, link }

final _postsRepoProvider = Provider<PostsRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return PostsRepository(dio);
});

class ComposeScreen extends ConsumerStatefulWidget {
  const ComposeScreen({super.key, this.replyToPostId});
  final String? replyToPostId;

  @override
  ConsumerState<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends ConsumerState<ComposeScreen> {
  final _controller = TextEditingController();
  final _linkController = TextEditingController();

  bool _posting = false;
  bool _loadingDraft = false;
  bool _savingDraft = false;

  Timer? _debounce;
  static const int _limit = 2000;

  _AttachKind _attachKind = _AttachKind.none;

  // File attachment
  XFile? _pickedFile;
  Uint8List? _previewImageBytes;
  String? _fileName;
  int? _fileBytes;
  int? _imgW;
  int? _imgH;

  // Link preview
  bool _linkLoading = false;
  String? _linkError;
  Map<String, dynamic>? _linkPreview; // {url,title,description,image}

  bool get _isReply => widget.replyToPostId != null;
  bool get _hasText => _controller.text.trim().isNotEmpty;
  bool get _hasAttachment => _attachKind != _AttachKind.none;

  @override
  void initState() {
    super.initState();
    if (!_isReply) {
      _loadDraft();
      _controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (!_isReply) _controller.removeListener(_onChanged);
    _controller.dispose();
    _linkController.dispose();
    super.dispose();
  }

  void _onChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      _saveDraft();
    });
    if (mounted) setState(() {});
  }

  Future<void> _loadDraft() async {
    setState(() => _loadingDraft = true);
    try {
      final dio = ref.read(dioProvider);

      final res = await dio.get('/posts/draft');
      final data = res.data;

      if (data == null) return;

      Map<String, dynamic>? post;
      if (data is Map && data['data'] is Map) {
        post = Map<String, dynamic>.from(data['data'] as Map);
      } else if (data is Map) {
        post = Map<String, dynamic>.from(data);
      }

      final text = (post?['text'] ?? '').toString();
      if (text.isNotEmpty) {
        _controller.text = text;
        _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
      }
    } catch (_) {
      // silent
    } finally {
      if (mounted) setState(() => _loadingDraft = false);
    }
  }

  Future<void> _saveDraft({bool silent = true}) async {
    if (_isReply) return;
    if (_savingDraft) return;

    setState(() => _savingDraft = true);
    try {
      final repo = ref.read(_postsRepoProvider);

      // Draft save includes any attachment metadata we already have
      await repo.saveDraft(
        text: _controller.text,
        mediaType: _draftMediaType(),
        mediaUrl: _draftMediaUrl(),
        mediaThumbUrl: _draftMediaThumbUrl(),
        mediaWidth: _imgW,
        mediaHeight: _imgH,
        caption: _draftCaption(),
        linkTitle: _linkPreview?['title']?.toString(),
        linkDescription: _linkPreview?['description']?.toString(),
        linkImageUrl: _linkPreview?['image']?.toString(),
      );

      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft saved.')));
      }
    } catch (_) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save draft.')));
      }
    } finally {
      if (mounted) setState(() => _savingDraft = false);
    }
  }

  String _draftMediaType() {
    switch (_attachKind) {
      case _AttachKind.image:
        return 'IMAGE';
      case _AttachKind.video:
        return 'VIDEO';
      case _AttachKind.link:
        return 'LINK';
      case _AttachKind.none:
        return 'NONE';
    }
  }

  String? _draftMediaUrl() {
    if (_attachKind == _AttachKind.link) return _linkPreview?['url']?.toString();
    // For image/video we only set mediaUrl after upload.
    return null;
  }

  String? _draftMediaThumbUrl() {
    if (_attachKind == _AttachKind.link) return _linkPreview?['image']?.toString();
    return null;
  }

  String? _draftCaption() {
    if (_attachKind == _AttachKind.link) {
      final t = _linkPreview?['title']?.toString();
      if (t != null && t.trim().isNotEmpty) return t.trim();
    }
    return null;
  }

  Future<void> _discardDraft() async {
    if (_isReply) {
      _controller.clear();
      _removeAttachment();
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cleared.')));
      return;
    }

    try {
      final dio = ref.read(dioProvider);
      await dio.delete('/posts/draft');
      _controller.clear();
      _removeAttachment();
      setState(() {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft discarded.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not discard draft: $e')));
    }
  }

  Future<void> _pickImage() async {
    if (_posting) return;
    if (_isReply) return;

    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 92);
      if (file == null) return;

      final bytes = await file.readAsBytes();

      final decoded = await _decodeImage(bytes);

      if (!mounted) return;

      setState(() {
        _attachKind = _AttachKind.image;
        _pickedFile = file;
        _previewImageBytes = bytes;
        _fileName = file.name;
        _fileBytes = bytes.length;
        _imgW = decoded.$1;
        _imgH = decoded.$2;
        _linkPreview = null;
        _linkError = null;
      });

      await _saveDraft();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not pick image: $e')));
    }
  }

  Future<void> _pickVideo() async {
    if (_posting) return;
    if (_isReply) return;

    try {
      final picker = ImagePicker();
      final file = await picker.pickVideo(source: ImageSource.gallery);
      if (file == null) return;

      final length = await file.length();

      // Hard client-side guard to match backend (50MB)
      const max = 50 * 1024 * 1024;
      if (length > max) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video too large (max 50MB).')),
        );
        return;
      }

      if (!mounted) return;

      setState(() {
        _attachKind = _AttachKind.video;
        _pickedFile = file;
        _previewImageBytes = null;
        _fileName = file.name;
        _fileBytes = length;
        _imgW = null;
        _imgH = null;
        _linkPreview = null;
        _linkError = null;
      });

      await _saveDraft();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not pick video: $e')));
    }
  }

  void _attachLink() {
    if (_posting) return;
    if (_isReply) return;

    setState(() {
      _attachKind = _AttachKind.link;
      _pickedFile = null;
      _previewImageBytes = null;
      _fileName = null;
      _fileBytes = null;
      _imgW = null;
      _imgH = null;
      _linkPreview = null;
      _linkError = null;
    });
  }

  Future<void> _fetchLinkPreview() async {
    if (_posting) return;
    if (_attachKind != _AttachKind.link) return;

    final raw = _linkController.text.trim();
    if (raw.isEmpty) return;

    final url = _normalizeUrl(raw);
    if (url == null) {
      setState(() {
        _linkError = 'Invalid link.';
        _linkPreview = null;
      });
      return;
    }

    setState(() {
      _linkLoading = true;
      _linkError = null;
      _linkPreview = null;
    });

    try {
      final repo = ref.read(_postsRepoProvider);
      final preview = await repo.fetchLinkPreview(url: url);

      if (!mounted) return;

      setState(() {
        _linkPreview = preview;
        _fileName = url;
        _fileBytes = null;
        _linkError = null;
      });

      await _saveDraft();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _linkError = 'Could not preview link.';
        _linkPreview = null;
      });
    } finally {
      if (mounted) setState(() => _linkLoading = false);
    }
  }

  void _removeAttachment() {
    setState(() {
      _attachKind = _AttachKind.none;
      _pickedFile = null;
      _previewImageBytes = null;
      _fileName = null;
      _fileBytes = null;
      _imgW = null;
      _imgH = null;
      _linkPreview = null;
      _linkError = null;
      _linkController.clear();
    });
  }

  Future<void> _publish() async {
    if (_posting) return;

    final text = _controller.text.trim();
    if (text.isEmpty) return;

    if (text.length > _limit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Too long. Keep it under 2000 characters.')),
      );
      return;
    }

    setState(() => _posting = true);

    try {
      final repo = ref.read(_postsRepoProvider);

      if (_isReply) {
        // Replies: text only (avoid breaking backend DTO unexpectedly)
        final dio = ref.read(dioProvider);
        await dio.post('/posts/${widget.replyToPostId}/reply', data: {'text': text});
        _controller.clear();
        _removeAttachment();
        if (!mounted) return;
        context.pop(true);
        return;
      }

      // 1) If attachment is IMAGE or VIDEO: presign + upload + markReady
      String? uploadedPublicUrl;
      String? uploadedMediaId;

      if (_attachKind == _AttachKind.image || _attachKind == _AttachKind.video) {
        if (_pickedFile == null) {
          throw Exception('No file selected')
        }

        final mime = await _inferMimeType(_pickedFile!);
        final bytes = await _pickedFile!.readAsBytes();

        // match backend limits (image 10MB, video 50MB)
        if (_attachKind == _AttachKind.image && bytes.length > 10 * 1024 * 1024) {
          throw Exception('Image too large (max 10MB)')
        }
        if (_attachKind == _AttachKind.video && bytes.length > 50 * 1024 * 1024) {
          throw Exception('Video too large (max 50MB)')
        }

        final presigned = await repo.presignMedia(
          fileName: _pickedFile!.name,
          mimeType: mime,
          bytes: bytes.length,
          kind: _attachKind == _AttachKind.image ? 'IMAGE' : 'VIDEO',
          width: _attachKind == _AttachKind.image ? _imgW : null,
          height: _attachKind == _AttachKind.image ? _imgH : null,
        );

        uploadedMediaId = presigned['mediaId']?.toString();
        uploadedPublicUrl = presigned['publicUrl']?.toString();
        final upload = Map<String, dynamic>.from(presigned['upload'] as Map);

        final uploadUrl = upload['url']?.toString() ?? '';
        final headers = Map<String, dynamic>.from(upload['headers'] as Map);

        await repo.uploadToPresignedUrl(
          url: uploadUrl,
          headers: headers,
          mimeType: mime,
          bytes: bytes,
        );

        if (uploadedMediaId != null) {
          // best effort
          unawaited(repo.markMediaReady(uploadedMediaId));
        }
      }

      // 2) Save draft with final media fields
      await repo.saveDraft(
        text: _controller.text,
        mediaType: _draftMediaType(),
        mediaUrl: _attachKind == _AttachKind.link ? _linkPreview?['url']?.toString() : uploadedPublicUrl,
        mediaThumbUrl: _attachKind == _AttachKind.link ? _linkPreview?['image']?.toString() : null,
        mediaWidth: _attachKind == _AttachKind.image ? _imgW : null,
        mediaHeight: _attachKind == _AttachKind.image ? _imgH : null,
        // video duration unknown in phase 1
        mediaDuration: null,
        caption: _attachKind == _AttachKind.link ? _linkPreview?['title']?.toString() : null,
        linkTitle: _linkPreview?['title']?.toString(),
        linkDescription: _linkPreview?['description']?.toString(),
        linkImageUrl: _linkPreview?['image']?.toString(),
      );

      // 3) Publish draft
      await repo.publishDraft();

      _controller.clear();
      _removeAttachment();
      if (!mounted) return;
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not publish: $e')));
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  String? _normalizeUrl(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;

    // If user writes "example.com", treat as https://example.com
    if (!s.startsWith('http://') && !s.startsWith('https://')) {
      final candidate = 'https://$s';
      return Uri.tryParse(candidate)?.hasAbsolutePath == true ? candidate : null;
    }

    final u = Uri.tryParse(s);
    if (u == null) return null;
    if (u.scheme != 'http' && u.scheme != 'https') return null;
    return s;
  }

  Future<(int, int)> _decodeImage(Uint8List bytes) async {
    final c = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, (img) => c.complete(img));
    final img = await c.future;
    return (img.width, img.height);
  }

  Future<String> _inferMimeType(XFile file) async {
    // image_picker may not always provide mimeType across platforms.
    // We infer from extension as a safe default.
    final name = file.name.toLowerCase();

    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
    if (name.endsWith('.webp')) return 'image/webp';

    if (name.endsWith('.mp4')) return 'video/mp4';
    if (name.endsWith('.mov')) return 'video/quicktime';
    if (name.endsWith('.webm')) return 'video/webm';

    // fallback
    return _attachKind == _AttachKind.video ? 'video/mp4' : 'image/jpeg';
  }

  String _humanBytes(int? n) {
    if (n == null) return '';
    if (n < 1024) return '${n}B';
    final kb = n / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(0)}KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)}MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(1)}GB';
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _limit - _controller.text.trim().length;

    return AuraScaffold(
      title: _isReply ? 'Reply' : 'Compose',
      actions: [
        TextButton(
          onPressed: _posting ? null : _discardDraft,
          child: const Text('Discard'),
        ),
        TextButton(
          onPressed: (_posting || !_hasText) ? null : _publish,
          child: Text(_posting ? 'Publishing…' : 'Publish'),
        ),
      ],
      body: ListView(
        padding: EdgeInsets.fromLTRB(AuraSpace.s16, AuraSpace.s12, AuraSpace.s16, AuraSpace.s24),
        children: [
          AuraCard(
            child: Padding(
              padding: const EdgeInsets.all(AuraSpace.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _isReply ? 'Reply with care.' : 'Write something worth carrying.',
                          style: AuraText.title,
                        ),
                      ),
                      if (!_isReply) ...[
                        if (_loadingDraft)
                          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                        const SizedBox(width: AuraSpace.s10),
                        if (_savingDraft)
                          Text('Saving…', style: AuraText.small.copyWith(color: const Color(0xFF6F6F6F))),
                      ],
                    ],
                  ),
                  const SizedBox(height: AuraSpace.s10),

                  // Attach controls (main compose only)
                  if (!_isReply) ...[
                    Wrap(
                      spacing: AuraSpace.s10,
                      runSpacing: AuraSpace.s10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _posting ? null : _pickImage,
                          icon: const Icon(Icons.image_outlined),
                          label: const Text('Image'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _posting ? null : _pickVideo,
                          icon: const Icon(Icons.videocam_outlined),
                          label: const Text('Video'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _posting ? null : _attachLink,
                          icon: const Icon(Icons.link),
                          label: const Text('Link'),
                        ),
                        if (_hasAttachment)
                          TextButton(
                            onPressed: _posting ? null : _removeAttachment,
                            child: const Text('Remove'),
                          ),
                      ],
                    ),
                    const SizedBox(height: AuraSpace.s12),
                  ],

                  // Attachment preview area
                  if (_hasAttachment) ...[
                    if (_attachKind == _AttachKind.image && _previewImageBytes != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(_previewImageBytes!, fit: BoxFit.cover),
                      ),
                      if ((_fileName ?? '').trim().isNotEmpty || _fileBytes != null) ...[
                        const SizedBox(height: AuraSpace.s8),
                        Text(
                          [
                            if ((_fileName ?? '').trim().isNotEmpty) _fileName!.trim(),
                            if (_fileBytes != null) _humanBytes(_fileBytes),
                            if (_imgW != null && _imgH != null) '${_imgW}×${_imgH}',
                          ].join(' • '),
                          style: AuraText.small.copyWith(color: const Color(0xFF6F6F6F)),
                        ),
                      ],
                      const SizedBox(height: AuraSpace.s12),
                    ] else if (_attachKind == _AttachKind.video) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AuraSpace.s14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE0E0E0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.videocam_outlined),
                            const SizedBox(width: AuraSpace.s10),
                            Expanded(
                              child: Text(
                                [
                                  _fileName?.trim().isNotEmpty == true ? _fileName!.trim() : 'Video selected',
                                  if (_fileBytes != null) _humanBytes(_fileBytes),
                                ].where((s) => s.trim().isNotEmpty).join(' • '),
                                style: AuraText.body,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AuraSpace.s12),
                      Text(
                        'Phase 1: upload + playback on post. No transcoding yet.',
                        style: AuraText.small.copyWith(color: const Color(0xFF6F6F6F)),
                      ),
                      const SizedBox(height: AuraSpace.s12),
                    ] else if (_attachKind == _AttachKind.link) ...[
                      TextField(
                        controller: _linkController,
                        decoration: const InputDecoration(
                          hintText: 'Paste a link…',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _fetchLinkPreview(),
                      ),
                      const SizedBox(height: AuraSpace.s10),
                      Row(
                        children: [
                          FilledButton(
                            onPressed: (_posting || _linkLoading) ? null : _fetchLinkPreview,
                            child: Text(_linkLoading ? 'Previewing…' : 'Preview'),
                          ),
                          const SizedBox(width: AuraSpace.s10),
                          if (_linkError != null)
                            Expanded(
                              child: Text(_linkError!, style: AuraText.small.copyWith(color: Colors.red)),
                            ),
                        ],
                      ),
                      const SizedBox(height: AuraSpace.s12),
                      if (_linkPreview != null) _LinkPreviewCard(preview: _linkPreview!),
                      const SizedBox(height: AuraSpace.s12),
                    ],
                  ],

                  TextField(
                    controller: _controller,
                    maxLength: _limit,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      hintText: 'Draft here…',
                      border: InputBorder.none,
                      counterText: '',
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AuraSpace.s8),
          Text(
            remaining >= 0 ? '$remaining characters remaining' : '${remaining.abs()} over limit',
            style: AuraText.small.copyWith(
              color: remaining >= 0 ? const Color(0xFF6F6F6F) : Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: AuraSpace.s16),
          FilledButton.icon(
            onPressed: (_posting || !_hasText) ? null : _publish,
            icon: _posting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send),
            label: Text(_posting ? 'Publishing…' : 'Publish'),
          ),
        ],
      ),
    );
  }
}

class _LinkPreviewCard extends StatelessWidget {
  const _LinkPreviewCard({required this.preview});

  final Map<String, dynamic> preview;

  @override
  Widget build(BuildContext context) {
    final title = (preview['title'] ?? '').toString().trim();
    final desc = (preview['description'] ?? '').toString().trim();
    final image = (preview['image'] ?? '').toString().trim();
    final url = (preview['url'] ?? '').toString().trim();

    return AuraCard(
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.s14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (image.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox()),
              ),
            if (image.isNotEmpty) const SizedBox(height: AuraSpace.s10),
            if (title.isNotEmpty)
              Text(title, style: AuraText.body.copyWith(fontWeight: FontWeight.w800)),
            if (title.isNotEmpty) const SizedBox(height: AuraSpace.s6),
            if (desc.isNotEmpty) Text(desc, style: AuraText.body),
            if (desc.isNotEmpty) const SizedBox(height: AuraSpace.s8),
            Text(url, style: AuraText.small.copyWith(color: const Color(0xFF6F6F6F))),
          ],
        ),
      ),
    );
  }
}