import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/institutions_repository.dart';
import '../domain/institution.dart';

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

class _InstitutionDetailBody extends StatelessWidget {
  const _InstitutionDetailBody({required this.institution});

  final Institution institution;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AuraSpace.s16,
                AuraSpace.s20,
                AuraSpace.s16,
                AuraSpace.s32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _buildContent(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildContent() {
    final title = institution.name.trim().isNotEmpty
        ? institution.name.trim()
        : 'Institution';

    final subtitleParts = <String>[
      if (institution.slug.trim().isNotEmpty) institution.slug.trim(),
      if (institution.domain.trim().isNotEmpty) institution.domain.trim(),
    ];

    final isVerified = institution.isVerified;

    return [
      // Hero header card
      Container(
        padding: const EdgeInsets.all(AuraSpace.s20),
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
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AuraSurface.accentSoft,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AuraSurface.accent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.apartment_outlined,
                    size: 24,
                    color: AuraSurface.accentText,
                  ),
                ),
                const SizedBox(width: AuraSpace.s14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: Text(title, style: AuraText.title)),
                          if (isVerified) ...[
                            const SizedBox(width: AuraSpace.s8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AuraSpace.s8,
                                vertical: AuraSpace.s4,
                              ),
                              decoration: BoxDecoration(
                                color: AuraSurface.goodBg,
                                borderRadius: BorderRadius.circular(
                                  AuraRadius.pill,
                                ),
                                border: Border.all(
                                  color: AuraSurface.goodInk.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.verified_rounded,
                                    size: 12,
                                    color: AuraSurface.goodInk,
                                  ),
                                  const SizedBox(width: AuraSpace.s4),
                                  Text(
                                    'Verified',
                                    style: AuraText.micro.copyWith(
                                      color: AuraSurface.goodInk,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (subtitleParts.isNotEmpty) ...[
                        const SizedBox(height: AuraSpace.s6),
                        Text(
                          subtitleParts.join(' · '),
                          style: AuraText.small.copyWith(
                            color: AuraSurface.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (institution.description.trim().isNotEmpty) ...[
              const SizedBox(height: AuraSpace.s16),
              Text(
                institution.description.trim(),
                style: AuraText.body.copyWith(
                  color: AuraSurface.muted,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: AuraSpace.s14),
      // Standing card
      _InfoSection(
        title: 'Standing',
        rows: [
          _InfoRow(
            label: 'Verification',
            value: isVerified ? 'Verified' : 'Not verified',
            valueColor: isVerified ? AuraSurface.goodInk : AuraSurface.muted,
          ),
          if (institution.jurisdiction.trim().isNotEmpty)
            _InfoRow(
              label: 'Jurisdiction',
              value: institution.jurisdiction.trim(),
            ),
          if (institution.domain.trim().isNotEmpty)
            _InfoRow(label: 'Domain', value: institution.domain.trim()),
        ],
      ),
      const SizedBox(height: AuraSpace.s14),
      // Details card
      _InfoSection(
        title: 'Details',
        rows: [
          _InfoRow(label: 'Name', value: institution.name),
          _InfoRow(label: 'Slug', value: institution.slug),
          if (institution.domain.trim().isNotEmpty)
            _InfoRow(label: 'Domain', value: institution.domain),
          if (institution.jurisdiction.trim().isNotEmpty)
            _InfoRow(label: 'Jurisdiction', value: institution.jurisdiction),
          if (institution.website.trim().isNotEmpty)
            _InfoRow(label: 'Website', value: institution.website),
          _InfoRow(
            label: 'Standing',
            value: isVerified ? 'Verified' : 'Unverified',
          ),
        ],
      ),
    ];
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
