/// SUBJECTS — people and institutions as coherent operator subjects.
///
/// The console this replaces had `/admin/users`, `/admin/institutions`,
/// `/admin/institutions/:id/members`, `/admin/grants` and
/// `/admin/identity-review` as five unrelated screens, three of which had no
/// navigation entry. Understanding one person meant visiting several of them
/// and holding the result in your head.
///
/// A subject brings the governed state together WITHOUT collapsing the
/// authorities behind it. Identity, standing, capability and membership remain
/// separate decisions made by separate authorities; this is one place to see
/// them, and one place from which to invoke them.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../data/admin_providers.dart';
import '../data/operator_cache.dart';
import '../domain/operator_authority_provider.dart';
import '../domain/operator_capability.dart';
import '../domain/operator_routes.dart';
import '../ui/operator_kit.dart';

/// Which kind of subject the directory is showing.
///
/// PUBLIC, unlike the rest of this file's internals: the render harness sets
/// it to photograph the institution directory, which is otherwise unreachable
/// in a still image and so was never looked at.
final subjectKindProvider =
    StateProvider<SubjectKind>((_) => SubjectKind.people);

enum SubjectKind { people, institutions }

final subjectQueryProvider = StateProvider<String>((_) => '');

final subjectPeopleProvider = FutureProvider.autoDispose((ref) async {
  cacheOperatorReading(ref);
  final query = ref.watch(subjectQueryProvider);
  return ref.watch(adminRepositoryProvider).fetchUsers(query: query, limit: 50);
});

/// The directory, across EVERY standing.
///
/// The server used to answer an unfiltered request with verified institutions
/// only, so pending, suspended and rejected subjects were absent from the
/// console's one institution list without any sign that they had been left
/// out. Standing is now a facet the operator chooses, not a hidden default.
final subjectInstitutionsProvider = FutureProvider.autoDispose((ref) async {
  cacheOperatorReading(ref);
  return ref.watch(adminRepositoryProvider).fetchInstitutions();
});

/// ONE institution subject, resolved by id.
///
/// Independent of the directory and of whatever standing filter is applied to
/// it: a subject exists, or it does not.
final institutionSubjectProvider = FutureProvider.autoDispose
    .family<AdminInstitutionSummary?, String>((ref, institutionId) async {
  cacheOperatorReading(ref);
  return ref.watch(adminRepositoryProvider).fetchInstitution(institutionId);
});

/// Which standing the directory is showing. `null` is every standing — the
/// operator's default, because a directory that hides subjects is not one.
final subjectStandingProvider = StateProvider<String?>((_) => null);

class SubjectsArea extends ConsumerWidget {
  const SubjectsArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authority = ref.watch(operatorAuthorityProvider).valueOrNull ??
        const OperatorAuthority.none();
    final kind = ref.watch(subjectKindProvider);

    final canPeople = authority.can(OperatorCapability.usersRead);
    final canInstitutions = authority.can(OperatorCapability.institutionsRead);

    // An operator holding neither is told so rather than shown empty tabs.
    if (!canPeople && !canInstitutions) {
      return const Padding(
        padding: EdgeInsets.all(AuraSpace.s20),
        child: OperatorInsufficientCapability(needs: 'people or institution'),
      );
    }

