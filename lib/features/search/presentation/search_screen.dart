import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aura/core/auth/session_providers.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/aura_text_block.dart';
import '../../feed/domain/post.dart';
import '../providers.dart';
import '../search_repository.dart';

final searchResultProvider = FutureProvider<SearchResult>((ref) async {
  final q = ref.watch(searchQueryProvider);

  if (q.trim().isEmpty) {
    return const SearchResult(
      users: [],
      institutions: [],
      posts: [],
    );
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
    _controller.selection =
        TextSelection.collapsed(offset: _controller.text.length);
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(searchQueryProvider.notifier).state = value;
    });
  }

  Widget _authorCard(BuildContext context, Map<String, dynamic> u) {
    final handle = (u['handle'] ?? '').toString().trim();
    final name = (u['displayName'] ?? '').toString().trim();
    final bio = (u['bio'] ?? '').toString().trim();
    final avatarUrl = (u['avatarUrl'] ?? '').toString().trim();

    final display =
        name.isNotEmpty ? name : (handle.isNotEmpty ? handle : 'Author');

    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s10),
      child: AuraCard(
        onTap: handle.isEmpty ? null : () => context.push('/u/$handle'),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage:
                  avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
              backgroundColor: const Color(0x332E2A26),
              child: avatarUrl.isEmpty
                  ? Text(
                      display.isNotEmpty ? display[0].toUpperCase() : 'A',
                      style: AuraText.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
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
                    style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (handle.isNotEmpty)
                    Text(
                      '@$handle',
                      style: AuraText.muted,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (bio.isNotEmpty) ...[
                    const SizedBox(height: AuraSpace.s4),
                    Text(
                      bio,
                      style: AuraText.small,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Widget _institutionCard(BuildContext context, Map<String, dynamic> i) {
    final name = (i['name'] ?? '').toString().trim();
    final slug = (i['slug'] ?? '').toString().trim();
    final domain = (i['domain'] ?? '').toString().trim();
    final jurisdiction = (i['jurisdiction'] ?? '').toString().trim();
    final description = (i['description'] ?? '').toString().trim();

    final sublineParts = <String>[
      if (domain.isNotEmpty) domain,
      if (jurisdiction.isNotEmpty) jurisdiction,
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s10),
      child: AuraCard(
        onTap: slug.isEmpty ? null : () => context.push('/institutions/$slug'),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 20,
              backgroundColor: Color(0x332E2A26),
              child: Icon(Icons.apartment_outlined),
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
                    style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (slug.isNotEmpty)
                    Text(
                      slug,
                      style: AuraText.muted,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (sublineParts.isNotEmpty) ...[
                    const SizedBox(height: AuraSpace.s4),
                    Text(
                      sublineParts.join(' • '),
                      style: AuraText.small,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: AuraSpace.s4),
                    Text(
                      description,
                      style: AuraText.small,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Widget _postCard(BuildContext context, Post p) {
    final author = p.author;
    final handle = (author?.handle ?? '').trim();
    final name = (author?.displayName ?? '').trim();

    final byline =
        handle.isEmpty ? name : '@$handle${name.isNotEmpty ? ' • $name' : ''}';

    final text = p.text.trim();
    final preview = text.length <= 220 ? text : '${text.substring(0, 220)}…';

    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s10),
      child: AuraCard(
        onTap: () => context.push('/posts/${p.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (byline.isNotEmpty)
              AuraTextBlock(
                byline,
                style: AuraText.small.copyWith(fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (byline.isNotEmpty) const SizedBox(height: AuraSpace.s8),
            AuraTextBlock(
              preview.isEmpty ? '—' : preview,
              style: AuraText.body.copyWith(height: 1.45),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchInput() {
    return AuraCard(
      child: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          hintText: 'Search people, institutions, or public work…',
          border: InputBorder.none,
          prefixIcon: Icon(Icons.search),
        ),
        textInputAction: TextInputAction.search,
        onChanged: _onQueryChanged,
      ),
    );
  }

  Widget _publicIntroCard(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Explore public work',
            style: AuraText.title,
          ),
          const SizedBox(height: AuraSpace.s10),
          Text(
            'Search is open so anyone can discover creators, institutions, and work already present in Aura.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s14),
          Text(
            'Create an account when you are ready to publish, respond, save, and build your own record.',
            style: AuraText.small.copyWith(
              color: AuraSurface.muted,
            ),
          ),
          const SizedBox(height: AuraSpace.s16),
          Wrap(
            spacing: AuraSpace.s10,
            runSpacing: AuraSpace.s10,
            children: [
              FilledButton(
                onPressed: () => context.go('/register?redirect=%2Fsearch'),
                child: const Text('Start Publishing'),
              ),
              OutlinedButton(
                onPressed: () => context.go('/login?redirect=%2Fsearch'),
                child: const Text('Login'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptySearchCard() {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Search the public record',
            style: AuraText.title,
          ),
          const SizedBox(height: AuraSpace.s10),
          Text(
            'Start with a name, handle, institution, phrase, or theme.',
            style: AuraText.body,
          ),
        ],
      ),
    );
  }

  Widget _searchResults(AsyncValue<SearchResult> results) {
    return results.when(
      data: (r) {
        final hasAny =
            r.users.isNotEmpty || r.institutions.isNotEmpty || r.posts.isNotEmpty;

        if (!hasAny) {
          return AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No matches yet.', style: AuraText.title),
                const SizedBox(height: AuraSpace.s10),
                Text(
                  'Try a different name, phrase, handle, or institution.',
                  style: AuraText.body,
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (r.users.isNotEmpty) ...[
              const _SectionHeader(
                title: 'Authors',
                subtitle: 'People publishing through Aura.',
              ),
              const SizedBox(height: AuraSpace.s10),
              ...r.users.take(8).map((u) => _authorCard(context, u)),
              const SizedBox(height: AuraSpace.s18),
            ],
            if (r.institutions.isNotEmpty) ...[
              const _SectionHeader(
                title: 'Institutions',
                subtitle: 'Organizations present in the public record.',
              ),
              const SizedBox(height: AuraSpace.s10),
              ...r.institutions.take(8).map((i) => _institutionCard(context, i)),
              const SizedBox(height: AuraSpace.s18),
            ],
            if (r.posts.isNotEmpty) ...[
              const _SectionHeader(
                title: 'Public Work',
                subtitle: 'Writing and creations matching your search.',
              ),
              const SizedBox(height: AuraSpace.s10),
              ...r.posts.take(12).map((p) => _postCard(context, p)),
            ],
          ],
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => AuraCard(
        child: Text('Search failed: $e', style: AuraText.body),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAuthed = ref.watch(isAuthedProvider);
    final q = ref.watch(searchQueryProvider);

    _syncControllerToQuery(q);

    if (!isAuthed) {
      final publicResults = ref.watch(searchResultProvider);

      return AuraScaffold(
        title: 'Search',
        actions: [
          TextButton(
            onPressed: () => context.go('/login?redirect=%2Fsearch'),
            child: const Text('Login'),
          ),
        ],
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            AuraSpace.s16,
            AuraSpace.s12,
            AuraSpace.s16,
            AuraSpace.s24,
          ),
          children: [
            _searchInput(),
            const SizedBox(height: AuraSpace.s14),
            _publicIntroCard(context),
            const SizedBox(height: AuraSpace.s14),
            if (q.trim().isEmpty) _emptySearchCard() else _searchResults(publicResults),
          ],
        ),
      );
    }

    final results = ref.watch(searchResultProvider);

    return AuraScaffold(
      title: 'Search',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AuraSpace.s16,
          AuraSpace.s12,
          AuraSpace.s16,
          AuraSpace.s24,
        ),
        children: [
          _searchInput(),
          const SizedBox(height: AuraSpace.s14),
          if (q.trim().isEmpty) _emptySearchCard() else _searchResults(results),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AuraText.title),
        const SizedBox(height: AuraSpace.s8),
        Text(subtitle, style: AuraText.muted),
      ],
    );
  }
}
