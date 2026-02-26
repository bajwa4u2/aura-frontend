import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/auth_providers.dart';
import 'package:aura/core/auth/session_providers.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';

Map<String, dynamic> _unwrapMap(dynamic raw) {
  if (raw is! Map) return <String, dynamic>{};
  final root = Map<String, dynamic>.from(raw);

  dynamic inner = root['data'];

  // { ok:true, data:{ data:{...} } } case
  if (inner is Map && inner['data'] is Map) {
    inner = inner['data'];
  }

  if (inner is Map) return Map<String, dynamic>.from(inner);
  return root;
}

List<Map<String, dynamic>> _unwrapItems(dynamic raw) {
  // Accept direct list
  if (raw is List) {
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  // Accept envelope map
  final m = _unwrapMap(raw);

  // Most common: { items: [], nextCursor: ... }
  final a = m['items'];
  if (a is List) {
    return a.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  // Some endpoints: { data: [], nextCursor: ... } inside data envelope
  final b = m['data'];
  if (b is List) {
    return b.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  // Sometimes: { data: { items:[...] } } already handled by _unwrapMap but keep fallback
  if (b is Map && b['items'] is List) {
    final list = b['items'] as List;
    return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  return <Map<String, dynamic>>[];
}

final meProfileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/users/me');
  final m = _unwrapMap(res.data);
  // If backend returned { ok:true, data:{...} } then m is the user map.
  // If backend returned something else, still return map to avoid crashing.
  return m;
});

final _meDraftProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/posts/draft');
  final m = _unwrapMap(res.data);

  // Draft route might return null or {} depending on backend; normalize.
  return m;
});

final _mePostsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/posts/mine');
  return _unwrapItems(res.data);
});

final _meSavesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/saves', queryParameters: {'limit': 12});
  return _unwrapItems(res.data);
});

final _meRepliesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/replies/mine');
  return _unwrapItems(res.data);
});

class MeScreen extends ConsumerStatefulWidget {
  const MeScreen({super.key});

