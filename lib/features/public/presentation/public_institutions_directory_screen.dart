import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../features/institution_ontology/providers.dart';
import '../../../features/institution_ontology/widgets/ontology_class_filter.dart';
import '../../../features/institution_ontology/widgets/ontology_identity_chips.dart';
import '../../../shared/identity/aura_identity_badge.dart';
import '../data/public_institutions_repository.dart';

/// Public institution directory.
///
/// This is the single `/institutions` route. It renders THE SAME public
/// directory whether the visitor is signed in or not — the brief is
/// explicit that institutions must not feel hidden behind auth. Auth
/// affordances are added inline:
///   * Authed visitor with institution access → "Open your workspace"
///     pill at the top so they can re-enter the operator surface.
///   * Authed visitor without institution access → "Set up your
///     institution" pill linking to the existing /institutions/get-started
///     wizard.
///   * Unauthed visitor → "Join Aura" pill linking to /register.
///
/// The directory itself is sectioned by verification: verified
/// institutions are pinned at the top with a clear visual separator,
/// the unverified cohort follows. Within each cohort, items are sorted
/// by most-recent activity (institution.updatedAt) — newer activity
/// surfaces first without needing a trending algorithm.
class PublicInstitutionsDirectoryScreen extends ConsumerStatefulWidget {
  const PublicInstitutionsDirectoryScreen({super.key});

  @override
  ConsumerState<PublicInstitutionsDirectoryScreen> createState() =>
      _PublicInstitutionsDirectoryScreenState();
}

class _PublicInstitutionsDirectoryScreenState
    extends ConsumerState<PublicInstitutionsDirectoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _q = '';
  String? _category;
  bool _verifiedOnly = false;

  /// Ontology Level-1 filter (wire token, e.g., `GOVERNMENT`). Null =
  /// All. Sent to the backend `/v1/public/institutions?class=…` so the
  /// query is paginated and complete; no client-side overlay.
  String? _ontologyClass;

  /// Ontology Level-2 filter (wire token, e.g., `UNIVERSITY`). Null =
  /// no type narrow. Only meaningful when `_ontologyClass` is set; the
  /// type narrow pill row only renders in that case.
  String? _ontologyType;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  PublicInstitutionsQuery get _query => PublicInstitutionsQuery(
        q: _q,
        category: _category,
        verifiedOnly: _verifiedOnly,
        institutionClass: _ontologyClass,
        institutionType: _ontologyType,
      );

  @override
  Widget build(BuildContext context) {
    final isAuthed = ref.watch(isAuthedProvider);
    final categoriesAsync = ref.watch(publicInstitutionCategoriesProvider);
    final listAsync = ref.watch(publicInstitutionsListProvider(_query));

    return AuraScaffold(
      showHeader: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AuraSpace.s16,
          AuraSpace.s20,
          AuraSpace.s16,
          AuraSpace.s32,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(isAuthed: isAuthed),
                  const SizedBox(height: AuraSpace.s20),
                  _SearchAndFilters(
                    controller: _searchController,
                    onSearchSubmit: (value) {
                      setState(() => _q = value.trim());
                    },
                    onSearchChanged: (value) {
                      // Debounce-free: only refetch when the user pauses;
                      // server filters on substring so this is cheap.
                      setState(() => _q = value.trim());
                    },
                    categoriesAsync: categoriesAsync,
                    selectedCategory: _category,
                    onCategoryChanged: (value) =>
                        setState(() => _category = value),
                    verifiedOnly: _verifiedOnly,
                    onVerifiedToggled: (value) =>
                        setState(() => _verifiedOnly = value),
                  ),
                  const SizedBox(height: AuraSpace.s12),
                  // Ontology Level-1 class filter pills. Renders only the
                  // curated classes (from `institutionOntologyProvider`).
                  // Self-renders an "All" pill so the row makes sense even
                  // before the ontology has loaded. Selecting a class
                  // sends `?class=…` to the backend AND reveals the type
                  // narrow row below.
                  OntologyClassFilter(
                    selected: _ontologyClass,
                    onChanged: (id) {
                      setState(() {
                        _ontologyClass = id;
                        // Selecting (or clearing) a class drops any
                        // active type filter — the chosen type may no
                        // longer belong to the new class.
                        _ontologyType = null;
                      });
                    },
                  ),
                  if (_ontologyClass != null) ...[
                    const SizedBox(height: AuraSpace.s8),
                    _OntologyTypeNarrowRow(
                      classId: _ontologyClass!,
                      selected: _ontologyType,
                      onChanged: (id) =>
                          setState(() => _ontologyType = id),
                    ),
                  ],
                  const SizedBox(height: AuraSpace.s16),
                  listAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(AuraSpace.s32),
                      child: Center(
                        child: AuraLoadingState(
                            message: 'Loading institutions…'),
                      ),
                    ),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.all(AuraSpace.s8),
                      child: AuraErrorState(
                        title: 'Could not load the directory',
                        body: 'Try again in a moment.',
                        action: AuraSecondaryButton(
                          label: 'Retry',
                          onPressed: () => ref.invalidate(
                            publicInstitutionsListProvider(_query),
                          ),
                        ),
                      ),
                    ),
                    data: (page) => _ResultsBody(
                      page: page,
                      hasQuery: _q.isNotEmpty ||
                          _category != null ||
                          _verifiedOnly ||
                          _ontologyClass != null ||
                          _ontologyType != null,
                      ontologyFilterActive:
                          _ontologyClass != null || _ontologyType != null,
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
}

