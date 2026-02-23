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

class ComposeScreen extends ConsumerStatefulWidget {
  const ComposeScreen({super.key, this.replyToPostId});
  final String? replyToPostId;

  @override
  ConsumerState<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends ConsumerState<ComposeScreen> {
  final _controller = TextEditingController();
  bool _posting = false;
  static const int _limit = 2000;

  // Attachment (in-memory preview; web-safe)
  Uint8List? _imageBytes;
  String? _imageName;

  // In-session draft cache.
  // Survives navigation while the app is running, but not a full reload.
  static final Map<String, String> _sessionDrafts = <String, String>{};

  String get _draftKey =>
      widget.replyToPostId != null ? 'reply:${widget.replyToPostId}' : 'compose:new';
  bool get _hasText => _controller.text.trim().isNotEmpty;
  bool get _hasAttachment => _imageBytes != null;

  @override
  void initState() {
    super.initState();
    final existing = _sessionDrafts[_draftKey];
    if (existing != null && existing.isNotEmpty) {
      _controller.text = existing;
      _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _saveDraft({bool quiet = false}) {
    final text = _controller.text;

    if (text.trim().isEmpty) {
      _sessionDrafts.remove(_draftKey);
      if (!quiet && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nothing to save.')),
        );
      }
      return;
    }

    _sessionDrafts[_draftKey] = text;

    if (!quiet && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved.')),
      );
    }
  }

  void _discardDraft() {
    _sessionDrafts.remove(_draftKey);
  }

  Future<void> _pickImage() async {
    if (_posting) return;

    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (!mounted) return;

      setState(() {
        _imageBytes = bytes;
        _imageName = file.name;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not pick image: $e')),
      );
    }
  }

  void _removeAttachment() {
    setState(() {
      _imageBytes = null;
      _imageName = null;
    });
  }

  Future<void> _publish() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _posting) return;

    if (text.length > _limit) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Too long. Keep it under 2000 characters.')),
      );
      return;
    }

    // NOTE (this step): We show attachment preview, but we are not wiring upload
    // until we confirm the backend media upload route/contract.
    // We won't invent endpoints here.
    if (_hasAttachment) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attachment preview is working. Next step: wire media upload.'),
        ),
      );
      // Continue publishing text anyway (so user can still post).
    }

    setState(() => _posting = true);
    try {
      final dio = ref.read(dioProvider);

      // Replies are created as posts with replyToPostId.
      final payload = <String, dynamic>{
        'text': text,
        if (widget.replyToPostId != null) 'replyToPostId': widget.replyToPostId,
      };

      await dio.post('/posts', data: payload);

      _discardDraft();
      _removeAttachment();

      if (!mounted) return;
      context.pop(true);
    } catch (e) {
      _saveDraft(quiet: true);

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
    final isReply = widget.replyToPostId != null;
    final text = _controller.text.trim();
    final remaining = _limit - text.length;

    return AuraScaffold(
      title: isReply ? 'Reply' : 'Compose',
      actions: [
        TextButton(
          onPressed: _posting ? null : () => _saveDraft(),
          child: const Text('Save'),
        ),
        TextButton(
          onPressed: _posting ? null : _publish,
          child: Text(_posting ? 'Publishing…' : 'Publish'),
        ),
      ],
      body: ListView(
        padding: EdgeInsets.fromLTRB(AuraSpace.s16, AuraSpace.s12, AuraSpace.s16, AuraSpace.s24),
        children: [
          AuraCard(
            padding: EdgeInsets.all(AuraSpace.s18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isReply ? 'Reply with care.' : 'Write something worth carrying.',
                  style: AuraText.title,
                ),
                SizedBox(height: AuraSpace.s8),
                Text(
                  'No performance, no bait. Just clarity.',
                  style: AuraText.muted.copyWith(height: 1.35),
                ),
              ],
            ),
          ),
          SizedBox(height: AuraSpace.s14),

          // Attachment controls
          AuraCard(
            child: Padding(
              padding: EdgeInsets.all(AuraSpace.s14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Attachment', style: AuraText.body.copyWith(fontWeight: FontWeight.w700)),
                  SizedBox(height: AuraSpace.s10),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _posting ? null : _pickImage,
                        icon: const Icon(Icons.image_outlined),
                        label: const Text('Attach image'),
                      ),
                      SizedBox(width: AuraSpace.s10),
                      if (_hasAttachment)
                        TextButton(
                          onPressed: _posting ? null : _removeAttachment,
                          child: const Text('Remove'),
                        ),
                    ],
                  ),
                  if (_hasAttachment) ...[
                    SizedBox(height: AuraSpace.s12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        _imageBytes!,
                        fit: BoxFit.cover,
                      ),
                    ),
                    if ((_imageName ?? '').trim().isNotEmpty) ...[
                      SizedBox(height: AuraSpace.s8),
                      Text(
                        _imageName!,
                        style: AuraText.small.copyWith(color: const Color(0xFF6F6F6F)),
                      ),
                    ],
                  ] else ...[
                    SizedBox(height: AuraSpace.s8),
                    Text(
                      'Nothing attached yet.',
                      style: AuraText.small.copyWith(color: const Color(0xFF6F6F6F)),
                    ),
                  ],
                ],
              ),
            ),
          ),

          SizedBox(height: AuraSpace.s14),
          AuraCard(
            child: TextField(
              controller: _controller,
              maxLength: _limit,
              maxLines: 12,
              decoration: const InputDecoration(
                hintText: 'Draft here…',
                border: InputBorder.none,
                counterText: '',
              ),
              onChanged: (_) {
                _saveDraft(quiet: true);
                setState(() {});
              },
            ),
          ),
          SizedBox(height: AuraSpace.s8),
          Text(
            remaining >= 0 ? '$remaining characters remaining' : '${remaining.abs()} over limit',
            style: AuraText.small.copyWith(
              color: remaining >= 0 ? const Color(0xFF6F6F6F) : Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: AuraSpace.s12),
          AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Preview', style: AuraText.body.copyWith(fontWeight: FontWeight.w700)),
                SizedBox(height: AuraSpace.s8),
                Text(
                  text.isEmpty ? 'Nothing yet.' : text,
                  style: AuraText.body.copyWith(height: 1.45),
                ),
              ],
            ),
          ),
          SizedBox(height: AuraSpace.s18),
          FilledButton.icon(
            onPressed: (_posting || !_hasText) ? null : _publish,
            icon: _posting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send),
            label: Text(_posting ? 'Publishing…' : 'Publish'),
          ),
          SizedBox(height: AuraSpace.s10),
          TextButton(
            onPressed: _posting
                ? null
                : () {
                    _discardDraft();
                    _removeAttachment();
                    _controller.clear();
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Draft discarded.')),
                    );
                  },
            child: const Text('Discard draft'),
          ),
        ],
      ),
    );
  }
}