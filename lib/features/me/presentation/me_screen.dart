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

  bool _isAdmin(Map<String, dynamic> me) {
    final id = (me['id'] ?? '').toString();
    return id.isNotEmpty && _adminUserIdList().contains(id);
  }

  Future<void> _openEditProfile() async {
    final res = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );

    // If user saved, refresh profile/drafts/etc
    if (res != null) {
      ref.invalidate(meProfileProvider);
      ref.invalidate(_meDraftProvider);
      ref.invalidate(_mePostsProvider);
      ref.invalidate(_meSavesProvider);
      ref.invalidate(_meRepliesProvider);
    }
  }

  Future<void> _adminCreateAnnouncementDialog() async {
    final titleCtl = TextEditingController();
    final bodyCtl = TextEditingController();
    String audience = 'MEMBERS';
    String kind = 'GENERAL';
    String status = 'PUBLISHED';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('New announcement'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtl,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      hintText: 'Short, factual, official',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bodyCtl,
                    maxLines: 7,
                    decoration: const InputDecoration(
                      labelText: 'Body',
                      hintText: 'Write the announcement. Keep it clear and calm.',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: audience,
                          decoration: const InputDecoration(labelText: 'Audience'),
                          items: const [
                            DropdownMenuItem(value: 'PUBLIC', child: Text('PUBLIC')),
                            DropdownMenuItem(value: 'MEMBERS', child: Text('MEMBERS')),
                            DropdownMenuItem(value: 'INTERNAL', child: Text('INTERNAL')),
                          ],
                          onChanged: (v) => audience = v ?? 'MEMBERS',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: kind,
                          decoration: const InputDecoration(labelText: 'Kind'),
                          items: const [
                            DropdownMenuItem(value: 'GENERAL', child: Text('GENERAL')),
                            DropdownMenuItem(value: 'RELEASE', child: Text('RELEASE')),
                            DropdownMenuItem(value: 'SAFETY', child: Text('SAFETY')),
                            DropdownMenuItem(value: 'GOVERNANCE', child: Text('GOVERNANCE')),
                          ],
                          onChanged: (v) => kind = v ?? 'GENERAL',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: 'DRAFT', child: Text('DRAFT')),
                      DropdownMenuItem(value: 'PUBLISHED', child: Text('PUBLISHED')),
                    ],
                    onChanged: (v) => status = v ?? 'PUBLISHED',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Publish')),
          ],
        );
      },
    );

    if (ok != true) return;

    final title = titleCtl.text.trim();
    final body = bodyCtl.text.trim();

    if (title.isEmpty || body.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and body are required.')),
      );
      return;
    }

    try {
      final dio = ref.read(dioProvider);

      // Assumed endpoint contract: POST /announcements
      // Backend should enforce admin permission; UI only gates visibility.
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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Announcement created')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create announcement: $e')),
      );
    } finally {
      titleCtl.dispose();
      bodyCtl.dispose();
    }
  }

  Future<void> _logout() async {
    if (_busyLogout) return;
    setState(() => _busyLogout = true);

    try {
      final dio = ref.read(dioProvider);

      // Best-effort revoke server session (ignore failures)
      try {
        await dio.post('/auth/logout');
      } catch (_) {}

      final store = ref.read(tokenStoreProvider);
      await store.clear();

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
          // Allow a friendly message for EMAIL_NOT_VERIFIED
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
                    Text('Could not load your profile.', style: AuraText.title),
                    const SizedBox(height: 12),
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
              // Profile
              ui.AuraCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        // Quick avatar upload entrypoint remains: edit screen has full flow
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

                      return ui.AuraCard(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Draft', style: AuraText.title),
                              const SizedBox(height: 10),
                              Text(title.isNotEmpty ? title : '(Untitled)', style: AuraText.body),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  FilledButton(
                                    onPressed: () => context.go('/compose'),
                                    child: const Text('Continue'),
                                  ),
                                  OutlinedButton(
                                    onPressed: () => ref.invalidate(_meDraftProvider),
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
                              Text('Your posts', style: AuraText.title),
                              const SizedBox(height: 10),
                              if (items.isEmpty)
                                Text('No posts yet.', style: AuraText.small)
                              else
                                Text('You have ${items.length} post(s).', style: AuraText.small),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  OutlinedButton(
                                    onPressed: () => context.go('/compose'),
                                    child: const Text('Compose'),
                                  ),
                                  OutlinedButton(
                                    onPressed: () => context.go('/feed'),
                                    child: const Text('View feed'),
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
              ref.watch(_meSavesProvider).when(
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
                                items.isEmpty ? 'Nothing saved yet.' : 'You have ${items.length} saved item(s).',
                                style: AuraText.small,
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  OutlinedButton(
                                    onPressed: () => context.go('/saved'),
                                    child: const Text('Open saved'),
                                  ),
                                  OutlinedButton(
                                    onPressed: () => ref.invalidate(_meSavesProvider),
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

              const SizedBox(height: AuraSpace.s14),

              // Tools (beta)
              ui.AuraCard(
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
              ),
            ],
          );
        },
      ),
    );
  }
}