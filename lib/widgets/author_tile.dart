import 'package:flutter/material.dart';
import 'package:aura/models/author.dart';

class AuthorTile extends StatelessWidget {
  final Author author;
  final Widget? trailing;
  final VoidCallback? onTap;

  const AuthorTile({
    super.key,
    required this.author,
    this.trailing,
    this.onTap,
  });

  Widget _avatar() {
    final url = author.avatarUrl;
    if (url == null || url.trim().isEmpty) {
      return CircleAvatar(
        child: Text(author.name.isNotEmpty ? author.name[0] : '?'),
      );
    }
    return CircleAvatar(
      backgroundImage: NetworkImage(url),
      onBackgroundImageError: (_, __) {},
      child: const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      mouseCursor: SystemMouseCursors.click,
      leading: _avatar(),
      title: Text(
        author.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${author.handle}\n${author.bio}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: true,
      trailing: trailing,
    );
  }
}
