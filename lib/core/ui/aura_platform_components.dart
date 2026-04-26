import 'package:flutter/material.dart';

import 'aura_card.dart';
import 'aura_design_system.dart';
import 'aura_radius.dart';
import 'aura_space.dart';
import 'aura_surface.dart';
import 'aura_text.dart';

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
    if (padding != null) {
      body = Padding(padding: padding!, child: body);
    }

    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AuraGradients.page),
      child: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x1A5B6CFF),
                      Colors.transparent,
                      Color(0x09000000),
                    ],
                    stops: [0.0, 0.34, 1.0],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: alignTop ? Alignment.topCenter : Alignment.center,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: SizedBox(width: double.infinity, child: body),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
                Text(title, style: AuraText.title),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: AuraSpace.s8),
                  Text(subtitle!, style: AuraText.muted),
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
              Text(title, style: AuraText.title.copyWith(fontSize: 17)),
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: AuraSpace.s6),
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
    return FilledButton.icon(
      onPressed: onPressed,
      icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: AuraIconSize.sm),
      label: Text(label),
    );
  }
}

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
      icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: AuraIconSize.sm),
      label: Text(label),
    );
  }
}

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
      icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: AuraIconSize.sm),
      label: Text(label),
    );
  }
}

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
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search_rounded, size: AuraIconSize.md),
      ),
    );
  }
}

class AuraBottomNavigation extends StatelessWidget {
  const AuraBottomNavigation({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<AuraNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      destinations: [
        for (final item in items)
          NavigationDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.selectedIcon ?? item.icon),
            label: item.label,
          ),
      ],
    );
  }
}

class AuraSideRail extends StatelessWidget {
  const AuraSideRail({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.width = 248,
  });

  final List<AuraNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF12161E), Color(0xFF0F1318)],
        ),
        border: Border(
          right: BorderSide(color: AuraSurface.divider),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(AuraSpace.lg),
        children: [
          const SizedBox(height: AuraSpace.xs),
          for (var i = 0; i < items.length; i++) ...[
            _AuraRailTile(
              item: items[i],
              selected: i == selectedIndex,
              onTap: () => onSelected(i),
            ),
            const SizedBox(height: AuraSpace.xs),
          ],
        ],
      ),
    );
  }
}

class AuraNavItem {
  const AuraNavItem({
    required this.label,
    required this.icon,
    this.selectedIcon,
    required this.path,
    this.isPrimary = false,
  });

  final String label;
  final IconData icon;
  final IconData? selectedIcon;
  final String path;
  final bool isPrimary;
}

class _AuraRailTile extends StatelessWidget {
  const _AuraRailTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AuraNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AuraSurface.accentSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(AuraRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.md,
            vertical: AuraSpace.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AuraRadius.card),
            border: Border.all(
              color: selected ? AuraSurface.accent : AuraSurface.divider,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? (item.selectedIcon ?? item.icon) : item.icon,
                size: AuraIconSize.md,
                color: selected ? AuraSurface.ink : AuraSurface.muted,
              ),
              const SizedBox(width: AuraSpace.s10),
              Expanded(
                child: Text(
                  item.label,
                  style: AuraText.body.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AuraSurface.ink : AuraSurface.muted,
                  ),
                ),
              ),
              if (item.isPrimary)
                const Icon(Icons.bolt_rounded, size: AuraIconSize.sm, color: AuraSurface.accent),
            ],
          ),
        ),
      ),
    );
  }
}

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
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AuraIconSize.lg, color: AuraSurface.muted),
          const SizedBox(height: AuraSpace.s12),
          Text(title, style: AuraText.title.copyWith(fontSize: 17)),
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
      borderColor: AuraSurface.dangerInk.withValues(alpha: 0.24),
      color: AuraSurface.dangerBg.withValues(alpha: 0.92),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AuraText.title.copyWith(fontSize: 17)),
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

class AuraLoadingState extends StatelessWidget {
  const AuraLoadingState({
    super.key,
    this.message = 'Loading…',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AuraSpace.s10),
          Expanded(child: Text(message, style: AuraText.muted)),
        ],
      ),
    );
  }
}

