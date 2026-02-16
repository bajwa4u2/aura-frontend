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

Map<String, dynamic> _asMap(dynamic v) {
  if (v is Map) return Map<String, dynamic>.from(v as Map);
  throw Exception('Unexpected response');
}

List<Map<String, dynamic>> _asListOfMaps(dynamic v) {
  if (v is List) return v.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  throw Exception('Unexpected response');
}

/// Some endpoints return { data: ... }. Some return raw data.
/// This helper unwraps when needed.
dynamic _unwrapData(dynamic v) {
  if (v is Map && v['data'] != null) return v['data'];
  return v;
}

final meProfileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.read(dioProvider);

  // Canonical backend route is /auth/me. It returns { data: user }.
  final res = await dio.get('/auth/me');
  final body = _unwrapData(res.data);
  return _asMap(body);
});

final _meDraftProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/posts/draft');
  final body = _unwrapData(res.data);
  return _asMap(body);
});

final _mePostsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/posts/me');
  final body = _unwrapData(res.data);
  return _asListOfMaps(body);
});

final _meSavesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/saves/me');
  final body = _unwrapData(res.data);
  return _asListOfMaps(body);
});

final _meRepliesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.read(dioProvider);

  // Locked by backend: GET /v1/replies/me
  final res = await dio.get('/replies/me');

  // Service returns { data: [...], nextCursor }. unwrapData() yields the list.
  final body = _unwrapData(res.data);
  return _asListOfMaps(body);
});

class MeScreen extends ConsumerStatefulWidget {
  const MeScreen({super.key});

  @override
  ConsumerState<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends ConsumerState<MeScreen> {
  Future<void> _editProfile({
    required BuildContext context,
    required String? displayName,
    required String? bio,
  }) async {
    final nameCtl = TextEditingController(text: displayName ?? '');
    final bioCtl = TextEditingController(text: bio ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit profile'),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtl,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AuraSpace.s12),
              TextField(
                controller: bioCtl,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Bio',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final dio = ref.read(dioProvider);
    await dio.put(
      '/users/me',
      data: {
        'displayName': nameCtl.text.trim().isEmpty ? null : nameCtl.text.trim(),
        'bio': bioCtl.text.trim().isEmpty ? null : bioCtl.text.trim(),
      },
    );

    ref.invalidate(meProfileProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved.')));
  }

  Future<void> _editDraft(BuildContext context, String initial) async {
    final ctl = TextEditingController(text: initial);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit draft'),
        content: SizedBox(
          width: 640,
          child: TextField(
            controller: ctl,
            maxLines: 12,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Save')),
        ],
      ),
    );

    if (ok != true) return;

    final dio = ref.read(dioProvider);
    await dio.put('/posts/draft', data: {'text': ctl.text});
    ref.invalidate(_meDraftProvider);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft saved.')));
  }

  Future<void> _discardDraft(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard draft?'),
        content: const Text('This will delete your current draft.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Discard')),
        ],
      ),
    );

    if (ok != true) return;

