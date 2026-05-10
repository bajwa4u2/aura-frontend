import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/admin_access_provider.dart';
import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/media/canonical_media_thumb.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../feed/domain/feed_media.dart';
import '../domain/announcement.dart';
import '../providers.dart';

class AnnouncementsScreen extends ConsumerWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Display-only admin signal — never triggers a probe from
    // /announcements. A user who has not been confirmed as admin sees
    // the public/member announcements view; if they actually are an
    // unconfirmed admin, opening /admin once will populate the cache and
    // a re-visit will pick up the admin variant.
    final isAdmin = ref.watch(appAdminCachedDisplayProvider);
    final institutionAsync = ref.watch(institutionAccessProvider);
    final pinnedAsync = ref.watch(pinnedAnnouncementsProvider);
    final listAsync = ref.watch(announcementsProvider);

    if (isAdmin) {
      return _AdminAnnouncementsScreen(
        pinnedAsync: pinnedAsync,
        listAsync: listAsync,
      );
    }

    return institutionAsync.when(
          loading: () => AuraScaffold(
            showHeader: false,
            body: const Center(
              child: AuraLoadingState(message: 'Loading announcements…'),
            ),
          ),
          error: (_, __) {
            return _PublicAnnouncementsScreen(
              pinnedAsync: pinnedAsync,
              listAsync: listAsync,
            );
          },
          data: (institutionAccess) {
            final hasInstitutionStanding =
                institutionAccess.state == InstitutionAccessState.pending ||
                institutionAccess.state ==
                    InstitutionAccessState.verifiedMember ||
                institutionAccess.state ==
                    InstitutionAccessState.authorizedSpeaker;

            if (hasInstitutionStanding) {
              return _InstitutionAnnouncementsScreen(
                access: institutionAccess,
                pinnedAsync: pinnedAsync,
                listAsync: listAsync,
              );
            }

            return _PublicAnnouncementsScreen(
              pinnedAsync: pinnedAsync,
              listAsync: listAsync,
            );
          },
        );
  }
}

// ── Shared header ──────────────────────────────────────────────────────────

class _AnnouncementsHeader extends StatelessWidget {
  const _AnnouncementsHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AuraText.headline),
        const SizedBox(height: AuraSpace.s6),
        Text(
          subtitle,
          style: AuraText.body.copyWith(color: AuraSurface.muted, height: 1.5),
        ),
      ],
    );
  }
}

// ── Public screen ──────────────────────────────────────────────────────────

class _PublicAnnouncementsScreen extends StatelessWidget {
  const _PublicAnnouncementsScreen({
    required this.pinnedAsync,
    required this.listAsync,
  });

  final AsyncValue<List<Announcement>> pinnedAsync;
  final AsyncValue<List<Announcement>> listAsync;

  @override
  Widget build(BuildContext context) {
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
          const _AnnouncementsHeader(
            title: 'Announcements',
            subtitle: 'Official platform notices and public communications.',
          ),
          const SizedBox(height: AuraSpace.s24),
          _PinnedSection(asyncValue: pinnedAsync),
          const SizedBox(height: AuraSpace.s12),
          _AllSection(asyncValue: listAsync),
        ],
      ),
    );
  }
}

// ── Admin screen ───────────────────────────────────────────────────────────

class _AdminAnnouncementsScreen extends ConsumerWidget {
  const _AdminAnnouncementsScreen({
    required this.pinnedAsync,
    required this.listAsync,
  });

  final AsyncValue<List<Announcement>> pinnedAsync;
  final AsyncValue<List<Announcement>> listAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          const _AnnouncementsHeader(
            title: 'Admin announcement workspace',
            subtitle:
                'Review pinned notices, the archive, and the live announcement detail paths.',
          ),
          const SizedBox(height: AuraSpace.s24),
          AuraAdminTile(
            title: 'Workspace',
            body:
                'Review what is live, what is pinned, and how each notice opens on the public path.',
            icon: Icons.campaign_outlined,
            action: Wrap(
              spacing: AuraSpace.s10,
              runSpacing: AuraSpace.s10,
              children: [
                AuraPrimaryButton(
                  label: 'Create platform notice',
                  onPressed: () =>
                      context.go('/announcements/create?scope=platform'),
                  icon: Icons.add_circle_outline,
                ),
                AuraSecondaryButton(
                  label: 'Refresh archive',
                  onPressed: () => ref.invalidate(announcementsProvider),
                  icon: Icons.refresh_rounded,
                ),
                AuraSecondaryButton(
                  label: 'Refresh pinned',
                  onPressed: () => ref.invalidate(pinnedAnnouncementsProvider),
                  icon: Icons.push_pin_outlined,
                ),
                AuraGhostButton(
                  label: 'Open updates',
                  onPressed: () => context.go('/updates'),
                  icon: Icons.notifications_none_outlined,
                ),
                AuraGhostButton(
                  label: 'Public home',
                  onPressed: () => context.go('/public'),
                  icon: Icons.public_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: AuraSpace.s20),
          _PinnedSection(
            asyncValue: pinnedAsync,
            title: 'Pinned platform notices',
          ),
          const SizedBox(height: AuraSpace.s12),
          _AllSection(
            asyncValue: listAsync,
            title: 'Announcement archive',
            emptyTitle: 'No announcements yet',
            emptyBody:
                'When platform notices are published, they will appear here.',
          ),
        ],
      ),
    );
  }
}

