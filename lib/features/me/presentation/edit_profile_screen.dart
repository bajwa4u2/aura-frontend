import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';

final meProfileRawProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/users/me');
  final data = res.data;

  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);

  throw Exception('Unexpected response');
});

Map<String, dynamic> _asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return <String, dynamic>{};
}

Map<String, dynamic> _unwrap(dynamic raw) {
  final root = _asMap(raw);
  dynamic inner = root['data'];
  if (inner is Map && inner['data'] is Map) inner = inner['data'];
  if (inner is Map) return Map<String, dynamic>.from(inner);
  return root;
}

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _displayName = TextEditingController();
  final _bio = TextEditingController();
  final _avatarUrl = TextEditingController();
  final _city = TextEditingController();
  final _country = TextEditingController();
  final _websiteUrl = TextEditingController();

  final List<_LinkRow> _links = [];
  final List<_PublicationRow> _publications = [];

  bool _seeded = false;
  bool _saving = false;
  bool _uploading = false;

  // Cache-bust nonce for avatar preview. Bumped after upload/save.
  int _avatarBust = 0;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _displayName.dispose();
    _bio.dispose();
    _avatarUrl.dispose();
    _city.dispose();
    _country.dispose();
    _websiteUrl.dispose();

    for (final r in _links) {
      r.dispose();
    }
    for (final r in _publications) {
      r.dispose();
    }

    super.dispose();
  }

  String _str(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v is String) return v;
    return '';
  }

  String? _nullableStr(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v is String) return v;
    return null;
  }

  List<dynamic> _list(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v is List) return v;
    return const <dynamic>[];
  }

  void _seed(Map<String, dynamic> me) {
    if (_seeded) return;
    _seeded = true;

    _firstName.text = (_nullableStr(me, 'firstName') ?? '').trim();
    _lastName.text = (_nullableStr(me, 'lastName') ?? '').trim();

    _displayName.text = _str(me, 'displayName').trim();
    _bio.text = (_nullableStr(me, 'bio') ?? '').trim();
    _avatarUrl.text = (_nullableStr(me, 'avatarUrl') ?? '').trim();
    _city.text = (_nullableStr(me, 'city') ?? '').trim();
    _country.text = (_nullableStr(me, 'country') ?? '').trim();
    _websiteUrl.text = (_nullableStr(me, 'websiteUrl') ?? '').trim();

    final links = _list(me, 'links');
    for (final raw in links) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final url = (m['url'] ?? '').toString().trim();
      if (url.isEmpty) continue;
      final label = (m['label'] ?? '').toString().trim();
      _links.add(_LinkRow(label: label, url: url));
    }

    final pubs = _list(me, 'publications');
    for (final raw in pubs) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final title = (m['title'] ?? '').toString().trim();
      if (title.isEmpty) continue;

      final url = (m['url'] ?? '').toString().trim();
      final publisher = (m['publisher'] ?? '').toString().trim();
      final year = (m['year'] ?? '').toString().trim();

      _publications.add(
        _PublicationRow(
          title: title,
          url: url,
          publisher: publisher,
          year: year,
        ),
      );
    }

    if (_links.isEmpty) _links.add(_LinkRow());
    if (_publications.isEmpty) _publications.add(_PublicationRow());
  }

  bool _isHttpUrl(String s) {
    final t = s.trim();
    if (t.isEmpty) return false;
    return t.startsWith('http://') || t.startsWith('https://');
  }

  void _touchAvatarBust() {
    if (!mounted) return;
    setState(() => _avatarBust++);
  }

  Future<void> _uploadAvatar() async {
    if (_uploading) return;

    setState(() => _uploading = true);

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
      if (picked == null) return;

      final Uint8List bytes = await picked.readAsBytes();
      final dio = ref.read(dioProvider);

      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: picked.name.isNotEmpty ? picked.name : 'avatar.jpg',
        ),
      });

      final res = await dio.post('/uploads/avatar', data: form);
      final m = _unwrap(res.data);
      String? url = (m['url'] ?? m['avatarUrl'] ?? m['path'])?.toString();

      if (url == null || url.trim().isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload completed but no URL returned.')),
        );
        return;
      }

      _avatarUrl.text = url.trim();
      _touchAvatarBust();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar uploaded. Tap Save to apply.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Avatar upload failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  List<Map<String, dynamic>> _buildLinksPayload() {
    final out = <Map<String, dynamic>>[];
    for (final r in _links) {
      final url = r.url.text.trim();
      if (url.isEmpty) continue;

      final label = r.label.text.trim();
      out.add({
        'label': label.isEmpty ? null : label,
        'url': url,
      });
    }
    return out;
  }

  List<Map<String, dynamic>> _buildPublicationsPayload() {
    final out = <Map<String, dynamic>>[];
    for (final r in _publications) {
      final title = r.title.text.trim();
      if (title.isEmpty) continue;

      final url = r.url.text.trim();
      final publisher = r.publisher.text.trim();
      final yearStr = r.year.text.trim();

      int? year;
      if (yearStr.isNotEmpty) {
        final n = int.tryParse(yearStr);
        if (n != null && n > 0) year = n;
      }

      out.add({
        'title': title,
        'url': url.isEmpty ? null : url,
        'publisher': publisher.isEmpty ? null : publisher,
        'year': year,
      });
    }
    return out;
  }

  String _absoluteFromMaybeRelative(String raw, Dio dio) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    if (t.startsWith('http://') || t.startsWith('https://')) return t;

    final base = dio.options.baseUrl.trim();
    if (base.isEmpty) return t;

    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final p = t.startsWith('/') ? t : '/$t';
    return '$b$p';
  }

  Future<void> _save() async {
    if (_saving) return;

    final dn = _displayName.text.trim();
    final fn = _firstName.text.trim();
    final ln = _lastName.text.trim();

    if (dn.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Display name is required.')),
      );
      return;
    }

    final web = _websiteUrl.text.trim();
    if (web.isNotEmpty && !_isHttpUrl(web)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Website must start with http:// or https://')),
      );
      return;
    }

    for (final r in _links) {
      final url = r.url.text.trim();
      if (url.isNotEmpty && !_isHttpUrl(url)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All links must start with http:// or https://')),
        );
        return;
      }
    }

    for (final r in _publications) {
      final url = r.url.text.trim();
      if (url.isNotEmpty && !_isHttpUrl(url)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Publication URLs must start with http:// or https://')),
        );
        return;
      }
    }

    setState(() => _saving = true);

    try {
      final dio = ref.read(dioProvider);

      // CLEAR-TO-NULL behavior
      final bb = _bio.text.trim();
      final av = _avatarUrl.text.trim();
      final city = _city.text.trim();
      final country = _country.text.trim();

      final links = _buildLinksPayload();
      final pubs = _buildPublicationsPayload();

      final res = await dio.patch(
        '/users/me',
        data: {
          'displayName': dn,
          'firstName': fn.isEmpty ? null : fn,
          'lastName': ln.isEmpty ? null : ln,
          'bio': bb.isEmpty ? null : bb,
          'avatarUrl': av.isEmpty ? null : av,
          'city': city.isEmpty ? null : city,
          'country': country.isEmpty ? null : country,
          'websiteUrl': web.isEmpty ? null : web,
          'links': links,
          'publications': pubs,
        },
      );

      ref.invalidate(meProfileRawProvider);
      _touchAvatarBust();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
      Navigator.of(context).pop(res.data);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addLink() {
    setState(() => _links.add(_LinkRow()));
  }

  void _removeLink(int i) {
    if (i < 0 || i >= _links.length) return;
    setState(() {
      _links[i].dispose();
      _links.removeAt(i);
      if (_links.isEmpty) _links.add(_LinkRow());
    });
  }

  void _addPublication() {
    setState(() => _publications.add(_PublicationRow()));
  }

  void _removePublication(int i) {
    if (i < 0 || i >= _publications.length) return;
    setState(() {
      _publications[i].dispose();
      _publications.removeAt(i);
      if (_publications.isEmpty) _publications.add(_PublicationRow());
    });
  }

  @override
  Widget build(BuildContext context) {
    final meAsync = ref.watch(meProfileRawProvider);

    return AuraScaffold(
      title: 'Edit profile',
      child: meAsync.when(
        data: (raw) {
          final me = _unwrap(raw);
          _seed(me);

          final dio = ref.read(dioProvider);
          final avatarRaw = _absoluteFromMaybeRelative(_avatarUrl.text, dio);
          final avatar = avatarRaw.isNotEmpty
              ? (avatarRaw.contains('?') ? '$avatarRaw&v=$_avatarBust' : '$avatarRaw?v=$_avatarBust')
              : '';

          return ListView(
            padding: const EdgeInsets.all(AuraSpace.s16),
            children: [
              AuraCard(
                child: Padding(
                  padding: const EdgeInsets.all(AuraSpace.s16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                        child: avatar.isEmpty ? const Icon(Icons.person, size: 34) : null,
                      ),
                      const SizedBox(width: AuraSpace.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Avatar', style: AuraText.title),
                            const SizedBox(height: AuraSpace.s10),
                            Wrap(
                              spacing: AuraSpace.s10,
                              runSpacing: AuraSpace.s10,
                              children: [
                                FilledButton(
                                  onPressed: _uploading ? null : _uploadAvatar,
                                  child: Text(_uploading ? 'Uploading…' : 'Upload avatar'),
                                ),
                                OutlinedButton(
                                  onPressed: _touchAvatarBust,
                                  child: const Text('Refresh preview'),
                                ),
                              ],
                            ),
                            const SizedBox(height: AuraSpace.s12),
                            Text('Avatar URL', style: AuraText.body),
                            const SizedBox(height: AuraSpace.s8),
                            TextField(
                              controller: _avatarUrl,
                              decoration: const InputDecoration(
                                hintText: 'https://…',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) => _touchAvatarBust(),
                            ),
                            const SizedBox(height: AuraSpace.s8),
                            Text(
                              'Upload is preferred. URL is available for debugging or advanced use.',
                              style: AuraText.small,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AuraSpace.s14),

              // Identity
              AuraCard(
                child: Padding(
                  padding: const EdgeInsets.all(AuraSpace.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Identity', style: AuraText.title),
                      const SizedBox(height: AuraSpace.s10),

                      Text('First name (private)', style: AuraText.body),
                      const SizedBox(height: AuraSpace.s8),
                      TextField(
                        controller: _firstName,
                        decoration: const InputDecoration(
                          hintText: 'Muhammad',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: AuraSpace.s12),

                      Text('Last name (private)', style: AuraText.body),
                      const SizedBox(height: AuraSpace.s8),
                      TextField(
                        controller: _lastName,
                        decoration: const InputDecoration(
                          hintText: 'Sakhawat',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: AuraSpace.s14),

                      Text('Display name', style: AuraText.body),
                      const SizedBox(height: AuraSpace.s8),
                      TextField(
                        controller: _displayName,
                        decoration: const InputDecoration(
                          hintText: 'Your name',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: AuraSpace.s14),
                      Text('Website', style: AuraText.body),
                      const SizedBox(height: AuraSpace.s8),
                      TextField(
                        controller: _websiteUrl,
                        decoration: const InputDecoration(
                          hintText: 'https://…',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: AuraSpace.s14),
                      Text('Bio', style: AuraText.body),
                      const SizedBox(height: AuraSpace.s8),
                      TextField(
                        controller: _bio,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          hintText: 'A short note about you (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AuraSpace.s14),

              // Location
              AuraCard(
                child: Padding(
                  padding: const EdgeInsets.all(AuraSpace.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Location', style: AuraText.title),
                      const SizedBox(height: AuraSpace.s10),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('City', style: AuraText.body),
                                const SizedBox(height: AuraSpace.s8),
                                TextField(
                                  controller: _city,
                                  decoration: const InputDecoration(
                                    hintText: 'Canton',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AuraSpace.s12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Country', style: AuraText.body),
                                const SizedBox(height: AuraSpace.s8),
                                TextField(
                                  controller: _country,
                                  decoration: const InputDecoration(
                                    hintText: 'USA',
                                    border: OutlineInputBorder(),
                                  ),
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

              const SizedBox(height: AuraSpace.s14),

              // Links
              AuraCard(
                child: Padding(
                  padding: const EdgeInsets.all(AuraSpace.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Links', style: AuraText.title),
                      const SizedBox(height: AuraSpace.s10),
                      for (int i = 0; i < _links.length; i++) ...[
                        _links[i].build(
                          context: context,
                          index: i,
                          onRemove: () => _removeLink(i),
                        ),
                        const SizedBox(height: AuraSpace.s12),
                      ],
                      OutlinedButton(onPressed: _addLink, child: const Text('Add link')),
                      const SizedBox(height: AuraSpace.s8),
                      Text('Examples: personal site, author page, organization profile.', style: AuraText.small),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AuraSpace.s14),

              // Publications
              AuraCard(
                child: Padding(
                  padding: const EdgeInsets.all(AuraSpace.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Publications', style: AuraText.title),
                      const SizedBox(height: AuraSpace.s10),
                      for (int i = 0; i < _publications.length; i++) ...[
                        _publications[i].build(
                          context: context,
                          index: i,
                          onRemove: () => _removePublication(i),
                        ),
                        const SizedBox(height: AuraSpace.s12),
                      ],
                      OutlinedButton(onPressed: _addPublication, child: const Text('Add publication')),
                      const SizedBox(height: AuraSpace.s8),
                      Text('Add books, essays, or notable work. Keep it minimal and factual.', style: AuraText.small),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AuraSpace.s14),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AuraSpace.s12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Saving…' : 'Save'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(
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
                      onPressed: () => ref.invalidate(meProfileRawProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LinkRow {
  final label = TextEditingController();
  final url = TextEditingController();

  _LinkRow({String label = '', String url = ''}) {
    this.label.text = label;
    this.url.text = url;
  }

  void dispose() {
    label.dispose();
    url.dispose();
  }

  Widget build({
    required BuildContext context,
    required int index,
    required VoidCallback onRemove,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Link ${index + 1}', style: AuraText.body),
        const SizedBox(height: AuraSpace.s8),
        Row(
          children: [
            Expanded(
              flex: 4,
              child: TextField(
                controller: label,
                decoration: const InputDecoration(
                  hintText: 'Label (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: AuraSpace.s10),
            Expanded(
              flex: 6,
              child: TextField(
                controller: url,
                decoration: const InputDecoration(
                  hintText: 'https://…',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: AuraSpace.s10),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close),
              tooltip: 'Remove',
            ),
          ],
        ),
      ],
    );
  }
}

class _PublicationRow {
  final title = TextEditingController();
  final url = TextEditingController();
  final publisher = TextEditingController();
  final year = TextEditingController();

  _PublicationRow({
    String title = '',
    String url = '',
    String publisher = '',
    String year = '',
  }) {
    this.title.text = title;
    this.url.text = url;
    this.publisher.text = publisher;
    this.year.text = year;
  }

  void dispose() {
    title.dispose();
    url.dispose();
    publisher.dispose();
    year.dispose();
  }

  Widget build({
    required BuildContext context,
    required int index,
    required VoidCallback onRemove,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Publication ${index + 1}', style: AuraText.body),
        const SizedBox(height: AuraSpace.s8),
        TextField(
          controller: title,
          decoration: const InputDecoration(
            hintText: 'Title',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AuraSpace.s10),
        Row(
          children: [
            Expanded(
              flex: 6,
              child: TextField(
                controller: url,
                decoration: const InputDecoration(
                  hintText: 'URL (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: AuraSpace.s10),
            Expanded(
              flex: 4,
              child: TextField(
                controller: publisher,
                decoration: const InputDecoration(
                  hintText: 'Publisher (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: AuraSpace.s10),
            SizedBox(
              width: 110,
              child: TextField(
                controller: year,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Year',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: AuraSpace.s10),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close),
              tooltip: 'Remove',
            ),
          ],
        ),
      ],
    );
  }
}