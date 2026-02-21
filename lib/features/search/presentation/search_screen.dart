import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../../posts/presentation/widgets/post_card.dart';
import '../providers.dart';
import '../search_repository.dart';

final searchResultProvider = FutureProvider<SearchResult>((ref) async {
  final q = ref.watch(searchQueryProvider);
  if (q.trim().isEmpty) return SearchResult(users: const [], posts: const []);
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

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncControllerToQuery(String q) {
    // Keep the input stable when coming back to this screen.
    if (_controller.text == q) return;
    _controller.text = q;
    _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
  }

  @override
  Widget build(BuildContext context) {
    final isAuthed = ref.watch(isAuthedProvider);
    final q = ref.watch(searchQueryProvider);
    _syncControllerToQuery(q);

    // Public-safe version: allow typing, but gate results behind auth.
    if (!isAuthed) {
      return AuraScaffold(
        title: 'Search',
        actions: [
          TextButton(
            onPressed: () => context.go('/login?redirect=%2Fsearch'),
            child: const Text('Login'),
          ),
        ],
        body: ListView(
          padding: EdgeInsets.fromLTRB(AuraSpace.s16, AuraSpace.s12, AuraSpace.s16, AuraSpace.s24),
          children: [
            AuraCard(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Search authors or work…',
                  border: InputBorder.none,
                ),
                onChanged: (v) => ref.read(searchQueryProvider.notifier).state = v,
              ),
            ),
            SizedBox(height: AuraSpace.s14),
            AuraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Search becomes real after login.', style: AuraText.title),
                  SizedBox(height: AuraSpace.s10),
                  Text(
                    'Aura keeps discovery tied to identity. This protects writers and prevents anonymous scraping.',
                    style: AuraText.body,
                  ),
                  SizedBox(height: AuraSpace.s16),
                  Wrap(
                    spacing: AuraSpace.s10,
                    runSpacing: AuraSpace.s10,
                    children: [
                      FilledButton(
                        onPressed: () => context.go('/register?redirect=%2Fsearch'),
                        child: const Text('Create account'),
                      ),
                      OutlinedButton(
                        onPressed: () => context.go('/login?redirect=%2Fsearch'),
                        child: const Text('Login'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Authenticated: full search (only watch results here).
    final results = ref.watch(searchResultProvider);

    return AuraScaffold(
      title: 'Search',
      body: ListView(
        padding: EdgeInsets.fromLTRB(AuraSpace.s16, AuraSpace.s12, AuraSpace.s16, AuraSpace.s24),
        children: [
          AuraCard(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Search authors or work…',
                border: InputBorder.none,
              ),
              onChanged: (v) => ref.read(searchQueryProvider.notifier).state = v,
            ),
          ),
          SizedBox(height: AuraSpace.s14),
          if (q.trim().isEmpty)
            AuraCard(
              child: Text('Start with a name, a phrase, or a theme.', style: AuraText.body),
            )
          else
            results.when(
              data: (r) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (r.users.isNotEmpty) ...[
                    Text('Authors', style: AuraText.title),
                    SizedBox(height: AuraSpace.s10),
                    ...r.users.take(6).whereType<Map>().map((u) {
                      final handle = (u['handle'] ?? '').toString();
                      final name = (u['displayName'] ?? handle).toString();
                      return Padding(
                        padding: EdgeInsets.only(bottom: AuraSpace.s10),
                        child: AuraCard(
                          onTap: handle.isEmpty ? null : () => context.push('/u/$handle'),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: const Color(0x332E2A26),
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'A',
                                  style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              SizedBox(width: AuraSpace.s12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: AuraText.body.copyWith(fontWeight: FontWeight.w700)),
                                    Text('@$handle', style: AuraText.muted),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                        ),
                      );
                    }),
                    SizedBox(height: AuraSpace.s18),
                  ],
                  Text('Work', style: AuraText.title),
                  SizedBox(height: AuraSpace.s10),
                  if (r.posts.isEmpty)
                    AuraCard(child: Text('No matches yet.', style: AuraText.body))
                  else
                    ...r.posts.take(12).map(
                          (p) => Padding(
                            padding: EdgeInsets.only(bottom: AuraSpace.s10),
                            child: PostCard(post: p, compact: true),
                          ),
                        ),
                ],
              ),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => AuraCard(child: Text('Search failed: $e', style: AuraText.body)),
            ),
        ],
      ),
    );
  }
}