class AuraBadge extends StatelessWidget {
  const AuraBadge({
    super.key,
    required this.label,
    this.backgroundColor = AuraSurface.accentSoft,
    this.textColor = AuraSurface.ink,
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
        borderRadius: BorderRadius.circular(999),
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
            style: AuraText.small.copyWith(
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
    final initial = trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF2A3357), Color(0xFF5B6CFF)],
        ),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: ClipOval(
        child: imageUrl == null || imageUrl!.trim().isEmpty
            ? Center(
                child: Text(
                  initial,
                  style: AuraText.body.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              )
            : Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: Text(
                    initial,
                    style: AuraText.body.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

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
          Text(value, style: AuraText.title.copyWith(fontSize: 26)),
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
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: AuraGradients.accent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: AuraIconSize.md),
          ),
          const SizedBox(width: AuraSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AuraText.title.copyWith(fontSize: 17)),
                const SizedBox(height: AuraSpace.s6),
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
                    Expanded(
                      child: Text(title, style: AuraText.title.copyWith(fontSize: 17)),
                    ),
                    if (badge != null) badge!,
                  ],
                ),
                const SizedBox(height: AuraSpace.s6),
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
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AuraSurface.divider),
            ),
            child: Icon(icon ?? Icons.notifications_none_rounded, size: AuraIconSize.sm),
          ),
          const SizedBox(width: AuraSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AuraText.title.copyWith(fontSize: 17)),
                const SizedBox(height: AuraSpace.s6),
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
    final bg = isMine ? AuraSurface.accentSoft : AuraSurface.elevated;
    final align = isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: align,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 620),
          padding: const EdgeInsets.all(AuraSpace.s12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: Column(
            crossAxisAlignment: align,
            children: [
              if (body.trim().isNotEmpty)
                Text(body, style: AuraText.body),
              if (attachmentLabel != null && attachmentLabel!.trim().isNotEmpty) ...[
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
          const SizedBox(height: AuraSpace.s6),
          Text(timestamp!, style: AuraText.small),
        ],
      ],
    );
  }
}

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
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.call, color: Colors.white, size: AuraIconSize.md),
          ),
          const SizedBox(width: AuraSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AuraText.title.copyWith(fontSize: 17)),
                const SizedBox(height: AuraSpace.s6),
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
            icon: cameraOn ? Icons.videocam_off_rounded : Icons.videocam_rounded,
            label: cameraOn ? 'Camera off' : 'Camera on',
            onPressed: onToggleCamera,
          ),
          const SizedBox(width: AuraSpace.s10),
          FilledButton.icon(
            onPressed: onHangUp,
            icon: const Icon(Icons.call_end_rounded),
            label: const Text('End'),
          ),
        ],
      ),
    );
  }
}

class AuraGlassCard extends StatelessWidget {
  const AuraGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.trailing,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          child,
          if (trailing != null) ...[
            const SizedBox(height: AuraSpace.s12),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class AuraGradientHero extends StatelessWidget {
  const AuraGradientHero({
    super.key,
    required this.title,
    required this.subtitle,
    this.badge,
    this.actions = const [],
    this.metrics = const [],
    this.trailing,
  });

  final String title;
  final String subtitle;
  final String? badge;
  final List<Widget> actions;
  final List<Widget> metrics;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.lg),
      decoration: BoxDecoration(
        gradient: AuraGradients.header,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AuraSurface.divider),
        boxShadow: AuraShadows.panel,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 920;
          final core = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (badge != null) ...[
                AuraBadge(
                  label: badge!,
                  icon: Icons.auto_awesome_outlined,
                ),
                const SizedBox(height: AuraSpace.s12),
              ],
              Text(
                title,
                style: AuraText.title.copyWith(fontSize: 34, height: 1.05),
              ),
              const SizedBox(height: AuraSpace.s10),
              Text(subtitle, style: AuraText.body),
              if (metrics.isNotEmpty) ...[
                const SizedBox(height: AuraSpace.s16),
                Wrap(
                  spacing: AuraSpace.s10,
                  runSpacing: AuraSpace.s10,
                  children: metrics,
                ),
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: AuraSpace.s16),
                Wrap(
                  spacing: AuraSpace.s10,
                  runSpacing: AuraSpace.s10,
                  children: actions,
                ),
              ],
            ],
          );

          if (!isWide && trailing == null) return core;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: core),
              if (trailing != null) ...[
                const SizedBox(width: AuraSpace.s16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: trailing!,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class AuraFeatureGrid extends StatelessWidget {
  const AuraFeatureGrid({
    super.key,
    required this.children,
    this.minTileWidth = 240,
  });

  final List<Widget> children;
  final double minTileWidth;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AuraSpace.s12,
      runSpacing: AuraSpace.s12,
      children: [
        for (final child in children)
          ConstrainedBox(
            constraints: BoxConstraints(minWidth: minTileWidth, maxWidth: 420),
            child: child,
          ),
      ],
    );
  }
}

