import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';

enum _AttachKind { none, image, video }

class ComposeScreen extends ConsumerStatefulWidget {
  const ComposeScreen({super.key, this.replyToPostId});
  final String? replyToPostId;

  @override
  ConsumerState<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends ConsumerState<ComposeScreen> {
  final _controller = TextEditingController();
  bool _posting = false;
  bool _loadingDraft = false;
  bool _savingDraft = false;

  Timer? _debounce;
  static const int _limit = 2000;

  // Attachment (preview only for now; upload wiring comes next step)
  _AttachKind _attachKind = _AttachKind.none;
  Uint8List? _imageBytes;
  String? _fileName;
  int? _fileBytes;

  bool get _isReply => widget.replyToPostId != null;
  bool get _hasText => _controller.text.trim().isNotEmpty;
  bool get _hasAttachment => _attachKind != _AttachKind.none;

  @override
  void initState() {
    super.initState();

    // Only main compose uses draft autosave across devices.
    // Replies should not share the same single global draft row.
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
    super.dispose();
  }

  void _onChanged() {
    // Debounced autosave to backend
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      _saveDraft();
    });
    // Update counters / preview
    if (mounted) setState(() {});
  }

  Future<void> _loadDraft() async {
    setState(() => _loadingDraft = true);
    try {
      final dio = ref.read(dioProvider);

      final res = await dio.get('/posts/draft');
      final data = res.data;

      // API may return null when no draft exists.
      if (data == null) return;

      // Accept either {ok:true,data:{...}} or direct post object.
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

      // Media draft restore can be added later once upload wiring is done.
    } catch (_) {
      // Silent: drafts should never block compose.
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

      await dio.put('/posts/draft', data: {'text': _controller.text});
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft saved.')));
      }
    } catch (_) {
      // Silent by default: draft failures shouldn’t spam the user.
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

  Future<void> _pickImage() async {
    if (_posting) return;

    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 92);
      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (!mounted) return;

      setState(() {
        _attachKind = _AttachKind.image;
        _imageBytes = bytes;
        _fileName = file.name;
        _fileBytes = bytes.length;
      });

      // Draft save will include media later (next step). For now we just keep preview.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not pick image: $e')));
    }
  }

  Future<void> _pickVideo() async {
    if (_posting) return;

    try {
      final picker = ImagePicker();
      final file = await picker.pickVideo(source: ImageSource.gallery);
      if (file == null) return;

      // Don’t load full video into memory for preview (can be huge).
      final length = await file.length();
      if (!mounted) return;

      setState(() {
        _attachKind = _AttachKind.video;
        _imageBytes = null;
        _fileName = file.name;
        _fileBytes = length;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not pick video: $e')));
    }
  }

  void _removeAttachment() {
    setState(() {
      _attachKind = _AttachKind.none;
      _imageBytes = null;
      _fileName = null;
      _fileBytes = null;
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
        // Replies publish directly (do not use global draft)
        await dio.post('/posts/${widget.replyToPostId}/reply', data: {'text': text});
        _controller.clear();
        _removeAttachment();
        if (!mounted) return;
        context.pop(true);
        return;
      }

      // Main compose publishes the saved draft row.
      // To keep behavior deterministic across devices:
      // - force one last save
      await dio.put('/posts/draft', data: {'text': _controller.text});

      // Media upload wiring comes next step:
      // - upload to backend media endpoint -> get url/type/width/height/duration
      // - saveDraft including media fields
      // For now we publish text-only draft.
      if (_hasAttachment && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attachment picked. Next step: wire media upload to the post.')),
        );
      }

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

                  // Attach controls (same card)
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
                      if (_hasAttachment)
                        TextButton(
                          onPressed: _posting ? null : _removeAttachment,
                          child: const Text('Remove'),
                        ),
                    ],
                  ),

                  const SizedBox(height: AuraSpace.s12),

                  // Attachment preview area (within same card)
                  if (_hasAttachment) ...[
                    if (_attachKind == _AttachKind.image && _imageBytes != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                      ),
                      if ((_fileName ?? '').trim().isNotEmpty || _fileBytes != null) ...[
                        const SizedBox(height: AuraSpace.s8),
                        Text(
                          [
                            if ((_fileName ?? '').trim().isNotEmpty) _fileName!.trim(),
                            if (_fileBytes != null) _humanBytes(_fileBytes),
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
                        'Video preview playback comes next (upload wiring + player).',
                        style: AuraText.small.copyWith(color: const Color(0xFF6F6F6F)),
                      ),
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