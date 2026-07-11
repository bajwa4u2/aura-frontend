import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/institutions/institution_paths.dart';
import '../../../core/interactions/actor_context.dart';
import '../../../core/diagnostics/runtime_trace.dart';
import '../../../core/interactions/follow_invalidation.dart';
import '../../../core/interactions/follows_repository.dart';
import '../../../core/interactions/interaction_service.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../accountability/widgets/continuation_chain_rail.dart';
import '../../discourse_intelligence/models.dart';
import '../../discourse_intelligence/providers.dart';
import '../../discourse_intelligence/widgets/continuity_cards.dart';
import '../../discourse_intelligence/widgets/discourse_continuity_panel.dart';
import '../../feed/data/unified_feed_providers.dart';
import '../../feed/presentation/feed_filter_bar.dart';
import '../../feed/presentation/unified_feed_card.dart';
import '../../institution_ontology/widgets/ontology_identity_chips.dart';
import '../data/institutions_repository.dart';
import '../domain/institution.dart';
import '../units/institution_unit_card.dart';

final institutionDetailProvider = FutureProvider.family<Institution, String>((
  ref,
  slug,
) async {
  final repo = ref.watch(institutionsRepositoryProvider);
  return repo.getBySlug(slug);
});

class InstitutionDetailScreen extends ConsumerWidget {
  const InstitutionDetailScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cleanSlug = slug.trim();
    final institutionAsync = ref.watch(institutionDetailProvider(cleanSlug));

    return AuraScaffold(
      showHeader: false,
      body: institutionAsync.when(
        loading: () => const Center(
          child: AuraLoadingState(message: 'Loading institution…'),
        ),
        error: (e, _) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AuraSpace.s16,
            AuraSpace.s20,
            AuraSpace.s16,
            AuraSpace.s32,
          ),
          children: [
            AuraErrorState(
              title: 'Institution could not be loaded',
              body: '$e',
            ),
          ],
        ),
        data: (institution) => _InstitutionDetailBody(institution: institution),
      ),
    );
  }
}

class _InstitutionDetailBody extends ConsumerWidget {
  const _InstitutionDetailBody({required this.institution});

