import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../shared/identity/aura_identity_badge.dart';
import '../data/public_institutions_repository.dart';

/// Public profile for a single unit (sub-entity) of an institution.
///
/// Honest scope: Units do not yet carry their own posts/announcements
/// stream in the data model (`InstitutionUnit` is identity-only). The
/// page renders the unit's identity + a link back into the parent
/// institution's public surface so the trust attribution is intact.
/// When unit-scoped posts ship, the "Activity" block becomes the
/// stream; until then it points at the parent institution feed and
/// labels the redirect honestly.
class _UnitDetailArgs {
  const _UnitDetailArgs({required this.slug, required this.unitSlug});
  final String slug;
  final String unitSlug;

  @override
  bool operator ==(Object other) =>
      other is _UnitDetailArgs &&
      other.slug == slug &&
      other.unitSlug == unitSlug;

  @override
  int get hashCode => Object.hash(slug, unitSlug);
}

final publicUnitDetailProvider = FutureProvider.family<
    PublicUnitDetail, _UnitDetailArgs>((ref, args) {
  return ref
      .watch(publicInstitutionsRepositoryProvider)
      .getUnit(args.slug, args.unitSlug);
});

class PublicUnitDetailScreen extends ConsumerWidget {
  const PublicUnitDetailScreen({
    super.key,
    required this.slug,
    required this.unitSlug,
  });

  final String slug;
  final String unitSlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = _UnitDetailArgs(slug: slug, unitSlug: unitSlug);
    final async = ref.watch(publicUnitDetailProvider(args));
    return AuraScaffold(
      showHeader: false,
      body: async.when(
        loading: () => const Center(
          child: AuraLoadingState(message: 'Loading unit…'),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AuraSpace.s16),
            child: AuraErrorState(
              title: 'Could not load unit',
              body: 'Try again in a moment.',
              action: AuraSecondaryButton(
                label: 'Retry',
                onPressed: () =>
                    ref.invalidate(publicUnitDetailProvider(args)),
              ),
            ),
          ),
        ),
        data: (detail) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AuraSpace.s16,
            AuraSpace.s20,
            AuraSpace.s16,
            AuraSpace.s32,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: _Body(detail: detail),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.detail});
  final PublicUnitDetail detail;

  @override
  Widget build(BuildContext context) {
    final unit = detail.unit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () =>
              context.push('/institutions/${detail.institutionSlug}/units'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.arrow_back_rounded, size: 16),
                const SizedBox(width: 6),
                Text(
                  'All units of ${detail.institutionName}',
                  style: AuraText.small.copyWith(
                    color: AuraSurface.faint,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AuraSpace.s14),
        // Trust-attribution band — surfaces the parent institution above
        // the unit identity so the visitor sees the upstream first.
        InkWell(
          onTap: () =>
              context.push('/institutions/${detail.institutionSlug}'),
          borderRadius: BorderRadius.circular(AuraRadius.r12),
          child: Container(
            padding: const EdgeInsets.all(AuraSpace.s12),
            decoration: BoxDecoration(
              color: AuraSurface.card,
              borderRadius: BorderRadius.circular(AuraRadius.r12),
              border: Border.all(
                color: AuraSurface.divider.withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AuraRadius.r10),
                  ),
                  child: Text(
                    detail.institutionName.trim().isEmpty
                        ? '?'
                        : detail.institutionName.trim()[0].toUpperCase(),
                    style: AuraText.title.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: AuraSpace.s10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'A unit of',
                        style: AuraText.micro.copyWith(
                          color: AuraSurface.faint,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              detail.institutionName,
                              style: AuraText.body.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (detail.institutionIsVerified) ...[
                            const SizedBox(width: 6),
                            const AuraVerifiedInstitutionBadge(),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AuraSurface.faint,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AuraSpace.s20),
        Row(
          children: [
            Icon(
              Icons.hub_outlined,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              _typeLabel(unit.type),
              style: AuraText.micro.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
        const SizedBox(height: AuraSpace.s8),
        Text(unit.name, style: AuraText.headline),
        if ((unit.description ?? '').isNotEmpty) ...[
          const SizedBox(height: AuraSpace.s10),
          Text(
            unit.description!,
            style: AuraText.body.copyWith(height: 1.55),
          ),
        ],
        const SizedBox(height: AuraSpace.s20),
        if ((unit.locationLabel.isNotEmpty) ||
            (unit.websiteUrl ?? '').isNotEmpty ||
            (unit.contactEmail ?? '').isNotEmpty)
          _MetaPanel(unit: unit),
        const SizedBox(height: AuraSpace.s20),
        _ActivityRedirect(institutionSlug: detail.institutionSlug),
      ],
    );
  }
}

class _MetaPanel extends StatelessWidget {
  const _MetaPanel({required this.unit});
  final PublicUnit unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s14),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.r12),
        border: Border.all(
          color: AuraSurface.divider.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (unit.locationLabel.isNotEmpty)
            _MetaRow(icon: Icons.place_outlined, label: unit.locationLabel),
          if ((unit.websiteUrl ?? '').isNotEmpty)
            _MetaRow(
              icon: Icons.link_rounded,
              label: unit.websiteUrl!,
              selectable: true,
            ),
          if ((unit.contactEmail ?? '').isNotEmpty)
            _MetaRow(
              icon: Icons.mail_outline_rounded,
              label: unit.contactEmail!,
              selectable: true,
            ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.label,
    this.selectable = false,
  });
  final IconData icon;
  final String label;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: AuraSurface.faint),
          const SizedBox(width: AuraSpace.s8),
          Expanded(
            child: selectable
                ? SelectableText(
                    label,
                    style: AuraText.small.copyWith(color: AuraSurface.ink),
                  )
                : Text(
                    label,
                    style: AuraText.small.copyWith(color: AuraSurface.ink),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ActivityRedirect extends StatelessWidget {
  const _ActivityRedirect({required this.institutionSlug});
  final String institutionSlug;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s14),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.r12),
        border: Border.all(
          color: AuraSurface.divider.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Public activity', style: AuraText.title),
          const SizedBox(height: AuraSpace.s6),
          Text(
            'Posts and announcements from this unit appear in the '
            'parent institution\'s public stream. Open the institution '
            'page to read them in context.',
            style: AuraText.body.copyWith(
              color: AuraSurface.muted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AuraSpace.s10),
          AuraSecondaryButton(
            label: 'Open the institution page',
            icon: Icons.arrow_outward_rounded,
            onPressed: () => context.push('/institutions/$institutionSlug'),
          ),
        ],
      ),
    );
  }
}

String _typeLabel(String type) {
  return type.replaceAll('_', ' ').toUpperCase();
}
