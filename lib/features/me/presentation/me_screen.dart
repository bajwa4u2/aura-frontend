import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';

final meProfileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.read(dioProvider);

  Response res;
  try {
    res = await dio.get('/users/me');
  } catch (_) {
    // Fallback (older path) if needed
    res = await dio.get('/auth/me');
  }

  final data = res.data;
  if (data is Map) return Map<String, dynamic>.from(data);
  throw Exception('Unexpected response');
});

final _meDraftProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/posts/draft');
  final data = res.data;
  if (data is Map) return Map<String, dynamic>.from(data);
  throw Exception('Unexpected response');
});

final _mePostsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/posts/mine');
  final data = res.data;
  if (data is List) {
    return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
  throw Exception('Unexpected response');
});

final _meSavesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/saves', queryParameters: {'limit': 12});
  final data = res.data;
  if (data is List) {
    return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
  throw Exception('Unexpected response');
});

final _meRepliesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/replies/mine');
  final data = res.data;
  if (data is List) {
    return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
  throw Exception('Unexpected response');
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

      Uint8List bytes = await picked.readAsBytes();

      // Web: we keep bytes; mobile: same.
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
    // - If user leaves a field empty, we send null to clear it in DB.
    // - If user writes something, we send the trimmed string.
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
      } catch (_) {
        // Ignore server logout errors; local logout still happens.
      }

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
    final messenger = ScaffoldMessenger.of(context);

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
                            if (id.isNotEmpty) context.push('/posts/$id');
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
                            _ItemAction(
                              label: 'Archive',
                              onTap: () => _archivePost((it['id'] ?? '').toString()),
                            ),
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
                            final id = (it['postId'] ?? it['id'] ?? '').toString();
                            if (id.isNotEmpty) context.push('/posts/$id');
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
                          onOpen: null,
                          actions: const [],
                        ),
                        const SizedBox(height: AuraSpace.s12),
                      ],
                    ],
                  );
                },
              ),

          const SizedBox(height: AuraSpace.s20),
          Text('Settings', style: AuraText.title),
          const SizedBox(height: AuraSpace.s10),
          AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Account', style: AuraText.title),
                const SizedBox(height: AuraSpace.s8),
                Text(
                  'Logout is available here. Password reset will be added once the backend endpoint is enabled.',
                  style: AuraText.muted,
                ),
                const SizedBox(height: AuraSpace.s16),
                Wrap(
                  spacing: AuraSpace.s10,
                  runSpacing: AuraSpace.s10,
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Password reset is not wired yet.')),
                        );
                      },
                      child: const Text('Reset password'),
                    ),
                    OutlinedButton(
                      onPressed: _busyLogout ? null : () => _logout(context),
                      child: Text(_busyLogout ? 'Logging out…' : 'Log out'),
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
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.title,
    required this.subtitle,
    required this.text,
    required this.onOpen,
    required this.actions,
  });

  final String title;
  final String subtitle;
  final String text;
  final VoidCallback? onOpen;
  final List<_ItemAction> actions;

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