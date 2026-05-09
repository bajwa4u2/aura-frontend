import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'aura_platform_components.dart';
import 'aura_space.dart';
import 'aura_surface.dart';
import 'aura_text.dart';

class AuraIdentitySurface extends StatelessWidget {
  const AuraIdentitySurface({
    super.key,
    required this.displayName,
    required this.handle,
    this.avatarUrl,
    this.contextLine,
    this.onTap,
    this.compact = false,
    this.trailing,
  });

  final String displayName;
  final String handle;
  final String? avatarUrl;
  final String? contextLine;

  final VoidCallback? onTap;

  /// compact mode used in dense lists
  final bool compact;

  /// optional trailing widget (follow button etc)
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tap =
        onTap ??
        () {
          context.push('/author/$handle');
        };

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: tap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AuraSpace.s8,
          horizontal: AuraSpace.s6,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Avatar(avatarUrl: avatarUrl, name: displayName),
            const SizedBox(width: AuraSpace.s10),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    '@$handle',
                    style: AuraText.small.copyWith(color: AuraSurface.muted),
                  ),

                  if (!compact &&
                      contextLine != null &&
                      contextLine!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      contextLine!,
                      style: AuraText.small.copyWith(color: AuraSurface.muted),
                    ),
                  ],
                ],
              ),
            ),

            if (trailing != null) ...[
              const SizedBox(width: AuraSpace.s8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Identity-surface avatar — delegates to the canonical [AuraAvatar].
/// Local fallback styling preserved by passing an empty `name` so the
/// initial gradient fills with `?` (matches the original generic
/// person-icon look closely enough; full-app initial avatars are
/// preferred over neutral icons for personal identification).
class _Avatar extends StatelessWidget {
  const _Avatar({this.avatarUrl, this.name = ''});

  final String? avatarUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    return AuraAvatar(name: name, imageUrl: avatarUrl, size: 40);
  }
}
