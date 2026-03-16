import 'package:flutter/material.dart';

import 'aura_card.dart';
import 'aura_space.dart';
import 'aura_surface.dart';
import 'aura_text.dart';

class PresenceHeaderAction {
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final IconData? icon;

  const PresenceHeaderAction({
    required this.label,
    this.onTap,
    this.primary = false,
    this.icon,
  });
}

class PresenceHeader extends StatelessWidget {
  final String displayName;
  final String handle;
  final String bio;
  final String avatarUrl;
  final String coverUrl;
  final List<PresenceHeaderAction> actions;
  final List<Widget> trailingMeta;

  const PresenceHeader({
    super.key,
    required this.displayName,
    required this.handle,
    this.bio = '',
    this.avatarUrl = '',
    this.coverUrl = '',
    this.actions = const [],
    this.trailingMeta = const [],
  });

  @override
  Widget build(BuildContext context) {
    final safeName = displayName.trim().isNotEmpty ? displayName.trim() : '—';
    final safeHandle = handle.trim().isNotEmpty ? '@${handle.trim()}' : '—';
    final safeBio = bio.trim();

    return AuraCard(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 720;
          const coverHeight = 208.0;
          const avatarSize = 104.0;
          const overlap = 34.0;

          final identity = _PresenceIdentity(
            displayName: safeName,
            handle: safeHandle,
            bio: safeBio,
            actions: actions,
            trailingMeta: trailingMeta,
            isNarrow: isNarrow,
          );

          final avatar = _PresenceAvatar(
            avatarUrl: avatarUrl,
            displayName: safeName,
            size: avatarSize,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _PresenceCover(
                    coverUrl: coverUrl,
                    height: coverHeight,
                  ),
                  Positioned(
                    left: isNarrow ? AuraSpace.s18 : AuraSpace.s24,
                    bottom: -(avatarSize / 2) + overlap,
                    child: avatar,
                  ),
                ],
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isNarrow ? AuraSpace.s18 : AuraSpace.s24,
                  (avatarSize / 2) + AuraSpace.s10,
                  isNarrow ? AuraSpace.s18 : AuraSpace.s24,
                  AuraSpace.s24,
                ),
                child: identity,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PresenceIdentity extends StatelessWidget {
  final String displayName;
  final String handle;
  final String bio;
  final List<PresenceHeaderAction> actions;
  final List<Widget> trailingMeta;
  final bool isNarrow;

  const _PresenceIdentity({
    required this.displayName,
    required this.handle,
    required this.bio,
    required this.actions,
    required this.trailingMeta,
    required this.isNarrow,
  });

  @override
  Widget build(BuildContext context) {
    final textBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          displayName,
          style: AuraText.title.copyWith(
            fontSize: isNarrow ? 28 : 32,
            fontWeight: FontWeight.w700,
            height: 1.05,
            color: AuraSurface.ink,
          ),
        ),
        const SizedBox(height: AuraSpace.s6),
        Text(
          handle,
          style: AuraText.muted.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (bio.isNotEmpty) ...[
          const SizedBox(height: AuraSpace.s14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Text(
              bio,
              style: AuraText.body.copyWith(
                height: 1.5,
                color: AuraSurface.ink,
              ),
            ),
          ),
        ],
        if (trailingMeta.isNotEmpty) ...[
          const SizedBox(height: AuraSpace.s14),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: trailingMeta,
          ),
        ],
      ],
    );

    final actionsBlock = actions.isEmpty
        ? const SizedBox.shrink()
        : Wrap(
            spacing: AuraSpace.s10,
            runSpacing: AuraSpace.s10,
            children: actions
                .map((action) => _PresenceActionButton(action: action))
                .toList(),
          );

    if (isNarrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          textBlock,
          if (actions.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s16),
            actionsBlock,
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: textBlock),
        if (actions.isNotEmpty) ...[
          const SizedBox(width: AuraSpace.s20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Align(
              alignment: Alignment.topRight,
              child: actionsBlock,
            ),
          ),
        ],
      ],
    );
  }
}

class _PresenceCover extends StatelessWidget {
  final String coverUrl;
  final double height;

  const _PresenceCover({
    required this.coverUrl,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final hasCover = coverUrl.trim().isNotEmpty;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasCover)
            Image.network(
              coverUrl.trim(),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _emptySurface(),
            )
          else
            _emptySurface(),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(hasCover ? 0.10 : 0.08),
                  Colors.black.withOpacity(hasCover ? 0.20 : 0.16),
                  Colors.black.withOpacity(hasCover ? 0.34 : 0.24),
                ],
                stops: const [0.0, 0.52, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptySurface() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF232833),
            Color(0xFF1C212A),
            Color(0xFF171B22),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: AuraSurface.divider),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -34,
            right: -16,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -28,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.02),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PresenceAvatar extends StatelessWidget {
  final String avatarUrl;
  final String displayName;
  final double size;

  const _PresenceAvatar({
    required this.avatarUrl,
    required this.displayName,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final initials = _initials(displayName);

    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AuraSurface.card,
        border: Border.all(color: AuraSurface.divider, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: AuraText.title.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AuraSurface.ink,
        ),
      ),
    );

    if (avatarUrl.trim().isEmpty) return fallback;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AuraSurface.card,
        border: Border.all(color: AuraSurface.card, width: 4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24000000),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        avatarUrl.trim(),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();

    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final first = parts.first;
      return first.isEmpty ? '?' : first.substring(0, 1).toUpperCase();
    }

    final first = parts.first.substring(0, 1).toUpperCase();
    final last = parts.last.substring(0, 1).toUpperCase();
    return '$first$last';
  }
}

class _PresenceActionButton extends StatelessWidget {
  final PresenceHeaderAction action;

  const _PresenceActionButton({
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