import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/app_error_mapper.dart';
import '../ui/aura_space.dart';
import '../ui/aura_surface.dart';
import '../ui/aura_text.dart';
import '../ui/aura_platform_components.dart';
import 'engagement_model.dart';
import 'publication_discussion_repository.dart';

/// Discussion for any eligible publication class.
///
/// Deliberately not an article comments widget. A reply IS a Post on Aura, and
/// discussion reaches the same canonical authority — with its moderation gate,
/// Discourse Quality rules, mention fan-out, acting authority and blocking —
/// through the generalized engagement surface. An ArticleCommentsSystem would
/// have been a second discussion product to keep in step with the first.
class AuraPublicationDiscussion extends ConsumerStatefulWidget {
  const AuraPublicationDiscussion({
    super.key,
    required this.target,
    required this.publicationId,
  });

  final PublicationTarget target;
  final String publicationId;

  @override
  ConsumerState<AuraPublicationDiscussion> createState() =>
      _AuraPublicationDiscussionState();
}

class _AuraPublicationDiscussionState
    extends ConsumerState<AuraPublicationDiscussion> {
  final _controller = TextEditingController();
  bool _sending = false;

  ({PublicationTarget target, String id}) get _key =>
      (target: widget.target, id: widget.publicationId);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(publicationDiscussionRepositoryProvider)
          .reply(widget.target, widget.publicationId, text);
      _controller.clear();
      ref.invalidate(publicationDiscussionProvider(_key));
      await ref.read(publicationDiscussionProvider(_key).future);
    } catch (e) {
      if (!mounted) return;
      // The server refuses for real reasons — a block, Discourse Quality, the
      // objectionable-content gate. Those refusals are the product working, so
      // they are surfaced as written rather than flattened into "try again".
      final err = AppErrorMapper.from(e, feature: 'post that reply');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(publicationDiscussionProvider(_key));
    final replies = async.value ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          replies.isEmpty
              ? 'Discussion'
              : 'Discussion · ${replies.length}',
          style: AuraText.body.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AuraSpace.s12),

        // Compose first: on a long article the reader has just finished
        // reading, and making them scroll past every existing reply to find
        // the box is a small hostility.
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 6,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: 'Add to the discussion',
                  filled: true,
                  fillColor: AuraSurface.elevated,
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: AuraSurface.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AuraSurface.divider),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: AuraSpace.s12,
                    vertical: AuraSpace.s10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AuraSpace.s8),
            IconButton(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, size: 20),
              tooltip: 'Post reply',
            ),
          ],
        ),
        const SizedBox(height: AuraSpace.s16),

        if (async.isLoading && replies.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AuraSpace.s12),
            child: SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (replies.isEmpty)
          Text(
            'No replies yet.',
            style: AuraText.small.copyWith(color: AuraSurface.muted),
          )
        else
          for (final r in replies)
            Padding(
              padding: const EdgeInsets.only(bottom: AuraSpace.s16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AuraAvatar(
                    name: r.authorName,
                    imageUrl: r.authorAvatarUrl,
                    size: 28,
                  ),
                  const SizedBox(width: AuraSpace.s10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.authorName.isEmpty ? 'Aura member' : r.authorName,
                          style: AuraText.small.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AuraSurface.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        SelectableText(
                          r.text,
                          style: AuraText.body.copyWith(color: AuraSurface.ink),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
