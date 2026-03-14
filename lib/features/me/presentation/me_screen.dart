import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/session_providers.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart' as ui;
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import 'edit_profile_screen.dart';

const String _adminUserIds =
    String.fromEnvironment('AURA_ADMIN_USER_IDS', defaultValue: '');

const String _uploadEndpointForAnnouncementMedia = '/uploads/media';

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
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  final m = _unwrapMap(raw);

  final a = m['items'];
  if (a is List) {
    return a
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  final b = m['data'];
  if (b is List) {
    return b
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  if (b is Map && b['items'] is List) {
    final l = b['items'] as List;
    return l
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  if (b is Map && b['data'] is List) {
    final l = b['data'] as List;
    return l
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
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

final _meRepliesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
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
      context.go('/public');
    } finally {
      if (mounted) setState(() => _busyLogout = false);
    }
  }

  String _firstLineSummary(String body) {
    final t = body.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (t.isEmpty) return '';
    return t.length <= 160 ? t : '${t.substring(0, 160).trim()}…';
  }

  String? _extractMediaId(dynamic raw) {
    final m = _asMap(raw);
    if (m.isEmpty) return null;

    dynamic cur = m;
    if (cur is Map && cur['data'] is Map) cur = cur['data'];
    if (cur is Map && cur['item'] is Map) cur = cur['item'];

    if (cur is Map) {
      final mediaId = cur['mediaId'] ?? cur['id'];
      if (mediaId != null) {
        final s = mediaId.toString().trim();
        if (s.isNotEmpty) return s;
      }
      final media = cur['media'];
      if (media is Map) {
        final id = media['id'];
        if (id != null) {
          final s = id.toString().trim();
          if (s.isNotEmpty) return s;
        }
      }
    }

    return null;
  }

  Future<String?> _pickAndUploadAnnouncementImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1400,
    );
    if (file == null) return null;

    final dio = ref.read(dioProvider);

    MultipartFile part;
    if (kIsWeb) {
      part = MultipartFile.fromBytes(
        await file.readAsBytes(),
        filename: file.name,
      );
    } else {
      part = await MultipartFile.fromFile(
        file.path,
        filename: file.name,
      );
    }

    final form = FormData.fromMap({'file': part});

    final res = await dio.post(_uploadEndpointForAnnouncementMedia, data: form);
    final mediaId = _extractMediaId(res.data);

    return mediaId;
  }

  Future<void> _adminCreateAnnouncementDialog() async {
    final titleCtrl = TextEditingController();
    final summaryCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();

    String audience = 'PUBLIC';
    String kind = 'RELEASE';
    String status = 'PUBLISHED';

    bool pinned = false;
    String? mediaId;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            Future<void> addImage() async {
              try {
                final id = await _pickAndUploadAnnouncementImage();
                if (id == null || id.trim().isEmpty) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Upload did not return a media id.'),
                    ),
                  );
                  return;
                }
                setState(() => mediaId = id);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Upload failed: $e')),
                );
              }
            }

            void removeImage() => setState(() => mediaId = null);

            return AlertDialog(
              title: const Text('New announcement'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
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
                        controller: summaryCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Summary',
                          hintText: 'Required (short, 1–2 lines)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: bodyCtrl,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'Body (Markdown)',
                        ),
                        onChanged: (v) {
                          if (summaryCtrl.text.trim().isEmpty) {
                            final s = _firstLineSummary(v);
                            if (s.isNotEmpty) summaryCtrl.text = s;
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: audience,
                              decoration:
                                  const InputDecoration(labelText: 'Audience'),
                              items: const [
                                DropdownMenuItem(
                                  value: 'PUBLIC',
                                  child: Text('PUBLIC'),
                                ),
                                DropdownMenuItem(
                                  value: 'MEMBERS',
                                  child: Text('MEMBERS'),
                                ),
                                DropdownMenuItem(
                                  value: 'INTERNAL',
                                  child: Text('INTERNAL'),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => audience = v ?? audience),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: kind,
                              decoration:
                                  const InputDecoration(labelText: 'Kind'),
                              items: const [
                                DropdownMenuItem(
                                  value: 'GENERAL',
                                  child: Text('GENERAL'),
                                ),
                                DropdownMenuItem(
                                  value: 'RELEASE',
                                  child: Text('RELEASE'),
                                ),
                                DropdownMenuItem(
                                  value: 'SAFETY',
                                  child: Text('SAFETY'),
                                ),
                                DropdownMenuItem(
                                  value: 'GOVERNANCE',
                                  child: Text('GOVERNANCE'),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => kind = v ?? kind),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: status,
                        decoration:
                            const InputDecoration(labelText: 'Status'),
                        items: const [
                          DropdownMenuItem(
                            value: 'PUBLISHED',
                            child: Text('PUBLISHED'),
                          ),
                          DropdownMenuItem(
                            value: 'DRAFT',
                            child: Text('DRAFT'),
                          ),
                        ],
                        onChanged: (v) => setState(() => status = v ?? status),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Pinned'),
                        value: pinned,
                        onChanged: (v) => setState(() => pinned = v),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: addImage,
                            icon: const Icon(Icons.image_outlined),
                            label: const Text('Add image'),
                          ),
                          const SizedBox(width: 10),
                          if (mediaId != null && mediaId!.isNotEmpty)
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Attached: ${mediaId!}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Remove',
                                    onPressed: removeImage,
                                    icon: const Icon(Icons.close),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      if (mediaId == null || mediaId!.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Optional: add one image (Phase 1).',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(
                    status == 'PUBLISHED' ? 'Publish' : 'Save draft',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true) return;

    final title = titleCtrl.text.trim();
    final summary = summaryCtrl.text.trim();
    final bodyMd = bodyCtrl.text.trim();

    if (title.isEmpty || summary.isEmpty || bodyMd.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Title, Summary, and Body are required.'),
        ),
      );
      return;
    }

    final excerpt = summary;
    final dio = ref.read(dioProvider);

    try {
      final createRes = await dio.post(
        '/admin/announcements',
        data: {
          'title': title,
          'summary': summary,
          'excerpt': excerpt,
          'bodyMarkdown': bodyMd,
          'audience': audience,
          'kind': kind,
          'pinned': pinned,
          if (mediaId != null && mediaId!.trim().isNotEmpty)
            'mediaIds': [mediaId!.trim()],
        },
      );

      final createdMap = _unwrapMap(createRes.data);
      final createdId = (createdMap['id'] ?? '').toString().trim();

      if (createdId.isEmpty) {
        throw Exception('Announcement created but no id returned.');
      }

      if (status == 'PUBLISHED') {
        await dio.post('/admin/announcements/$createdId/publish');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'PUBLISHED' ? 'Announcement published.' : 'Draft saved.',
          ),
        ),
      );
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;

      if (statusCode == 403) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Forbidden: your account is not an admin.'),
          ),
        );
        return;
      }

      final msg = (e.response?.data is Map)
          ? (e.response?.data).toString()
          : (e.message ?? 'Request failed');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
      );
      if (file == null) return;

      final dio = ref.read(dioProvider);

      MultipartFile part;
      if (kIsWeb) {
        part = MultipartFile.fromBytes(
          await file.readAsBytes(),
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
        const SnackBar(content: Text('Photo uploaded')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
  }

  Widget _statTile({
    required String title,
    required String detail,
    required String status,
    VoidCallback? onTap,
  }) {
    final enabled = onTap != null;

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(detail, style: AuraText.body),
                const SizedBox(height: 10),
                Text(
                  status,
                  style: AuraText.small.copyWith(
                    fontWeight: FontWeight.w600,
                    color: enabled ? Colors.black87 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tileGrid(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 900.0;

        double tileWidth;
        if (maxWidth >= 1100) {
          tileWidth = (maxWidth - AuraSpace.s12 * 2) / 3;
        } else if (maxWidth >= 720) {
          tileWidth = (maxWidth - AuraSpace.s12) / 2;
        } else {
          tileWidth = maxWidth;
        }

        tileWidth = tileWidth.clamp(0.0, 360.0);

        return Wrap(
          spacing: AuraSpace.s12,
          runSpacing: AuraSpace.s12,
          children: children
              .map((child) => SizedBox(width: tileWidth, child: child))
              .toList(),
        );
      },
    );
  }

  Widget _sectionCard({
    required String title,
    String? intro,
    required List<Widget> children,
  }) {
    return ui.AuraCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AuraText.title),
            if (intro != null && intro.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(intro, style: AuraText.small),
            ],
            const SizedBox(height: 12),
            _tileGrid(children),
          ],
        ),
      ),
    );
  }

  Widget _profileCard({
    required String displayName,
    required String handle,
    required String bio,
    required String avatarUrl,
    required String id,
    required bool isAdmin,
  }) {
    final identityText = handle.isNotEmpty ? '@$handle' : '—';

    return ui.AuraCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 640;

            final avatar = GestureDetector(
              onTap: _openEditProfile,
              child: CircleAvatar(
                radius: 34,
                backgroundImage:
                    avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                child: avatarUrl.isEmpty ? const Icon(Icons.person, size: 28) : null,
              ),
            );

            final content = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName.isNotEmpty ? displayName : '—',
                  style: AuraText.title,
                ),
                const SizedBox(height: 6),
                Text(identityText, style: AuraText.small),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isAdmin ? 'App admin account' : 'Member account',
                    style: AuraText.small.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  bio.trim().isNotEmpty
                      ? bio
                      : 'This is your member presence inside Aura.',
                  style: AuraText.body,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton(
                      onPressed: _openEditProfile,
                      child: const Text('Edit profile'),
                    ),
                    OutlinedButton(
                      onPressed: _pickAndUploadPhoto,
                      child: const Text('Upload photo'),
                    ),
                    OutlinedButton(
                      onPressed: _busyLogout ? null : _logout,
                      child: Text(_busyLogout ? 'Signing out…' : 'Sign out'),
                    ),
                  ],
                ),
                if (kDebugMode && id.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SelectableText(
                    'User ID: $id',
                    style: AuraText.small,
                  ),
                ],
              ],
            );

            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  avatar,
                  const SizedBox(height: 14),
                  content,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                avatar,
                const SizedBox(width: 16),
                Expanded(child: content),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _connectionsCard(BuildContext context, String handle) {
    final hasHandle = handle.trim().isNotEmpty;

    return _sectionCard(
      title: 'Connections',
      intro:
          'The relationship surfaces around your presence in Aura.',
      children: [
        _statTile(
          title: 'Followers',
          detail: 'People who follow your profile.',
          status: hasHandle ? 'Available now' : 'Unavailable',
          onTap: hasHandle ? () => context.go('/u/$handle/followers') : null,
        ),
        _statTile(
          title: 'Following',
          detail: 'People your account currently follows.',
          status: hasHandle ? 'Available now' : 'Unavailable',
          onTap: hasHandle ? () => context.go('/u/$handle/following') : null,
        ),
        _statTile(
          title: 'Follow requests',
          detail: 'Accept or deny pending follow requests.',
          status: 'Available now',
          onTap: () => context.go('/me/follow-requests'),
        ),
      ],
    );
  }

  Widget _activityCard(BuildContext context) {
    return _sectionCard(
      title: 'Your activity',
      intro:
          'Your writing, saved work, and ongoing presence inside Aura.',
      children: [
        _statTile(
          title: 'Compose',
          detail: 'Write a new post from your member account.',
          status: 'Available now',
          onTap: () => context.go('/compose'),
        ),
        _statTile(
          title: 'Draft',
          detail: 'Open your current draft and continue where you left off.',
          status: 'Available now',
          onTap: () => context.go('/compose'),
        ),
        _statTile(
          title: 'Posts',
          detail: 'Review your published writing and profile activity.',
          status: 'Available now',
          onTap: () => context.go('/home'),
        ),
        _statTile(
          title: 'Replies',
          detail: 'View the replies attached to your activity in Aura.',
          status: 'Available now',
          onTap: () => context.go('/home'),
        ),
        _statTile(
          title: 'Saved',
          detail: 'Open the posts and items you have saved.',
          status: 'Available now',
          onTap: () => context.go('/saved'),
        ),
      ],
    );
  }

  Widget _adminToolsCard(BuildContext context) {
    return _sectionCard(
      title: 'Admin tools',
      intro:
          'Separate controls for platform administration. Kept secondary to your member identity.',
      children: [
        _statTile(
          title: 'Publish announcement',
          detail:
              'Create and publish official platform announcements.',
          status: 'Admin only',
          onTap: _adminCreateAnnouncementDialog,
        ),
        _statTile(
          title: 'Correspondence hub',
          detail:
              'Open the admin-level correspondence surface.',
          status: 'Admin only',
          onTap: () => context.go('/me/correspondence'),
        ),
        _statTile(
          title: 'Announcements',
          detail:
              'Review the live platform announcements surface.',
          status: 'Available now',
          onTap: () => context.go('/announcements'),
        ),
        _statTile(
          title: 'Institution dashboard',
          detail:
              'Open the institution-facing workspace separately.',
          status: 'Separate surface',
          onTap: () => context.go('/institution/dashboard'),
        ),
      ],
    );
  }

  Widget _asyncStatusCard({
    required AsyncValue<dynamic> asyncValue,
    required Widget Function(dynamic data) dataBuilder,
    required String loadingLabel,
    required String errorLabel,
  }) {
    return asyncValue.when(
      loading: () => ui.AuraCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  loadingLabel,
                  style: AuraText.body,
                ),
              ),
            ],
          ),
        ),
      ),
      error: (err, st) => ui.AuraCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '$errorLabel: $err',
            style: AuraText.small,
          ),
        ),
      ),
      data: dataBuilder,
    );
  }

  Widget _draftCard(BuildContext context, Map<String, dynamic> draft) {
    final title = (draft['title'] ?? '').toString().trim();
    final hasDraft = draft.isNotEmpty && (draft['id'] != null);
    final did = (draft['id'] ?? '').toString();

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
                  onPressed: did.isEmpty ? null : () => context.go('/posts/$did'),
                  child: const Text('Open'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _countCard({
    required String title,
    required String emptyLabel,
    required String countLabel,
    required List<Map<String, dynamic>> items,
    required List<Widget> actions,
  }) {
    return ui.AuraCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AuraText.title),
            const SizedBox(height: 10),
            Text(
              items.isEmpty ? emptyLabel : countLabel,
              style: AuraText.small,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: actions,
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardList(List<Widget> children) {
    final items = <Widget>[];

    for (var i = 0; i < children.length; i++) {
      items.add(children[i]);

      if (i != children.length - 1) {
        items.add(const SizedBox(height: AuraSpace.s14));
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        double horizontalPadding;
        double maxWidth;

        if (width < 600) {
          horizontalPadding = 12;
          maxWidth = double.infinity;
        } else if (width < 980) {
          horizontalPadding = 24;
          maxWidth = 760;
        } else {
          horizontalPadding = 32;
          maxWidth = 820;
        }

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                16,
                horizontalPadding,
                28,
              ),
              children: items,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authed = ref.watch(isAuthedProvider);

    if (!authed) {
      return AuraScaffold(
        showHeader: false,
        body: _cardList([
          ui.AuraCard(
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
                        onPressed: () => context.go('/login'),
                        child: const Text('Sign in'),
                      ),
                      OutlinedButton(
                        onPressed: () => context.go('/public'),
                        child: const Text('Back'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ]),
      );
    }

    final profileAsync = ref.watch(meProfileProvider);

    return AuraScaffold(
      showHeader: false,
      body: profileAsync.when(
        loading: () => _cardList(const [
          ui.AuraCard(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        ]),
        error: (err, st) {
          if (_isEmailNotVerifiedError(err)) {
            return _cardList([
              ui.AuraCard(
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
                                  const SnackBar(
                                    content: Text('Verification email sent'),
                                  ),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Could not resend: $e'),
                                  ),
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
            ]);
          }

          return _cardList([
            ui.AuraCard(
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
          ]);
        },
        data: (me) {
          final profile = (me['profile'] is Map)
              ? Map<String, dynamic>.from(me['profile'] as Map)
              : <String, dynamic>{};

          final id = (me['id'] ?? '').toString();
          final handle = (me['handle'] ?? '').toString();
          final displayName =
              (profile['displayName'] ?? me['displayName'] ?? '').toString();
          final bio = (profile['bio'] ?? me['bio'] ?? '').toString();
          final avatarUrl =
              (profile['avatarUrl'] ?? me['avatarUrl'] ?? '').toString();
          final isAdmin = _isAdmin(me);

          return _cardList([
            _profileCard(
              displayName: displayName,
              handle: handle,
              bio: bio,
              avatarUrl: avatarUrl,
              id: id,
              isAdmin: isAdmin,
            ),
            _connectionsCard(context, handle),
            _activityCard(context),
            _asyncStatusCard(
              asyncValue: ref.watch(_meDraftProvider),
              loadingLabel: 'Loading draft…',
              errorLabel: 'Draft load failed',
              dataBuilder: (draft) => _draftCard(
                context,
                Map<String, dynamic>.from(draft as Map),
              ),
            ),
            _asyncStatusCard(
              asyncValue: ref.watch(_mePostsProvider),
              loadingLabel: 'Loading posts…',
              errorLabel: 'Posts load failed',
              dataBuilder: (items) => _countCard(
                title: 'Posts',
                emptyLabel: 'No posts yet.',
                countLabel:
                    'You have ${(items as List<Map<String, dynamic>>).length} post(s).',
                items: items,
                actions: [
                  FilledButton(
                    onPressed: () => context.go('/compose'),
                    child: const Text('Compose'),
                  ),
                  OutlinedButton(
                    onPressed: () => context.go('/home'),
                    child: const Text('Open feed'),
                  ),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(_mePostsProvider),
                    child: const Text('Refresh'),
                  ),
                ],
              ),
            ),
            _asyncStatusCard(
              asyncValue: ref.watch(_meSavedProvider),
              loadingLabel: 'Loading saved…',
              errorLabel: 'Saved load failed',
              dataBuilder: (items) => _countCard(
                title: 'Saved',
                emptyLabel: 'No saved posts yet.',
                countLabel:
                    'You have ${(items as List<Map<String, dynamic>>).length} saved item(s).',
                items: items,
                actions: [
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
            ),
            _asyncStatusCard(
              asyncValue: ref.watch(_meRepliesProvider),
              loadingLabel: 'Loading replies…',
              errorLabel: 'Replies load failed',
              dataBuilder: (items) => _countCard(
                title: 'Replies',
                emptyLabel: 'No replies yet.',
                countLabel:
                    'You have ${(items as List<Map<String, dynamic>>).length} reply/replies.',
                items: items,
                actions: [
                  OutlinedButton(
                    onPressed: () => context.go('/home'),
                    child: const Text('Open feed'),
                  ),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(_meRepliesProvider),
                    child: const Text('Refresh'),
                  ),
                ],
              ),
            ),
            if (isAdmin) _adminToolsCard(context),
          ]);
        },
      ),
    );
  }
}
