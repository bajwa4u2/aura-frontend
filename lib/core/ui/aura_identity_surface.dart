import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
    final tap = onTap ??
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
            _Avatar(avatarUrl: avatarUrl),
            const SizedBox(width: AuraSpace.s10),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: AuraText.body.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    '@$handle',
                    style: AuraText.small.copyWith(
                      color: AuraSurface.muted,
                    ),
                  ),

                  if (!compact &&
                      contextLine != null &&
                      contextLine!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      contextLine!,
                      style: AuraText.small.copyWith(
                        color: AuraSurface.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            if (trailing != null) ...[
              const SizedBox(width: AuraSpace.s8),
              trailing!,
            ]
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.avatarUrl});

  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final size = 40.0;

    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          avatarUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(size),
        ),
      );
    }

    return _fallback(size);
  }

  Widget _fallback(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AuraSurface.card,
        shape: BoxShape.circle,
        border: Border.all(color: AuraSurface.divider),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.person_outline,
        color: AuraSurface.muted,
        size: 22,
      ),
    );
  }
}