import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aura/core/net/dio_provider.dart';
import 'package:aura/core/ui/aura_card.dart';
import 'package:aura/core/ui/aura_scaffold.dart';
import 'package:aura/core/ui/aura_space.dart';
import 'package:aura/core/ui/aura_text.dart';

final meProfileRawProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/users/me');
  final raw = res.data;

  if (raw is Map<String, dynamic>) {
    if (raw['ok'] == true && raw['data'] is Map) {
      return Map<String, dynamic>.from(raw['data'] as Map);
    }
    return raw;
  }

  if (raw is Map) {
    return Map<String, dynamic>.from(raw);
  }

  throw Exception('Unexpected response');
});

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _displayNameCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _avatarUrlCtrl = TextEditingController();

  final List<TextEditingController> _links = [];
  final List<TextEditingController> _pubTitles = [];
  final List<TextEditingController> _pubUrls = [];

  bool _saving = false;
  bool _loaded = false;
  String? _saveError;

  @override
  void dispose() {
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
    final profile = me['profile'] is Map
        ? Map<String, dynamic>.from(me['profile'] as Map)
        : <String, dynamic>{};

    _displayNameCtrl.text = (profile['displayName'] ?? '').toString();
    _websiteCtrl.text = (profile['websiteUrl'] ?? profile['website'] ?? '')
        .toString();
    _bioCtrl.text = (profile['bio'] ?? '').toString();
    _cityCtrl.text = (profile['city'] ?? '').toString();
    _countryCtrl.text = (profile['country'] ?? '').toString();
    _avatarUrlCtrl.text = (profile['avatarUrl'] ?? '').toString();

    _links.clear();
    final links = profile['links'];
    if (links is List) {
      for (final v in links) {
        if (v is Map) {
          final url = (v['url'] ?? '').toString().trim();
          if (url.isNotEmpty) {
            _links.add(TextEditingController(text: url));
          }
        } else {
          final value = (v ?? '').toString().trim();
          if (value.isNotEmpty) {
            _links.add(TextEditingController(text: value));
          }
        }
      }
    }
    if (_links.isEmpty) {
      _links.add(TextEditingController());
    }

    _pubTitles.clear();
    _pubUrls.clear();
    final pubs = profile['publications'];
    if (pubs is List) {
      for (final v in pubs) {
        if (v is Map) {
          _pubTitles.add(
            TextEditingController(text: (v['title'] ?? '').toString()),
          );
          _pubUrls.add(
            TextEditingController(text: (v['url'] ?? '').toString()),
          );
        }
      }
    }
    if (_pubTitles.isEmpty) {
      _pubTitles.add(TextEditingController());
      _pubUrls.add(TextEditingController());
    }

    _loaded = true;
  }

  List<Map<String, dynamic>> _cleanLinks() {
    final out = <Map<String, dynamic>>[];
    for (final c in _links) {
      final url = c.text.trim();
      if (url.isEmpty) continue;
      out.add({'url': url});
    }
    return out;
  }

  List<Map<String, dynamic>> _cleanPublications() {
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < _pubTitles.length; i++) {
      final title = _pubTitles[i].text.trim();
      final url = _pubUrls[i].text.trim();
      if (title.isEmpty && url.isEmpty) continue;
      out.add({
        'title': title,
        if (url.isNotEmpty) 'url': url,
      });
    }
    return out;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      final dio = ref.read(dioProvider);

      final body = <String, dynamic>{
        'displayName': _displayNameCtrl.text.trim(),
        'websiteUrl': _websiteCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'country': _countryCtrl.text.trim(),
        'avatarUrl': _avatarUrlCtrl.text.trim(),
        'links': _cleanLinks(),
        'publications': _cleanPublications(),
      };

      final res = await dio.patch('/users/me', data: body);
      final raw = res.data;

      if (raw is Map && raw['ok'] == false) {
        final msg = (raw['error']?['message'] ?? 'Save failed').toString();
        throw Exception(msg);
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _saveError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
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
        error: (err, _) => Padding(
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
          if (!_loaded) {
            _loadFromProfile(me);
          }

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

                AuraCard(
                  padding: const EdgeInsets.all(AuraSpace.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('Identity'),
                      const SizedBox(height: AuraSpace.s12),
                      TextField(
                        controller: _displayNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Display name',
                        ),
                      ),
                      const SizedBox(height: AuraSpace.s8),
                      TextField(
                        controller: _websiteCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Website',
                        ),
                      ),
                      const SizedBox(height: AuraSpace.s8),
                      TextField(
                        controller: _bioCtrl,
                        minLines: 3,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          labelText: 'Bio',
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AuraSpace.s14),

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
                              decoration: const InputDecoration(
                                labelText: 'City',
                              ),
                            ),
                          ),
                          const SizedBox(width: AuraSpace.s12),
                          Expanded(
                            child: TextField(
                              controller: _countryCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Country',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AuraSpace.s14),

                AuraCard(
                  padding: const EdgeInsets.all(AuraSpace.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('Avatar'),
                      const SizedBox(height: AuraSpace.s12),
                      TextField(
                        controller: _avatarUrlCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Avatar URL',
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AuraSpace.s14),

                AuraCard(
                  padding: const EdgeInsets.all(AuraSpace.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('Links'),
                      const SizedBox(height: AuraSpace.s12),
                      for (var i = 0; i < _links.length; i++)
                        _LinkRow(
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
                            setState(() {
                              _links.add(TextEditingController());
                            });
                          },
                          child: const Text('Add link'),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AuraSpace.s14),

                AuraCard(
                  padding: const EdgeInsets.all(AuraSpace.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('Publications'),
                      const SizedBox(height: AuraSpace.s12),
                      for (var i = 0; i < _pubTitles.length; i++)
                        _PublicationRow(
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

                AuraCard(
                  padding: const EdgeInsets.all(AuraSpace.s16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          child: Text(_saving ? 'Saving…' : 'Save changes'),
                        ),
                      ),
                      const SizedBox(width: AuraSpace.s12),
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(false),
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