class AuraActionTile extends StatelessWidget {
  const AuraActionTile({
    super.key,
    required this.title,
    required this.body,
    required this.icon,
    this.onTap,
    this.trailing,
  });

  final String title;
  final String body;
  final IconData icon;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: AuraGradients.accent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: AuraIconSize.md),
          ),
          const SizedBox(width: AuraSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AuraText.title.copyWith(fontSize: 17)),
                const SizedBox(height: AuraSpace.s6),
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

class AuraTrustBadge extends StatelessWidget {
  const AuraTrustBadge({
    super.key,
    required this.label,
    this.icon = Icons.shield_outlined,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AuraBadge(
      label: label,
      icon: icon,
      backgroundColor: AuraSurface.accentSoft,
      textColor: AuraSurface.ink,
    );
  }
}

class AuraAnnouncementCard extends StatelessWidget {
  const AuraAnnouncementCard({
    super.key,
    required this.title,
    required this.body,
    this.meta,
    this.onTap,
  });

  final String title;
  final String body;
  final String? meta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AuraTrustBadge(label: 'Announcement', icon: Icons.campaign_outlined),
          const SizedBox(height: AuraSpace.s10),
          Text(title, style: AuraText.title.copyWith(fontSize: 18)),
          if (meta != null && meta!.trim().isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text(meta!, style: AuraText.small),
          ],
          const SizedBox(height: AuraSpace.s10),
          Text(body, style: AuraText.body),
        ],
      ),
    );
  }
}

class AuraInstitutionCard extends StatelessWidget {
  const AuraInstitutionCard({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
  });

  final String title;
  final String body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AuraTrustBadge(label: 'Institution', icon: Icons.apartment_outlined),
          const SizedBox(height: AuraSpace.s10),
          Text(title, style: AuraText.title.copyWith(fontSize: 18)),
          const SizedBox(height: AuraSpace.s8),
          Text(body, style: AuraText.body),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s12),
            Wrap(
              spacing: AuraSpace.s10,
              runSpacing: AuraSpace.s10,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }
}

class AuraProfileHeader extends StatelessWidget {
  const AuraProfileHeader({
    super.key,
    required this.title,
    required this.handle,
    this.bio,
    this.actions = const [],
    this.badges = const [],
  });

  final String title;
  final String handle;
  final String? bio;
  final List<Widget> actions;
  final List<Widget> badges;

  @override
  Widget build(BuildContext context) {
    return AuraGradientHero(
      badge: 'Identity',
      title: title,
      subtitle: bio?.trim().isNotEmpty == true
          ? bio!
          : 'Trusted identity, record, and public presence.',
      actions: [
        AuraTrustBadge(label: handle.isNotEmpty ? handle : 'Presence'),
        ...actions,
      ],
      metrics: badges,
    );
  }
}

class AuraAIInsightPanel extends StatelessWidget {
  const AuraAIInsightPanel({
    super.key,
    required this.title,
    required this.body,
    this.items = const [],
  });