    // The selector never offers a kind the operator cannot read.
    final effective = switch (kind) {
      SubjectKind.people when !canPeople => SubjectKind.institutions,
      SubjectKind.institutions when !canInstitutions => SubjectKind.people,
      _ => kind,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                wide ? AuraSpace.s20 : AuraSpace.s12,
                wide ? AuraSpace.s20 : AuraSpace.s12,
                wide ? AuraSpace.s20 : AuraSpace.s12,
                AuraSpace.s12,
              ),
              child: Row(
                children: [
                  if (canPeople && canInstitutions) ...[
                    _KindChip(
                      label: 'People',
                      icon: Icons.person_outline_rounded,
                      selected: effective == SubjectKind.people,
                      onTap: () => ref
                          .read(subjectKindProvider.notifier)
                          .state = SubjectKind.people,
                    ),
                    const SizedBox(width: AuraSpace.s8),
                    _KindChip(
                      label: 'Institutions',
                      icon: Icons.apartment_rounded,
                      selected: effective == SubjectKind.institutions,
                      onTap: () => ref
                          .read(subjectKindProvider.notifier)
                          .state = SubjectKind.institutions,
                    ),
                    const SizedBox(width: AuraSpace.s16),
                  ],
                  Expanded(child: _SearchField(kind: effective)),
                ],
              ),
            ),
            // STANDING IS A FACET, NOT A HIDDEN DEFAULT. It appears only for
            // institutions, because people carry standing on the person and
            // not as a directory-wide slice.
            if (effective == SubjectKind.institutions)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  wide ? AuraSpace.s20 : AuraSpace.s12,
                  0,
                  wide ? AuraSpace.s20 : AuraSpace.s12,
                  AuraSpace.s12,
                ),
                child: const _StandingFacet(),
              ),
            Expanded(
              child: effective == SubjectKind.people
                  ? const _PeopleList()
                  : const _InstitutionsList(),
            ),
          ],
        );
      },
    );
  }
}

class _SearchField extends ConsumerStatefulWidget {
  const _SearchField({required this.kind});

  /// What is being searched. An institution has no email address, and a field
  /// offering to search one is the console describing a capability it does
  /// not have.
  final SubjectKind kind;

  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      style: const TextStyle(color: AuraSurface.ink, fontSize: 13.5),
      onSubmitted: (v) =>
          ref.read(subjectQueryProvider.notifier).state = v.trim(),
      decoration: InputDecoration(
        isDense: true,
        hintText: widget.kind == SubjectKind.people
            ? 'Search by name or email'
            : 'Search by name, address or domain',
        hintStyle: const TextStyle(color: AuraSurface.faint, fontSize: 13.5),
        prefixIcon:
            const Icon(Icons.search_rounded, size: 18, color: AuraSurface.faint),
        filled: true,
        fillColor: AuraSurface.card,
        contentPadding: const EdgeInsets.symmetric(vertical: AuraSpace.s12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AuraRadius.pill),
          borderSide: const BorderSide(color: AuraSurface.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AuraRadius.pill),
          borderSide: const BorderSide(color: AuraSurface.divider),
        ),
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AuraSurface.accentSoft : AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        child: InkWell(
          borderRadius: BorderRadius.circular(AuraRadius.pill),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.s14,
              vertical: AuraSpace.s10,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 15,
                    color: selected ? AuraSurface.accent : AuraSurface.muted),
                const SizedBox(width: AuraSpace.s6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? AuraSurface.ink : AuraSurface.muted,
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

/// Every standing, and each one on its own.
///
/// "Everything" leads because it is the honest default for a directory of
/// subjects. The others are how an operator narrows deliberately — never how
/// the product narrows silently.
class _StandingFacet extends ConsumerWidget {
  const _StandingFacet();

  static const _standings = <(String?, String)>[
    (null, 'Everything'),
    ('VERIFIED', 'Verified'),
    ('PENDING', 'Awaiting review'),
    ('SUSPENDED', 'Suspended'),
    ('REJECTED', 'Rejected'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(subjectStandingProvider);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (value, label) in _standings) ...[
            _KindChip(
              label: label,
              icon: value == null
                  ? Icons.all_inclusive_rounded
                  : _standingIcon(value),
              selected: selected == value,
              onTap: () =>
                  ref.read(subjectStandingProvider.notifier).state = value,
            ),
            const SizedBox(width: AuraSpace.s8),
          ],
        ],
      ),
    );
  }

  static IconData _standingIcon(String standing) => switch (standing) {
        'VERIFIED' => Icons.verified_outlined,
        'PENDING' => Icons.hourglass_empty_rounded,
        'SUSPENDED' => Icons.pause_circle_outline_rounded,
        _ => Icons.block_outlined,
      };
}

class _PeopleList extends ConsumerWidget {
  const _PeopleList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = ref.watch(subjectPeopleProvider);
    final query = ref.watch(subjectQueryProvider);

