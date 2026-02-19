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
import '../../profile/domain/profile.dart';
import '../../profile/providers.dart';

final meProfileProvider = FutureProvider.autoDispose<Profile>((ref) async {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.fetchMe();
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

  bool _saving = false;
  bool _uploading = false;
  bool _seeded = false;

  @override
  void dispose() {
    _displayName.dispose();
    _bio.dispose();
    _avatarUrl.dispose();
    super.dispose();
  }

  void _seed(Profile p) {
    if (_seeded) return;
    _seeded = true;
    _displayName.text = p.displayName;
    _bio.text = p.bio;
    _avatarUrl.text = (p.avatarUrl ?? '');
  }

  String _absoluteFromMaybeRelative(String url, Dio dio) {
    final u = url.trim();
    if (u.isEmpty) return u;
    if (u.startsWith('http://') || u.startsWith('https://')) return u;

    // Dio baseUrl includes /v1
    final root = dio.options.baseUrl.replaceAll(RegExp(r'/v1/?$'), '');
    if (u.startsWith('/')) return '$root$u';
    return '$root/$u';
  }

  Future<void> _uploadAvatar() async {
    if (_uploading) return;

    setState(() => _uploading = true);

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
      if (picked == null) return;

      Uint8List bytes = await picked.readAsBytes();
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
        final m = Map<String, dynamic>.from(data as Map);
        url = (m['url'] ?? m['avatarUrl'] ?? m['path'])?.toString();
      }

      if (url == null || url.trim().isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload succeeded but no URL returned.')));
        return;
      }

      // Put the URL in the field; actual saving happens with Save button.
      _avatarUrl.text = url.trim();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Avatar uploaded. Tap Save to apply.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Avatar upload failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final dio = ref.read(dioProvider);

      // CLEAR-TO-NULL behavior consistent with Me screen:
      final dn = _displayName.text.trim();
      final bb = _bio.text.trim();
      final av = _avatarUrl.text.trim();

      final res = await dio.patch(
        '/users/me',
        data: {
          'displayName': dn.isEmpty ? null : dn,
          'bio': bb.isEmpty ? null : bb,
          'avatarUrl': av.isEmpty ? null : av,
        },
      );

      // Refresh local providers
      ref.invalidate(meProfileProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
      Navigator.of(context).pop(res.data);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncMe = ref.watch(meProfileProvider);
    final dio = ref.read(dioProvider);

    return AuraScaffold(
      title: 'Edit profile',
      showHomeAction: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AuraSpace.s16, AuraSpace.s12, AuraSpace.s16, AuraSpace.s24),
        children: [
          asyncMe.when(
            loading: () => const AuraCard(child: _LoadingBlock()),
            error: (e, _) => AuraCard(child: _ErrorBlock(message: '$e')),
            data: (p) {
              _seed(p);

              final avatar = _absoluteFromMaybeRelative(_avatarUrl.text, dio);

              return AuraCard(
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
                              Text(p.displayName, style: AuraText.title),
                              const SizedBox(height: AuraSpace.s6),
                              Text('@${p.handle}', style: AuraText.muted),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AuraSpace.s12),
                    Wrap(
                      spacing: AuraSpace.s10,
                      runSpacing: AuraSpace.s10,
                      children: [
                        OutlinedButton(
                          onPressed: _uploading ? null : _uploadAvatar,
                          child: Text(_uploading ? 'Uploading…' : 'Upload avatar'),
                        ),
                        OutlinedButton(
                          onPressed: () {
                            _avatarUrl.clear();
                            setState(() {});
                          },
                          child: const Text('Clear avatar'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: AuraSpace.s16),
          AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Public profile', style: AuraText.title),
                const SizedBox(height: AuraSpace.s12),
                TextField(
                  controller: _displayName,
                  decoration: const InputDecoration(
                    labelText: 'Display name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AuraSpace.s12),
                TextField(
                  controller: _bio,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Bio',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AuraSpace.s12),
                TextField(
                  controller: _avatarUrl,
                  decoration: const InputDecoration(
                    labelText: 'Avatar URL (optional)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AuraSpace.s16),
                Wrap(
                  spacing: AuraSpace.s10,
                  runSpacing: AuraSpace.s10,
                  children: [
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Saving…' : 'Save'),
                    ),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AuraSpace.s16),
      child: Row(
        children: [
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: AuraSpace.s12),
          Text('Loading…', style: AuraText.muted),
        ],
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
