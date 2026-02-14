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

    // Backend returns "/uploads/.." relative to its origin.
    // Dio baseUrl is like "http://localhost:3000" (no /v1).
    final root = dio.options.baseUrl.replaceAll(RegExp(r'/+$'), '');
    if (u.startsWith('/')) return '$root$u';
    return '$root/$u';
  }

  Future<void> _uploadAvatar() async {
    if (_uploading) return;
    setState(() => _uploading = true);

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
      );

      if (picked == null) {
        setState(() => _uploading = false);
        return;
      }

      final dio = ref.read(dioProvider);

      MultipartFile filePart;
      if (kIsWeb) {
        final Uint8List bytes = await picked.readAsBytes();
        filePart = MultipartFile.fromBytes(bytes, filename: picked.name);
      } else {
        filePart = await MultipartFile.fromFile(picked.path, filename: picked.name);
      }

      final form = FormData.fromMap({'file': filePart});
      final res = await dio.post('/uploads/avatar', data: form);

      final body = res.data;
      String avatarUrl = '';
      if (body is Map) {
        avatarUrl = (body['avatarUrl'] ?? '').toString().trim();
        if (avatarUrl.isEmpty && body['user'] is Map) {
          avatarUrl = ((body['user'] as Map)['avatarUrl'] ?? '').toString().trim();
        }
      }

      if (avatarUrl.isEmpty) {
        throw Exception('Upload succeeded but avatarUrl missing in response.');
      }

      final absolute = _absoluteFromMaybeRelative(avatarUrl, dio);
      _avatarUrl.text = absolute;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar uploaded. Tap Save.')),
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
      final repo = ref.read(profileRepositoryProvider);

      final updated = await repo.updateMe(
        displayName: _displayName.text.trim(),
        bio: _bio.text.trim(),
        avatarUrl: _avatarUrl.text.trim().isEmpty ? null : _avatarUrl.text.trim(),
      );

      ref.invalidate(meProfileProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
      Navigator.of(context).pop(updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final meAsync = ref.watch(meProfileProvider);

    return AuraScaffold(
      title: 'Edit profile',
      actions: [
        TextButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
      body: meAsync.when(
        data: (p) {
          _seed(p);

          final avatar = _avatarUrl.text.trim().isNotEmpty ? _avatarUrl.text.trim() : ((p.avatarUrl ?? '').trim());

          return ListView(
            padding: EdgeInsets.fromLTRB(AuraSpace.s16, AuraSpace.s12, AuraSpace.s16, AuraSpace.s24),
            children: [
              AuraCard(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: const Color(0x332E2A26),
                      backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                      child: avatar.isEmpty
                          ? Text(
                              p.displayName.isNotEmpty ? p.displayName[0].toUpperCase() : 'A',
                              style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                            )
                          : null,
                    ),
                    SizedBox(width: AuraSpace.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('@${p.handle}', style: AuraText.title),
                          SizedBox(height: AuraSpace.s6),
                          Text('Keep it simple. Keep it true.', style: AuraText.muted),
                        ],
                      ),
                    )
                  ],
                ),
              ),
              SizedBox(height: AuraSpace.s12),

              FilledButton.icon(
                onPressed: (_uploading || _saving) ? null : _uploadAvatar,
                icon: _uploading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.image_outlined),
                label: Text(_uploading ? 'Uploading…' : 'Upload avatar'),
              ),

              SizedBox(height: AuraSpace.s18),

              AuraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Basics', style: AuraText.title),
                    SizedBox(height: AuraSpace.s10),
                    TextField(
                      controller: _displayName,
                      decoration: const InputDecoration(
                        labelText: 'Display name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: AuraSpace.s12),
                    TextField(
                      controller: _bio,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Bio',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: AuraSpace.s12),

              AuraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Avatar URL', style: AuraText.title),
                    SizedBox(height: AuraSpace.s10),
                    TextField(
                      controller: _avatarUrl,
                      decoration: const InputDecoration(
                        labelText: 'Auto-filled after upload',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: AuraSpace.s16),

              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save changes'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: AuraCard(
              child: Text('Could not load profile: $e', style: AuraText.body),
            ),
          ),
        ),
      ),
    );
  }
}
