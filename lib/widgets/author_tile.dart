import 'package:flutter/material.dart';
import 'package:aura/models/author.dart';

import '../core/ui/aura_platform_components.dart';

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

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      mouseCursor: SystemMouseCursors.click,
      leading: AuraAvatar(
        name: author.name,
        imageUrl: author.avatarUrl,
        size: 40,
      ),
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
