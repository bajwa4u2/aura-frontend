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
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';

class ComposeScreen extends ConsumerStatefulWidget {
  final String? replyToPostId;
  const ComposeScreen({super.key, this.replyToPostId});

  @override
  ConsumerState<ComposeScreen> createState() => _ComposeScreenState();
}

enum _ComposeMode { text, image, video }

class _ComposeScreenState extends ConsumerState<ComposeScreen> {
  static const int _limit = 2000;

  final _textController = TextEditingController();
  final _contextController = TextEditingController();

  bool _posting = false;
  bool _saving = false;

  // Option 2: enforce text always
  bool _showTextError = false;

  _ComposeMode _mode = _ComposeMode.text;

  XFile? _pickedFile;
  Uint8List? _pickedBytes; // web preview for images
  int? _imgW;
  int? _imgH;

  // When continuing a draft that already has media attached.
  String? _existingMediaUrl;

  DateTime? _lastSavedAt;

  Timer? _autosaveDebounce;

  bool get _isReply => widget.replyToPostId != null;

  bool get _hasText => _textController.text.trim().isNotEmpty;
  bool get _textTooLong => _textController.text.trim().length > _limit;

  bool get _hasPickedMedia =>
      _pickedFile != null && (_mode == _ComposeMode.image || _mode == _ComposeMode.video);

  bool get _hasExistingMedia =>
      (_existingMediaUrl ?? '').trim().isNotEmpty &&
      (_mode == _ComposeMode.image || _mode == _ComposeMode.video);

  bool get _hasAnyMedia => _hasPickedMedia || _hasExistingMedia;

  // Option 2: text is required in ALL modes.
  bool get _canPublish {
    if (!_hasText) return false;
    if (_textTooLong) return false;

    switch (_mode) {
      case _ComposeMode.text:
        return true;
      case _ComposeMode.image:
      case _ComposeMode.video:
        return _hasAnyMedia;
    }
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
    if (!mounted) return;
    setState(() {
      _imgW = img.width;
      _imgH = img.height;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadDraft();

    _textController.addListener(_scheduleAutosave);
    _contextController.addListener(_scheduleAutosave);
  }

  @override
  void dispose() {
    _autosaveDebounce?.cancel();
    _textController.dispose();
    _contextController.dispose();
    super.dispose();
  }

  Future<void> _loadDraft() async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/posts/draft');
      final data = _asMap(res.data);
      final draftRaw = data['draft'];
      if (draftRaw is! Map) return;

      final draft = Map<String, dynamic>.from(draftRaw);

      final text = (draft['text'] ?? '').toString();
      final mediaType = (draft['mediaType'] ?? 'NONE').toString().toUpperCase();
      final mediaUrl = (draft['mediaUrl'] ?? '').toString();
      final caption = (draft['caption'] ?? '').toString();

      final updatedAtRaw = (draft['updatedAt'] ?? '').toString();
      final savedAt = DateTime.tryParse(updatedAtRaw)?.toLocal();

      if (!mounted) return;

      setState(() {
        _textController.text = text;
        _contextController.text = caption;

        if (mediaType == 'IMAGE') {
          _mode = _ComposeMode.image;
          _existingMediaUrl = mediaUrl.trim().isEmpty ? null : mediaUrl.trim();
        } else if (mediaType == 'VIDEO') {
          _mode = _ComposeMode.video;
          _existingMediaUrl = mediaUrl.trim().isEmpty ? null : mediaUrl.trim();
        } else {
          _mode = _ComposeMode.text;
          _existingMediaUrl = null;
        }

        // preserve dimensions if present (helps re-save draft without losing metadata)
        final w = draft['mediaWidth'];
        final h = draft['mediaHeight'];
        _imgW = (w is int) ? w : int.tryParse((w ?? '').toString());
        _imgH = (h is int) ? h : int.tryParse((h ?? '').toString());

        _lastSavedAt = savedAt;

        // reset error state on restore if valid
        if (_hasText) _showTextError = false;
      });
    } catch (_) {
      // ignore: draft restore is best-effort
    }
  }

