import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../domain/institution_post.dart';
import '../presentation/institution_detail_screen.dart'
    show institutionPublicPostsProvider;

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

class _ProfileBody extends ConsumerWidget {
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

  int? _int(List<String> keys) {
    for (final k in keys) {
      final v = inst[k];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String && v.isNotEmpty) {
        final parsed = int.tryParse(v);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  String _publicLink(String slug) {
    if (slug.isEmpty) return '';
    final base = Uri.base;
    if (base.scheme.startsWith('http')) {
      return '${base.origin}/institutions/$slug';
    }
    return '/institutions/$slug';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    final memberCount = _int(['memberCount', 'membersCount', 'memberTotal']);
    final resolvedLogo = logoUrl.isNotEmpty ? logoUrl : identity?.logoUrl;
    final publicLink = _publicLink(slug);

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, AuraSpace.s32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeroCover(
                  coverUrl: coverUrl,
                  logoUrl: resolvedLogo,
                  name: name.isEmpty ? 'Institution' : name,
                ),
                const SizedBox(height: AuraSpace.s12),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AuraSpace.s16,
                    0,
                    AuraSpace.s16,
                    0,
                  ),
                  child: _HeroIdentity(
                    name: name,
                    slug: slug,
                    tagline: tagline,
                    description: description,
                    isVerified: isVerified,
                  ),
                ),
                const SizedBox(height: AuraSpace.s14),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AuraSpace.s16,
                  ),
                  child: _WorkspaceActionRow(
                    identity: identity,
                    publicLink: publicLink,
                  ),
                ),
                const SizedBox(height: AuraSpace.s14),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AuraSpace.s16,
                  ),
                  child: _StatChips(
                    isVerified: isVerified,
                    domainVerified: domainVerified,
                    memberCount: memberCount,
                    foundedYear: foundedYear,
                    jurisdiction: jurisdiction,
                  ),
                ),
                const SizedBox(height: AuraSpace.s14),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AuraSpace.s16,
                    0,
                    AuraSpace.s16,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (description.isNotEmpty) ...[
                        _InfoSection(
                          title: 'ABOUT',
                          rows: [
                            _DescriptionRow(text: description),
                          ],
                        ),
                        const SizedBox(height: AuraSpace.s14),
                      ],
                      if (mission.isNotEmpty ||
                          services.isNotEmpty ||
                          audience.isNotEmpty) ...[
                        _InfoSection(
                          title: 'MISSION & REPRESENTATION',
                          rows: [
                            if (mission.isNotEmpty)
                              _LabeledBlock(label: 'Mission', text: mission),
                            if (services.isNotEmpty)
                              _LabeledBlock(
                                label: 'Services',
                                text: services,
                              ),
                            if (audience.isNotEmpty)
                              _LabeledBlock(
                                label: 'Audience',
                                text: audience,
                              ),
                          ],
                        ),
                        const SizedBox(height: AuraSpace.s14),
                      ],
                      if (hasContact ||
                          website.isNotEmpty ||
                          locationLine.isNotEmpty) ...[
                        _InfoSection(
                          title: 'CONTACT',
                          rows: [
                            if (publicEmail.isNotEmpty)
                              _InfoRow(label: 'Email', value: publicEmail),
                            if (phone.isNotEmpty)
                              _InfoRow(label: 'Phone', value: phone),
                            if (website.isNotEmpty)
                              _InfoRow(
                                label: 'Website',
                                value: website,
                                isLink: true,
                              ),
                            if (address.isNotEmpty)
                              _InfoRow(label: 'Address', value: address),
                            if (locationLine.isNotEmpty)
                              _InfoRow(label: 'Location', value: locationLine),
                          ],
                        ),
                        const SizedBox(height: AuraSpace.s14),
                      ],
                      _InfoSection(
                        title: 'DOMAINS & VERIFICATION',
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
                            value: domainVerified
                                ? 'Verified'
                                : 'Not verified',
                            valueColor: domainVerified
                                ? AuraSurface.goodInk
                                : AuraSurface.muted,
                          ),
                          if (domain.isNotEmpty)
                            _InfoRow(label: 'Domain', value: domain),
                          if (jurisdiction.isNotEmpty)
                            _InfoRow(
                              label: 'Jurisdiction',
                              value: jurisdiction,
                            ),
                          if (category.isNotEmpty)
                            _InfoRow(label: 'Category', value: category),
                        ],
                      ),
                      const SizedBox(height: AuraSpace.s14),
                      if (hasSocial) ...[
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
                        const SizedBox(height: AuraSpace.s14),
                      ],
                      if (slug.isNotEmpty)
                        _PublicPostsPreview(
                          slug: slug,
                          institutionId: identity?.id ?? '',
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

// ── Hero cover (cover + avatar overlap) ──────────────────────────────────────

class _HeroCover extends StatelessWidget {
  const _HeroCover({
    required this.coverUrl,
    required this.logoUrl,
    required this.name,
  });

  final String coverUrl;
  final String? logoUrl;
  final String name;

  static const Color _accent = Color(0xFF0D9488);
  static const Color _accentText = Color(0xFF5EEAD4);

  @override
  Widget build(BuildContext context) {
    const double coverHeight = 220;
    const double avatarSize = 96;
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
                    _accent.withValues(alpha: 0.30),
                    _accent.withValues(alpha: 0.08),
                    AuraSurface.subtle,
                  ],
                ),
              ),
              child: coverUrl.isEmpty
                  ? const Center(
                      child: Icon(
                        Icons.apartment_rounded,
                        size: 56,
                        color: _accentText,
                      ),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          coverUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: _accent.withValues(alpha: 0.12),
                            child: const Center(
                              child: Icon(
                                Icons.image_outlined,
                                color: _accentText,
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
              child: _InstitutionAvatar(
                logoUrl: logoUrl,
                size: avatarSize,
                name: name,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero identity (name / slug / verified / workspace badge / tagline) ──────

class _HeroIdentity extends StatelessWidget {
  const _HeroIdentity({
    required this.name,
    required this.slug,
    required this.tagline,
    required this.description,
    required this.isVerified,
  });

  final String name;
  final String slug;
  final String tagline;
  final String description;
  final bool isVerified;

  static const Color _accent = Color(0xFF0D9488);
  static const Color _accentSoft = Color(0x1E0D9488);
  static const Color _accentText = Color(0xFF5EEAD4);

  @override
  Widget build(BuildContext context) {
    final displayName = name.isNotEmpty ? name : 'Institution';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AuraSpace.s8,
          runSpacing: AuraSpace.s6,
          children: [
            Text(displayName, style: AuraText.title),
            if (isVerified)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpace.s8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AuraSurface.goodBg,
                  borderRadius: BorderRadius.circular(AuraRadius.pill),
                  border: Border.all(
                    color: AuraSurface.goodInk.withValues(alpha: 0.3),
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
                    const SizedBox(width: 4),
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
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AuraSpace.s8,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: _accentSoft,
                borderRadius: BorderRadius.circular(AuraRadius.pill),
                border: Border.all(color: _accent.withValues(alpha: 0.35)),
              ),
              child: Text(
                'Workspace',
                style: AuraText.micro.copyWith(
                  color: _accentText,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
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
          const SizedBox(height: AuraSpace.s8),
          Text(
            tagline,
            style: AuraText.body.copyWith(
              color: AuraSurface.muted,
              fontStyle: FontStyle.italic,
              height: 1.45,
            ),
          ),
        ],
      ],
    );
  }
}

// ── Action row ────────────────────────────────────────────────────────────────

class _WorkspaceActionRow extends StatelessWidget {
  const _WorkspaceActionRow({
    required this.identity,
    required this.publicLink,
  });

  final InstitutionIdentity? identity;
  final String publicLink;

  Future<void> _copyLink(BuildContext context) async {
    if (publicLink.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: publicLink));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Public link copied')),
    );
  }

  Future<void> _share(BuildContext context) async {
    if (publicLink.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: publicLink));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Public link copied — paste anywhere to share'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = identity != null && identity!.isAdmin;
    final canPreview = identity != null &&
        identity!.slug.isNotEmpty &&
        identity!.id.isNotEmpty;

    return Wrap(
      spacing: AuraSpace.s10,
      runSpacing: AuraSpace.s10,
      children: [
        if (canEdit)
          AuraPrimaryButton(
            label: 'Edit profile',
            icon: Icons.edit_outlined,
            onPressed: () => context.go('/institution/edit-profile'),
          ),
        if (canPreview)
          AuraSecondaryButton(
            label: 'Public preview',
            icon: Icons.visibility_outlined,
            onPressed: () => context.push(
              '/institution/${identity!.id}/institutions/${identity!.slug}',
            ),
          ),
        if (publicLink.isNotEmpty)
          AuraSecondaryButton(
            label: 'Copy public link',
            icon: Icons.link_rounded,
            onPressed: () => _copyLink(context),
          ),
        if (publicLink.isNotEmpty)
          AuraSecondaryButton(
            label: 'Share',
            icon: Icons.ios_share_rounded,
            onPressed: () => _share(context),
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

// ── Stat chips ───────────────────────────────────────────────────────────────

class _StatChips extends StatelessWidget {
  const _StatChips({
    required this.isVerified,
    required this.domainVerified,
    required this.memberCount,
    required this.foundedYear,
    required this.jurisdiction,
  });

  final bool isVerified;
  final bool domainVerified;
  final int? memberCount;
  final String foundedYear;
  final String jurisdiction;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      _StatChip(
        icon: Icons.verified_rounded,
        label: isVerified ? 'Verified' : 'Unverified',
        good: isVerified,
      ),
      _StatChip(
        icon: Icons.dns_rounded,
        label: domainVerified ? 'Domain DNS verified' : 'Domain unverified',
        good: domainVerified,
      ),
      if (memberCount != null)
        _StatChip(
          icon: Icons.groups_2_rounded,
          label: '${memberCount!} '
              '${memberCount == 1 ? 'member' : 'members'}',
        ),
      if (foundedYear.isNotEmpty)
        _StatChip(
          icon: Icons.flag_rounded,
          label: 'Founded $foundedYear',
        ),
      if (jurisdiction.isNotEmpty)
        _StatChip(
          icon: Icons.public_rounded,
          label: jurisdiction,
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: AuraSpace.s8,
      runSpacing: AuraSpace.s8,
      children: chips,
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    this.good = false,
  });

  final IconData icon;
  final String label;
  final bool good;

  @override
  Widget build(BuildContext context) {
    final fg = good ? AuraSurface.goodInk : AuraSurface.muted;
    final bg = good ? AuraSurface.goodBg : AuraSurface.subtle;
    final border = good
        ? AuraSurface.goodInk.withValues(alpha: 0.3)
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

// ── Public posts preview ─────────────────────────────────────────────────────

class _PublicPostsPreview extends ConsumerWidget {
  const _PublicPostsPreview({
    required this.slug,
    required this.institutionId,
  });

  final String slug;
  final String institutionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (institutionId.isEmpty) return const SizedBox.shrink();
    final async = ref.watch(institutionPublicPostsProvider(institutionId));
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
          Row(
            children: [
              Expanded(
                child: Text(
                  'PUBLIC POSTS',
                  style: AuraText.micro.copyWith(
                    color: AuraSurface.faint,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              if (institutionId.isNotEmpty && slug.isNotEmpty)
                TextButton.icon(
                  onPressed: () => context.push(
                    '/institution/$institutionId/institutions/$slug',
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: const Text('View public profile'),
                ),
            ],
          ),
          const SizedBox(height: AuraSpace.s10),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AuraSpace.s14),
              child: AuraLoadingState(message: 'Loading posts…'),
            ),
            error: (e, _) => Text(
              'Could not load posts: $e',
              style: AuraText.small.copyWith(color: AuraSurface.muted),
            ),
            data: (posts) {
              if (posts.isEmpty) {
                return Text(
                  'No public posts yet. Posts you publish to the institution feed will appear here.',
                  style: AuraText.small.copyWith(color: AuraSurface.muted),
                );
              }
              final preview = posts.take(3).toList();
              return Column(
                children: [
                  for (var i = 0; i < preview.length; i++) ...[
                    _PostPreviewTile(post: preview[i]),
                    if (i < preview.length - 1)
                      const Divider(
                        height: AuraSpace.s12,
                        color: AuraSurface.divider,
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

class _PostPreviewTile extends StatelessWidget {
  const _PostPreviewTile({required this.post});

  final InstitutionPost post;

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final yyyy = local.year.toString().padLeft(4, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }

  @override
  Widget build(BuildContext context) {
    final title = post.title.trim();
    final body = post.body.trim();
    final preview = body.length > 220 ? '${body.substring(0, 220)}…' : body;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (title.isNotEmpty)
                Expanded(
                  child: Text(
                    title,
                    style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (post.publishedAt != null)
                Text(
                  _formatDate(post.publishedAt!),
                  style: AuraText.micro.copyWith(color: AuraSurface.faint),
                ),
            ],
          ),
          if (preview.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              preview,
              style: AuraText.small.copyWith(
                color: AuraSurface.muted,
                height: 1.5,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
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
