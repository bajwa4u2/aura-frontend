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
import '../../feed/data/unified_feed_providers.dart';
import '../../feed/presentation/unified_feed_card.dart';
import '../ui/institution_ds.dart';

/// Phase 6.6c — Institution Profile / Workspace Identity hub.
///
/// Layout:
///   1. `InsCoverHeader` — cover band, overlapping avatar, identity row
///      (name / handle / badges / tagline / facts).
///   2. `InsActionGroup` — primary "Edit profile" + secondary cluster
///      (Public preview · Copy public link · Share · Domains).
///   3. Section cards — About / Mission & representation / Contact /
///      Domains & verification / Social. Each composed on `InsSection` +
///      `InsCard`. Sections collapse cleanly when their data isn't set.
///   4. Public posts preview — last three posts, framed as a section so it
///      reads as part of the same hub.
///
/// Data + behaviour parity with the prior screen: same `/institutions/me`
/// pull, same copy/share callbacks, same routing.
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
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(InsSpacing.screenHPad),
          child: AuraErrorState(
            title: 'Profile unavailable',
            body: '$e',
            action: AuraSecondaryButton(
              label: 'Try again',
              onPressed: () => ref.invalidate(institutionAccessProvider),
              icon: Icons.refresh_rounded,
            ),
          ),
        ),
        data: (access) {
          final inst = access.institution ??
              (access.membership?['institution'] is Map
                  ? Map<String, dynamic>.from(
                      access.membership!['institution'] as Map,
                    )
                  : null);

          if (inst == null) {
            return const Padding(
              padding: EdgeInsets.all(InsSpacing.screenHPad),
              child: AuraErrorState(
                title: 'No institution',
                body: 'Institution data is not available for this account.',
              ),
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
    // ── Pull data ────────────────────────────────────────────────────────
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

    final publicEmail = _str(['publicEmail', 'email']);
    final phone = _str(['phone', 'phoneNumber']);
    final address = _str(['address']);
    final city = _str(['city']);
    final region = _str(['region', 'state']);
    final country = _str(['country']);

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

    final mission = _str(['mission']);
    final services = _str(['services']);
    final audience = _str(['audience']);
    final foundedYearRaw = inst['foundedYear'];
    final foundedYear = foundedYearRaw != null ? foundedYearRaw.toString() : '';

    final hasContact = publicEmail.isNotEmpty ||
        phone.isNotEmpty ||
        website.isNotEmpty ||
        address.isNotEmpty ||
        city.isNotEmpty ||
        region.isNotEmpty ||
        country.isNotEmpty;

    final locationParts = <String>[
      if (city.isNotEmpty) city,
      if (region.isNotEmpty) region,
      if (country.isNotEmpty) country,
    ];
    final locationLine = locationParts.isNotEmpty
        ? locationParts.join(', ')
        : location;

    final memberCount = _int(['memberCount', 'membersCount', 'memberTotal']);
    final resolvedLogo =
        logoUrl.isNotEmpty ? logoUrl : (identity?.logoUrl ?? '');
    final publicLink = _publicLink(slug);

    // ── Identity badges (tone-driven, no rainbow) ────────────────────────
    final badges = <Widget>[
      if (isVerified)
        const InsBadge(
          label: 'VERIFIED',
          tone: InsTone.ok,
          icon: Icons.verified_rounded,
        )
      else
        const InsBadge(
          label: 'UNVERIFIED',
          tone: InsTone.neutral,
          icon: Icons.help_outline_rounded,
        ),
      const InsBadge(
        label: 'WORKSPACE',
        tone: InsTone.info,
        icon: Icons.apartment_rounded,
      ),
      if (domainVerified)
        const InsBadge(
          label: 'DOMAIN VERIFIED',
          tone: InsTone.ok,
          icon: Icons.dns_rounded,
        ),
    ];

    // ── Identity facts (calm, replaces noisy chip wrap) ──────────────────
    final facts = <InsFact>[
      if (memberCount != null && memberCount > 0)
        InsFact(
          icon: Icons.people_outline_rounded,
          text: '$memberCount '
              '${memberCount == 1 ? 'member' : 'members'}',
        ),
      if (locationLine.isNotEmpty)
        InsFact(icon: Icons.place_outlined, text: locationLine),
      if (category.isNotEmpty)
        InsFact(icon: Icons.workspaces_outlined, text: category),
      if (foundedYear.isNotEmpty)
        InsFact(
          icon: Icons.event_available_outlined,
          text: 'Founded $foundedYear',
        ),
      if (jurisdiction.isNotEmpty)
        InsFact(icon: Icons.public_rounded, text: jurisdiction),
    ];

    // ── Compose ──────────────────────────────────────────────────────────
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, AuraSpace.s12, 0, AuraSpace.s32),
      children: [
        InsCoverHeader(
          name: name,
          handle: slug.isEmpty ? null : 'institutions/$slug',
          tagline: tagline.isEmpty ? null : tagline,
          logoUrl: resolvedLogo.isEmpty ? null : resolvedLogo,
          coverUrl: coverUrl.isEmpty ? null : coverUrl,
          badges: badges,
          facts: facts,
        ),
        const SizedBox(height: AuraSpace.s20),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: InsSpacing.contentMaxWidth,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: InsSpacing.screenHPad,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Mode header ──────────────────────────────────────
                  InsModeHeader(
                    title: 'Profile',
                    description:
                        'Identity, mission, and trust signals that members and the public see.',
                    primaryAction:
                        (identity != null && identity!.isAdmin)
                            ? AuraPrimaryButton(
                                label: 'Edit profile',
                                icon: Icons.edit_outlined,
                                onPressed: () =>
                                    context.go('/institution/edit-profile'),
                              )
                            : null,
                  ),

                  const InsModeHeaderGap(),

                  // ── Action group ─────────────────────────────────────
                  _ActionGroup(
                    identity: identity,
                    publicLink: publicLink,
                  ),

                  const InsSectionGap(),

                  // ── About ────────────────────────────────────────────
                  if (description.isNotEmpty) ...[
                    InsSection(
                      eyebrow: 'About',
                      title: 'What this institution is',
                      child: InsCard(
                        child: Text(
                          description,
                          style: AuraText.body.copyWith(
                            color: AuraSurface.ink,
                            height: 1.7,
                          ),
                        ),
                      ),
                    ),
                    const InsSectionGap(),
                  ],

                  // ── Mission & representation ─────────────────────────
                  if (mission.isNotEmpty ||
                      services.isNotEmpty ||
                      audience.isNotEmpty) ...[
                    InsSection(
                      eyebrow: 'Representation',
                      title: 'Mission, services, audience',
                      child: InsCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (mission.isNotEmpty)
                              _LabeledBlock(label: 'Mission', text: mission),
                            if (services.isNotEmpty)
                              _LabeledBlock(label: 'Services', text: services),
                            if (audience.isNotEmpty)
                              _LabeledBlock(
                                label: 'Audience',
                                text: audience,
                                isLast: true,
                              ),
                          ],
                        ),
                      ),
                    ),
                    const InsSectionGap(),
                  ],

                  // ── Contact ──────────────────────────────────────────
                  if (hasContact || locationLine.isNotEmpty) ...[
                    InsSection(
                      eyebrow: 'Contact',
                      title: 'How to reach this institution',
                      child: InsCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (publicEmail.isNotEmpty)
                              _KeyValue(label: 'Email', value: publicEmail),
                            if (phone.isNotEmpty)
                              _KeyValue(label: 'Phone', value: phone),
                            if (website.isNotEmpty)
                              _KeyValue(
                                label: 'Website',
                                value: website,
                                isLink: true,
                              ),
                            if (address.isNotEmpty)
                              _KeyValue(label: 'Address', value: address),
                            if (locationLine.isNotEmpty)
                              _KeyValue(label: 'Location', value: locationLine),
                          ],
                        ),
                      ),
                    ),
                    const InsSectionGap(),
                  ],

                  // ── Domains & verification ───────────────────────────
                  InsSection(
                    eyebrow: 'Trust',
                    title: 'Domains & verification',
                    child: InsCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _KeyValue(
                            label: 'Institution',
                            value: isVerified ? 'Verified' : 'Unverified',
                            valueColor: isVerified
                                ? AuraSurface.goodInk
                                : AuraSurface.muted,
                          ),
                          _KeyValue(
                            label: 'Domain DNS',
                            value: domainVerified
                                ? 'Verified'
                                : 'Not verified',
                            valueColor: domainVerified
                                ? AuraSurface.goodInk
                                : AuraSurface.muted,
                          ),
                          if (domain.isNotEmpty)
                            _KeyValue(label: 'Domain', value: domain),
                          if (jurisdiction.isNotEmpty)
                            _KeyValue(
                              label: 'Jurisdiction',
                              value: jurisdiction,
                            ),
                          if (category.isNotEmpty)
                            _KeyValue(
                              label: 'Category',
                              value: category,
                            ),
                        ],
                      ),
                    ),
                  ),

                  if (hasSocial) ...[
                    const InsSectionGap(),
                    InsSection(
                      eyebrow: 'Social',
                      title: 'Where this institution lives elsewhere',
                      child: InsCard(
                        child: _SocialList(
                          linkedinUrl: linkedinUrl,
                          xUrl: xUrl,
                          facebookUrl: facebookUrl,
                          instagramUrl: instagramUrl,
                          youtubeUrl: youtubeUrl,
                        ),
                      ),
                    ),
                  ],

                  if (slug.isNotEmpty &&
                      identity?.id != null &&
                      identity!.id.isNotEmpty) ...[
                    const InsSectionGap(),
                    InsSection(
                      eyebrow: 'Public',
                      title: 'Recent public posts',
                      trailing: AuraGhostButton(
                        label: 'Open public profile',
                        icon: Icons.open_in_new_rounded,
                        onPressed: () => context.push(
                          '/institution/${identity!.id}/institutions/$slug',
                        ),
                      ),
                      child: _PublicPostsPreview(
                        institutionId: identity!.id,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action group — primary Edit + secondary cluster
// ─────────────────────────────────────────────────────────────────────────────

class _ActionGroup extends StatelessWidget {
  const _ActionGroup({required this.identity, required this.publicLink});

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

    // Primary "Edit profile" lives in the Mode Header above; this row
    // carries only secondary actions so the workspace stays consistent.
    return InsActionGroup(
      secondary: [
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
            label: 'Copy link',
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
        // Surface billing only for institution admins/owners. Backend
        // enforces the same on POST /v1/monetization/checkout/*.
        if (canEdit && (identity?.id.isNotEmpty ?? false))
          AuraSecondaryButton(
            label: 'Manage billing',
            icon: Icons.receipt_long_rounded,
            onPressed: () => context.go(
              '/institution/${identity!.id}/billing',
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Content atoms — calm key/value, labeled block, social anchors
// ─────────────────────────────────────────────────────────────────────────────

class _KeyValue extends StatelessWidget {
  const _KeyValue({
    required this.label,
    required this.value,
    this.valueColor,
    this.isLink = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool isLink;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stack = constraints.maxWidth < 440;
          final labelW = AuraText.small.copyWith(
            color: AuraSurface.faint,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          );
          final valueW = AuraText.body.copyWith(
            color: isLink
                ? AuraSurface.accentText
                : (valueColor ?? AuraSurface.ink),
            decoration: isLink ? TextDecoration.underline : TextDecoration.none,
            height: 1.5,
          );
          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: labelW),
                const SizedBox(height: 2),
                Text(value.isEmpty ? '—' : value, style: valueW),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 130,
                child: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(label.toUpperCase(), style: labelW),
                ),
              ),
              Expanded(
                child: Text(value.isEmpty ? '—' : value, style: valueW),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LabeledBlock extends StatelessWidget {
  const _LabeledBlock({
    required this.label,
    required this.text,
    this.isLast = false,
  });

  final String label;
  final String text;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : AuraSpace.s14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AuraText.micro.copyWith(
              color: AuraSurface.faint,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: AuraText.body.copyWith(
              color: AuraSurface.ink,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialList extends StatelessWidget {
  const _SocialList({
    required this.linkedinUrl,
    required this.xUrl,
    required this.facebookUrl,
    required this.instagramUrl,
    required this.youtubeUrl,
  });

  final String linkedinUrl;
  final String xUrl;
  final String facebookUrl;
  final String instagramUrl;
  final String youtubeUrl;

  @override
  Widget build(BuildContext context) {
    final entries = <_SocialAnchor>[
      if (linkedinUrl.isNotEmpty)
        _SocialAnchor(
          label: 'LinkedIn',
          url: linkedinUrl,
          icon: Icons.business_center_outlined,
        ),
      if (xUrl.isNotEmpty)
        _SocialAnchor(
          label: 'X',
          url: xUrl,
          icon: Icons.alternate_email_rounded,
        ),
      if (facebookUrl.isNotEmpty)
        _SocialAnchor(
          label: 'Facebook',
          url: facebookUrl,
          icon: Icons.facebook_rounded,
        ),
      if (instagramUrl.isNotEmpty)
        _SocialAnchor(
          label: 'Instagram',
          url: instagramUrl,
          icon: Icons.camera_alt_outlined,
        ),
      if (youtubeUrl.isNotEmpty)
        _SocialAnchor(
          label: 'YouTube',
          url: youtubeUrl,
          icon: Icons.play_circle_outline_rounded,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          _SocialRow(entry: entries[i]),
          if (i < entries.length - 1)
            const Divider(height: 1, color: AuraSurface.divider),
        ],
      ],
    );
  }
}

class _SocialAnchor {
  const _SocialAnchor({
    required this.label,
    required this.url,
    required this.icon,
  });
  final String label;
  final String url;
  final IconData icon;
}

class _SocialRow extends StatelessWidget {
  const _SocialRow({required this.entry});

  final _SocialAnchor entry;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: entry.url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${entry.label} link copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AuraRadius.md),
      onTap: () => _copy(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AuraSpace.s10),
        child: Row(
          children: [
            Icon(entry.icon, size: 16, color: AuraSurface.muted),
            const SizedBox(width: AuraSpace.s10),
            SizedBox(
              width: 100,
              child: Text(
                entry.label,
                style: AuraText.small.copyWith(
                  color: AuraSurface.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Text(
                entry.url,
                style: AuraText.small.copyWith(
                  color: AuraSurface.accentText,
                  decoration: TextDecoration.underline,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AuraSpace.s8),
            const Icon(
              Icons.content_copy_rounded,
              size: 14,
              color: AuraSurface.faint,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Public posts preview — last 3 posts, framed inside an InsCard
// ─────────────────────────────────────────────────────────────────────────────

class _PublicPostsPreview extends ConsumerWidget {
  const _PublicPostsPreview({required this.institutionId});

  final String institutionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(institutionProfileFeedProvider(institutionId));
    return InsCard(
      child: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: AuraSpace.s16),
          child: AuraLoadingState(message: 'Loading posts…'),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.symmetric(vertical: AuraSpace.s10),
          child: Text(
            'Could not load posts: $e',
            style: AuraText.small.copyWith(color: AuraSurface.muted),
          ),
        ),
        data: (page) {
          if (page.items.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AuraSpace.s10),
              child: Text(
                'No public posts yet. Posts you publish to the institution feed will appear here.',
                style: AuraText.small.copyWith(color: AuraSurface.muted),
              ),
            );
          }
          final preview = page.items.take(3).toList();
          return Column(
            children: [
              for (var i = 0; i < preview.length; i++) ...[
                UnifiedFeedCard(item: preview[i]),
                if (i < preview.length - 1)
                  const SizedBox(height: AuraSpace.s10),
              ],
            ],
          );
        },
      ),
    );
  }
}
