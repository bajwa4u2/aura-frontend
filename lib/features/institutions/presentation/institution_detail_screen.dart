import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/institutions_repository.dart';
import '../domain/institution.dart';

final institutionDetailProvider =
    FutureProvider.family<Institution, String>((ref, slug) async {
  final repo = ref.watch(institutionsRepositoryProvider);
  return repo.getBySlug(slug);
});

class InstitutionDetailScreen extends ConsumerWidget {
  const InstitutionDetailScreen({
    super.key,
    required this.slug,
  });

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cleanSlug = slug.trim();
    final institutionAsync = ref.watch(institutionDetailProvider(cleanSlug));

    return AuraScaffold(
      title: 'Institution',
      body: institutionAsync.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (e, _) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AuraSpace.s16,
            AuraSpace.s12,
            AuraSpace.s16,
            AuraSpace.s24,
          ),
          children: [
            AuraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Institution could not be loaded.',
                    style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AuraSpace.s10),
                  Text(
                    '$e',
                    style: AuraText.body,
                  ),
                ],
              ),
            ),
          ],
        ),
        data: (institution) {
          final title = institution.name.trim().isNotEmpty
              ? institution.name.trim()
              : 'Institution';

          final subtitleParts = <String>[
            if (institution.slug.trim().isNotEmpty) institution.slug.trim(),
            if (institution.domain.trim().isNotEmpty) institution.domain.trim(),
          ];

          final metaParts = <String>[
            if (institution.jurisdiction.trim().isNotEmpty)
              institution.jurisdiction.trim(),
            institution.isVerified ? 'Verified standing' : 'Standing not verified',
          ];

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.s16,
              AuraSpace.s12,
              AuraSpace.s16,
              AuraSpace.s24,
            ),
            children: [
              AuraCard(
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
                            border: Border.all(color: AuraSurface.divider),
                          ),
                          child: const Icon(Icons.apartment_outlined),
                        ),
                        const SizedBox(width: AuraSpace.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: AuraText.title),
                              if (subtitleParts.isNotEmpty) ...[
                                const SizedBox(height: AuraSpace.s6),
                                Text(
                                  subtitleParts.join(' • '),
                                  style: AuraText.muted,
                                ),
                              ],
                              const SizedBox(height: AuraSpace.s8),
                              Text(
                                metaParts.join(' • '),
                                style: AuraText.small,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AuraSpace.s14),
                    Text(
                      'Public institutional record inside Aura.',
                      style: AuraText.small.copyWith(
                        color: AuraSurface.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AuraSpace.s14),
              AuraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Standing',
                      style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AuraSpace.s10),
                    _StatusRow(
                      label: 'Verification',
                      value: institution.isVerified ? 'Verified' : 'Not verified',
                    ),
                    _StatusRow(
                      label: 'Jurisdiction',
                      value: institution.jurisdiction,
                    ),
                    _StatusRow(
                      label: 'Domain',
                      value: institution.domain,
                      isLast: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AuraSpace.s14),
              AuraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'About',
                      style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AuraSpace.s10),
                    Text(
                      institution.description.trim().isEmpty
                          ? 'No public description has been added yet.'
                          : institution.description.trim(),
                      style: AuraText.body,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AuraSpace.s14),
              AuraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Institution details',
                      style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AuraSpace.s12),
                    _DetailRow(label: 'Name', value: institution.name),
                    _DetailRow(label: 'Slug', value: institution.slug),
                    _DetailRow(label: 'Domain', value: institution.domain),
                    _DetailRow(
                      label: 'Jurisdiction',
                      value: institution.jurisdiction,
                    ),
                    _DetailRow(label: 'Website', value: institution.website),
                    _DetailRow(
                      label: 'Standing',
                      value: institution.isVerified ? 'Verified' : 'Unverified',
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final cleanValue = value.trim().isEmpty ? '—' : value.trim();

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : AuraSpace.s10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: AuraText.small.copyWith(
                fontWeight: FontWeight.w700,
                color: AuraSurface.muted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              cleanValue,
              style: AuraText.body,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final cleanValue = value.trim().isEmpty ? '—' : value.trim();

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : AuraSpace.s10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AuraText.small.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AuraSpace.s4),
          Text(
            cleanValue,
            style: AuraText.body,
          ),
        ],
      ),
    );
  }
}
