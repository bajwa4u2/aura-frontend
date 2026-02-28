import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aura/core/net/dio_provider.dart';
import 'package:aura/core/ui/aura_card.dart';
import 'package:aura/core/ui/aura_scaffold.dart';
import 'package:aura/core/ui/aura_space.dart';
import 'package:aura/core/ui/aura_text.dart';

final meProfileRawProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/users/me');
  final raw = res.data;
  if (raw is! Map) throw Exception('Unexpected response');
  final ok = raw['ok'] == true;
  if (!ok) throw Exception((raw['error']?['message'] ?? 'Request failed').toString());
  final data = raw['data'];
  if (data is! Map) throw Exception('Unexpected response: ok=true but data is not a map');
  return Map<String, dynamic>.from(data as Map);
});

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  // Identity
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  // Location
  final _cityCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();

  // Avatar
  final _avatarUrlCtrl = TextEditingController();

  // Links + publications as JSON-ish
  final List<TextEditingController> _links = [];
  final List<TextEditingController> _pubTitles = [];
  final List<TextEditingController> _pubUrls = [];

  bool _saving = false;
  String? _saveError;
  bool _loaded = false;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _displayNameCtrl.dispose();
    _websiteCtrl.dispose();
    _bioCtrl.dispose();
    _cityCtrl.dispose();
    _countryCtrl.dispose();
    _avatarUrlCtrl.dispose();
    for (final c in _links) {
      c.dispose();
    }
    for (final c in _pubTitles) {
      c.dispose();
    }
    for (final c in _pubUrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _loadFromProfile(Map<String, dynamic> me) {
    final profile = (me['profile'] is Map) ? Map<String, dynamic>.from(me['profile'] as Map) : <String, dynamic>{};
    _firstNameCtrl.text = (profile['firstName'] ?? '').toString();
    _lastNameCtrl.text = (profile['lastName'] ?? '').toString();
    _displayNameCtrl.text = (profile['displayName'] ?? '').toString();
    _websiteCtrl.text = (profile['website'] ?? '').toString();
    _bioCtrl.text = (profile['bio'] ?? '').toString();

    _cityCtrl.text = (profile['city'] ?? '').toString();
    _countryCtrl.text = (profile['country'] ?? '').toString();

    _avatarUrlCtrl.text = (profile['avatarUrl'] ?? '').toString();

    // Links
    _links.clear();
    final links = profile['links'];
    if (links is List) {
      for (final v in links) {
        final c = TextEditingController(text: (v ?? '').toString());
        _links.add(c);
      }
    }
    if (_links.isEmpty) _links.add(TextEditingController());

    // Publications
    _pubTitles.clear();
    _pubUrls.clear();
    final pubs = profile['publications'];
    if (pubs is List) {
      for (final v in pubs) {
        if (v is Map) {
          _pubTitles.add(TextEditingController(text: (v['title'] ?? '').toString()));
          _pubUrls.add(TextEditingController(text: (v['url'] ?? '').toString()));
        }
      }
    }
    if (_pubTitles.isEmpty) {
      _pubTitles.add(TextEditingController());
      _pubUrls.add(TextEditingController());
    }

    _loaded = true;
  }

  List<String> _cleanStringList(List<TextEditingController> ctrls) {
    final out = <String>[];
    for (final c in ctrls) {
      final v = c.text.trim();
      if (v.isNotEmpty) out.add(v);
    }
    return out;
  }

  List<Map<String, dynamic>> _cleanPublications() {
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < _pubTitles.length; i++) {
      final t = _pubTitles[i].text.trim();
      final u = _pubUrls[i].text.trim();
      if (t.isEmpty && u.isEmpty) continue;
      out.add({'title': t, 'url': u});
    }
    return out;
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      final dio = ref.read(dioProvider);

      final body = <String, dynamic>{
        'profile': {
          'firstName': _firstNameCtrl.text.trim(),
          'lastName': _lastNameCtrl.text.trim(),
          'displayName': _displayNameCtrl.text.trim(),
          'website': _websiteCtrl.text.trim(),
          'bio': _bioCtrl.text.trim(),
          'city': _cityCtrl.text.trim(),
          'country': _countryCtrl.text.trim(),
          'avatarUrl': _avatarUrlCtrl.text.trim(),
          'links': _cleanStringList(_links),
          'publications': _cleanPublications(),
        }
      };

      final res = await dio.put('/users/me', data: body);
      final raw = res.data;
      if (raw is! Map) throw Exception('Unexpected response');
      if (raw['ok'] != true) {
        final msg = (raw['error']?['message'] ?? 'Save failed').toString();
        throw Exception(msg);
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _saveError = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _sectionTitle(String text) {
    return Text(text, style: AuraText.title);
  }

  @override
  Widget build(BuildContext context) {
    final meAsync = ref.watch(meProfileRawProvider);

    return AuraScaffold(
      title: 'Edit profile',
      child: meAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Padding(
          padding: const EdgeInsets.all(AuraSpace.s16),
          child: AuraCard(
            padding: const EdgeInsets.all(AuraSpace.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Could not load your profile.', style: AuraText.title),
                const SizedBox(height: AuraSpace.s10),
                Text('$err', style: AuraText.small),
              ],
            ),
          ),
        ),
        data: (me) {
          if (!_loaded) _loadFromProfile(me);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AuraSpace.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_saveError != null) ...[
                  AuraCard(
                    padding: const EdgeInsets.all(AuraSpace.s16),
                    child: Text(_saveError!, style: AuraText.small),
                  ),
                  const SizedBox(height: AuraSpace.s12),
                ],

                // Avatar
                AuraCard(
                  padding: const EdgeInsets.all(AuraSpace.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('Avatar'),
                      const SizedBox(height: AuraSpace.s12),
                      Wrap(
                        spacing: AuraSpace.s10,
                        runSpacing: AuraSpace.s10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: 340,
                            child: TextField(
                              controller: _avatarUrlCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Avatar URL',
                              ),
                            ),
                          ),
                          Text(
                            'Upload is preferred. URL is available for debugging or advanced use.',
                            style: AuraText.small,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AuraSpace.s14),

                // Identity
                AuraCard(
                  padding: const EdgeInsets.all(AuraSpace.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('Identity'),
                      const SizedBox(height: AuraSpace.s12),
                      TextField(
                        controller: _firstNameCtrl,
                        decoration: const InputDecoration(labelText: 'First name (private)'),
                      ),
                      const SizedBox(height: AuraSpace.s8),
                      TextField(
                        controller: _lastNameCtrl,
                        decoration: const InputDecoration(labelText: 'Last name (private)'),
                      ),
                      const SizedBox(height: AuraSpace.s12),
                      TextField(
                        controller: _displayNameCtrl,
                        decoration: const InputDecoration(labelText: 'Display name'),
                      ),
                      const SizedBox(height: AuraSpace.s8),
                      TextField(
                        controller: _websiteCtrl,
                        decoration: const InputDecoration(labelText: 'Website'),
                      ),
                      const SizedBox(height: AuraSpace.s8),
                      TextField(
                        controller: _bioCtrl,
                        minLines: 3,
                        maxLines: 8,
                        decoration: const InputDecoration(labelText: 'Bio'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AuraSpace.s14),

                // Location
                AuraCard(
                  padding: const EdgeInsets.all(AuraSpace.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('Location'),
                      const SizedBox(height: AuraSpace.s12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _cityCtrl,
                              decoration: const InputDecoration(labelText: 'City'),
                            ),
                          ),
                          const SizedBox(width: AuraSpace.s12),
                          Expanded(
                            child: TextField(
                              controller: _countryCtrl,
                              decoration: const InputDecoration(labelText: 'Country'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AuraSpace.s14),

                // Links
                AuraCard(
                  padding: const EdgeInsets.all(AuraSpace.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('Links'),
                      const SizedBox(height: AuraSpace.s10),
                      Text(
                        'Examples: personal site, author page, organization profile.',
                        style: AuraText.small,
                      ),
                      const SizedBox(height: AuraSpace.s12),
                      for (var i = 0; i < _links.length; i++) _LinkRow(
                        index: i,
                        controller: _links[i],
                        onRemove: _links.length <= 1
                            ? null
                            : () {
                                setState(() {
                                  final c = _links.removeAt(i);
                                  c.dispose();
                                });
                              },
                      ),
                      const SizedBox(height: AuraSpace.s10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() => _links.add(TextEditingController()));
                          },
                          child: const Text('Add link'),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AuraSpace.s14),

                // Publications
                AuraCard(
                  padding: const EdgeInsets.all(AuraSpace.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('Publications'),
                      const SizedBox(height: AuraSpace.s10),
                      Text(
                        'Add books, essays, or notable work. Keep it minimal and factual.',
                        style: AuraText.small,
                      ),
                      const SizedBox(height: AuraSpace.s12),
                      for (var i = 0; i < _pubTitles.length; i++) _PublicationRow(
                        index: i,
                        titleCtrl: _pubTitles[i],
                        urlCtrl: _pubUrls[i],
                        onRemove: _pubTitles.length <= 1
                            ? null
                            : () {
                                setState(() {
                                  final t = _pubTitles.removeAt(i);
                                  final u = _pubUrls.removeAt(i);
                                  t.dispose();
                                  u.dispose();
                                });
                              },
                      ),
                      const SizedBox(height: AuraSpace.s10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _pubTitles.add(TextEditingController());
                              _pubUrls.add(TextEditingController());
                            });
                          },
                          child: const Text('Add publication'),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AuraSpace.s14),

                // Save
                AuraCard(
                  padding: const EdgeInsets.all(AuraSpace.s16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          child: _saving ? const Text('Saving…') : const Text('Save changes'),
                        ),
                      ),
                      const SizedBox(width: AuraSpace.s12),
                      TextButton(
                        onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.index,
    required this.controller,
    required this.onRemove,
  });

  final int index;
  final TextEditingController controller;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(labelText: 'Link ${index + 1}'),
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
    );
  }
}

class _PublicationRow extends StatelessWidget {
  const _PublicationRow({
    required this.index,
    required this.titleCtrl,
    required this.urlCtrl,
    required this.onRemove,
  });

  final int index;
  final TextEditingController titleCtrl;
  final TextEditingController urlCtrl;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Publication ${index + 1}', style: AuraText.body),
          const SizedBox(height: AuraSpace.s8),
          TextField(
            controller: titleCtrl,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: AuraSpace.s8),
          TextField(
            controller: urlCtrl,
            decoration: const InputDecoration(labelText: 'URL'),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onRemove,
              child: const Text('Remove'),
            ),
          ),
        ],
      ),
    );
  }
}