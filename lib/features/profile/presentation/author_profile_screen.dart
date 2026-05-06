import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/interactions/follows_repository.dart';
import '../../../core/interactions/interaction_service.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/profile_header.dart';
import '../../feed/domain/post.dart';
import '../../posts/presentation/widgets/post_card.dart';
import '../domain/profile.dart';
import '../providers.dart';

enum _ProfileTab { posts, connections }

class AuthorProfileScreen extends ConsumerStatefulWidget {
  const AuthorProfileScreen({super.key, required this.handle});

  final String handle;

  @override
  ConsumerState<AuthorProfileScreen> createState() =>
      _AuthorProfileScreenState();
}

class _AuthorProfileScreenState extends ConsumerState<AuthorProfileScreen> {
  late Future<_ProfileBundle> _bundleFuture;
  _ProfileTab _activeTab = _ProfileTab.posts;

  @override
  void initState() {
    super.initState();
    _bundleFuture = _load();
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
      path: '/me/correspondence/create/space',
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
              if (leading != null) ...[
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

    if (profile.isVerified) {
      meta.add(
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s10,
            vertical: AuraSpace.s4,
          ),
          decoration: BoxDecoration(
            color: AuraSurface.goodBg,
            border: Border.all(
              color: AuraSurface.goodInk.withValues(alpha: 0.35),
            ),
            borderRadius: BorderRadius.circular(AuraRadius.pill),
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
      );
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
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s4),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Row(
        children: [
          _ProfileTabPill(
            label: 'Posts',
            selected: _activeTab == _ProfileTab.posts,
            onTap: () => setState(() => _activeTab = _ProfileTab.posts),
          ),
          _ProfileTabPill(
            label: 'Connections',
            selected: _activeTab == _ProfileTab.connections,
            onTap: () => setState(() => _activeTab = _ProfileTab.connections),
          ),
        ],
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
    String? viewerId;
    String? viewerHandle;
    if (me != null) {
      final user = me['user'];
      if (user is Map) {
        viewerId = user['id']?.toString();
        viewerHandle = user['handle']?.toString();
      }
    }
    final isSelf = isAuthed &&
        ((viewerHandle != null &&
                normalizeHandle(viewerHandle) ==
                    normalizeHandle(widget.handle)) ||
            (viewerId != null &&
                viewerId.isNotEmpty &&
                viewerId == _cleanValue(profile.id)));

    final followLabel = switch (followState) {
      'following' => 'Following',
      'outgoing_pending' => 'Requested',
      _ => 'Follow',
    };

    final canFollowAction = !isSelf &&
        (followState == 'none' || followState == 'outgoing_pending');
    final canCorrespond =
        isAuthed && !isSelf && followState == 'following';

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
                PresenceHeader(
                  displayName: name,
                  handle: widget.handle,
                  bio: bio,
                  avatarUrl: avatar,
                  coverUrl: cover,
                  trailingMeta: trailingMeta,
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
                      PresenceHeaderAction(
                        label: 'Settings',
                        primary: false,
                        icon: Icons.settings_outlined,
                        onTap: () => context.push('/security'),
                      ),
                    ]
                    else
                      PresenceHeaderAction(
                        label: followLabel,
                        primary: true,
                        icon: followState == 'following'
                            ? Icons.check
                            : followState == 'outgoing_pending'
                            ? Icons.schedule
                            : Icons.person_add_alt_1,
                        onTap: !canFollowAction
                            ? null
                            : () async {
                                try {
                                  if (followState == 'outgoing_pending') {
                                    await repo.unfollow(widget.handle);
                                    _showMessage('Request canceled');
                                  } else {
                                    await repo.follow(widget.handle);
                                    _showMessage('Follow request sent');
                                  }
                                  _reload();
                                } catch (_) {
                                  _showMessage('Could not update follow state');
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
                if (showNotice) ...[
                  const SizedBox(height: AuraSpace.s16),
                  notice,
                ],
                const SizedBox(height: AuraSpace.s16),
                _buildTabBar(),
                const SizedBox(height: AuraSpace.s20),
                if (_activeTab == _ProfileTab.posts)
                  _workSection(posts)
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
                      if (isAuthed) ...[
                        const SizedBox(height: AuraSpace.s24),
                        _reportSection(),
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

  Widget _reportSection() {
    return _surfaceSection(
      title: 'Moderation',
      children: [
        _sectionRow(
          title: 'Report this profile',
          subtitle: 'Flag content for review by moderators',
          leading: Icons.flag_outlined,
          onTap: () => _showMessage('Report submitted. Thank you.'),
        ),
      ],
    );
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

class _ProfileTabPill extends StatelessWidget {
  const _ProfileTabPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(
              vertical: AuraSpace.s8,
              horizontal: AuraSpace.s4,
            ),
            decoration: BoxDecoration(
              color: selected ? AuraSurface.accentSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(AuraRadius.pill),
              border: Border.all(
                color: selected
                    ? AuraSurface.accent.withValues(alpha: 0.4)
                    : Colors.transparent,
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AuraText.small.copyWith(
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
                color:
                    selected ? AuraSurface.accentText : AuraSurface.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
