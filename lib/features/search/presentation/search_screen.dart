import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aura/core/auth/session_providers.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../feed/domain/feed_item.dart' show FeedRouting;
import '../../feed/domain/post.dart';
import '../providers.dart';
import '../search_repository.dart';

final searchResultProvider = FutureProvider<SearchResult>((ref) async {
  final q = ref.watch(searchQueryProvider);

  if (q.trim().isEmpty) {
    return const SearchResult(users: [], institutions: [], posts: []);
  }

  final repo = ref.watch(searchRepositoryProvider);
  return repo.search(q);
});

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    // AXR-1 — governed tag taps arrive as /search?q=... ; seed the query
    // so the destination opens already showing the tag's results.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final q =
          GoRouterState.of(context).uri.queryParameters['q']?.trim() ?? '';
      if (q.isNotEmpty && ref.read(searchQueryProvider).isEmpty) {
        ref.read(searchQueryProvider.notifier).state = q;
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _syncControllerToQuery(String q) {
    if (_controller.text == q) return;
    _controller.text = q;
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(searchQueryProvider.notifier).state = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAuthed = ref.watch(isAuthedProvider);
    final q = ref.watch(searchQueryProvider);
    final results = ref.watch(searchResultProvider);

    _syncControllerToQuery(q);

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
          _SearchHeader(
            isAuthed: isAuthed,
            onSignIn: () => context.go('/login?redirect=%2Fsearch'),
          ),
          const SizedBox(height: AuraSpace.s16),
          _SearchInput(controller: _controller, onChanged: _onQueryChanged),
          const SizedBox(height: AuraSpace.s20),
          if (q.trim().isEmpty)
            _SearchEmptyPrompt(
              isAuthed: isAuthed,
              onSignIn: () => context.go('/login?redirect=%2Fsearch'),
            )
          else
            _SearchResults(results: results, q: q),
        ],
      ),
    );
  }
}

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({required this.isAuthed, required this.onSignIn});

  final bool isAuthed;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(
          child: Text('Discover', style: AuraText.headline),
        ),
        if (!isAuthed)
          AuraActionPill(
            icon: Icons.login_rounded,
            label: 'Sign in',
            onTap: onSignIn,
          ),
      ],
    );
  }
}

class _SearchInput extends StatelessWidget {
  const _SearchInput({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.r14),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: TextField(
        controller: controller,
        style: AuraText.body.copyWith(color: AuraSurface.ink),
        decoration: InputDecoration(
          hintText: 'Search creators, institutions, or work…',
          hintStyle: AuraText.body.copyWith(color: AuraSurface.faint),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: AuraSurface.muted,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s16,
            vertical: AuraSpace.s14,
          ),
        ),
        textInputAction: TextInputAction.search,
        onChanged: onChanged,
      ),
    );
  }
}

class _SearchEmptyPrompt extends StatelessWidget {
  const _SearchEmptyPrompt({required this.isAuthed, required this.onSignIn});

  final bool isAuthed;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SearchSectionLabel(label: 'What you can find'),
        const SizedBox(height: AuraSpace.s12),
        const _SearchHintRow(
          icon: Icons.person_outline_rounded,
          title: 'Creators',
          body: 'Profiles, handles, and public presence.',
        ),
        const SizedBox(height: AuraSpace.s8),
        const _SearchHintRow(
          icon: Icons.apartment_outlined,
          title: 'Institutions',
          body: 'Organizations in the public record.',
        ),
        const SizedBox(height: AuraSpace.s8),
        const _SearchHintRow(
          icon: Icons.article_outlined,
          title: 'Posts',
          body: 'Public discussion posts matching your terms.',
        ),
        if (!isAuthed) ...[
          const SizedBox(height: AuraSpace.s20),
          Container(
            padding: const EdgeInsets.all(AuraSpace.s16),
            decoration: BoxDecoration(
              color: AuraSurface.card,
              borderRadius: BorderRadius.circular(AuraRadius.card),
              border: Border.all(color: AuraSurface.divider),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Sign in to publish, respond, save, and follow.',
                    style: AuraText.small.copyWith(color: AuraSurface.muted),
                  ),
                ),
                const SizedBox(width: AuraSpace.s12),
                AuraActionPill(
                  icon: Icons.login_rounded,
                  label: 'Sign in',
                  onTap: onSignIn,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SearchHintRow extends StatelessWidget {
  const _SearchHintRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s14),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AuraSurface.subtle,
              borderRadius: BorderRadius.circular(AuraRadius.r10),
              border: Border.all(color: AuraSurface.divider),
            ),
            child: Icon(icon, size: 16, color: AuraSurface.muted),
          ),
          const SizedBox(width: AuraSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AuraText.small.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AuraSpace.s2),
                Text(
                  body,
                  style: AuraText.small.copyWith(color: AuraSurface.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.results, required this.q});

