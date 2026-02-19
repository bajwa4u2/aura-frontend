import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/auth/token_store.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';

Map<String, dynamic> _unwrapApiMap(dynamic data) {
  if (data is Map) {
    final m = Map<String, dynamic>.from(data as Map);

    // Common envelope shapes:
    // - { data: {...} }
    // - { user: {...} }
    final inner = m['data'] ?? m['user'];
    if (inner is Map) return Map<String, dynamic>.from(inner as Map);

    return m;
  }
  throw Exception('Unexpected response');
}

final meProfileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.read(dioProvider);

  Response res;
  try {
    // Current canonical route
    res = await dio.get('/users/me');
  } catch (_) {
    // Back-compat (older path) if needed
    res = await dio.get('/auth/me');
  }

  return _unwrapApiMap(res.data);
});

final _meDraftProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/posts/draft');

  final data = res.data;
  if (data is Map) {
    final m = Map<String, dynamic>.from(data as Map);
    if (m.containsKey('draft')) return m;

    final inner = m['data'] ?? m['result'];
    if (inner is Map) {
      final mm = Map<String, dynamic>.from(inner as Map);
      if (mm.containsKey('draft')) return mm;
      return mm;
    }
    return m;
  }

  throw Exception('Unexpected response');
});

final _mePostsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/posts/mine');
  final data = res.data;

  if (data is Map) {
    final m = Map<String, dynamic>.from(data);
    final inner = m['data'] ?? m['items'] ?? m['posts'] ?? m['result'];
    if (inner is List) {
      return inner.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
  }

  if (data is List) {
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  return const <Map<String, dynamic>>[];
});

class MeScreen extends ConsumerStatefulWidget {
  const MeScreen({super.key});

  @override
  ConsumerState<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends ConsumerState<MeScreen> {
  bool _busyLogout = false;

  String _absoluteAvatarUrl({
    required String baseUrl,
    required String avatarUrl,
  }) {
    final raw = avatarUrl.trim();
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;

    // Ensure one slash between base and path
    final b = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final p = raw.startsWith('/') ? raw : '/$raw';
    return '$b$p';
  }

  Future<void> _logout(BuildContext context) async {
    if (_busyLogout) return;
    setState(() => _busyLogout = true);

    try {
      final dio = ref.read(dioProvider);

      // Best-effort logout, then clear local tokens regardless.
      try {
        await dio.post('/auth/logout');
      } catch (_) {}

      await ref.read(tokenStoreProvider).clear();

      if (!mounted) return;
      context.go('/home');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logged out.')));
    } finally {
      if (mounted) setState(() => _busyLogout = false);
    }
  }

  Future<void> _pickAndUploadAvatar(BuildContext context) async {
    final dio = ref.read(dioProvider);
    final picker = ImagePicker();

    try {
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );

      if (picked == null) return;

      Uint8List bytes = await picked.readAsBytes();

      // On web, ImagePicker returns bytes directly (still ok)
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: picked.name,
        ),
      });

      final res = await dio.post('/uploads/avatar', data: form);

      String? url;
      final data = res.data;

      if (data is Map) {
        final m = Map<String, dynamic>.from(data as Map);
        final inner = m['data'] ?? m;
        if (inner is Map) {
          final mm = Map<String, dynamic>.from(inner as Map);
          url = (mm['url'] ?? mm['avatarUrl'] ?? mm['path'])?.toString();
        }
      }

      if (url == null || url.trim().isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload succeeded but no URL returned.')),
        );
        return;
      }

      // Store avatarUrl on user
      await dio.patch(
        '/users/me',
        data: {'avatarUrl': url.trim()},
      );

      ref.invalidate(meProfileProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo updated.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
  }

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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved.')));
  }

  Future<void> _editDraft(BuildContext context, String initial) async {
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
              labelText: 'Draft',
              border: OutlineInputBorder(),
            ),
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

  @override
  Widget build(BuildContext context) {
    final authed = ref.watch(isAuthedProvider);

    if (!authed) {
      return AuraScaffold(
        title: 'Me',
        showHomeAction: true,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: AuraCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('You are not signed in.', style: AuraText.body),
                  const SizedBox(height: AuraSpace.s16),
                  Wrap(
                    spacing: AuraSpace.s12,
                    runSpacing: AuraSpace.s12,
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
          ),
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
                  final d = (draft['draft'] is Map)
                      ? Map<String, dynamic>.from(draft['draft'] as Map)
                      : null;

                  final text = (d?['text'] ?? '').toString();

                  return AuraCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (text.trim().isEmpty)
                          Text('No draft yet.', style: AuraText.muted)
                        else
                          Text(text, style: AuraText.body),
                        const SizedBox(height: AuraSpace.s12),
                        Wrap(
                          spacing: AuraSpace.s10,
                          runSpacing: AuraSpace.s10,
                          children: [
                            OutlinedButton(
                              onPressed: () => _editDraft(context, text),
                              child: const Text('Edit draft'),
                            ),
                            FilledButton(
                              onPressed: () async {
                                final dio = ref.read(dioProvider);
                                await dio.post('/posts/draft/publish');
                                ref.invalidate(_meDraftProvider);
                                ref.invalidate(_mePostsProvider);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Published.')),
                                );
                              },
                              child: const Text('Publish'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
          const SizedBox(height: AuraSpace.s16),
          Text('My posts', style: AuraText.title),
          const SizedBox(height: AuraSpace.s10),
          ref.watch(_mePostsProvider).when(
                loading: () => const AuraCard(child: _LoadingBlock()),
                error: (e, _) => AuraCard(child: _ErrorBlock(message: '$e')),
                data: (items) {
                  if (items.isEmpty) {
                    return AuraCard(child: Text('No posts yet.', style: AuraText.muted));
                  }

                  return Column(
                    children: [
                      for (final p in items) ...[
                        AuraCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text((p['text'] ?? '').toString(), style: AuraText.body),
                              const SizedBox(height: AuraSpace.s10),
                              TextButton(
                                onPressed: () => context.go('/post/${p['id']}'),
                                child: const Text('Open'),
                              ),
                            ],
                          ),
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

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AuraSpace.s16),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
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
      child: Text(message, style: AuraText.body.copyWith(color: Colors.red)),
    );
  }
}
