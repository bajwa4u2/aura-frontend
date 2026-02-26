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
  throw Exception('Unexpected /users/me response');
});

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _displayName = TextEditingController();
  final _bio = TextEditingController();
  final _avatarUrl = TextEditingController();
  final _city = TextEditingController();
  final _country = TextEditingController();
  final _websiteUrl = TextEditingController();

  final List<_LinkRow> _links = [];
  final List<_PublicationRow> _publications = [];

  bool _saving = false;
  bool _uploading = false;
  bool _seeded = false;

  // Cache-bust nonce for avatar preview. Bumped after upload/save.
  int _avatarBust = 0;

  @override
  void dispose() {
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
    if (v == null) return null;
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
      final year = m['year'];
      final yearStr = year == null ? '' : year.toString();
      _publications.add(
        _PublicationRow(
          title: title,
          url: url,
          publisher: publisher,
          year: yearStr,
        ),
      );
    }

    // Always show at least one empty row for UX.
    if (_links.isEmpty) _links.add(_LinkRow());
    if (_publications.isEmpty) _publications.add(_PublicationRow());
  }

  String _absoluteFromMaybeRelative(String url, Dio dio) {
    final u = url.trim();
    if (u.isEmpty) return u;
    if (u.startsWith('http://') || u.startsWith('https://')) return u;

    final base = dio.options.baseUrl.trim();
    if (base.isEmpty) return u;
    if (u.startsWith('/')) return '$base$u';
    return '$base/$u';
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
      final data = res.data;

      String? url;
      if (data is Map) {
        final m = Map<String, dynamic>.from(data);
        url = (m['url'] ?? m['avatarUrl'] ?? m['path'])?.toString();
      }

      if (url == null || url.trim().isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload succeeded but no URL returned.')),
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
      final label = r.label.text.trim();
      if (url.isEmpty) continue;
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

  Future<void> _save() async {
    if (_saving) return;

    final dn = _displayName.text.trim();
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
        SnackBar(content: Text('Could not save: $e')),
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
      final row = _links.removeAt(i);
      row.dispose();
      if (_links.isEmpty) _links.add(_LinkRow());
    });
  }

  void _addPublication() {
    setState(() => _publications.add(_PublicationRow()));
  }

  void _removePublication(int i) {
    if (i < 0 || i >= _publications.length) return;
    setState(() {
      final row = _publications.removeAt(i);
      row.dispose();
      if (_publications.isEmpty) _publications.add(_PublicationRow());
    });
  }

  @override
  Widget build(BuildContext context) {
    final dio = ref.watch(dioProvider);

    return AuraScaffold(
      title: 'Edit Profile',
      actions: [
        TextButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
      body: Consumer(
        builder: (context, ref, _) {
          final meAsync = ref.watch(meProfileRawProvider);

          return meAsync.when(
            data: (me) {
              _seed(me);

              final handle = _str(me, 'handle');
              final avatarRaw = _absoluteFromMaybeRelative(_avatarUrl.text, dio);
              final avatar = avatarRaw.isNotEmpty
                  ? (avatarRaw.contains('?') ? '${avatarRaw}&v=$_avatarBust' : '${avatarRaw}?v=$_avatarBust')
                  : '';

              return ListView(
                padding: const EdgeInsets.all(AuraSpace.s16),
                children: [
                  AuraCard(
                    child: Padding(
                      padding: const EdgeInsets.all(AuraSpace.s16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 34,
                                backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                                child: avatar.isEmpty ? const Icon(Icons.person, size: 34) : null,
                              ),
                              const SizedBox(width: AuraSpace.s16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _displayName.text.trim().isEmpty ? 'Member' : _displayName.text.trim(),
                                      style: AuraText.title,
                                    ),
                                    const SizedBox(height: AuraSpace.s6),
                                    Text(handle.isEmpty ? '' : '@$handle', style: AuraText.muted),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AuraSpace.s14),
                          Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed: _uploading ? null : _uploadAvatar,
                                icon: _uploading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.image_outlined),
                                label: Text(_uploading ? 'Uploading…' : 'Upload avatar'),
                              ),
                              const SizedBox(width: AuraSpace.s12),
                              Expanded(
                                child: Text(
                                  'Upload updates the URL field. Tap Save to apply.',
                                  style: AuraText.small,
                                ),
                              ),
                            ],
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
                              hintText: 'https://your-site.com',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AuraSpace.s14),

                  // About
                  AuraCard(
                    child: Padding(
                      padding: const EdgeInsets.all(AuraSpace.s16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('About', style: AuraText.title),
                          const SizedBox(height: AuraSpace.s10),
                          Text('Bio', style: AuraText.body),
                          const SizedBox(height: AuraSpace.s8),
                          TextField(
                            controller: _bio,
                            maxLines: 5,
                            decoration: const InputDecoration(
                              hintText: 'A few lines about you',
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
                          const SizedBox(height: AuraSpace.s10),
                          Text(
                            'These are optional. If you prefer privacy, leave them blank.',
                            style: AuraText.small,
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
                          Row(
                            children: [
                              Expanded(child: Text('Links', style: AuraText.title)),
                              TextButton.icon(
                                onPressed: _addLink,
                                icon: const Icon(Icons.add),
                                label: const Text('Add'),
                              ),
                            ],
                          ),
                          const SizedBox(height: AuraSpace.s6),
                          Text('Add your key links (site, newsletter, socials).', style: AuraText.small),
                          const SizedBox(height: AuraSpace.s10),
                          for (int i = 0; i < _links.length; i++) ...[
                            _LinkEditorRow(
                              row: _links[i],
                              onRemove: _links.length <= 1 ? null : () => _removeLink(i),
                            ),
                            const SizedBox(height: AuraSpace.s10),
                          ],
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
                          Row(
                            children: [
                              Expanded(child: Text('Publications', style: AuraText.title)),
                              TextButton.icon(
                                onPressed: _addPublication,
                                icon: const Icon(Icons.add),
                                label: const Text('Add'),
                              ),
                            ],
                          ),
                          const SizedBox(height: AuraSpace.s6),
                          Text('Articles, papers, books, interviews, or notable links.', style: AuraText.small),
                          const SizedBox(height: AuraSpace.s10),
                          for (int i = 0; i < _publications.length; i++) ...[
                            _PublicationEditorRow(
                              row: _publications[i],
                              onRemove: _publications.length <= 1 ? null : () => _removePublication(i),
                            ),
                            const SizedBox(height: AuraSpace.s12),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AuraSpace.s14),

                  // Advanced
                  AuraCard(
                    child: Padding(
                      padding: const EdgeInsets.all(AuraSpace.s16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Advanced', style: AuraText.title),
                          const SizedBox(height: AuraSpace.s10),
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
                          const SizedBox(height: AuraSpace.s12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton(
                              onPressed: _saving ? null : _save,
                              child: Text(_saving ? 'Saving…' : 'Save'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AuraSpace.s16),
                ],
              );
            },
            loading: () => const _LoadingBlock(),
            error: (e, _) => _ErrorBlock(message: e.toString()),
          );
        },
      ),
    );
  }
}

class _LinkRow {
  _LinkRow({String label = '', String url = ''})
      : label = TextEditingController(text: label),
        url = TextEditingController(text: url);

  final TextEditingController label;
  final TextEditingController url;

  void dispose() {
    label.dispose();
    url.dispose();
  }
}

class _PublicationRow {
  _PublicationRow({String title = '', String url = '', String publisher = '', String year = ''})
      : title = TextEditingController(text: title),
        url = TextEditingController(text: url),
        publisher = TextEditingController(text: publisher),
        year = TextEditingController(text: year);

  final TextEditingController title;
  final TextEditingController url;
  final TextEditingController publisher;
  final TextEditingController year;

  void dispose() {
    title.dispose();
    url.dispose();
    publisher.dispose();
    year.dispose();
  }
}

class _LinkEditorRow extends StatelessWidget {
  const _LinkEditorRow({required this.row, this.onRemove});

  final _LinkRow row;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: row.label,
                decoration: const InputDecoration(
                  hintText: 'Label (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: AuraSpace.s10),
            if (onRemove != null)
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close),
                tooltip: 'Remove link',
              ),
          ],
        ),
        const SizedBox(height: AuraSpace.s8),
        TextField(
          controller: row.url,
          decoration: const InputDecoration(
            hintText: 'https://…',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}

class _PublicationEditorRow extends StatelessWidget {
  const _PublicationEditorRow({required this.row, this.onRemove});

  final _PublicationRow row;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: row.title,
                    decoration: const InputDecoration(
                      hintText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AuraSpace.s8),
                  TextField(
                    controller: row.url,
                    decoration: const InputDecoration(
                      hintText: 'URL (optional) https://…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AuraSpace.s10),
            if (onRemove != null)
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close),
                tooltip: 'Remove publication',
              ),
          ],
        ),
        const SizedBox(height: AuraSpace.s8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: row.publisher,
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
                controller: row.year,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Year',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AuraSpace.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: AuraSpace.s12),
            Text('Loading…', style: AuraText.muted),
          ],
        ),
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