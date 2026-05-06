import 'package:flutter/material.dart';

import '../../core/ui/aura_radius.dart';
import '../../core/ui/aura_surface.dart';
import '../../core/ui/aura_text.dart';
import '../../features/feed/domain/feed_item.dart';

/// Phase 6.1 — small, calm identity chip for feed surfaces.
///
/// Aura's product principle: identity is trust infrastructure. The badge
/// communicates *who* the author is and *how* they're speaking (Personal /
/// Official / Member / Admin) without ever counting followers, scoring
/// popularity, or styling anything as influencer-flair.
///
/// Modes
///   * `compact`        — single chip on one line, used in author rows.
///   * `replyPreview`   — micro variant for the in-line reply preview block.
///
/// Renders nothing for `PERSONAL` or unknown context types (the implied
/// default); meaningful context only.
class AuraIdentityBadge extends StatelessWidget {
  const AuraIdentityBadge({
    super.key,
    required this.context,
    this.mode = AuraIdentityBadgeMode.compact,
  });

  final FeedIdentityContext context;

  // Renamed to avoid shadowing the BuildContext param of `build()`.
  // ignore: library_private_types_in_public_api
  final AuraIdentityBadgeMode mode;

  @override
  Widget build(BuildContext buildContext) {
    if (!context.isMeaningful) return const SizedBox.shrink();

    final tone = _toneFor(context.type);
    final dense = mode == AuraIdentityBadgeMode.replyPreview;

    final label = _labelFor(context);
    final icon = _iconFor(context);

    final padding = dense
        ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
        : const EdgeInsets.symmetric(horizontal: 8, vertical: 3);
    final iconSize = dense ? 10.0 : 12.0;
    final textStyle = (dense ? AuraText.micro : AuraText.micro).copyWith(
      color: tone.foreground,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.3,
      fontSize: dense ? 10 : 11,
    );

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(color: tone.border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: tone.foreground),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
          ),
        ],
      ),
    );
  }

  String _labelFor(FeedIdentityContext c) {
    if (c.label.isNotEmpty) return c.label;
    switch (c.type) {
      case FeedIdentityContextType.officialInstitution:
        return c.verified ? 'Verified institution' : 'Official institution';
      case FeedIdentityContextType.institutionMember:
        return c.institutionName != null && c.institutionName!.isNotEmpty
            ? 'Member · ${c.institutionName}'
            : 'Institution member';
      case FeedIdentityContextType.institutionAdmin:
        return c.institutionName != null && c.institutionName!.isNotEmpty
            ? 'Admin · ${c.institutionName}'
            : 'Institution admin';
      case FeedIdentityContextType.platformAdmin:
        return 'Platform admin';
      case FeedIdentityContextType.personal:
      case FeedIdentityContextType.unknown:
        return '';
    }
  }

  IconData? _iconFor(FeedIdentityContext c) {
    switch (c.type) {
      case FeedIdentityContextType.officialInstitution:
        return c.verified
            ? Icons.verified_rounded
            : Icons.apartment_rounded;
      case FeedIdentityContextType.institutionMember:
        return Icons.workspace_premium_outlined;
      case FeedIdentityContextType.institutionAdmin:
        return Icons.shield_outlined;
      case FeedIdentityContextType.platformAdmin:
        return Icons.shield_moon_outlined;
      case FeedIdentityContextType.personal:
      case FeedIdentityContextType.unknown:
        return null;
    }
  }

  _BadgeTone _toneFor(FeedIdentityContextType t) {
    switch (t) {
      case FeedIdentityContextType.officialInstitution:
        return const _BadgeTone(
          background: Color(0x1E0D9488),
          foreground: Color(0xFF5EEAD4),
          border: Color(0x4D0D9488),
        );
      case FeedIdentityContextType.institutionAdmin:
      case FeedIdentityContextType.platformAdmin:
        return const _BadgeTone(
          background: Color(0x1F8B5CF6),
          foreground: Color(0xFFC4B5FD),
          border: Color(0x4D8B5CF6),
        );
      case FeedIdentityContextType.institutionMember:
        return const _BadgeTone(
          background: AuraSurface.subtle,
          foreground: AuraSurface.muted,
          border: AuraSurface.divider,
        );
      case FeedIdentityContextType.personal:
      case FeedIdentityContextType.unknown:
        return const _BadgeTone(
          background: AuraSurface.subtle,
          foreground: AuraSurface.faint,
          border: AuraSurface.divider,
        );
    }
  }
}

enum AuraIdentityBadgeMode {
  /// Single chip suitable for the author row of a feed card.
  compact,

  /// Smaller chip for the inline reply-preview block.
  replyPreview,
}

class _BadgeTone {
  const _BadgeTone({
    required this.background,
    required this.foreground,
    required this.border,
  });
  final Color background;
  final Color foreground;
  final Color border;
}

/// Standalone "Verified institution" badge for screens that don't carry a
/// full `FeedIdentityContext` (e.g. institution profile header, member
/// shell). Keeps the same look as the full badge so the meaning is
/// consistent across surfaces.
class AuraVerifiedInstitutionBadge extends StatelessWidget {
  const AuraVerifiedInstitutionBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuraIdentityBadge(
      context: FeedIdentityContext(
        type: FeedIdentityContextType.officialInstitution,
        label: 'Verified institution',
        verified: true,
      ),
    );
  }
}
