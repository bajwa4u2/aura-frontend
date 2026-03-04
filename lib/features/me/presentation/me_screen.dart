import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/auth_providers.dart'; // tokenStoreProvider
import '../../../core/auth/session_providers.dart'; // authStatusProvider, emailVerifiedProvider, isAuthedProvider
import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart' as ui;
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import 'edit_profile_screen.dart';

const String _adminUserIds =
    String.fromEnvironment('AURA_ADMIN_USER_IDS', defaultValue: '');

List<String> _adminUserIdList() {
  return _adminUserIds
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

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
    final l = b['items'] as List;
    return l.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  if (b is Map && b['data'] is List) {
    final l = b['data'] as List;
    return l.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  return <Map<String, dynamic>>[];
}

bool _isEmailNotVerifiedError(Object err) {
  final s = err.toString().toLowerCase();
  return s.contains('email_not_verified') ||
      s.contains('email not verified') ||
      s.contains('email verification') ||
      s.contains('verify your email');
}

final meProfileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/users/me');
  final raw = res.data;
  final root = _asMap(raw);
  if (root['ok'] == true) return _unwrapMap(raw);
  throw Exception('Unexpected response');
});

final _meDraftProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/posts/draft?limit=1');
  final raw = res.data;
  final root = _asMap(raw);
  if (root['ok'] == true) {
    final items = _unwrapItems(raw);
    if (items.isNotEmpty) return items.first;
    final m = _unwrapMap(raw);
    if (m.isNotEmpty) return m;
  }
  return <String, dynamic>{};
});

final _mePostsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/posts?limit=12');
  final raw = res.data;
  final root = _asMap(raw);
  if (root['ok'] == true) return _unwrapItems(raw);
  return <Map<String, dynamic>>[];
});

final _meSavedProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/saves/me', queryParameters: {'limit': 12});
  final raw = res.data;
  final root = _asMap(raw);
  if (root['ok'] == true) return _unwrapItems(raw);
  return <Map<String, dynamic>>[];
});

final _meRepliesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/replies?limit=12');
  final raw = res.data;
  final root = _asMap(raw);
  if (root['ok'] == true) return _unwrapItems(raw);
  return <Map<String, dynamic>>[];
});

class MeScreen extends ConsumerStatefulWidget {
  const MeScreen({super.key});

