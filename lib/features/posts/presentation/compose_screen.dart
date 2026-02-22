import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

  // In-session draft cache.
  // Survives navigation while the app is running, but not a full reload.
  static final Map<String, String> _sessionDrafts = <String, String>{};

  String get _draftKey => widget.replyToPostId != null ? 'reply:${widget.replyToPostId}' : 'compose:new';
  bool get _hasText => _controller.text.trim().isNotEmpty;

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