class _Header extends ConsumerWidget {
  const _Header({required this.isAuthed});
  final bool isAuthed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Institutions', style: AuraText.headline),
        const SizedBox(height: AuraSpace.s6),
        Text(
          'Public ledgers of accountability. Verified organizations '
          'speak here under their official identity — and members can '
          'see exactly who said what, on the record.',
          style: AuraText.body.copyWith(
            color: AuraSurface.muted,
            height: 1.55,
          ),
        ),
        const SizedBox(height: AuraSpace.s14),
        _AuthAffordance(isAuthed: isAuthed),
      ],
    );
  }
}

class _AuthAffordance extends ConsumerWidget {
  const _AuthAffordance({required this.isAuthed});
  final bool isAuthed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isAuthed) {
      return Row(
        children: [
          AuraSecondaryButton(
            label: 'Join Aura',
            onPressed: () => context.go('/register'),
          ),
          const SizedBox(width: AuraSpace.s8),
          AuraSecondaryButton(
            label: 'Sign in',
            onPressed: () => context.go('/login'),
          ),
        ],
      );
    }
    // Authed: link to the workspace entry. The /institution/dashboard
    // route is itself access-aware — it routes the user to setup if
    // they don't yet have institution access, so we don't need to
    // probe access state from here (probing would slow down the public
    // directory load for every authed visitor for no UX benefit).
    return AuraSecondaryButton(
      label: 'Your workspace',
      icon: Icons.arrow_outward_rounded,
      onPressed: () => context.go('/institution/dashboard'),
    );
  }
}