    return people.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: AuraSpace.s16),
        child: OperatorLoading(lines: 6),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(AuraSpace.s16),
        child: OperatorFailure(
          title: 'People could not be loaded',
          onRetry: () => ref.invalidate(subjectPeopleProvider),
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return OperatorClear(
            title: query.isEmpty ? 'No people yet' : 'No one matches "$query"',
            icon: Icons.person_search_rounded,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            AuraSpace.s16, 0, AuraSpace.s16, AuraSpace.s20),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final person = list[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: AuraSpace.s8),
              child: _SubjectRow(
                title: person.person.displayName.isEmpty
                    ? person.email
                    : person.person.displayName,
                subtitle: person.email,
                state: person.status,
                // OPERATOR AUTHORITY, or nothing. Almost nobody holds one,
                // and the directory says nothing rather than inventing a rank
                // for everybody else.
                trailing: person.isOperator ? person.role : null,
                onTap: () => context.go(operatorPersonRoute(person.person.userId)),
              ),
            );
          },
        );
      },
    );
  }
}

class _InstitutionsList extends ConsumerWidget {
  const _InstitutionsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final institutions = ref.watch(subjectInstitutionsProvider);
    final query = ref.watch(subjectQueryProvider).toLowerCase();

    return institutions.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: AuraSpace.s16),
        child: OperatorLoading(lines: 5),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(AuraSpace.s16),
        child: OperatorFailure(
          title: 'Institutions could not be loaded',
          onRetry: () => ref.invalidate(subjectInstitutionsProvider),
        ),
      ),
      data: (all) {
        final standing = ref.watch(subjectStandingProvider);
        final byStanding = standing == null
            ? all
            : all.where((i) => i.status == standing).toList();
        final list = query.isEmpty
            ? byStanding
            : byStanding
                .where((i) =>
                    i.name.toLowerCase().contains(query) ||
                    i.slug.toLowerCase().contains(query) ||
                    (i.domain ?? '').toLowerCase().contains(query))
                .toList();
        if (list.isEmpty) {
          // AN EMPTY RESULT NAMES ITS OWN NARROWING. "No institutions yet" over
          // a filtered directory is a lie about the estate.
          return OperatorClear(
            title: query.isNotEmpty
                ? 'No institution matches "$query"'
                : standing != null
                    ? 'No institution is ${_standingWord(standing)}'
                    : 'No institutions yet',
            detail: standing != null && all.isNotEmpty
                ? '${all.length} institution${all.length == 1 ? '' : 's'} '
                    'exist under other standings.'
                : null,
            icon: Icons.apartment_rounded,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(
              AuraSpace.s16, 0, AuraSpace.s16, AuraSpace.s20),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final institution = list[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: AuraSpace.s8),
              child: _SubjectRow(
                title: institution.name,
                subtitle: institution.domain?.isNotEmpty == true
                    ? institution.domain!
                    : institution.slug,
                state: institution.status,
                trailing: '${institution.memberCount} '
                    'member${institution.memberCount == 1 ? '' : 's'}',
                onTap: () => context
                    .go(operatorInstitutionRoute(institution.id)),
              ),
            );
          },
        );
      },
    );
  }
}

String _standingWord(String standing) => switch (standing) {
      'VERIFIED' => 'verified',
      'PENDING' => 'awaiting review',
      'SUSPENDED' => 'suspended',
      'REJECTED' => 'rejected',
      _ => standing.toLowerCase(),
    };

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({
    required this.title,
    required this.subtitle,
    required this.state,
    required this.onTap,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final String state;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AuraSurface.card,
      borderRadius: BorderRadius.circular(AuraRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AuraRadius.card),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AuraRadius.card),
            border: Border.all(color: AuraSurface.divider),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s14,
            vertical: AuraSpace.s12,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AuraSurface.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AuraSurface.muted),
                    ),
                  ],
                ),
              ),
              if (trailing != null && trailing!.isNotEmpty) ...[
                Text(
                  trailing!,
                  style: const TextStyle(
                      fontSize: 11.5, color: AuraSurface.faint),
                ),
                const SizedBox(width: AuraSpace.s12),
              ],
              OperatorStatePill(state: state, dense: true),
              const SizedBox(width: AuraSpace.s8),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AuraSurface.faint),
            ],
          ),
        ),
      ),
    );
  }
}
