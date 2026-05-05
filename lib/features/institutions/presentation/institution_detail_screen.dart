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

class _InstitutionDetailBody extends StatelessWidget {
  const _InstitutionDetailBody({required this.institution});

  final Institution institution;

  @override
  Widget build(BuildContext context) {
    final coverUrl = institution.coverUrl?.trim() ?? '';

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (coverUrl.isNotEmpty) _PublicCoverBanner(coverUrl: coverUrl),
                Padding(
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
              ],
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
    final logoUrl = institution.logoUrl?.trim() ?? '';

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
                _PublicInstitutionAvatar(
                  size: 52,
                  name: title,
                  logoUrl: logoUrl,
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
      if (institution.units.isNotEmpty) ...[
        const SizedBox(height: AuraSpace.s14),
        _UnitsSection(
          institutionName: institution.name,
          units: institution.units,
        ),
      ],
    ];
  }
}

// ── Units section ──────────────────────────────────────────────────────────

class _UnitsSection extends StatelessWidget {
  const _UnitsSection({
    required this.institutionName,
    required this.units,
  });

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

// ── Public-shell cover banner ────────────────────────────────────────────────

class _PublicCoverBanner extends StatelessWidget {
  const _PublicCoverBanner({required this.coverUrl});

  final String coverUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      width: double.infinity,
      color: AuraSurface.accentSoft,
      child: Image.network(
        coverUrl,
        fit: BoxFit.cover,
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
        border: Border.all(
          color: AuraSurface.accent.withValues(alpha: 0.3),
        ),
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
