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
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/profile_header.dart';
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

int? _readMeaningfulCount(List<dynamic> candidates) {
  for (final value in candidates) {
    if (value is int && value > 0) return value;
    if (value is num && value.toInt() > 0) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null && parsed > 0) return parsed;
    }
  }
  return null;
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

final _mePostsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/posts?limit=12');
  final raw = res.data;
  final root = _asMap(raw);
  if (root['ok'] == true) return _unwrapItems(raw);
  return <Map<String, dynamic>>[];
});

final _meSavedProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
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

  String _extractPostPreview(Map<String, dynamic> post) {
    final raw = [
      post['excerpt'],
      post['summary'],
      post['body'],
      post['bodyMarkdown'],
      post['content'],
      post['text'],
    ].firstWhere(
      (e) => e != null && e.toString().trim().isNotEmpty,
      orElse: () => '',
    );

    final text = raw.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.isEmpty) return '';
    return text.length <= 180 ? text : '${text.substring(0, 180).trim()}…';
  }

  String _extractPostTitle(Map<String, dynamic> post) {
    final raw = [
      post['title'],
      post['headline'],
      post['name'],
    ].firstWhere(
      (e) => e != null && e.toString().trim().isNotEmpty,
      orElse: () => '',
    );

    final title = raw.toString().trim();
    if (title.isNotEmpty) return title;

    final preview = _extractPostPreview(post);
    if (preview.isEmpty) return 'Untitled';
    return preview.length <= 80 ? preview : '${preview.substring(0, 80).trim()}…';
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
                        decoration: const InputDecoration(labelText: 'Title'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: summaryCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Summary',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: bodyCtrl,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'Body',
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
                              decoration: const InputDecoration(
                                labelText: 'Audience',
                              ),
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
                              decoration: const InputDecoration(
                                labelText: 'Kind',
                              ),
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
                        decoration: const InputDecoration(labelText: 'Status'),
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
                                      mediaId!,
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
          content: Text('Title, summary, and body are required.'),
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
          const SnackBar(content: Text('Forbidden')),
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

  Widget _pillButton({
    required String label,
    required VoidCallback? onTap,
    IconData? icon,
    bool primary = false,
  }) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16),
          const SizedBox(width: 8),
        ],
        Text(label),
      ],
    );

    if (primary) {
      return FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: child,
      );
    }

    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s10),
      child: Text(title, style: AuraText.title),
    );
  }

  Widget _section({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(title),
        ui.AuraCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: _withDividers(children),
          ),
        ),
      ],
    );
  }

  List<Widget> _withDividers(List<Widget> children) {
    final out = <Widget>[];

    for (var i = 0; i < children.length; i++) {
      out.add(children[i]);
      if (i != children.length - 1) {
        out.add(const Divider(
          height: 1,
          thickness: 1,
          color: AuraSurface.divider,
        ));
      }
    }

    return out;
  }

  Widget _sectionRow({
    required String title,
    String? subtitle,
    String? trailing,
    required VoidCallback? onTap,
    IconData? leading,
    bool enabled = true,
  }) {
    final active = enabled && onTap != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: active ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s16,
            vertical: AuraSpace.s14,
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                Icon(
                  leading,
                  size: 18,
                  color: active ? AuraSurface.ink : AuraSurface.muted,
                ),
                const SizedBox(width: AuraSpace.s12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AuraText.body.copyWith(
                        fontWeight: FontWeight.w700,
                        color: active ? AuraSurface.ink : AuraSurface.muted,
                      ),
                    ),
                    if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: AuraText.small.copyWith(
                          color: AuraSurface.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null && trailing.trim().isNotEmpty) ...[
                Text(
                  trailing,
                  style: AuraText.small.copyWith(
                    color: AuraSurface.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: AuraSpace.s10),
              ],
              Icon(
                Icons.chevron_right,
                size: 18,
                color: active ? AuraSurface.muted : AuraSurface.divider,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _workSection(
    BuildContext context, {
    required List<Map<String, dynamic>> posts,
    required bool hasDraft,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Work'),
        if (posts.isEmpty && !hasDraft)
          ui.AuraCard(
            child: Padding(
              padding: const EdgeInsets.all(AuraSpace.s18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No work yet.', style: AuraText.body),
                  const SizedBox(height: AuraSpace.s12),
                  _pillButton(
                    label: 'Compose',
                    onTap: () => context.go('/compose'),
                    icon: Icons.edit_outlined,
                    primary: true,
                  ),
                ],
              ),
            ),
          )
        else ...[
          if (hasDraft)
            Padding(
              padding: const EdgeInsets.only(bottom: AuraSpace.s10),
              child: ui.AuraCard(
                child: InkWell(
                  onTap: () => context.go('/compose'),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(AuraSpace.s16),
                    child: Row(
                      children: [
                        const Icon(Icons.drafts_outlined, size: 18),
                        const SizedBox(width: AuraSpace.s12),
                        Expanded(
                          child: Text(
                            'Draft',
                            style: AuraText.body.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          'Continue',
                          style: AuraText.small.copyWith(
                            color: AuraSurface.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ...posts.take(4).map(
                (post) => Padding(
                  padding: const EdgeInsets.only(bottom: AuraSpace.s10),
                  child: _PostPreviewCard(
                    title: _extractPostTitle(post),
                    preview: _extractPostPreview(post),
                    onTap: () => context.go('/home'),
                  ),
                ),
              ),
          if (posts.length > 4)
            Padding(
              padding: const EdgeInsets.only(top: AuraSpace.s4),
              child: TextButton(
                onPressed: () => context.go('/home'),
                child: const Text('View all posts'),
              ),
            ),
        ],
      ],
    );
  }

  Widget _connectionsSection(
    BuildContext context,
    String handle, {
    int? followersCount,
    int? followingCount,
  }) {
    final hasHandle = handle.trim().isNotEmpty;

    return _section(
      title: 'Connections',
      children: [
        _sectionRow(
          title: 'Followers',
          trailing: followersCount != null ? '$followersCount' : null,
          leading: Icons.people_outline,
          onTap: hasHandle ? () => context.go('/u/$handle/followers') : null,
        ),
        _sectionRow(
          title: 'Following',
          trailing: followingCount != null ? '$followingCount' : null,
          leading: Icons.person_add_alt_outlined,
          onTap: hasHandle ? () => context.go('/u/$handle/following') : null,
        ),
        _sectionRow(
          title: 'Requests',
          leading: Icons.mail_outline,
          onTap: () => context.go('/me/follow-requests'),
        ),
      ],
    );
  }

  Widget _toolsSection(
    BuildContext context, {
    required bool hasDraft,
    int? savedCount,
    int? repliesCount,
  }) {
    return _section(
      title: 'Tools',
      children: [
        _sectionRow(
          title: 'Compose',
          leading: Icons.edit_outlined,
          onTap: () => context.go('/compose'),
        ),
        _sectionRow(
          title: 'Draft',
          trailing: hasDraft ? '1' : null,
          leading: Icons.drafts_outlined,
          onTap: () => context.go('/compose'),
        ),
        _sectionRow(
          title: 'Saved',
          trailing: savedCount != null ? '$savedCount' : null,
          leading: Icons.bookmark_border,
          onTap: () => context.go('/saved'),
        ),
        _sectionRow(
          title: 'Replies',
          trailing: repliesCount != null ? '$repliesCount' : null,
          leading: Icons.reply_outlined,
          onTap: () => context.go('/home'),
        ),
      ],
    );
  }

  Widget _adminSection(BuildContext context) {
    return _section(
      title: 'Admin',
      children: [
        _sectionRow(
          title: 'Publish announcement',
          leading: Icons.campaign_outlined,
          onTap: _adminCreateAnnouncementDialog,
        ),
        _sectionRow(
          title: 'Correspondence',
          leading: Icons.forum_outlined,
          onTap: () => context.go('/me/correspondence'),
        ),
        _sectionRow(
          title: 'Announcements',
          leading: Icons.notifications_outlined,
          onTap: () => context.go('/announcements'),
        ),
        _sectionRow(
          title: 'Institution',
          leading: Icons.apartment_outlined,
          onTap: () => context.go('/institution/dashboard'),
        ),
      ],
    );
  }

  Widget _cardList(List<Widget> children) {
    final items = <Widget>[];

    for (var i = 0; i < children.length; i++) {
      items.add(children[i]);
      if (i != children.length - 1) {
        items.add(const SizedBox(height: 32));
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
          maxWidth = 860;
        }

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                18,
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
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sign in', style: AuraText.title),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _pillButton(
                        label: 'Sign in',
                        onTap: () => context.go('/login'),
                        primary: true,
                      ),
                      _pillButton(
                        label: 'Back',
                        onTap: () => context.go('/public'),
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
    final draftAsync = ref.watch(_meDraftProvider);
    final postsAsync = ref.watch(_mePostsProvider);
    final savedAsync = ref.watch(_meSavedProvider);
    final repliesAsync = ref.watch(_meRepliesProvider);

    return AuraScaffold(
      showHeader: false,
      body: profileAsync.when(
        loading: () => _cardList(const [
          ui.AuraCard(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        ]),
        error: (err, st) {
          if (_isEmailNotVerifiedError(err)) {
            return _cardList([
              ui.AuraCard(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _pillButton(
                        label: 'Resend email',
                        onTap: () async {
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
                              SnackBar(content: Text('Could not resend: $e')),
                            );
                          }
                        },
                        primary: true,
                      ),
                      _pillButton(
                        label: 'Refresh',
                        onTap: () {
                          ref.invalidate(meProfileProvider);
                          ref.invalidate(emailVerifiedProvider);
                        },
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
                padding: const EdgeInsets.all(18),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    Text('Profile load failed', style: AuraText.title),
                    _pillButton(
                      label: 'Retry',
                      onTap: () => ref.invalidate(meProfileProvider),
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

          final hasDraft = draftAsync.maybeWhen(
            data: (draft) => draft.isNotEmpty && draft['id'] != null,
            orElse: () => false,
          );

          final posts = postsAsync.maybeWhen(
            data: (items) => items,
            orElse: () => const <Map<String, dynamic>>[],
          );

          final ownPostsCount = posts.isNotEmpty ? posts.length : null;

          final savedCount = savedAsync.maybeWhen(
            data: (items) => items.isNotEmpty ? items.length : null,
            orElse: () => null,
          );

          final repliesCount = repliesAsync.maybeWhen(
            data: (items) => items.isNotEmpty ? items.length : null,
            orElse: () => null,
          );

          final followersCount = _readMeaningfulCount([
            me['followersCount'],
            profile['followersCount'],
          ]);

          final followingCount = _readMeaningfulCount([
            me['followingCount'],
            profile['followingCount'],
          ]);

          return _cardList([
            ProfileHeader(
              displayName: displayName,
              handle: handle,
              bio: bio,
              avatarUrl: avatarUrl,
              stats: [
                ProfileHeaderStat(
                  label: 'Followers',
                  value: followersCount != null ? '$followersCount' : '—',
                  onTap: handle.trim().isNotEmpty
                      ? () => context.go('/u/$handle/followers')
                      : null,
                ),
                ProfileHeaderStat(
                  label: 'Following',
                  value: followingCount != null ? '$followingCount' : '—',
                  onTap: handle.trim().isNotEmpty
                      ? () => context.go('/u/$handle/following')
                      : null,
                ),
                if (ownPostsCount != null)
                  ProfileHeaderStat(
                    label: 'Posts',
                    value: '$ownPostsCount',
                  ),
              ],
              actions: [
                ProfileHeaderAction(
                  label: 'Edit profile',
                  onTap: _openEditProfile,
                  primary: true,
                  icon: Icons.edit_outlined,
                ),
                ProfileHeaderAction(
                  label: 'Upload photo',
                  onTap: _pickAndUploadPhoto,
                  icon: Icons.image_outlined,
                ),
                ProfileHeaderAction(
                  label: _busyLogout ? 'Signing out…' : 'Sign out',
                  onTap: _busyLogout ? null : _logout,
                  icon: Icons.logout,
                ),
              ],
              trailingMeta: [
                if (isAdmin)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AuraSurface.divider),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Admin',
                      style: AuraText.small.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (kDebugMode && id.isNotEmpty)
                  SelectableText(
                    'ID: $id',
                    style: AuraText.small,
                  ),
              ],
            ),
            _workSection(
              context,
              posts: posts,
              hasDraft: hasDraft,
            ),
            _connectionsSection(
              context,
              handle,
              followersCount: followersCount,
              followingCount: followingCount,
            ),
            _toolsSection(
              context,
              hasDraft: hasDraft,
              savedCount: savedCount,
              repliesCount: repliesCount,
            ),
            if (isAdmin) _adminSection(context),
          ]);
        },
      ),
    );
  }
}

class _PostPreviewCard extends StatelessWidget {
  const _PostPreviewCard({
    required this.title,
    required this.preview,
    required this.onTap,
  });

  final String title;
  final String preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ui.AuraCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(AuraSpace.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AuraText.body.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (preview.isNotEmpty) ...[
                const SizedBox(height: AuraSpace.s8),
                Text(
                  preview,
                  style: AuraText.small.copyWith(
                    color: AuraSurface.muted,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
