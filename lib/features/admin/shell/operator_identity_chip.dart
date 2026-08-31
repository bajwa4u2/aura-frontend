/// WHO IS OPERATING, AND UNDER WHAT AUTHORITY.
///
/// An operator console must answer "under what authority" about its OWN user,
/// not only about records. Someone holding four permissions and someone
/// holding twenty-five are doing different jobs, and the console should say
/// which one you are before you wonder why an action is missing.
library;

import 'package:flutter/material.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../domain/operator_capability.dart';

class OperatorIdentityChip extends StatelessWidget {
  const OperatorIdentityChip({
    super.key,
    required this.authority,
    this.dense = false,
  });

  final OperatorAuthority authority;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final role = authority.primaryRole;
    final label = authority.holdsOwnerRole
        ? OperatorRole.owner.label
        : (role?.label ?? 'Operator');
    final expired = authority.expiredAt(DateTime.now());

    return Tooltip(
      message: _tooltip(label, expired),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: dense ? AuraSpace.s8 : AuraSpace.s12,
          vertical: AuraSpace.s6,
        ),
        decoration: BoxDecoration(
          color: expired ? const Color(0x33FF6B6B) : AuraSurface.elevated,
          borderRadius: BorderRadius.circular(AuraRadius.pill),
          border: Border.all(
            color: expired ? const Color(0x66FF6B6B) : AuraSurface.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              expired ? Icons.gpp_maybe_rounded : Icons.verified_user_rounded,
              size: 14,
              color: expired ? const Color(0xFFFF8A8A) : AuraSurface.accent,
            ),
            const SizedBox(width: AuraSpace.s6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: expired ? const Color(0xFFFFC9C9) : AuraSurface.ink,
              ),
            ),
            if (!dense) ...[
              const SizedBox(width: AuraSpace.s6),
              Text(
                '${authority.capabilities.length}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AuraSurface.muted,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _tooltip(String label, bool expired) {
    final buffer = StringBuffer('$label · ${authority.capabilities.length} '
        'capabilit${authority.capabilities.length == 1 ? 'y' : 'ies'}');
    if (expired) buffer.write('\nThis grant has expired.');
    if (authority.unknownCapabilities.isNotEmpty) {
      // Reported rather than hidden: a newer server's scopes are a fact about
      // this build, not a gap in the operator's authority.
      buffer.write('\n${authority.unknownCapabilities.length} newer '
          'capabilit${authority.unknownCapabilities.length == 1 ? 'y' : 'ies'} '
          'this client does not yet model.');
    }
    return buffer.toString();
  }
}