class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters({
    required this.controller,
    required this.onSearchSubmit,
    required this.onSearchChanged,
    required this.categoriesAsync,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.verifiedOnly,
    required this.onVerifiedToggled,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSearchSubmit;
  final ValueChanged<String> onSearchChanged;
  final AsyncValue<List<String>> categoriesAsync;
  final String? selectedCategory;
  final ValueChanged<String?> onCategoryChanged;
  final bool verifiedOnly;
  final ValueChanged<bool> onVerifiedToggled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          onSubmitted: onSearchSubmit,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search institutions by name, tagline, or description',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: AuraSurface.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AuraRadius.r12),
              borderSide: BorderSide(
                color: AuraSurface.divider.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
        const SizedBox(height: AuraSpace.s12),
        Wrap(
          spacing: AuraSpace.s8,
          runSpacing: AuraSpace.s8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilterChip(
              selected: verifiedOnly,
              onSelected: onVerifiedToggled,
              avatar: const Icon(Icons.verified_rounded, size: 16),
              label: const Text('Verified only'),
            ),
            categoriesAsync.maybeWhen(
              data: (cats) {
                if (cats.isEmpty) return const SizedBox.shrink();
                return DropdownButton<String?>(
                  value: selectedCategory,
                  hint: const Text('Any category'),
                  underline: const SizedBox.shrink(),
                  borderRadius: BorderRadius.circular(AuraRadius.r10),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Any category'),
                    ),
                    for (final c in cats)
                      DropdownMenuItem<String?>(
                        value: c,
                        child: Text(c),
                      ),
                  ],
                  onChanged: onCategoryChanged,
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
      ],
    );
  }
}

class _ResultsBody extends StatelessWidget {
  const _ResultsBody({
    required this.page,
    required this.hasQuery,
    this.ontologyFilterActive = false,
  });
  final PublicInstitutionsPage page;
  final bool hasQuery;

  /// True when the user has applied an ontology class or type filter.
  /// Drives the filtered empty-state copy — server-side filtering
  /// means an empty result on an ontology filter is meaningful ("no
  /// institutions match this classification yet") rather than a
  /// partial-page artefact.
  final bool ontologyFilterActive;

  @override
  Widget build(BuildContext context) {
    if (page.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AuraSpace.s24),
        child: AuraEmptyState(
          title: ontologyFilterActive
              ? 'No institutions match this classification yet'
              : (hasQuery
                  ? 'No institutions match those filters'
                  : 'Verified institutions arrive here as they onboard'),
          body: ontologyFilterActive
              ? 'Try a different class or clear the filter to browse '
                  'every institution on the platform.'
              : (hasQuery
                  ? 'Try removing a filter or widening your search.'
                  : 'When organizations join Aura and complete '
                      'verification, their public profile appears on '
                      'this directory. Until then, you can explore '
                      'individual institutions through links shared in '
                      'posts and announcements.'),
          icon: Icons.account_balance_outlined,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (page.verified.isNotEmpty) ...[
          _SectionHeading(
            label: 'Verified',
            count: page.verified.length,
            tone: _SectionTone.verified,
            blurb: 'Organizations whose identity Aura has confirmed.',
          ),
          const SizedBox(height: AuraSpace.s10),
          _InstitutionGrid(items: page.verified),
        ],
        if (page.other.isNotEmpty) ...[
          const SizedBox(height: AuraSpace.s24),
          _SectionHeading(
            label: 'On the platform',
            count: page.other.length,
            tone: _SectionTone.other,
            blurb:
                'Organizations active on Aura. Verification confirms the '
                'identity behind the name; it is in progress for these.',
          ),
          const SizedBox(height: AuraSpace.s10),
          _InstitutionGrid(items: page.other),
        ],
      ],
    );
  }
}

enum _SectionTone { verified, other }

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.label,
    required this.count,
    required this.tone,
    required this.blurb,
  });
  final String label;
  final int count;
  final _SectionTone tone;
  final String blurb;

  @override
  Widget build(BuildContext context) {
    final accent = tone == _SectionTone.verified
        ? Theme.of(context).colorScheme.primary
        : AuraSurface.muted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 6,
              height: 18,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AuraSpace.s8),
            Text(label, style: AuraText.title),
            const SizedBox(width: AuraSpace.s8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AuraSpace.s8,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AuraSurface.card,
                borderRadius: BorderRadius.circular(AuraRadius.pill),
                border: Border.all(
                  color: AuraSurface.divider.withValues(alpha: 0.6),
                ),
              ),
              child: Text(
                '$count',
                style: AuraText.micro.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AuraSurface.faint,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 14),
          child: Text(
            blurb,
            style: AuraText.small.copyWith(
              color: AuraSurface.muted,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _InstitutionGrid extends StatelessWidget {
  const _InstitutionGrid({required this.items});
  final List<PublicInstitutionSummary> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 960
            ? 3
            : constraints.maxWidth >= 640
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
                child: _InstitutionCard(item: i),
              ),
          ],
        );
      },
    );
  }
}

