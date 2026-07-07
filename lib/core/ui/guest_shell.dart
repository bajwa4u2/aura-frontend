import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'aura_space.dart';
import 'aura_surface.dart';
import 'aura_text.dart';

/// Public-facing minimal shell for guest flows.
///
/// Replaces [AuraScaffold] on all screens a guest sees before they are a
/// member: booking pages, pre-join, waiting room, booking confirmation,
/// reschedule, and cancel. Shows institution identity (logo + name) in the
/// top bar, no workspace navigation, and a "Powered by Aura" footer.
class GuestShell extends StatelessWidget {
  final Widget body;
  final String? institutionName;
  final String? institutionLogoUrl;
  final bool showBackButton;

  const GuestShell({
    super.key,
    required this.body,
    this.institutionName,
    this.institutionLogoUrl,
    this.showBackButton = false,
  });

  @override
  Widget build(BuildContext context) {
    // The public shell above already brands the page with Aura navigation —
    // this bar earns its place only when it carries something (institution
    // identity or a back affordance). Otherwise it is duplicated chrome.
    final hasInstitution = institutionName?.trim().isNotEmpty == true;
    final showBar = hasInstitution || showBackButton;
    return Scaffold(
      backgroundColor: AuraSurface.page,
      body: Column(
        children: [
          if (showBar)
            _GuestTopBar(
              institutionName: institutionName,
              institutionLogoUrl: institutionLogoUrl,
              showBackButton: showBackButton,
            ),
          Expanded(child: body),
          const _GuestFooter(),
        ],
      ),
    );
  }
}

class _GuestTopBar extends StatelessWidget {
  final String? institutionName;
  final String? institutionLogoUrl;
  final bool showBackButton;

  const _GuestTopBar({
    required this.institutionName,
    required this.institutionLogoUrl,
    required this.showBackButton,
  });

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(
        AuraSpace.s16,
        safeTop + AuraSpace.s12,
        AuraSpace.s16,
        AuraSpace.s12,
      ),
      decoration: const BoxDecoration(
        color: AuraSurface.subtle,
        border: Border(bottom: BorderSide(color: AuraSurface.divider)),
      ),
      child: Row(
        children: [
          if (showBackButton) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded,
                  color: AuraSurface.muted, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: AuraSpace.s8),
          ],
          // No Aura logo fallback here: the public shell's navigation above
          // already brands the page — repeating the mark reads as clutter.
          if (institutionName != null && institutionName!.trim().isNotEmpty)
            _InstitutionMark(
              name: institutionName!,
              logoUrl: institutionLogoUrl,
            ),
        ],
      ),
    );
  }
}

class _InstitutionMark extends StatelessWidget {
  final String name;
  final String? logoUrl;

  const _InstitutionMark({required this.name, this.logoUrl});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? 'A' : name.trim()[0].toUpperCase();
    const size = 28.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFF5B6CFF).withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(6),
          ),
          clipBehavior: Clip.antiAlias,
          child: logoUrl != null && logoUrl!.trim().isNotEmpty
              ? Image.network(
                  logoUrl!,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _FallbackMark(initial: initial),
                )
              : _FallbackMark(initial: initial),
        ),
        const SizedBox(width: AuraSpace.s8),
        Text(
          name,
          style: AuraText.subtitle.copyWith(fontSize: 15),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _FallbackMark extends StatelessWidget {
  final String initial;
  const _FallbackMark({required this.initial});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          color: Color(0xFFE6E9EF),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _GuestFooter extends StatelessWidget {
  const _GuestFooter();

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(
        AuraSpace.s16,
        AuraSpace.s10,
        AuraSpace.s16,
        AuraSpace.s10 + safeBottom,
      ),
      decoration: const BoxDecoration(
        color: AuraSurface.subtle,
        border: Border(top: BorderSide(color: AuraSurface.divider)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Powered by ',
            style: AuraText.micro.copyWith(color: AuraSurface.faint),
          ),
          SvgPicture.asset(
            'assets/brand/AURA_logo_master.svg',
            height: 11,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }
}