// ── Institution screen ─────────────────────────────────────────────────────

class _InstitutionAnnouncementsScreen extends StatelessWidget {
  const _InstitutionAnnouncementsScreen({
    required this.access,
    required this.pinnedAsync,
    required this.listAsync,
  });

  final InstitutionAccess access;
  final AsyncValue<List<Announcement>> pinnedAsync;
  final AsyncValue<List<Announcement>> listAsync;

  Map<String, dynamic> _asMapLocal(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _value(dynamic value) => (value ?? '').toString().trim();

  String _institutionName() {
    final institution = _asMapLocal(access.institution);
    final request = _asMapLocal(access.request);

    final fromInstitution = _value(institution['name']);
    if (fromInstitution.isNotEmpty) return fromInstitution;

    final fromRequest = _value(request['organizationName']);
    if (fromRequest.isNotEmpty) return fromRequest;

    return 'Institution announcements';
  }

  String _domain() {
    final institution = _asMapLocal(access.institution);
    final request = _asMapLocal(access.request);

    final fromInstitution = _value(institution['domain']);
    if (fromInstitution.isNotEmpty) return fromInstitution;

    return _value(request['domain']);
  }

  String _standingLabel() {
    switch (access.state) {
      case InstitutionAccessState.pending:
        return 'Standing: Pending review';
      case InstitutionAccessState.verifiedMember:
        return 'Standing: Active';
      case InstitutionAccessState.authorizedSpeaker:
        return 'Standing: Active with speech authority';
      case InstitutionAccessState.none:
        return 'Standing: Not active';
    }
  }

  @override
  Widget build(BuildContext context) {
    final institutionName = _institutionName();
    final domain = _domain();
    final standing = _standingLabel();

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
          _AnnouncementsHeader(
            title: institutionName,
            subtitle:
                'Institution-facing announcement context alongside platform notices.',
          ),
          const SizedBox(height: AuraSpace.s24),
          // Standing + actions card
          Container(
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
                  'Standing',
                  style: AuraText.small.copyWith(
                    color: AuraSurface.faint,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: AuraSpace.s10),
                Wrap(
                  spacing: AuraSpace.s8,
                  runSpacing: AuraSpace.s8,
                  children: [
                    _StatusBadge(label: standing),
                    if (domain.isNotEmpty)
                      _StatusBadge(label: 'Domain: $domain'),
                  ],
                ),
                const SizedBox(height: AuraSpace.s16),
                Wrap(
                  spacing: AuraSpace.s10,
                  runSpacing: AuraSpace.s10,
                  children: [
                    AuraPrimaryButton(
                      label: 'Create institution notice',
                      onPressed: () =>
                          context.go('/announcements/create?scope=institution'),
                      icon: Icons.add_circle_outline,
                    ),
                    AuraSecondaryButton(
                      label: 'Institution dashboard',
                      onPressed: () => context.go('/institution/dashboard'),
                      icon: Icons.apartment_outlined,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AuraSpace.s20),
          _PinnedSection(
            asyncValue: pinnedAsync,
            title: 'Pinned platform notices',
          ),
          const SizedBox(height: AuraSpace.s12),
          _AllSection(
            asyncValue: listAsync,
            title: 'Platform announcements',
            emptyTitle: 'Nothing yet',
            emptyBody: 'Platform notices will appear here when published.',
          ),
        ],
      ),
    );
  }
}

// ── Status badge ───────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s10,
        vertical: AuraSpace.s6,
      ),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        border: Border.all(color: AuraSurface.divider),
        borderRadius: BorderRadius.circular(AuraRadius.pill),
      ),
      child: Text(
        label,
        style: AuraText.small.copyWith(
          fontWeight: FontWeight.w600,
          color: AuraSurface.muted,
        ),
      ),
    );
  }
}

