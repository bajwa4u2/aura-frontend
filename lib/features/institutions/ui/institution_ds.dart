import 'package:flutter/material.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';

/// Phase 6.6 — Institution surface design system.
///
/// Shared primitives used across the four institution identity surfaces
/// (Overview / Edit / Profile / Public Preview). The point of this file is
/// continuity — every institution screen composes the same spacing, card,
/// section, badge, and identity-header primitives so the workspace feels
/// like one product, not four bolted-on forms.
///
/// Conventions:
///  * `Ins…` prefix on every public symbol so it's obvious at a call site
///    that we are inside the institution surface vocabulary.
///  * Tokens (`InsSpacing`) compose existing `AuraSpace` / `AuraSurface`
///    values — never re-define brand colours or hard-code spacing.
///  * Tone (`InsTone`) is the only sanctioned way to express status colour;
///    no surface picks raw red/green/yellow itself.

// ─────────────────────────────────────────────────────────────────────────────
// SPACING / SIZING TOKENS
// ─────────────────────────────────────────────────────────────────────────────

class InsSpacing {
  InsSpacing._();

  /// Outer page horizontal padding.
  static const double screenHPad = AuraSpace.s20;
  static const double screenVPad = AuraSpace.s24;

  /// Vertical gap between major sections (eyebrow → next eyebrow).
  static const double sectionGap = AuraSpace.s28;

  /// Gap between a section's header line and its first content row.
  static const double headerToContentGap = AuraSpace.s14;

  /// Gap between cards inside the same section / grid.
  static const double cardGap = AuraSpace.s12;

  /// Standard card interior padding.
  static const double cardPadding = AuraSpace.s18;

  /// Tighter card interior — used for action rows / list-style cards.
  static const double cardPaddingDense = AuraSpace.s14;

  /// Inline cluster gap (icon ↔ label, badge ↔ badge).
  static const double inlineGap = AuraSpace.s10;

  /// Workspace-page max content width — matches existing institution shells.
  static const double contentMaxWidth = 1080;
}

// ─────────────────────────────────────────────────────────────────────────────
// TONE — the only sanctioned status colour vocabulary on institution surfaces
// ─────────────────────────────────────────────────────────────────────────────

enum InsTone { neutral, ok, warn, danger, info }

class InsToneStyle {
  const InsToneStyle({
    required this.bg,
    required this.fg,
    required this.border,
    required this.icon,
  });

  final Color bg;
  final Color fg;
  final Color border;
  final IconData icon;

