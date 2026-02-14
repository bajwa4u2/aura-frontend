import 'package:flutter/material.dart';
import 'package:aura/models/note.dart';
import 'package:aura/state/app_state.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback? onAuthorTap;

  const NoteCard({
    super.key,
    required this.note,
    this.onAuthorTap,
  });

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Widget _avatar(String name, String? url) {
    if (url == null || url.trim().isEmpty) {
      return CircleAvatar(
        radius: 18,
        child: Text(name.isNotEmpty ? name[0] : '?'),
      );
    }
    return CircleAvatar(
      radius: 18,
      backgroundImage: NetworkImage(url),
      onBackgroundImageError: (_, __) {},
      child: const SizedBox.shrink(),
    );
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 900)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppStateScope.of(context);
    final author = app.authorById(note.authorId);

    final isLiked = app.isLiked(note.id);
    final isBookmarked = app.isBookmarked(note.id);
    final likes = app.likeCount(note.id);

    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _avatar(author.name, author.avatarUrl),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                author.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                author.handle,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Text(
          _formatDate(note.createdAt),
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 12,
          ),
        ),
      ],
    );

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header (clickable identity)
            if (onAuthorTap != null)
              InkWell(
                onTap: onAuthorTap,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: header,
                ),
              )
            else
              header,

            const SizedBox(height: 10),

            // Note text
            Text(
              note.text,
              style: const TextStyle(
                fontSize: 15,
                height: 1.45,
              ),
            ),

            const SizedBox(height: 10),

            // Actions
            Row(
              children: [
                TextButton.icon(
                  onPressed: () {
                    if (!app.isMember) {
                      _toast(context, 'Login required');
                      return;
                    }
                    app.toggleLike(note.id);
                  },
                  icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border),
                  label: Text(likes == 0 ? 'Like' : '$likes'),
                ),
                const SizedBox(width: 6),
                TextButton.icon(
                  onPressed: () {
                    if (!app.isMember) {
                      _toast(context, 'Login required');
                      return;
                    }
                    app.toggleBookmark(note.id);
                    _toast(context, app.isBookmarked(note.id) ? 'Bookmarked' : 'Removed');
                  },
                  icon: Icon(
                    isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  ),
                  label: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