  final String title;
  final String body;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AuraTrustBadge(label: 'AI review', icon: Icons.auto_awesome_outlined),
          const SizedBox(height: AuraSpace.s10),
          Text(title, style: AuraText.title.copyWith(fontSize: 18)),
          const SizedBox(height: AuraSpace.s8),
          Text(body, style: AuraText.body),
          if (items.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s12),
            for (final item in items) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: AuraSpace.s8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_outline, size: 18, color: AuraSurface.accent),
                    const SizedBox(width: AuraSpace.s8),
                    Expanded(child: Text(item, style: AuraText.muted)),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class AuraLoadingSkeleton extends StatelessWidget {
  const AuraLoadingSkeleton({
    super.key,
    this.height = 120,
  });

  final double height;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: SizedBox(
        height: height,
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}

class AuraComposerDock extends StatelessWidget {
  const AuraComposerDock({
    super.key,
    required this.child,
    this.actions = const [],
  });

  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          child,
          if (actions.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s12),
            Wrap(
              spacing: AuraSpace.s10,
              runSpacing: AuraSpace.s10,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }
}

class AuraAttachmentDock extends StatelessWidget {
  const AuraAttachmentDock({
    super.key,
    required this.actions,
  });

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Wrap(
        spacing: AuraSpace.s10,
        runSpacing: AuraSpace.s10,
        children: actions,
      ),
    );
  }
}

class AuraVoiceRecorderPanel extends StatelessWidget {
  const AuraVoiceRecorderPanel({
    super.key,
    required this.isRecording,
    required this.elapsedLabel,
    this.onStop,
    this.onCancel,
  });

  final bool isRecording;
  final String elapsedLabel;
  final VoidCallback? onStop;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Row(
        children: [
          Icon(
            isRecording ? Icons.graphic_eq_rounded : Icons.mic_none_rounded,
            color: AuraSurface.accent,
          ),
          const SizedBox(width: AuraSpace.s10),
          Expanded(
            child: Text(
              isRecording ? 'Recording voice note' : 'Voice note ready',
              style: AuraText.title.copyWith(fontSize: 17),
            ),
          ),
          Text(elapsedLabel, style: AuraText.muted),
          const SizedBox(width: AuraSpace.s10),
          if (onCancel != null)
            TextButton(onPressed: onCancel, child: const Text('Cancel')),
          if (onStop != null)
            FilledButton(onPressed: onStop, child: const Text('Stop')),
        ],
      ),
    );
  }
}

class AuraCallOverlay extends StatelessWidget {
  const AuraCallOverlay({
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
      borderColor: AuraSurface.accent.withValues(alpha: 0.32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AuraTrustBadge(label: 'Incoming call', icon: Icons.call),
          const SizedBox(height: AuraSpace.s10),
          Text(title, style: AuraText.title.copyWith(fontSize: 18)),
          const SizedBox(height: AuraSpace.s6),
          Text(body, style: AuraText.muted),
          if (onJoin != null || onDismiss != null) ...[
            const SizedBox(height: AuraSpace.s12),
            Wrap(
              spacing: AuraSpace.s10,
              runSpacing: AuraSpace.s10,
              children: [
                if (onJoin != null)
                  FilledButton(onPressed: onJoin, child: const Text('Join')),
                if (onDismiss != null)
                  OutlinedButton(onPressed: onDismiss, child: const Text('Dismiss')),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class AuraLiveRoomLayout extends StatelessWidget {
  const AuraLiveRoomLayout({
    super.key,
    required this.stage,
    required this.sideRail,
  });

  final Widget stage;
  final Widget sideRail;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1100;
        if (!isWide) {
          return Column(
            children: [
              stage,
              const SizedBox(height: AuraSpace.s12),
              sideRail,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: stage),
            const SizedBox(width: AuraSpace.s12),
            SizedBox(width: 340, child: sideRail),
          ],
        );
      },
    );
  }
}

class AuraParticipantTile extends StatelessWidget {
  const AuraParticipantTile({
    super.key,
    required this.name,
    required this.subtitle,
    this.leading,
    this.trailing,
  });

  final String name;
  final String subtitle;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AuraConversationTile(
      title: name,
      subtitle: subtitle,
      leading: leading,
      trailing: trailing,
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