  @override
  ConsumerState<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends ConsumerState<MeScreen> {
  bool _busyLogout = false;

  bool _isAdmin(Map<String, dynamic> me) {
    final role = (me['role'] ?? '').toString().toLowerCase();
    if (role == 'admin') return true;

    final list = _adminUserIdList();
    if (list.isEmpty) return false;

    final id = (me['id'] ?? '').toString();
    return id.isNotEmpty && list.contains(id);
  }

  Future<void> _openEditProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const EditProfileScreen(),
      ),
    );
    ref.invalidate(meProfileProvider);
  }

  Future<void> _logout() async {
    if (_busyLogout) return;
    setState(() => _busyLogout = true);

    try {
      final dio = ref.read(dioProvider);
      await dio.post('/auth/logout');
    } catch (_) {
      // ignore
    }

    try {
      ref.read(tokenStoreProvider).clear();
      ref.invalidate(authStatusProvider);
      ref.invalidate(isAuthedProvider);
      ref.invalidate(emailVerifiedProvider);
      ref.invalidate(meProfileProvider);

      if (!mounted) return;
      context.go('/');
    } finally {
      if (mounted) setState(() => _busyLogout = false);
    }
  }

  Future<void> _adminCreateAnnouncementDialog() async {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();

    String audience = 'PUBLIC';
    String kind = 'RELEASE';
    String status = 'PUBLISHED';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('New announcement'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bodyCtrl,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Body',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: audience,
                            decoration: const InputDecoration(labelText: 'Audience'),
                            items: const [
                              DropdownMenuItem(value: 'PUBLIC', child: Text('PUBLIC')),
                              DropdownMenuItem(value: 'MEMBERS', child: Text('MEMBERS')),
                              DropdownMenuItem(value: 'ADMINS', child: Text('ADMINS')),
                            ],
                            onChanged: (v) => setState(() => audience = v ?? audience),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: kind,
                            decoration: const InputDecoration(labelText: 'Kind'),
                            items: const [
                              DropdownMenuItem(value: 'RELEASE', child: Text('RELEASE')),
                              DropdownMenuItem(value: 'NOTICE', child: Text('NOTICE')),
                              DropdownMenuItem(value: 'POLICY', child: Text('POLICY')),
                            ],
                            onChanged: (v) => setState(() => kind = v ?? kind),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(value: 'PUBLISHED', child: Text('PUBLISHED')),
                        DropdownMenuItem(value: 'DRAFT', child: Text('DRAFT')),
                      ],
                      onChanged: (v) => setState(() => status = v ?? status),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Publish'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true) return;

    final title = titleCtrl.text.trim();
    final body = bodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) return;

    final dio = ref.read(dioProvider);
    try {
      await dio.post(
        '/announcements',
        data: {
          'title': title,
          'body': body,
          'audience': audience,
          'kind': kind,
          'status': status,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Announcement published.')),
        );
      }
    } on DioException catch (e) {
      final msg = (e.response?.data is Map)
          ? (e.response?.data).toString()
          : (e.message ?? 'Request failed');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024);
      if (file == null) return;

      final dio = ref.read(dioProvider);

      // Web does not support dart:io file paths. Use bytes.
      MultipartFile part;
      if (kIsWeb) {
          part = MultipartFile.fromBytes(
              await file.readAsBytes(),
              filename: file.name,
            )
          : await MultipartFile.fromFile(
              file.path,
              filename: file.name,
            );
          } else {
            part = await MultipartFile.fromFile(
             file.path,
             filename: file.name,
           );
         }

      final form = FormData.fromMap({'file': part});

      await dio.post('/uploads/avatar', data: form);
      ref.invalidate(meProfileProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar uploaded')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authed = ref.watch(isAuthedProvider);

    if (!authed) {
      return AuraScaffold(
        title: 'Account',
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ui.AuraCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('You are not signed in.', style: AuraText.title),
                  const SizedBox(height: 12),
                  Text(
                    'Sign in to manage your profile and see your drafts, posts, and saved items.',
                    style: AuraText.body,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton(
                        onPressed: () => context.go('/auth'),
                        child: const Text('Sign in'),
                      ),
                      OutlinedButton(
                        onPressed: () => context.go('/'),
                        child: const Text('Back'),
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

    final profileAsync = ref.watch(meProfileProvider);

    return AuraScaffold(
      title: 'Account',
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) {
          if (_isEmailNotVerifiedError(err)) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: ui.AuraCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Email verification required', style: AuraText.title),
                      const SizedBox(height: 10),
                      Text(
                        'Please verify your email to unlock writing and full account features.',
                        style: AuraText.body,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton(
                            onPressed: () async {
                              try {
                                final dio = ref.read(dioProvider);
                                await dio.post('/auth/resend-verification');
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Verification email sent')),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Could not resend: $e')),
                                );
                              }
                            },
                            child: const Text('Resend email'),
                          ),
                          OutlinedButton(
                            onPressed: () {
                              ref.invalidate(meProfileProvider);
                              ref.invalidate(emailVerifiedProvider);
                            },
                            child: const Text('Refresh'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: ui.AuraCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Profile load failed', style: AuraText.title),
                    const SizedBox(height: 10),
                    Text('$err', style: AuraText.small),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => ref.invalidate(meProfileProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        data: (me) {
          final id = (me['id'] ?? '').toString();
          final displayName = (me['displayName'] ?? '').toString();
          final handle = (me['handle'] ?? '').toString();
          final email = (me['email'] ?? '').toString();
          final bio = (me['bio'] ?? '').toString();
          final avatarUrl = (me['avatarUrl'] ?? '').toString();

          final isAdmin = _isAdmin(me);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 960;

                  final profileCard = ui.AuraCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () async {
                            await _openEditProfile();
                          },
                          child: CircleAvatar(
                            radius: 28,
                            backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                            child: avatarUrl.isEmpty ? const Icon(Icons.person) : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(0, 14, 16, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(displayName.isNotEmpty ? displayName : '—', style: AuraText.title),
                                const SizedBox(height: 6),
                                Text(handle.isNotEmpty ? '@$handle' : '—', style: AuraText.small),
                                const SizedBox(height: 6),
                                Text(email.isNotEmpty ? email : '—', style: AuraText.small),
                                if (bio.trim().isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Text(bio, style: AuraText.body),
                                ],
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    FilledButton(
                                      onPressed: _openEditProfile,
                                      child: const Text('Edit profile'),
                                    ),
                                    OutlinedButton(
                                      onPressed: _busyLogout ? null : _logout,
                                      child: Text(_busyLogout ? 'Signing out…' : 'Sign out'),
                                    ),
                                    OutlinedButton(
                                      onPressed: _pickAndUploadAvatar,
                                      child: const Text('Upload avatar'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Tip: tap your avatar to edit and upload a new photo.',
                                  style: AuraText.small,
                                ),
                                if (kDebugMode && id.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  SelectableText('User ID: $id', style: AuraText.small),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );

                  final toolsCard = ui.AuraCard(
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
                            if (isAdmin)
                              FilledButton(
                                onPressed: _adminCreateAnnouncementDialog,
                                child: const Text('New announcement'),
                              ),
                            OutlinedButton(
                              onPressed: () => context.go('/ai/claim-audit'),
                              child: const Text('Claim audit'),
                            ),
                          ],
                        ),
                        const SizedBox(height: AuraSpace.s10),
                        Text(
                          isAdmin
                              ? 'Announcements are official notes. Admins can publish announcements directly from here.'
                              : 'Announcements are official notes. Claim audit is a private tool for testing language before you publish.',
                          style: AuraText.small,
                        ),
                        if (!isAdmin && _adminUserIds.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Admin mode is configured, but your account is not the admin user.',
                            style: AuraText.small,
                          ),
                        ],
                      ],
                    ),
                  );

                  if (!wide) {
                    return Column(
                      children: [
                        profileCard,
                        const SizedBox(height: AuraSpace.s14),
                        toolsCard,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: profileCard),
                      const SizedBox(width: AuraSpace.s14),
                      Expanded(child: toolsCard),
                    ],
                  );
                },
              ),

              const SizedBox(height: AuraSpace.s14),

              // Draft
              ref.watch(_meDraftProvider).when(
                loading: () => ui.AuraCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: const [
                        SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text('Loading draft…'),
                      ],
                    ),
                  ),
                ),
                error: (err, st) => ui.AuraCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Draft load failed: $err', style: AuraText.small),
                  ),
                ),
                data: (draft) {
                  final title = (draft['title'] ?? '').toString().trim();
                  final hasDraft = draft.isNotEmpty && (draft['id'] != null);

                  if (!hasDraft) {
                    return ui.AuraCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Draft', style: AuraText.title),
                            const SizedBox(height: 10),
                            Text('No draft yet.', style: AuraText.small),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: () => context.go('/compose'),
                              child: const Text('Compose'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final id = (draft['id'] ?? '').toString();
                  return ui.AuraCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Draft', style: AuraText.title),
                          const SizedBox(height: 10),
                          Text(
                            title.isEmpty ? '(untitled)' : title,
                            style: AuraText.body,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              FilledButton(
                                onPressed: () => context.go('/compose'),
                                child: const Text('Continue drafting'),
                              ),
                              OutlinedButton(
                                onPressed: id.isEmpty ? null : () => context.go('/posts/$id'),
                                child: const Text('Open'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: AuraSpace.s14),

              // Posts
              ref.watch(_mePostsProvider).when(
                loading: () => ui.AuraCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: const [
                        SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text('Loading posts…'),
                      ],
                    ),
                  ),
                ),
                error: (err, st) => ui.AuraCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Posts load failed: $err', style: AuraText.small),
                  ),
                ),
                data: (items) {
                  return ui.AuraCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Posts', style: AuraText.title),
                          const SizedBox(height: 10),
                          Text(
                            items.isEmpty ? 'No posts yet.' : 'You have ${items.length} post(s).',
                            style: AuraText.small,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              FilledButton(
                                onPressed: () => context.go('/compose'),
                                child: const Text('Compose'),
                              ),
                              OutlinedButton(
                                onPressed: () => context.go('/feed'),
                                child: const Text('Browse feed'),
                              ),
                              OutlinedButton(
                                onPressed: () => ref.invalidate(_mePostsProvider),
                                child: const Text('Refresh'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: AuraSpace.s14),

              // Saved
              ref.watch(_meSavedProvider).when(
                loading: () => ui.AuraCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: const [
                        SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text('Loading saved…'),
                      ],
                    ),
                  ),
                ),
                error: (err, st) => ui.AuraCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Saved load failed: $err', style: AuraText.small),
                  ),
                ),
                data: (items) {
                  return ui.AuraCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Saved', style: AuraText.title),
                          const SizedBox(height: 10),
                          Text(
                            items.isEmpty ? 'No saved posts yet.' : 'You have ${items.length} saved item(s).',
                            style: AuraText.small,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              OutlinedButton(
                                onPressed: () => context.go('/saved'),
                                child: const Text('View saved'),
                              ),
                              OutlinedButton(
                                onPressed: () => ref.invalidate(_meSavedProvider),
                                child: const Text('Refresh'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: AuraSpace.s14),

              // Replies
              ref.watch(_meRepliesProvider).when(
                loading: () => ui.AuraCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: const [
                        SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text('Loading replies…'),
                      ],
                    ),
                  ),
                ),
                error: (err, st) => ui.AuraCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Replies load failed: $err', style: AuraText.small),
                  ),
                ),
                data: (items) {
                  return ui.AuraCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Replies', style: AuraText.title),
                          const SizedBox(height: 10),
                          Text(
                            items.isEmpty ? 'No replies yet.' : 'You have ${items.length} reply/replies.',
                            style: AuraText.small,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              OutlinedButton(
                                onPressed: () => context.go('/feed'),
                                child: const Text('Browse feed'),
                              ),
                              OutlinedButton(
                                onPressed: () => ref.invalidate(_meRepliesProvider),
                                child: const Text('Refresh'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}