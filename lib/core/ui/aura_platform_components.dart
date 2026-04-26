import 'package:flutter/material.dart';

import 'aura_card.dart';
import 'aura_design_system.dart';
import 'aura_radius.dart';
import 'aura_space.dart';
import 'aura_surface.dart';
import 'aura_text.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PAGE SHELLS
// ─────────────────────────────────────────────────────────────────────────────

class AuraPageShell extends StatelessWidget {
  const AuraPageShell({
    super.key,
    required this.child,
    this.maxWidth = 1200,
    this.padding,
    this.alignTop = true,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final bool alignTop;

  @override
  Widget build(BuildContext context) {
    Widget body = child;
    if (padding != null) body = Padding(padding: padding!, child: body);

    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AuraGradients.page),
      child: Align(
        alignment: alignTop ? Alignment.topCenter : Alignment.center,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SizedBox(width: double.infinity, child: body),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADERS
// ─────────────────────────────────────────────────────────────────────────────

/// Section header used at the top of screen content areas.
/// More premium than the previous card-boxed version.
class AuraGradientHeader extends StatelessWidget {
  const AuraGradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.leading,
    this.padding = const EdgeInsets.all(AuraSpace.lg),
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: AuraGradients.header,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
        boxShadow: AuraShadows.panel,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AuraSpace.s12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AuraText.headline),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: AuraSpace.s8),
                  Text(
                    subtitle!,
                    style: AuraText.body.copyWith(
                      color: AuraSurface.muted,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AuraSpace.s12),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Section title + optional subtitle + optional action button.
class AuraSectionHeader extends StatelessWidget {
  const AuraSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AuraText.subtitle),
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: AuraSpace.s4),
                Text(subtitle!, style: AuraText.muted),
              ],
            ],
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOADING & SKELETON
// ─────────────────────────────────────────────────────────────────────────────

/// Pulsing skeleton placeholder for loading states.
class AuraSkeleton extends StatefulWidget {
  const AuraSkeleton({super.key, this.width, this.height = 16, this.radius});

  final double? width;
  final double height;
  final double? radius;

  @override
  State<AuraSkeleton> createState() => _AuraSkeletonState();
}

class _AuraSkeletonState extends State<AuraSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Color?> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = ColorTween(
      begin: AuraSurface.card,
      end: AuraSurface.elevated,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.radius ?? (widget.height / 2);
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: _anim.value,
          borderRadius: BorderRadius.circular(r),
        ),
      ),
    );
  }
}

/// Pre-built skeleton for a card that contains a title + two lines of text.
class AuraCardSkeleton extends StatelessWidget {
  const AuraCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AuraSkeleton(width: 36, height: 36, radius: 18),
              SizedBox(width: AuraSpace.s10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AuraSkeleton(height: 13, width: 140),
                    SizedBox(height: 6),
                    AuraSkeleton(height: 11, width: 80),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AuraSpace.s14),
          AuraSkeleton(height: 13),
          SizedBox(height: AuraSpace.s8),
          AuraSkeleton(height: 13),
          SizedBox(height: AuraSpace.s8),
          AuraSkeleton(height: 13, width: 200),
        ],
      ),
    );
  }
}

/// Compact inline loading state — spinner + message.
class AuraLoadingState extends StatelessWidget {
  const AuraLoadingState({super.key, this.message = 'Loading…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AuraSpace.s20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AuraSurface.muted,
            ),
          ),
          const SizedBox(width: AuraSpace.s10),
          Text(message, style: AuraText.small),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY / ERROR STATES
// ─────────────────────────────────────────────────────────────────────────────

class AuraEmptyState extends StatelessWidget {
  const AuraEmptyState({
    super.key,
    required this.title,
    required this.body,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String title;
  final String body;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AuraSpace.s28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AuraSurface.subtle,
              borderRadius: BorderRadius.circular(AuraRadius.r16),
              border: Border.all(color: AuraSurface.divider),
            ),
            child: Icon(icon, size: AuraIconSize.lg, color: AuraSurface.faint),
          ),
          const SizedBox(height: AuraSpace.s16),
          Text(title, style: AuraText.subtitle, textAlign: TextAlign.center),
          const SizedBox(height: AuraSpace.s8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              body,
              style: AuraText.muted,
              textAlign: TextAlign.center,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: AuraSpace.s16),
            action!,
          ],
        ],
      ),
    );
  }
}

