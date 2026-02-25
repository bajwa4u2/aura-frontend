import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_providers.dart';
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

  final res = await dio.get('/posts/draft'); // interceptor will attach auth + refresh if needed
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
    final draftAsync =
        isAuthed ? ref.watch(draftProvider) : const AsyncValue<Map<String, dynamic>?>.data(null);

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
                        Text('Continue draft', style: AuraText.body.copyWith(fontWeight: FontWeight.w700)),
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
                  final mediaType = (draft['mediaType'] ?? 'NONE').toString().toUpperCase();
                  final hasMedia = mediaType == 'IMAGE' || mediaType == 'VIDEO';

                  // IMPORTANT: allow media-only drafts too
                  if (text.isEmpty && !hasMedia) return const SizedBox.shrink();

                  final updatedAtRaw = (draft['updatedAt'] ?? '').toString();
                  final dt = DateTime.tryParse(updatedAtRaw)?.toLocal();
                  final savedLine = dt == null ? 'Draft saved.' : 'Draft saved ${_time(dt)}.';

                  String preview;
                  if (text.isNotEmpty) {
                    preview = text.length <= 140 ? text : '${text.substring(0, 140)}…';
                  } else {
                    preview = mediaType == 'VIDEO'
                        ? 'Video draft (context optional).'
                        : 'Image draft (context optional).';
                  }

                  return Padding(
                    padding: EdgeInsets.only(bottom: AuraSpace.s10),
                    child: AuraCard(
                      onTap: () => _openCompose(context, ref),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Continue draft', style: AuraText.body.copyWith(fontWeight: FontWeight.w700)),
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
                          Text('Continue draft', style: AuraText.body.copyWith(fontWeight: FontWeight.w700)),
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
              final count = posts.length;

              // Header card: always clickable so "Saved" never feels dead.
              final header = AuraCard(
                onTap: () => context.push('/saved'),
                child: Row(
                  children: [
                    Text('Saved', style: AuraText.body.copyWith(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text('$count saved', style: AuraText.muted),
                    SizedBox(width: AuraSpace.s8),
                    const Icon(Icons.chevron_right, size: 18),
                  ],
                ),
              );

              if (posts.isEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    SizedBox(height: AuraSpace.s10),
                    AuraCard(
                      onTap: () => context.push('/saved'),
                      child: Text(
                        'Save something you want to return to. It will live here.',
                        style: AuraText.body,
                      ),
                    ),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  SizedBox(height: AuraSpace.s10),
                  ...posts.take(2).map(
                        (p) => Padding(
                          padding: EdgeInsets.only(bottom: AuraSpace.s10),
                          child: PostCard(post: p, compact: true),
                        ),
                      ),
                ],
              );
            },
            loading: () => const _LoadingCard(),
            error: (e, _) => AuraCard(child: Text('Could not load saved: $e', style: AuraText.body)),
          ),

          SizedBox(height: AuraSpace.s18),

          _SectionTitle(title: 'Latest'),
          SizedBox(height: AuraSpace.s10),

          // Latest feed rhythm pass:
          // - remove compact
          // - increase vertical breathing room
          feedAsync.when(
            data: (posts) {
              final top = posts.take(6).toList();
              if (top.isEmpty) return AuraCard(child: Text('No posts yet.', style: AuraText.body));
              return Column(
                children: top
                    .map(
                      (p) => Padding(
                        padding: EdgeInsets.only(bottom: AuraSpace.s18),
                        child: PostCard(post: p),
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

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.onCompose, required this.onDiscover});

  final VoidCallback onCompose;
  final VoidCallback onDiscover;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('A place where weight matters.', style: AuraText.body.copyWith(fontWeight: FontWeight.w700)),
          SizedBox(height: AuraSpace.s8),
          Text(
            'Write quietly. Read responsibly. Return to what you saved.',
            style: AuraText.body,
          ),
          SizedBox(height: AuraSpace.s12),
          Wrap(
            spacing: AuraSpace.s10,
            runSpacing: AuraSpace.s10,
            children: [
              OutlinedButton.icon(
                onPressed: onCompose,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Compose'),
              ),
              OutlinedButton.icon(
                onPressed: onDiscover,
                icon: const Icon(Icons.search),
                label: const Text('Discover'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: AuraText.body.copyWith(fontWeight: FontWeight.w800));
  }
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
            child: Row(
              children: [
                const Icon(Icons.article_outlined, size: 18),
                SizedBox(width: AuraSpace.s8),
                Text('Updates', style: AuraText.body),
              ],
            ),
          ),
        ),
        SizedBox(width: AuraSpace.s10),
        Expanded(
          child: AuraCard(
            onTap: () => context.go('/me'),
            child: Row(
              children: [
                const Icon(Icons.person_outline, size: 18),
                SizedBox(width: AuraSpace.s8),
                Text('Me', style: AuraText.body),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Row(
        children: [
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: AuraSpace.s10),
          Text('Loading…', style: AuraText.body),
        ],
      ),
    );
  }
}

String _time(DateTime dt) {
  final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final mm = dt.minute.toString().padLeft(2, '0');
  final ap = dt.hour >= 12 ? 'pm' : 'am';
  return '$h:$mm $ap';
}

String _friendlyDraftError(Object e) {
  if (e is DioException) {
    final code = e.response?.statusCode;
    if (code == 401) return 'Session expired. Tap to continue.';
    if (code == 403) return 'Please verify your email to continue.';
    return 'Could not load your draft. Tap to continue.';
  }
  return 'Could not load your draft. Tap to continue.';
}