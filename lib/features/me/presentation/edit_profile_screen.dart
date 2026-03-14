import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _displayNameController;
  late final TextEditingController _bioController;
  late final TextEditingController _avatarUrlController;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  String _handle = '';
  String _email = '';

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController();
    _bioController = TextEditingController();
    _avatarUrlController = TextEditingController();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final dio = ref.read(dioProvider);

    try {
      final data = await _fetchCurrentUser(dio);

      if (!mounted) return;

      _displayNameController.text =
          (data['displayName'] ?? data['name'] ?? '').toString().trim();
      _bioController.text = (data['bio'] ?? '').toString();
      _avatarUrlController.text =
          (data['avatarUrl'] ?? data['avatar'] ?? '').toString().trim();

      _handle = (data['handle'] ?? '').toString().trim();
      _email = (data['email'] ?? '').toString().trim();

      setState(() {
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load your profile.';
      });
    }
  }

  Future<Map<String, dynamic>> _fetchCurrentUser(Dio dio) async {
    final attempts = <Future<Response<dynamic>> Function()>[
      () => dio.get('/users/me'),
      () => dio.get('/auth/me'),
    ];

    Object? lastError;

    for (final request in attempts) {
      try {
        final res = await request();
        final normalized = _normalizeMap(res.data);
        if (normalized.isNotEmpty) return normalized;
      } catch (e) {
        lastError = e;
      }
    }

    throw lastError ?? Exception('Failed to load current user');
  }

  Map<String, dynamic> _normalizeMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      final nested = raw['data'];
      if (nested is Map<String, dynamic>) return nested;
      return raw;
    }

    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final nested = map['data'];
      if (nested is Map) return Map<String, dynamic>.from(nested);
      return map;
    }

    return <String, dynamic>{};
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final dio = ref.read(dioProvider);

    final payload = <String, dynamic>{
      'displayName': _displayNameController.text.trim(),
      'bio': _bioController.text.trim(),
      'avatarUrl': _avatarUrlController.text.trim(),
    };

    Object? lastError;

    final attempts = <Future<Response<dynamic>> Function()>[
      () => dio.patch('/users/me', data: payload),
      () => dio.put('/users/me', data: payload),
      () => dio.patch('/auth/me', data: payload),
      () => dio.put('/auth/me', data: payload),
      () => dio.patch('/profile/me', data: payload),
      () => dio.put('/profile/me', data: payload),
    ];

    for (final request in attempts) {
      try {
        await request();

        if (!mounted) return;

        setState(() {
          _saving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );

        return;
      } catch (e) {
        lastError = e;
      }
    }

    if (!mounted) return;

    String message = 'Could not save profile.';
    if (lastError is DioException) {
      final data = lastError.response?.data;
      if (data is Map && data['message'] != null) {
        message = data['message'].toString();
      }
    }

    setState(() {
      _saving = false;
      _error = message;
    });
  }

  Widget _buildHeaderCard() {
    final name = _displayNameController.text.trim();
    final bio = _bioController.text.trim();
    final avatarUrl = _avatarUrlController.text.trim();

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Edit profile', style: AuraText.title),
          const SizedBox(height: AuraSpace.s10),
          Text(
            'Keep this simple and alive. Your profile should feel like a real person, not a slogan.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProfileAvatarPreview(
                imageUrl: avatarUrl,
                fallbackText: name.isNotEmpty ? name : _handle,
              ),
              const SizedBox(width: AuraSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isNotEmpty ? name : 'Your display name',
                      style: AuraText.body.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (_handle.isNotEmpty) ...[
                      const SizedBox(height: AuraSpace.s4),
                      Text(
                        '@$_handle',
                        style: AuraText.small,
                      ),
                    ],
                    if (_email.isNotEmpty) ...[
                      const SizedBox(height: AuraSpace.s4),
                      Text(
                        _email,
                        style: AuraText.small,
                      ),
                    ],
                    if (bio.isNotEmpty) ...[
                      const SizedBox(height: AuraSpace.s8),
                      Text(
                        bio,
                        style: AuraText.body.copyWith(height: 1.35),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return AuraCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Profile details', style: AuraText.title),
            const SizedBox(height: AuraSpace.s14),
            TextFormField(
              controller: _displayNameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Display name',
                hintText: 'How your name should appear',
              ),
              onChanged: (_) => setState(() {}),
              validator: (value) {
                final v = (value ?? '').trim();
                if (v.isEmpty) return 'Display name is required';
                if (v.length < 2) return 'Display name is too short';
                return null;
              },
            ),
            const SizedBox(height: AuraSpace.s14),
            TextFormField(
              initialValue: _handle,
              enabled: false,
              decoration: const InputDecoration(
                labelText: 'Handle',
              ),
            ),
            const SizedBox(height: AuraSpace.s14),
            TextFormField(
              controller: _bioController,
              minLines: 4,
              maxLines: 7,
              decoration: const InputDecoration(
                labelText: 'Bio',
                hintText: 'A grounded line about who you are and what you carry',
                alignLabelWithHint: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AuraSpace.s14),
            TextFormField(
              controller: _avatarUrlController,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Avatar URL',
                hintText: 'https://...',
              ),
              onChanged: (_) => setState(() {}),
              validator: (value) {
                final v = (value ?? '').trim();
                if (v.isEmpty) return null;
                final uri = Uri.tryParse(v);
                if (uri == null || !uri.hasAbsolutePath) {
                  return 'Enter a valid URL or leave it empty';
                }
                return null;
              },
            ),
            const SizedBox(height: AuraSpace.s18),
            Wrap(
              spacing: AuraSpace.s10,
              runSpacing: AuraSpace.s10,
              children: [
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving...' : 'Save changes'),
                ),
                OutlinedButton(
                  onPressed: _saving ? null : _load,
                  child: const Text('Reload'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: AuraSpace.s14),
              Text(
                _error!,
                style: AuraText.body.copyWith(color: Colors.redAccent),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAuthed = ref.watch(isAuthedProvider);

    if (!isAuthed) {
      return AuraScaffold(
        showHeader: false,
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            AuraSpace.s16,
            AuraSpace.s12,
            AuraSpace.s16,
            AuraSpace.s24,
          ),
          children: const [
            AuraCard(
              child: Text(
                'You need to be signed in to edit your profile.',
                style: AuraText.body,
              ),
            ),
          ],
        ),
      );
    }

    if (_loading) {
      return AuraScaffold(
        showHeader: false,
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            AuraSpace.s16,
            AuraSpace.s12,
            AuraSpace.s16,
            AuraSpace.s24,
          ),
          children: const [
            AuraCard(
              child: Padding(
                padding: EdgeInsets.all(AuraSpace.s12),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return AuraScaffold(
      showHeader: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AuraSpace.s16,
          AuraSpace.s12,
          AuraSpace.s16,
          AuraSpace.s24,
        ),
        children: [
          _buildHeaderCard(),
          const SizedBox(height: AuraSpace.s16),
          _buildFormCard(),
        ],
      ),
    );
  }
}

class _ProfileAvatarPreview extends StatelessWidget {
  const _ProfileAvatarPreview({
    required this.imageUrl,
    required this.fallbackText,
  });

  final String imageUrl;
  final String fallbackText;

  @override
  Widget build(BuildContext context) {
    final trimmed = imageUrl.trim();
    final initial = fallbackText.trim().isNotEmpty
        ? fallbackText.trim().characters.first.toUpperCase()
        : '?';

    if (trimmed.isEmpty) {
      return CircleAvatar(
        radius: 28,
        child: Text(initial),
      );
    }

    return CircleAvatar(
      radius: 28,
      backgroundImage: NetworkImage(trimmed),
      onBackgroundImageError: (_, __) {},
      child: trimmed.isEmpty ? Text(initial) : null,
    );
  }
}