class AuraErrorState extends StatelessWidget {
  const AuraErrorState({
    super.key,
    required this.title,
    required this.body,
    this.action,
  });

  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      borderColor: AuraSurface.dangerInk.withValues(alpha: 0.22),
      color: AuraSurface.dangerBg.withValues(alpha: 0.9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: AuraIconSize.md,
                color: AuraSurface.dangerInk,
              ),
              const SizedBox(width: AuraSpace.s8),
              Expanded(
                child: Text(
                  title,
                  style: AuraText.subtitle.copyWith(
                    color: AuraSurface.dangerInk,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(body, style: AuraText.muted),
          if (action != null) ...[
            const SizedBox(height: AuraSpace.s12),
            action!,
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BUTTONS
// ─────────────────────────────────────────────────────────────────────────────

/// Primary CTA — accent gradient background.
class AuraPrimaryButton extends StatelessWidget {
  const AuraPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AuraRadius.r14),
        splashColor: Colors.white12,
        child: Ink(
          decoration: BoxDecoration(
            gradient: onPressed != null ? AuraGradients.accent : null,
            color: onPressed == null ? AuraSurface.faint : null,
            borderRadius: BorderRadius.circular(AuraRadius.r14),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: AuraIconSize.sm, color: Colors.white),
                  const SizedBox(width: AuraSpace.s8),
                ],
                Text(
                  label,
                  style: AuraText.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Secondary CTA — outlined border.
class AuraSecondaryButton extends StatelessWidget {
  const AuraSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon == null
          ? const SizedBox.shrink()
          : Icon(icon, size: AuraIconSize.sm),
      label: Text(label),
    );
  }
}

/// Ghost / text button.
class AuraGhostButton extends StatelessWidget {
  const AuraGhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: icon == null
          ? const SizedBox.shrink()
          : Icon(icon, size: AuraIconSize.sm),
      label: Text(label),
    );
  }
}

/// Action pill — for feed card action rows (respond, save, share, etc.)
class AuraActionPill extends StatelessWidget {
  const AuraActionPill({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        splashColor: AuraSurface.accentSoft,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s12,
            vertical: AuraSpace.s8,
          ),
          decoration: BoxDecoration(
            color: active ? AuraSurface.accentSoft : AuraSurface.subtle,
            borderRadius: BorderRadius.circular(AuraRadius.pill),
            border: Border.all(
              color: active
                  ? AuraSurface.accent.withValues(alpha: 0.35)
                  : AuraSurface.divider,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: AuraIconSize.sm,
                color: active ? AuraSurface.accentText : AuraSurface.muted,
              ),
              const SizedBox(width: AuraSpace.s6),
              Text(
                label,
                style: AuraText.label.copyWith(
                  color: active ? AuraSurface.accentText : AuraSurface.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FORM INPUTS
// ─────────────────────────────────────────────────────────────────────────────

class AuraInput extends StatelessWidget {
  const AuraInput({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.minLines,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.suffixIcon,
    this.prefixIcon,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final int? minLines;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      minLines: minLines,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      style: AuraText.body,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
      ),
    );
  }
}

class AuraSearchBar extends StatelessWidget {
  const AuraSearchBar({
    super.key,
    required this.controller,
    this.hintText = 'Search',
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: onSubmitted,
      style: AuraText.body,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search_rounded, size: AuraIconSize.md),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AVATAR
// ─────────────────────────────────────────────────────────────────────────────

/// Canonical Aura avatar — single implementation for the entire app.
class AuraAvatar extends StatelessWidget {
  const AuraAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 44,
  });

  final String name;
  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty
        ? '?'
        : trimmed.substring(0, 1).toUpperCase();
    final url = (imageUrl ?? '').trim();

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AuraGradients.accent,
      ),
      child: ClipOval(
        child: url.isEmpty
            ? _InitialView(initial: initial, size: size)
            : Image.network(
                url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    _InitialView(initial: initial, size: size),
              ),
      ),
    );
  }
}

class _InitialView extends StatelessWidget {
  const _InitialView({required this.initial, required this.size});

  final String initial;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: AuraText.body.copyWith(
          fontWeight: FontWeight.w700,
          color: Colors.white,
          fontSize: size * 0.4,
          height: 1,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BADGES & CHIPS
// ─────────────────────────────────────────────────────────────────────────────

class AuraBadge extends StatelessWidget {
  const AuraBadge({
    super.key,
    required this.label,
    this.backgroundColor = AuraSurface.accentSoft,
    this.textColor = AuraSurface.accentText,
    this.icon,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s10,
        vertical: AuraSpace.s6,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: AuraIconSize.xs, color: textColor),
            const SizedBox(width: AuraSpace.s6),
          ],
          Text(
            label,
            style: AuraText.label.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class AuraStatusChip extends StatelessWidget {
  const AuraStatusChip({
    super.key,
    required this.label,
    this.backgroundColor = AuraSurface.infoBg,
    this.textColor = AuraSurface.infoInk,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return AuraBadge(
      label: label,
      backgroundColor: backgroundColor,
      textColor: textColor,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// METRIC & ADMIN TILES
// ─────────────────────────────────────────────────────────────────────────────

class AuraMetricCard extends StatelessWidget {
  const AuraMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.subtext,
    this.icon,
  });

  final String label;
  final String value;
  final String? subtext;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: AuraSurface.accent, size: AuraIconSize.md),
                const SizedBox(width: AuraSpace.s8),
              ],
              Expanded(child: Text(label, style: AuraText.muted)),
            ],
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(value, style: AuraText.headline),
          if (subtext != null && subtext!.trim().isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text(subtext!, style: AuraText.small),
          ],
        ],
      ),
    );
  }
}

class AuraAdminTile extends StatelessWidget {
  const AuraAdminTile({
    super.key,
    required this.title,
    required this.body,
    required this.icon,
    this.action,
  });

  final String title;
  final String body;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: AuraGradients.accent,
              borderRadius: BorderRadius.circular(AuraRadius.r12),
            ),
            child: Icon(icon, color: Colors.white, size: AuraIconSize.md),
          ),
          const SizedBox(width: AuraSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AuraText.subtitle),
                const SizedBox(height: AuraSpace.s4),
                Text(body, style: AuraText.muted),
                if (action != null) ...[
                  const SizedBox(height: AuraSpace.s12),
                  action!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONVERSATION & NOTIFICATION TILES
// ─────────────────────────────────────────────────────────────────────────────

class AuraConversationTile extends StatelessWidget {
  const AuraConversationTile({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.leading,
    this.badge,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;
  final Widget? leading;
  final Widget? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AuraSpace.s12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(title, style: AuraText.subtitle)),
                    if (badge != null) badge!,
                  ],
                ),
                const SizedBox(height: AuraSpace.s4),
                Text(subtitle, style: AuraText.muted),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AuraSpace.s10),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class AuraNotificationTile extends StatelessWidget {
  const AuraNotificationTile({
    super.key,
    required this.title,
    required this.body,
    this.trailing,
    this.onTap,
    this.icon,
  });

  final String title;
  final String body;
  final Widget? trailing;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AuraSurface.accentSoft,
              borderRadius: BorderRadius.circular(AuraRadius.r12),
              border: Border.all(
                color: AuraSurface.accent.withValues(alpha: 0.2),
              ),
            ),
            child: Icon(
              icon ?? Icons.notifications_none_rounded,
              size: AuraIconSize.sm,
              color: AuraSurface.accentText,
            ),
          ),
          const SizedBox(width: AuraSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AuraText.subtitle),
                const SizedBox(height: AuraSpace.s4),
                Text(body, style: AuraText.muted),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AuraSpace.s10),
            trailing!,
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MESSAGING
// ─────────────────────────────────────────────────────────────────────────────

