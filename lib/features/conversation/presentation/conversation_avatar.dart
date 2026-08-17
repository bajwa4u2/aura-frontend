import 'package:flutter/material.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/conversations_repository.dart';
import 'conversation_identity.dart';

/// CONVERSATION VISUAL IDENTITY (founder ruling 2026-08-17, F056).
///
/// A conversation is people, so it looks like its people:
///   • 1:1 — the counterpart's canonical avatar;
///   • group — a compact composite of canonical participant identities in
///     the F055 formation order, current user excluded, bounded to a few
///     faces plus "+N";
///   • canonical initials appear only for a participant who genuinely has
///     no usable avatar — never as the identity of the whole group;
///   • a custom conversation name changes the TEXT, never erases the human
///     visual identity underneath.
///
/// Uses the shared [AuraAvatar] for every individual face so image
/// loading, fallback initials and shape stay identical to the rest of the
/// product (no per-surface identity dialect).
class ConversationAvatar extends StatelessWidget {
  const ConversationAvatar({
    super.key,
    required this.conversation,
    required this.myUserId,
    this.size = 44,
  });

  final Conversation conversation;
  final String myUserId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final identities = conversationAvatarIdentities(conversation, myUserId);
    final overflow = conversationAvatarOverflow(conversation, myUserId);

    // No resolvable people (edge case: everyone left) — fall back to the
    // conversation's own textual identity rather than inventing a face.
    if (identities.isEmpty) {
      return AuraAvatar(
        name: conversationDisplayName(conversation, myUserId),
        size: size,
      );
    }

    // 1:1 — the counterpart IS the identity.
    if (identities.length == 1 && overflow == 0) {
      return AuraAvatar(
        name: identities.first.name,
        imageUrl: identities.first.imageUrl,
        size: size,
      );
    }

    // Group — bounded composite. Faces overlap slightly so several
    // identities read clearly inside one avatar-sized slot.
    final faceSize = size * 0.62;
    final step = faceSize * 0.62;
    final visible = identities.take(overflow > 0 ? 2 : 3).toList();
    final extra =
        overflow + (identities.length - visible.length);

    final children = <Widget>[];
    for (var i = 0; i < visible.length; i++) {
      children.add(
        Positioned(
          left: i * step,
          top: i.isEven ? 0 : size - faceSize,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AuraSurface.page, width: 1.5),
            ),
            child: AuraAvatar(
              name: visible[i].name,
              imageUrl: visible[i].imageUrl,
              size: faceSize,
            ),
          ),
        ),
      );
    }

    if (extra > 0) {
      children.add(
        Positioned(
          left: visible.length * step,
          top: visible.length.isEven ? 0 : size - faceSize,
          child: Container(
            width: faceSize,
            height: faceSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AuraSurface.subtle,
              shape: BoxShape.circle,
              border: Border.all(color: AuraSurface.page, width: 1.5),
            ),
            child: Text(
              '+$extra',
              style: AuraText.micro.copyWith(
                color: AuraSurface.muted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(clipBehavior: Clip.none, children: children),
    );
  }
}
