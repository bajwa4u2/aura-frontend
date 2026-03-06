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
import '../../ai/providers.dart';

class ComposeScreen extends ConsumerStatefulWidget {
  final String? replyToPostId;
  const ComposeScreen({super.key, this.replyToPostId});

  @override
  ConsumerState<ComposeScreen> createState() => _ComposeScreenState();
}

enum _ComposeMode { text, image, video }

enum _PostVisibility { public, followers, private }

class _ComposeScreenState extends ConsumerState<ComposeScreen> {
  static const int _limit = 2000;

  final _textController = TextEditingController();
  final _contextController = TextEditingController();

  bool _posting = false;
  bool _saving = false;

  bool _showTextError = false;

  _ComposeMode _mode = _ComposeMode.text;
  _PostVisibility _visibility = _PostVisibility.public;

  XFile? _pickedFile;
  Uint8List? _pickedBytes;
  int? _imgW;
  int? _imgH;

  String? _existingMediaUrl;

  DateTime? _lastSavedAt;
  Timer? _autosaveDebounce;

  bool _auditBusy = false;
  DateTime? _lastAuditAt;
  Map<String, dynamic>? _auditResult;
  String? _auditError;

  bool get _isReply => widget.replyToPostId != null;

  bool get _hasText => _textController.text.trim().isNotEmpty;
  bool get _textTooLong => _textController.text.trim().length > _limit;

  bool get _hasPickedMedia =>
      _pickedFile != null && (_mode == _ComposeMode.image || _mode == _ComposeMode.video);

  bool get _hasExistingMedia =>
      (_existingMediaUrl ?? '').trim().isNotEmpty &&
      (_mode == _ComposeMode.image || _mode == _ComposeMode.video);

  bool get _hasAnyMedia => _hasPickedMedia || _hasExistingMedia;

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

  String _visibilityApiValue(_PostVisibility value) {
    switch (value) {
      case _PostVisibility.public:
        return 'PUBLIC';
      case _PostVisibility.followers:
        return 'FOLLOWERS';
      case _PostVisibility.private:
        return 'PRIVATE';
    }
  }

  _PostVisibility _visibilityFromApi(dynamic value) {
    final raw = (value ?? '').toString().trim().toUpperCase();
    switch (raw) {
      case 'FOLLOWERS':
        return _PostVisibility.followers;
      case 'PRIVATE':
        return _PostVisibility.private;
      case 'PUBLIC':
      default:
        return _PostVisibility.public;
    }
  }

  String _visibilityLabel(_PostVisibility value) {
    switch (value) {
      case _PostVisibility.public:
        return 'Public';
      case _PostVisibility.followers:
        return 'Followers';
      case _PostVisibility.private:
        return 'Private';
    }
  }

  String _visibilityHelp(_PostVisibility value) {
    switch (value) {
      case _PostVisibility.public:
        return 'Visible to everyone, including visitors.';
      case _PostVisibility.followers:
        return 'Visible only to followers and approved member surfaces.';
      case _PostVisibility.private:
        return 'Visible only to you.';
    }
  }

