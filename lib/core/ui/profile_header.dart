import 'package:flutter/material.dart';

import 'aura_card.dart';
import 'aura_space.dart';
import 'aura_surface.dart';
import 'aura_text.dart';
import 'aura_text_block.dart';

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
  final List<PresenceHeaderAction> workspaceActions;
  final List<Widget> trailingMeta;

  const PresenceHeader({
    super.key,
    required this.displayName,
    required this.handle,
    this.bio = '',
    this.avatarUrl = '',
    this.coverUrl = '',
    this.actions = const [],
    this.workspaceActions = const [],
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
          const coverHeight = 200.0;
          const avatarSize = 104.0;
          const overlap = 34.0;

          final identity = _PresenceIdentity(
            displayName: safeName,
            handle: safeHandle,
            bio: safeBio,
            actions: actions,
            workspaceActions: workspaceActions,
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
                  _PresenceCover(coverUrl: coverUrl, height: coverHeight),
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
  final List<PresenceHeaderAction> workspaceActions;
  final List<Widget> trailingMeta;
  final bool isNarrow;

  const _PresenceIdentity({
    required this.displayName,
    required this.handle,
    required this.bio,
    required this.actions,
    required this.workspaceActions,
    required this.trailingMeta,
    required this.isNarrow,
  });

  @override
  Widget build(BuildContext context) {
    final textBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuraTextBlock(
          displayName,
          style: AuraText.title.copyWith(
            fontSize: isNarrow ? 28 : 32,
            fontWeight: FontWeight.w700,
            height: 1.05,
            color: AuraSurface.ink,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
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
            child: AuraTextBlock(
              bio,
              style: AuraText.body.copyWith(
                height: 1.5,
                color: AuraSurface.ink,
              ),
              // Profile bio is discourse — selectable so it can be
              // quoted and referenced.
              selectable: true,
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

    final controlBlock = _PresenceControlRail(
      actions: actions,
      workspaceActions: workspaceActions,
      isNarrow: isNarrow,
    );

    if (isNarrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          textBlock,
          if (actions.isNotEmpty || workspaceActions.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s16),
            controlBlock,
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: textBlock),
        if (actions.isNotEmpty || workspaceActions.isNotEmpty) ...[
          const SizedBox(width: AuraSpace.s20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 286),
            child: controlBlock,
          ),
        ],
      ],
    );
  }
}

class _PresenceControlRail extends StatelessWidget {
  const _PresenceControlRail({
    required this.actions,
    required this.workspaceActions,
    required this.isNarrow,
  });

  final List<PresenceHeaderAction> actions;
  final List<PresenceHeaderAction> workspaceActions;
  final bool isNarrow;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty && workspaceActions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isNarrow ? AuraSpace.s12 : AuraSpace.s14),
      decoration: BoxDecoration(
        color: AuraSurface.elevated,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...actions.map(
            (action) => Padding(
              padding: const EdgeInsets.only(bottom: AuraSpace.s10),
              child: _PresenceActionButton(action: action, expand: true),
            ),
          ),
          if (workspaceActions.isNotEmpty) ...[
            if (actions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: AuraSpace.s12),
                child: Container(height: 1, color: AuraSurface.divider),
              ),
            Text(
              'Workspaces',
              style: AuraText.small.copyWith(
                color: AuraSurface.muted,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: AuraSpace.s10),
            ...workspaceActions.map(
              (action) => Padding(
                padding: const EdgeInsets.only(bottom: AuraSpace.s10),
                child: _PresenceActionButton(action: action, expand: true),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PresenceCover extends StatelessWidget {
  final String coverUrl;
  final double height;

  const _PresenceCover({required this.coverUrl, required this.height});

  @override
  Widget build(BuildContext context) {
    final raw = coverUrl.trim();
    final hasCover = raw.isNotEmpty;
    final resolvedUrl = hasCover ? _withBust(raw) : '';

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasCover)
            Image.network(
              resolvedUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _emptySurface(),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    _emptySurface(),
                    const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ],
                );
              },
            )
          else
            _emptySurface(),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: hasCover ? 0.10 : 0.08),
                  Colors.black.withValues(alpha: hasCover ? 0.20 : 0.16),
                  Colors.black.withValues(alpha: hasCover ? 0.34 : 0.24),
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
          colors: [Color(0xFF232833), Color(0xFF1C212A), Color(0xFF171B22)],
        ),
        border: Border(bottom: BorderSide(color: AuraSurface.divider)),
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
                color: Colors.white.withValues(alpha: 0.04),
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
                color: Colors.white.withValues(alpha: 0.02),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _withBust(String value) {
    final separator = value.contains('?') ? '&' : '?';
    return '$value${separator}v=${DateTime.now().millisecondsSinceEpoch}';
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
    final raw = avatarUrl.trim();

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

    if (raw.isEmpty) return fallback;

    final resolvedUrl = _withBust(raw);

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
        resolvedUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return fallback;
        },
      ),
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final first = parts.first;
      return first.isEmpty ? '?' : first.substring(0, 1).toUpperCase();
    }

    final first = parts.first.substring(0, 1).toUpperCase();
    final last = parts.last.substring(0, 1).toUpperCase();
    return '$first$last';
  }

  String _withBust(String value) {
    final separator = value.contains('?') ? '&' : '?';
    return '$value${separator}v=${DateTime.now().millisecondsSinceEpoch}';
  }
}

class _PresenceActionButton extends StatelessWidget {
  final PresenceHeaderAction action;
  final bool expand;

  const _PresenceActionButton({required this.action, this.expand = false});

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: expand
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        if (action.icon != null) ...[
          Icon(action.icon, size: 16),
          const SizedBox(width: AuraSpace.s8),
        ],
        Flexible(child: Text(action.label, overflow: TextOverflow.ellipsis)),
      ],
    );

    if (action.primary) {
      return FilledButton(
        onPressed: action.onTap,
        style: FilledButton.styleFrom(
          minimumSize: expand ? const Size.fromHeight(48) : null,
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
        minimumSize: expand ? const Size.fromHeight(48) : null,
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s16,
          vertical: AuraSpace.s12,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      child: child,
    );
  }
}