  static InsToneStyle of(InsTone tone) {
    switch (tone) {
      case InsTone.ok:
        return const InsToneStyle(
          bg: Color(0x2222C55E),
          fg: AuraSurface.goodInk,
          border: Color(0x4422C55E),
          icon: Icons.check_circle_rounded,
        );
      case InsTone.warn:
        return const InsToneStyle(
          bg: Color(0x22F59E0B),
          fg: AuraSurface.warnInk,
          border: Color(0x44F59E0B),
          icon: Icons.warning_amber_rounded,
        );
      case InsTone.danger:
        return const InsToneStyle(
          bg: Color(0x22EF4444),
          fg: AuraSurface.dangerInk,
          border: Color(0x44EF4444),
          icon: Icons.error_outline_rounded,
        );
      case InsTone.info:
        return InsToneStyle(
          bg: AuraSurface.accentSoft,
          fg: AuraSurface.accentText,
          border: AuraSurface.accent.withValues(alpha: 0.3),
          icon: Icons.info_outline_rounded,
        );
      case InsTone.neutral:
        return const InsToneStyle(
          bg: AuraSurface.subtle,
          fg: AuraSurface.muted,
          border: AuraSurface.divider,
          icon: Icons.circle_outlined,
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN — every institution surface composes its content inside InsScreen
// ─────────────────────────────────────────────────────────────────────────────

class InsScreen extends StatelessWidget {
  const InsScreen({super.key, required this.children, this.maxWidth});

  final List<Widget> children;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        InsSpacing.screenHPad,
        InsSpacing.screenVPad,
        InsSpacing.screenHPad,
        AuraSpace.s32,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth ?? InsSpacing.contentMaxWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}

/// Vertical gap between two stacked sections.
class InsSectionGap extends StatelessWidget {
  const InsSectionGap({super.key});
  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: InsSpacing.sectionGap);
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION — eyebrow + title + helper + content. Used everywhere.
// ─────────────────────────────────────────────────────────────────────────────

class InsSection extends StatelessWidget {
  const InsSection({
    super.key,
    required this.title,
    required this.child,
    this.eyebrow,
    this.helper,
    this.trailing,
  });

  final String title;
  final String? eyebrow;
  final String? helper;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null && eyebrow!.trim().isNotEmpty) ...[
          Text(
            eyebrow!.toUpperCase(),
            style: AuraText.micro.copyWith(
              color: AuraSurface.faint,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: AuraSpace.s6),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: Text(title, style: AuraText.subtitle)),
            if (trailing != null) trailing!,
          ],
        ),
        if (helper != null && helper!.trim().isNotEmpty) ...[
          const SizedBox(height: AuraSpace.s4),
          Text(
            helper!,
            style: AuraText.small.copyWith(
              color: AuraSurface.muted,
              height: 1.5,
            ),
          ),
        ],
        const SizedBox(height: InsSpacing.headerToContentGap),
        child,
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARDS
// ─────────────────────────────────────────────────────────────────────────────

/// Plain institution card surface — same border / radius / padding everywhere.
class InsCard extends StatelessWidget {
  const InsCard({
    super.key,
    required this.child,
    this.padding,
    this.tone,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  /// When set, the card adopts a tinted surface aligned to the tone.
  final InsTone? tone;

  @override
  Widget build(BuildContext context) {
    final t = tone == null ? null : InsToneStyle.of(tone!);
    return Container(
      padding: padding ?? const EdgeInsets.all(InsSpacing.cardPadding),
      decoration: BoxDecoration(
        color: t?.bg ?? AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: t?.border ?? AuraSurface.divider),
      ),
      child: child,
    );
  }
}

/// Status card — title + value pill + one-line explanation.
///
/// "Standing", "Role", "Official Speech", "Domain Trust" all use this.
class InsStatusCard extends StatelessWidget {
  const InsStatusCard({
    super.key,
    required this.title,
    required this.value,
    required this.tone,
    this.helper,
    this.icon,
  });

  final String title;
  final String value;
  final String? helper;
  final InsTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = InsToneStyle.of(tone);
    return Container(
      padding: const EdgeInsets.all(InsSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: AuraText.micro.copyWith(
              color: AuraSurface.faint,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: AuraSpace.s10),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.s10,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: t.bg,
              borderRadius: BorderRadius.circular(AuraRadius.pill),
              border: Border.all(color: t.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon ?? t.icon, size: 12, color: t.fg),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AuraText.small.copyWith(
                      color: t.fg,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (helper != null && helper!.trim().isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s10),
            Text(
              helper!,
              style: AuraText.small.copyWith(
                color: AuraSurface.muted,
                height: 1.45,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

/// Action card — leading tone-tinted icon, title, body, optional CTA + badge.
class InsActionCard extends StatelessWidget {
  const InsActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.onTap,
    this.tone = InsTone.info,
    this.cta,
    this.badge,
    this.disabledHint,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onTap;
  final InsTone tone;
  final String? cta;
  final int? badge;

  /// Text shown in place of the CTA when [onTap] is null (e.g. "Unavailable").
  final String? disabledHint;

  @override
  Widget build(BuildContext context) {
    final t = InsToneStyle.of(tone);
    final enabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        child: Opacity(
          opacity: enabled ? 1 : 0.55,
          child: Container(
            padding: const EdgeInsets.all(InsSpacing.cardPaddingDense),
            decoration: BoxDecoration(
              color: AuraSurface.card,
              borderRadius: BorderRadius.circular(AuraRadius.card),
              border: Border.all(color: AuraSurface.divider),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: t.bg,
                        borderRadius: BorderRadius.circular(AuraRadius.r10),
                        border: Border.all(color: t.border),
                      ),
                      child: Icon(icon, size: 18, color: t.fg),
                    ),
                    if (badge != null && badge! > 0)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          decoration: BoxDecoration(
                            color: AuraSurface.dangerInk,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Center(
                            child: Text(
                              '$badge',
                              style: AuraText.micro.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: InsSpacing.inlineGap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style:
                            AuraText.body.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        body,
                        style: AuraText.small.copyWith(
                          color: AuraSurface.muted,
                          height: 1.45,
                        ),
                      ),
                      if (enabled && cta != null) ...[
                        const SizedBox(height: AuraSpace.s10),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              cta!,
                              style: AuraText.small.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AuraSurface.accentText,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 12,
                              color: AuraSurface.accentText,
                            ),
                          ],
                        ),
                      ] else if (!enabled && disabledHint != null) ...[
                        const SizedBox(height: AuraSpace.s10),
                        Text(
                          disabledHint!,
                          style: AuraText.small.copyWith(
                            color: AuraSurface.faint,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
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

// ─────────────────────────────────────────────────────────────────────────────
// IDENTITY HEADER — premium institution identity strip
// ─────────────────────────────────────────────────────────────────────────────

class InsBadge extends StatelessWidget {
  const InsBadge({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
  });

  final String label;
  final InsTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = InsToneStyle.of(tone);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(color: t.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon ?? t.icon, size: 11, color: t.fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: AuraText.micro.copyWith(
              color: t.fg,
              fontWeight: FontWeight.w800,
              fontSize: 10,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class InsFact {
  const InsFact({required this.icon, required this.text});
  final IconData icon;
  final String text;
}

class InsFactRow extends StatelessWidget {
  const InsFactRow({super.key, required this.fact});
  final InsFact fact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(fact.icon, size: 14, color: AuraSurface.faint),
        const SizedBox(width: 6),
        Text(
          fact.text,
          style: AuraText.small.copyWith(color: AuraSurface.muted),
        ),
      ],
    );
  }
}

class InsInstitutionAvatar extends StatelessWidget {
  const InsInstitutionAvatar({
    super.key,
    required this.name,
    this.logoUrl,
    this.size = 56,
  });

  final String name;
  final String? logoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty
        ? name.trim().substring(0, 1).toUpperCase()
        : 'I';

    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AuraSurface.accentSoft,
        borderRadius: BorderRadius.circular(AuraRadius.r14),
        border: Border.all(color: AuraSurface.accent.withValues(alpha: 0.25)),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: AuraText.headline.copyWith(
          color: AuraSurface.accentText,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.4,
        ),
      ),
    );

    if (logoUrl == null || logoUrl!.trim().isEmpty) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AuraRadius.r14),
      child: Image.network(
        logoUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}

/// Identity header used at the top of every institution identity surface.
///
/// Strong hierarchy: avatar (left) → name (display) → handle (muted) →
/// badge cluster → optional tagline → fact row (location, members…).
class InsIdentityHeader extends StatelessWidget {
  const InsIdentityHeader({
    super.key,
    required this.name,
    this.handle,
    this.logoUrl,
    this.tagline,
    this.badges = const [],
    this.facts = const [],
    this.trailing,
  });

  final String name;
  final String? handle;
  final String? logoUrl;
  final String? tagline;
  final List<Widget> badges;
  final List<InsFact> facts;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InsInstitutionAvatar(name: name, logoUrl: logoUrl, size: 64),
        const SizedBox(width: AuraSpace.s16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      name.trim().isEmpty ? 'Institution' : name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AuraText.headline,
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: AuraSpace.s10),
                    trailing!,
                  ],
                ],
              ),
              if (handle != null && handle!.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  '/${handle!.replaceFirst(RegExp(r'^/+'), '')}',
                  style: AuraText.small.copyWith(color: AuraSurface.muted),
                ),
              ],
              if (badges.isNotEmpty) ...[
                const SizedBox(height: AuraSpace.s10),
                Wrap(
                  spacing: AuraSpace.s6,
                  runSpacing: AuraSpace.s6,
                  children: badges,
                ),
              ],
              if (tagline != null && tagline!.trim().isNotEmpty) ...[
                const SizedBox(height: AuraSpace.s12),
                Text(
                  tagline!,
                  style: AuraText.body.copyWith(
                    color: AuraSurface.muted,
                    height: 1.55,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (facts.isNotEmpty) ...[
                const SizedBox(height: AuraSpace.s12),
                Wrap(
                  spacing: AuraSpace.s14,
                  runSpacing: AuraSpace.s8,
                  children: [
                    for (final f in facts) InsFactRow(fact: f),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COVER HEADER — premium institutional hero used on Profile + Public Preview
// ─────────────────────────────────────────────────────────────────────────────

/// Cover band + overlapping avatar + identity row.
///
/// Renders edge-to-edge inside its own constrained 1080 column. The avatar
/// hangs over the bottom of the cover by half its height; the identity row
/// (name, handle, badges, tagline, facts) sits below with consistent
/// horizontal padding.
///
/// Used on:
///   * Profile (workspace)        — full identity header.
///   * Public preview (workspace) — same primitive, framed by a preview bar.
///
/// The widget is layout-only: tones, badges, and facts are passed in by the
/// caller, which keeps this primitive surface-agnostic.
class InsCoverHeader extends StatelessWidget {
  const InsCoverHeader({
    super.key,
    required this.name,
    this.handle,
    this.tagline,
    this.logoUrl,
    this.coverUrl,
    this.badges = const [],
    this.facts = const [],
    this.coverHeight = 220,
    this.avatarSize = 96,
  });

  final String name;
  final String? handle;
  final String? tagline;
  final String? logoUrl;
  final String? coverUrl;
  final List<Widget> badges;
  final List<InsFact> facts;
  final double coverHeight;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: InsSpacing.contentMaxWidth,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CoverWithAvatar(
              coverUrl: coverUrl,
              logoUrl: logoUrl,
              name: name,
              coverHeight: coverHeight,
              avatarSize: avatarSize,
            ),
            // The cover stack already includes the avatar's lower half — pad
            // upward so the identity row clears the avatar without touching
            // it visually.
            const SizedBox(height: AuraSpace.s14),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: InsSpacing.screenHPad,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.trim().isEmpty ? 'Institution' : name,
                    style: AuraText.headline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (handle != null && handle!.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '/${handle!.replaceFirst(RegExp(r'^/+'), '')}',
                      style: AuraText.small.copyWith(color: AuraSurface.muted),
                    ),
                  ],
                  if (badges.isNotEmpty) ...[
                    const SizedBox(height: AuraSpace.s10),
                    Wrap(
                      spacing: AuraSpace.s6,
                      runSpacing: AuraSpace.s6,
                      children: badges,
                    ),
                  ],
                  if (tagline != null && tagline!.trim().isNotEmpty) ...[
                    const SizedBox(height: AuraSpace.s12),
                    Text(
                      tagline!,
                      style: AuraText.body.copyWith(
                        color: AuraSurface.muted,
                        height: 1.55,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (facts.isNotEmpty) ...[
                    const SizedBox(height: AuraSpace.s12),
                    Wrap(
                      spacing: AuraSpace.s14,
                      runSpacing: AuraSpace.s8,
                      children: [
                        for (final f in facts) InsFactRow(fact: f),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverWithAvatar extends StatelessWidget {
  const _CoverWithAvatar({
    required this.coverUrl,
    required this.logoUrl,
    required this.name,
    required this.coverHeight,
    required this.avatarSize,
  });

  final String? coverUrl;
  final String? logoUrl;
  final String name;
  final double coverHeight;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // Container needs to absorb both the cover and the lower half of the
      // overlapping avatar so the row below can sit naturally underneath.
      height: coverHeight + avatarSize / 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: coverHeight,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AuraRadius.lg),
              child: _CoverSurface(
                coverUrl: coverUrl,
                fallbackLogo: logoUrl,
              ),
            ),
          ),
          Positioned(
            left: InsSpacing.screenHPad,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AuraSurface.page,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.30),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipOval(
                child: _AvatarSurface(
                  size: avatarSize,
                  name: name,
                  logoUrl: logoUrl,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverSurface extends StatelessWidget {
  const _CoverSurface({required this.coverUrl, required this.fallbackLogo});

  final String? coverUrl;
  final String? fallbackLogo;

  @override
  Widget build(BuildContext context) {
    final url = (coverUrl ?? '').trim();
    if (url.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const _CoverFallback(),
          ),
          // Soft bottom darkening so badges/text in the row below have
          // breathing room when the cover is bright.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.30),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return const _CoverFallback();
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AuraSurface.accent.withValues(alpha: 0.30),
            AuraSurface.accent.withValues(alpha: 0.08),
            AuraSurface.subtle,
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.apartment_rounded,
          size: 48,
          color: AuraSurface.accentText,
        ),
      ),
    );
  }
}

class _AvatarSurface extends StatelessWidget {
  const _AvatarSurface({
    required this.size,
    required this.name,
    required this.logoUrl,
  });

  final double size;
  final String name;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final url = (logoUrl ?? '').trim();
    final initial = name.trim().isNotEmpty
        ? name.trim().substring(0, 1).toUpperCase()
        : 'I';
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AuraSurface.accentSoft,
        shape: BoxShape.circle,
        border: Border.all(color: AuraSurface.accent.withValues(alpha: 0.3)),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: AuraText.headline.copyWith(
          color: AuraSurface.accentText,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.4,
        ),
      ),
    );
    if (url.isEmpty) return fallback;
    return SizedBox(
      width: size,
      height: size,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RESPONSIVE GRID — used by status grid and any future card grid.
// ─────────────────────────────────────────────────────────────────────────────

class InsResponsiveGrid extends StatelessWidget {
  const InsResponsiveGrid({
    super.key,
    required this.children,
    this.gap = InsSpacing.cardGap,
    this.maxCols = 4,
    this.minColWidth = 220,
  });

  final List<Widget> children;
  final double gap;
  final int maxCols;
  final double minColWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        var cols = (w / (minColWidth + gap)).floor().clamp(1, maxCols);
        if (cols > children.length) cols = children.length.clamp(1, maxCols);
        final colWidth = (w - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final c in children) SizedBox(width: colWidth, child: c),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTION GROUP — primary + secondary cluster used on Profile / Edit / Preview.
// ─────────────────────────────────────────────────────────────────────────────

class InsActionGroup extends StatelessWidget {
  const InsActionGroup({
    super.key,
    this.primary,
    this.secondary = const [],
  });

  final Widget? primary;
  final List<Widget> secondary;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AuraSpace.s8,
      runSpacing: AuraSpace.s8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (primary != null) primary!,
        ...secondary,
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODE HEADER — every institution surface declares its institutional mode
// here. Same layout everywhere: title (left) + primary action (top-right) on
// one row, description on the next line, optional tabs below.
//
// Frame = constant. Mode = meaning. Content = variable.
// ─────────────────────────────────────────────────────────────────────────────

class InsModeHeader extends StatelessWidget {
  const InsModeHeader({
    super.key,
    required this.title,
    this.description,
    this.primaryAction,
    this.tabs,
  });

  final String title;
  final String? description;
  final Widget? primaryAction;
  final Widget? tabs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                title,
                style: AuraText.headline,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (primaryAction != null) ...[
              const SizedBox(width: AuraSpace.s12),
              primaryAction!,
            ],
          ],
        ),
        if (description != null && description!.trim().isNotEmpty) ...[
          const SizedBox(height: AuraSpace.s6),
          Text(
            description!,
            style: AuraText.body.copyWith(
              color: AuraSurface.muted,
              height: 1.5,
            ),
          ),
        ],
        if (tabs != null) ...[
          const SizedBox(height: AuraSpace.s14),
          tabs!,
        ],
      ],
    );
  }
}

/// Standard vertical gap between the Mode Header and the first section.
class InsModeHeaderGap extends StatelessWidget {
  const InsModeHeaderGap({super.key});

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: InsSpacing.sectionGap);
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE — in-container, never a center-page hero.
//
// Pattern:  [small icon]  [title]  [description]  [optional secondary]
// Primary action lives in the Mode Header, never inside the empty state.
// ─────────────────────────────────────────────────────────────────────────────

class InsEmptyState extends StatelessWidget {
  const InsEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.secondary,
    this.tone = InsTone.neutral,
  });

  final IconData icon;
  final String title;
  final String? description;

  /// Optional second line for nuance ("Members can post here when…",
  /// "Visible only to admins…"). Not a CTA — CTAs live in Mode Header.
  final String? secondary;

  final InsTone tone;

  @override
  Widget build(BuildContext context) {
    final t = InsToneStyle.of(tone);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: InsSpacing.cardPadding,
        vertical: AuraSpace.s24,
      ),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: t.bg,
              borderRadius: BorderRadius.circular(AuraRadius.r10),
              border: Border.all(color: t.border),
            ),
            child: Icon(icon, size: 18, color: t.fg),
          ),
          const SizedBox(height: AuraSpace.s12),
          Text(
            title,
            style: AuraText.subtitle,
          ),
          if (description != null && description!.trim().isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text(
              description!,
              style: AuraText.small.copyWith(
                color: AuraSurface.muted,
                height: 1.5,
              ),
            ),
          ],
          if (secondary != null && secondary!.trim().isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text(
              secondary!,
              style: AuraText.small.copyWith(
                color: AuraSurface.faint,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
