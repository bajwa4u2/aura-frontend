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
  bool get _canPublish => _controller.text.trim().isNotEmpty;
  bool get _hasText => _controller.text.trim().isNotEmpty;
  bool get _hasAttachment => _attachKind != _AttachKind.none;

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
    final root = _asMap(v);
    final d = root['data'];
    if (d is Map) return _asMap(d);
    return root;
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _removeAttachment() {
    setState(() {
      _attachKind = _AttachKind.none;
      _pickedFile = null;
      _pickedBytes = null;
      _imgW = null;
      _imgH = null;
      _linkText = null;
      _linkPreview = null;
    });
  }

  Map<String, dynamic>? _postToMap(dynamic v) {
    if (v is Post) return (v).toJson();
    if (v is Map) return Map<String, dynamic>.from(v as Map);
    return null;
  }

  Map<String, dynamic>? _mapOrNull(dynamic v) {
    if (v == null) return null;
    if (v is Map) return Map<String, dynamic>.from(v as Map);
    return null;
  }

  Map<String, dynamic> _ensureMap(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v as Map);
    return <String, dynamic>{};
  }

  String _inferMimeType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.webm')) return 'video/webm';
    return 'application/octet-stream';
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      imageQuality: 92,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    final decoded = await _decodeImage(bytes);

    setState(() {
      _attachKind = _AttachKind.image;
      _pickedFile = file;
      _pickedBytes = bytes;
      _imgW = decoded.$1;
      _imgH = decoded.$2;
      _linkText = null;
      _linkPreview = null;
    });
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

  Future<(int, int)> _decodeImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    return (image.width, image.height);
  }

  Future<void> _setLink() async {
    final url = _linkText?.trim() ?? '';
    if (url.isEmpty) return;
    if (_fetchingPreview) return;

    setState(() => _fetchingPreview = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post('/links/preview', data: {'url': url});
      final body = _ensureMap(res.data);
      final payload = (body['data'] is Map) ? _ensureMap(body['data']) : body;

      setState(() {
        _attachKind = _AttachKind.link;
        _linkPreview = payload;
        _pickedFile = null;
        _pickedBytes = null;
        _imgW = null;
        _imgH = null;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not fetch link preview.')),
      );
    } finally {
      if (mounted) setState(() => _fetchingPreview = false);
    }
  }

  String? _linkUrl() => _linkPreview?['url']?.toString();
  String? _linkTitle() => _linkPreview?['title']?.toString();
  String? _linkDescription() => _linkPreview?['description']?.toString();
  String? _linkImage() => _linkPreview?['image']?.toString();

  String _draftMediaType() {
    switch (_attachKind) {
      case _AttachKind.image:
        return 'IMAGE';
      case _AttachKind.video:
        return 'VIDEO';
      case _AttachKind.link:
        return 'LINK';
      case _AttachKind.none:
      default:
        return 'NONE';
    }
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

      await dio.post('/posts/draft/publish');

      _controller.clear();
      _removeAttachment();
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
  Widget build(BuildContext context) {
    return AuraScaffold(
      title: 'Compose',
      showBack: true,
      actions: [
        TextButton(
          onPressed: _posting
              ? null
              : () async {
                  _controller.clear();
                  _removeAttachment();
                  if (!mounted) return;
                  context.pop(false);
                },
          child: const Text('Discard'),
        ),
        TextButton(
          onPressed: (_posting || !_canPublish) ? null : _publish,
          child: const Text('Publish'),
        ),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: AuraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Write something worth carrying.',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _posting ? null : _pickImage,
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Image'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _posting ? null : _pickVideo,
                    icon: const Icon(Icons.videocam_outlined),
                    label: const Text('Video'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _posting
                        ? null
                        : () async {
                            final v = await showDialog<String>(
                              context: context,
                              builder: (ctx) {
                                final c = TextEditingController(text: _linkText ?? '');
                                return AlertDialog(
                                  title: const Text('Link'),
                                  content: TextField(
                                    controller: c,
                                    decoration: const InputDecoration(hintText: 'Paste a URL'),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, c.text.trim()),
                                      child: const Text('Add'),
                                    ),
                                  ],
                                );
                              },
                            );
                            if (v == null) return;
                            setState(() {
                              _linkText = v;
                            });
                            await _setLink();
                          },
                    icon: const Icon(Icons.link),
                    label: const Text('Link'),
                  ),
                  const SizedBox(width: 16),
                  TextButton(
                    onPressed: _hasAttachment ? _removeAttachment : null,
                    child: const Text('Remove'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                minLines: 6,
                maxLines: 14,
                decoration: InputDecoration(
                  hintText: _isReply ? 'Write a reply…' : 'Write…',
                  border: const OutlineInputBorder(),
                  helperText: '${_controller.text.trim().length}/$_limit',
                ),
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