  Dio _cleanUploadDio() {
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
      final draftSource = data['draft'] ?? data;
      if (draftSource is! Map) return;

      final draft = Map<String, dynamic>.from(draftSource);

      final text = (draft['text'] ?? '').toString();
      final mediaType = (draft['mediaType'] ?? 'NONE').toString().toUpperCase();
      final mediaUrl = (draft['mediaUrl'] ?? '').toString();
      final caption = (draft['caption'] ?? '').toString();
      final visibility = _visibilityFromApi(draft['visibility']);

      final updatedAtRaw = (draft['updatedAt'] ?? '').toString();
      final savedAt = DateTime.tryParse(updatedAtRaw)?.toLocal();

      if (!mounted) return;

      setState(() {
        _textController.text = text;
        _contextController.text = caption;
        _visibility = visibility;

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

        final w = draft['mediaWidth'];
        final h = draft['mediaHeight'];
        _imgW = (w is int) ? w : int.tryParse((w ?? '').toString());
        _imgH = (h is int) ? h : int.tryParse((h ?? '').toString());

        _lastSavedAt = savedAt;

        if (_hasText) _showTextError = false;
      });
    } catch (_) {
      // best-effort
    }
  }

  void _scheduleAutosave() {
    _autosaveDebounce?.cancel();
    _autosaveDebounce = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      if (_posting) return;
      if (!_hasText) return;
      _saveDraft(silent: true);
    });
  }

  void _setMode(_ComposeMode next) {
    if (_posting) return;
    if (_mode == next) return;

    setState(() {
      _mode = next;
      _pickedFile = null;
      _pickedBytes = null;
      _imgW = null;
      _imgH = null;
      _existingMediaUrl = null;

      if (_mode == _ComposeMode.text) {
        _contextController.clear();
      }
    });

    _scheduleAutosave();
  }

  void _setVisibility(_PostVisibility next) {
    if (_posting) return;
    if (_visibility == next) return;

    setState(() {
      _visibility = next;
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
        'visibility': _visibilityApiValue(_visibility),
        'mediaType': _mediaTypeForMode(),
      };

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

      final hasFreshUpload =
          _pickedFile != null && (_mode == _ComposeMode.image || _mode == _ComposeMode.video);

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
        if (uploadedPublicUrl == null || uploadedPublicUrl.trim().isEmpty) {
          throw Exception('publicUrl missing from presign response.');
        }

        final uploadDio = _cleanUploadDio();

        final uploadHeaders = <String, String>{};
        headers.forEach((k, v) {
          if (v == null) return;
          uploadHeaders[k.toString()] = v.toString();
        });

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

  bool get _auditCooldownActive {
    final t = _lastAuditAt;
    if (t == null) return false;
    return DateTime.now().difference(t) < const Duration(seconds: 15);
  }

  Future<void> _runAuraEditor() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _auditError = 'Write something first.';
        _auditResult = null;
      });
      return;
    }

    if (text.length < 40) {
      setState(() {
        _auditError = 'Add a little more context (at least a few lines).';
        _auditResult = null;
      });
      return;
    }

    if (_auditBusy || _auditCooldownActive) return;

    setState(() {
      _auditBusy = true;
      _auditError = null;
      _auditResult = null;
      _lastAuditAt = DateTime.now();
    });

    try {
      final repo = ref.read(aiRepoProvider);

      Map<String, dynamic> out;
      try {
        out = await repo.editorReview(text: text);
      } on DioException catch (e) {
        final code = e.response?.statusCode;
        if (code == 404) {
          out = await repo.claimAudit(text: text);
        } else {
          rethrow;
        }
      }

      if (!mounted) return;
      setState(() {
        _auditResult = out;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _auditError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _auditBusy = false);
      }
    }
  }

  List<Map<String, dynamic>> _listOfMap(dynamic v) {
    if (v is List) {
      final out = <Map<String, dynamic>>[];
      for (final x in v) {
        if (x is Map) out.add(Map<String, dynamic>.from(x.cast<String, dynamic>()));
      }
      return out;
    }
    return const [];
  }

  String _str(dynamic v) => (v ?? '').toString().trim();

  List<String> _takeSignals(Map<String, dynamic> r) {
    final assumptions = _listOfMap(r['assumptions'])
        .take(3)
        .map((x) => _str(x['reason']))
        .where((s) => s.isNotEmpty);
    final clarity = _listOfMap(r['clarity_issues'])
        .take(3)
        .map((x) => _str(x['reason']))
        .where((s) => s.isNotEmpty);
    final tone = _listOfMap(r['tone_flags'])
        .take(2)
        .map((x) => _str(x['reason']))
        .where((s) => s.isNotEmpty);

    final combined = <String>[
      ...clarity,
      ...assumptions,
      ...tone,
    ];

    final seen = <String>{};
    final out = <String>[];
    for (final s in combined) {
      final k = s.toLowerCase();
      if (k.isEmpty || seen.contains(k)) continue;
      seen.add(k);
      out.add(s);
      if (out.length >= 5) break;
    }
    return out;
  }

  String _suggestRefinement(Map<String, dynamic> r, String original) {
    final signals = _takeSignals(r);
    final firstLine = signals.isNotEmpty ? signals.first : '';

    final text = original.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.isEmpty) return '';

    final softened = text
        .replaceAll(
          RegExp(
            r'\b(always|never|everyone|no one|obviously|clearly|completely|totally)\b',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final example = softened.isEmpty ? text : softened;

    if (firstLine.isEmpty) {
      return 'Try tightening one sentence for clarity.\nExample: $example';
    }
    return '$firstLine\nExample: $example';
  }

  Future<void> _openAuraEditorSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AuraSurface.page,
      builder: (ctx) {
        final pad = MediaQuery.of(ctx).viewInsets.bottom;
        final r = _auditResult;

        final signals = r == null ? const <String>[] : _takeSignals(r);
        final refinement = r == null ? '' : _suggestRefinement(r, _textController.text);

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AuraSpace.s16,
              AuraSpace.s16,
              AuraSpace.s16,
              AuraSpace.s16 + pad,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Aura Editor', style: AuraText.title),
                const SizedBox(height: AuraSpace.s8),
                Text(
                  'A quiet review for civic clarity and responsibility. Limited output by design.',
                  style: AuraText.small.copyWith(color: AuraSurface.muted),
                ),
                const SizedBox(height: AuraSpace.s12),
                Row(
                  children: [
                    FilledButton(
                      onPressed: (_auditBusy || _auditCooldownActive) ? null : _runAuraEditor,
                      child: Text(
                        _auditBusy
                            ? 'Reviewing…'
                            : (_auditCooldownActive ? 'Wait a moment…' : 'Run review'),
                      ),
                    ),
                    const SizedBox(width: AuraSpace.s10),
                    OutlinedButton(
                      onPressed: _auditBusy
                          ? null
                          : () {
                              setState(() {
                                _auditResult = null;
                                _auditError = null;
                              });
                              Navigator.of(ctx).pop();
                            },
                      child: const Text('Close'),
                    ),
                  ],
                ),
                const SizedBox(height: AuraSpace.s12),
                if (_auditError != null)
                  AuraCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Note',
                          style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AuraSpace.s8),
                        Text(_auditError!, style: AuraText.body),
                      ],
                    ),
                  ),
                if (r != null) ...[
                  const SizedBox(height: AuraSpace.s12),
                  AuraCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Signals',
                          style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AuraSpace.s10),
                        if (signals.isEmpty)
                          Text(
                            'No obvious issues detected.',
                            style: AuraText.small.copyWith(color: AuraSurface.muted),
                          )
                        else
                          for (final s in signals)
                            Padding(
                              padding: const EdgeInsets.only(bottom: AuraSpace.s10),
                              child: Text('• $s', style: AuraText.body),
                            ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AuraSpace.s12),
                  AuraCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Refinement (limited)',
                          style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AuraSpace.s10),
                        Text(refinement, style: AuraText.body),
                      ],
                    ),
                  ),
                  const SizedBox(height: AuraSpace.s12),
                  AuraCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hard line',
                          style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AuraSpace.s10),
                        Text(
                          'No nudity, pornography, sexual scenes, or explicit sexual content. If you are unsure, do not publish.',
                          style: AuraText.body,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _modeChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: selected
              ? AuraText.body.copyWith(fontWeight: FontWeight.w700)
              : AuraText.small.copyWith(color: AuraSurface.muted),
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
          onPressed: _posting ? null : _openAuraEditorSheet,
          child: const Text('Aura Editor'),
        ),
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
              Text(
                _savedLine(),
                style: AuraText.small.copyWith(color: AuraSurface.muted),
              ),
              const SizedBox(height: AuraSpace.s12),
              _divider(),
              const SizedBox(height: AuraSpace.s8),
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

              Text('Audience', style: AuraText.body.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: AuraSpace.s8),
              Wrap(
                spacing: AuraSpace.s8,
                runSpacing: AuraSpace.s8,
                children: _PostVisibility.values
                    .map(
                      (v) => _VisibilityChip(
                        label: _visibilityLabel(v),
                        selected: _visibility == v,
                        onTap: _posting ? null : () => _setVisibility(v),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: AuraSpace.s8),
              Text(
                _visibilityHelp(_visibility),
                style: AuraText.small.copyWith(color: AuraSurface.muted),
              ),

              const SizedBox(height: AuraSpace.s12),
              _divider(),
              const SizedBox(height: AuraSpace.s12),

              Container(
                decoration: BoxDecoration(
                  color: AuraSurface.page,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AuraSurface.divider),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpace.s12,
                  vertical: AuraSpace.s10,
                ),
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
                    hintStyle: AuraText.small.copyWith(color: AuraSurface.muted),
                    border: InputBorder.none,
                    errorText: _showTextError ? 'Text is required' : null,
                  ),
                ),
              ),
              const SizedBox(height: AuraSpace.s8),
              Text(
                '${_textController.text.trim().length}/$_limit',
                style: AuraText.small.copyWith(color: AuraSurface.muted),
              ),

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
                            style: AuraText.small.copyWith(color: AuraSurface.muted),
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
                      return Text(
                        'Preview is available after publish.',
                        style: AuraText.small.copyWith(color: AuraSurface.muted),
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

              const SizedBox(height: AuraSpace.s16),
              _divider(),
              const SizedBox(height: AuraSpace.s12),

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

class _VisibilityChip extends StatelessWidget {
  const _VisibilityChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AuraSurface.card : AuraSurface.page,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AuraSurface.divider),
        ),
        child: Text(
          label,
          style: selected
              ? AuraText.body.copyWith(fontWeight: FontWeight.w700)
              : AuraText.small.copyWith(color: AuraSurface.muted),
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
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s12,
        vertical: AuraSpace.s10,
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        maxLines: null,
        minLines: 3,
        style: AuraText.body,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AuraText.small.copyWith(color: AuraSurface.muted),
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
              Expanded(
                child: Text(
                  label,
                  style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: AuraSpace.s6),
          Text(sublabel, style: AuraText.small.copyWith(color: AuraSurface.muted)),
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