class _InstitutionCard extends StatelessWidget {
  const _InstitutionCard({required this.item});
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
            borderRadius: BorderRadius.circular(AuraRadius.r14),
            border: Border.all(
              color: AuraSurface.divider.withValues(alpha: 0.6),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Avatar(item: item),
                  const SizedBox(width: AuraSpace.s10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                item.name,
                                style: AuraText.body.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (item.isVerified) ...[
                              const SizedBox(width: 6),
                              const AuraVerifiedInstitutionBadge(),
                            ],
                          ],
                        ),
                        if ((item.institutionClass ?? '').isNotEmpty ||
                            (item.institutionType ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: OntologyIdentityChips(
                              institutionClass: item.institutionClass,
                              institutionType: item.institutionType,
                              domainTags: const [],
                              dense: true,
                            ),
                          )
                        else if ((item.category ?? '').isNotEmpty)
                          // Legacy category fallback — for unclassified
                          // institutions that haven't yet been upgraded to
                          // the ontology.
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              item.category!,
                              style: AuraText.micro.copyWith(
                                color: AuraSurface.faint,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AuraSpace.s10),
              if ((item.tagline ?? '').isNotEmpty)
                Text(
                  item.tagline!,
                  style: AuraText.small.copyWith(
                    color: AuraSurface.ink,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )
              else if ((item.description ?? '').isNotEmpty)
                Text(
                  item.description!,
                  style: AuraText.small.copyWith(
                    color: AuraSurface.muted,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: AuraSpace.s10),
              Wrap(
                spacing: AuraSpace.s6,
                runSpacing: 4,
                children: [
                  if (item.memberCount > 0)
                    _MetaChip(
                      icon: Icons.group_outlined,
                      label: _pluralize(item.memberCount, 'member'),
                    ),
                  if (item.announcementCount > 0)
                    _MetaChip(
                      icon: Icons.campaign_outlined,
                      label: _pluralize(item.announcementCount, 'announcement'),
                    ),
                  if (item.unitCount > 0)
                    _MetaChip(
                      icon: Icons.account_tree_outlined,
                      label: _pluralize(item.unitCount, 'unit'),
                    ),
                  if (item.locationLabel.isNotEmpty)
                    _MetaChip(
                      icon: Icons.place_outlined,
                      label: item.locationLabel,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.item});
  final PublicInstitutionSummary item;

  @override
  Widget build(BuildContext context) {
    final initial = item.name.trim().isEmpty
        ? '?'
        : item.name.trim()[0].toUpperCase();
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AuraRadius.r10),
        border: Border.all(
          color:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        initial,
        style: AuraText.title.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(
          color: AuraSurface.divider.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AuraSurface.faint),
          const SizedBox(width: 4),
          Text(
            label,
            style: AuraText.micro.copyWith(
              color: AuraSurface.faint,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

String _pluralize(int n, String singular) {
  if (n == 1) return '1 $singular';
  return '$n ${singular}s';
}

/// Type narrow row — only renders once a Level-1 class is selected.
/// Surfaces the curated types belonging to the parent class as a
/// secondary horizontal pill row. Wire tokens are sent verbatim to
/// the backend `/v1/public/institutions?type=…` filter.
class _OntologyTypeNarrowRow extends ConsumerWidget {
  const _OntologyTypeNarrowRow({
    required this.classId,
    required this.selected,
    required this.onChanged,
  });

  final String classId;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ontology = ref
        .watch(institutionOntologyProvider)
        .valueOrNull;
    if (ontology == null) return const SizedBox.shrink();
    final types = ontology.typesForClass(classId);
    if (types.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 30,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        children: [
          _TypePill(
            label: 'Any type',
            selected: selected == null,
            onTap: () => onChanged(null),
          ),
          for (final t in types) ...[
            const SizedBox(width: AuraSpace.s6),
            _TypePill(
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

class _TypePill extends StatelessWidget {
  const _TypePill({
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
          vertical: 4,
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
