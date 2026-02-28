import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/auth/session_providers.dart';
import '../../core/net/dio_provider.dart';
import '../../core/ui/aura_card.dart';
import '../../core/ui/aura_scaffold.dart';
import '../../core/ui/aura_space.dart';
import '../../core/ui/aura_text.dart';

import 'edit_profile_screen.dart';

Map<String, dynamic> _asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return <String, dynamic>{};
}

/// Unwrap common envelopes:
/// - { ok:true, data:{...} }
/// - { ok:true, data:{ data:{...} } }
Map<String, dynamic> _unwrapMap(dynamic raw) {
  final root = _asMap(raw);
  dynamic inner = root['data'];

  if (inner is Map && inner['data'] is Map) {
    inner = inner['data'];
  }

  if (inner is Map) return Map<String, dynamic>.from(inner);
  return root;
}

List<Map<String, dynamic>> _unwrapItems(dynamic raw) {
  if (raw is List) {
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  final m = _unwrapMap(raw);

  final a = m['items'];
  if (a is List) {
    return a.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  final b = m['data'];
  if (b is List) {
    return b.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  if (b is Map && b['items'] is List) {
    final list = b['items'] as List;
    return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  return <Map<String, dynamic>>[];
}

bool _isEmailNotVerifiedError(Object err) {
  if (err is DioException) {
    final data = err.response?.data;
    final m = _asMap(data);
    final code = _asMap(m['error'])['code']?.toString();
    return code == 'EMAIL_NOT_VERIFIED';
  }
  return false;
}

final meProfileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  try {
    final res = await dio.get('/users/me');
    return _unwrapMap(res.data);
  } on DioException catch (e) {
    // Important: don’t crash the whole screen on EMAIL_NOT_VERIFIED
    final m = _asMap(e.response?.data);
    final code = _asMap(m['error'])['code']?.toString();
    if (code == 'EMAIL_NOT_VERIFIED') {
      return <String, dynamic>{'_emailNotVerified': true};
    }
    rethrow;
  }
});

final _meDraftProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/posts/draft');
  return _unwrapMap(res.data);
});

final _mePostsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/posts/mine');
  return _unwrapItems(res.data);
});

