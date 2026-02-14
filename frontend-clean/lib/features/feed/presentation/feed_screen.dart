import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_providers.dart';
import '../providers.dart';
import '../../posts/presentation/compose_screen.dart';
import '../domain/post.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    final cur = _scroll.position.pixels;
    if (max <= 0) return;

    if (cur >= max - 240) {
      ref.read(feedControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAuthed = ref.watch(isAuthedProvider);
    final feed = ref.watch(feedControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aura'),
        actions: [
          IconButton(
            tooltip: isAuthed ? 'Logout' : 'Login',
            icon: Icon(isAuthed ? Icons.logout : Icons.login),
            onPressed: () async {
              if (isAuthed) {
                await ref.read(authControllerProvider).logout();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logged out')));
                }
              } else {
                // Minimal quick login route: you already have a LoginScreen in your project.
                // Keep this screen clean. Wire navigation in your router layer.
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Open your Login screen from router/menu')),
                );
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: isAuthed
            ? () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ComposeScreen()),
                );
                // After posting, reload feed (simple + stable)
                await ref.read(feedControllerProvider.notifier).loadInitial();
              }
            : null,
        child: const Icon(Icons.edit),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(feedControllerProvider.notifier).loadInitial(),
        child: _buildBody(context, feed),
      ),
    );
  }

  Widget _buildBody(BuildContext context, FeedState feed) {
    if (feed.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (feed.error != null && feed.items.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.cloud_off, size: 42),
          const SizedBox(height: 12),
          Center(child: Text('Could not load feed.\n${feed.error}', textAlign: TextAlign.center)),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton(
              onPressed: () => ref.read(feedControllerProvider.notifier).loadInitial(),
              child: const Text('Retry'),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: feed.items.length + 1,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        if (i == feed.items.length) {
          if (feed.isLoadingMore) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return const SizedBox(height: 72);
        }

        final p = feed.items[i];
        return _PostTile(post: p);
      },
    );
  }
}

class _PostTile extends StatelessWidget {
  const _PostTile({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final ts = '${post.createdAt.toLocal()}'.split('.').first;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            post.text,
            style: const TextStyle(fontSize: 16, height: 1.35),
          ),
          const SizedBox(height: 10),
          Text(
            ts,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