// ── Pinned section ─────────────────────────────────────────────────────────

class _PinnedSection extends StatelessWidget {
  const _PinnedSection({
    required this.asyncValue,
    this.title = 'Pinned notices',
  });

  final AsyncValue<List<Announcement>> asyncValue;
  final String title;

  @override
  Widget build(BuildContext context) {
    return asyncValue.when(
      loading: () => const AuraLoadingState(message: 'Loading pinned…'),
      error: (e, _) => const AuraErrorState(
        title: 'Could not load pinned notices',
        body: 'Something went wrong. Try refreshing.',
      ),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: AuraSpace.s4,
                bottom: AuraSpace.s10,
              ),
              child: Text(
                title,
                style: AuraText.label.copyWith(
                  color: AuraSurface.faint,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            ...items.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: AuraSpace.s8),
                child: _AnnouncementCard(
                  title: a.title.isEmpty ? a.slug : a.title,
                  publishedAt: a.publishedAt,
                  pinned: true,
                  firstMedia: _firstMediaOf(a),
                  onTap: () => context.go('/announcements/${a.slug}'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

FeedMedia? _firstMediaOf(Announcement a) {
  if (a.media.isEmpty) return null;
  return FeedMedia.tryFromJson(a.media.first);
}

// ── All section ────────────────────────────────────────────────────────────

class _AllSection extends StatelessWidget {
  const _AllSection({
    required this.asyncValue,
    this.title = 'All notices',
    this.emptyTitle = 'Nothing published yet',
    this.emptyBody =
        'When platform notices are published, they will appear here.',
  });

  final AsyncValue<List<Announcement>> asyncValue;
  final String title;
  final String emptyTitle;
  final String emptyBody;

  @override
  Widget build(BuildContext context) {
    return asyncValue.when(
      loading: () => const AuraLoadingState(message: 'Loading announcements…'),
      error: (e, _) => const AuraErrorState(
        title: 'Could not load announcements',
        body: 'Something went wrong. Try refreshing.',
      ),
      data: (items) {
        if (items.isEmpty) {
          return AuraEmptyState(
            title: emptyTitle,
            body: emptyBody,
            icon: Icons.campaign_outlined,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: AuraSpace.s4,
                bottom: AuraSpace.s10,
              ),
              child: Text(
                title,
                style: AuraText.label.copyWith(
                  color: AuraSurface.faint,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            ...items.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: AuraSpace.s8),
                child: _AnnouncementCard(
                  title: a.title.isEmpty ? a.slug : a.title,
                  publishedAt: a.publishedAt,
                  firstMedia: _firstMediaOf(a),
                  onTap: () => context.go('/announcements/${a.slug}'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Announcement card ──────────────────────────────────────────────────────

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({
    required this.title,
    required this.onTap,
    this.publishedAt,
    this.pinned = false,
    this.firstMedia,
  });

  final String title;
  final DateTime? publishedAt;
  final bool pinned;
  final VoidCallback onTap;
  final FeedMedia? firstMedia;

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        child: Container(
          decoration: BoxDecoration(
            color: AuraSurface.card,
            borderRadius: BorderRadius.circular(AuraRadius.card),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (firstMedia != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AuraSpace.s14,
                    AuraSpace.s14,
                    AuraSpace.s14,
                    0,
                  ),
                  child: CanonicalMediaThumb(media: firstMedia!),
                ),
              Padding(
                padding: const EdgeInsets.all(AuraSpace.s14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AuraSurface.accentSoft,
                        borderRadius: BorderRadius.circular(AuraRadius.r10),
                        border: Border.all(
                          color: AuraSurface.accent.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Icon(
                        pinned
                            ? Icons.push_pin_outlined
                            : Icons.campaign_outlined,
                        size: 16,
                        color: AuraSurface.accentText,
                      ),
                    ),
                    const SizedBox(width: AuraSpace.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AuraText.small.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (publishedAt != null) ...[
                            const SizedBox(height: AuraSpace.s4),
                            Text(
                              _formatDate(publishedAt!),
                              style: AuraText.micro.copyWith(
                                color: AuraSurface.faint,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AuraSpace.s8),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: AuraSurface.faint,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