class AuraMessageBubble extends StatelessWidget {
  const AuraMessageBubble({
    super.key,
    required this.body,
    required this.isMine,
    this.attachmentLabel,
    this.timestamp,
  });

  final String body;
  final bool isMine;
  final String? attachmentLabel;
  final String? timestamp;

  @override
  Widget build(BuildContext context) {
    final bg = isMine ? AuraSurface.accentSoft : AuraSurface.subtle;
    final borderColor = isMine
        ? AuraSurface.accent.withValues(alpha: 0.3)
        : AuraSurface.divider;
    final align = isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: align,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 620),
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s14,
            vertical: AuraSpace.s12,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AuraRadius.r18),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: align,
            children: [
              if (body.trim().isNotEmpty) Text(body, style: AuraText.body),
              if (attachmentLabel != null &&
                  attachmentLabel!.trim().isNotEmpty) ...[
                const SizedBox(height: AuraSpace.s8),
                AuraStatusChip(
                  label: attachmentLabel!,
                  backgroundColor: AuraSurface.page.withValues(alpha: 0.35),
                  textColor: AuraSurface.ink,
                ),
              ],
            ],
          ),
        ),
        if (timestamp != null && timestamp!.trim().isNotEmpty) ...[
          const SizedBox(height: AuraSpace.s4),
          Text(timestamp!, style: AuraText.micro),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REALTIME / CALL
// ─────────────────────────────────────────────────────────────────────────────

class AuraCallBanner extends StatelessWidget {
  const AuraCallBanner({
    super.key,
    required this.title,
    required this.body,
    this.onJoin,
    this.onDismiss,
  });

  final String title;
  final String body;
  final VoidCallback? onJoin;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      borderColor: AuraSurface.accent.withValues(alpha: 0.28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: AuraGradients.accent,
              borderRadius: BorderRadius.circular(AuraRadius.r14),
            ),
            child: const Icon(
              Icons.call,
              color: Colors.white,
              size: AuraIconSize.md,
            ),
          ),
          const SizedBox(width: AuraSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AuraText.subtitle),
                const SizedBox(height: AuraSpace.s4),
                Text(body, style: AuraText.muted),
              ],
            ),
          ),
          const SizedBox(width: AuraSpace.s10),
          if (onDismiss != null)
            TextButton(onPressed: onDismiss, child: const Text('Dismiss')),
          if (onJoin != null) ...[
            const SizedBox(width: AuraSpace.s8),
            FilledButton(onPressed: onJoin, child: const Text('Join')),
          ],
        ],
      ),
    );
  }
}

class AuraRealtimeControlBar extends StatelessWidget {
  const AuraRealtimeControlBar({
    super.key,
    required this.micOn,
    required this.cameraOn,
    required this.onToggleMic,
    required this.onToggleCamera,
    required this.onHangUp,
  });

  final bool micOn;
  final bool cameraOn;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleCamera;
  final VoidCallback onHangUp;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ControlButton(
            icon: micOn ? Icons.mic_none_rounded : Icons.mic_off_rounded,
            label: micOn ? 'Mute' : 'Unmute',
            onPressed: onToggleMic,
          ),
          const SizedBox(width: AuraSpace.s10),
          _ControlButton(
            icon: cameraOn
                ? Icons.videocam_off_rounded
                : Icons.videocam_rounded,
            label: cameraOn ? 'Camera off' : 'Camera on',
            onPressed: onToggleCamera,
          ),
          const SizedBox(width: AuraSpace.s10),
          FilledButton.icon(
            onPressed: onHangUp,
            icon: const Icon(Icons.call_end_rounded),
            label: const Text('End'),
            style: FilledButton.styleFrom(
              backgroundColor: AuraSurface.dangerInk,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: AuraIconSize.sm),
      label: Text(label),
    );
  }
}
