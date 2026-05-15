import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/surface/surface_composition.dart';
import '../../../features/admin/data/admin_providers.dart';
import '../../../features/announcements/providers.dart';
import '../../../features/discourse_intelligence/models.dart';
import '../../../features/discourse_intelligence/providers.dart';
import '../../../features/feed/data/unified_feed_providers.dart';
import '../../../features/feed/domain/feed_item.dart';
import '../../../features/feed/domain/post.dart';
import '../../../features/institutions/data/institutions_repository.dart';
import '../../../features/realtime/application/realtime_providers.dart';
import '../../../features/realtime/domain/realtime_enums.dart';
import '../../../features/realtime/domain/realtime_models.dart';
import '../../../features/saves/providers.dart';
import '../../../features/updates/providers.dart';

/// Real-data right-rail modules.
///
/// Each module follows the contract from `surface_composition.dart`:
///   * Uses `AuraRailModule` for chrome (title + icon + tone + body)
///   * Watches its OWN provider — no upstream prop-drilling
///   * Renders `SizedBox.shrink()` when there is nothing to surface, so
///     the rail collapses to whatever modules currently have content
///     instead of showing empty boxes
///   * Click targets push or go via GoRouter — no per-module navigation
///     callback indirection
///
/// What this file is NOT:
///   - a place to add new layout primitives (those belong in
///     surface_composition.dart)
///   - a place to add new providers (those belong in their feature
///     folders; this file only consumes existing ones)
///   - a marketing/engagement-bait surface — modules are operational,
///     not "trending" or algorithmic. If a module has no real data to
///     show, it hides itself.

// ─────────────────────────────────────────────────────────────────────────────
// LIVE NOW
// ─────────────────────────────────────────────────────────────────────────────

/// Surfaces active discoverable realtime sessions (spaces / institution
/// rooms) so the user always knows what's live without checking a tab.
/// Hidden when nothing is live.
class LiveNowRailModule extends ConsumerWidget {
  const LiveNowRailModule({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref
        .watch(discoverableLiveSessionsProvider)
        .maybeWhen(
          data: (s) => s,
          orElse: () => const <RealtimeSession>[],
        );
    if (sessions.isEmpty) return const SizedBox.shrink();

    return AuraRailModule(
      title: 'LIVE NOW',
      icon: Icons.sensors_rounded,
      tone: AuraRailModuleTone.accent,
      action: _LivePulseDot(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < sessions.length; i++) ...[
            _LiveSessionRow(session: sessions[i]),
            if (i < sessions.length - 1)
              const SizedBox(height: AuraSpace.s8),
          ],
        ],
      ),
    );
  }
}

class _LiveSessionRow extends StatelessWidget {
  const _LiveSessionRow({required this.session});

  final RealtimeSession session;

