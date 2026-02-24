import 'dart:async';
import 'dart:convert';
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
import '../../feed/data/post_repository.dart';
import '../../feed/post_model.dart';

class ComposeScreen extends ConsumerStatefulWidget {
  final String? replyToPostId;
  const ComposeScreen({super.key, this.replyToPostId});

  @override
  ConsumerState<ComposeScreen> createState() => _ComposeScreenState();
}

enum _AttachKind { none, image, video, link }

class _ComposeScreenState extends ConsumerState<ComposeScreen> {
  static const int _limit = 2000;

  final _controller = TextEditingController();
  bool _posting = false;

  _AttachKind _attachKind = _AttachKind.none;

  XFile? _pickedFile;
  Uint8List? _pickedBytes; // for web preview
  int? _imgW;
  int? _imgH;

  String? _linkText;
  Map<String, dynamic>? _linkPreview;
  bool _fetchingPreview = false;

  bool get _isReply => widget.replyToPostId != null;
  bool get _hasText => _controller.text.trim().isNotEmpty;
  bool get _hasMediaFile =>
      (_attachKind == _AttachKind.image || _attachKind == _AttachKind.video) && _pickedFile != null;
  bool get _hasLink => _attachKind == _AttachKind.link && (_linkUrl() ?? '').trim().isNotEmpty;

  bool get _canPublish {
    // allow text-only OR media-only OR link
    return _hasText || _hasMediaFile || _hasLink;
  }