    final dio = ref.read(dioProvider);
    await dio.delete('/posts/draft');
    ref.invalidate(_meDraftProvider);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft discarded.')));
  }

  Future<void> _editPost({
    required BuildContext context,
    required String id,
    required String initialText,
  }) async {
    final ctl = TextEditingController(text: initialText);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit post'),
        content: SizedBox(
          width: 640,
          child: TextField(
            controller: ctl,
            maxLines: 10,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Save')),
        ],
      ),
    );

    if (ok != true) return;

    final dio = ref.read(dioProvider);
    await dio.patch('/posts/$id', data: {'text': ctl.text.trim()});
    ref.invalidate(_mePostsProvider);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Updated.')));
  }

  Future<void> _archivePost(String id) async {
    final dio = ref.read(dioProvider);
    await dio.post('/posts/$id/archive');
    ref.invalidate(_mePostsProvider);
  }

  Future<void> _deletePost(String id) async {
    final dio = ref.read(dioProvider);
    await dio.delete('/posts/$id');
    ref.invalidate(_mePostsProvider);
  }

  // LOCKED: Replies are posts. Edit/delete replies via /posts/:id.
  Future<void> _editReply({
    required BuildContext context,
    required String id,
    required String initialText,
  }) async {
    final ctl = TextEditingController(text: initialText);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit reply'),
        content: SizedBox(
          width: 640,
          child: TextField(
            controller: ctl,
            maxLines: 10,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Save')),
        ],
      ),
    );

    if (ok != true) return;

    final dio = ref.read(dioProvider);
    await dio.patch('/posts/$id', data: {'text': ctl.text.trim()});

    ref.invalidate(_meRepliesProvider);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Updated.')));
  }

  Future<void> _deleteReply(String id) async {
    final dio = ref.read(dioProvider);
    await dio.delete('/posts/$id');
    ref.invalidate(_meRepliesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final isAuthed = ref.watch(isAuthedProvider);

    if (!isAuthed) {
      return AuraScaffold(
        title: 'Aura',
        showHomeAction: true,
        body: ListView(
          padding: const EdgeInsets.fromLTRB(AuraSpace.s16, AuraSpace.s12, AuraSpace.s16, AuraSpace.s24),
          children: [
            AuraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Not signed in', style: AuraText.title),
                  const SizedBox(height: AuraSpace.s10),
                  Text(
                    'Login to access your profile, drafts, posts, saves, and replies.',
                    style: AuraText.body,
                  ),
                  const SizedBox(height: AuraSpace.s16),
                  Wrap(
                    spacing: AuraSpace.s10,
                    runSpacing: AuraSpace.s10,
                    children: [
                      FilledButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('Login'),
                      ),
                      OutlinedButton(
                        onPressed: () => context.go('/register'),
                        child: const Text('Create account'),
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

    final meAsync = ref.watch(meProfileProvider);

    return AuraScaffold(
      title: 'Me',
      showHomeAction: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AuraSpace.s16, AuraSpace.s12, AuraSpace.s16, AuraSpace.s24),
        children: [
          meAsync.when(
            loading: () => const AuraCard(child: _LoadingBlock()),
            error: (e, _) => AuraCard(child: _ErrorBlock(message: '$e')),
            data: (me) {
              final handle = (me['handle'] ?? '').toString();
              final displayName = (me['displayName'] ?? '').toString();
              final bio = (me['bio'] ?? '').toString();
              final email = (me['email'] ?? '').toString();

              return AuraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName.isEmpty ? '@$handle' : displayName, style: AuraText.title),
                    const SizedBox(height: AuraSpace.s8),
                    if (handle.isNotEmpty) Text('@$handle', style: AuraText.muted),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: AuraSpace.s6),
                      Text(email, style: AuraText.muted),
                    ],
                    if (bio.isNotEmpty) ...[
                      const SizedBox(height: AuraSpace.s12),
                      Text(bio, style: AuraText.body),
                    ],
                    const SizedBox(height: AuraSpace.s16),
                    Wrap(
                      spacing: AuraSpace.s10,
                      runSpacing: AuraSpace.s10,
                      children: [
                        OutlinedButton(
                          onPressed: () => _editProfile(
                            context: context,
                            displayName: me['displayName']?.toString(),
                            bio: me['bio']?.toString(),
                          ),
                          child: const Text('Edit profile'),
                        ),
                        OutlinedButton(
                          onPressed: () => context.push('/settings'),
                          child: const Text('Settings'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: AuraSpace.s16),
          Text('Draft', style: AuraText.title),
          const SizedBox(height: AuraSpace.s10),
          ref.watch(_meDraftProvider).when(
                loading: () => const AuraCard(child: _LoadingBlock()),
                error: (e, _) => AuraCard(child: _ErrorBlock(message: '$e')),
                data: (draft) {
                  final id = (draft['id'] ?? '').toString();
                  final text = (draft['text'] ?? '').toString();

                  return _ItemCard(
                    title: 'Current draft',
                    subtitle: id.isEmpty ? '—' : id,
                    text: text.isEmpty ? '(empty)' : text,
                    onOpen: null,
                    actions: [
                      _ItemAction(label: 'Edit', onTap: () => _editDraft(context, text)),
                      _ItemAction(label: 'Discard', destructive: true, onTap: () => _discardDraft(context)),
                    ],
                  );
                },
              ),

          const SizedBox(height: AuraSpace.s20),
          Text('Posts', style: AuraText.title),
          const SizedBox(height: AuraSpace.s10),
          ref.watch(_mePostsProvider).when(
                loading: () => const AuraCard(child: _LoadingBlock()),
                error: (e, _) => AuraCard(child: _ErrorBlock(message: '$e')),
                data: (items) {
                  if (items.isEmpty) return const AuraCard(child: Text('No posts yet.'));

                  return Column(
                    children: [
                      for (final it in items) ...[
                        _ItemCard(
                          title: (it['status'] ?? 'Post').toString(),
                          subtitle: (it['id'] ?? '').toString(),
                          text: (it['text'] ?? '').toString(),
                          onOpen: () {
                            final id = (it['id'] ?? '').toString();
                            if (id.isNotEmpty) context.push('/post/$id');
                          },
                          actions: [
                            _ItemAction(
                              label: 'Edit',
                              onTap: () => _editPost(
                                context: context,
                                id: (it['id'] ?? '').toString(),
                                initialText: (it['text'] ?? '').toString(),
                              ),
                            ),
                            _ItemAction(label: 'Archive', onTap: () => _archivePost((it['id'] ?? '').toString())),
                            _ItemAction(label: 'Delete', destructive: true, onTap: () => _deletePost((it['id'] ?? '').toString())),
                          ],
                        ),
                        const SizedBox(height: AuraSpace.s12),
                      ],
                    ],
                  );
                },
              ),

          const SizedBox(height: AuraSpace.s20),
          Text('Saves', style: AuraText.title),
          const SizedBox(height: AuraSpace.s10),
          ref.watch(_meSavesProvider).when(
                loading: () => const AuraCard(child: _LoadingBlock()),
                error: (e, _) => AuraCard(child: _ErrorBlock(message: '$e')),
                data: (items) {
                  if (items.isEmpty) return const AuraCard(child: Text('No saves yet.'));

                  return Column(
                    children: [
                      for (final it in items) ...[
                        _ItemCard(
                          title: 'Saved',
                          subtitle: (it['postId'] ?? it['id'] ?? '').toString(),
                          text: (it['text'] ?? '').toString(),
                          onOpen: () {
                            final postId = (it['postId'] ?? '').toString();
                            if (postId.isNotEmpty) context.push('/post/$postId');
                          },
                          actions: const [],
                        ),
                        const SizedBox(height: AuraSpace.s12),
                      ],
                    ],
                  );
                },
              ),

          const SizedBox(height: AuraSpace.s20),
          Text('Replies', style: AuraText.title),
          const SizedBox(height: AuraSpace.s10),
          ref.watch(_meRepliesProvider).when(
                loading: () => const AuraCard(child: _LoadingBlock()),
                error: (e, _) => AuraCard(child: _ErrorBlock(message: '$e')),
                data: (items) {
                  if (items.isEmpty) return const AuraCard(child: Text('No replies yet.'));

                  return Column(
                    children: [
                      for (final it in items) ...[
                        _ItemCard(
                          title: 'Reply',
                          subtitle: (it['id'] ?? '').toString(),
                          text: (it['text'] ?? '').toString(),
                          onOpen: () {
                            final postId = (it['postId'] ?? it['replyToPostId'] ?? '').toString();
                            if (postId.isNotEmpty) context.push('/post/$postId');
                          },
                          actions: [
                            _ItemAction(
                              label: 'Edit',
                              onTap: () => _editReply(
                                context: context,
                                id: (it['id'] ?? '').toString(),
                                initialText: (it['text'] ?? '').toString(),
                              ),
                            ),
                            _ItemAction(label: 'Delete', destructive: true, onTap: () => _deleteReply((it['id'] ?? '').toString())),
                          ],
                        ),
                        const SizedBox(height: AuraSpace.s12),
                      ],
                    ],
                  );
                },
              ),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.title,
    required this.subtitle,
    required this.text,
    required this.actions,
    this.onOpen,
  });

  final String title;
  final String subtitle;
  final String text;
  final List<_ItemAction> actions;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: AuraText.title)),
              if (onOpen != null)
                TextButton(
                  onPressed: onOpen,
                  child: const Text('Open'),
                ),
            ],
          ),
          const SizedBox(height: AuraSpace.s6),
          Text(subtitle, style: AuraText.muted),
          const SizedBox(height: AuraSpace.s12),
          Text(text, style: AuraText.body),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s14),
            Wrap(
              spacing: AuraSpace.s10,
              runSpacing: AuraSpace.s10,
              children: [
                for (final a in actions)
                  OutlinedButton(
                    onPressed: a.onTap,
                    style: a.destructive ? OutlinedButton.styleFrom(foregroundColor: Colors.red) : null,
                    child: Text(a.label),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemAction {
  const _ItemAction({required this.label, required this.onTap, this.destructive = false});
  final String label;
  final VoidCallback onTap;
  final bool destructive;
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AuraSpace.s16),
      child: Row(
        children: [
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: AuraSpace.s12),
          Text('Loading…', style: AuraText.muted),
        ],
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AuraSpace.s16),
      child: Text(message, style: AuraText.body),
    );
  }
}
