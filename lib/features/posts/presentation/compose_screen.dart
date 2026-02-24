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
  bool _fetchingLink = false;

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

  Future<Uint8List> _readXFileBytes(XFile f) async {
    return await f.readAsBytes();
  }

  Future<void> _decodeImageSize(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    setState(() {
      _imgW = image.width;
      _imgH = image.height;
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    final bytes = await _readXFileBytes(file);
    setState(() {
      _attachKind = _AttachKind.image;
      _pickedFile = file;
      _pickedBytes = bytes;
      _linkText = null;
      _linkPreview = null;
    });

    // Attempt to read dimensions (best-effort)
    try {
      await _decodeImageSize(bytes);
    } catch (_) {
      // ignore
    }
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

  Future<void> _fetchLinkPreview() async {
    final text = _controller.text.trim();
    final urlMatch = RegExp(r'(https?:\/\/[^\s]+)').firstMatch(text);
    final url = urlMatch?.group(0);

    if (url == null || url.isEmpty) {
      setState(() {
        _attachKind = _AttachKind.none;
        _linkText = null;
        _linkPreview = null;
      });
      return;
    }

    setState(() {
      _fetchingLink = true;
      _attachKind = _AttachKind.link;
      _linkText = url;
      _pickedFile = null;
      _pickedBytes = null;
      _imgW = null;
      _imgH = null;
    });

    try {
      final repo = ref.read(postRepositoryProvider);
      final previewRaw = await repo.previewLink(url);
      final preview = _mapOrNull(previewRaw) ?? _postToMap(previewRaw) ?? _ensureMap(previewRaw);

      if (!mounted) return;
      setState(() {
        _linkPreview = preview.isEmpty ? null : preview;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _linkPreview = null;
      });
    } finally {
      if (mounted) setState(() => _fetchingLink = false);
    }
  }

  bool get _canPublish {
    if (_posting) return false;
    final text = _controller.text.trim();
    if (text.isNotEmpty) return true;
    if (_attachKind == _AttachKind.image && _pickedFile != null) return true;
    if (_attachKind == _AttachKind.video && _pickedFile != null) return true;
    if (_attachKind == _AttachKind.link && (_linkText ?? '').trim().isNotEmpty) return true;
    return false;
  }

  Future<Map<String, dynamic>> _createUploadIntent({
    required String mimeType,
    required int sizeBytes,
    required int? width,
    required int? height,
    required int? duration,
  }) async {
    final dio = ref.read(dioProvider);

    final res = await dio.post(
      '/v1/media/intent',
      data: <String, dynamic>{
        'mimeType': mimeType,
        'sizeBytes': sizeBytes,
        'width': width,
        'height': height,
        'duration': duration,
      },
    );

    final raw = res.data;
    if (raw is Map && raw['data'] is Map) {
      return Map<String, dynamic>.from(raw['data'] as Map);
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    throw Exception('Unexpected media intent response');
  }

  Future<void> _putToPresignedUrl({
    required String uploadUrl,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final dio = Dio(
      BaseOptions(
        // Presigned URL is absolute; do not use API base.
        followRedirects: true,
        validateStatus: (s) => s != null && s >= 200 && s < 400,
      ),
    );

    await dio.put(
      uploadUrl,
      data: Stream.fromIterable([bytes]),
      options: Options(
        headers: <String, dynamic>{
          'Content-Type': contentType,
          'Content-Length': bytes.length,
        },
      ),
    );
  }

  Future<Map<String, dynamic>?> _uploadIfNeeded() async {
    if (_attachKind == _AttachKind.none) return null;

    if (_attachKind == _AttachKind.link) {
      if ((_linkText ?? '').trim().isEmpty) return null;
      return <String, dynamic>{
        'type': 'LINK',
        'url': _linkText,
        'preview': _linkPreview,
      };
    }

    final file = _pickedFile;
    if (file == null) return null;

    final bytes = await _readXFileBytes(file);
    final mimeType = _inferMimeType(file.name);

    final kind = _attachKind == _AttachKind.video ? 'VIDEO' : 'IMAGE';

    final intent = await _createUploadIntent(
      mimeType: mimeType,
      sizeBytes: bytes.length,
      width: _imgW,
      height: _imgH,
      duration: null,
    );

    final uploadUrl = (intent['uploadUrl'] ?? '').toString();
    final publicUrl = (intent['publicUrl'] ?? intent['url'] ?? '').toString();
    final thumbUrl = (intent['thumbUrl'] as String?)?.toString();

    if (uploadUrl.isEmpty || publicUrl.isEmpty) {
      throw Exception('Media intent missing uploadUrl/publicUrl');
    }

    await _putToPresignedUrl(
      uploadUrl: uploadUrl,
      bytes: bytes,
      contentType: mimeType,
    );

    return <String, dynamic>{
      'type': kind,
      'url': publicUrl,
      'thumbUrl': thumbUrl,
      'width': _imgW,
      'height': _imgH,
      'duration': null,
    };
  }

  Future<void> _publish() async {
    if (_posting) return;

    final text = _controller.text.trim();
    if (text.length > _limit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Too long. Please shorten your post.')),
      );
      return;
    }

    setState(() => _posting = true);

    try {
      final media = await _uploadIfNeeded();

      final repo = ref.read(postRepositoryProvider);
      await repo.publish(
        text: text.isEmpty ? null : text,
        replyToPostId: widget.replyToPostId,
        media: media,
        caption: null,
      );

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
      leading: SizedBox(
        width: 36,
        height: 36,
        child: IconButton(
          tooltip: 'Back',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 36, height: 36),
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            final canPop = Navigator.of(context).canPop() || GoRouter.of(context).canPop();
            if (canPop) {
              context.pop();
            } else {
              context.go('/member');
            }
          },
        ),
      ),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: AuraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Write',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                maxLines: null,
                minLines: 6,
                decoration: const InputDecoration(
                  hintText: 'What do you want to say?',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) {
                  setState(() {});
                },
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
                    onPressed: _posting ? null : _fetchLinkPreview,
                    icon: const Icon(Icons.link),
                    label: Text(_fetchingLink ? 'Checking…' : 'Link'),
                  ),
                  const Spacer(),
                  Text(
                    '${_controller.text.trim().length}/$_limit',
                    style: TextStyle(
                      color: _controller.text.trim().length > _limit
                          ? Colors.red
                          : Colors.black54,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_attachKind != _AttachKind.none) ...[
                Row(
                  children: [
                    const Text(
                      'Attachment',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _posting ? null : _removeAttachment,
                      child: const Text('Remove'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (_attachKind == _AttachKind.image && _pickedBytes != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(_pickedBytes!, fit: BoxFit.cover),
                ),
                const SizedBox(height: 8),
                if (_imgW != null && _imgH != null)
                  Text(
                    '$_imgW × $_imgH',
                    style: const TextStyle(color: Colors.black54),
                  ),
              ],
              if (_attachKind == _AttachKind.video && _pickedFile != null) ...[
                const Icon(Icons.videocam, size: 40),
                const SizedBox(height: 8),
                Text(
                  _pickedFile!.name,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
              if (_attachKind == _AttachKind.link) ...[
                Text(
                  _linkText ?? '',
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 8),
                if (_fetchingLink) const LinearProgressIndicator(),
                if (!_fetchingLink && _linkPreview != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      const JsonEncoder.withIndent('  ').convert(_linkPreview),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                ],
                if (!_fetchingLink && _linkPreview == null)
                  const Text(
                    'No preview available.',
                    style: TextStyle(color: Colors.black54),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}