import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/ui/aura_design_system.dart';
import '../core/ui/aura_platform_components.dart';
import '../core/ui/aura_radius.dart';
import '../core/ui/aura_scaffold.dart';
import '../core/ui/aura_space.dart';
import '../core/ui/aura_surface.dart';
import '../core/ui/aura_text.dart';

class InstitutionsHubScreen extends StatelessWidget {
  const InstitutionsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuraScaffold(
      showHeader: false,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Hero
          _InstitutionsHero(
            onSignIn: () => context.go('/institution/sign-in'),
            onCreate: () => context.go('/institution/create'),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.s16,
              AuraSpace.s28,
              AuraSpace.s16,
              AuraSpace.s40,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _TrustPrinciplesSection(),
                    const SizedBox(height: AuraSpace.s32),
                    const _WhySection(),
                    const SizedBox(height: AuraSpace.s32),
                    _EntryCard(
                      onSignIn: () => context.go('/institution/sign-in'),
                      onCreate: () => context.go('/institution/create'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero ────────────────────────────────────────────────────────────────────

class _InstitutionsHero extends StatelessWidget {
  const _InstitutionsHero({required this.onSignIn, required this.onCreate});

  final VoidCallback onSignIn;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AuraGradients.hero,
        border: Border(bottom: BorderSide(color: AuraSurface.divider)),
      ),
      child: Stack(
        children: [
          // Accent glow
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 380,
              height: 380,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x125B6CFF), Colors.transparent],
                  radius: 0.6,
                ),
              ),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AuraSpace.s20,
                  56,
                  AuraSpace.s20,
                  52,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 640;
                    return wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                flex: 3,
                                child: _HeroContent(
                                  onSignIn: onSignIn,
                                  onCreate: onCreate,
                                ),
                              ),
                              const SizedBox(width: AuraSpace.s32),
                              const Expanded(flex: 2, child: _HeroSignals()),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _HeroContent(
                                onSignIn: onSignIn,
                                onCreate: onCreate,
                              ),
                              const SizedBox(height: AuraSpace.s24),
                              const _HeroSignals(),
                            ],
                          );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroContent extends StatelessWidget {
  const _HeroContent({required this.onSignIn, required this.onCreate});

  final VoidCallback onSignIn;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s10,
            vertical: AuraSpace.s6,
          ),
          decoration: BoxDecoration(
            color: AuraSurface.accentSoft,
            borderRadius: BorderRadius.circular(AuraRadius.pill),
            border: Border.all(
              color: AuraSurface.accent.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.apartment_rounded,
                size: 11,
                color: AuraSurface.accentText,
              ),
              const SizedBox(width: AuraSpace.s6),
              Text(
                'Institutional presence',
                style: AuraText.label.copyWith(color: AuraSurface.accentText),
              ),
            ],
          ),
        ),
        const SizedBox(height: AuraSpace.s20),
        const Text(
          'A quieter kind of\npublic standing',
          style: AuraText.display,
        ),
        const SizedBox(height: AuraSpace.s14),
        Text(
          'Aura gives institutions a place built for continuity, accountability, and readable record — not noise.',
          style: AuraText.body.copyWith(
            color: AuraSurface.muted,
            height: 1.6,
          ),
        ),
        const SizedBox(height: AuraSpace.s28),
        Wrap(
          spacing: AuraSpace.s10,
          runSpacing: AuraSpace.s10,
          children: [
            AuraPrimaryButton(
              label: 'Institution sign in',
              onPressed: onSignIn,
              icon: Icons.login_rounded,
            ),
            AuraGhostButton(
              label: 'Create account',
              onPressed: onCreate,
              icon: Icons.add_rounded,
            ),
          ],
        ),
        const SizedBox(height: AuraSpace.s20),
        const Wrap(
          spacing: AuraSpace.s8,
          runSpacing: AuraSpace.s8,
          children: [
            _HeroTrustPill(
              label: 'Verified presence',
              icon: Icons.verified_outlined,
            ),
            _HeroTrustPill(
              label: 'Lasting public record',
              icon: Icons.history_edu_outlined,
            ),
            _HeroTrustPill(
              label: 'Clear institutional voice',
              icon: Icons.campaign_outlined,
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroTrustPill extends StatelessWidget {
  const _HeroTrustPill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s10,
        vertical: AuraSpace.s6,
      ),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AuraSurface.faint),
          const SizedBox(width: AuraSpace.s6),
          Text(
            label,
            style: AuraText.micro.copyWith(
              color: AuraSurface.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSignals extends StatelessWidget {
  const _HeroSignals();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s20),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.xl),
        border: Border.all(color: AuraSurface.divider),
        boxShadow: AuraShadows.panel,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Designed for institutions',
            style: AuraText.label.copyWith(
              color: AuraSurface.faint,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: AuraSpace.s16),
          const _SignalRow(
            icon: Icons.history_edu_outlined,
            title: 'Lasting public record',
            body:
                'Statements remain readable over time instead of dissolving into feed churn.',
          ),
          const SizedBox(height: AuraSpace.s12),
          const Divider(color: AuraSurface.divider, height: 1),
          const SizedBox(height: AuraSpace.s12),
          const _SignalRow(
            icon: Icons.account_balance_outlined,
            title: 'Clear institutional voice',
            body:
                'Aura separates personal presence from institutional authority.',
          ),
          const SizedBox(height: AuraSpace.s12),
          const Divider(color: AuraSurface.divider, height: 1),
          const SizedBox(height: AuraSpace.s12),
          const _SignalRow(
            icon: Icons.shield_outlined,
            title: 'Responsibility-first',
            body:
                'A calmer environment built for continuity and serious communication.',
          ),
        ],
      ),
    );
  }
}

