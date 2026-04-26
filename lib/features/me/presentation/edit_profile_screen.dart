import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/attachments/aura_media_upload.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_design_system.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/aura_text_block.dart';

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
  List<Map<String, dynamic>> _initialPublicationsData = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _initialLinksData = const <Map<String, dynamic>>[];

  List<_EditablePublication> _publications = <_EditablePublication>[];
  List<_EditableLink> _links = <_EditableLink>[];

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

    for (final item in _publications) {
      item.dispose();
    }
    for (final item in _links) {
      item.dispose();
    }
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
        (_coverUrl ?? '') != (_initialCoverUrl ?? '') ||
        _publicationsSignature != _signatureForCollection(_initialPublicationsData) ||
        _linksSignature != _signatureForCollection(_initialLinksData);
  }

  String get _displayName {
    final value = _displayNameController.text.trim();
    if (value.isNotEmpty) return value;

    final fallback = '${_firstName.trim()} ${_lastName.trim()}'.trim();
    if (fallback.isNotEmpty) return fallback;
    if (_handle.trim().isNotEmpty) return _handle.trim();
    return 'Presence';
  }

  String get _bio => _bioController.text.trim();
  String get _location => _locationController.text.trim();
  String get _website => _websiteController.text.trim();

  String get _initials {
    final source = _displayName.trim();
    if (source.isEmpty) return 'A';

    final parts =
        source.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();

    if (parts.isEmpty) return 'A';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    final first = parts.first.substring(0, 1).toUpperCase();
    final last = parts.last.substring(0, 1).toUpperCase();
    return '$first$last';
  }

  String get _publicationsSignature =>
      _signatureForCollection(_normalizedPublicationsPayload());

  String get _linksSignature => _signatureForCollection(_normalizedLinksPayload());

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/users/me');
      final data = _unwrapResponseMap(res.data);

      _initialDisplayName = _readString(data, const ['displayName', 'name']);
      _initialBio = _readString(data, const ['bio', 'headline', 'summary']);
      _initialLocation = _readString(data, const ['location', 'place']);
      if (_initialLocation.isEmpty) {
        final city = _readString(data, const ['city']);
        final country = _readString(data, const ['country']);
        _initialLocation = [city, country].where((e) => e.isNotEmpty).join(', ');
      }

      _initialWebsite = _readString(
        data,
        const ['website', 'websiteUrl', 'site', 'url'],
      );
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

      _replacePublications(
        _extractPublications(data)
            .map((item) => _EditablePublication.fromMap(item, onChanged: _onChanged))
            .toList(),
      );
      _replaceLinks(
        _extractLinks(data)
            .map((item) => _EditableLink.fromMap(item, onChanged: _onChanged))
            .toList(),
      );

      _initialPublicationsData = _normalizedPublicationsPayload();
      _initialLinksData = _normalizedLinksPayload();

      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorText = _readApiError(e, fallback: 'Could not load profile.');
      });
    } catch (_) {
      if (!mounted) return;
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
    final bytes = await file.readAsBytes();
    final mimeType = file.mimeType ?? _inferMime(file.name);
    final size = await _decodeImageSize(bytes);
    final result = await uploadAuraMedia(
      dio: ref.read(dioProvider),
      bytes: bytes,
      fileName: file.name,
      mimeType: mimeType,
      kind: 'IMAGE',
      source: 'UPLOAD',
      width: size?['width'],
      height: size?['height'],
      metadataPatch: <String, dynamic>{
        if (size?['width'] != null) 'width': size!['width'],
        if (size?['height'] != null) 'height': size!['height'],
        'editDisclosure': false,
      },
    );

    final url = result.url.trim();
    if (url.isNotEmpty) return url;

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

      final location = _emptyToNull(_locationController.text);
      final website = _emptyToNull(_websiteController.text);
      final publications = _normalizedPublicationsPayload();
      final links = _normalizedLinksPayload();

      await dio.patch(
        '/users/me',
        data: {
          'displayName': _displayNameController.text.trim(),
          'bio': _bioController.text.trim(),
          'location': location,
          'website': website,
          'websiteUrl': website,
          'avatarUrl': _emptyToNull(_avatarUrl),
          'coverUrl': _emptyToNull(_coverUrl),
          'bannerUrl': _emptyToNull(_coverUrl),
          'publications': publications,
          'links': links,
        },
      );

      _initialDisplayName = _displayNameController.text.trim();
      _initialBio = _bioController.text.trim();
      _initialLocation = _locationController.text.trim();
      _initialWebsite = _websiteController.text.trim();
      _initialAvatarUrl = _emptyToNull(_avatarUrl);
      _initialCoverUrl = _emptyToNull(_coverUrl);
      _initialPublicationsData = publications;
      _initialLinksData = links;

      if (!mounted) return;
      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Presence updated')),
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
      _replacePublications(
        _initialPublicationsData
            .map((item) => _EditablePublication.fromMap(item, onChanged: _onChanged))
            .toList(),
      );
      _replaceLinks(
        _initialLinksData
            .map((item) => _EditableLink.fromMap(item, onChanged: _onChanged))
            .toList(),
      );
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

  void _addPublication() {
    if (_busy) return;
    setState(() {
      _publications = [
        ..._publications,
        _EditablePublication(onChanged: _onChanged),
      ];
    });
  }

  void _removePublicationAt(int index) {
    if (_busy || index < 0 || index >= _publications.length) return;
    setState(() {
      final item = _publications.removeAt(index);
      item.dispose();
    });
  }

  void _addLink() {
    if (_busy) return;
    setState(() {
      _links = [
        ..._links,
        _EditableLink(onChanged: _onChanged),
      ];
    });
  }

  void _removeLinkAt(int index) {
    if (_busy || index < 0 || index >= _links.length) return;
    setState(() {
      final item = _links.removeAt(index);
      item.dispose();
    });
  }

  void _replacePublications(List<_EditablePublication> next) {
    for (final item in _publications) {
      item.dispose();
    }
    _publications = next;
  }

  void _replaceLinks(List<_EditableLink> next) {
    for (final item in _links) {
      item.dispose();
    }
    _links = next;
  }

  List<Map<String, dynamic>> _normalizedPublicationsPayload() {
    final out = <Map<String, dynamic>>[];
    for (final item in _publications) {
      final map = item.normalized;
      if (map.isNotEmpty) out.add(map);
    }
    return out;
  }

  List<Map<String, dynamic>> _normalizedLinksPayload() {
    final out = <Map<String, dynamic>>[];
    for (final item in _links) {
      final map = item.normalized;
      if (map.isNotEmpty) out.add(map);
    }
    return out;
  }

  ImageProvider? _imageProviderFromUrl(String? value) {
    final url = (value ?? '').trim();
    if (url.isEmpty) return null;
    return NetworkImage(url);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return AuraScaffold(
        title: 'Edit presence',
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return AuraScaffold(
      title: 'Edit presence',
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.s20,
              AuraSpace.s20,
              AuraSpace.s20,
              140,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      const AuraGradientHero(
                        badge: 'Presence editor',
                        title: 'Shape how Aura knows you',
                        subtitle:
                            'Refine your public identity, profile media, and the records that travel with your name.',
                      ),
                      const SizedBox(height: AuraSpace.s16),
                      _buildCoverSurface(),
                      Transform.translate(
                        offset: const Offset(0, -36),
                        child: Column(
                          children: [
                            _buildAvatar(),
                            const SizedBox(height: AuraSpace.s14),
                            _buildIdentityPreview(),
                          ],
                        ),
                      ),
                      const SizedBox(height: AuraSpace.s4),
                      if (_errorText != null) ...[
                        _buildErrorBanner(),
                        const SizedBox(height: AuraSpace.s24),
                      ],
                      _buildSectionLabel('Identity'),
                      const SizedBox(height: AuraSpace.s14),
                      _buildIdentityBlock(),
                      const SizedBox(height: AuraSpace.s32),
                      _buildSectionLabel('Presence'),
                      const SizedBox(height: AuraSpace.s14),
                      _buildPresenceBlock(),
                      const SizedBox(height: AuraSpace.s32),
                      _buildSectionLabel('Publications'),
                      const SizedBox(height: AuraSpace.s14),
                      _buildPublicationsBlock(),
                      const SizedBox(height: AuraSpace.s32),
                      _buildSectionLabel('Links'),
                      const SizedBox(height: AuraSpace.s14),
                      _buildLinksBlock(),
                      const SizedBox(height: AuraSpace.s32),
                      _buildSectionLabel('Account record'),
                      const SizedBox(height: AuraSpace.s14),
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
      height: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: AuraSurface.card,
        border: Border.all(color: AuraSurface.divider),
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
                    AuraSurface.elevated,
                    AuraSurface.card,
                    const Color(0xFF171B22),
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
                  Colors.black.withOpacity(0.10),
                  Colors.black.withOpacity(0.22),
                  Colors.black.withOpacity(0.34),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
          Positioned(
            left: AuraSpace.s18,
            bottom: AuraSpace.s18,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AuraSpace.s14,
                vertical: AuraSpace.s10,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.34),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.10)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cover',
                    style: AuraText.muted.copyWith(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.78),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _coverUrl == null ? 'Set the surface behind your presence' : 'Current cover in use',
                    style: AuraText.body.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: AuraSpace.s14,
            right: AuraSpace.s14,
            child: Wrap(
              spacing: AuraSpace.s8,
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
            color: AuraSurface.page,
            boxShadow: [
              BoxShadow(
                blurRadius: 18,
                offset: const Offset(0, 8),
                color: Colors.black.withOpacity(0.22),
              ),
            ],
          ),
          padding: const EdgeInsets.all(6),
          child: CircleAvatar(
            radius: 52,
            backgroundColor: AuraSurface.card,
            backgroundImage: avatarProvider,
            child: avatarProvider == null
                ? Text(
                    _initials,
                    style: AuraText.title.copyWith(
                      fontSize: 30,
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
            color: AuraSurface.card,
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
                child: Text(
                  _uploadingAvatar ? 'Uploading...' : 'Change photo',
                  style: AuraText.body,
                ),
              ),
              if ((_avatarUrl ?? '').isNotEmpty)
                PopupMenuItem<String>(
                  value: 'remove',
                  child: Text(
                    'Remove photo',
                    style: AuraText.body,
                  ),
                ),
            ],
            child: Container(
              height: 36,
              width: 36,
              decoration: BoxDecoration(
                color: AuraSurface.ink,
                shape: BoxShape.circle,
                border: Border.all(color: AuraSurface.page, width: 2),
              ),
              child: const Icon(
                Icons.camera_alt_outlined,
                size: 17,
                color: Colors.black,
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
        AuraTextBlock(
          _displayName,
          textAlign: TextAlign.center,
          style: AuraText.title.copyWith(
            fontSize: 30,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (_handle.trim().isNotEmpty) ...[
          const SizedBox(height: AuraSpace.s6),
          Text(
            '@${_handle.trim()}',
            textAlign: TextAlign.center,
            style: AuraText.muted.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        if (_bio.isNotEmpty) ...[
          const SizedBox(height: AuraSpace.s12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: AuraTextBlock(
              _bio,
              textAlign: TextAlign.center,
              style: AuraText.body.copyWith(height: 1.45),
            ),
          ),
        ],
        if (_location.isNotEmpty || _website.isNotEmpty) ...[
          const SizedBox(height: AuraSpace.s12),
          Wrap(
            spacing: AuraSpace.s12,
            runSpacing: AuraSpace.s8,
            alignment: WrapAlignment.center,
            children: [
              if (_location.isNotEmpty)
                _previewChip(label: _location),
              if (_website.isNotEmpty)
                _previewChip(label: _website),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildIdentityBlock() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panelHeader(
            title: 'How you appear',
            subtitle: 'Name and short statement',
          ),
          const SizedBox(height: AuraSpace.s18),
          _buildField(
            label: 'Display name',
            controller: _displayNameController,
            textInputAction: TextInputAction.next,
            maxLines: 1,
          ),
          const SizedBox(height: AuraSpace.s16),
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
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panelHeader(
            title: 'Where you are found',
            subtitle: 'Place and primary site',
          ),
          const SizedBox(height: AuraSpace.s18),
          _buildField(
            label: 'Location',
            controller: _locationController,
            textInputAction: TextInputAction.next,
            maxLines: 1,
          ),
          const SizedBox(height: AuraSpace.s16),
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

  Widget _buildPublicationsBlock() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _panelHeader(
                  title: 'Published record',
                  subtitle: 'Works you want carried into your presence',
                ),
              ),
              _inlineAddButton(
                label: 'Add publication',
                onPressed: _busy ? null : _addPublication,
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s18),
          if (_publications.isEmpty)
            _emptySurface('No publications added')
          else
            Column(
              children: List.generate(_publications.length, (index) {
                final item = _publications[index];
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == _publications.length - 1 ? 0 : AuraSpace.s14,
                  ),
                  child: _entryCard(
                    indexLabel: 'Publication ${index + 1}',
                    onRemove: _busy ? null : () => _removePublicationAt(index),
                    child: Column(
                      children: [
                        _buildField(
                          label: 'Title',
                          controller: item.titleController,
                          textInputAction: TextInputAction.next,
                          maxLines: 1,
                        ),
                        const SizedBox(height: AuraSpace.s14),
                        _buildField(
                          label: 'Link',
                          controller: item.linkController,
                          textInputAction: TextInputAction.next,
                          maxLines: 1,
                        ),
                        const SizedBox(height: AuraSpace.s14),
                        _buildField(
                          label: 'Description',
                          controller: item.descriptionController,
                          textInputAction: TextInputAction.newline,
                          minLines: 3,
                          maxLines: 5,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildLinksBlock() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _panelHeader(
                  title: 'Linked references',
                  subtitle: 'Places that belong beside your name',
                ),
              ),
              _inlineAddButton(
                label: 'Add link',
                onPressed: _busy ? null : _addLink,
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s18),
          if (_links.isEmpty)
            _emptySurface('No links added')
          else
            Column(
              children: List.generate(_links.length, (index) {
                final item = _links[index];
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == _links.length - 1 ? 0 : AuraSpace.s14,
                  ),
                  child: _entryCard(
                    indexLabel: 'Link ${index + 1}',
                    onRemove: _busy ? null : () => _removeLinkAt(index),
                    child: Column(
                      children: [
                        _buildField(
                          label: 'Label',
                          controller: item.labelController,
                          textInputAction: TextInputAction.next,
                          maxLines: 1,
                        ),
                        const SizedBox(height: AuraSpace.s14),
                        _buildField(
                          label: 'URL',
                          controller: item.urlController,
                          textInputAction: TextInputAction.done,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildAccountRecordBlock() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panelHeader(
            title: 'Fixed record',
            subtitle: 'Account fields currently held outside this editor',
          ),
          const SizedBox(height: AuraSpace.s10),
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

  Widget _panel({required Widget child}) {
    return AuraGlassCard(
      padding: const EdgeInsets.all(AuraSpace.s20),
      child: child,
    );
  }

  Widget _panelHeader({required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AuraText.title.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: AuraText.muted.copyWith(fontSize: 13),
        ),
      ],
    );
  }

  Widget _entryCard({
    required String indexLabel,
    required Widget child,
    required VoidCallback? onRemove,
  }) {
    return AuraCard(
      padding: const EdgeInsets.all(AuraSpace.s16),
      child: Column(
        children: [
          Row(
            children: [
              AuraTrustBadge(label: indexLabel, icon: Icons.layers_outlined),
              const Spacer(),
              TextButton.icon(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Remove'),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s8),
          child,
        ],
      ),
    );
  }

  Widget _emptySurface(String label) {
    return AuraCard(
      child: Text(
        label,
        style: AuraText.muted,
      ),
    );
  }

  Widget _inlineAddButton({
    required String label,
    required VoidCallback? onPressed,
  }) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: const Icon(Icons.add, size: 16),
      label: Text(label),
    );
  }

  Widget _previewChip({required String label}) {
    return AuraTrustBadge(
      label: label,
      icon: Icons.link_outlined,
    );
  }

  Widget _recordRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s20,
        vertical: AuraSpace.s16,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: AuraSpace.s16),
          Flexible(
            child: AuraTextBlock(
              value,
              textAlign: TextAlign.right,
              style: AuraText.muted,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
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
          style: AuraText.muted.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AuraSpace.s10),
        TextField(
          controller: controller,
          textInputAction: textInputAction,
          minLines: minLines,
          maxLines: maxLines,
          style: AuraText.body,
          decoration: InputDecoration(
            filled: true,
            fillColor: AuraSurface.card,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.s16,
              vertical: AuraSpace.s16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AuraSurface.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AuraSurface.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AuraSurface.ink, width: 1.1),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return AuraErrorState(
      title: 'Could not save presence',
      body: _errorText ?? '',
    );
  }

  Widget _buildSaveRail() {
    return Positioned(
      left: AuraSpace.s20,
      right: AuraSpace.s20,
      bottom: AuraSpace.s20,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Container(
            decoration: BoxDecoration(
              gradient: AuraGradients.header,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AuraSurface.divider),
              boxShadow: AuraShadows.panel,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.s16,
              vertical: AuraSpace.s14,
            ),
            child: Row(
              children: [
                const AuraTrustBadge(label: 'Unsaved changes', icon: Icons.edit_outlined),
                const Spacer(),
                TextButton(
                  onPressed: _busy ? null : _discardChanges,
                  child: const Text('Discard'),
                ),
                const SizedBox(width: AuraSpace.s8),
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
    return AuraSectionHeader(
      title: text,
    );
  }

  Widget _surfaceActionButton({
    required String label,
    required VoidCallback? onPressed,
  }) {
    return AuraSecondaryButton(label: label, onPressed: onPressed, icon: Icons.swap_horiz_rounded);
  }

  Widget _divider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: AuraSpace.s18),
      color: AuraSurface.divider,
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
    return msg.isNotEmpty ? msg : fallback;
  }
}

class _EditablePublication {
  _EditablePublication({
    String title = '',
    String link = '',
    String description = '',
    required VoidCallback onChanged,
  })  : titleController = TextEditingController(text: title),
        linkController = TextEditingController(text: link),
        descriptionController = TextEditingController(text: description),
        _onChanged = onChanged {
    titleController.addListener(_onChanged);
    linkController.addListener(_onChanged);
    descriptionController.addListener(_onChanged);
  }

  factory _EditablePublication.fromMap(
    Map<String, dynamic> map, {
    required VoidCallback onChanged,
  }) {
    return _EditablePublication(
      title: _firstPresent(map, const ['title', 'name']),
      link: _firstPresent(map, const ['link', 'url', 'href']),
      description: _firstPresent(
        map,
        const ['description', 'summary', 'note'],
      ),
      onChanged: onChanged,
    );
  }

  final TextEditingController titleController;
  final TextEditingController linkController;
  final TextEditingController descriptionController;
  final VoidCallback _onChanged;

  Map<String, dynamic> get normalized {
    final title = titleController.text.trim();
    final link = linkController.text.trim();
    final description = descriptionController.text.trim();

    if (title.isEmpty && link.isEmpty && description.isEmpty) {
      return <String, dynamic>{};
    }

    return {
      'title': title,
      'link': link,
      'description': description,
    };
  }

  void dispose() {
    titleController.removeListener(_onChanged);
    linkController.removeListener(_onChanged);
    descriptionController.removeListener(_onChanged);
    titleController.dispose();
    linkController.dispose();
    descriptionController.dispose();
  }
}

class _EditableLink {
  _EditableLink({
    String label = '',
    String url = '',
    required VoidCallback onChanged,
  })  : labelController = TextEditingController(text: label),
        urlController = TextEditingController(text: url),
        _onChanged = onChanged {
    labelController.addListener(_onChanged);
    urlController.addListener(_onChanged);
  }

  factory _EditableLink.fromMap(
    Map<String, dynamic> map, {
    required VoidCallback onChanged,
  }) {
    return _EditableLink(
      label: _firstPresent(map, const ['label', 'title', 'name']),
      url: _firstPresent(map, const ['url', 'link', 'href']),
      onChanged: onChanged,
    );
  }

  final TextEditingController labelController;
  final TextEditingController urlController;
  final VoidCallback _onChanged;

  Map<String, dynamic> get normalized {
    final label = labelController.text.trim();
    final url = urlController.text.trim();

    if (label.isEmpty && url.isEmpty) {
      return <String, dynamic>{};
    }

    return {
      'label': label,
      'url': url,
    };
  }

  void dispose() {
    labelController.removeListener(_onChanged);
    urlController.removeListener(_onChanged);
    labelController.dispose();
    urlController.dispose();
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

List<Map<String, dynamic>> _extractPublications(Map<String, dynamic> data) {
  final raw = data['publications'];
  return _normalizeObjectList(raw)
      .map((item) => {
            'title': _firstPresent(item, const ['title', 'name']),
            'link': _firstPresent(item, const ['link', 'url', 'href']),
            'description': _firstPresent(
              item,
              const ['description', 'summary', 'note'],
            ),
          })
      .where((item) => item.values.any((value) => value.toString().trim().isNotEmpty))
      .toList();
}

List<Map<String, dynamic>> _extractLinks(Map<String, dynamic> data) {
  final raw = data['links'];
  return _normalizeObjectList(raw)
      .map((item) => {
            'label': _firstPresent(item, const ['label', 'title', 'name']),
            'url': _firstPresent(item, const ['url', 'link', 'href']),
          })
      .where((item) => item.values.any((value) => value.toString().trim().isNotEmpty))
      .toList();
}

List<Map<String, dynamic>> _normalizeObjectList(dynamic raw) {
  if (raw is! List) return const [];

  final out = <Map<String, dynamic>>[];
  for (final item in raw) {
    if (item is Map<String, dynamic>) {
      out.add(item);
    } else if (item is Map) {
      out.add(Map<String, dynamic>.from(item));
    }
  }
  return out;
}

String _signatureForCollection(List<Map<String, dynamic>> items) {
  final normalized = items
      .map(
        (item) => item.map(
          (key, value) => MapEntry(key, value.toString().trim()),
        ),
      )
      .toList();
  return normalized.toString();
}


String _firstPresent(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = (map[key] ?? '').toString().trim();
    if (value.isNotEmpty) return value;
  }
  return '';
}
