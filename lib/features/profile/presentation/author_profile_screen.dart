import '../../../core/media/aura_media_viewer.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/navigation/navigation_authority.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/compliance/blocks_repository.dart';
import '../../../core/compliance/report_content_sheet.dart';
import '../../../core/compliance/report_repository.dart';
import '../../../core/interactions/follows_repository.dart';
import '../../../core/interactions/interaction_service.dart';
import '../../../core/trust/trust_marks.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_profile_tab_bar.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/aura_text_block.dart';
import '../../../core/ui/compact_profile_hero.dart';
import '../../../core/ui/profile_header.dart';
import '../../feed/data/unified_feed_providers.dart';
import '../../feed/domain/post.dart';
import '../../posts/presentation/widgets/post_card.dart';
import '../domain/profile.dart';
import '../providers.dart';
import '../../../core/identity/person_identity_model.dart';

class AuthorProfileScreen extends ConsumerStatefulWidget {
  const AuthorProfileScreen({super.key, required this.handle});

  final String handle;

  @override
  ConsumerState<AuthorProfileScreen> createState() =>
      _AuthorProfileScreenState();
}

class _AuthorProfileScreenState extends ConsumerState<AuthorProfileScreen>
    with SingleTickerProviderStateMixin {
  late Future<_ProfileBundle> _bundleFuture;
  late final TabController _tabController;

  // R1 follow hardening: prevent concurrent follow/unfollow taps and
  // give the user an immediate label flip. Cleared after _reload()
  // completes or on backend failure.
  bool _followBusy = false;
  String? _optimisticFollowState;

  @override
  void initState() {
    super.initState();
    _bundleFuture = _load();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<_ProfileBundle> _load() async {
    final repo = ref.read(profileRepositoryProvider);

    final profile = await repo.fetchProfile(widget.handle);
    final posts = await repo.getUserPosts(widget.handle);
    final followDetail = await repo.getFollowStateDetail(widget.handle);

    return _ProfileBundle(
      profile: profile,
      posts: posts,
      followState: followDetail.state,
    );
  }

  void _reload() {
    setState(() {
      _bundleFuture = _load();
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Single-source-of-truth Message CTA. Routes through
  /// [InteractionService.openDirectThread]. Never falls back to /home or
  /// /messages — failures surface as errors only.
  Future<void> _openPrivateConversation(Profile profile) async {
    final targetId = _cleanValue(profile.id);
    if (targetId.isEmpty) {
      _showMessage('Profile is not available for messaging.');
      return;
    }
    try {
      await ref.read(interactionServiceProvider).openDirectThread(
            context: context,
            ref: ref,
            target: ActorRef.user(targetId),
          );
    } on InteractionError catch (e) {
      _showMessage(e.message);
    } on DioException catch (e) {
      final msg = (e.response?.data is Map &&
              (e.response!.data as Map)['message'] != null)
          ? (e.response!.data as Map)['message'].toString()
          : 'Could not open message thread.';
      _showMessage(msg);
    } catch (_) {
      _showMessage('Could not open message thread.');
    }
  }

  void _openInviteToSpace(Profile profile) {
    final userId = _cleanValue(profile.id);
    final displayName = _cleanValue(profile.displayName);
    final handle = _cleanValue(widget.handle);

    final uri = Uri(
      path: '/messages/new',
      queryParameters: {
        if (userId.isNotEmpty) 'userId': userId,
        if (handle.isNotEmpty) 'handle': handle,
        if (displayName.isNotEmpty) 'name': displayName,
      },
    );

    context.push(uri.toString());
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s10),
      child: Text(title, style: AuraText.title),
    );
  }

  Widget _surfaceSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(title),
        AuraCard(
          padding: EdgeInsets.zero,
          child: Column(children: _withDividers(children)),
        ),
      ],
    );
  }

  List<Widget> _withDividers(List<Widget> children) {
    final out = <Widget>[];

    for (var i = 0; i < children.length; i++) {
      out.add(children[i]);
      if (i != children.length - 1) {
        out.add(
          const Divider(height: 1, thickness: 1, color: AuraSurface.divider),
        );
      }
    }

    return out;
  }

  Widget _sectionRow({
    required String title,
    String? subtitle,
    String? trailing,
    required VoidCallback? onTap,
    IconData? leading,
    /// A real image in the leading slot -- a work's cover, a site's mark.
    /// Takes precedence over [leading] when both are given.
    Widget? leadingWidget,
    bool enabled = true,
  }) {
    final active = enabled && onTap != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: active ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s16,
            vertical: AuraSpace.s14,
          ),
          child: Row(
            children: [
              if (leadingWidget != null) ...[
                leadingWidget,
                const SizedBox(width: AuraSpace.s12),
              ] else if (leading != null) ...[
                Icon(
                  leading,
                  size: 18,
                  color: active ? AuraSurface.ink : AuraSurface.muted,
                ),
                const SizedBox(width: AuraSpace.s12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AuraText.body.copyWith(
                        fontWeight: FontWeight.w700,
                        color: active ? AuraSurface.ink : AuraSurface.muted,
                      ),
                    ),
                    if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: AuraText.small.copyWith(
                          color: AuraSurface.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null && trailing.trim().isNotEmpty) ...[
                Text(
                  trailing,
                  style: AuraText.small.copyWith(
                    color: AuraSurface.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: AuraSpace.s10),
              ],
              Icon(
                Icons.chevron_right,
                size: 18,
                color: active ? AuraSurface.muted : AuraSurface.divider,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Account Lifecycle / Public Identity doctrine — truthful, non-
  /// judgmental representation. Never states a moderation reason; just
  /// that the account is no longer active/deleted, so the viewer
  /// understands why Follow/Message aren't offered.
  Widget? _lifecycleNotice(Profile profile) {
    if (profile.isActive) return null;
    final message = profile.accountStatus == 'DELETED'
        ? 'This account has been deleted.'
        : 'This account is currently inactive.';
    return AuraCard(
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: AuraSurface.muted),
          const SizedBox(width: AuraSpace.s10),
          Expanded(
            child: Text(
              message,
              style: AuraText.body.copyWith(color: AuraSurface.muted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _presenceNotice({
    required bool isAuthed,
    required bool canCorrespond,
    required String followState,
  }) {
    if (!isAuthed || canCorrespond) {
      return const SizedBox.shrink();
    }

    final message = followState == 'outgoing_pending'
        ? 'Messaging opens when the follow relationship is established.'
        : 'Follow first to open a direct message or invite this person into a shared space.';

    return AuraCard(
      child: Text(
        message,
        style: AuraText.body.copyWith(color: AuraSurface.muted, height: 1.5),
      ),
    );
  }

  List<Widget> _presenceMeta(Profile profile) {
    final meta = <Widget>[];

    // C2 — layered Person verification. One mark per governed class
    // (identity / affiliation / role-or-credential), never a collapsed
    // "Verified person". Nothing renders when nothing is verified.
    for (final verifiedClass in profile.verification.classes) {
      meta.add(TrustMark(fact: TrustFact.ofPersonClass(verifiedClass)));
    }

    final location = _cleanValue(profile.location);
    if (location.isNotEmpty) {
      meta.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: AuraSurface.divider),
            borderRadius: BorderRadius.circular(AuraRadius.pill),
          ),
          child: Text(
            location,
            style: AuraText.small.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return meta;
  }

  /// PUBLISHED RECORD — the works a person declares on their own profile.
  ///
  /// The API has sent these all along (`publicSelect` includes `publications`
  /// and `links`); the public profile simply never rendered them, so a
  /// person's books were stored and invisible. Founder-reported 2026-09-09 —
  /// and the whole point of storing them is that a reader reaches the work.
  ///
  /// A PUBLICATION IS NOT A LINK. It carries a title that is its identity and
  /// the person's own description, so it is presented as a work: the
  /// description is shown and the destination is a trailing detail. Links keep
  /// their own quieter section. Both share a card; neither borrows the other's
  /// meaning.
  ///
  /// It is an ASSERTION, not a verified credential. Nothing here renders a
  /// trust mark, and nothing infers authorship from it.
  Widget _publishedRecordSection(List<ProfilePublication> publications) {
    if (publications.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s24),
      child: _surfaceSection(
        title: 'Published record',
        children: [
          for (final publication in publications)
            _publicationRow(publication),
        ],
      ),
    );
  }

  /// ELSEWHERE — general external destinations. Same name the owner's own
  /// presence view uses, so one thing has one vocabulary.
  Widget _elsewhereSection(List<ProfileLink> links) {
    if (links.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s24),
      child: _surfaceSection(
        title: 'Elsewhere',
        children: [
          for (final link in links) _linkRow(link),
        ],
      ),
    );
  }

  /// A WORK, WITH ITS OWN COVER WHERE ONE EXISTS.
  ///
  /// The cover is the destination's Open Graph image, resolved on save and
  /// served through Aura's proxy. It is ENRICHMENT: the title and description
  /// beside it are the person's own and are never replaced by what the page
  /// says about itself.
  ///
  /// A publication with no cover keeps the book icon rather than a grey
  /// placeholder. An empty frame promising an image that will never arrive is
  /// worse than an honest mark.
  Widget _publicationRow(ProfilePublication publication) {
    final cover = (publication.coverUrl ?? '').trim();
    return _sectionRow(
      title: publication.title,
      // The person's own words. Never truncated to a label, never replaced by
      // a scraped summary.
      subtitle: publication.description,
      trailing: publication.year?.toString(),
      leading: cover.isEmpty ? Icons.menu_book_outlined : null,
      leadingWidget: cover.isEmpty
          ? null
          : ClipRRect(
              borderRadius: BorderRadius.circular(AuraRadius.r10),
              child: Image.network(
                cover,
                width: 34,
                height: 46,
                fit: BoxFit.cover,
                // A cover that fails to load falls back to the mark rather
                // than to a broken-image glyph.
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.menu_book_outlined,
                  size: 18,
                  color: AuraSurface.ink,
                ),
              ),
            ),
      onTap: (publication.url ?? '').isEmpty
          ? null
          : () => _openExternalUrl(publication.url!),
    );
  }

  /// A DESTINATION, WITH THE MARK OF WHERE IT GOES.
  ///
  /// A favicon, not a banner. What a link needs is the identity of the site
  /// it points at; a full-width image here would make a bookmark look like an
  /// authored work.
  Widget _linkRow(ProfileLink link) {
    final icon = (link.iconUrl ?? '').trim();
    return _sectionRow(
      title: (link.label ?? '').isNotEmpty ? link.label! : _hostOf(link.url),
      subtitle: _hostOf(link.url),
      leading: icon.isEmpty ? Icons.link_outlined : null,
      leadingWidget: icon.isEmpty
          ? null
          : ClipRRect(
              borderRadius: BorderRadius.circular(AuraRadius.r10),
              child: Image.network(
                icon,
                width: 18,
                height: 18,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.link_outlined,
                  size: 18,
                  color: AuraSurface.ink,
                ),
              ),
            ),
      onTap: () => _openExternalUrl(link.url),
    );
  }

  /// The bare host, for a calm secondary line. A full URL in a subtitle reads
  /// as debug output rather than as a destination.
  String _hostOf(String url) {
    final uri = Uri.tryParse(url.trim());
    final host = (uri?.host ?? '').replaceFirst(RegExp(r'^www\.'), '');
    return host.isEmpty ? url.trim() : host;
  }

  /// Open an external destination.
  ///
  /// The scheme is checked rather than assumed. The canonical contract already
  /// refuses anything but http(s) on write; this refuses it again on the way
  /// out, so no legacy row can ever become a `javascript:` navigation.
  Future<void> _openExternalUrl(String raw) async {
    final value = raw.trim();
    if (value.isEmpty) return;
    final normalized =
        value.startsWith('http://') || value.startsWith('https://')
            ? value
            : 'https://$value';
    final uri = Uri.tryParse(normalized);
    if (uri == null) return;
    if (uri.scheme != 'http' && uri.scheme != 'https') return;
    await launchUrl(uri, mode: LaunchMode.platformDefault);
  }

  Widget _workSection(List<Post> posts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Works'),
        if (posts.isEmpty)
          const AuraCard(
            child: Padding(
              padding: EdgeInsets.all(AuraSpace.s18),
              child: Text('No work yet.', style: AuraText.body),
            ),
          )
        else
          Column(
            children: posts
                .map(
                  (post) => Padding(
                    padding: const EdgeInsets.only(bottom: AuraSpace.s10),
                    child: PostCard(post: post),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget _correspondenceSection({
    required bool isAuthed,
    required bool canCorrespond,
    required Profile profile,
  }) {
    return _surfaceSection(
      title: 'Messages',
      children: [
        _sectionRow(
          title: 'Message',
          subtitle: canCorrespond
              ? 'Open a private conversation'
              : isAuthed
              ? 'Available after the follow relationship is established'
              : 'Sign in to continue',
          leading: Icons.chat_bubble_outline,
          enabled: canCorrespond,
          onTap: canCorrespond ? () => _openPrivateConversation(profile) : null,
        ),
        _sectionRow(
          title: 'Invite to space',
          subtitle: canCorrespond
              ? 'Bring this person into a shared room'
              : isAuthed
              ? 'Available after the follow relationship is established'
              : 'Sign in to continue',
          leading: Icons.person_add_alt_outlined,
          enabled: canCorrespond,
          onTap: canCorrespond ? () => _openInviteToSpace(profile) : null,
        ),
      ],
    );
  }

  /// Connections section.
  ///
  /// Aura's follow principle: counts are private. We render the row only
  /// for the profile owner (`isSelf`); other viewers see neither the
  /// trailing number nor the section. Follow/Following lists remain
  /// reachable from elsewhere in the app for the owner; we don't expose
  /// "0 followers" or placeholders in the public layout.
  Widget _connectionsSection(Profile profile, {required bool isSelf}) {
    if (!isSelf) return const SizedBox.shrink();
    return _surfaceSection(
      title: 'Connections',
      children: [
        _sectionRow(
          title: 'Followers',
          trailing: '${profile.followersCount}',
          leading: Icons.people_outline,
          onTap: () => context.push('/u/${widget.handle}/followers'),
        ),
        _sectionRow(
          title: 'Following',
          trailing: '${profile.followingCount}',
          leading: Icons.person_add_alt_1_outlined,
          onTap: () => context.push('/u/${widget.handle}/following'),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return AuraProfileTabBar(
      controller: _tabController,
      tabs: const [
        ('Posts', Icons.article_outlined),
        ('Connections', Icons.people_outline),
      ],
    );
  }

  Widget _aboutCard(String bio) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.xl),
        border: Border.all(color: AuraSurface.divider),
      ),
      padding: const EdgeInsets.all(AuraSpace.s20),
      child: AuraTextBlock(
        bio,
        style: AuraText.body.copyWith(height: 1.5, color: AuraSurface.ink),
        selectable: true,
      ),
    );
  }

  Widget _buildLoaded(_ProfileBundle bundle, bool isAuthed) {
    final repo = ref.read(profileRepositoryProvider);
    final profile = bundle.profile;
    final posts = bundle.posts;
    final followState = bundle.followState;

    final name = profile.displayName.trim().isNotEmpty
        ? profile.displayName.trim()
        : widget.handle;
    final bio = (profile.bio ?? '').trim();
    final title = (profile.title ?? '').trim();
    final avatar = (profile.avatarUrl ?? '').trim();
    final cover = (profile.coverUrl ?? '').trim();
    final trailingMeta = _presenceMeta(profile);

    // Self-profile detection. Compare viewer's handle (from /auth/me) to
    // the routed handle, with profile.id as a secondary fallback. When
    // the viewer is the profile owner, hide Follow + Message and show
    // account-management entries instead.
    final me = ref.watch(authMeDataProvider).valueOrNull;
    String normalizeHandle(String h) =>
        h.trim().replaceAll(RegExp(r'^@+'), '').toLowerCase();
    // F053/F116 — the VIEWER is a person, read through the one authority.
    // The local `me['user']` unwrap here is the F057 shape: it resolved
    // nothing when the payload was not nested exactly that way, and "am I
    // looking at my own profile?" then silently answered no.
    final viewer = AuraPersonIdentity.fromJson(me);
    final String? viewerId = viewer.userId.isEmpty ? null : viewer.userId;
    final String? viewerHandle = viewer.handle.isEmpty ? null : viewer.handle;
    final isSelf = isAuthed &&
        ((viewerHandle != null &&
                normalizeHandle(viewerHandle) ==
                    normalizeHandle(widget.handle)) ||
            (viewerId != null &&
                viewerId.isNotEmpty &&
                viewerId == _cleanValue(profile.id)));

    // Optimistic override takes precedence: the moment the user taps
    // Follow we want the label to flip before the _reload() round-trip
    // lands. If the request fails the override is cleared and we fall
    // back to the bundle's authoritative followState.
    final effectiveFollowState = _optimisticFollowState ?? followState;

    final followLabel = switch (effectiveFollowState) {
      'following' => 'Following',
      'outgoing_pending' => 'Requested',
      // C2 canonical Follow — the rejection cooldown is truthful relationship
      // state. Presenting "Follow" here would offer an action the backend
      // refuses; the person sees the honest state instead of a surprise error.
      'cooldown' => 'Not available yet',
      'incoming_pending' => 'Follow',
      _ => 'Follow',
    };

    // Account Lifecycle / Public Identity doctrine — the profile stays
    // resolvable (historical continuity), but a non-active account must
    // never offer an action the backend would reject: it's no longer a
    // valid target for a NEW relationship (follow) or NEW communication
    // (message/invite).
    final canFollowAction = !isSelf &&
        profile.isActive &&
        (effectiveFollowState == 'none' ||
            effectiveFollowState == 'incoming_pending' ||
            effectiveFollowState == 'outgoing_pending');
    final canCorrespond =
        isAuthed && !isSelf && profile.isActive && followState == 'following';

    final notice = _presenceNotice(
      isAuthed: isAuthed,
      canCorrespond: canCorrespond,
      followState: followState,
    );
    final showNotice = isAuthed && !isSelf && !canCorrespond;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final hPad = width < 600 ? 12.0 : width < 980 ? 24.0 : 32.0;
        final maxW = width < 600 ? double.infinity : width < 980 ? 760.0 : 860.0;

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: ListView(
              padding: EdgeInsets.fromLTRB(hPad, AuraSpace.s18, hPad, AuraSpace.s28),
              children: [
                CompactProfileHero(
                  displayName: name,
                  handle: widget.handle,
                  title: title,
                  avatarUrl: avatar,
                  coverUrl: cover,
                  // FOUNDER RULING — on the profile itself, the meaningful
                  // action on identity imagery is to LOOK at it: the reader is
                  // already where navigating would take them. Away from the
                  // profile the same avatar means "go to this person".
                  //
                  // Opened through Aura's CANONICAL media viewer, so full
                  // resolution resolves over the same governed door and custody
                  // path as every other image. No identity-private viewer.
                  onTapAvatar: avatar.isEmpty
                      ? null
                      : () => showAuraMediaViewer(
                            context,
                            items: [
                              AuraViewerItem(
                                originalUrl: avatar,
                                caption: name,
                                downloadContext: 'profile-avatar',
                              ),
                            ],
                          ),
                  onTapCover: cover.isEmpty
                      ? null
                      : () => showAuraMediaViewer(
                            context,
                            items: [
                              AuraViewerItem(
                                originalUrl: cover,
                                caption: name,
                                downloadContext: 'profile-cover',
                              ),
                            ],
                          ),
                  metaChips: trailingMeta,
                  actions: [
                    if (!isAuthed)
                      PresenceHeaderAction(
                        label: 'Sign in to follow',
                        primary: true,
                        icon: Icons.lock_outline,
                        onTap: () {
                          final redirect = '/u/${widget.handle}';
                          context.push(
                            '/login?redirect=${Uri.encodeComponent(redirect)}',
                          );
                        },
                      )
                    else if (isSelf) ...[
                      PresenceHeaderAction(
                        label: 'Edit profile',
                        primary: true,
                        icon: Icons.edit_outlined,
                        onTap: () => context.push('/me/edit'),
                      ),
                      // A FOURTH entry point, and mislabelled like the others:
                      // "Settings" that opened only security. Own-profile
                      // settings mean the Preferences landing.
                      PresenceHeaderAction(
                        label: 'Preferences',
                        primary: false,
                        icon: Icons.tune_outlined,
                        onTap: () =>
                            context.push(NavigationAuthority.preferencesRoute),
                      ),
                    ]
                    else
                      PresenceHeaderAction(
                        label: followLabel,
                        primary: true,
                        icon: effectiveFollowState == 'following'
                            ? Icons.check
                            : effectiveFollowState == 'outgoing_pending'
                            ? Icons.schedule
                            : Icons.person_add_alt_1,
                        onTap: !canFollowAction || _followBusy
                            ? null
                            : () async {
                                // R1: guard against concurrent taps and
                                // flip the optimistic label immediately
                                // so the button reflects intent before
                                // the round-trip lands.
                                final isCancel =
                                    followState == 'outgoing_pending';
                                final optimisticNext =
                                    isCancel ? 'none' : 'outgoing_pending';
                                setState(() {
                                  _followBusy = true;
                                  _optimisticFollowState = optimisticNext;
                                });
                                try {
                                  if (isCancel) {
                                    await repo.unfollow(widget.handle);
                                    _showMessage('Request canceled');
                                  } else {
                                    await repo.follow(widget.handle);
                                    _showMessage('Follow request sent');
                                  }
                                  // After a follow / unfollow / cancel, invalidate
                                  // every feed surface so the home feed reflects
                                  // the new graph state on next render.
                                  invalidateUnifiedFeedSurfaces(ref);
                                  _reload();
                                } catch (_) {
                                  // Rollback the optimistic flip so the
                                  // label reverts to the bundle's truth.
                                  if (mounted) {
                                    setState(
                                        () => _optimisticFollowState = null);
                                  }
                                  _showMessage('Could not update follow state');
                                } finally {
                                  if (mounted) {
                                    setState(() {
                                      _followBusy = false;
                                      // _reload() will land with the
                                      // authoritative bundle; drop the
                                      // override so we don't shadow it.
                                      _optimisticFollowState = null;
                                    });
                                  }
                                }
                              },
                      ),
                    if (!isSelf)
                      PresenceHeaderAction(
                        label: 'Message',
                        primary: false,
                        icon: Icons.chat_bubble_outline,
                        onTap: canCorrespond
                            ? () => _openPrivateConversation(profile)
                            : null,
                      ),
                  ],
                ),
                if (_lifecycleNotice(profile) != null) ...[
                  const SizedBox(height: AuraSpace.s16),
                  _lifecycleNotice(profile)!,
                ],
                if (showNotice) ...[
                  const SizedBox(height: AuraSpace.s16),
                  notice,
                ],
                if (bio.isNotEmpty) ...[
                  const SizedBox(height: AuraSpace.s16),
                  _aboutCard(bio),
                ],
                const SizedBox(height: AuraSpace.s16),
                _buildTabBar(),
                const SizedBox(height: AuraSpace.s20),
                if (_tabController.index == 0) ...[
                  // A person's declared works come BEFORE the posts feed.
                  // "Works" below is that feed; the published record is the
                  // thing a reader came for.
                  _publishedRecordSection(profile.publications),
                  _elsewhereSection(profile.links),
                  _workSection(posts),
                ]
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _connectionsSection(profile, isSelf: isSelf),
                      if (isSelf) const SizedBox(height: AuraSpace.s24),
                      _correspondenceSection(
                        isAuthed: isAuthed,
                        canCorrespond: canCorrespond,
                        profile: profile,
                      ),
                      if (isAuthed && !isSelf) ...[
                        const SizedBox(height: AuraSpace.s24),
                        _reportSection(profile),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _reportSection(Profile profile) {
    final userId = _cleanValue(profile.id);
    return _surfaceSection(
      title: 'Moderation',
      children: [
        _sectionRow(
          title: 'Report this profile',
          subtitle: 'A human moderator reviews reports within 24 hours.',
          leading: Icons.flag_outlined,
          onTap: userId.isEmpty
              ? null
              : () => ReportContentSheet.show(
                    context,
                    targetType: ReportTargetType.user,
                    targetId: userId,
                    contextLabel: 'this profile',
                  ),
        ),
        _sectionRow(
          title: 'Block this user',
          subtitle: 'You will stop seeing their posts and replies.',
          leading: Icons.block,
          onTap: userId.isEmpty
              ? null
              : () => _confirmBlockProfile(userId),
        ),
      ],
    );
  }

  Future<void> _confirmBlockProfile(String userId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Block this user?'),
        content: const Text(
          'You will stop seeing this user\'s posts and replies. '
          'A moderator will review the block within 24 hours.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await blockUser(ref, userId);
      if (!mounted) return;
      _showMessage('User blocked. A moderator will review within 24 hours.');
    } catch (_) {
      if (!mounted) return;
      _showMessage('Could not block user. Try again later.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAuthed = ref.watch(authStatusProvider) == AuthStatus.authed;

    return AuraScaffold(
      title: 'Profile',
      body: FutureBuilder<_ProfileBundle>(
        future: _bundleFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: AuraLoadingState(message: 'Loading profile…'),
            );
          }

          if (snapshot.hasError || snapshot.data == null) {
            return const Center(
              child: AuraErrorState(
                title: 'Could not load profile',
                body: 'Check your connection and try again.',
              ),
            );
          }

          return _buildLoaded(snapshot.data!, isAuthed);
        },
      ),
    );
  }
}

class _ProfileBundle {
  const _ProfileBundle({
    required this.profile,
    required this.posts,
    required this.followState,
  });

  final Profile profile;
  final List<Post> posts;
  final String followState;
}

String _cleanValue(String? value) {
  return (value ?? '').trim();
}