  final Institution institution;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(
      institutionProfileFeedPagedProvider(institution.id),
    );

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Visible return path to the directory. Closes the loop
                // from /institutions → /institutions/:slug so visitors
                // don't have to rely on browser back to navigate the
                // ecosystem.
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AuraSpace.s16,
                    AuraSpace.s12,
                    AuraSpace.s16,
                    0,
                  ),
                  child: InkWell(
                    onTap: () => context.go('/institutions'),
                    borderRadius: BorderRadius.circular(AuraRadius.r10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.arrow_back_rounded,
                            size: 14,
                            color: AuraSurface.faint,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Institutions',
                            style: AuraText.small.copyWith(
                              color: AuraSurface.faint,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _PublicHero(institution: institution),
                const SizedBox(height: AuraSpace.s12),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AuraSpace.s16,
                  ),
                  child: _PublicIdentity(institution: institution),
                ),
                const SizedBox(height: AuraSpace.s14),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AuraSpace.s16,
                  ),
                  child: _InstitutionProfileCtaRow(
                    institutionId: institution.id,
                  ),
                ),
                const SizedBox(height: AuraSpace.s14),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AuraSpace.s16,
                  ),
                  child: _PublicStatChips(institution: institution),
                ),
                const SizedBox(height: AuraSpace.s14),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AuraSpace.s16,
                    0,
                    AuraSpace.s16,
                    AuraSpace.s32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (institution.description.trim().isNotEmpty) ...[
                        _InfoSection(
                          title: 'About',
                          rows: [
                            _InfoRow(
                              label: 'Description',
                              value: institution.description.trim(),
                            ),
                          ],
                        ),
                        const SizedBox(height: AuraSpace.s14),
                      ],
                      if (institution.website.trim().isNotEmpty) ...[
                        _InfoSection(
                          title: 'Contact',
                          rows: [
                            _InfoRow(
                              label: 'Website',
                              value: institution.website.trim(),
                            ),
                          ],
                        ),
                        const SizedBox(height: AuraSpace.s14),
                      ],
                      _InfoSection(
                        title: 'Domains & verification',
                        rows: [
                          _InfoRow(
                            label: 'Verification',
                            value: institution.isVerified
                                ? 'Verified'
                                : 'Not verified',
                            valueColor: institution.isVerified
                                ? AuraSurface.coVerdant
                                : AuraSurface.muted,
                          ),
                          if (institution.domain.trim().isNotEmpty)
                            _InfoRow(
                              label: 'Domain',
                              value: institution.domain.trim(),
                            ),
                          if (institution.jurisdiction.trim().isNotEmpty)
                            _InfoRow(
                              label: 'Jurisdiction',
                              value: institution.jurisdiction.trim(),
                            ),
                          if ((institution.category ?? '').trim().isNotEmpty)
                            _InfoRow(
                              label: 'Category',
                              value: (institution.category ?? '').trim(),
                            ),
                        ],
                      ),
                      if (institution.units.isNotEmpty) ...[
                        const SizedBox(height: AuraSpace.s14),
                        _UnitsSection(
                          institutionName: institution.name,
                          units: institution.units,
                        ),
                      ],
                      const SizedBox(height: AuraSpace.s14),
                      _PublicPostsSection(
                        institutionId: institution.id,
                        postsAsync: postsAsync,
                      ),
                      // Institution-scoped continuity surfaces. Each
                      // self-collapses when no aggregation backs it,
                      // so a quiet institution shows nothing extra —
                      // never an empty metric box.
                      const SizedBox(height: AuraSpace.s14),
                      DiscourseContinuityPanel(institutionId: institution.id),
                      const SizedBox(height: AuraSpace.s14),
                      ContinuationChainRail(institutionId: institution.id),
                      const SizedBox(height: AuraSpace.s14),
                      _RelatedInstitutionsSection(
                        institutionId: institution.id,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Units section ──────────────────────────────────────────────────────────

class _UnitsSection extends StatelessWidget {
  const _UnitsSection({required this.institutionName, required this.units});

  final String institutionName;
  final List<InstitutionUnit> units;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'UNITS & BRANCHES',
            style: AuraText.small.copyWith(
              fontWeight: FontWeight.w700,
              color: AuraSurface.faint,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: AuraSpace.s14),
          ...units.asMap().entries.map(
            (e) => Padding(
              padding: EdgeInsets.only(
                bottom: e.key < units.length - 1 ? AuraSpace.s10 : 0,
              ),
              child: PublicUnitCard(
                unit: e.value,
                institutionName: institutionName,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info section ───────────────────────────────────────────────────────────

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.title, required this.rows});

  final String title;
  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AuraText.small.copyWith(
              fontWeight: FontWeight.w700,
              color: AuraSurface.faint,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: AuraSpace.s14),
          ...rows.asMap().entries.map(
            (e) => Padding(
              padding: EdgeInsets.only(
                bottom: e.key < rows.length - 1 ? AuraSpace.s10 : 0,
              ),
              child: e.value,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final cleanValue = value.trim().isEmpty ? '—' : value.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: AuraText.small.copyWith(
              fontWeight: FontWeight.w600,
              color: AuraSurface.muted,
            ),
          ),
        ),
        Expanded(
          child: Text(
            cleanValue,
            style: AuraText.small.copyWith(
              color: valueColor ?? AuraSurface.ink,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Public posts section ────────────────────────────────────────────────────
//
// Consumes the unified `institutionProfileFeedProvider` and renders rows via
// the shared `UnifiedFeedCard`. Empty state only fires when the provider
// returns an empty page — never when posts exist (per Phase 2 rule:
// "❌ Remove false 'No posts' empty state").

/// Related-institution co-participation strip. Reads
/// `relatedInstitutionsProvider(institutionId)` and surfaces the
/// strip when the backend returned ≥1 co-participating institution.
/// Calm "related institutional participation" framing — no
/// recommendation engine, no leaderboard tone.
class _RelatedInstitutionsSection extends ConsumerWidget {
  const _RelatedInstitutionsSection({required this.institutionId});

  final String institutionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (institutionId.isEmpty) return const SizedBox.shrink();
    final async = ref.watch(relatedInstitutionsProvider(institutionId));
    final rows = async.maybeWhen(
      data: (p) => p.items,
      orElse: () => const <RelatedInstitutionRow>[],
    );
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s14),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.r14),
        border: Border.all(color: AuraSurface.divider.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 14,
                decoration: BoxDecoration(
                  color: AuraSurface.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: AuraSpace.s8),
              Expanded(
                child: Text(
                  'Related institutional participation',
                  style: AuraText.subtitle.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Other institutions that have replied on the same recent '
            'public discussions.',
            style: AuraText.micro.copyWith(
              color: AuraSurface.faint,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: AuraSpace.s10),
          RelatedInstitutionStrip(rows: rows),
        ],
      ),
    );
  }
}

class _PublicPostsSection extends ConsumerWidget {
  const _PublicPostsSection({
    required this.institutionId,
    required this.postsAsync,
  });

  final String institutionId;
  final AsyncValue<FeedPagedState> postsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'POSTS',
            style: AuraText.small.copyWith(
              fontWeight: FontWeight.w700,
              color: AuraSurface.faint,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: AuraSpace.s12),
          // Topic + Resources controls — same doctrine as Works/Explore.
          const FeedFilterBar(),
          const SizedBox(height: AuraSpace.s14),
          postsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AuraSpace.s16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (e, _) => Text(
              'Could not load posts.',
              style: AuraText.small.copyWith(color: AuraSurface.muted),
            ),
            data: (page) {
              if (page.items.isEmpty) {
                return Text(
                  'This institution has no public posts yet.',
                  style: AuraText.small.copyWith(color: AuraSurface.muted),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < page.items.length; i++) ...[
                    UnifiedFeedCard(item: page.items[i]),
                    if (i < page.items.length - 1)
                      const SizedBox(height: AuraSpace.s10),
                  ],
                  // Phase 3 — Load more for institution profile feed.
                  if (page.hasMore) ...[
                    const SizedBox(height: AuraSpace.s14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AuraSecondaryButton(
                        label: page.loadingMore ? 'Loading…' : 'Load more',
                        icon: page.loadingMore
                            ? Icons.hourglass_empty_rounded
                            : Icons.expand_more_rounded,
                        onPressed: page.loadingMore
                            ? null
                            : () => ref
                                  .read(
                                    institutionProfileFeedPagedProvider(
                                      institutionId,
                                    ).notifier,
                                  )
                                  .loadMore(),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Public hero (cover + avatar overlap) ─────────────────────────────────────

class _PublicHero extends StatelessWidget {
  const _PublicHero({required this.institution});

  final Institution institution;

  @override
  Widget build(BuildContext context) {
    const double avatarSize = 96;
    final coverUrl = institution.coverUrl?.trim() ?? '';
    final logoUrl = institution.logoUrl?.trim() ?? '';
    final name = institution.name.trim().isNotEmpty
        ? institution.name.trim()
        : 'Institution';

    return LayoutBuilder(
      builder: (context, constraints) {
        final coverHeight = constraints.maxWidth.isFinite
            ? constraints.maxWidth / 4
            : 220.0;
        return SizedBox(
          height: coverHeight + avatarSize / 2,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                bottom: avatarSize / 2,
                child: Container(
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
                  child: coverUrl.isEmpty
                      ? const Center(
                          child: Icon(
                            Icons.apartment_rounded,
                            size: 56,
                            color: AuraSurface.accentText,
                          ),
                        )
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              coverUrl,
                              fit: BoxFit.fill,
                              errorBuilder: (_, __, ___) => Container(
                                color: AuraSurface.accentSoft,
                                child: const Center(
                                  child: Icon(
                                    Icons.image_outlined,
                                    color: AuraSurface.accentText,
                                    size: 48,
                                  ),
                                ),
                              ),
                            ),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.35),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              Positioned(
                left: AuraSpace.s16,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AuraSurface.page,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: _PublicInstitutionAvatar(
                    size: avatarSize,
                    name: name,
                    logoUrl: logoUrl,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Public identity (name / verified / slug · domain / description) ─────────

class _PublicIdentity extends StatelessWidget {
  const _PublicIdentity({required this.institution});

  final Institution institution;

  @override
  Widget build(BuildContext context) {
    final title = institution.name.trim().isNotEmpty
        ? institution.name.trim()
        : 'Institution';
    final slug = institution.slug.trim();
    final domain = institution.domain.trim();
    final subtitleParts = <String>[
      if (slug.isNotEmpty) '@$slug',
      if (domain.isNotEmpty) domain,
    ];
    final description = institution.description.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AuraSpace.s8,
          runSpacing: AuraSpace.s6,
          children: [
            Text(title, style: AuraText.title),
            if (institution.isVerified)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpace.s8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AuraSurface.coVerdant.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AuraRadius.pill),
                  border: Border.all(
                    color: AuraSurface.coVerdant.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      size: 12,
                      color: AuraSurface.coVerdant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Verified',
                      style: AuraText.micro.copyWith(
                        color: AuraSurface.coVerdant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (subtitleParts.isNotEmpty) ...[
          const SizedBox(height: AuraSpace.s4),
          Text(
            subtitleParts.join(' · '),
            style: AuraText.small.copyWith(
              color: AuraSurface.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if ((institution.institutionClass ?? '').isNotEmpty ||
            (institution.institutionType ?? '').isNotEmpty ||
            institution.domainTags.isNotEmpty) ...[
          const SizedBox(height: AuraSpace.s8),
          OntologyIdentityChips(
            institutionClass: institution.institutionClass,
            institutionType: institution.institutionType,
            domainTags: institution.domainTags,
            maxDomainTags: 5,
          ),
        ],
        if (description.isNotEmpty) ...[
          const SizedBox(height: AuraSpace.s10),
          Text(
            description,
            style: AuraText.body.copyWith(
              color: AuraSurface.muted,
              height: 1.5,
            ),
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

// ── Public stat chips ────────────────────────────────────────────────────────

class _PublicStatChips extends StatelessWidget {
  const _PublicStatChips({required this.institution});

  final Institution institution;

  @override
  Widget build(BuildContext context) {
    // Build chips, then collapse any later chip whose label duplicates an
    // earlier one (case-insensitive). The Institution model derives
    // `jurisdiction` from country/region and `location` from city — when
    // an entry has no city, both fall back to the country and we'd
    // otherwise render two identical pills (e.g. "United States" twice).
    final seenLabels = <String>{};
    void add(List<Widget> into, _PublicStatChip chip) {
      final key = chip.label.trim().toLowerCase();
      if (key.isEmpty || !seenLabels.add(key)) return;
      into.add(chip);
    }

    final chips = <Widget>[];
    add(
      chips,
      _PublicStatChip(
        icon: Icons.verified_rounded,
        label: institution.isVerified ? 'Verified' : 'Unverified',
        good: institution.isVerified,
      ),
    );
    if (institution.domain.trim().isNotEmpty) {
      add(
        chips,
        _PublicStatChip(
          icon: Icons.dns_rounded,
          label: institution.domain.trim(),
        ),
      );
    }
    if (institution.jurisdiction.trim().isNotEmpty) {
      add(
        chips,
        _PublicStatChip(
          icon: Icons.public_rounded,
          label: institution.jurisdiction.trim(),
        ),
      );
    }
    if ((institution.category ?? '').trim().isNotEmpty) {
      add(
        chips,
        _PublicStatChip(
          icon: Icons.category_rounded,
          label: (institution.category ?? '').trim(),
        ),
      );
    }
    if ((institution.location ?? '').trim().isNotEmpty) {
      add(
        chips,
        _PublicStatChip(
          icon: Icons.place_rounded,
          label: (institution.location ?? '').trim(),
        ),
      );
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: AuraSpace.s8,
      runSpacing: AuraSpace.s8,
      children: chips,
    );
  }
}

class _PublicStatChip extends StatelessWidget {
  const _PublicStatChip({
    required this.icon,
    required this.label,
    this.good = false,
  });

  final IconData icon;
  final String label;
  final bool good;

  @override
  Widget build(BuildContext context) {
    final fg = good ? AuraSurface.coVerdant : AuraSurface.muted;
    final bg = good
        ? AuraSurface.coVerdant.withValues(alpha: 0.16)
        : AuraSurface.subtle;
    final border = good
        ? AuraSurface.coVerdant.withValues(alpha: 0.3)
        : AuraSurface.divider;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: AuraText.micro.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Public-shell institution avatar ──────────────────────────────────────────

class _PublicInstitutionAvatar extends StatelessWidget {
  const _PublicInstitutionAvatar({
    required this.size,
    required this.name,
    required this.logoUrl,
  });

  final double size;
  final String name;
  final String logoUrl;

  @override
  Widget build(BuildContext context) {
    Widget fallback() {
      final initial = name.trim().isNotEmpty
          ? name.trim()[0].toUpperCase()
          : '';
      if (initial.isNotEmpty) {
        return Center(
          child: Text(
            initial,
            style: TextStyle(
              color: AuraSurface.accentText,
              fontSize: size * 0.4,
              fontWeight: FontWeight.w800,
            ),
          ),
        );
      }
      return Icon(
        Icons.apartment_outlined,
        size: size * 0.46,
        color: AuraSurface.accentText,
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AuraSurface.accentSoft,
        shape: BoxShape.circle,
        border: Border.all(color: AuraSurface.accent.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: logoUrl.isNotEmpty
          ? Image.network(
              logoUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback(),
            )
          : fallback(),
    );
  }
}

// ── Profile Follow + Message CTAs ────────────────────────────────────────────

class _InstitutionProfileCtaRow extends ConsumerStatefulWidget {
  const _InstitutionProfileCtaRow({required this.institutionId});

  final String institutionId;

  @override
  ConsumerState<_InstitutionProfileCtaRow> createState() =>
      _InstitutionProfileCtaRowState();
}

class _InstitutionProfileCtaRowState
    extends ConsumerState<_InstitutionProfileCtaRow> {
  bool _busy = false;
  String? _error;

  // Optimistic follow override. Set the moment the user taps Follow /
  // Following; cleared after the canonical provider re-fetch completes
  // or on backend failure. The button label/icon prefer this when set so
  // the toggle feels immediate even though the round-trip is still in
  // flight.
  bool? _optimisticFollowing;

  ActorRef _targetRef() => ActorRef.institution(widget.institutionId);

  ActorRef? _actorRefOf(ActorContext actor) {
    if (actor.isInstitution) {
      final id = (actor.institutionId ?? '').trim();
      if (id.isEmpty) return null;
      return ActorRef.institution(id);
    }
    final uid = (actor.userId ?? '').trim();
    if (uid.isEmpty) return null;
    return ActorRef.user(uid);
  }

  bool _isOwnInstitution(ActorContext actor) {
    return actor.isInstitution &&
        (actor.institutionId ?? '') == widget.institutionId;
  }

  Future<void> _toggleFollow(
    ActorContext actor,
    FollowState current,
    FollowStateKey key,
  ) async {
    if (_busy) return;
    final actorRef = _actorRefOf(actor);
    if (actorRef == null) return;
    final nextFollowing = !current.following;
    setState(() {
      _busy = true;
      _error = null;
      _optimisticFollowing = nextFollowing;
    });
    try {
      final repo = ref.read(followsRepositoryProvider);
      RuntimeTrace.emit(
        'follow.api',
        'request',
        data: {
          'op': current.following ? 'unfollow' : 'follow',
          'actor': actorRef.toString(),
          'target': _targetRef().toString(),
        },
      );
      final FollowState result;
      if (current.following) {
        result = await repo.unfollow(actor: actorRef, target: _targetRef());
      } else {
        result = await repo.follow(actor: actorRef, target: _targetRef());
      }
      RuntimeTrace.emit(
        'follow.api',
        'response',
        data: {
          'op': current.following ? 'unfollow' : 'follow',
          'following': result.following,
          'status': result.status,
          'canMessage': result.canMessage,
        },
      );
      // Institution follow affects which institution posts appear in the
      // home feed and the institution-explore band. Invalidating through
      // the centralised helper keeps follow-graph-driven surfaces in sync
      // with the per-pair cache.
      invalidateFollowSurfaces(ref, key: key);
    } catch (e) {
      // Extract HTTP status + raw response payload from a DioException so
      // the trace shows the real backend signal rather than the generic
      // "Something went wrong" mapped message — that's what made the
      // unfollow regression initially unattributable.
      String? status;
      String? body;
      if (e is DioException) {
        status = e.response?.statusCode?.toString();
        body = e.response?.data?.toString();
      }
      RuntimeTrace.emit(
        'follow.api',
        'threw',
        data: {
          'op': current.following ? 'unfollow' : 'follow',
          'status': status,
          'body': body,
          'err': '$e',
        },
      );
      if (!mounted) return;
      // Rollback: drop optimistic override so the button reverts to the
      // provider's truth (which never changed locally).
      setState(() {
        _error = _readError(e);
        _optimisticFollowing = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          // Clear the override once the round-trip is done. The provider
          // re-fetch triggered by invalidateFollowSurfaces will land
          // with the authoritative truth on next watch.
          _optimisticFollowing = null;
        });
      }
    }
  }

  Future<void> _openMessage(ActorContext actor) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(interactionServiceProvider)
          .openDirectThread(context: context, ref: ref, target: _targetRef());
    } on InteractionError catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _readError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _readError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final m = data['message']?.toString().trim() ?? '';
        if (m.isNotEmpty) return m;
      }
      if (e.response?.statusCode == 403) {
        return 'Not allowed.';
      }
    }
    return 'Something went wrong. Try again.';
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStatusProvider);

    if (auth != AuthStatus.authed) {
      return Wrap(
        spacing: AuraSpace.s10,
        runSpacing: AuraSpace.s10,
        children: [
          AuraPrimaryButton(
            label: 'Sign in',
            icon: Icons.login_rounded,
            onPressed: () => context.push('/login'),
          ),
          AuraSecondaryButton(
            label: 'Join Aura',
            icon: Icons.person_add_alt_1_rounded,
            onPressed: () => context.push('/register'),
          ),
        ],
      );
    }

    final actor = resolveActorContext(context, ref);
    if (actor == null) {
      return const SizedBox.shrink();
    }
    final actorRef = _actorRefOf(actor);
    if (actorRef == null) return const SizedBox.shrink();

    if (_isOwnInstitution(actor)) {
      return Wrap(
        spacing: AuraSpace.s10,
        runSpacing: AuraSpace.s10,
        children: [
          AuraPrimaryButton(
            label: 'Open workspace',
            icon: Icons.dashboard_rounded,
            onPressed: () => context.push('/institution/dashboard'),
          ),
          AuraSecondaryButton(
            label: 'Edit profile',
            icon: Icons.edit_outlined,
            onPressed: () => context.push(
              widget.institutionId.isNotEmpty
                  ? institutionWorkspacePath(
                      widget.institutionId,
                      InstitutionSection.editProfile,
                    )
                  : '/institution/dashboard',
            ),
          ),
        ],
      );
    }

    final key = FollowStateKey(actor: actorRef, target: _targetRef());
    final stateAsync = ref.watch(followStateProvider(key));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        stateAsync.when(
          // Hold the current Follow / Following button visible during the
          // post-toggle invalidate — without this the SizedBox+spinner
          // replaces the button for one frame, which the user perceives
          // as the label flickering back to "Follow" before the new data
          // resolves. `skipLoadingOnReload` keeps the data branch active
          // for a reload that already has a previous value; the spinner
          // still appears on the genuine first load.
          skipLoadingOnReload: true,
          loading: () => const SizedBox(
            height: 38,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (e, _) => Text(
            'Could not load follow state.',
            style: AuraText.small.copyWith(color: AuraSurface.coRose),
          ),
          data: (state) {
            final effectiveFollowing = _optimisticFollowing ?? state.following;
            return Wrap(
              spacing: AuraSpace.s10,
              runSpacing: AuraSpace.s10,
              children: [
                AuraPrimaryButton(
                  label: _busy
                      ? 'Working…'
                      : (effectiveFollowing ? 'Following' : 'Follow'),
                  icon: effectiveFollowing
                      ? Icons.check_rounded
                      : Icons.add_rounded,
                  onPressed: _busy
                      ? null
                      : () => _toggleFollow(actor, state, key),
                ),
                AuraSecondaryButton(
                  label: state.canMessage
                      ? (_busy ? 'Opening…' : 'Message')
                      : (actor.isUser ? 'Follow to message' : 'Cannot message'),
                  icon: Icons.mail_outline_rounded,
                  onPressed: state.canMessage && !_busy
                      ? () => _openMessage(actor)
                      : null,
                ),
              ],
            );
          },
        ),
        if (_error != null) ...[
          const SizedBox(height: AuraSpace.s8),
          Text(
            _error!,
            style: AuraText.small.copyWith(color: AuraSurface.coRose),
          ),
        ],
      ],
    );
  }
}