  void _scheduleAutosave() {
    // Keep it calm: autosave quietly after short pause.
    _autosaveDebounce?.cancel();
    _autosaveDebounce = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      if (_posting) return;

      // Option 2: do not autosave empty text (backend enforces text required)
      if (!_hasText) return;

      // For media modes, autosave is meaningful even if media isn't picked yet
      // (it saves the text), but we must avoid writing IMAGE/VIDEO type with no media.
      _saveDraft(silent: true);
    });
  }

  void _setMode(_ComposeMode next) {
    if (_posting) return;
    if (_mode == next) return;

    setState(() {
      _mode = next;

      // Enforce one-primary-medium: switching modes clears the other payload.
      _pickedFile = null;
      _pickedBytes = null;
      _imgW = null;
      _imgH = null;
      _existingMediaUrl = null;

      // Keep text across modes (context only matters for media).
      if (_mode == _ComposeMode.text) {
        _contextController.clear();
      }
    });

    _scheduleAutosave();
  }

  void _clearMedia() {
    if (_posting) return;
    setState(() {
      _pickedFile = null;
      _pickedBytes = null;
      _existingMediaUrl = null;
      _imgW = null;
      _imgH = null;
      _contextController.clear();
    });
    _scheduleAutosave();
  }

  Future<void> _pickImage() async {
    if (_posting) return;

    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    final bytes = await file.readAsBytes();

    if (!mounted) return;
    setState(() {
      _mode = _ComposeMode.image;
      _pickedFile = file;
      _pickedBytes = bytes;
      _existingMediaUrl = null;
    });

    try {
      await _decodeImageSize(bytes);
    } catch (_) {}

    _scheduleAutosave();
  }

  Future<void> _pickVideo() async {
    if (_posting) return;

    final picker = ImagePicker();
    final file = await picker.pickVideo(source: ImageSource.gallery);
    if (file == null) return;

    if (!mounted) return;
    setState(() {
      _mode = _ComposeMode.video;
      _pickedFile = file;
      _pickedBytes = null;
      _existingMediaUrl = null;
      _imgW = null;
      _imgH = null;
    });

    _scheduleAutosave();
  }

  String _mediaTypeForMode() {
    // Foolproof: never claim IMAGE/VIDEO in draft unless media actually exists.
    switch (_mode) {
      case _ComposeMode.text:
        return 'NONE';
      case _ComposeMode.image:
        return _hasAnyMedia ? 'IMAGE' : 'NONE';
      case _ComposeMode.video:
        return _hasAnyMedia ? 'VIDEO' : 'NONE';
    }
  }

  String _savedLine() {
    if (_saving) return 'Saving…';
    final dt = _lastSavedAt;
    if (dt == null) return 'Draft not saved yet.';
    return 'Draft saved ${_time(dt)}.';
  }

  Future<void> _saveDraft({bool silent = false, String? mediaUrlOverride}) async {
    if (_saving || _posting) return;

    // Option 2: enforce text always (stop backend 400s before they happen)
    if (!_hasText) {
      if (!silent && mounted) {
        setState(() => _showTextError = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Text is required.')),
        );
      }
      return;
    }

    setState(() => _saving = true);

    try {
      final dio = ref.read(dioProvider);

      final payload = <String, dynamic>{
        'text': _textController.text,
        'mediaType': _mediaTypeForMode(),
      };

      // Media payload
      if (_mode == _ComposeMode.image && _hasAnyMedia) {
        final url = (mediaUrlOverride ?? _existingMediaUrl ?? '').trim();
        if (url.isNotEmpty) payload['mediaUrl'] = url;
        if (_imgW != null) payload['mediaWidth'] = _imgW;
        if (_imgH != null) payload['mediaHeight'] = _imgH;

        final ctx = _contextController.text.trim();
        if (ctx.isNotEmpty) payload['caption'] = ctx;
      }

      if (_mode == _ComposeMode.video && _hasAnyMedia) {
        final url = (mediaUrlOverride ?? _existingMediaUrl ?? '').trim();
        if (url.isNotEmpty) payload['mediaUrl'] = url;

        final ctx = _contextController.text.trim();
        if (ctx.isNotEmpty) payload['caption'] = ctx;
      }

      await dio.put('/posts/draft', data: payload);

      if (!mounted) return;
      setState(() => _lastSavedAt = DateTime.now());
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save draft: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _publish() async {
    if (_posting) return;

    // Option 2: enforce text always (UI + function guard)
    if (!_hasText) {
      setState(() => _showTextError = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Text is required.')),
      );
      return;
    }

    if (_textTooLong) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Too long. Please shorten your post.')),
      );
      return;
    }

    if (!_canPublish) return;

    setState(() => _posting = true);

    try {
      final dio = ref.read(dioProvider);

      String? uploadedPublicUrl;

      // If draft already has media and user didn't pick a new file, we keep it.
      final hasFreshUpload =
          _pickedFile != null && (_mode == _ComposeMode.image || _mode == _ComposeMode.video);

      // 1) If IMAGE/VIDEO picked now, presign + upload to R2
      if (hasFreshUpload) {
        final mime = _inferMime(_pickedFile!.name);
        final bytes = await _pickedFile!.readAsBytes();

        if (_mode == _ComposeMode.image && bytes.length > 10 * 1024 * 1024) {
          throw Exception('Image too large (max 10MB)');
        }
        if (_mode == _ComposeMode.video && bytes.length > 50 * 1024 * 1024) {
          throw Exception('Video too large (max 50MB)');
        }

        final pres = await dio.post('/media/presign', data: {
          'fileName': _pickedFile!.name,
          'mimeType': mime,
          'bytes': bytes.length,
          'kind': _mode == _ComposeMode.image ? 'IMAGE' : 'VIDEO',
          if (_mode == _ComposeMode.image) 'width': _imgW,
          if (_mode == _ComposeMode.image) 'height': _imgH,
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

      // 2) Save draft (final)
      if (_mode == _ComposeMode.image || _mode == _ComposeMode.video) {
        final finalUrl = (uploadedPublicUrl ?? _existingMediaUrl ?? '').trim();
        if (finalUrl.isNotEmpty) {
          await _saveDraft(silent: true, mediaUrlOverride: finalUrl);
        } else {
          await _saveDraft(silent: true);
        }
      } else {
        await _saveDraft(silent: true);
      }

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

  Widget _modeChip({required String label, required bool selected, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: (selected ? AuraText.body.copyWith(fontWeight: FontWeight.w700) : AuraText.muted),
        ),
      ),
    );
  }

  Widget _divider() => Container(height: 1, color: AuraSurface.divider);

  @override
  Widget build(BuildContext context) {
    final title = _isReply ? 'Reply' : 'Compose';

    return AuraScaffold(
      title: title,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.pop(),
      ),
      actions: [
        TextButton(
          onPressed: _posting
              ? null
              : () {
                  _textController.clear();
                  _contextController.clear();
                  _clearMedia();
                  context.pop(false);
                },
          child: const Text('Discard'),
        ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AuraSpace.xl),
        child: AuraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Composing', style: AuraText.title),
              const SizedBox(height: AuraSpace.s6),
              Text(_savedLine(), style: AuraText.small),
              const SizedBox(height: AuraSpace.s12),
              _divider(),
              const SizedBox(height: AuraSpace.s8),

              // Mode selector (quiet)
              Row(
                children: [
                  _modeChip(
                    label: 'Text',
                    selected: _mode == _ComposeMode.text,
                    onTap: () => _setMode(_ComposeMode.text),
                  ),
                  _modeChip(
                    label: 'Image',
                    selected: _mode == _ComposeMode.image,
                    onTap: () => _setMode(_ComposeMode.image),
                  ),
                  _modeChip(
                    label: 'Video',
                    selected: _mode == _ComposeMode.video,
                    onTap: () => _setMode(_ComposeMode.video),
                  ),
                ],
              ),
              const SizedBox(height: AuraSpace.s8),
              _divider(),
              const SizedBox(height: AuraSpace.s12),

              // Writing surface (always shown; text required for all modes)
              Container(
                decoration: BoxDecoration(
                  color: AuraSurface.page,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AuraSurface.divider),
                ),
                padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s12, vertical: AuraSpace.s10),
                child: TextField(
                  controller: _textController,
                  maxLines: null,
                  minLines: 10,
                  onChanged: (_) {
                    if (_showTextError && _hasText) {
                      setState(() => _showTextError = false);
                    } else {
                      setState(() {});
                    }
                  },
                  style: AuraText.body,
                  decoration: InputDecoration(
                    hintText: _isReply ? 'Write a reply…' : 'Add to the record… (required)',
                    hintStyle: AuraText.muted,
                    border: InputBorder.none,
                    errorText: _showTextError ? 'Text is required' : null,
                  ),
                ),
              ),
              const SizedBox(height: AuraSpace.s8),
              Text('${_textController.text.trim().length}/$_limit', style: AuraText.small),

              if (_mode == _ComposeMode.image) ...[
                const SizedBox(height: AuraSpace.s12),
                _MediaZone(
                  label: _hasAnyMedia ? 'Image attached' : 'Add image',
                  sublabel: _hasAnyMedia ? 'Tap to replace, or remove.' : 'One image per post.',
                  isBusy: _posting,
                  hasMedia: _hasAnyMedia,
                  onTap: _posting ? null : _pickImage,
                  trailing: _hasAnyMedia
                      ? TextButton(
                          onPressed: _posting ? null : _clearMedia,
                          child: const Text('Remove'),
                        )
                      : null,
                  child: () {
                    if (_pickedBytes != null) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(_pickedBytes!, fit: BoxFit.cover),
                      );
                    }
                    if (_hasExistingMedia) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          _existingMediaUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Text(
                            'Preview unavailable. The image is still attached.',
                            style: AuraText.muted,
                          ),
                        ),
                      );
                    }
                    return null;
                  }(),
                ),
                const SizedBox(height: AuraSpace.s12),
                _ContextField(
                  controller: _contextController,
                  hint: 'Add context (optional)',
                  enabled: !_posting,
                ),
              ],

              if (_mode == _ComposeMode.video) ...[
                const SizedBox(height: AuraSpace.s12),
                _MediaZone(
                  label: _hasAnyMedia ? 'Video attached' : 'Add video',
                  sublabel: _hasAnyMedia ? 'Tap to replace, or remove.' : 'One video per post.',
                  isBusy: _posting,
                  hasMedia: _hasAnyMedia,
                  onTap: _posting ? null : _pickVideo,
                  trailing: _hasAnyMedia
                      ? TextButton(
                          onPressed: _posting ? null : _clearMedia,
                          child: const Text('Remove'),
                        )
                      : null,
                  child: () {
                    if (_pickedFile != null) {
                      return Text(_pickedFile!.name, style: AuraText.body);
                    }
                    if (_hasExistingMedia) {
                      return Text('Preview is available after publish.', style: AuraText.muted);
                    }
                    return null;
                  }(),
                ),
                const SizedBox(height: AuraSpace.s12),
                _ContextField(
                  controller: _contextController,
                  hint: 'Add context (optional)',
                  enabled: !_posting,
                ),
              ],

              const SizedBox(height: AuraSpace.s16),
              _divider(),
              const SizedBox(height: AuraSpace.s12),

              // Publish bar (calm)
              Row(
                children: [
                  TextButton(
                    onPressed: (_posting || _saving || !_hasText)
                        ? null
                        : () {
                            if (!_hasText) {
                              setState(() => _showTextError = true);
                              return;
                            }
                            _saveDraft(silent: false);
                          },
                    child: const Text('Save draft'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: (_posting || !_canPublish)
                        ? null
                        : () {
                            if (!_hasText) {
                              setState(() => _showTextError = true);
                              return;
                            }
                            _publish();
                          },
                    child: Text(_posting ? 'Publishing…' : 'Publish to record'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContextField extends StatelessWidget {
  const _ContextField({
    required this.controller,
    required this.hint,
    required this.enabled,
  });

  final TextEditingController controller;
  final String hint;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AuraSurface.page,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AuraSurface.divider),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s12, vertical: AuraSpace.s10),
      child: TextField(
        controller: controller,
        enabled: enabled,
        maxLines: null,
        minLines: 3,
        style: AuraText.body,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AuraText.muted,
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class _MediaZone extends StatelessWidget {
  const _MediaZone({
    required this.label,
    required this.sublabel,
    required this.isBusy,
    required this.hasMedia,
    required this.onTap,
    this.trailing,
    this.child,
  });

  final String label;
  final String sublabel;
  final bool isBusy;
  final bool hasMedia;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AuraSurface.page,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AuraSurface.divider),
      ),
      padding: const EdgeInsets.all(AuraSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: AuraText.body.copyWith(fontWeight: FontWeight.w700))),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: AuraSpace.s6),
          Text(sublabel, style: AuraText.small),
          const SizedBox(height: AuraSpace.s12),
          if (child != null) ...[
            child!,
            const SizedBox(height: AuraSpace.s12),
          ],
          OutlinedButton.icon(
            onPressed: isBusy ? null : onTap,
            icon: const Icon(Icons.add),
            label: Text(hasMedia ? 'Replace' : 'Add'),
          ),
        ],
      ),
    );
  }
}

String _time(DateTime dt) {
  final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final mm = dt.minute.toString().padLeft(2, '0');
  final ap = dt.hour >= 12 ? 'pm' : 'am';
  return '$h:$mm $ap';
}