  final AsyncValue<SearchResult> results;
  final String q;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return results.when(
      data: (r) {
        final hasAny =
            r.users.isNotEmpty ||
            r.institutions.isNotEmpty ||
            r.posts.isNotEmpty;

        if (!hasAny) {
          return AuraEmptyState(
            title: 'No matches for "$q"',
            body:
                'Try a different name, handle, phrase, institution, or theme.',
            icon: Icons.search_off_rounded,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (r.users.isNotEmpty) ...[
              const _SearchSectionLabel(label: 'Creators'),
              const SizedBox(height: AuraSpace.s10),
              ...r.users.take(8).map((u) => _AuthorTile(u: u)),
              const SizedBox(height: AuraSpace.s20),
            ],
            if (r.institutions.isNotEmpty) ...[
              const _SearchSectionLabel(label: 'Institutions'),
              const SizedBox(height: AuraSpace.s10),
              ...r.institutions.take(8).map((i) => _InstitutionTile(i: i)),
              const SizedBox(height: AuraSpace.s20),
            ],
            if (r.posts.isNotEmpty) ...[
              const _SearchSectionLabel(label: 'Posts'),
              const SizedBox(height: AuraSpace.s10),
              ...r.posts.take(12).map((p) => _PostTile(p: p)),
            ],
          ],
        );
      },
      loading: () => const AuraLoadingState(message: 'Searching…'),
      error: (e, _) => const AuraErrorState(
        title: 'Search unavailable',
        body: 'Search could not be reached right now. Try again in a moment.',
      ),
    );
  }
}

