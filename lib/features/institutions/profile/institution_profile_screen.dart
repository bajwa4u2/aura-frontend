import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';

class InstitutionProfileScreen extends ConsumerWidget {
  const InstitutionProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessAsync = ref.watch(institutionAccessProvider);
    final identity = ref.watch(institutionIdentityProvider);

    return AuraScaffold(
      showHeader: false,
      body: accessAsync.when(
        loading: () => const AuraLoadingState(message: 'Loading profile…'),
        error: (e, _) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AuraSpace.s16,
            AuraSpace.s20,
            AuraSpace.s16,
            AuraSpace.s32,
          ),
          children: [
            AuraErrorState(
              title: 'Profile unavailable',
              body: '$e',
              action: AuraSecondaryButton(
                label: 'Try again',
                onPressed: () => ref.invalidate(institutionAccessProvider),
                icon: Icons.refresh_rounded,
              ),
            ),
          ],
        ),
        data: (access) {
          final inst = access.institution ??
              (access.membership?['institution'] is Map
                  ? Map<String, dynamic>.from(
                      access.membership!['institution'] as Map,
                    )
                  : null);

          if (inst == null) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AuraSpace.s16,
                AuraSpace.s20,
                AuraSpace.s16,
                AuraSpace.s32,
              ),
              children: const [
                AuraErrorState(
                  title: 'No institution',
                  body: 'Institution data is not available for this account.',
                ),
              ],
            );
          }

          return _ProfileBody(inst: inst, identity: identity);
        },
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.inst, required this.identity});

  final Map<String, dynamic> inst;
  final InstitutionIdentity? identity;

  String _str(List<String> keys) {
    for (final k in keys) {
      final v = inst[k]?.toString().trim() ?? '';
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  bool _bool(List<String> keys) {
    for (final k in keys) {
      final v = inst[k];
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v != null) {
        final s = v.toString().trim().toLowerCase();
        if (s == 'true' || s == '1') return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final name = _str(['name', 'displayName', 'organizationName']);
    final slug = _str(['slug', 'handle']);
    final domain = _str(['domain']);
    final description = _str(['description', 'bio', 'summary']);
    final tagline = _str(['tagline']);
    final website = _str(['website', 'websiteUrl']);
    final category = _str(['category', 'type', 'institutionType']);
    final location = _str(['location', 'city']);
    final logoUrl = _str(['logoUrl', 'logo']);
    final coverUrl = _str(['coverUrl', 'cover', 'bannerUrl']);
    final isVerified = _bool(['isVerified', 'verified']);
    final domainVerified = _str(['domainVerifiedAt']).isNotEmpty;
    final jurisdiction = _str(['jurisdiction', 'country', 'region']);

    // contact
    final publicEmail = _str(['publicEmail', 'email']);
    final phone = _str(['phone', 'phoneNumber']);
    final address = _str(['address']);
    final city = _str(['city']);
    final region = _str(['region', 'state']);
    final country = _str(['country']);

    // social
    final xUrl = _str(['xUrl', 'twitterUrl', 'twitter']);
    final linkedinUrl = _str(['linkedinUrl', 'linkedin']);
    final facebookUrl = _str(['facebookUrl', 'facebook']);
    final instagramUrl = _str(['instagramUrl', 'instagram']);
    final youtubeUrl = _str(['youtubeUrl', 'youtube']);
    final hasSocial = xUrl.isNotEmpty ||
        linkedinUrl.isNotEmpty ||
        facebookUrl.isNotEmpty ||
        instagramUrl.isNotEmpty ||
        youtubeUrl.isNotEmpty;

    // mission
    final mission = _str(['mission']);
    final services = _str(['services']);
    final audience = _str(['audience']);
    final foundedYearRaw = inst['foundedYear'];
    final foundedYear = foundedYearRaw != null ? foundedYearRaw.toString() : '';

    // contact section visibility
    final hasContact = publicEmail.isNotEmpty ||
        phone.isNotEmpty ||
        address.isNotEmpty ||
        city.isNotEmpty ||
        region.isNotEmpty ||
        country.isNotEmpty;

    // build location line
    final locationParts = <String>[
      if (city.isNotEmpty) city,
      if (region.isNotEmpty) region,
      if (country.isNotEmpty) country,
    ];
    final locationLine = locationParts.isNotEmpty
        ? locationParts.join(', ')
        : location;

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, AuraSpace.s32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover banner
                if (coverUrl.isNotEmpty)
                  _CoverBanner(coverUrl: coverUrl),

                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AuraSpace.s16,
                    AuraSpace.s16,
                    AuraSpace.s16,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InstitutionHeroCard(
                        name: name,
                        slug: slug,
                        tagline: tagline,
                        description: description,
                        isVerified: isVerified,
                        logoUrl: logoUrl.isNotEmpty
                            ? logoUrl
                            : identity?.logoUrl,
                      ),
                      const SizedBox(height: AuraSpace.s14),

                      // STANDING section
                      _InfoSection(
                        title: 'STANDING',
                        rows: [
                          _InfoRow(
                            label: 'Institution',
                            value: isVerified ? 'Verified' : 'Unverified',
                            valueColor: isVerified
                                ? AuraSurface.goodInk
                                : AuraSurface.muted,
                          ),
                          _InfoRow(
                            label: 'Domain DNS',
                            value: domainVerified ? 'Verified' : 'Not verified',
                            valueColor: domainVerified
                                ? AuraSurface.goodInk
                                : AuraSurface.muted,
                          ),
                          if (jurisdiction.isNotEmpty)
                            _InfoRow(
                              label: 'Jurisdiction',
                              value: jurisdiction,
                            ),
                        ],
                      ),
                      const SizedBox(height: AuraSpace.s14),

                      // IDENTITY section
                      _InfoSection(
                        title: 'IDENTITY',
                        rows: [
                          _InfoRow(
                            label: 'Name',
                            value: name.isEmpty ? '—' : name,
                          ),
                          _InfoRow(
                            label: 'Slug',
                            value: slug.isEmpty ? '—' : '@$slug',
                          ),
                          if (category.isNotEmpty)
                            _InfoRow(label: 'Category', value: category),
                          if (locationLine.isNotEmpty)
                            _InfoRow(label: 'Location', value: locationLine),
                          if (domain.isNotEmpty)
                            _InfoRow(label: 'Domain', value: domain),
                          if (website.isNotEmpty)
                            _InfoRow(label: 'Website', value: website, isLink: true),
                          if (foundedYear.isNotEmpty)
                            _InfoRow(label: 'Founded', value: foundedYear),
                        ],
                      ),

                      // CONTACT section
                      if (hasContact) ...[
                        const SizedBox(height: AuraSpace.s14),
                        _InfoSection(
                          title: 'CONTACT',
                          rows: [
                            if (publicEmail.isNotEmpty)
                              _InfoRow(label: 'Email', value: publicEmail),
                            if (phone.isNotEmpty)
                              _InfoRow(label: 'Phone', value: phone),
                            if (address.isNotEmpty)
                              _InfoRow(label: 'Address', value: address),
                            if (locationLine.isNotEmpty && address.isNotEmpty)
                              _InfoRow(label: 'City / Region', value: locationLine),
                          ],
                        ),
                      ],

                      // ABOUT section
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: AuraSpace.s14),
                        _InfoSection(
                          title: 'ABOUT',
                          rows: [
                            _DescriptionRow(text: description),
                          ],
                        ),
                      ],

                      // MISSION section
                      if (mission.isNotEmpty ||
                          services.isNotEmpty ||
                          audience.isNotEmpty) ...[
                        const SizedBox(height: AuraSpace.s14),
                        _InfoSection(
                          title: 'MISSION & REPRESENTATION',
                          rows: [
                            if (mission.isNotEmpty)
                              _LabeledBlock(label: 'Mission', text: mission),
                            if (services.isNotEmpty)
                              _LabeledBlock(label: 'Services', text: services),
                            if (audience.isNotEmpty)
                              _LabeledBlock(
                                label: 'Audience',
                                text: audience,
                              ),
                          ],
                        ),
                      ],

                      // SOCIAL section
                      if (hasSocial) ...[
                        const SizedBox(height: AuraSpace.s14),
                        _InfoSection(
                          title: 'SOCIAL',
                          rows: [
                            if (linkedinUrl.isNotEmpty)
                              _InfoRow(
                                label: 'LinkedIn',
                                value: linkedinUrl,
                                isLink: true,
                              ),
                            if (xUrl.isNotEmpty)
                              _InfoRow(
                                label: 'X / Twitter',
                                value: xUrl,
                                isLink: true,
                              ),
                            if (facebookUrl.isNotEmpty)
                              _InfoRow(
                                label: 'Facebook',
                                value: facebookUrl,
                                isLink: true,
                              ),
                            if (instagramUrl.isNotEmpty)
                              _InfoRow(
                                label: 'Instagram',
                                value: instagramUrl,
                                isLink: true,
                              ),
                            if (youtubeUrl.isNotEmpty)
                              _InfoRow(
                                label: 'YouTube',
                                value: youtubeUrl,
                                isLink: true,
                              ),
                          ],
                        ),
                      ],

                      const SizedBox(height: AuraSpace.s24),
                      _ActionRow(identity: identity),
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

// ── Cover banner ─────────────────────────────────────────────────────────────

class _CoverBanner extends StatelessWidget {
  const _CoverBanner({required this.coverUrl});

  final String coverUrl;

  static const Color _accent = Color(0xFF0D9488);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      width: double.infinity,
      color: _accent.withValues(alpha: 0.12),
      child: Image.network(
        coverUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: _accent.withValues(alpha: 0.12),
          child: const Center(
            child: Icon(
              Icons.image_outlined,
              color: Color(0xFF5EEAD4),
              size: 48,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Hero card ─────────────────────────────────────────────────────────────────

class _InstitutionHeroCard extends StatelessWidget {
  const _InstitutionHeroCard({
    required this.name,
    required this.slug,
    required this.tagline,
    required this.description,
    required this.isVerified,
    this.logoUrl,
  });

  final String name;
  final String slug;
  final String tagline;
  final String description;
  final bool isVerified;
  final String? logoUrl;

  static const Color _accent = Color(0xFF0D9488);
  static const Color _accentSoft = Color(0x1E0D9488);
  static const Color _accentText = Color(0xFF5EEAD4);

  @override
  Widget build(BuildContext context) {
    final displayName = name.isNotEmpty ? name : 'Institution';

    return Container(
      padding: const EdgeInsets.all(AuraSpace.s20),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.xl),
        border: Border.all(color: _accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InstitutionAvatar(
                logoUrl: logoUrl,
                size: 56,
                name: displayName,
              ),
              const SizedBox(width: AuraSpace.s14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(displayName, style: AuraText.title),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: AuraSpace.s8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AuraSpace.s8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AuraSurface.goodBg,
                              borderRadius:
                                  BorderRadius.circular(AuraRadius.pill),
                              border: Border.all(
                                color: AuraSurface.goodInk
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.verified_rounded,
                                  size: 11,
                                  color: AuraSurface.goodInk,
                                ),
                                const SizedBox(width: 3),
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
                    if (slug.isNotEmpty) ...[
                      const SizedBox(height: AuraSpace.s4),
                      Text(
                        '@$slug',
                        style: AuraText.small.copyWith(
                          color: _accentText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (tagline.isNotEmpty) ...[
                      const SizedBox(height: AuraSpace.s6),
                      Text(
                        tagline,
                        style: AuraText.body.copyWith(
                          color: AuraSurface.muted,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    const SizedBox(height: AuraSpace.s6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AuraSpace.s8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _accentSoft,
                        borderRadius: BorderRadius.circular(AuraRadius.pill),
                        border: Border.all(
                          color: _accent.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        'Institution workspace',
                        style: AuraText.micro.copyWith(
                          color: _accentText,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s16),
            Text(
              description,
              style: AuraText.body.copyWith(
                color: AuraSurface.muted,
                height: 1.5,
              ),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Action row ────────────────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.identity});

  final InstitutionIdentity? identity;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AuraSpace.s10,
      runSpacing: AuraSpace.s10,
      children: [
        if (identity != null && identity!.isAdmin)
          AuraPrimaryButton(
            label: 'Edit profile',
            icon: Icons.edit_outlined,
            onPressed: () => context.go('/institution/edit-profile'),
          ),
        if (identity != null &&
            identity!.slug.isNotEmpty &&
            identity!.id.isNotEmpty)
          AuraSecondaryButton(
            label: 'Public preview',
            icon: Icons.open_in_new_rounded,
            // Shell-preserving — keeps the preview inside InstitutionShell.
            onPressed: () => context.push(
              '/institution/${identity!.id}/institutions/${identity!.slug}',
            ),
          ),
        AuraSecondaryButton(
          label: 'Domains',
          icon: Icons.language_rounded,
          onPressed: () => context.go('/institution/domains'),
        ),
      ],
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────

class _InstitutionAvatar extends StatelessWidget {
  const _InstitutionAvatar({
    required this.size,
    required this.name,
    this.logoUrl,
  });

  final double size;
  final String name;
  final String? logoUrl;

  static const Color _accent = Color(0xFF0D9488);
  static const Color _accentSoft = Color(0x1E0D9488);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _accentSoft,
        shape: BoxShape.circle,
        border: Border.all(color: _accent.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: logoUrl != null && logoUrl!.isNotEmpty
          ? Image.network(
              logoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  _FallbackIcon(size: size, name: name),
            )
          : _FallbackIcon(size: size, name: name),
    );
  }
}

class _FallbackIcon extends StatelessWidget {
  const _FallbackIcon({required this.size, required this.name});

  final double size;
  final String name;

  static const Color _accentText = Color(0xFF5EEAD4);

  @override
  Widget build(BuildContext context) {
    if (name.isNotEmpty) {
      return Center(
        child: Text(
          name[0].toUpperCase(),
          style: TextStyle(
            color: _accentText,
            fontSize: size * 0.38,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return Icon(
      Icons.apartment_outlined,
      size: size * 0.45,
      color: _accentText,
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.title, required this.rows});

  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
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
            style: AuraText.micro.copyWith(
              color: AuraSurface.faint,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
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
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isLink = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool isLink;

  static const Color _linkColor = Color(0xFF5EEAD4);

  @override
  Widget build(BuildContext context) {
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
            value.isEmpty ? '—' : value,
            style: AuraText.small.copyWith(
              color: isLink
                  ? _linkColor
                  : (valueColor ?? AuraSurface.ink),
              decoration:
                  isLink ? TextDecoration.underline : TextDecoration.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _LabeledBlock extends StatelessWidget {
  const _LabeledBlock({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AuraText.small.copyWith(
            fontWeight: FontWeight.w700,
            color: AuraSurface.muted,
          ),
        ),
        const SizedBox(height: AuraSpace.s4),
        Text(
          text,
          style: AuraText.body.copyWith(
            color: AuraSurface.ink,
            height: 1.55,
          ),
        ),
      ],
    );
  }
}

class _DescriptionRow extends StatelessWidget {
  const _DescriptionRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AuraText.body.copyWith(
        color: AuraSurface.muted,
        height: 1.55,
      ),
    );
  }
}