  String get _label {
    final name = session.contextName ?? session.title;
    switch (session.surfaceType) {
      case RealtimeSurfaceType.space:
        return name?.trim().isNotEmpty == true ? name! : 'Space';
      case RealtimeSurfaceType.institution:
        return name?.trim().isNotEmpty == true ? name! : 'Institution';
      case RealtimeSurfaceType.room:
        return name?.trim().isNotEmpty == true ? name! : 'Live room';
      default:
        return name?.trim().isNotEmpty == true ? name! : 'Live session';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = session.kind.toUpperCase() == 'VIDEO';
    return InkWell(
      borderRadius: BorderRadius.circular(AuraRadius.r10),
      onTap: () => context.go('/realtime/${session.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s6,
          vertical: AuraSpace.s6,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isVideo ? Icons.videocam_rounded : Icons.mic_rounded,
              size: 14,
              color: AuraSurface.accentText,
            ),
            const SizedBox(width: AuraSpace.s8),
            Expanded(
              child: Text(
                _label,
                style: AuraText.small.copyWith(
                  color: AuraSurface.ink,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AuraSpace.s8),
            Text(
              'Join',
              style: AuraText.micro.copyWith(
                color: AuraSurface.accentText,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LivePulseDot extends StatefulWidget {
  @override
  State<_LivePulseDot> createState() => _LivePulseDotState();
}

class _LivePulseDotState extends State<_LivePulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = 0.45 + (_c.value * 0.55);
        return Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: const Color(0xFF4ADE80).withValues(alpha: t),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4ADE80).withValues(alpha: t * 0.5),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SAVED & DRAFTS
// ─────────────────────────────────────────────────────────────────────────────

/// Surfaces "what you have unfinished" — saved posts to come back to and
/// the most recent held draft. Hidden when both are empty so the rail
/// doesn't carry dead boxes for users who don't use these affordances.
class SavedRailModule extends ConsumerWidget {
  const SavedRailModule({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedAsync = ref.watch(savedPostsProvider);
    final saved = savedAsync.maybeWhen(
      data: (list) => list,
      orElse: () => null,
    );
    if (saved == null || saved.isEmpty) return const SizedBox.shrink();

    final shown = saved.take(3).toList(growable: false);
    return AuraRailModule(
      title: 'SAVED',
      icon: Icons.bookmark_outline_rounded,
      action: Text(
        '${saved.length}',
        style: AuraText.micro.copyWith(
          color: AuraSurface.muted,
          fontWeight: FontWeight.w800,
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final p in shown) ...[
            _SavedRow(
              title: _postPreview(p),
              onTap: () => context.push('/posts/${p.id}'),
            ),
            if (p != shown.last) const SizedBox(height: AuraSpace.s6),
          ],
          const SizedBox(height: AuraSpace.s8),
          InkWell(
            borderRadius: BorderRadius.circular(AuraRadius.r10),
            onTap: () => context.go('/saved'),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AuraSpace.s6,
                vertical: 4,
              ),
              child: Text(
                'View all saved →',
                style: AuraText.micro.copyWith(
                  color: AuraSurface.accentText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _postPreview(Post post) {
    final raw = post.text.trim().replaceAll('\n', ' ');
    if (raw.isEmpty) return 'Saved post';
    return raw.length > 64 ? '${raw.substring(0, 64)}…' : raw;
  }
}

class _SavedRow extends StatelessWidget {
  const _SavedRow({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AuraRadius.r10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s6,
          vertical: AuraSpace.s4,
        ),
        child: Row(
          children: [
            const Icon(
              Icons.bookmark_rounded,
              size: 12,
              color: AuraSurface.muted,
            ),
            const SizedBox(width: AuraSpace.s8),
            Expanded(
              child: Text(
                title,
                style: AuraText.small.copyWith(
                  color: AuraSurface.ink,
                  height: 1.35,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WORKSPACE ACTIVITY (institution)
// ─────────────────────────────────────────────────────────────────────────────

/// Operational summary for an institution workspace. Surfaces who you
/// are working as + the workspace verification status. Per-action data
/// (pending join requests, recent announcements, moderation queue) is
/// deferred to follow-up passes — those need institution-scoped
/// activity providers that don't exist yet.
class WorkspaceActivityRailModule extends ConsumerWidget {
  const WorkspaceActivityRailModule({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(institutionIdentityProvider);
    final name = identity?.name.trim();
    return AuraRailModule(
      title: 'WORKSPACE',
      icon: Icons.account_balance_outlined,
      tone: AuraRailModuleTone.accent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            identity == null
                ? 'Institution context is loading.'
                : (name == null || name.isEmpty)
                    ? 'You are working in this institution.'
                    : 'You are working in $name.',
            style: AuraText.small.copyWith(
              color: AuraSurface.ink,
              height: 1.4,
            ),
          ),
          if (identity?.isVerified == true) ...[
            const SizedBox(height: AuraSpace.s8),
            Row(
              children: [
                const Icon(
                  Icons.verified_rounded,
                  size: 13,
                  color: AuraSurface.accentText,
                ),
                const SizedBox(width: 4),
                Text(
                  'Verified institution',
                  style: AuraText.micro.copyWith(
                    color: AuraSurface.accentText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PLATFORM NOTICE (governance/trust-line)
// ─────────────────────────────────────────────────────────────────────────────

/// A static governance note that grounds the right rail. Not algorithmic
/// noise — a constant reminder that institution discourse is on-record.
/// If platform-level trust/governance notices ever ship as data, this
/// becomes the consumer.
class GovernanceNoticeRailModule extends StatelessWidget {
  const GovernanceNoticeRailModule({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuraRailModule(
      title: 'GOVERNANCE',
      icon: Icons.verified_user_outlined,
      body: Text(
        'Verified institutions are accountable for what they publish. '
        'Posts, announcements, and live sessions are traceable to this '
        'workspace.',
        style: AuraText.small,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PINNED ANNOUNCEMENT
// ─────────────────────────────────────────────────────────────────────────────

/// Surfaces the most recent pinned platform announcement. Self-hides when
/// nothing is pinned. Used in the member and public discovery contexts to
/// keep urgent civic-platform notices reachable without disrupting the
/// center feed.
class PinnedAnnouncementRailModule extends ConsumerWidget {
  const PinnedAnnouncementRailModule({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pinnedAnnouncementsProvider);
    final list = async.maybeWhen(
      data: (l) => l,
      orElse: () => null,
    );
    if (list == null || list.isEmpty) return const SizedBox.shrink();
    final top = list.first;
    final title = top.title.trim().isEmpty ? top.slug : top.title.trim();
    final summary = top.summary.trim().isEmpty
        ? top.excerpt.trim()
        : top.summary.trim();
    return AuraRailModule(
      title: 'PINNED',
      icon: Icons.push_pin_outlined,
      tone: AuraRailModuleTone.accent,
      body: InkWell(
        borderRadius: BorderRadius.circular(AuraRadius.r10),
        onTap: () => context.push('/announcements/${top.slug}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s4,
            vertical: AuraSpace.s4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: AuraText.small.copyWith(
                  color: AuraSurface.ink,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (summary.isNotEmpty) ...[
                const SizedBox(height: AuraSpace.s4),
                Text(
                  summary,
                  style: AuraText.small.copyWith(
                    color: AuraSurface.muted,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RECENT ACTIVITY (notifications-driven)
// ─────────────────────────────────────────────────────────────────────────────

/// "What's happened since you were last here." Reads from the same
/// notifications controller the bell uses, so the count and ordering
/// stay consistent. Renders up to 4 most-recent items with a count
/// badge; hides entirely when the inbox is empty.
class RecentActivityRailModule extends ConsumerWidget {
  const RecentActivityRailModule({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(appNotificationsListProvider);
    final unread = ref.watch(notificationsUnreadCountProvider);
    if (notes.isEmpty) return const SizedBox.shrink();
    final shown = notes.take(4).toList(growable: false);

    return AuraRailModule(
      title: 'RECENT ACTIVITY',
      icon: Icons.bolt_outlined,
      action: unread > 0
          ? Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AuraSpace.s6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AuraSurface.accentSoft,
                borderRadius: BorderRadius.circular(AuraRadius.pill),
                border: Border.all(
                  color: AuraSurface.accent.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                '$unread new',
                style: AuraText.micro.copyWith(
                  color: AuraSurface.accentText,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                ),
              ),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final n in shown) ...[
            _ActivityRow(notification: n),
            if (n != shown.last) const SizedBox(height: AuraSpace.s6),
          ],
          const SizedBox(height: AuraSpace.s8),
          InkWell(
            borderRadius: BorderRadius.circular(AuraRadius.r10),
            onTap: () => context.go('/notifications'),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AuraSpace.s4,
                vertical: 4,
              ),
              child: Text(
                'See all activity →',
                style: AuraText.micro.copyWith(
                  color: AuraSurface.accentText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.notification});

  final dynamic notification;

  String get _label {
    final type = (notification.type as String).toUpperCase();
    switch (type) {
      case 'LIKE':
        return 'Someone liked your post';
      case 'REPLY':
        return 'New reply to your post';
      case 'REPOST':
        return 'Someone reposted your work';
      case 'FOLLOW':
        return 'New follower';
      case 'MESSAGE':
        return 'New message';
      case 'INSTITUTION_REPLY':
        return 'An institution responded';
      case 'INVITE':
        return 'You were invited';
      default:
        return 'New activity';
    }
  }

  void _go(BuildContext context) {
    final deeplink = notification.deeplink as String?;
    if (deeplink != null && deeplink.isNotEmpty) {
      context.go(deeplink);
    } else {
      context.go('/notifications');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = !(notification.isRead as bool);
    return InkWell(
      borderRadius: BorderRadius.circular(AuraRadius.r10),
      onTap: () => _go(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s4,
          vertical: AuraSpace.s4,
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: isUnread
                    ? AuraSurface.accent
                    : AuraSurface.divider,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AuraSpace.s8),
            Expanded(
              child: Text(
                _label,
                style: AuraText.small.copyWith(
                  color: isUnread ? AuraSurface.ink : AuraSurface.muted,
                  fontWeight: isUnread ? FontWeight.w600 : FontWeight.w500,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VERIFIED INSTITUTIONS
// ─────────────────────────────────────────────────────────────────────────────

/// Ecosystem-depth signal for the member feed and the public discovery
/// surface: who's verified, with a tap-through to their public profile.
/// Hides when the verified-institutions list is empty (e.g., before
/// initial sync). Shows the top N at desktop densities.
class VerifiedInstitutionsRailModule extends ConsumerWidget {
  const VerifiedInstitutionsRailModule({super.key, this.limit = 5});

  final int limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(verifiedInstitutionsProvider);
    final list = async.maybeWhen(
      data: (l) => l,
      orElse: () => const <Map<String, dynamic>>[],
    );
    if (list.isEmpty) return const SizedBox.shrink();
    final shown = list.take(limit).toList(growable: false);
    return AuraRailModule(
      title: 'VERIFIED INSTITUTIONS',
      icon: Icons.verified_outlined,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final m in shown) ...[
            _VerifiedInstitutionRow(json: m),
            if (m != shown.last) const SizedBox(height: AuraSpace.s4),
          ],
          const SizedBox(height: AuraSpace.s8),
          InkWell(
            borderRadius: BorderRadius.circular(AuraRadius.r10),
            onTap: () => context.go('/institutions'),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AuraSpace.s4,
                vertical: 4,
              ),
              child: Text(
                'Browse all institutions →',
                style: AuraText.micro.copyWith(
                  color: AuraSurface.accentText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerifiedInstitutionRow extends StatelessWidget {
  const _VerifiedInstitutionRow({required this.json});

  final Map<String, dynamic> json;

  String get _name {
    final name = (json['name'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;
    final slug = (json['slug'] ?? '').toString().trim();
    return slug.isNotEmpty ? slug : 'Institution';
  }

  String? get _slug {
    final slug = (json['slug'] ?? '').toString().trim();
    return slug.isEmpty ? null : slug;
  }

  @override
  Widget build(BuildContext context) {
    final slug = _slug;
    return InkWell(
      borderRadius: BorderRadius.circular(AuraRadius.r10),
      onTap: slug == null ? null : () => context.go('/institutions/$slug'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s4,
          vertical: AuraSpace.s4,
        ),
        child: Row(
          children: [
            const Icon(
              Icons.apartment_outlined,
              size: 13,
              color: AuraSurface.muted,
            ),
            const SizedBox(width: AuraSpace.s8),
            Expanded(
              child: Text(
                _name,
                style: AuraText.small.copyWith(
                  color: AuraSurface.ink,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(
              Icons.verified_rounded,
              size: 12,
              color: AuraSurface.accentText,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INSTITUTION RECENT ACTIVITY (institution-scoped)
// ─────────────────────────────────────────────────────────────────────────────

/// Surfaces recent institution-scoped activity events (member joins,
/// announcements published, posts created, verifications) so the
/// workspace rail conveys what's been happening this week. Hidden when
/// no institution identity is loaded or the activity feed is empty.
class InstitutionRecentActivityRailModule extends ConsumerWidget {
  const InstitutionRecentActivityRailModule({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(institutionIdentityProvider);
    final id = identity?.id ?? '';
    if (id.isEmpty) return const SizedBox.shrink();
    final async = ref.watch(
      institutionActivityFirstPageProvider(
        InstitutionActivityArgs(institutionId: id),
      ),
    );
    final page = async.maybeWhen(
      data: (p) => p,
      orElse: () => null,
    );
    if (page == null || page.items.isEmpty) return const SizedBox.shrink();
    final shown = page.items.take(4).toList(growable: false);

    return AuraRailModule(
      title: 'WORKSPACE ACTIVITY',
      icon: Icons.timeline_rounded,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final e in shown) ...[
            _InstitutionActivityRow(event: e),
            if (e != shown.last) const SizedBox(height: AuraSpace.s6),
          ],
          const SizedBox(height: AuraSpace.s8),
          InkWell(
            borderRadius: BorderRadius.circular(AuraRadius.r10),
            onTap: () => context.go('/institution/$id/activity'),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AuraSpace.s4,
                vertical: 4,
              ),
              child: Text(
                'Open activity log →',
                style: AuraText.micro.copyWith(
                  color: AuraSurface.accentText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InstitutionActivityRow extends StatelessWidget {
  const _InstitutionActivityRow({required this.event});

  final dynamic event;

  String get _label {
    final kind = (event.kind as String).toUpperCase();
    switch (kind) {
      case 'POST_CREATED':
      case 'INSTITUTION_POST_CREATED':
        return 'New post';
      case 'ANNOUNCEMENT_PUBLISHED':
      case 'ANNOUNCEMENT_CREATED':
        return 'Announcement published';
      case 'MEMBER_JOINED':
      case 'MEMBER_ADDED':
        return 'Member joined';
      case 'INSTITUTION_VERIFIED':
        return 'Institution verified';
      case 'LIVE_SESSION_STARTED':
        return 'Live session started';
      case 'JOIN_REQUEST_APPROVED':
        return 'Join request approved';
      default:
        return kind.replaceAll('_', ' ').toLowerCase();
    }
  }

  String _relative(DateTime? when) {
    if (when == null) return '';
    final diff = DateTime.now().difference(when);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${(diff.inDays / 7).floor()}w';
  }

  @override
  Widget build(BuildContext context) {
    final route = event.targetRoute as String?;
    final isActionable = event.isActionable as bool;
    return InkWell(
      borderRadius: BorderRadius.circular(AuraRadius.r10),
      onTap: isActionable && route != null && route.isNotEmpty
          ? () => context.go(route)
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s4,
          vertical: AuraSpace.s4,
        ),
        child: Row(
          children: [
            const Icon(
              Icons.circle,
              size: 5,
              color: AuraSurface.muted,
            ),
            const SizedBox(width: AuraSpace.s8),
            Expanded(
              child: Text(
                _label,
                style: AuraText.small.copyWith(
                  color: AuraSurface.ink,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AuraSpace.s6),
            Text(
              _relative(event.createdAt as DateTime?),
              style: AuraText.micro.copyWith(
                color: AuraSurface.faint,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADMIN — PLATFORM HEALTH (metrics + health snapshot)
// ─────────────────────────────────────────────────────────────────────────────

/// Operational metrics card for the admin shell. Surfaces the 4 numbers
/// an operator scans first: active users, institutions, pending reports,
/// realtime sessions. Hidden until the admin metrics endpoint resolves
/// (it's gated on `adminMeProvider`, so non-admins see nothing).
class AdminPlatformHealthRailModule extends ConsumerWidget {
  const AdminPlatformHealthRailModule({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(adminMetricsProvider);
    final healthAsync = ref.watch(adminHealthProvider);
    final metrics = metricsAsync.maybeWhen(
      data: (m) => m,
      orElse: () => null,
    );
    final health = healthAsync.maybeWhen(
      data: (h) => h,
      orElse: () => null,
    );
    if (metrics == null && health == null) return const SizedBox.shrink();

    return AuraRailModule(
      title: 'PLATFORM HEALTH',
      icon: Icons.monitor_heart_outlined,
      tone: AuraRailModuleTone.accent,
      action: health == null
          ? null
          : _HealthDot(healthy: health.healthy),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (metrics != null) ...[
            _MetricRow(label: 'Active users', value: metrics.activeUsers),
            const SizedBox(height: 3),
            _MetricRow(
                label: 'Institutions', value: metrics.totalInstitutions),
            const SizedBox(height: 3),
            _MetricRow(
                label: 'Pending reports', value: metrics.pendingReports),
            const SizedBox(height: 3),
            _MetricRow(
                label: 'Live sessions', value: metrics.realtimeSessions),
          ],
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AuraText.small.copyWith(
              color: AuraSurface.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          '$value',
          style: AuraText.small.copyWith(
            color: AuraSurface.ink,
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _HealthDot extends StatelessWidget {
  const _HealthDot({required this.healthy});

  final bool healthy;

  @override
  Widget build(BuildContext context) {
    final color = healthy
        ? const Color(0xFF4ADE80)
        : const Color(0xFFFB7185);
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADMIN — REVIEW QUEUE
// ─────────────────────────────────────────────────────────────────────────────

/// Operator's most-actionable card: outstanding review-queue items.
/// Hides for non-admins (provider returns const []) and for an empty
/// queue (clean state — no decorative empty box).
class AdminReviewQueueRailModule extends ConsumerWidget {
  const AdminReviewQueueRailModule({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminReviewQueueProvider);
    final list = async.maybeWhen(
      data: (l) => l,
      orElse: () => const [],
    );
    if (list.isEmpty) return const SizedBox.shrink();
    final shown = list.take(3).toList(growable: false);

    return AuraRailModule(
      title: 'REVIEW QUEUE',
      icon: Icons.rule_folder_outlined,
      action: Text(
        '${list.length}',
        style: AuraText.micro.copyWith(
          color: AuraSurface.muted,
          fontWeight: FontWeight.w800,
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in shown) ...[
            _ReviewQueueRow(title: item.title, type: item.type),
            if (item != shown.last) const SizedBox(height: AuraSpace.s6),
          ],
          const SizedBox(height: AuraSpace.s8),
          InkWell(
            borderRadius: BorderRadius.circular(AuraRadius.r10),
            onTap: () => context.go('/admin/review-queue'),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AuraSpace.s4,
                vertical: 4,
              ),
              child: Text(
                'Open full queue →',
                style: AuraText.micro.copyWith(
                  color: AuraSurface.accentText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewQueueRow extends StatelessWidget {
  const _ReviewQueueRow({required this.title, required this.type});

  final String title;
  final String type;

  @override
  Widget build(BuildContext context) {
    final t = title.trim().isEmpty ? type : title.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s4,
        vertical: 2,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.fiber_manual_record,
            size: 7,
            color: AuraSurface.muted,
          ),
          const SizedBox(width: AuraSpace.s8),
          Expanded(
            child: Text(
              t,
              style: AuraText.small.copyWith(
                color: AuraSurface.ink,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADMIN — PENDING INSTITUTIONS
// ─────────────────────────────────────────────────────────────────────────────

/// Verification requests waiting on a decision. Hides when there are
/// none. This is one of the two compact decision queues the admin
/// shell surfaces in the rail (the other being [AdminReviewQueueRailModule]).
class AdminPendingInstitutionsRailModule extends ConsumerWidget {
  const AdminPendingInstitutionsRailModule({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pendingInstitutionRequestsProvider);
    final list = async.maybeWhen(
      data: (l) => l,
      orElse: () => const <Map<String, dynamic>>[],
    );
    if (list.isEmpty) return const SizedBox.shrink();
    return AuraRailModule(
      title: 'PENDING INSTITUTIONS',
      icon: Icons.apartment_outlined,
      action: Text(
        '${list.length}',
        style: AuraText.micro.copyWith(
          color: AuraSurface.muted,
          fontWeight: FontWeight.w800,
        ),
      ),
      body: InkWell(
        borderRadius: BorderRadius.circular(AuraRadius.r10),
        onTap: () => context.go('/admin/users'),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s4,
            vertical: AuraSpace.s4,
          ),
          child: Text(
            list.length == 1
                ? 'One institution awaiting verification.'
                : '${list.length} institutions awaiting verification.',
            style: AuraText.small.copyWith(
              color: AuraSurface.ink,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CIVIC SIGNAL LAYER — TRENDING DISCOURSE
// ─────────────────────────────────────────────────────────────────────────────

/// Surfaces public discourse with active momentum: items with non-trivial
/// reply counts AND a recent-reply hint from the backend's `activity`
/// block. This is NOT an algorithmic "trending" feed — it's a real
/// signal pulled from `FeedInteraction.replyCount` (gated by
/// `canViewReplyCount`) and `FeedActivityHint.recentReply`. Items with
/// no replies, or whose backend doesn't expose the count, are excluded.
/// Module hides when no item clears the threshold.
class TrendingDiscourseRailModule extends ConsumerWidget {
  const TrendingDiscourseRailModule({
    super.key,
    this.limit = 4,
    this.minReplies = 2,
  });

  final int limit;
  final int minReplies;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(globalPublicFeedProvider);
    final page = async.maybeWhen(
      data: (p) => p,
      orElse: () => null,
    );
    if (page == null || page.items.isEmpty) return const SizedBox.shrink();

    final scored = <_TrendingScore>[];
    for (final item in page.items) {
      final int replies = item.interaction.canViewReplyCount
          ? item.interaction.replyCount
          : 0;
      final bool recent = item.activity?.recentReply ?? false;
      if (replies < minReplies && !recent) continue;
      // Score = replies × 2 + (recent ? 10 : 0). Recent activity is the
      // dominant signal (calm freshness > sheer count), but raw reply
      // depth still breaks ties.
      final score = replies * 2 + (recent ? 10 : 0);
      scored.add(_TrendingScore(item: item, score: score));
    }
    if (scored.isEmpty) return const SizedBox.shrink();
    scored.sort((a, b) => b.score.compareTo(a.score));
    final shown = scored.take(limit).toList(growable: false);

    return AuraRailModule(
      title: 'TRENDING DISCOURSE',
      icon: Icons.trending_up_rounded,
      tone: AuraRailModuleTone.accent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in shown) ...[
            _TrendingRow(item: entry.item),
            if (entry != shown.last) const SizedBox(height: AuraSpace.s6),
          ],
        ],
      ),
    );
  }
}

class _TrendingScore {
  const _TrendingScore({required this.item, required this.score});
  final FeedItem item;
  final int score;
}

class _TrendingRow extends StatelessWidget {
  const _TrendingRow({required this.item});

  final FeedItem item;

  String get _preview {
    final body = item.body.trim().replaceAll('\n', ' ');
    if (body.isEmpty) return item.title?.trim() ?? 'Discussion';
    return body.length > 80 ? '${body.substring(0, 80)}…' : body;
  }

  @override
  Widget build(BuildContext context) {
    final replies = item.interaction.canViewReplyCount
        ? item.interaction.replyCount
        : 0;
    return InkWell(
      borderRadius: BorderRadius.circular(AuraRadius.r10),
      onTap: () => context.push(item.targetRoute),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s4,
          vertical: AuraSpace.s4,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Icon(
                Icons.forum_outlined,
                size: 12,
                color: AuraSurface.accentText,
              ),
            ),
            const SizedBox(width: AuraSpace.s8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _preview,
                    style: AuraText.small.copyWith(
                      color: AuraSurface.ink,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (replies > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      '$replies ${replies == 1 ? 'reply' : 'replies'}',
                      style: AuraText.micro.copyWith(
                        color: AuraSurface.muted,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CIVIC SIGNAL LAYER — INSTITUTIONAL RESPONSE
// ─────────────────────────────────────────────────────────────────────────────

/// Surfaces public posts that have at least one OFFICIAL_INSTITUTION
/// reply. This is the visible-accountability signal: "where institutions
/// have publicly responded today." Filter uses the backend-emitted
/// reply-preview author context, which carries `OFFICIAL_INSTITUTION`
/// when the reply was authored as the institution voice — no client-side
/// heuristics. Module hides when no item has an institution response.
class InstitutionalResponseRailModule extends ConsumerWidget {
  const InstitutionalResponseRailModule({super.key, this.limit = 4});

  final int limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(globalPublicFeedProvider);
    final page = async.maybeWhen(
      data: (p) => p,
      orElse: () => null,
    );
    if (page == null || page.items.isEmpty) return const SizedBox.shrink();

    final matches = <_InstResponseItem>[];
    for (final item in page.items) {
      final preview = item.replyPreview;
      if (preview == null || preview.items.isEmpty) continue;
      // Find the first OFFICIAL_INSTITUTION reply on this item, if any.
      FeedReplyPreviewItem? instReply;
      for (final r in preview.items) {
        final ctxType = r.author.context?.type;
        if (ctxType == FeedIdentityContextType.officialInstitution) {
          instReply = r;
          break;
        }
      }
      if (instReply == null) continue;
      matches.add(
        _InstResponseItem(parent: item, response: instReply),
      );
    }
    if (matches.isEmpty) return const SizedBox.shrink();
    final shown = matches.take(limit).toList(growable: false);

    return AuraRailModule(
      title: 'INSTITUTIONAL RESPONSE',
      icon: Icons.account_balance_outlined,
      tone: AuraRailModuleTone.accent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in shown) ...[
            _InstResponseRow(entry: entry),
            if (entry != shown.last) const SizedBox(height: AuraSpace.s6),
          ],
        ],
      ),
    );
  }
}

class _InstResponseItem {
  const _InstResponseItem({required this.parent, required this.response});
  final FeedItem parent;
  final FeedReplyPreviewItem response;
}

class _InstResponseRow extends StatelessWidget {
  const _InstResponseRow({required this.entry});

  final _InstResponseItem entry;

  String _relative(DateTime? when) {
    if (when == null) return '';
    final diff = DateTime.now().difference(when);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${(diff.inDays / 7).floor()}w';
  }

  @override
  Widget build(BuildContext context) {
    final ctx = entry.response.author.context;
    final orgName = (ctx?.institutionName ?? entry.response.author.displayName)
        .trim();
    final parentSnippet = entry.parent.body
        .trim()
        .replaceAll('\n', ' ')
        .split('.')
        .first;
    final parentLead =
        parentSnippet.length > 56 ? '${parentSnippet.substring(0, 56)}…' : parentSnippet;
    final tag = entry.response.accountabilityTagWire;
    return InkWell(
      borderRadius: BorderRadius.circular(AuraRadius.r10),
      onTap: () => context.push(entry.parent.targetRoute),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s4,
          vertical: AuraSpace.s4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.verified_rounded,
                  size: 12,
                  color: AuraSurface.accentText,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    orgName.isEmpty ? 'Institution' : orgName,
                    style: AuraText.small.copyWith(
                      color: AuraSurface.accentText,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _relative(entry.response.createdAt),
                  style: AuraText.micro.copyWith(
                    color: AuraSurface.faint,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'responded to: $parentLead',
              style: AuraText.small.copyWith(
                color: AuraSurface.muted,
                height: 1.35,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (tag != null && tag.isNotEmpty) ...[
              const SizedBox(height: AuraSpace.s4),
              _AccountabilityChip(tagWire: tag),
            ],
          ],
        ),
      ),
    );
  }
}

/// Renders an accountability tag (COMMITMENT / UPDATE / RESOLVED) as a
/// compact chip alongside an institution reply. Backend emits the wire
/// token in `FeedReplyPreviewItem.accountabilityTagWire`; this widget is
/// the canonical visual treatment so member, institution, and public
/// rails all read the same accountability signal.
class _AccountabilityChip extends StatelessWidget {
  const _AccountabilityChip({required this.tagWire});

  final String tagWire;

  ({String label, IconData icon, Color fg, Color bg}) get _style {
    switch (tagWire.toUpperCase()) {
      case 'COMMITMENT':
        return (
          label: 'Commitment',
          icon: Icons.flag_outlined,
          fg: const Color(0xFFFBBF24),
          bg: const Color(0x33FBBF24),
        );
      case 'UPDATE':
        return (
          label: 'Update',
          icon: Icons.update_rounded,
          fg: const Color(0xFF60A5FA),
          bg: const Color(0x3360A5FA),
        );
      case 'RESOLVED':
        return (
          label: 'Resolved',
          icon: Icons.check_circle_outline_rounded,
          fg: const Color(0xFF4ADE80),
          bg: const Color(0x334ADE80),
        );
      default:
        return (
          label: tagWire,
          icon: Icons.label_outline_rounded,
          fg: AuraSurface.muted,
          bg: AuraSurface.elevated,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _style;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(color: s.fg.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(s.icon, size: 10, color: s.fg),
          const SizedBox(width: 4),
          Text(
            s.label,
            style: AuraText.micro.copyWith(
              color: s.fg,
              fontWeight: FontWeight.w800,
              fontSize: 10,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DISCOURSE INTELLIGENCE — ONGOING ISSUES
// ─────────────────────────────────────────────────────────────────────────────

/// Surfaces ongoing public discussions with sustained reply activity.
/// Backed by `/v1/discourse/issues` — every row is a real parent post
/// with a real reply count and a real lastActivityAt. Hidden when the
/// endpoint returns no rows (e.g., a quiet day).
class OngoingIssuesRailModule extends ConsumerWidget {
  const OngoingIssuesRailModule({super.key, this.limit = 4});

  final int limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(discourseIssuesProvider);
    final page = async.maybeWhen(
      data: (p) => p,
      orElse: () => null,
    );
    if (page == null || page.items.isEmpty) return const SizedBox.shrink();
    final shown = page.items.take(limit).toList(growable: false);

    return AuraRailModule(
      title: 'ONGOING DISCUSSIONS',
      icon: Icons.forum_outlined,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final issue in shown) ...[
            _OngoingIssueRow(issue: issue),
            if (issue != shown.last) const SizedBox(height: AuraSpace.s6),
          ],
        ],
      ),
    );
  }
}

class _OngoingIssueRow extends StatelessWidget {
  const _OngoingIssueRow({required this.issue});

  final DiscourseIssue issue;

  String _ageLabel() {
    if (issue.ageInDays <= 0) return 'today';
    if (issue.ageInDays == 1) return '1 day';
    return '${issue.ageInDays} days';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AuraRadius.r10),
      onTap: () => context.push(issue.targetRoute),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s4,
          vertical: AuraSpace.s4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              issue.preview.isEmpty ? 'Discussion' : issue.preview,
              style: AuraText.small.copyWith(
                color: AuraSurface.ink,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  '${issue.replyCount} '
                  '${issue.replyCount == 1 ? 'reply' : 'replies'}',
                  style: AuraText.micro.copyWith(
                    color: AuraSurface.muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
                if (issue.institutionReplyCount > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    '• ${issue.institutionReplyCount} institution',
                    style: AuraText.micro.copyWith(
                      color: AuraSurface.accentText,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  _ageLabel(),
                  style: AuraText.micro.copyWith(
                    color: AuraSurface.faint,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DISCOURSE INTELLIGENCE — ACCOUNTABILITY TRAIL
// ─────────────────────────────────────────────────────────────────────────────

/// Surfaces accountability counts per institution (COMMITMENT / UPDATE /
/// RESOLVED). Backed by `/v1/discourse/accountability`. Hides when no
/// institution has accountability-tagged replies on record.
class AccountabilityTrailRailModule extends ConsumerWidget {
  const AccountabilityTrailRailModule({super.key, this.limit = 4});

  final int limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(accountabilityTrailProvider);
    final page = async.maybeWhen(
      data: (p) => p,
      orElse: () => null,
    );
    if (page == null || page.items.isEmpty) return const SizedBox.shrink();
    final shown = page.items.take(limit).toList(growable: false);

    return AuraRailModule(
      title: 'ACCOUNTABILITY',
      icon: Icons.flag_outlined,
      tone: AuraRailModuleTone.accent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in shown) ...[
            _AccountabilityRow(row: row),
            if (row != shown.last) const SizedBox(height: AuraSpace.s6),
          ],
        ],
      ),
    );
  }
}

class _AccountabilityRow extends StatelessWidget {
  const _AccountabilityRow({required this.row});

  final AccountabilityRow row;

  String _oldestLabel() {
    final at = row.oldestCommitmentAt;
    if (at == null) return '';
    final diff = DateTime.now().difference(at);
    if (diff.inDays < 1) return 'today';
    if (diff.inDays == 1) return '1 day';
    if (diff.inDays < 7) return '${diff.inDays} days';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w';
    return '${(diff.inDays / 30).floor()}mo';
  }

  @override
  Widget build(BuildContext context) {
    final oldest = _oldestLabel();
    return InkWell(
      borderRadius: BorderRadius.circular(AuraRadius.r10),
      onTap: () => context.push('/institutions/${row.institutionSlug}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s4,
          vertical: AuraSpace.s4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              row.institutionName.isEmpty
                  ? 'Institution'
                  : row.institutionName,
              style: AuraText.small.copyWith(
                color: AuraSurface.ink,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                _AccountChip(
                  label: '${row.commitments} open',
                  color: const Color(0xFFFBBF24),
                ),
                if (row.updates > 0) ...[
                  const SizedBox(width: 4),
                  _AccountChip(
                    label: '${row.updates} update'
                        '${row.updates == 1 ? '' : 's'}',
                    color: const Color(0xFF60A5FA),
                  ),
                ],
                if (row.resolved > 0) ...[
                  const SizedBox(width: 4),
                  _AccountChip(
                    label: '${row.resolved} resolved',
                    color: const Color(0xFF4ADE80),
                  ),
                ],
                if (oldest.isNotEmpty && row.commitments > 0) ...[
                  const Spacer(),
                  Text(
                    'oldest $oldest',
                    style: AuraText.micro.copyWith(
                      color: AuraSurface.faint,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountChip extends StatelessWidget {
  const _AccountChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: AuraText.micro.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 9.5,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DISCOURSE INTELLIGENCE — INSTITUTION PARTICIPATION
// ─────────────────────────────────────────────────────────────────────────────

/// Surfaces institutions that have publicly responded most recently
/// (count + last responded). Backed by
/// `/v1/discourse/institution-participation`. Hides when no institutions
/// have replied as a voice in the window.
class InstitutionParticipationRailModule extends ConsumerWidget {
  const InstitutionParticipationRailModule({super.key, this.limit = 5});

  final int limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(institutionParticipationProvider);
    final page = async.maybeWhen(
      data: (p) => p,
      orElse: () => null,
    );
    if (page == null || page.items.isEmpty) return const SizedBox.shrink();
    final shown = page.items.take(limit).toList(growable: false);

    return AuraRailModule(
      title: 'RESPONDING NOW',
      icon: Icons.account_balance_outlined,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in shown) ...[
            _ParticipationRow(row: row),
            if (row != shown.last) const SizedBox(height: AuraSpace.s4),
          ],
        ],
      ),
    );
  }
}

class _ParticipationRow extends StatelessWidget {
  const _ParticipationRow({required this.row});

  final InstitutionParticipationRow row;

  String _relative() {
    final at = row.lastRespondedAt;
    if (at == null) return '';
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${(diff.inDays / 7).floor()}w';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AuraRadius.r10),
      onTap: () => context.push('/institutions/${row.institutionSlug}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s4,
          vertical: AuraSpace.s4,
        ),
        child: Row(
          children: [
            const Icon(
              Icons.apartment_outlined,
              size: 13,
              color: AuraSurface.muted,
            ),
            const SizedBox(width: AuraSpace.s8),
            Expanded(
              child: Text(
                row.institutionName.isEmpty
                    ? 'Institution'
                    : row.institutionName,
                style: AuraText.small.copyWith(
                  color: AuraSurface.ink,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AuraSpace.s6),
            if (row.verified) ...[
              const Icon(
                Icons.verified_rounded,
                size: 11,
                color: AuraSurface.accentText,
              ),
              const SizedBox(width: 3),
            ],
            Text(
              '${row.responseCount} • ${_relative()}',
              style: AuraText.micro.copyWith(
                color: AuraSurface.faint,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
