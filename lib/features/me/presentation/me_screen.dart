import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/auth_providers.dart'; // tokenStoreProvider
import '../../../core/auth/session_providers.dart'; // authStatusProvider, emailVerifiedProvider, isAuthedProvider
import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';

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
      final data = _asMap(res.data);

      final url = (data['url'] ?? data['avatarUrl'] ?? data['path'])?.toString().trim();
      if (url == null || url.isEmpty) {
        if (!mounted) return;
        messenger.showSnackBar(const SnackBar(content: Text('Upload succeeded but no URL returned.')));
        return;
      }

      await dio.patch('/users/me', data: {'avatarUrl': url});

      ref.invalidate(meProfileProvider);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Photo updated.')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Upload failed: $e')));
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
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Save')),
        ],
      ),
    );

    if (ok != true) return;

    final dio = ref.read(dioProvider);
    final dn = nameCtl.text.trim();
    final bb = bioCtl.text.trim();

    await dio.patch('/users/me', data: {
      'displayName': dn.isEmpty ? null : dn,
      'bio': bb.isEmpty ? null : bb,
    });

    ref.invalidate(meProfileProvider);
    if (!mounted) return;
    messenger.showSnackBar(const SnackBar(content: Text('Saved.')));
  }

  Future<void> _logout(BuildContext context) async {
    if (_busyLogout) return;

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
      final store = ref.read(tokenStoreProvider);

      // Best-effort backend revoke (works on web too; cookie refresh handled server-side)
      try {
        final rt = (store.refreshToken ?? '').trim();
        if (!kIsWeb && rt.isNotEmpty) {
          await dio.post('/auth/logout', data: {'refreshToken': rt});
        } else {
          await dio.post('/auth/logout');
        }
      } catch (_) {}

      await store.clear();

      // Clear cached screens
      ref.invalidate(meProfileProvider);
      ref.invalidate(_meDraftProvider);
      ref.invalidate(_mePostsProvider);
      ref.invalidate(_meSavesProvider);
      ref.invalidate(_meRepliesProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logged out.')));
      context.go('/login');
    } finally {
      if (mounted) setState(() => _busyLogout = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authStatus = ref.watch(authStatusProvider);
    final verifiedAsync = ref.watch(emailVerifiedProvider);

    // Not authed: show simple gate
    if (authStatus == AuthStatus.unauthed) {
      return AuraScaffold(
        title: 'Aura',
        showHomeAction: true,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: AuraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Not signed in', style: AuraText.title),
                  const SizedBox(height: AuraSpace.s10),
                  Text('Log in to view your profile.', style: AuraText.body),
                  const SizedBox(height: AuraSpace.s14),
                  FilledButton(
                    onPressed: () => context.go('/login?redirect=${Uri.encodeComponent('/me')}'),
                    child: const Text('Go to login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Authed but not verified: show verify gate (router should also enforce, but this makes it bulletproof)
    final verified = verifiedAsync.valueOrNull ?? false;
    if (!verified) {
      return AuraScaffold(
        title: 'Verify email',
        showHomeAction: true,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: AuraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Email not verified', style: AuraText.title),
                  const SizedBox(height: AuraSpace.s10),
                  Text(
                    'Verify your email to unlock your profile.',
                    style: AuraText.body,
                  ),
                  const SizedBox(height: AuraSpace.s14),
                  FilledButton(
                    onPressed: () => context.go('/verify-pending?redirect=${Uri.encodeComponent('/me')}'),
                    child: const Text('Verify now'),
                  ),
                  const SizedBox(height: AuraSpace.s10),
                  TextButton(
                    onPressed: _busyLogout ? null : () => _logout(context),
                    child: const Text('Log out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Main profile UI
    final profile = ref.watch(meProfileProvider);

    return AuraScaffold(
      title: 'Me',
      showHomeAction: true,
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) {
          if (_isEmailNotVerifiedError(err)) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: AuraCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Email not verified', style: AuraText.title),
                      const SizedBox(height: AuraSpace.s10),
                      Text('Go to verify pending.', style: AuraText.body),
                      const SizedBox(height: AuraSpace.s14),
                      FilledButton(
                        onPressed: () => context.go('/verify-pending?redirect=${Uri.encodeComponent('/me')}'),
                        child: const Text('Verify'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: AuraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Failed to load profile', style: AuraText.title),
                    const SizedBox(height: AuraSpace.s10),
                    Text(err.toString(), style: AuraText.body),
                    const SizedBox(height: AuraSpace.s14),
                    FilledButton(
                      onPressed: () => ref.invalidate(meProfileProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        data: (m) {
          if (m['_emailNotVerified'] == true) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: AuraCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Email not verified', style: AuraText.title),
                      const SizedBox(height: AuraSpace.s10),
                      Text('Verify to unlock your profile.', style: AuraText.body),
                      const SizedBox(height: AuraSpace.s14),
                      FilledButton(
                        onPressed: () => context.go('/verify-pending?redirect=${Uri.encodeComponent('/me')}'),
                        child: const Text('Verify now'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final handle = (m['handle'] ?? '').toString();
          final displayName = (m['displayName'] ?? '').toString();
          final bio = (m['bio'] ?? '').toString();
          final avatarUrl = (m['avatarUrl'] ?? '').toString();

          final baseUrl = ref.read(dioProvider).options.baseUrl;
          final avatarAbs = _absoluteAvatarUrl(baseUrl: baseUrl, avatarUrl: avatarUrl);

          return ListView(
            padding: const EdgeInsets.fromLTRB(AuraSpace.s16, AuraSpace.s12, AuraSpace.s16, AuraSpace.s24),
            children: [
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(displayName.isNotEmpty ? displayName : 'Member', style: AuraText.title),
                          const SizedBox(height: 6),
                          if (handle.isNotEmpty) Text('@$handle', style: AuraText.body),
                          if (bio.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(bio, style: AuraText.body),
                          ],
                          const SizedBox(height: AuraSpace.s12),
                          Wrap(
                            spacing: AuraSpace.s10,
                            runSpacing: AuraSpace.s10,
                            children: [
                              FilledButton(
                                onPressed: () => _editProfile(
                                  context: context,
                                  displayName: displayName,
                                  bio: bio,
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
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AuraSpace.s14),

              // Quick links
              AuraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quick', style: AuraText.title),
                    const SizedBox(height: AuraSpace.s10),
                    Wrap(
                      spacing: AuraSpace.s10,
                      runSpacing: AuraSpace.s10,
                      children: [
                        OutlinedButton(
                          onPressed: () => context.go('/compose'),
                          child: const Text('Compose'),
                        ),
                        OutlinedButton(
                          onPressed: () => context.go('/saved'),
                          child: const Text('Saved'),
                        ),
                        OutlinedButton(
                          onPressed: () => context.go('/updates'),
                          child: const Text('Updates'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}