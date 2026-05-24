import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_responsive.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../civic_signals/widgets/sector_activity_panel.dart';
import '../../discourse_intelligence/widgets/discourse_continuity_panel.dart';
import '../../discourse_intelligence/widgets/institutional_response_history_strip.dart';
import '../../institution_ontology/models.dart';
import '../../institution_ontology/providers.dart';
import '../../institution_ontology/widgets/ontology_identity_chips.dart';
import '../data/public_institutions_repository.dart';

/// Sector landing — `/institutions/sector/:classId`.
///
/// Renders an ecosystem-style page scoped to a single curated class
/// (e.g., `GOVERNMENT`). Composition:
///
///   * Class hero — large class label, curated description, back link
///     to the directory.
///   * Type narrow pills — every type that belongs to this class.
///   * Verified institutions grid (capped at the server's default
///     page size) followed by "On the platform" grid for the rest.
///   * Filtered empty state when no institutions match.
///
/// Server-side filtering is the only source of truth — this screen
/// passes `class=` (and optionally `type=`) to
/// `publicInstitutionsListProvider` and consumes the paged result.
class InstitutionSectorScreen extends ConsumerStatefulWidget {
  const InstitutionSectorScreen({super.key, required this.classId});

  /// Wire token for the institution class (e.g., `GOVERNMENT`).
  final String classId;

  @override
  ConsumerState<InstitutionSectorScreen> createState() =>
      _InstitutionSectorScreenState();
}

class _InstitutionSectorScreenState
    extends ConsumerState<InstitutionSectorScreen> {
  String? _selectedType;

  PublicInstitutionsQuery get _query => PublicInstitutionsQuery(
        institutionClass: widget.classId,
        institutionType: _selectedType,
      );

  @override
  Widget build(BuildContext context) {
    final ontology = ref
        .watch(institutionOntologyProvider)
        .valueOrNull;
    final classDef = _resolveClass(ontology);
    final types = ontology?.typesForClass(widget.classId) ?? const [];
    final listAsync = ref.watch(publicInstitutionsListProvider(_query));

    return AuraScaffold(
      showHeader: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AuraSpace.s16,
          AuraSpace.s12,
          AuraSpace.s16,
          AuraSpace.s32,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              // Desktop composition normalization — matches the
              // directory landing so a class drill-through keeps the
              // same horizontal frame.
              constraints: const BoxConstraints(maxWidth: kHeroWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectorHero(classDef: classDef, classId: widget.classId),
                  if (types.isNotEmpty) ...[
                    const SizedBox(height: AuraSpace.s14),
                    _TypeNarrowPills(
                      types: types,
                      selected: _selectedType,
                      onChanged: (id) =>
                          setState(() => _selectedType = id),
                    ),
                  ],
                  const SizedBox(height: AuraSpace.s20),
                  listAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(AuraSpace.s24),
                      child: Center(
                        child: AuraLoadingState(
                          message: 'Loading institutions…',
                        ),
                      ),
                    ),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.all(AuraSpace.s8),
                      child: AuraErrorState(
                        title: 'Could not load this sector',
                        body: 'Try again in a moment.',
                        action: AuraSecondaryButton(
                          label: 'Retry',
                          onPressed: () => ref.invalidate(
                            publicInstitutionsListProvider(_query),
                          ),
                        ),
                      ),
                    ),
                    data: (page) => _SectorBodyWithActivity(
                      classId: widget.classId,
                      classLabel: classDef?.label ?? widget.classId,
                      page: page,
                      isFiltered: _selectedType != null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  InstitutionClassDef? _resolveClass(InstitutionOntology? ontology) {
    if (ontology == null) return null;
    for (final c in ontology.classes) {
      if (c.id == widget.classId) return c;
    }
    return null;
  }
}

class _SectorHero extends StatelessWidget {
  const _SectorHero({required this.classDef, required this.classId});

  final InstitutionClassDef? classDef;
  final String classId;

  @override
  Widget build(BuildContext context) {
    final label = classDef?.label ?? classId;
    final description =
        classDef?.description ?? 'Institutions classified as $classId.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => context.go('/institutions'),
          borderRadius: BorderRadius.circular(AuraRadius.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.s6,
              vertical: 2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.arrow_back_rounded,
                  size: 14,
                  color: AuraSurface.muted,
                ),
                const SizedBox(width: 4),
                Text(
                  'All institutions',
                  style: AuraText.small.copyWith(
                    color: AuraSurface.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AuraSpace.s8),
        Text(label, style: AuraText.headline),
        const SizedBox(height: AuraSpace.s6),
        Text(
          description,
          style: AuraText.body.copyWith(
            color: AuraSurface.muted,
            height: 1.55,
          ),
        ),
      ],
    );
  }
}

class _TypeNarrowPills extends StatelessWidget {
  const _TypeNarrowPills({
    required this.types,
    required this.selected,
    required this.onChanged,
  });

  final List<InstitutionTypeDef> types;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        children: [
          _Pill(
            label: 'All types',
            selected: selected == null,
            onTap: () => onChanged(null),
          ),
          for (final t in types) ...[
            const SizedBox(width: AuraSpace.s6),
            _Pill(
              label: t.label,
              selected: selected == t.id,
              onTap: () => onChanged(t.id),
            ),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AuraRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s10,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: selected ? AuraSurface.accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(AuraRadius.pill),
          border: Border.all(
            color: selected
                ? AuraSurface.accent.withValues(alpha: 0.4)
                : AuraSurface.divider,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AuraText.small.copyWith(
            color: selected ? AuraSurface.accentText : AuraSurface.muted,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

/// Layout host for the sector landing's main body.
///
/// On wide layouts (≥ 1100 px) renders the institution result grid as
/// the primary column with a secondary `SectorActivityPanel` column —
/// asymmetric ecosystem composition. On narrower viewports stacks
/// vertically with the panel below the grid.
///
/// The panel itself self-collapses when no signals exist, so there's
/// never a dead secondary column on quiet sectors. The right-column
/// width is capped at 360 px and falls back to 320 px on tighter
/// desktops; the main column always gets the bulk of horizontal room.
class _SectorBodyWithActivity extends StatelessWidget {
  const _SectorBodyWithActivity({
    required this.classId,
    required this.classLabel,
    required this.page,
    required this.isFiltered,
  });

  final String classId;
  final String classLabel;
  final PublicInstitutionsPage page;
  final bool isFiltered;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final body = _SectorBody(
          classLabel: classLabel,
          page: page,
          isFiltered: isFiltered,
        );
        // The secondary rail column now stacks two complementary
        // surfaces:
        //   * SectorActivityPanel — what institutions in this sector
        //     are publicly saying right now (institution-voice
        //     posts).
        //   * DiscourseContinuityPanel — observed civic continuity
        //     (ongoing discussions, unanswered questions, response
        //     activity). Each section self-collapses; the whole
        //     panel collapses when every section is empty.
        final secondary = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SectorActivityPanel(
              classId: classId,
              classLabel: classLabel,
            ),
            const SizedBox(height: AuraSpace.s12),
            InstitutionalResponseHistoryStrip(institutionClass: classId),
            const SizedBox(height: AuraSpace.s12),
            DiscourseContinuityPanel(institutionClass: classId),
          ],
        );
        if (constraints.maxWidth >= 1100) {
          final railWidth = constraints.maxWidth >= 1280 ? 360.0 : 320.0;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: body),
              const SizedBox(width: AuraSpace.s20),
              SizedBox(width: railWidth, child: secondary),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            body,
            const SizedBox(height: AuraSpace.s16),
            secondary,
          ],
        );
      },
    );
  }
}