  Map<String, dynamic> _asMap(dynamic v) {
    if (v == null) return <String, dynamic>{};
    if (v is Map) return Map<String, dynamic>.from(v as Map);
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return <String, dynamic>{};
      try {
        final decoded = jsonDecode(s);
        if (decoded is Map) return Map<String, dynamic>.from(decoded as Map);
      } catch (_) {
        // ignore
      }
    }
    return <String, dynamic>{};
  }

  Map<String, dynamic> _unwrapDataMap(dynamic v) {
    // Unwrap nested { ok:true, data:{ ok:true, data:{...} } } style envelopes
    Map<String, dynamic> cur = _asMap(v);
    while (cur.containsKey('ok') && cur.containsKey('data') && cur['data'] is Map) {
      cur = Map<String, dynamic>.from(cur['data'] as Map);
    }
    return cur;
  }

  String _inferMime(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.webm')) return 'video/webm';
    return 'application/octet-stream';
  }

  Dio _cleanUploadDio() {
    // Critical: presigned PUT must NOT include your API auth interceptors.
    return Dio(
      BaseOptions(
        responseType: ResponseType.plain,
        followRedirects: true,
      ),
    );
  }

  Future<void> _decodeImageSize(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final img = frame.image;
    setState(() {
      _imgW = img.width;
      _imgH = img.height;
    });
  }

  void _clearAttachment() {
    setState(() {
      _attachKind = _AttachKind.none;
      _pickedFile = null;
      _pickedBytes = null;
      _imgW = null;
      _imgH = null;
      _linkText = null;
      _linkPreview = null;
      _fetchingPreview = false;
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    final bytes = await file.readAsBytes();
    setState(() {
      _attachKind = _AttachKind.image;
      _pickedFile = file;
      _pickedBytes = bytes;
      _linkText = null;
      _linkPreview = null;
    });

    try {
      await _decodeImageSize(bytes);
    } catch (_) {}
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final file = await picker.pickVideo(source: ImageSource.gallery);
    if (file == null) return;

    setState(() {
      _attachKind = _AttachKind.video;
      _pickedFile = file;
      _pickedBytes = null;
      _imgW = null;
      _imgH = null;
      _linkText = null;
      _linkPreview = null;
    });
  }

  String? _firstUrlInText() {
    final text = _controller.text;
    final m = RegExp(r'(https?:\/\/[^\s]+)').firstMatch(text);
    return m?.group(0);
  }

  String? _linkUrl() => _linkText ?? _firstUrlInText();

  String? _linkTitle() {
    final m = _linkPreview ?? const <String, dynamic>{};
    final t = (m['title'] ?? m['ogTitle'] ?? m['siteName'])?.toString();
    return (t == null || t.trim().isEmpty) ? null : t.trim();
  }

  String? _linkDescription() {
    final m = _linkPreview ?? const <String, dynamic>{};
    final d = (m['description'] ?? m['ogDescription'])?.toString();
    return (d == null || d.trim().isEmpty) ? null : d.trim();
  }

  String? _linkImage() {
    final m = _linkPreview ?? const <String, dynamic>{};
    final u = (m['imageUrl'] ?? m['ogImage'])?.toString();
    return (u == null || u.trim().isEmpty) ? null : u.trim();
  }

  String? _draftMediaType() {
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

  Future<void> _attachLink() async {
    final url = _firstUrlInText();
    if (url == null || url.trim().isEmpty) {
      setState(() {
        _attachKind = _AttachKind.link;
        _linkText = null;
        _linkPreview = null;
      });
      return;
    }

    setState(() {
      _attachKind = _AttachKind.link;
      _linkText = url;
      _pickedFile = null;
      _pickedBytes = null;
      _imgW = null;
      _imgH = null;
      _linkPreview = null;
      _fetchingPreview = true;
    });

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post('/media/link-preview', data: {'url': url});
      final preview = _unwrapDataMap(res.data);
      if (!mounted) return;
      setState(() => _linkPreview = preview);
    } catch (_) {
      if (!mounted) return;
      setState(() => _linkPreview = null);
    } finally {
      if (mounted) setState(() => _fetchingPreview = false);
    }
  }

  Future<void> _publish() async {
    if (_posting) return;

    final trimmed = _controller.text.trim();
    if (trimmed.length > _limit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Too long. Please shorten your post.')),
      );
      return;
    }

    setState(() => _posting = true);

    try {
      final dio = ref.read(dioProvider);

      String? uploadedPublicUrl;

      // 1) If IMAGE/VIDEO selected, presign + upload to R2
      if (_pickedFile != null && (_attachKind == _AttachKind.image || _attachKind == _AttachKind.video)) {
        final mime = _inferMime(_pickedFile!.name);
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

        final presigned = _unwrapDataMap(pres.data);

        uploadedPublicUrl = (presigned['publicUrl'] ??
                presigned['url'] ??
                ((presigned['media'] is Map) ? _asMap(presigned['media'])['url'] : null))
            ?.toString();

        final upload = _asMap(presigned['upload']);
        final uploadUrl = (upload['url'] ?? '').toString();
        final headers = _asMap(upload['headers']);

        if (uploadUrl.isEmpty) {
          throw Exception('Upload URL missing from presign response.');
        }
        if (uploadedPublicUrl == null || uploadedPublicUrl!.trim().isEmpty) {
          throw Exception('publicUrl missing from presign response.');
        }

        // ✅ use clean Dio for presigned URL (no auth interceptors)
        final uploadDio = _cleanUploadDio();

        final uploadHeaders = <String, String>{};
        headers.forEach((k, v) {
          if (v == null) return;
          uploadHeaders[k.toString()] = v.toString();
        });

        // ensure Content-Type matches what backend signed
        if (!uploadHeaders.containsKey('Content-Type')) {
          uploadHeaders['Content-Type'] = mime;
        }

        await uploadDio.put(
          uploadUrl,
          data: bytes,
          options: Options(
            headers: uploadHeaders,
            contentType: uploadHeaders['Content-Type'],
            responseType: ResponseType.plain,
            followRedirects: true,
            validateStatus: (code) => code != null && code >= 200 && code < 300,
          ),
        );
      }

      // 2) Save draft
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
        if (_attachKind == _AttachKind.image || _attachKind == _AttachKind.video)
          'mediaUrl': uploadedPublicUrl,
      });

      // 3) Publish
      await dio.post('/posts/draft/publish');

      if (!mounted) return;
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not publish: $e')),
      );
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuraScaffold(
      title: 'Compose',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.pop(),
      ),
      actions: [
        TextButton(
          onPressed: _posting
              ? null
              : () {
                  _controller.clear();
                  _clearAttachment();
                  context.pop(false);
                },
          child: const Text('Discard'),
        ),
        TextButton(
          onPressed: (_posting || !_canPublish) ? null : _publish,
          child: const Text('Publish'),
        ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: AuraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Write', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                maxLines: null,
                minLines: 6,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: _isReply ? 'Write a reply…' : 'What do you want to say?',
                  border: const OutlineInputBorder(),
                  helperText: '${_controller.text.trim().length}/$_limit',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _posting ? null : _pickImage,
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Image'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _posting ? null : _pickVideo,
                    icon: const Icon(Icons.videocam_outlined),
                    label: const Text('Video'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _posting ? null : _attachLink,
                    icon: const Icon(Icons.link),
                    label: Text(_fetchingPreview ? 'Checking…' : 'Link'),
                  ),
                  const Spacer(),
                  if (_attachKind != _AttachKind.none)
                    TextButton(
                      onPressed: _posting ? null : _clearAttachment,
                      child: const Text('Remove'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (_attachKind == _AttachKind.image && _pickedBytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(_pickedBytes!, fit: BoxFit.cover),
                ),
              if (_attachKind == _AttachKind.video && _pickedFile != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_pickedFile!.name, style: const TextStyle(fontSize: 14)),
                ),
              if (_attachKind == _AttachKind.link && _linkPreview != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: AuraCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _linkTitle() ?? _linkUrl() ?? 'Link',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if ((_linkDescription() ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(_linkDescription()!),
                        ],
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