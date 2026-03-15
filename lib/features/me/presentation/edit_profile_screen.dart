import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  String _initialDisplayName = '';
  String _initialBio = '';
  String _initialAvatarUrl = '';

  @override
  void initState() {
    super.initState();

    _displayNameController = TextEditingController();
    _bioController = TextEditingController();
    _avatarUrlController = TextEditingController();

    _displayNameController.addListener(_onFormChanged);
    _bioController.addListener(_onFormChanged);
    _avatarUrlController.addListener(_onFormChanged);

    Future.microtask(_load);
  }

  @override
  void dispose() {
    _displayNameController.removeListener(_onFormChanged);
    _bioController.removeListener(_onFormChanged);
    _avatarUrlController.removeListener(_onFormChanged);

    _displayNameController.dispose();
    _bioController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  bool get _hasChanges {
    return _displayNameController.text.trim() != _initialDisplayName ||
        _bioController.text.trim() != _initialBio ||
        _avatarUrlController.text.trim() != _initialAvatarUrl;
  }

  String get _displayNameValue => _displayNameController.text.trim();
  String get _bioValue => _bioController.text.trim();
  String get _avatarValue => _avatarUrlController.text.trim();

  String get _effectiveDisplayLabel {
    if (_displayNameValue.isNotEmpty) return _displayNameValue;
    if (_handle.isNotEmpty) return _handle;
    return 'Your profile';
  }

  ImageProvider<Object>? get _avatarProvider {
    final url = _avatarValue;
    if (url.isEmpty) return null;

    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (!(uri.isScheme('http') || uri.isScheme('https'))) return null;

    return NetworkImage(url);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final dio = ref.read(dioProvider);

    try {
      final res = await dio.get('/users/me');
      final data = Map<String, dynamic>.from(res.data as Map);

      if (!mounted) return;

      _initialDisplayName = (data['displayName'] ?? '').toString().trim();
      _initialBio = (data['bio'] ?? '').toString().trim();
      _initialAvatarUrl = (data['avatarUrl'] ?? '').toString().trim();

      _displayNameController.text = _initialDisplayName;
      _bioController.text = _initialBio;
      _avatarUrlController.text = _initialAvatarUrl;

      _handle = (data['handle'] ?? '').toString().trim();
      _email = (data['email'] ?? '').toString().trim();

      setState(() {
        _loading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _error = _readApiError(e, fallback: 'Failed to load profile');
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Failed to load profile';
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    if (!_hasChanges) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final dio = ref.read(dioProvider);

    try {
      await dio.patch(
        '/users/me',
        data: {
          'displayName': _displayNameValue,
          'bio': _bioValue,
          'avatarUrl': _avatarValue,
        },
      );

      _initialDisplayName = _displayNameValue;
      _initialBio = _bioValue;
      _initialAvatarUrl = _avatarValue;

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _readApiError(e, fallback: 'Failed to save profile');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to save profile';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  String _readApiError(DioException e, {required String fallback}) {
    final data = e.response?.data;

    if (data is Map) {
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }

      final error = data['error'];
      if (error is Map) {
        final nestedMessage = error['message'];
        if (nestedMessage is String && nestedMessage.trim().isNotEmpty) {
          return nestedMessage.trim();
        }
      }
    }

    if (e.message != null && e.message!.trim().isNotEmpty) {
      return e.message!.trim();
    }

    return fallback;
  }

  InputDecoration _inputDecoration(
    String label, {
    String? hint,
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon,
      alignLabelWithHint: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AuraText.body.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AuraText.small.copyWith(
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadonlyRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
        color: Colors.white.withValues(alpha: 0.02),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white70),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AuraText.small.copyWith(color: Colors.white60),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarPreview() {
    final provider = _avatarProvider;
    final initials = _effectiveDisplayLabel.isNotEmpty
        ? _effectiveDisplayLabel.characters.first.toUpperCase()
        : 'A';

    return Container(
      padding: const EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
        color: Colors.white.withValues(alpha: 0.02),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: Colors.white12,
            foregroundImage: provider,
            child: provider == null
                ? Text(
                    initials,
                    style: AuraText.body.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: AuraSpace.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _effectiveDisplayLabel,
                  style: AuraText.body.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_handle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '@$_handle',
                    style: AuraText.small.copyWith(color: Colors.white70),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'This is how your identity begins to read across Aura.',
                  style: AuraText.small.copyWith(color: Colors.white60),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return AuraCard(
      padding: const EdgeInsets.all(AuraSpace.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Profile Studio',
            style: AuraText.body.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(
            'Shape how you appear, how you are read, and how your work is encountered.',
            style: AuraText.body.copyWith(
              color: Colors.white70,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AuraSpace.s20),
          _buildAvatarPreview(),
        ],
      ),
    );
  }

  Widget _buildIdentitySection() {
    return AuraCard(
      padding: const EdgeInsets.all(AuraSpace.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            'Identity',
            'The public name and account markers people recognize first.',
          ),
          if (_handle.isNotEmpty || _email.isNotEmpty) ...[
            if (_handle.isNotEmpty)
              _buildReadonlyRow(
                icon: Icons.alternate_email_rounded,
                label: 'Handle',
                value: '@$_handle',
              ),
            if (_handle.isNotEmpty && _email.isNotEmpty)
              const SizedBox(height: AuraSpace.s12),
            if (_email.isNotEmpty)
              _buildReadonlyRow(
                icon: Icons.mail_outline_rounded,
                label: 'Email',
                value: _email,
              ),
            const SizedBox(height: AuraSpace.s16),
          ],
          TextFormField(
            controller: _displayNameController,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(
              'Display name',
              hint: 'How your name appears across Aura',
              prefixIcon: const Icon(Icons.badge_outlined),
            ),
            validator: (value) {
              final v = (value ?? '').trim();
              if (v.isEmpty) return 'Display name is required';
              if (v.length < 2) return 'Display name is too short';
              if (v.length > 80) return 'Display name must be 80 characters or less';
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPresenceSection() {
    return AuraCard(
      padding: const EdgeInsets.all(AuraSpace.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            'Presence',
            'A short introduction that gives people a sense of your voice and direction.',
          ),
          TextFormField(
            controller: _bioController,
            maxLines: 6,
            maxLength: 280,
            decoration: _inputDecoration(
              'Bio',
              hint: 'Write a concise description of your work, interests, or point of view',
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 72),
                child: Icon(Icons.notes_rounded),
              ),
            ),
            validator: (value) {
              final v = (value ?? '').trim();
              if (v.length > 280) {
                return 'Bio must be 280 characters or less';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImageSection() {
    return AuraCard(
      padding: const EdgeInsets.all(AuraSpace.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            'Profile image',
            'Use a stable image URL for now. This can later be upgraded to first-class media upload.',
          ),
          TextFormField(
            controller: _avatarUrlController,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            decoration: _inputDecoration(
              'Avatar URL',
              hint: 'https://example.com/avatar.jpg',
              prefixIcon: const Icon(Icons.image_outlined),
            ),
            validator: (value) {
              final v = (value ?? '').trim();
              if (v.isEmpty) return null;

              final uri = Uri.tryParse(v);
              final valid = uri != null &&
                  (uri.isScheme('http') || uri.isScheme('https')) &&
                  (uri.host.isNotEmpty);

              if (!valid) return 'Enter a valid image URL';
              return null;
            },
          ),
          const SizedBox(height: AuraSpace.s12),
          Text(
            'A clean portrait or mark works best. Leave blank if you do not want to use one yet.',
            style: AuraText.small.copyWith(color: Colors.white60),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    if (_error == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error!,
              style: AuraText.small.copyWith(
                color: const Color(0xFFFFB4B4),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return AuraCard(
      padding: const EdgeInsets.all(AuraSpace.s16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _hasChanges
                  ? 'You have unsaved changes.'
                  : 'Everything is up to date.',
              style: AuraText.small.copyWith(color: Colors.white70),
            ),
          ),
          const SizedBox(width: AuraSpace.s12),
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: AuraSpace.s8),
          ElevatedButton(
            onPressed: (_saving || !_hasChanges) ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save changes'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AuraSpace.s16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: AuraSpace.s16),
                _buildErrorBanner(),
                if (_error != null) const SizedBox(height: AuraSpace.s16),
                _buildIdentitySection(),
                const SizedBox(height: AuraSpace.s16),
                _buildPresenceSection(),
                const SizedBox(height: AuraSpace.s16),
                _buildProfileImageSection(),
                const SizedBox(height: AuraSpace.s16),
                _buildActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuraScaffold(
      showHeader: false,
      body: _buildBody(),
    );
  }
}