class _SectorBody extends StatelessWidget {
  const _SectorBody({
    required this.classLabel,
    required this.page,
    required this.isFiltered,
  });

  final String classLabel;
  final PublicInstitutionsPage page;
  final bool isFiltered;

  @override
  Widget build(BuildContext context) {
    if (page.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AuraSpace.s24),
        child: AuraEmptyState(
          title: isFiltered
              ? 'No $classLabel institutions match this type yet'
              : 'No $classLabel institutions yet',
          body: isFiltered
              ? 'Try a different type or clear the filter to see every '
                  '$classLabel institution on the platform.'
              : 'When $classLabel organisations join Aura and complete '
                  'verification, they appear here.',
          icon: Icons.account_balance_outlined,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (page.verified.isNotEmpty) ...[
          _RowHeader(
            label: 'Verified',
            count: page.verified.length,
          ),
          const SizedBox(height: AuraSpace.s10),
          _SectorGrid(items: page.verified),
        ],
        if (page.other.isNotEmpty) ...[
          const SizedBox(height: AuraSpace.s24),
          _RowHeader(
            label: 'On the platform',
            count: page.other.length,
          ),
          const SizedBox(height: AuraSpace.s10),
          _SectorGrid(items: page.other),
        ],
      ],
    );
  }
}

class _RowHeader extends StatelessWidget {
  const _RowHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: AuraText.title.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: AuraSpace.s8),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s8,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: AuraSurface.subtle,
            borderRadius: BorderRadius.circular(AuraRadius.pill),
          ),
          child: Text(
            '$count',
            style: AuraText.micro.copyWith(
              color: AuraSurface.muted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectorGrid extends StatelessWidget {
  const _SectorGrid({required this.items});

  final List<PublicInstitutionSummary> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Sector landing inherits the same column rules as the main
        // directory grid — 4 cols at widescreen, 3 / 2 / 1 below.
        final cols = constraints.maxWidth >= 1280
            ? 4
            : constraints.maxWidth >= 920
                ? 3
                : constraints.maxWidth >= 600
                    ? 2
                    : 1;
        return Wrap(
          spacing: AuraSpace.s12,
          runSpacing: AuraSpace.s12,
          children: [
            for (final i in items)
              SizedBox(
                width: (constraints.maxWidth -
                        (AuraSpace.s12 * (cols - 1))) /
                    cols,
                child: _Card(item: i),
              ),
          ],
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.item});

  final PublicInstitutionSummary item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AuraSurface.card,
      borderRadius: BorderRadius.circular(AuraRadius.r14),
      child: InkWell(
        borderRadius: BorderRadius.circular(AuraRadius.r14),
        onTap: () => context.push('/institutions/${item.slug}'),
        child: Container(
          padding: const EdgeInsets.all(AuraSpace.s14),
          decoration: BoxDecoration(
            border: Border.all(
              color: AuraSurface.divider.withValues(alpha: 0.6),
            ),
            borderRadius: BorderRadius.circular(AuraRadius.r14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.name,
                style: AuraText.body.copyWith(fontWeight: FontWeight.w800),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              OntologyIdentityChips(
                institutionClass: item.institutionClass,
                institutionType: item.institutionType,
                domainTags: const [],
                dense: true,
              ),
              if ((item.tagline ?? '').isNotEmpty) ...[
                const SizedBox(height: AuraSpace.s8),
                Text(
                  item.tagline!,
                  style: AuraText.small.copyWith(
                    color: AuraSurface.muted,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