final _meSavesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/saves/me', queryParameters: {'limit': 12});
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

  String _absFromMaybeRelative(String raw, Dio dio) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    if (t.startsWith('http://') || t.startsWith('https://')) return t;

    final base = dio.options.baseUrl.trim();
    if (base.isEmpty) return t;

    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final p = t.startsWith('/') ? t : '/$t';
    return '$b$p';
  }

  Future<void> _logout(BuildContext context) async {
    if (_busyLogout) return;
    setState(() => _busyLogout = true);

    try {
      final dio = ref.read(dioProvider);

      // Best-effort backend logout.
      try {
        await dio.post('/auth/logout');
      } catch (_) {}

      // Clear local session
      final store = ref.read(tokenStoreProvider);
      await store.clear();

      if (!mounted) return;
      ref.invalidate(authStatusProvider);
      ref.invalidate(isAuthedProvider);
      ref.invalidate(emailVerifiedProvider);

      context.go('/login');
    } finally {
      if (mounted) setState(() => _busyLogout = false);
    }
  }

  Future<void> _pickAndUploadAvatar(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
      if (picked == null) return;

      final dio = ref.read(dioProvider);
      final bytes = await picked.readAsBytes();

      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: picked.name.isNotEmpty ? picked.name : 'avatar.jpg',
        ),
      });

      final res = await dio.post('/uploads/avatar', data: form);
      final unwrapped = _unwrapMap(res.data);
      final url = (unwrapped['url'] ?? unwrapped['avatarUrl'] ?? unwrapped['path'])?.toString().trim() ?? '';

      if (url.isEmpty) {
        messenger.showSnackBar(const SnackBar(content: Text('Upload completed but no URL returned.')));
        return;
      }

      await dio.patch('/users/me', data: {'avatarUrl': url});
      ref.invalidate(meProfileProvider);

      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Avatar updated.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Avatar upload failed: $e')));
    }
  }

  Future<void> _openEditProfile(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );

    // Refresh everything after returning
    ref.invalidate(meProfileProvider);
    ref.invalidate(_meDraftProvider);
    ref.invalidate(_mePostsProvider);
    ref.invalidate(_meSavesProvider);
    ref.invalidate(_meRepliesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final authed = ref.watch(isAuthedProvider);

    if (!authed) {
      return AuraScaffold(
        title: 'Me',
        body: Padding(
          padding: const EdgeInsets.all(AuraSpace.s16),
          child: AuraCard(
            child: Padding(
              padding: const EdgeInsets.all(AuraSpace.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('You are not signed in.', style: AuraText.title),
                  const SizedBox(height: AuraSpace.s10),
                  Text('Sign in to manage your profile and see your drafts, posts, and saved items.', style: AuraText.body),
                  const SizedBox(height: AuraSpace.s12),
                  FilledButton(
                    onPressed: () => context.go('/login?redirect=/me'),
                    child: const Text('Sign in'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final profileAsync = ref.watch(meProfileProvider);

    return AuraScaffold(
      title: 'Me',
      body: profileAsync.when(
        data: (me) {
          final emailNotVerified = me['_emailNotVerified'] == true;
          final dio = ref.read(dioProvider);

          final displayName = (me['displayName'] ?? '').toString().trim();
          final handle = (me['handle'] ?? '').toString().trim();
          final email = (me['email'] ?? '').toString().trim();
          final bio = (me['bio'] ?? '').toString().trim();
          final avatarRaw = (me['avatarUrl'] ?? '').toString().trim();
          final avatarAbs = _absFromMaybeRelative(avatarRaw, dio);

          // Admin capability discovery:
          // backend should add isAdmin to /users/me response.
          final isAdmin = me['isAdmin'] == true;

          return ListView(
            padding: const EdgeInsets.fromLTRB(AuraSpace.s16, AuraSpace.s16, AuraSpace.s16, AuraSpace.s24),
            children: [
              if (emailNotVerified)
                AuraCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AuraSpace.s16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Email verification required', style: AuraText.title),
                        const SizedBox(height: AuraSpace.s10),
                        Text('Please verify your email to unlock writing and full account features.', style: AuraText.body),
                        const SizedBox(height: AuraSpace.s12),
                        Wrap(
                          spacing: AuraSpace.s10,
                          runSpacing: AuraSpace.s10,
                          children: [
                            FilledButton(
                              onPressed: () => context.go('/verify'),
                              child: const Text('Verify email'),
                            ),
                            OutlinedButton(
                              onPressed: () => _logout(context),
                              child: const Text('Log out'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

              AuraCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => _pickAndUploadAvatar(context),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundImage: avatarAbs.isNotEmpty ? NetworkImage(avatarAbs) : null,
                        child: avatarAbs.isEmpty ? const Icon(Icons.person) : null,
                      ),
                    ),
                    const SizedBox(width: AuraSpace.s12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, AuraSpace.s14, AuraSpace.s16, AuraSpace.s14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(displayName.isNotEmpty ? displayName : '—', style: AuraText.title),
                            const SizedBox(height: AuraSpace.s6),
                            Text(handle.isNotEmpty ? '@$handle' : '—', style: AuraText.small),
                            const SizedBox(height: AuraSpace.s6),
                            Text(email.isNotEmpty ? email : '—', style: AuraText.small),
                            if (bio.isNotEmpty) ...[
                              const SizedBox(height: AuraSpace.s10),
                              Text(bio, style: AuraText.body),
                            ],
                            const SizedBox(height: AuraSpace.s12),
                            Wrap(
                              spacing: AuraSpace.s10,
                              runSpacing: AuraSpace.s10,
                              children: [
                                FilledButton(
                                  onPressed: () => _openEditProfile(context),
                                  child: const Text('Edit profile'),
                                ),
                                OutlinedButton(
                                  onPressed: _busyLogout ? null : () => _logout(context),
                                  child: Text(_busyLogout ? 'Logging out…' : 'Log out'),
                                ),
                              ],
                            ),
                            const SizedBox(height: AuraSpace.s10),
                            Text('Tip: tap your avatar to upload a new photo.', style: AuraText.small),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AuraSpace.s14),

              AuraCard(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AuraSpace.s16, AuraSpace.s12, AuraSpace.s16, AuraSpace.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tools', style: AuraText.title),
                      const SizedBox(height: AuraSpace.s10),
                      Wrap(
                        spacing: AuraSpace.s10,
                        runSpacing: AuraSpace.s10,
                        children: [
                          OutlinedButton(
                            onPressed: () => context.go('/announcements'),
                            child: const Text('Announcements'),
                          ),
                          OutlinedButton(
                            onPressed: () => context.go('/ai/claim-audit'),
                            child: const Text('Claim audit'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AuraSpace.s10),
                      Text(
                        'Announcements are official notes. Claim audit is a private tool for testing language before you publish.',
                        style: AuraText.small,
                      ),
                    ],
                  ),
                ),
              ),

              if (isAdmin) ...[
                const SizedBox(height: AuraSpace.s14),
                AuraCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AuraSpace.s16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Admin', style: AuraText.title),
                        const SizedBox(height: AuraSpace.s10),
                        Text('Administrative actions are only visible to admins.', style: AuraText.small),
                        const SizedBox(height: AuraSpace.s12),
                        FilledButton(
                          onPressed: () => context.go('/announcements?admin=1'),
                          child: const Text('Manage announcements'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: AuraSpace.s14),

              Consumer(
                builder: (context, ref, _) {
                  final draftAsync = ref.watch(_meDraftProvider);
                  return draftAsync.when(
                    data: (d) {
                      final hasDraft = (d['id'] ?? '').toString().trim().isNotEmpty;
                      if (!hasDraft) return const SizedBox.shrink();

                      final title = (d['title'] ?? 'Draft').toString().trim();
                      return AuraCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AuraSpace.s16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Draft', style: AuraText.title),
                              const SizedBox(height: AuraSpace.s10),
                              Text(title, style: AuraText.body),
                              const SizedBox(height: AuraSpace.s12),
                              FilledButton(
                                onPressed: () => context.go('/compose?draft=1'),
                                child: const Text('Continue writing'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (err, st) {
                      if (_isEmailNotVerifiedError(err)) return const SizedBox.shrink();
                      return AuraCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AuraSpace.s16),
                          child: Text('Draft load failed: $err', style: AuraText.small),
                        ),
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: AuraSpace.s14),

              Consumer(
                builder: (context, ref, _) {
                  final postsAsync = ref.watch(_mePostsProvider);
                  return postsAsync.when(
                    data: (items) {
                      if (items.isEmpty) {
                        return AuraCard(
                          child: Padding(
                            padding: const EdgeInsets.all(AuraSpace.s16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Your posts', style: AuraText.title),
                                const SizedBox(height: AuraSpace.s10),
                                Text('No posts yet.', style: AuraText.small),
                              ],
                            ),
                          ),
                        );
                      }

                      return AuraCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AuraSpace.s16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Your posts', style: AuraText.title),
                              const SizedBox(height: AuraSpace.s10),
                              for (final p in items.take(6)) ...[
                                Text((p['text'] ?? '').toString().trim(), style: AuraText.body),
                                const SizedBox(height: AuraSpace.s10),
                              ],
                              OutlinedButton(
                                onPressed: () => context.go('/posts/mine'),
                                child: const Text('View all'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (err, st) => AuraCard(
                      child: Padding(
                        padding: const EdgeInsets.all(AuraSpace.s16),
                        child: Text('Posts load failed: $err', style: AuraText.small),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: AuraSpace.s14),

              Consumer(
                builder: (context, ref, _) {
                  final savesAsync = ref.watch(_meSavesProvider);
                  return savesAsync.when(
                    data: (items) {
                      return AuraCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AuraSpace.s16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Saved', style: AuraText.title),
                              const SizedBox(height: AuraSpace.s10),
                              Text(items.isEmpty ? 'Nothing saved yet.' : 'You have ${items.length} saved item(s).', style: AuraText.small),
                              const SizedBox(height: AuraSpace.s12),
                              OutlinedButton(
                                onPressed: () => context.go('/saves'),
                                child: const Text('Open saved'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (err, st) => AuraCard(
                      child: Padding(
                        padding: const EdgeInsets.all(AuraSpace.s16),
                        child: Text('Saved load failed: $err', style: AuraText.small),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: AuraSpace.s14),

              Consumer(
                builder: (context, ref, _) {
                  final repliesAsync = ref.watch(_meRepliesProvider);
                  return repliesAsync.when(
                    data: (items) {
                      return AuraCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AuraSpace.s16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Replies', style: AuraText.title),
                              const SizedBox(height: AuraSpace.s10),
                              Text(items.isEmpty ? 'No replies yet.' : 'You have ${items.length} reply/replies.', style: AuraText.small),
                              const SizedBox(height: AuraSpace.s12),
                              OutlinedButton(
                                onPressed: () => context.go('/replies/mine'),
                                child: const Text('Open replies'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (err, st) => AuraCard(
                      child: Padding(
                        padding: const EdgeInsets.all(AuraSpace.s16),
                        child: Text('Replies load failed: $err', style: AuraText.small),
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AuraSpace.s16),
              child: AuraCard(
                child: Padding(
                  padding: const EdgeInsets.all(AuraSpace.s16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Could not load your profile.', style: AuraText.title),
                      const SizedBox(height: AuraSpace.s10),
                      Text('$err', style: AuraText.small),
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
          );
        },
      ),
    );
  }
}