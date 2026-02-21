import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../../feed/providers.dart';
import '../../posts/presentation/widgets/post_card.dart';
import '../../saves/providers.dart';

/// Latest draft for the current user.
/// Backend: GET /posts/draft -> { draft: Post | null }
final draftProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final dio = ref.watch(dioProvider);

  final res = await dio.get('/v1/posts/draft'); // interceptor will attach auth + refresh if needed
  final data = res.data;

  if (data is Map) {
    final map = Map<String, dynamic>.from(data);
    final draft = map['draft'];
    if (draft == null) return null;
    if (draft is Map) return Map<String, dynamic>.from(draft);
  }

  return null;
});

class MemberHomeScreen extends ConsumerWidget {
  const MemberHomeScreen({super.key});

  Future<void> _openCompose(BuildContext context, WidgetRef ref) async {
    await context.push('/compose');
    ref.invalidate(draftProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthed = ref.watch(isAuthedProvider);
    final feedAsync = ref.watch(feedProvider);
    final savedAsync = ref.watch(savedPostsProvider);

    // Only watch draftProvider when authed, otherwise avoid 401 churn.
    final draftAsync = isAuthed ? ref.watch(draftProvider) : const AsyncValue<Map<String, dynamic>?>.data(null);

    return AuraScaffold(
      title: 'Aura',
      actions: [
        IconButton(
          tooltip: 'Compose',
          onPressed: () => _openCompose(context, ref),
          icon: const Icon(Icons.edit_outlined),
        ),
      ],
      body: ListView(
        padding: EdgeInsets.fromLTRB(AuraSpace.s16, AuraSpace.s12, AuraSpace.s16, AuraSpace.s24),
        children: [
          _HeroCard(
            onCompose: () => _openCompose(context, ref),
            onDiscover: () => context.go('/search'),
          ),
          SizedBox(height: AuraSpace.s14),

          _SectionTitle(title: 'Continue'),
          SizedBox(height: AuraSpace.s10),

          // Draft "Continue writing"
          Builder(
            builder: (_) {
              if (!isAuthed) {
                return Padding(
                  padding: EdgeInsets.only(bottom: AuraSpace.s10),
                  child: AuraCard(
                    onTap: () => context.go('/login?redirect=%2Fcompose'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Continue writing', style: AuraText.body.copyWith(fontWeight: FontWeight.w700)),
                        SizedBox(height: AuraSpace.s6),
                        Text('Login is required to restore your draft.', style: AuraText.body),
                      ],
                    ),
                  ),
                );
              }

              return draftAsync.when(
                data: (draft) {
                  if (draft == null) return const SizedBox.shrink();

                  final text = (draft['text'] ?? '').toString().trim();
                  if (text.isEmpty) return const SizedBox.shrink();

                  final updatedAtRaw = (draft['updatedAt'] ?? '').toString();
                  final dt = DateTime.tryParse(updatedAtRaw)?.toLocal();
                  final savedLine = dt == null ? 'Draft saved.' : 'Draft saved ${_time(dt)}.';

                  final preview = text.length <= 140 ? text : '${text.substring(0, 140)}…';

                  return Padding(
                    padding: EdgeInsets.only(bottom: AuraSpace.s10),
                    child: AuraCard(
                      onTap: () => _openCompose(context, ref),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Continue writing', style: AuraText.body.copyWith(fontWeight: FontWeight.w700)),
                          SizedBox(height: AuraSpace.s6),
                          Text(preview, style: AuraText.body.copyWith(height: 1.35)),
                          SizedBox(height: AuraSpace.s10),
                          Text(savedLine, style: AuraText.muted),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (e, _) {
                  final msg = _friendlyDraftError(e);
                  return Padding(
                    padding: EdgeInsets.only(bottom: AuraSpace.s10),
                    child: AuraCard(
                      onTap: () => _openCompose(context, ref),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Continue writing', style: AuraText.body.copyWith(fontWeight: FontWeight.w700)),
                          SizedBox(height: AuraSpace.s6),
                          Text(msg, style: AuraText.body),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),

          // Continue (Saved)
          savedAsync.when(
            data: (posts) {
              if (posts.isEmpty) {
                return AuraCard(
                  child: Text('Save something you want to return to. It will live here.', style: AuraText.body),
                );
              }
              return Column(
                children: posts
                    .take(2)
                    .map(
                      (p) => Padding(
                        padding: EdgeInsets.only(bottom: AuraSpace.s10),
                        child: PostCard(post: p, compact: true),
                      ),
                    )
                    .toList(),
              );
            },
            loading: () => const _LoadingCard(),
            error: (e, _) => AuraCard(child: Text('Could not load saved: $e', style: AuraText.body)),
          ),

          SizedBox(height: AuraSpace.s18),

          _SectionTitle(title: 'Latest'),
          SizedBox(height: AuraSpace.s10),
          feedAsync.when(
            data: (posts) {
              final top = posts.take(6).toList();
              if (top.isEmpty) return AuraCard(child: Text('No posts yet.', style: AuraText.body));
              return Column(
                children: top
                    .map(
                      (p) => Padding(
                        padding: EdgeInsets.only(bottom: AuraSpace.s10),
                        child: PostCard(post: p, compact: true),
                      ),
                    )
                    .toList(),
              );
            },
            loading: () => const _LoadingCard(),
            error: (e, _) => AuraCard(child: Text('Could not load feed: $e', style: AuraText.body)),
          ),

          SizedBox(height: AuraSpace.s18),
          _SectionTitle(title: 'Quiet tools'),
          SizedBox(height: AuraSpace.s10),
          const _ToolsRow(),
        ],
      ),
    );
  }
}

String _time(DateTime dt) {
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return 'at $hh:$mm';
}

String _friendlyDraftError(Object e) {
  if (e is DioException) {
    final status = e.response?.statusCode;
    if (status == 401) return 'Session expired. Tap to login and restore your draft.';
    return 'Could not restore draft (${status ?? 'no status'}). Tap to try again.';
  }
  return 'Could not restore draft. Tap to try again.';
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.onCompose, required this.onDiscover});
  final VoidCallback onCompose;
  final VoidCallback onDiscover;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      padding: EdgeInsets.all(AuraSpace.s18),
      child: SizedBox(
        height: 180,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('A place that holds what you write.', style: AuraText.title),
            SizedBox(height: AuraSpace.s8),
            Text(
              'Not a race. Not a feed. A correspondence table.',
              style: AuraText.muted.copyWith(height: 1.35),
            ),
            const Spacer(),
            Wrap(
              spacing: AuraSpace.s10,
              runSpacing: AuraSpace.s10,
              children: [
                FilledButton(onPressed: onCompose, child: const Text('Compose')),
                OutlinedButton(onPressed: onDiscover, child: const Text('Discover')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: AuraText.title);
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.all(AuraSpace.s12),
        child: const Center(child: CircularProgressIndicator()),
      );
}

class _ToolsRow extends StatelessWidget {
  const _ToolsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AuraCard(
            onTap: () => context.go('/updates'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Updates', style: AuraText.body.copyWith(fontWeight: FontWeight.w700)),
                SizedBox(height: AuraSpace.s6),
                Text('Batched, calm notifications.', style: AuraText.body),
              ],
            ),
          ),
        ),
        SizedBox(width: AuraSpace.s12),
        Expanded(
          child: AuraCard(
            onTap: () => context.go('/search'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Search', style: AuraText.body.copyWith(fontWeight: FontWeight.w700)),
                SizedBox(height: AuraSpace.s6),
                Text('Find authors and work by meaning.', style: AuraText.body),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
