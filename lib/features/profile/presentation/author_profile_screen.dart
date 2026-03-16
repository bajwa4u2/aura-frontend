import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/profile_header.dart';
import '../../feed/domain/post.dart';
import '../../posts/presentation/widgets/post_card.dart';
import '../data/profile_repository.dart';
import '../domain/profile.dart';
import '../providers.dart';

class AuthorProfileScreen extends ConsumerStatefulWidget {
  const AuthorProfileScreen({
    super.key,
    required this.handle,
  });

  final String handle;

  @override
  ConsumerState<AuthorProfileScreen> createState() =>
      _AuthorProfileScreenState();
}

class _AuthorProfileScreenState extends ConsumerState<AuthorProfileScreen> {
  late Future<_ProfileBundle> _bundleFuture;

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _openPrivateConversation(Profile profile) {
    final userId = _cleanValue(profile.id);
    final displayName = _cleanValue(profile.displayName);
    final handle = _cleanValue(widget.handle);

    final uri = Uri(
      path: '/me/correspondence/create/conversation',
      queryParameters: {
        if (userId.isNotEmpty) 'userId': userId,
        if (handle.isNotEmpty) 'handle': handle,
        if (displayName.isNotEmpty) 'name': displayName,
      },
    );

    context.push(uri.toString());
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
          child: Column(
            children: _withDividers(children),
          ),
        ),
      ],
    );
  }

  List<Widget> _withDividers(List<Widget> children) {
    final out = <Widget>[];

    for (var i = 0; i < children.length; i++) {
      out.add(children[i]);
      if (i != children.length - 1) {
        out.add(const Divider(
          height: 1,
          thickness: 1,
          color: AuraSurface.divider,
        ));
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
        ? 'Correspondence opens when the follow relationship is established.'
        : 'Follow first to open direct correspondence or invite this person into a shared space.';

    return AuraCard(
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.s16),
        child: Text(
          message,
          style: AuraText.body,
        ),
      ),
    );
  }

  List<Widget> _presenceMeta(Profile profile) {
    final meta = <Widget>[];

    if (profile.isVerified) {
      meta.add(
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: AuraSurface.divider),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'Verified',
            style: AuraText.small.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    final location = _cleanValue(profile.location);
    if (location.isNotEmpty) {
      meta.add(
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: AuraSurface.divider),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            location,
            style: AuraText.small.copyWith(
              fontWeight: FontWeight.w600,
            ),
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
          AuraCard(
            child: Padding(
              padding: const EdgeInsets.all(AuraSpace.s18),
              child: Text(
                'No work yet.',
                style: AuraText.body,
              ),
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
      title: 'Correspondence',
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

  Widget _connectionsSection(Profile profile) {
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

  Widget _pageList(List<Widget> children) {
    final items = <Widget>[];

    for (var i = 0; i < children.length; i++) {
      items.add(children[i]);
      if (i != children.length - 1) {
        items.add(const SizedBox(height: 32));
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        double horizontalPadding;
        double maxWidth;

        if (width < 600) {
          horizontalPadding = 12;
          maxWidth = double.infinity;
        } else if (width < 980) {
          horizontalPadding = 24;
          maxWidth = 760;
        } else {
          horizontalPadding = 32;
          maxWidth = 860;
        }

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                18,
                horizontalPadding,
                28,
              ),
              children: items,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(profileRepositoryProvider);
    final isAuthed = ref.watch(authStatusProvider) == AuthStatus.authed;

    return AuraScaffold(
      title: 'Profile',
      body: FutureBuilder<_ProfileBundle>(
        future: _bundleFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return _pageList(const [
              AuraCard(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            ]);
          }

          if (snapshot.hasError || snapshot.data == null) {
            return _pageList([
              AuraCard(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    'Could not load profile.',
                    style: AuraText.body,
                  ),
                ),
              ),
            ]);
          }

          final bundle = snapshot.data!;
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

          final followLabel = switch (followState) {
            'following' => 'Following',
            'outgoing_pending' => 'Requested',
            _ => 'Follow',
          };

          final canFollowAction =
              followState == 'none' || followState == 'outgoing_pending';

          final canCorrespond = isAuthed && followState == 'following';

          return _pageList([
            PresenceHeader(
              displayName: name,
              handle: widget.handle,
              bio: bio,
              avatarUrl: avatar,
              coverUrl: cover,
              trailingMeta: trailingMeta,
              actions: [
                if (!isAuthed)
                  const PresenceHeaderAction(
                    label: 'Login to follow',
                    primary: true,
                    onTap: null,
                    icon: Icons.lock_outline,
                  )
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
                PresenceHeaderAction(
                  label: 'Message',
                  primary: false,
                  icon: Icons.chat_bubble_outline,
                  onTap: canCorrespond
                      ? () => _openPrivateConversation(profile)
                      : null,
                ),
                PresenceHeaderAction(
                  label: 'Invite to space',
                  primary: false,
                  icon: Icons.person_add_alt_outlined,
                  onTap: canCorrespond
                      ? () => _openInviteToSpace(profile)
                      : null,
                ),
              ],
            ),
            _presenceNotice(
              isAuthed: isAuthed,
              canCorrespond: canCorrespond,
              followState: followState,
            ),
            _workSection(posts),
            _correspondenceSection(
              isAuthed: isAuthed,
              canCorrespond: canCorrespond,
              profile: profile,
            ),
            _connectionsSection(profile),
          ]);
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