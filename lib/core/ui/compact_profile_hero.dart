import 'package:flutter/material.dart';

import 'aura_radius.dart';
import 'aura_space.dart';
import 'aura_surface.dart';
import 'aura_text.dart';
import 'profile_header.dart' show PresenceHeaderAction;

/// Shared compact identity hero used across every profile surface
/// (`/me`, `/u/:handle`, and edit-profile previews).
///
/// It is a slim banner — short cover, overlapping avatar, name + handle, an
/// optional role chip, a wrapping meta row, and a flexible action slot. The
/// header reflows on its own measured width (not the page breakpoint) so it
/// behaves identically wherever it is dropped: actions sit inline beside the
/// identity block when there is room, and stack full-width below it when there
/// is not.
///
/// Bio is intentionally NOT rendered here — long-form identity copy belongs in
/// the Identity tab's "Profile summary" card, not the hero.
class CompactProfileHero extends StatelessWidget {
  const CompactProfileHero({
    super.key,
    required this.displayName,
    required this.handle,
    this.title = '',
    this.avatarUrl = '',
    this.coverUrl = '',
    this.roleLabel = '',
    this.metaChips = const [],
    this.actions = const [],
  });

  /// Resolved display name. Falls back to an em dash when empty.
  final String displayName;

  /// Raw handle (without a leading `@`). The hero adds the `@`.
  final String handle;

  /// Short professional headline shown under the name (e.g. "Founder &
  /// Builder"). Hidden when empty.
  final String title;

  final String avatarUrl;
  final String coverUrl;

  /// Optional affiliation chip (e.g. "Speaks for Aura Platform"). Hidden when
  /// empty — never fabricate a role.
  final String roleLabel;

  /// Identity meta chips (location, website, joined …). Rendered in a [Wrap].
  final List<Widget> metaChips;

  /// Context actions (Edit/Public profile, Follow/Message, …). `primary`
  /// actions render filled; the rest render outlined.
  final List<PresenceHeaderAction> actions;

  static const double _coverAspectRatio = 3;
  static const double _avatarSize = 84;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.xl),
        border: Border.all(color: AuraSurface.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Reflow on the hero's own width, not the page's. Below this the
          // identity block and the actions stack instead of sitting side by
          // side.
          final isNarrow = constraints.maxWidth < 560;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _cover(width: constraints.maxWidth),
                  Positioned(
                    left: isNarrow ? AuraSpace.s18 : AuraSpace.s24,
                    bottom: -(_avatarSize / 2),
                    child: _avatar(),
                  ),
                ],
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isNarrow ? AuraSpace.s18 : AuraSpace.s24,
                  (_avatarSize / 2) + AuraSpace.s12,
                  isNarrow ? AuraSpace.s18 : AuraSpace.s24,
                  isNarrow ? AuraSpace.s18 : AuraSpace.s20,
                ),
                child: isNarrow
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _identity(isNarrow: true),
                          if (actions.isNotEmpty) ...[
                            const SizedBox(height: AuraSpace.s16),
                            _buttons(expand: true),
                          ],
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _identity(isNarrow: false)),
                          if (actions.isNotEmpty) ...[
                            const SizedBox(width: AuraSpace.s20),
                            _buttons(expand: false),
                          ],
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _identity({required bool isNarrow}) {
    final name = displayName.trim().isNotEmpty ? displayName.trim() : '—';
    final handleText = handle.trim().isNotEmpty ? '@${handle.trim()}' : '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: AuraText.title.copyWith(
            fontSize: isNarrow ? 22 : 26,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (title.trim().isNotEmpty) ...[
          const SizedBox(height: AuraSpace.s6),
          Text(
            title.trim(),
            style: AuraText.body.copyWith(
              color: AuraSurface.ink,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: AuraSpace.s4),
        Text(
          handleText,
          style: AuraText.muted.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (roleLabel.trim().isNotEmpty) ...[
          const SizedBox(height: AuraSpace.s10),
          _roleChip(roleLabel.trim()),
        ],
        if (metaChips.isNotEmpty) ...[
          const SizedBox(height: AuraSpace.s12),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: metaChips,
          ),
        ],
      ],
    );
  }

  Widget _cover({required double width}) {
    final url = coverUrl.trim();
    final coverHeight = width / _coverAspectRatio;
    return SizedBox(
      height: coverHeight,
      width: double.infinity,
      child: url.isEmpty
          ? const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF232833),
                    Color(0xFF1C212A),
                    Color(0xFF171B22),
                  ],
                ),
              ),
            )
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const ColoredBox(color: AuraSurface.elevated),
            ),
    );
  }

  Widget _avatar() {
    final url = avatarUrl.trim();
    final fallback = Container(
      width: _avatarSize,
      height: _avatarSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AuraSurface.elevated,
        border: Border.all(color: AuraSurface.card, width: 4),
      ),
      child: Text(
        _initials(displayName),
        style: AuraText.title.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    if (url.isEmpty) return fallback;

    return Container(
      width: _avatarSize,
      height: _avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AuraSurface.card,
        border: Border.all(color: AuraSurface.card, width: 4),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }

  Widget _roleChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s10,
        vertical: AuraSpace.s6,
      ),
      decoration: BoxDecoration(
        color: AuraSurface.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(color: AuraSurface.accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.verified_outlined,
            size: 13,
            color: AuraSurface.accent,
          ),
          const SizedBox(width: AuraSpace.s6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AuraText.micro.copyWith(
                color: AuraSurface.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buttons({required bool expand}) {
    final widgets = <Widget>[];
    for (var i = 0; i < actions.length; i++) {
      if (i != 0) {
        widgets.add(
          expand
              ? const SizedBox(height: AuraSpace.s10)
              : const SizedBox(width: AuraSpace.s10),
        );
      }
      widgets.add(_actionButton(actions[i], expand: expand));
    }

    return expand
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: widgets,
          )
        : Row(mainAxisSize: MainAxisSize.min, children: widgets);
  }

  Widget _actionButton(PresenceHeaderAction action, {required bool expand}) {
    final icon = action.icon;

    if (action.primary) {
      return FilledButton.icon(
        onPressed: action.onTap,
        icon: icon != null ? Icon(icon, size: 16) : const SizedBox.shrink(),
        label: Text(action.label),
        style: FilledButton.styleFrom(
          minimumSize: expand ? const Size.fromHeight(44) : null,
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s16,
            vertical: AuraSpace.s12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: action.onTap,
      icon: icon != null ? Icon(icon, size: 16) : const SizedBox.shrink(),
      label: Text(action.label),
      style: OutlinedButton.styleFrom(
        minimumSize: expand ? const Size.fromHeight(44) : null,
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s16,
          vertical: AuraSpace.s12,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}
