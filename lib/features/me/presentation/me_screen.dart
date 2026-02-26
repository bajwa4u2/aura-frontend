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

bool _isEmailNotVerifiedError(Object err) {
  if (err is DioException) {
    final data = err.response?.data;
    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      final e = m['error'];
      if (e is Map) {
        final em = Map<String, dynamic>.from(e);
        return (em['code']?.toString() ?? '') == 'EMAIL_NOT_VERIFIED';
      }
    }
  }
  return false;
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

    final text = ctl.text.trim();

    final dio = ref.read(dioProvider);
    await dio.post('/posts/draft', data: {'text': text});

    ref.invalidate(_meDraftProvider);
    if (!mounted) return;
    messenger.showSnackBar(const SnackBar(content: Text('Draft saved.')));
  }

  Future<void> _publishDraft(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final dio = ref.read(dioProvider);

    try {
      await dio.post('/posts/publish-latest-draft');
      ref.invalidate(_meDraftProvider);
      ref.invalidate(_mePostsProvider);
      ref.invalidate(_meRepliesProvider);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Published.')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Publish failed: $e')));
    }
  }

  Future<void> _discardDraft(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final dio = ref.read(dioProvider);

    try {
      await dio.delete('/posts/draft');
      ref.invalidate(_meDraftProvider);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Draft discarded.')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Discard failed: $e')));
    }
  }

  Future<void> _logout(BuildContext context) async {
    if (_busyLogout) return;
    setState(() => _busyLogout = true);

    try {
      // Centralized logout already clears tokens + invalidates.
      final controller = ref.read(authControllerProvider);
      await controller.logout(context);
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _busyLogout = false);
      if (!mounted) return;
      context.go('/public');
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
                  const SizedBox(height: AuraSpace.s8),
                  Text('Please log in to view your profile.', style: AuraText.body),
                  const SizedBox(height: AuraSpace.s12),
                  FilledButton(
                    onPressed: () => context.go('/login?redirect=/me'),
                    child: const Text('Log in'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final verifiedAsync = ref.watch(emailVerifiedProvider);

    // Email verification gate: never let this screen fire /users/me until verified.
    if (verifiedAsync.isLoading) {
      return const AuraScaffold(
        title: 'Aura',
        showHomeAction: true,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final verified = verifiedAsync.valueOrNull ?? false;
    if (!verified) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        context.go('/verify-pending');
      });

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
                  Text('Verify your email', style: AuraText.title),
                  const SizedBox(height: AuraSpace.s8),
                  Text(
                    'Please verify your email to access your account.',
                    style: AuraText.body,
                  ),
                  const SizedBox(height: AuraSpace.s12),
                  FilledButton(
                    onPressed: () => context.go('/verify-pending'),
                    child: const Text('Continue'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final meAsync = ref.watch(meProfileProvider);

    if (meAsync.hasError && _isEmailNotVerifiedError(meAsync.error!)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        context.go('/verify-pending');
      });
      return const AuraScaffold(
        title: 'Aura',
        showHomeAction: true,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return AuraScaffold(
      title: 'Me',
      showHomeAction: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AuraSpace.s16, AuraSpace.s12, AuraSpace.s16, AuraSpace.s24),
        children: [
          meAsync.when(
            data: (me) {
              final baseUrl = ref.read(dioProvider).options.baseUrl;
              final avatarUrl = (me['avatarUrl'] ?? '').toString();
              final displayName = (me['displayName'] ?? '').toString().trim();
              final handle = (me['handle'] ?? '').toString().trim();
              final bio = (me['bio'] ?? '').toString();

              final absAvatar = _absoluteAvatarUrl(baseUrl: baseUrl, avatarUrl: avatarUrl);

              return AuraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.white10,
                          backgroundImage: absAvatar.isNotEmpty ? NetworkImage(absAvatar) : null,
                          child: absAvatar.isEmpty ? const Icon(Icons.person_outline) : null,
                        ),
                        const SizedBox(width: AuraSpace.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(displayName.isNotEmpty ? displayName : 'Me', style: AuraText.title),
                              const SizedBox(height: 2),
                              Text(handle.isNotEmpty ? '@$handle' : '', style: AuraText.muted),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Change photo',
                          onPressed: () => _pickAndUploadAvatar(context),
                          icon: const Icon(Icons.camera_alt_outlined),
                        ),
                      ],
                    ),
                    const SizedBox(height: AuraSpace.s12),
                    if (bio.trim().isNotEmpty) Text(bio, style: AuraText.body),
                    if (bio.trim().isNotEmpty) const SizedBox(height: AuraSpace.s12),
                    Row(
                      children: [
                        FilledButton(
                          onPressed: () => _editProfile(
                            context: context,
                            displayName: displayName,
                            bio: bio,
                          ),
                          child: const Text('Edit profile'),
                        ),
                        const SizedBox(width: AuraSpace.s8),
                        OutlinedButton(
                          onPressed: _busyLogout ? null : () => _logout(context),
                          child: Text(_busyLogout ? 'Signing out…' : 'Sign out'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
            loading: () => const AuraCard(
              child: Padding(
                padding: EdgeInsets.all(AuraSpace.s12),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (e, st) => AuraCard(
              child: Padding(
                padding: const EdgeInsets.all(AuraSpace.s12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Could not load profile', style: AuraText.title),
                    const SizedBox(height: AuraSpace.s8),
                    Text('$e', style: AuraText.body),
                    const SizedBox(height: AuraSpace.s12),
                    FilledButton(
                      onPressed: () => ref.invalidate(meProfileProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: AuraSpace.s12),

          // Draft + publish controls
          ref.watch(_meDraftProvider).when(
                data: (draft) {
                  final text = (draft['text'] ?? '').toString();
                  final hasDraft = text.trim().isNotEmpty;

                  return AuraCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Draft', style: AuraText.title),
                        const SizedBox(height: AuraSpace.s8),
                        Text(
                          hasDraft ? text : 'No draft yet.',
                          style: AuraText.body,
                        ),
                        const SizedBox(height: AuraSpace.s12),
                        Wrap(
                          spacing: AuraSpace.s8,
                          runSpacing: AuraSpace.s8,
                          children: [
                            FilledButton(
                              onPressed: () => _editDraft(context, text),
                              child: Text(hasDraft ? 'Edit draft' : 'Start draft'),
                            ),
                            OutlinedButton(
                              onPressed: hasDraft ? () => _publishDraft(context) : null,
                              child: const Text('Publish'),
                            ),
                            TextButton(
                              onPressed: hasDraft ? () => _discardDraft(context) : null,
                              child: const Text('Discard'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const AuraCard(
                  child: Padding(
                    padding: EdgeInsets.all(AuraSpace.s12),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (e, st) => AuraCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AuraSpace.s12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Draft error', style: AuraText.title),
                        const SizedBox(height: AuraSpace.s8),
                        Text('$e', style: AuraText.body),
                      ],
                    ),
                  ),
                ),
              ),

          const SizedBox(height: AuraSpace.s12),

          // My posts
          AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('My posts', style: AuraText.title),
                const SizedBox(height: AuraSpace.s8),
                ref.watch(_mePostsProvider).when(
                      data: (items) {
                        if (items.isEmpty) return Text('No posts yet.', style: AuraText.body);
                        return Column(
                          children: items.take(8).map((p) {
                            final id = (p['id'] ?? '').toString();
                            final text = (p['text'] ?? '').toString();
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                text.trim().isEmpty ? '(no text)' : text,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => context.go('/posts/$id'),
                            );
                          }).toList(),
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, st) => Text('Error: $e', style: AuraText.body),
                    ),
              ],
            ),
          ),

          const SizedBox(height: AuraSpace.s12),

          // Saved
          AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Saved', style: AuraText.title),
                const SizedBox(height: AuraSpace.s8),
                ref.watch(_meSavesProvider).when(
                      data: (items) {
                        if (items.isEmpty) return Text('No saved posts.', style: AuraText.body);
                        return Column(
                          children: items.take(8).map((p) {
                            final id = (p['id'] ?? '').toString();
                            final text = (p['text'] ?? '').toString();
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                text.trim().isEmpty ? '(no text)' : text,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => context.go('/posts/$id'),
                            );
                          }).toList(),
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, st) => Text('Error: $e', style: AuraText.body),
                    ),
              ],
            ),
          ),

          const SizedBox(height: AuraSpace.s12),

          // Replies
          AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('My replies', style: AuraText.title),
                const SizedBox(height: AuraSpace.s8),
                ref.watch(_meRepliesProvider).when(
                      data: (items) {
                        if (items.isEmpty) return Text('No replies yet.', style: AuraText.body);
                        return Column(
                          children: items.take(8).map((p) {
                            final id = (p['id'] ?? '').toString();
                            final text = (p['text'] ?? '').toString();
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                text.trim().isEmpty ? '(no text)' : text,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => context.go('/posts/$id'),
                            );
                          }).toList(),
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, st) => Text('Error: $e', style: AuraText.body),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}