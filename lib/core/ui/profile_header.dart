import 'package:flutter/material.dart';

import 'aura_card.dart';
import 'aura_space.dart';
import 'aura_surface.dart';
import 'aura_text.dart';

class ProfileHeaderStat {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const ProfileHeaderStat({
    required this.label,
    required this.value,
    this.onTap,
  });
}

class ProfileHeaderAction {
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final IconData? icon;

  const ProfileHeaderAction({
    required this.label,
    this.onTap,
    this.primary = false,
    this.icon,
  });
}

class ProfileHeader extends StatelessWidget {
  final String displayName;
  final String handle;
  final String bio;
  final String avatarUrl;
  final List<ProfileHeaderStat> stats;
  final List<ProfileHeaderAction> actions;
  final List<Widget> trailingMeta;

  const ProfileHeader({
    super.key,
    required this.displayName,
    required this.handle,
    this.bio = '',
    this.avatarUrl = '',
    this.stats = const [],
    this.actions = const [],
    this.trailingMeta = const [],
  });

  @override
  Widget build(BuildContext context) {
    final safeName = displayName.trim().isNotEmpty ? displayName.trim() : '—';
    final safeHandle = handle.trim().isNotEmpty ? '@${handle.trim()}' : '—';
    final safeBio = bio.trim();

    return AuraCard(
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.s20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 680;

            final avatar = _ProfileAvatar(
              avatarUrl: avatarUrl,
              displayName: safeName,
            );

            final info = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(safeName, style: AuraText.title),
                const SizedBox(height: AuraSpace.s4),
                Text(safeHandle, style: AuraText.muted),
                if (safeBio.isNotEmpty) ...[
                  const SizedBox(height: AuraSpace.s12),
                  Text(safeBio, style: AuraText.body),
                ],
                if (stats.isNotEmpty) ...[
                  const SizedBox(height: AuraSpace.s16),
                  Wrap(
                    spacing: AuraSpace.s10,
                    runSpacing: AuraSpace.s10,
                    children: stats
                        .map(
                          (stat) => _ProfileStatPill(stat: stat),
                        )
                        .toList(),
                  ),
                ],
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: AuraSpace.s16),
                  Wrap(
                    spacing: AuraSpace.s10,
                    runSpacing: AuraSpace.s10,
                    children: actions
                        .map(
                          (action) => _ProfileActionButton(action: action),
                        )
                        .toList(),
                  ),
                ],
                if (trailingMeta.isNotEmpty) ...[
                  const SizedBox(height: AuraSpace.s12),
                  Wrap(
                    spacing: AuraSpace.s8,
                    runSpacing: AuraSpace.s8,
                    children: trailingMeta,
                  ),
                ],
              ],
            );

            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  avatar,
                  const SizedBox(height: AuraSpace.s16),
                  info,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                avatar,
                const SizedBox(width: AuraSpace.s16),
                Expanded(child: info),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String avatarUrl;
  final String displayName;

  const _ProfileAvatar({
    required this.avatarUrl,
    required this.displayName,
  });

  @override
  Widget build(BuildContext context) {
    const double size = 80;

    final initials = _buildInitials(displayName);

    Widget fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AuraSurface.elevated,
        shape: BoxShape.circle,
        border: Border.all(color: AuraSurface.divider),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: AuraText.body.copyWith(
          color: AuraSurface.ink,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    if (avatarUrl.trim().isEmpty) return fallback;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AuraSurface.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        avatarUrl.trim(),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }

  String _buildInitials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();

    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}

class _ProfileStatPill extends StatelessWidget {
  final ProfileHeaderStat stat;

  const _ProfileStatPill({
    required this.stat,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s12,
        vertical: AuraSpace.s10,
      ),
      decoration: BoxDecoration(
        color: AuraSurface.elevated,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            stat.value,
            style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: AuraSpace.s8),
          Text(stat.label, style: AuraText.small),
        ],
      ),
    );

    if (stat.onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: stat.onTap,
        borderRadius: BorderRadius.circular(999),
        child: content,
      ),
    );
  }
}

class _ProfileActionButton extends StatelessWidget {
  final ProfileHeaderAction action;

  const _ProfileActionButton({
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (action.icon != null) ...[
          Icon(action.icon, size: 16),
          const SizedBox(width: AuraSpace.s8),
        ],
        Text(action.label),
      ],
    );

    if (action.primary) {
      return FilledButton(
        onPressed: action.onTap,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s16,
            vertical: AuraSpace.s12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: child,
      );
    }

    return OutlinedButton(
      onPressed: action.onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s16,
          vertical: AuraSpace.s12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      child: child,
    );
  }
}
