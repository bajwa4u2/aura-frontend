import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _locationController = TextEditingController();
  final _websiteController = TextEditingController();
  final _picker = ImagePicker();

  bool _loading = true;
  bool _saving = false;
  bool _uploadingAvatar = false;
  bool _uploadingCover = false;

  String? _errorText;

  String? _avatarUrl;
  String? _coverUrl;

  String _handle = '';
  String _email = '';
  String _firstName = '';
  String _lastName = '';

  String _initialDisplayName = '';
  String _initialBio = '';
  String _initialLocation = '';
  String _initialWebsite = '';
  String? _initialAvatarUrl;
  String? _initialCoverUrl;

  @override
  void initState() {
    super.initState();
    _displayNameController.addListener(_onChanged);
    _bioController.addListener(_onChanged);
    _locationController.addListener(_onChanged);
    _websiteController.addListener(_onChanged);
    _load();
  }

  @override
  void dispose() {
    _displayNameController.removeListener(_onChanged);
    _bioController.removeListener(_onChanged);
    _locationController.removeListener(_onChanged);
    _websiteController.removeListener(_onChanged);

    _displayNameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  bool get _busy => _saving || _uploadingAvatar || _uploadingCover;

  bool get _hasChanges {
    return _displayNameController.text.trim() != _initialDisplayName ||
        _bioController.text.trim() != _initialBio ||
        _locationController.text.trim() != _initialLocation ||
        _websiteController.text.trim() != _initialWebsite ||
        (_avatarUrl ?? '') != (_initialAvatarUrl ?? '') ||
        (_coverUrl ?? '') != (_initialCoverUrl ?? '');
  }

  String get _displayName {
    final value = _displayNameController.text.trim();
    if (value.isNotEmpty) return value;
    if (_firstName.trim().isNotEmpty || _lastName.trim().isNotEmpty) {
      return '${_firstName.trim()} ${_lastName.trim()}'.trim();
    }
    if (_handle.trim().isNotEmpty) return _handle.trim();
    return 'Profile';
  }

  String get _bio => _bioController.text.trim();

  String get _location => _locationController.text.trim();

  String get _website => _websiteController.text.trim();

  String get _initials {
    final source = _displayName.trim();
    if (source.isEmpty) return 'A';
    final parts = source.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }
    return '${parts.first.characters.first}${parts.last.characters.first}'.toUpperCase();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/v1/users/me');
      final data = _unwrapResponseMap(res.data);

      _initialDisplayName = _readString(data, const ['displayName', 'name']);
      _initialBio = _readString(data, const ['bio', 'headline', 'summary']);
      _initialLocation = _readString(data, const ['location']);
      _initialWebsite = _readString(data, const ['website', 'site', 'url']);
      _initialAvatarUrl = _emptyToNull(
        _readString(data, const ['avatarUrl', 'avatar', 'photoUrl']),
      );
      _initialCoverUrl = _emptyToNull(
        _readString(data, const ['coverUrl', 'bannerUrl']),
      );

      _displayNameController.text = _initialDisplayName;
      _bioController.text = _initialBio;
      _locationController.text = _initialLocation;
      _websiteController.text = _initialWebsite;
      _avatarUrl = _initialAvatarUrl;
      _coverUrl = _initialCoverUrl;

      _handle = _readString(data, const ['handle', 'username']);
      _email = _readString(data, const ['email']);
      _firstName = _readString(data, const ['firstName']);
      _lastName = _readString(data, const ['lastName']);

      setState(() {
        _loading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _loading = false;
        _errorText = _readApiError(e, fallback: 'Could not load profile.');
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _errorText = 'Could not load profile.';
      });
    }
  }

  Future<void> _pickAvatar() async {
    if (_busy) return;
    await _pickAndUploadImage(isAvatar: true);
  }

  Future<void> _pickCover() async {
    if (_busy) return;
    await _pickAndUploadImage(isAvatar: false);
  }

  Future<void> _pickAndUploadImage({required bool isAvatar}) async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );
    if (file == null) return;

    setState(() {
      _errorText = null;
      if (isAvatar) {
        _uploadingAvatar = true;
      } else {
        _uploadingCover = true;
      }
    });

    try {
      final uploadedUrl = await _uploadImage(file);
      if (!mounted) return;

      setState(() {
        if (isAvatar) {
          _avatarUrl = uploadedUrl;
        } else {
          _coverUrl = uploadedUrl;
        }
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = _readApiError(e, fallback: 'Could not upload image.');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Could not upload image.';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        if (isAvatar) {
          _uploadingAvatar = false;
        } else {
          _uploadingCover = false;
        }
      });
    }
  }

  Future<String> _uploadImage(XFile file) async {
    final dio = ref.read(dioProvider);
    final bytes = await file.readAsBytes();
    final mimeType = file.mimeType ?? _inferMime(file.name);
    final size = await _decodeImageSize(bytes);

    final presignRes = await dio.post(
      '/media/presign',
      data: {
        'fileName': file.name,
        'mimeType': mimeType,
        'bytes': bytes.length,
        'kind': 'IMAGE',
        'source': 'UPLOAD',
        if (size?['width'] != null) 'width': size!['width'],
        if (size?['height'] != null) 'height': size!['height'],
      },
    );

    final presigned = _unwrapDataMap(presignRes.data);
    final mediaMap = _asMap(presigned['media']);
    final uploadMap = _asMap(presigned['upload']);

    final uploadUrl = _readString(uploadMap, const ['url']);
    if (uploadUrl.isEmpty) {
      throw Exception('Upload URL missing.');
    }

    final uploadHeaders = <String, String>{};
    final rawHeaders = _asMap(uploadMap['headers']);
    rawHeaders.forEach((key, value) {
      if (value == null) return;
      uploadHeaders[key.toString()] = value.toString();
    });
    uploadHeaders.putIfAbsent('Content-Type', () => mimeType);

    final uploadDio = Dio(
      BaseOptions(
        responseType: ResponseType.plain,
        followRedirects: true,
      ),
    );

    await uploadDio.put(
      uploadUrl,
      data: bytes,
      options: Options(
        headers: uploadHeaders,
        contentType: uploadHeaders['Content-Type'],
        validateStatus: (code) => code != null && code >= 200 && code < 300,
      ),
    );

    final mediaId = _readString(mediaMap, const ['id', 'mediaId']);
    if (mediaId.isEmpty) {
      throw Exception('Media id missing.');
    }

    await dio.post('/media/$mediaId/confirm');
    await dio.post('/media/$mediaId/ready');

    final patchRes = await dio.patch(
      '/media/$mediaId',
      data: {
        if (size?['width'] != null) 'width': size!['width'],
        if (size?['height'] != null) 'height': size!['height'],
        'editDisclosure': false,
      },
    );

    final patched = _unwrapDataMap(patchRes.data);

    final url = _readString(
      patched,
      const ['displayUrl', 'url', 'publicUrl', 'sourceUrl', 'originalUrl'],
    );
    if (url.isNotEmpty) return url;

    final fallback = _readString(
      mediaMap,
      const ['displayUrl', 'url', 'publicUrl', 'sourceUrl', 'originalUrl'],
    );
    if (fallback.isNotEmpty) return fallback;

    throw Exception('Uploaded image URL missing.');
  }

  Future<void> _save() async {
    if (_busy || !_hasChanges) return;

    setState(() {
      _saving = true;
      _errorText = null;
    });

    try {
      final dio = ref.read(dioProvider);

      await dio.patch(
        '/v1/users/me',
        data: {
          'displayName': _displayNameController.text.trim(),
          'bio': _bioController.text.trim(),
          'location': _emptyToNull(_locationController.text),
          'website': _emptyToNull(_websiteController.text),
          'avatarUrl': _emptyToNull(_avatarUrl),
          'coverUrl': _emptyToNull(_coverUrl),
        },
      );

      _initialDisplayName = _displayNameController.text.trim();
      _initialBio = _bioController.text.trim();
      _initialLocation = _locationController.text.trim();
      _initialWebsite = _websiteController.text.trim();
      _initialAvatarUrl = _emptyToNull(_avatarUrl);
      _initialCoverUrl = _emptyToNull(_coverUrl);

      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorText = _readApiError(e, fallback: 'Could not save changes.');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorText = 'Could not save changes.';
      });
    }
  }

  void _discardChanges() {
    if (_busy) return;

    setState(() {
      _displayNameController.text = _initialDisplayName;
      _bioController.text = _initialBio;
      _locationController.text = _initialLocation;
      _websiteController.text = _initialWebsite;
      _avatarUrl = _initialAvatarUrl;
      _coverUrl = _initialCoverUrl;
      _errorText = null;
    });
  }

  void _removeAvatar() {
    if (_busy) return;
    setState(() {
      _avatarUrl = null;
    });
  }

  void _removeCover() {
    if (_busy) return;
    setState(() {
      _coverUrl = null;
    });
  }

  ImageProvider? _imageProviderFromUrl(String? value) {
    final url = (value ?? '').trim();
    if (url.isEmpty) return null;
    return NetworkImage(url);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AuraScaffold(
        title: 'Profile',
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return AuraScaffold(
      title: 'Profile',
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 780),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCoverSurface(),
                      Transform.translate(
                        offset: const Offset(0, -36),
                        child: Column(
                          children: [
                            _buildAvatar(),
                            const SizedBox(height: 14),
                            _buildIdentityPreview(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (_errorText != null) ...[
                        _buildErrorBanner(),
                        const SizedBox(height: 24),
                      ],
                      _buildSectionLabel('Identity'),
                      const SizedBox(height: 14),
                      _buildIdentityBlock(),
                      const SizedBox(height: 32),
                      _buildSectionLabel('Presence'),
                      const SizedBox(height: 14),
                      _buildPresenceBlock(),
                      const SizedBox(height: 32),
                      _buildSectionLabel('Account record'),
                      const SizedBox(height: 14),
                      _buildAccountRecordBlock(),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_hasChanges) _buildSaveRail(),
        ],
      ),
    );
  }

  Widget _buildCoverSurface() {
    final coverProvider = _imageProviderFromUrl(_coverUrl);

    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.black.withOpacity(0.06),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (coverProvider != null)
            Image(
              image: coverProvider,
              fit: BoxFit.cover,
            )
          else
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.10),
                    Colors.black.withOpacity(0.04),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.18),
                  Colors.black.withOpacity(0.10),
                  Colors.black.withOpacity(0.04),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
          Positioned(
            top: 14,
            right: 14,
            child: Wrap(
              spacing: 8,
              children: [
                _surfaceActionButton(
                  label: _uploadingCover ? 'Uploading...' : 'Change cover',
                  onPressed: _busy ? null : _pickCover,
                ),
                if ((_coverUrl ?? '').isNotEmpty)
                  _surfaceActionButton(
                    label: 'Remove',
                    onPressed: _busy ? null : _removeCover,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final avatarProvider = _imageProviderFromUrl(_avatarUrl);

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                blurRadius: 18,
                offset: const Offset(0, 8),
                color: Colors.black.withOpacity(0.08),
              ),
            ],
          ),
          padding: const EdgeInsets.all(6),
          child: CircleAvatar(
            radius: 48,
            backgroundColor: Colors.black.withOpacity(0.08),
            backgroundImage: avatarProvider,
            child: avatarProvider == null
                ? Text(
                    _initials,
                    style: AuraTextStyles.title.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
        ),
        Positioned(
          right: 0,
          bottom: 2,
          child: PopupMenuButton<String>(
            enabled: !_busy,
            onSelected: (value) {
              if (value == 'change') {
                _pickAvatar();
              } else if (value == 'remove') {
                _removeAvatar();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'change',
                child: Text(_uploadingAvatar ? 'Uploading...' : 'Change photo'),
              ),
              if ((_avatarUrl ?? '').isNotEmpty)
                const PopupMenuItem<String>(
                  value: 'remove',
                  child: Text('Remove photo'),
                ),
            ],
            child: Container(
              height: 34,
              width: 34,
              decoration: BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.camera_alt_outlined,
                size: 17,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIdentityPreview() {
    return Column(
      children: [
        Text(
          _displayName,
          textAlign: TextAlign.center,
          style: AuraTextStyles.title.copyWith(
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (_handle.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            '@${_handle.trim()}',
            textAlign: TextAlign.center,
            style: AuraTextStyles.muted.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        if (_bio.isNotEmpty) ...[
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Text(
              _bio,
              textAlign: TextAlign.center,
              style: AuraTextStyles.body.copyWith(height: 1.45),
            ),
          ),
        ],
        if (_location.isNotEmpty || _website.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              if (_location.isNotEmpty)
                Text(
                  _location,
                  style: AuraTextStyles.muted.copyWith(fontSize: 13),
                ),
              if (_website.isNotEmpty)
                Text(
                  _website,
                  style: AuraTextStyles.muted.copyWith(fontSize: 13),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildIdentityBlock() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
        color: Colors.black.withOpacity(0.02),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildField(
            label: 'Display name',
            controller: _displayNameController,
            textInputAction: TextInputAction.next,
            maxLines: 1,
          ),
          const SizedBox(height: 16),
          _buildField(
            label: 'Bio',
            controller: _bioController,
            textInputAction: TextInputAction.newline,
            minLines: 4,
            maxLines: 6,
          ),
        ],
      ),
    );
  }

  Widget _buildPresenceBlock() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
        color: Colors.black.withOpacity(0.02),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildField(
            label: 'Location',
            controller: _locationController,
            textInputAction: TextInputAction.next,
            maxLines: 1,
          ),
          const SizedBox(height: 16),
          _buildField(
            label: 'Website',
            controller: _websiteController,
            textInputAction: TextInputAction.done,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildAccountRecordBlock() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
        color: Colors.black.withOpacity(0.02),
      ),
      child: Column(
        children: [
          _recordRow('Handle', _handle.isEmpty ? '—' : '@$_handle'),
          _divider(),
          _recordRow('Email', _email.isEmpty ? '—' : _email),
          _divider(),
          _recordRow('First name', _firstName.isEmpty ? '—' : _firstName),
          _divider(),
          _recordRow('Last name', _lastName.isEmpty ? '—' : _lastName),
        ],
      ),
    );
  }

  Widget _recordRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AuraTextStyles.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AuraTextStyles.muted,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required TextInputAction textInputAction,
    int minLines = 1,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AuraTextStyles.muted.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          textInputAction: textInputAction,
          minLines: minLines,
          maxLines: maxLines,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.black.withOpacity(0.10)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.black.withOpacity(0.10)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.black, width: 1.2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFCECEC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8B7B7)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Text(
        _errorText ?? '',
        style: AuraTextStyles.body.copyWith(
          color: const Color(0xFF7A1E1E),
        ),
      ),
    );
  }

  Widget _buildSaveRail() {
    return Positioned(
      left: 20,
      right: 20,
      bottom: 20,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black.withOpacity(0.10)),
              boxShadow: [
                BoxShadow(
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                  color: Colors.black.withOpacity(0.10),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _saving ? 'Saving...' : 'Unsaved changes',
                    style: AuraTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : _discardChanges,
                  child: const Text('Discard'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: AuraTextStyles.muted.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _surfaceActionButton({
    required String label,
    required VoidCallback? onPressed,
  }) {
    return Material(
      color: Colors.white.withOpacity(0.90),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            label,
            style: AuraTextStyles.body.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 18),
      color: Colors.black.withOpacity(0.07),
    );
  }

  String _readApiError(DioException e, {required String fallback}) {
    final data = e.response?.data;
    if (data is Map) {
      final direct = data['message'];
      if (direct is String && direct.trim().isNotEmpty) {
        return direct.trim();
      }
      final error = data['error'];
      if (error is Map) {
        final nested = error['message'];
        if (nested is String && nested.trim().isNotEmpty) {
          return nested.trim();
        }
      }
    }
    final msg = e.message?.trim() ?? '';
    if (msg.isNotEmpty) return msg;
    return fallback;
  }
}

Map<String, dynamic> _unwrapResponseMap(dynamic raw) {
  if (raw is Map<String, dynamic>) {
    const nestedKeys = ['data', 'user', 'item', 'result', 'payload'];
    for (final key in nestedKeys) {
      final nested = raw[key];
      if (nested is Map<String, dynamic>) {
        return _unwrapResponseMap(nested);
      }
      if (nested is Map) {
        return _unwrapResponseMap(Map<String, dynamic>.from(nested));
      }
    }
    return raw;
  }

  if (raw is Map) {
    return _unwrapResponseMap(Map<String, dynamic>.from(raw));
  }

  return <String, dynamic>{};
}

Map<String, dynamic> _unwrapDataMap(dynamic raw) {
  if (raw is Map) {
    final map = Map<String, dynamic>.from(raw);
    final data = map['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return map;
  }
  return <String, dynamic>{};
}

Map<String, dynamic> _asMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return <String, dynamic>{};
}

String _readString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = (map[key] ?? '').toString().trim();
    if (value.isNotEmpty) return value;
  }
  return '';
}

String? _emptyToNull(String? value) {
  final text = (value ?? '').trim();
  return text.isEmpty ? null : text;
}

String _inferMime(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.webp')) return 'image/webp';
  return 'application/octet-stream';
}

Future<Map<String, int>?> _decodeImageSize(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  return {
    'width': image.width,
    'height': image.height,
  };
}