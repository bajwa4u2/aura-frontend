import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

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
  Uint8List? _pickedBytes; // preview
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
      _fetchingLink = false;
    });
  }

  Map<String, dynamic>? _postToMap(dynamic v) {
    if (v is Post) return v.toJson();
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

  // Unwraps nested envelopes like:
  // { ok:true, data:{ ok:true, data:{...} } }
  // until the payload is no longer in that shape.
  Map<String, dynamic> _unwrapEnvelopeDeep(Map<String, dynamic> m) {
    Map<String, dynamic> cur = m;
    while (cur.containsKey('ok') && cur.containsKey('data') && cur['data'] is Map) {
      cur = Map<String, dynamic>.from(cur['data'] as Map);
    }
    return cur;
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

  Future<Uint8List> _readXFileBytes(XFile f) async => await f.readAsBytes();

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
      _linkPreview = null;
    });

    try {
      final repo = ref.read(postRepositoryProvider);
      final raw = await repo.fetchLinkPreview(url: url);
      final payload = _unwrapEnvelopeDeep(raw);
      final preview = _mapOrNull(payload) ?? _postToMap(payload) ?? _ensureMap(payload);

      if (!mounted) return;
      setState(() => _linkPreview = preview.isEmpty ? null : preview);
    } catch (_) {
      if (!mounted) return;
      setState(() => _linkPreview = null);
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

  Future<Map<String, dynamic>?> _presignAndUploadIfNeeded() async {
    if (_attachKind == _AttachKind.none) return null;

    if (_attachKind == _AttachKind.link) {
      if ((_linkText ?? '').trim().isEmpty) return null;
      return <String, dynamic>{
        'kind': 'LINK',
        'url': _linkText,
        'preview': _linkPreview,
      };
    }

    final file = _pickedFile;
    if (file == null) return null;

    final bytes = await _readXFileBytes(file);
    final mimeType = _inferMimeType(file.name);
    final kind = _attachKind == _AttachKind.video ? 'VIDEO' : 'IMAGE';

    final repo = ref.read(postRepositoryProvider);

    final presignRaw = await repo.presignMedia(
      fileName: file.name,
      mimeType: mimeType,
      bytes: bytes.length,
      kind: kind,
      width: _imgW,
      height: _imgH,
    );

    // ✅ Your server returns { ok:true, data:{ ok:true, media:{...}, publicUrl, upload:{url,headers,method} } }
    final presign = _unwrapEnvelopeDeep(presignRaw);

    final publicUrl = (presign['publicUrl'] ?? '').toString();
    final mediaMap = _mapOrNull(presign['media']) ?? const <String, dynamic>{};
    final mediaId = (mediaMap['id'] ?? '').toString();

    final upload = _mapOrNull(presign['upload']) ?? const <String, dynamic>{};
    final uploadUrl = (upload['url'] ?? '').toString();
    final uploadMethod = (upload['method'] ?? 'PUT').toString().toUpperCase();
    final headersAny = upload['headers'];
    final headers = (headersAny is Map) ? Map<String, dynamic>.from(headersAny) : <String, dynamic>{};

    if (uploadUrl.isEmpty || publicUrl.isEmpty) {
      throw Exception('Presign response missing upload.url/publicUrl');
    }
    if (uploadMethod != 'PUT') {
      throw Exception('Unsupported presign method: $uploadMethod');
    }

    await repo.uploadToPresignedUrl(
      url: uploadUrl,
      headers: headers,
      mimeType: mimeType,
      bytes: bytes,
    );

    // Best-effort finalize
    if (mediaId.isNotEmpty) {
      try {
        await repo.markMediaReady(mediaId);
      } catch (_) {}
    }

    return <String, dynamic>{
      'kind': kind,
      'mediaUrl': publicUrl,
      'thumbUrl': null,
      'width': _imgW,
      'height': _imgH,
      'mediaId': mediaId,
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
      final repo = ref.read(postRepositoryProvider);
      final uploaded = await _presignAndUploadIfNeeded();

      String? mediaType;
      String? mediaUrl;
      int? mediaWidth;
      int? mediaHeight;

      String? linkTitle;
      String? linkDescription;
      String? linkImageUrl;

      if (uploaded != null) {
        final kind = (uploaded['kind'] ?? '').toString();

        if (kind == 'IMAGE' || kind == 'VIDEO') {
          mediaType = kind;
          mediaUrl = (uploaded['mediaUrl'] ?? '').toString();
          mediaWidth = uploaded['width'] as int?;
          mediaHeight = uploaded['height'] as int?;
        }

        if (kind == 'LINK') {
          final preview = uploaded['preview'];
          final m = _mapOrNull(preview) ?? _ensureMap(preview);
          linkTitle = (m['title'] as String?)?.toString();
          linkDescription = (m['description'] as String?)?.toString();
          linkImageUrl = (m['imageUrl'] as String?)?.toString();
          if (text.isEmpty && (uploaded['url'] as String?)?.isNotEmpty == true) {
            _controller.text = (uploaded['url'] as String).toString();
          }
        }
      }

      await repo.saveDraft(
        text: _controller.text.trim(),
        mediaType: mediaType,
        mediaUrl: mediaUrl,
        mediaThumbUrl: null,
        mediaWidth: mediaWidth,
        mediaHeight: mediaHeight,
        mediaDuration: null,
        caption: null,
        linkTitle: linkTitle,
        linkDescription: linkDescription,
        linkImageUrl: linkImageUrl,
      );

      await repo.publishDraft();

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
              : () {
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
              const Text('Write', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                maxLines: null,
                minLines: 6,
                decoration: const InputDecoration(
                  hintText: 'What do you want to say?',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
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
                      color: _controller.text.trim().length > _limit ? Colors.red : Colors.black54,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_attachKind != _AttachKind.none) ...[
                Row(
                  children: [
                    const Text('Attachment', style: TextStyle(fontWeight: FontWeight.w600)),
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
                  Text('$_imgW × $_imgH', style: const TextStyle(color: Colors.black54)),
              ],
              if (_attachKind == _AttachKind.video && _pickedFile != null) ...[
                const Icon(Icons.videocam, size: 40),
                const SizedBox(height: 8),
                Text(_pickedFile!.name, style: const TextStyle(color: Colors.black54)),
              ],
              if (_attachKind == _AttachKind.link) ...[
                Text(_linkText ?? '', style: const TextStyle(color: Colors.black54)),
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
                  const Text('No preview available.', style: TextStyle(color: Colors.black54)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}