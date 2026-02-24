import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';

enum _AttachKind { none, image, video, link }

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

  XFile? _pickedFile;
  Uint8List? _previewImageBytes;
  String? _fileName;
  int? _fileBytes;
  int? _imgW;
  int? _imgH;

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
      final dio = ref.read(dioProvider);

      await dio.put('/posts/draft', data: {
        'text': _controller.text,
        'mediaType': _draftMediaType(),
        if (_attachKind == _AttachKind.link) 'mediaUrl': _linkUrl(),
        if (_attachKind == _AttachKind.link) 'mediaThumbUrl': _linkImage(),
        if (_attachKind == _AttachKind.image) 'mediaWidth': _imgW,
        if (_attachKind == _AttachKind.image) 'mediaHeight': _imgH,
        if (_attachKind == _AttachKind.link) 'caption': _linkTitle(),
        if (_attachKind == _AttachKind.link) 'linkTitle': _linkTitle(),
        if (_attachKind == _AttachKind.link) 'linkDescription': _linkDescription(),
        if (_attachKind == _AttachKind.link) 'linkImageUrl': _linkImage(),
      });

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

  String? _linkUrl() => _linkPreview == null ? null : (_linkPreview!['url']?.toString());
  String? _linkTitle() => _linkPreview == null ? null : (_linkPreview!['title']?.toString());
  String? _linkDescription() => _linkPreview == null ? null : (_linkPreview!['description']?.toString());
  String? _linkImage() => _linkPreview == null ? null : (_linkPreview!['image']?.toString());

  Future<void> _pickImage() async {
    if (_posting) return;
    if (_isReply) return;

    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 92);
      if (file == null) return;

      final bytes = await file.readAsBytes();
      final dims = await _decodeImage(bytes);

      if (!mounted) return;

      setState(() {
        _attachKind = _AttachKind.image;
        _pickedFile = file;
        _previewImageBytes = bytes;
        _fileName = file.name;
        _fileBytes = bytes.length;
        _imgW = dims.$1;
        _imgH = dims.$2;
        _linkPreview = null;
        _linkError = null;
        _linkController.clear();
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

      const max = 50 * 1024 * 1024;
      if (length > max) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Video too large (max 50MB).')));
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
        _linkController.clear();
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
      final dio = ref.read(dioProvider);
      final res = await dio.post('/media/link-preview', data: {'url': url});
      final preview = Map<String, dynamic>.from(res.data as Map);

      if (!mounted) return;

      setState(() {
        _linkPreview = preview;
        _fileName = url;
        _fileBytes = null;
        _linkError = null;
      });

      await _saveDraft();
    } catch (_) {
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
      final dio = ref.read(dioProvider);

      if (_isReply) {
        await dio.post('/posts/${widget.replyToPostId}/reply', data: {'text': text});
        _controller.clear();
        _removeAttachment();
        if (!mounted) return;
        context.pop(true);
        return;
      }

      // IMAGE / VIDEO: presign + PUT upload + update draft with mediaUrl
      String? uploadedPublicUrl;

      if (_attachKind == _AttachKind.image || _attachKind == _AttachKind.video) {
        if (_pickedFile == null) {
          throw Exception('No file selected');
        }

        final mime = _inferMimeType(_pickedFile!.name);
        final bytes = await _pickedFile!.readAsBytes();

        if (_attachKind == _AttachKind.image && bytes.length > 10 * 1024 * 1024) {
          throw Exception('Image too large (max 10MB)');
        }
        if (_attachKind == _AttachKind.video && bytes.length > 50 * 1024 * 1024) {
          throw Exception('Video too large (max 50MB)');
        }

        final pres = await dio.post('/media/presign', data: {
          'fileName': _pickedFile!.name,
          'mimeType': mime,
          'bytes': bytes.length,
          'kind': _attachKind == _AttachKind.image ? 'IMAGE' : 'VIDEO',
          if (_attachKind == _AttachKind.image) 'width': _imgW,
          if (_attachKind == _AttachKind.image) 'height': _imgH,
        });

        final presigned = Map<String, dynamic>.from(pres.data as Map);
        uploadedPublicUrl = presigned['publicUrl']?.toString();

        final upload = Map<String, dynamic>.from(presigned['upload'] as Map);
        final uploadUrl = upload['url']?.toString() ?? '';
        final headers = Map<String, dynamic>.from(upload['headers'] as Map);

        // PUT to presigned URL (absolute)
        await dio.put(
          uploadUrl,
          data: bytes,
          options: Options(
            headers: headers.map((k, v) => MapEntry(k.toString(), v.toString())),
            contentType: mime,
            responseType: ResponseType.plain,
            validateStatus: (code) => code != null && code >= 200 && code < 300,
          ),
        );
      }

      // Save final draft payload
      await dio.put('/posts/draft', data: {
        'text': _controller.text,
        'mediaType': _draftMediaType(),
        if (_attachKind == _AttachKind.link) 'mediaUrl': _linkUrl(),
        if (_attachKind == _AttachKind.link) 'mediaThumbUrl': _linkImage(),
        if (_attachKind == _AttachKind.link) 'caption': _linkTitle(),
        if (_attachKind == _AttachKind.link) 'linkTitle': _linkTitle(),
        if (_attachKind == _AttachKind.link) 'linkDescription': _linkDescription(),
        if (_attachKind == _AttachKind.link) 'linkImageUrl': _linkImage(),
        if (_attachKind == _AttachKind.image) 'mediaWidth': _imgW,
        if (_attachKind == _AttachKind.image) 'mediaHeight': _imgH,
        if (_attachKind == _AttachKind.image || _attachKind == _AttachKind.video) 'mediaUrl': uploadedPublicUrl,
      });

      await dio.post('/posts/draft/publish');

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

    if (!s.startsWith('http://') && !s.startsWith('https://')) {
      final candidate = 'https://$s';
      final u = Uri.tryParse(candidate);
      if (u == null) return null;
      if (u.scheme != 'https') return null;
      if (u.host.trim().isEmpty) return null;
      return candidate;
    }

    final u = Uri.tryParse(s);
    if (u == null) return null;
    if (u.scheme != 'http' && u.scheme != 'https') return null;
    if (u.host.trim().isEmpty) return null;
    return s;
  }

  Future<(int, int)> _decodeImage(Uint8List bytes) async {
    final c = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, (img) => c.complete(img));
    final img = await c.future;
    return (img.width, img.height);
  }

  String _inferMimeType(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.jpg') || n.endsWith('.jpeg')) return 'image/jpeg';
    if (n.endsWith('.webp')) return 'image/webp';

    if (n.endsWith('.mp4')) return 'video/mp4';
    if (n.endsWith('.mov')) return 'video/quicktime';
    if (n.endsWith('.webm')) return 'video/webm';

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
                        if (_savingDraft) Text('Saving…', style: AuraText.small),
                      ],
                    ],
                  ),
                  const SizedBox(height: AuraSpace.s10),

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

                  if (_hasAttachment) ...[
                    if (_attachKind == _AttachKind.image && _previewImageBytes != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(_previewImageBytes!, fit: BoxFit.cover),
                      ),
                      const SizedBox(height: AuraSpace.s8),
                      Text(
                        [
                          if ((_fileName ?? '').trim().isNotEmpty) _fileName!.trim(),
                          if (_fileBytes != null) _humanBytes(_fileBytes),
                          if (_imgW != null && _imgH != null) '${_imgW}×${_imgH}',
                        ].join(' • '),
                        style: AuraText.small,
                      ),
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
                          if (_linkError != null) Expanded(child: Text(_linkError!, style: AuraText.small)),
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
            style: AuraText.small,
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
            if (title.isNotEmpty) Text(title, style: AuraText.body),
            if (title.isNotEmpty) const SizedBox(height: AuraSpace.s6),
            if (desc.isNotEmpty) Text(desc, style: AuraText.body),
            if (desc.isNotEmpty) const SizedBox(height: AuraSpace.s8),
            Text(url, style: AuraText.small),
          ],
        ),
      ),
    );
  }
}