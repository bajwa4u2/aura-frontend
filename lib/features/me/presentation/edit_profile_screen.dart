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

  // Cache-bust nonce for avatar preview. Bumped after upload/save.
  int _avatarBust = 0;

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

    // If API base is like https://api.xxx, we try to keep media relative handling sane.
    final base = dio.options.baseUrl.trim();
    if (base.isEmpty) return u;

    // If you store "/uploads/..." etc, join with API host.
    if (u.startsWith('/')) return '$base$u';
    return '$base/$u';
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

      // Put the URL in the field; actual saving happens with Save button.
      _avatarUrl.text = url.trim();

      // Force UI to rebuild so the CircleAvatar preview updates immediately.
      if (mounted) {
        setState(() => _avatarBust++);
      }

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

      // Also bump bust so preview doesn’t stick if URL is unchanged/cached.
      if (mounted) {
        setState(() => _avatarBust++);
      }

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
          final meAsync = ref.watch(meProfileProvider);

          return meAsync.when(
            data: (p) {
              _seed(p);

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
                                    Text(p.displayName, style: AuraText.title),
                                    const SizedBox(height: AuraSpace.s6),
                                    Text('@${p.handle}', style: AuraText.muted),
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
                  AuraCard(
                    child: Padding(
                      padding: const EdgeInsets.all(AuraSpace.s16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Display name', style: AuraText.body),
                          const SizedBox(height: AuraSpace.s8),
                          TextField(
                            controller: _displayName,
                            decoration: const InputDecoration(
                              hintText: 'Your name',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: AuraSpace.s14),
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
                          const SizedBox(height: AuraSpace.s14),
                          Text('Avatar URL', style: AuraText.body),
                          const SizedBox(height: AuraSpace.s8),
                          TextField(
                            controller: _avatarUrl,
                            decoration: const InputDecoration(
                              hintText: 'https://…',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) {
                              // Manual edits should also refresh preview.
                              setState(() => _avatarBust++);
                            },
                          ),
                          const SizedBox(height: AuraSpace.s14),
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