  @override
  ConsumerState<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends ConsumerState<MeScreen> {
  bool _busyLogout = false;

  String _absoluteAvatarUrl({required String baseUrl, required String avatarUrl}) {
    final u = avatarUrl.trim();
    if (u.isEmpty) return '';
    if (u.startsWith('http://') || u.startsWith('https://')) return u;

    // Dio baseUrl includes /v1
    final root = baseUrl.replaceAll(RegExp(r'/?$'), '');
    if (u.startsWith('/')) return '$root$u';
    return '$root/$u';
  }

  Future<void> _pickAndUploadAvatar(BuildContext context) async {
    final picker = ImagePicker();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final dio = ref.read(dioProvider);

      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: picked.name.isNotEmpty ? picked.name : 'avatar.jpg',
        ),
      });

      final res = await dio.post('/uploads/avatar', data: form);
      final data = res.data;

      String? url;
      if (data is Map) {
        final m = Map<String, dynamic>.from(data);
        url = (m['url'] ?? m['avatarUrl'] ?? m['path'])?.toString();
      }

      if (url == null || url.trim().isEmpty) {
        if (!mounted) return;
        messenger.showSnackBar(const SnackBar(content: Text('Upload succeeded but no URL returned.')));
        return;
      }

      // Store avatarUrl on user
      await dio.patch(
        '/users/me',
        data: {'avatarUrl': url.trim()},
      );

      ref.invalidate(meProfileProvider);

      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Photo updated.')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
  }

  Future<void> _editProfile({
    required BuildContext context,
    required String? displayName,
    required String? bio,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
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

    // CLEAR-TO-NULL behavior:
    final dn = nameCtl.text.trim();
    final bb = bioCtl.text.trim();

    await dio.patch(
      '/users/me',
      data: {
        'displayName': dn.isEmpty ? null : dn,
        'bio': bb.isEmpty ? null : bb,
      },
    );

    ref.invalidate(meProfileProvider);
    if (!mounted) return;
    messenger.showSnackBar(const SnackBar(content: Text('Saved.')));
  }

  Future<void> _editDraft(BuildContext context, String initial) async {
    final messenger = ScaffoldMessenger.of(context);
    final ctl = TextEditingController(text: initial);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit draft'),
        content: SizedBox(
          width: 560,
          child: TextField(
            controller: ctl,
            maxLines: 10,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Write…',
            ),
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
    await dio.put('/posts/draft', data: {'text': ctl.text});

    ref.invalidate(_meDraftProvider);
    if (!mounted) return;
    messenger.showSnackBar(const SnackBar(content: Text('Draft saved.')));
  }

  Future<void> _discardDraft(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
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
    messenger.showSnackBar(const SnackBar(content: Text('Draft discarded.')));
  }

  Future<void> _editPost({
    required BuildContext context,
    required String id,
    required String initialText,
  }) async {
    if (id.trim().isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);

    final ctl = TextEditingController(text: initialText);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit post'),
        content: SizedBox(
          width: 560,
          child: TextField(
            controller: ctl,
            maxLines: 10,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
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
    await dio.patch('/posts/$id', data: {'text': ctl.text});

    ref.invalidate(_mePostsProvider);
    if (!mounted) return;
    messenger.showSnackBar(const SnackBar(content: Text('Post updated.')));
  }

  Future<void> _archivePost(String id) async {
    if (id.trim().isEmpty) return;
    final dio = ref.read(dioProvider);
    await dio.post('/posts/$id/archive');
    ref.invalidate(_mePostsProvider);
  }

  Future<void> _logout(BuildContext context) async {
    if (_busyLogout) return;

    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to log in again to access your account.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Log out')),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _busyLogout = true);

    try {
      final dio = ref.read(dioProvider);
      final tokenStore = ref.read(tokenStoreProvider);

      // Best effort: tell backend to revoke refresh token if we have it.
      final rt = (tokenStore.refreshToken ?? '').trim();
      try {
        if (rt.isNotEmpty) {
          await dio.post('/auth/logout', data: {'refreshToken': rt});
        } else {
          await dio.post('/auth/logout');
        }
      } catch (_) {}

      await tokenStore.clear();

      // Clear any cached “Me” views.
      ref.invalidate(meProfileProvider);
      ref.invalidate(_meDraftProvider);
      ref.invalidate(_mePostsProvider);
      ref.invalidate(_meSavesProvider);
      ref.invalidate(_meRepliesProvider);

      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Logged out.')));
      router.go('/login');
    } finally {
      if (mounted) setState(() => _busyLogout = false);
    }
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

              final dio = ref.read(dioProvider);
              final baseUrl = dio.options.baseUrl.toString();
              final avatarRaw = (me['avatarUrl'] ?? '').toString();
              final avatarUrl = _absoluteAvatarUrl(baseUrl: baseUrl, avatarUrl: avatarRaw);

              return AuraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 34,
                          backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                          child: avatarUrl.isEmpty ? const Icon(Icons.person, size: 34) : null,
                        ),
                        const SizedBox(width: AuraSpace.s16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(displayName.isEmpty ? '@$handle' : displayName, style: AuraText.title),
                              const SizedBox(height: AuraSpace.s6),
                              if (handle.isNotEmpty) Text('@$handle', style: AuraText.muted),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AuraSpace.s10),
                    TextButton(
                      onPressed: () => _pickAndUploadAvatar(context),
                      child: const Text('Change photo'),
                    ),
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
                          onPressed: _busyLogout ? null : () => _logout(context),
                          child: Text(_busyLogout ? 'Logging out…' : 'Log out'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: AuraSpace.s14),

          // Draft card
          Consumer(
            builder: (context, ref, _) {
              final draftAsync = ref.watch(_meDraftProvider);
              return draftAsync.when(
                loading: () => const AuraCard(child: _LoadingBlock()),
                error: (e, _) => AuraCard(child: _ErrorBlock(message: '$e')),
                data: (raw) {
                  final m = _unwrapMap(raw);
                  final inner = (m['data'] is Map) ? Map<String, dynamic>.from(m['data'] as Map) : m;
                  final text = (inner['text'] ?? m['text'] ?? '').toString();

                  return AuraCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Draft', style: AuraText.title),
                        const SizedBox(height: AuraSpace.s10),
                        Text(text.isEmpty ? 'No draft yet.' : text, style: AuraText.body),
                        const SizedBox(height: AuraSpace.s12),
                        Wrap(
                          spacing: AuraSpace.s10,
                          runSpacing: AuraSpace.s10,
                          children: [
                            FilledButton(
                              onPressed: () => _editDraft(context, text),
                              child: const Text('Edit draft'),
                            ),
                            OutlinedButton(
                              onPressed: () => _discardDraft(context),
                              child: const Text('Discard'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),

          const SizedBox(height: AuraSpace.s14),

          // Posts card
          Consumer(
            builder: (context, ref, _) {
              final postsAsync = ref.watch(_mePostsProvider);
              return postsAsync.when(
                loading: () => const AuraCard(child: _LoadingBlock()),
                error: (e, _) => AuraCard(child: _ErrorBlock(message: '$e')),
                data: (items) {
                  return AuraCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Posts', style: AuraText.title),
                        const SizedBox(height: AuraSpace.s10),
                        if (items.isEmpty)
                          Text('No posts yet.', style: AuraText.body)
                        else
                          ...items.take(5).map((p) {
                            final id = (p['id'] ?? '').toString();
                            final text = (p['text'] ?? '').toString();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: AuraSpace.s10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: Text(text.isEmpty ? '(no text)' : text, style: AuraText.body)),
                                  const SizedBox(width: AuraSpace.s10),
                                  PopupMenuButton<String>(
                                    onSelected: (v) async {
                                      if (v == 'edit') {
                                        await _editPost(context: context, id: id, initialText: text);
                                      } else if (v == 'archive') {
                                        await _archivePost(id);
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                                      PopupMenuItem(value: 'archive', child: Text('Archive')),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  );
                },
              );
            },
          ),

          const SizedBox(height: AuraSpace.s14),

          // Saves card
          Consumer(
            builder: (context, ref, _) {
              final savesAsync = ref.watch(_meSavesProvider);
              return savesAsync.when(
                loading: () => const AuraCard(child: _LoadingBlock()),
                error: (e, _) => AuraCard(child: _ErrorBlock(message: '$e')),
                data: (items) => AuraCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Saves', style: AuraText.title),
                      const SizedBox(height: AuraSpace.s10),
                      Text(items.isEmpty ? 'No saves yet.' : 'Saved items: ${items.length}', style: AuraText.body),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: AuraSpace.s14),

          // Replies card
          Consumer(
            builder: (context, ref, _) {
              final repliesAsync = ref.watch(_meRepliesProvider);
              return repliesAsync.when(
                loading: () => const AuraCard(child: _LoadingBlock()),
                error: (e, _) => AuraCard(child: _ErrorBlock(message: '$e')),
                data: (items) => AuraCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Replies', style: AuraText.title),
                      const SizedBox(height: AuraSpace.s10),
                      Text(items.isEmpty ? 'No replies yet.' : 'Replies: ${items.length}', style: AuraText.body),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AuraSpace.s16),
      child: Center(child: CircularProgressIndicator()),
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
      child: Text(message, style: AuraText.body.copyWith(color: Colors.red)),
    );
  }
}