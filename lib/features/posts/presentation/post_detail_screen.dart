import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_error_mapper.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_responsive.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../feed/domain/post.dart';
import '../../share/aura_share_sheet.dart';
import 'widgets/post_card.dart';
import 'widgets/post_card/post_card_utils.dart';

Map<String, dynamic> _asMap(dynamic v) {
  if (v is Map) return Map<String, dynamic>.from(v);
  return <String, dynamic>{};
}

List<dynamic> _asList(dynamic v) {
  if (v is List) return v;
  return const <dynamic>[];
}

Post _postFromAny(dynamic body) {
  if (body is Map) {
    final map = Map<String, dynamic>.from(body);

    final directPost = map['post'];
    if (directPost is Map) {
      return Post.fromJson(Map<String, dynamic>.from(directPost));
    }

    final data = map['data'];
    if (data is Map) {
      final dataMap = Map<String, dynamic>.from(data);

      final nestedPost = dataMap['post'];
      if (nestedPost is Map) {
        return Post.fromJson(Map<String, dynamic>.from(nestedPost));
      }

      return Post.fromJson(dataMap);
    }

    return Post.fromJson(map);
  }

  throw StateError('Unexpected post response');
}

List<Post> _repliesFromAny(dynamic body) {
  if (body is List) {
    return body
        .whereType<Map>()
        .map((e) => Post.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  if (body is! Map) return const <Post>[];

  final root = _asMap(body);

  final directItems = _asList(root['items']);
  if (directItems.isNotEmpty) {
    return directItems
        .whereType<Map>()
        .map((e) => Post.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  final directReplies = _asList(root['replies']);
  if (directReplies.isNotEmpty) {
    return directReplies
        .whereType<Map>()
        .map((e) => Post.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  final data = root['data'];

  if (data is List) {
    return data
        .whereType<Map>()
        .map((e) => Post.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  if (data is Map) {
    final dataMap = _asMap(data);

    final nestedItems = _asList(dataMap['items']);
    if (nestedItems.isNotEmpty) {
      return nestedItems
          .whereType<Map>()
          .map((e) => Post.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    final nestedReplies = _asList(dataMap['replies']);
    if (nestedReplies.isNotEmpty) {
      return nestedReplies
          .whereType<Map>()
          .map((e) => Post.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
  }

  return const <Post>[];
}

final postProvider = FutureProvider.family<Post, String>((ref, id) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/posts/$id');
  return _postFromAny(res.data);
});

final repliesProvider = FutureProvider.family<List<Post>, String>((
  ref,
  id,
) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/posts/$id/replies');
  return _repliesFromAny(res.data);
});

class PostDetailScreen extends ConsumerWidget {
  const PostDetailScreen({super.key, required this.postId});

  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postAsync = ref.watch(postProvider(postId));
    final repliesAsync = ref.watch(repliesProvider(postId));

    return AuraScaffold(
      showHeader: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AuraSpace.s16,
          AuraSpace.s12,
          AuraSpace.s16,
          AuraSpace.s24,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kFeedWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TopBar(postId: postId),
                  const SizedBox(height: AuraSpace.s16),

                  const _SectionLabel(title: 'Public Record'),
                  const SizedBox(height: AuraSpace.s10),

                  Text(
                    'This work is part of a public record that remains accessible and accountable over time.',
                    style: AuraText.small.copyWith(color: AuraSurface.muted),
                  ),

                  const SizedBox(height: AuraSpace.s14),

                  postAsync.when(
                    data: (post) {
                      // `Post.visibility` is a non-nullable String on
                      // the domain model. Defensive trim() + uppercase
                      // is intentional even though the field is
                      // non-null: backend may emit lowercase strings.
                      final isPublic =
                          post.visibility.trim().toUpperCase() == 'PUBLIC';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PostCard(post: post, compact: false),
                          const SizedBox(height: AuraSpace.s12),
                          Wrap(
                            spacing: AuraSpace.s10,
                            runSpacing: AuraSpace.s10,
                            children: [
                              AuraSecondaryButton(
                                label: 'Respond',
                                icon: Icons.reply_outlined,
                                onPressed: () =>
                                    context.push('/compose?replyTo=$postId'),
                              ),
                              // External share — only when visibility is
                              // PUBLIC. FOLLOWERS / PRIVATE posts cannot
                              // be shared externally; the share URL would
                              // return a safe "content unavailable" page
                              // and surfacing the button would leak the
                              // post's existence.
                              if (isPublic)
                                AuraSecondaryButton(
                                  label: 'Share',
                                  icon: Icons.ios_share_rounded,
                                  onPressed: () => showAuraShareSheet(
                                    context,
                                    shareUrl: canonicalPostUrl(postId),
                                    headline: 'Share this work',
                                    subtitle:
                                        'A public, crawler-friendly link that previews on LinkedIn, X, Discord, Slack, Facebook.',
                                    emailSubject: 'Aura post',
                                  ),
                                ),
                            ],
                          ),
                        ],
                      );
                    },
                    loading: () => const _LoadingCard(label: 'Loading work…'),
                    error: (e, _) => _ErrorCard(
                      message: AppErrorMapper.from(e, feature: 'view this work').message,
                    ),
                  ),

                  const SizedBox(height: AuraSpace.s24),
                  const Divider(height: 1),
                  const SizedBox(height: AuraSpace.s20),

                  Row(
                    children: [
                      const Expanded(child: _SectionLabel(title: 'Responses')),
                      repliesAsync.when(
                        data: (items) => _CountPill(count: items.length),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ),

                  const SizedBox(height: AuraSpace.s10),

                  Text(
                    'Responses become part of the same record.',
                    style: AuraText.small.copyWith(color: AuraSurface.muted),
                  ),

                  const SizedBox(height: AuraSpace.s14),

                  repliesAsync.when(
                    data: (items) {
                      if (items.isEmpty) {
                        return AuraCard(
                          child: Padding(
                            padding: const EdgeInsets.all(AuraSpace.s14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'No responses yet.',
                                  style: AuraText.body.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: AuraSpace.s8),
                                Text(
                                  'Be the first to respond to this work.',
                                  style: AuraText.small.copyWith(
                                    color: AuraSurface.muted,
                                  ),
                                ),
                                const SizedBox(height: AuraSpace.s12),
                                AuraSecondaryButton(
                                  label: 'Respond',
                                  icon: Icons.reply_outlined,
                                  onPressed: () =>
                                      context.push('/compose?replyTo=$postId'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AuraSpace.s14),
                        itemBuilder: (context, index) {
                          return PostCard(post: items[index], compact: false);
                        },
                      );
                    },
                    loading: () =>
                        const _LoadingCard(label: 'Loading responses…'),
                    error: (e, _) => _ErrorCard(
                      message: AppErrorMapper.from(e, feature: 'view responses').message,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.postId});

  final String postId;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AuraSpace.s10,
      runSpacing: AuraSpace.s10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AuraSecondaryButton(
          label: 'Back',
          icon: Icons.arrow_back,
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            context.go('/search');
          },
        ),
        const Text('Record', style: AuraText.title),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AuraText.body.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s10,
        vertical: AuraSpace.s6,
      ),
      decoration: BoxDecoration(
        color: AuraSurface.elevated,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Text(
        '$count',
        style: AuraText.small.copyWith(
          color: AuraSurface.muted,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.s14),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AuraSpace.s10),
            Expanded(child: Text(label, style: AuraText.body)),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.s14),
        child: Text(message, style: AuraText.body),
      ),
    );
  }
}