class _SearchSectionLabel extends StatelessWidget {
  const _SearchSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: AuraText.label.copyWith(
        color: AuraSurface.faint,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _AuthorTile extends StatelessWidget {
  const _AuthorTile({required this.u});

  final Map<String, dynamic> u;

  @override
  Widget build(BuildContext context) {
    final handle = (u['handle'] ?? '').toString().trim();
    final name = (u['displayName'] ?? '').toString().trim();
    final bio = (u['bio'] ?? '').toString().trim();
    final avatarUrl = (u['avatarUrl'] ?? '').toString().trim();
    final display = name.isNotEmpty
        ? name
        : (handle.isNotEmpty ? handle : 'Author');

    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: handle.isEmpty
              ? null
              : () => context.push(FeedRouting.adaptProfileRoute(
                        '/u/$handle',
                        currentPath: GoRouterState.of(context).uri.path,
                      ) ??
                      '/u/$handle'),
          borderRadius: BorderRadius.circular(AuraRadius.card),
          child: Container(
            padding: const EdgeInsets.all(AuraSpace.s14),
            decoration: BoxDecoration(
              color: AuraSurface.card,
              borderRadius: BorderRadius.circular(AuraRadius.card),
              border: Border.all(color: AuraSurface.divider),
            ),
            child: Row(
              children: [
                AuraAvatar(
                  name: display,
                  imageUrl: avatarUrl.isEmpty ? null : avatarUrl,
                  size: 40,
                ),
                const SizedBox(width: AuraSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        display,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AuraText.body.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (handle.isNotEmpty)
                        Text(
                          '@$handle',
                          style: AuraText.small.copyWith(
                            color: AuraSurface.muted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (bio.isNotEmpty) ...[
                        const SizedBox(height: AuraSpace.s4),
                        Text(
                          bio,
                          style: AuraText.small.copyWith(
                            color: AuraSurface.muted,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AuraSurface.faint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InstitutionTile extends StatelessWidget {
  const _InstitutionTile({required this.i});

  final Map<String, dynamic> i;

  @override
  Widget build(BuildContext context) {
    final name = (i['name'] ?? '').toString().trim();
    final slug = (i['slug'] ?? '').toString().trim();
    final domain = (i['domain'] ?? '').toString().trim();
    final jurisdiction = (i['jurisdiction'] ?? '').toString().trim();
    final description = (i['description'] ?? '').toString().trim();
    final logoUrl = (i['logoUrl'] ?? '').toString().trim();

    final sublineParts = <String>[
      if (domain.isNotEmpty) domain,
      if (jurisdiction.isNotEmpty) jurisdiction,
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: slug.isEmpty
              ? null
              : () => context.push(FeedRouting.adaptProfileRoute(
                        '/institutions/$slug',
                        currentPath: GoRouterState.of(context).uri.path,
                      ) ??
                      '/institutions/$slug'),
          borderRadius: BorderRadius.circular(AuraRadius.card),
          child: Container(
            padding: const EdgeInsets.all(AuraSpace.s14),
            decoration: BoxDecoration(
              color: AuraSurface.card,
              borderRadius: BorderRadius.circular(AuraRadius.card),
              border: Border.all(color: AuraSurface.divider),
            ),
            child: Row(
              children: [
                // AXR-1 identity precedence — institution logo when the
                // institution has one; the building icon is the true
                // placeholder, not the first resort.
                Container(
                  width: 40,
                  height: 40,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AuraSurface.subtle,
                    borderRadius: BorderRadius.circular(AuraRadius.r10),
                    border: Border.all(color: AuraSurface.divider),
                  ),
                  child: logoUrl.isEmpty
                      ? const Icon(
                          Icons.apartment_outlined,
                          size: 20,
                          color: AuraSurface.muted,
                        )
                      : Image.network(
                          logoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.apartment_outlined,
                            size: 20,
                            color: AuraSurface.muted,
                          ),
                        ),
                ),
                const SizedBox(width: AuraSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isNotEmpty ? name : 'Institution',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AuraText.body.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (slug.isNotEmpty)
                        Text(
                          slug,
                          style: AuraText.small.copyWith(
                            color: AuraSurface.muted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (sublineParts.isNotEmpty) ...[
                        const SizedBox(height: AuraSpace.s4),
                        Text(
                          sublineParts.join(' · '),
                          style: AuraText.small.copyWith(
                            color: AuraSurface.muted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: AuraSpace.s4),
                        Text(
                          description,
                          style: AuraText.small.copyWith(
                            color: AuraSurface.muted,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AuraSurface.faint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PostTile extends StatelessWidget {
  const _PostTile({required this.p});

  final Post p;

  @override
  Widget build(BuildContext context) {
    final author = p.author;
    final handle = (author?.handle ?? '').trim();
    final name = (author?.displayName ?? '').trim();

    final byline = handle.isEmpty
        ? name
        : '@$handle${name.isNotEmpty ? ' · $name' : ''}';

    final text = p.text.trim();
    final preview = text.length <= 220 ? text : '${text.substring(0, 220)}…';

    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push(FeedRouting.adaptTargetRoute(
            '/posts/${p.id}',
            currentPath: GoRouterState.of(context).uri.path,
          )),
          borderRadius: BorderRadius.circular(AuraRadius.card),
          child: Container(
            padding: const EdgeInsets.all(AuraSpace.s14),
            decoration: BoxDecoration(
              color: AuraSurface.card,
              borderRadius: BorderRadius.circular(AuraRadius.card),
              border: Border.all(color: AuraSurface.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (byline.isNotEmpty) ...[
                  Text(
                    byline,
                    style: AuraText.small.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AuraSpace.s8),
                ],
                Text(
                  preview.isEmpty ? '—' : preview,
                  style: AuraText.body.copyWith(height: 1.45),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