class _SignalRow extends StatelessWidget {
  const _SignalRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AuraSurface.accentSoft,
            borderRadius: BorderRadius.circular(AuraRadius.r10),
            border: Border.all(
              color: AuraSurface.accent.withValues(alpha: 0.2),
            ),
          ),
          child: Icon(icon, size: 16, color: AuraSurface.accentText),
        ),
        const SizedBox(width: AuraSpace.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AuraText.small.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AuraSurface.ink,
                ),
              ),
              const SizedBox(height: AuraSpace.s2),
              Text(
                body,
                style: AuraText.small.copyWith(
                  color: AuraSurface.muted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Trust principles section ────────────────────────────────────────────────

class _TrustPrinciplesSection extends StatelessWidget {
  const _TrustPrinciplesSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WHAT INSTITUTIONS ENTER HERE FOR',
          style: AuraText.label.copyWith(
            color: AuraSurface.faint,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: AuraSpace.s16),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 560;
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Expanded(
                    child: _PrincipleCard(
                      icon: Icons.history_edu_outlined,
                      title: 'A lasting public record',
                      body:
                          'Institutional statements, clarifications, and responses remain readable over time instead of dissolving into feed churn.',
                    ),
                  ),
                  SizedBox(width: AuraSpace.s14),
                  Expanded(
                    child: _PrincipleCard(
                      icon: Icons.account_balance_outlined,
                      title: 'Clear institutional voice',
                      body:
                          'Aura distinguishes between a person speaking personally and a person speaking while carrying institutional authority.',
                    ),
                  ),
                  SizedBox(width: AuraSpace.s14),
                  Expanded(
                    child: _PrincipleCard(
                      icon: Icons.shield_outlined,
                      title: 'A calmer environment',
                      body:
                          'Designed for continuity, responsibility, and serious communication rather than volume, reach, and reaction loops.',
                    ),
                  ),
                ],
              );
            }
            return const Column(
              children: [
                _PrincipleCard(
                  icon: Icons.history_edu_outlined,
                  title: 'A lasting public record',
                  body:
                      'Institutional statements, clarifications, and responses remain readable over time instead of dissolving into feed churn.',
                ),
                SizedBox(height: AuraSpace.s14),
                _PrincipleCard(
                  icon: Icons.account_balance_outlined,
                  title: 'Clear institutional voice',
                  body:
                      'Aura distinguishes between a person speaking personally and a person speaking while carrying institutional authority.',
                ),
                SizedBox(height: AuraSpace.s14),
                _PrincipleCard(
                  icon: Icons.shield_outlined,
                  title: 'A calmer environment',
                  body:
                      'Designed for continuity, responsibility, and serious communication rather than volume, reach, and reaction loops.',
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PrincipleCard extends StatelessWidget {
  const _PrincipleCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s20),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AuraSurface.accentSoft,
              borderRadius: BorderRadius.circular(AuraRadius.md),
              border: Border.all(
                color: AuraSurface.accent.withValues(alpha: 0.2),
              ),
            ),
            child: Icon(icon, size: 20, color: AuraSurface.accentText),
          ),
          const SizedBox(height: AuraSpace.s14),
          Text(
            title,
            style: AuraText.body.copyWith(
              fontWeight: FontWeight.w700,
              color: AuraSurface.ink,
            ),
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(
            body,
            style: AuraText.small.copyWith(
              color: AuraSurface.muted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Why Aura different section ──────────────────────────────────────────────

class _WhySection extends StatelessWidget {
  const _WhySection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s24),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.xl),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AuraSurface.accentSoft,
                  borderRadius: BorderRadius.circular(AuraRadius.md),
                  border: Border.all(
                    color: AuraSurface.accent.withValues(alpha: 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.compare_arrows_rounded,
                  size: 22,
                  color: AuraSurface.accentText,
                ),
              ),
              const SizedBox(width: AuraSpace.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('What makes Aura different', style: AuraText.title),
                    const SizedBox(height: AuraSpace.s8),
                    Text(
                      'Aura is not built around velocity, promotion, or algorithmic attention. It gives institutions a place to speak with continuity, maintain public memory, and act under visible responsibility.',
                      style: AuraText.body.copyWith(
                        color: AuraSurface.muted,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s20),
          const Divider(color: AuraSurface.divider, height: 1),
          const SizedBox(height: AuraSpace.s20),
          Wrap(
            spacing: AuraSpace.s24,
            runSpacing: AuraSpace.s16,
            children: [
              _DiffStat(
                label: 'No algorithmic feed manipulation',
                icon: Icons.do_not_disturb_outlined,
              ),
              _DiffStat(
                label: 'Provenance-first publishing',
                icon: Icons.verified_user_outlined,
              ),
              _DiffStat(
                label: 'Searchable and auditable record',
                icon: Icons.manage_search_outlined,
              ),
              _DiffStat(
                label: 'Separated personal and institutional voice',
                icon: Icons.account_tree_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DiffStat extends StatelessWidget {
  const _DiffStat({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AuraSurface.accentText),
        const SizedBox(width: AuraSpace.s8),
        Text(
          label,
          style: AuraText.small.copyWith(
            color: AuraSurface.muted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ── Entry card ──────────────────────────────────────────────────────────────

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.onSignIn, required this.onCreate});

  final VoidCallback onSignIn;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF172444), Color(0xFF0F1E36)],
        ),
        borderRadius: BorderRadius.circular(AuraRadius.xl),
        border: Border.all(color: AuraSurface.accent.withValues(alpha: 0.2)),
        boxShadow: AuraShadows.panel,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 3,
            decoration: const BoxDecoration(
              gradient: AuraGradients.accent,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AuraRadius.xl),
              ),
            ),
          ),
          const SizedBox(height: AuraSpace.s4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpace.s8,
                  vertical: AuraSpace.s4,
                ),
                decoration: BoxDecoration(
                  color: AuraSurface.accentSoft,
                  borderRadius: BorderRadius.circular(AuraRadius.pill),
                  border: Border.all(
                    color: AuraSurface.accent.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'Institution access',
                  style: AuraText.label.copyWith(color: AuraSurface.accentText),
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s16),
          const Text('Enter the institution workspace', style: AuraText.title),
          const SizedBox(height: AuraSpace.s8),
          Text(
            'Institutions may sign in with approved institutional credentials or begin by creating an institutional account.',
            style: AuraText.body.copyWith(
              color: AuraSurface.muted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AuraSpace.s20),
          Wrap(
            spacing: AuraSpace.s10,
            runSpacing: AuraSpace.s10,
            children: [
              AuraPrimaryButton(
                label: 'Institution sign in',
                onPressed: onSignIn,
                icon: Icons.login_rounded,
              ),
              AuraGhostButton(
                label: 'Create institutional account',
                onPressed: onCreate,
                icon: Icons.add_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
