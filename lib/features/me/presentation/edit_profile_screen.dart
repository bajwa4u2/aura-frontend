import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/attachments/aura_media_upload.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/aura_text_block.dart';
import '../../../shared/media/profile_media_editor.dart';
import 'edit_profile/edit_profile_widgets.dart';

enum _EditSection { identity, coverAndAvatar, presence, publications, links, account }

class _SectionItem {
  const _SectionItem(this.section, this.label, this.icon);
  final _EditSection section;
  final String label;
  final IconData icon;
}

const _kSections = <_SectionItem>[
  _SectionItem(_EditSection.identity, 'Identity', Icons.person_outline_rounded),
  _SectionItem(_EditSection.coverAndAvatar, 'Cover & Avatar', Icons.photo_outlined),
  _SectionItem(_EditSection.presence, 'Presence', Icons.location_on_outlined),
  _SectionItem(_EditSection.publications, 'Publications', Icons.auto_stories_outlined),
  _SectionItem(_EditSection.links, 'Links', Icons.link_rounded),
  _SectionItem(_EditSection.account, 'Account', Icons.lock_outline_rounded),
];

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

  _EditSection _activeSection = _EditSection.identity;
  bool _showPreview = false;

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
  List<Map<String, dynamic>> _initialPublicationsData =
      const <Map<String, dynamic>>[];
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
        _publicationsSignature !=
            _signatureForCollection(_initialPublicationsData) ||
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

    final parts = source
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();

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

  String get _linksSignature =>
      _signatureForCollection(_normalizedLinksPayload());

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
        _initialLocation = [
          city,
          country,
        ].where((e) => e.isNotEmpty).join(', ');
      }

      _initialWebsite = _readString(data, const [
        'website',
        'websiteUrl',
        'site',
        'url',
      ]);
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
            .map(
              (item) =>
                  _EditablePublication.fromMap(item, onChanged: _onChanged),
            )
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

  /// "Edit current" — open the editor against the existing avatar URL so the
  /// user can pan/zoom + re-save without re-picking a file.
  Future<void> _editCurrentAvatar() async {
    final url = (_avatarUrl ?? '').trim();
    if (_busy || url.isEmpty) return;
    await _editFromUrl(url, isAvatar: true);
  }

  /// "Edit current" — same flow for the cover image.
  Future<void> _editCurrentCover() async {
    final url = (_coverUrl ?? '').trim();
    if (_busy || url.isEmpty) return;
    await _editFromUrl(url, isAvatar: false);
  }

  Future<void> _editFromUrl(String url, {required bool isAvatar}) async {
    final cropped = await ProfileMediaEditor.openFromUrl(
      context,
      imageUrl: url,
      config: isAvatar
          ? ProfileMediaEditorConfig.memberAvatar
          : ProfileMediaEditorConfig.memberCover,
    );
    if (cropped == null || !mounted) return;

    setState(() {
      _errorText = null;
      if (isAvatar) {
        _uploadingAvatar = true;
      } else {
        _uploadingCover = true;
      }
    });

    try {
      final uploadedUrl = await _uploadProcessedBytes(
        bytes: cropped,
        fileName: isAvatar ? 'avatar-edit.png' : 'cover-edit.png',
        outputW: isAvatar
            ? ProfileMediaEditorConfig.memberAvatar.outputWidth
            : ProfileMediaEditorConfig.memberCover.outputWidth,
        outputH: isAvatar
            ? ProfileMediaEditorConfig.memberAvatar.outputHeight
            : ProfileMediaEditorConfig.memberCover.outputHeight,
      );
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
      setState(() => _errorText = 'Could not upload image.');
    } finally {
      if (mounted) {
        setState(() {
          if (isAvatar) {
            _uploadingAvatar = false;
          } else {
            _uploadingCover = false;
          }
        });
      }
    }
  }

  Future<void> _pickAndUploadImage({required bool isAvatar}) async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );
    if (file == null) return;

    final pickedBytes = await file.readAsBytes();
    if (!mounted) return;

    // Route every picked file through the shared ProfileMediaEditor so
    // the user can pan + zoom before save. The editor returns the cropped
    // PNG bytes (or null on cancel).
    final cropped = await ProfileMediaEditor.open(
      context,
      imageBytes: pickedBytes,
      config: isAvatar
          ? ProfileMediaEditorConfig.memberAvatar
          : ProfileMediaEditorConfig.memberCover,
    );
    if (cropped == null || !mounted) return;

    setState(() {
      _errorText = null;
      if (isAvatar) {
        _uploadingAvatar = true;
      } else {
        _uploadingCover = true;
      }
    });

    try {
      final uploadedUrl = await _uploadProcessedBytes(
        bytes: cropped,
        fileName: _processedFileName(file.name, isAvatar),
        outputW: isAvatar
            ? ProfileMediaEditorConfig.memberAvatar.outputWidth
            : ProfileMediaEditorConfig.memberCover.outputWidth,
        outputH: isAvatar
            ? ProfileMediaEditorConfig.memberAvatar.outputHeight
            : ProfileMediaEditorConfig.memberCover.outputHeight,
      );

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
      if (mounted) {
        setState(() {
          if (isAvatar) {
            _uploadingAvatar = false;
          } else {
            _uploadingCover = false;
          }
        });
      }
    }
  }

  String _processedFileName(String original, bool isAvatar) {
    // Editor outputs PNG; replace the extension so the upload signs the
    // correct content-type and the CDN serves it back as PNG.
    final base = original.contains('.')
        ? original.substring(0, original.lastIndexOf('.'))
        : original;
    final tag = isAvatar ? 'avatar' : 'cover';
    return '$base-$tag.png';
  }

  Future<String> _uploadProcessedBytes({
    required Uint8List bytes,
    required String fileName,
    required int outputW,
    required int outputH,
  }) async {
    final result = await uploadAuraMedia(
      dio: ref.read(dioProvider),
      bytes: bytes,
      fileName: fileName,
      mimeType: 'image/png',
      kind: 'IMAGE',
      source: 'UPLOAD',
      width: outputW,
      height: outputH,
      metadataPatch: <String, dynamic>{
        'width': outputW,
        'height': outputH,
        'editDisclosure': true,
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Presence updated')));
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
            .map(
              (item) =>
                  _EditablePublication.fromMap(item, onChanged: _onChanged),
            )
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
      _links = [..._links, _EditableLink(onChanged: _onChanged)];
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
        title: 'Edit profile',
        body: const Center(child: AuraLoadingState(message: 'Loading profile…')),
      );
    }

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showDiscardDialog();
      },
      child: AuraScaffold(
        title: 'Edit profile',
        body: LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth >= 900
              ? _buildWideLayout()
              : _buildNarrowLayout(),
        ),
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
            Image(image: coverProvider, fit: BoxFit.cover)
          else
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AuraSurface.elevated,
                    AuraSurface.card,
                    Color(0xFF171B22),
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
                  Colors.black.withValues(alpha: 0.10),
                  Colors.black.withValues(alpha: 0.22),
                  Colors.black.withValues(alpha: 0.34),
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
                color: Colors.black.withValues(alpha: 0.34),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cover',
                    style: AuraText.muted.copyWith(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.78),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _coverUrl == null
                        ? 'Set the surface behind your presence'
                        : 'Current cover in use',
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
            // Phase 5.2 completion: dark glass control cluster sits directly
            // on top of the cover image. Each button is a self-contained
            // dark pill with white text, a hairline white border, and a
            // strong shadow — readable on bright OR dark imagery without
            // depending on the cover's own gradient overlay.
            child: Wrap(
              spacing: AuraSpace.s8,
              children: [
                _glassActionButton(
                  label: _uploadingCover ? 'Uploading…' : 'Change cover',
                  icon: Icons.upload_rounded,
                  onPressed: _busy ? null : _pickCover,
                ),
                if ((_coverUrl ?? '').isNotEmpty)
                  _glassActionButton(
                    label: 'Edit current',
                    icon: Icons.crop_rounded,
                    onPressed: _busy ? null : _editCurrentCover,
                  ),
                if ((_coverUrl ?? '').isNotEmpty)
                  _glassActionButton(
                    label: 'Remove',
                    icon: Icons.delete_outline_rounded,
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
                color: Colors.black.withValues(alpha: 0.22),
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
              } else if (value == 'edit') {
                _editCurrentAvatar();
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
                const PopupMenuItem<String>(
                  value: 'edit',
                  child: Text('Edit current', style: AuraText.body),
                ),
              if ((_avatarUrl ?? '').isNotEmpty)
                const PopupMenuItem<String>(
                  value: 'remove',
                  child: Text('Remove photo', style: AuraText.body),
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
                color: AuraSurface.page,
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
              if (_location.isNotEmpty) EditProfilePreviewChip(label: _location),
              if (_website.isNotEmpty) EditProfilePreviewChip(label: _website),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildIdentityBlock() {
    return EditProfilePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EditProfilePanelHeader(
            title: 'How you appear',
            subtitle: 'Name and short statement',
          ),
          const SizedBox(height: AuraSpace.s18),
          EditProfileField(
            label: 'Display name',
            controller: _displayNameController,
            textInputAction: TextInputAction.next,
            maxLines: 1,
          ),
          const SizedBox(height: AuraSpace.s16),
          EditProfileField(
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
    return EditProfilePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EditProfilePanelHeader(
            title: 'Where you are found',
            subtitle: 'Place and primary site',
          ),
          const SizedBox(height: AuraSpace.s18),
          EditProfileField(
            label: 'Location',
            controller: _locationController,
            textInputAction: TextInputAction.next,
            maxLines: 1,
          ),
          const SizedBox(height: AuraSpace.s16),
          EditProfileField(
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
    return EditProfilePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: EditProfilePanelHeader(
                  title: 'Published record',
                  subtitle: 'Works you want carried into your presence',
                ),
              ),
              EditProfileInlineAddButton(
                label: 'Add publication',
                onPressed: _busy ? null : _addPublication,
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s18),
          if (_publications.isEmpty)
            const EditProfileEmptySurface('No publications added')
          else
            Column(
              children: List.generate(_publications.length, (index) {
                final item = _publications[index];
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == _publications.length - 1
                        ? 0
                        : AuraSpace.s14,
                  ),
                  child: EditProfileEntryCard(
                    indexLabel: 'Publication ${index + 1}',
                    onRemove: _busy ? null : () => _removePublicationAt(index),
                    child: Column(
                      children: [
                        EditProfileField(
                          label: 'Title',
                          controller: item.titleController,
                          textInputAction: TextInputAction.next,
                          maxLines: 1,
                        ),
                        const SizedBox(height: AuraSpace.s14),
                        EditProfileField(
                          label: 'Link',
                          controller: item.linkController,
                          textInputAction: TextInputAction.next,
                          maxLines: 1,
                        ),
                        const SizedBox(height: AuraSpace.s14),
                        EditProfileField(
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
    return EditProfilePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: EditProfilePanelHeader(
                  title: 'Linked references',
                  subtitle: 'Places that belong beside your name',
                ),
              ),
              EditProfileInlineAddButton(
                label: 'Add link',
                onPressed: _busy ? null : _addLink,
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s18),
          if (_links.isEmpty)
            const EditProfileEmptySurface('No links added')
          else
            Column(
              children: List.generate(_links.length, (index) {
                final item = _links[index];
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == _links.length - 1 ? 0 : AuraSpace.s14,
                  ),
                  child: EditProfileEntryCard(
                    indexLabel: 'Link ${index + 1}',
                    onRemove: _busy ? null : () => _removeLinkAt(index),
                    child: Column(
                      children: [
                        EditProfileField(
                          label: 'Label',
                          controller: item.labelController,
                          textInputAction: TextInputAction.next,
                          maxLines: 1,
                        ),
                        const SizedBox(height: AuraSpace.s14),
                        EditProfileField(
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
    return EditProfilePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EditProfilePanelHeader(
            title: 'Fixed record',
            subtitle: 'Account fields currently held outside this editor',
          ),
          const SizedBox(height: AuraSpace.s10),
          EditProfileRecordRow('Handle', _handle.isEmpty ? '—' : '@$_handle'),
          _divider(),
          EditProfileRecordRow('Email', _email.isEmpty ? '—' : _email),
          _divider(),
          EditProfileRecordRow('First name', _firstName.isEmpty ? '—' : _firstName),
          _divider(),
          EditProfileRecordRow('Last name', _lastName.isEmpty ? '—' : _lastName),
        ],
      ),
    );
  }


  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AuraSurface.coRose.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AuraSurface.coRose.withValues(alpha: 0.35),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s16,
        vertical: AuraSpace.s14,
      ),
      child: AuraTextBlock(
        _errorText ?? '',
        style: AuraText.body.copyWith(color: AuraSurface.coRose),
      ),
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
              color: AuraSurface.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AuraSurface.divider),
              boxShadow: [
                BoxShadow(
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                  color: Colors.black.withValues(alpha: 0.18),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.s16,
              vertical: AuraSpace.s14,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _saving ? 'Saving...' : 'Unsaved changes',
                    style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                AuraGhostButton(
                  label: 'Discard',
                  onPressed: _busy ? null : _discardChanges,
                ),
                const SizedBox(width: AuraSpace.s8),
                AuraPrimaryButton(
                  label: _saving ? 'Saving…' : 'Save',
                  onPressed: _busy ? null : _save,
                  icon: _saving ? null : Icons.check_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDiscardDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AuraSurface.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AuraRadius.card),
        ),
        title: const Text('Discard changes?', style: AuraText.title),
        content: Text(
          'You have unsaved changes. Going back will discard them.',
          style: AuraText.body.copyWith(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Keep editing',
              style: AuraText.body.copyWith(color: AuraSurface.muted),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _discardChanges();
              Navigator.of(context).pop();
            },
            child: Text(
              'Discard',
              style: AuraText.body.copyWith(color: AuraSurface.coRose),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideLayout() {
    return Stack(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 220, child: _buildLeftNav()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AuraSpace.s24,
                  AuraSpace.s24,
                  AuraSpace.s24,
                  100,
                ),
                children: [
                  if (_errorText != null) ...[
                    _buildErrorBanner(),
                    const SizedBox(height: AuraSpace.s20),
                  ],
                  _buildSectionEditor(),
                ],
              ),
            ),
            SizedBox(width: 260, child: _buildPreviewPanel()),
          ],
        ),
        if (_hasChanges) _buildSaveRail(),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return Stack(
      children: [
        Column(
          children: [
            _buildSectionChipRow(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AuraSpace.s16,
                  AuraSpace.s16,
                  AuraSpace.s16,
                  100,
                ),
                children: [
                  if (_showPreview) ...[
                    _buildPreviewCard(),
                    const SizedBox(height: AuraSpace.s20),
                  ],
                  if (_errorText != null) ...[
                    _buildErrorBanner(),
                    const SizedBox(height: AuraSpace.s20),
                  ],
                  EditProfileSectionLabel(
                    _kSections
                        .firstWhere((s) => s.section == _activeSection)
                        .label,
                  ),
                  const SizedBox(height: AuraSpace.s14),
                  _buildSectionEditor(),
                ],
              ),
            ),
          ],
        ),
        if (_hasChanges) _buildSaveRail(),
      ],
    );
  }

  Widget _buildLeftNav() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: AuraSurface.divider)),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: AuraSpace.s20),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.s16,
              0,
              AuraSpace.s16,
              AuraSpace.s12,
            ),
            child: Text(
              'SECTION',
              style: AuraText.muted.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          ..._kSections.map(_buildNavItem),
          const SizedBox(height: AuraSpace.s20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s12),
            child: AuraPrimaryButton(
              label: _saving ? 'Saving…' : 'Save changes',
              onPressed: (_busy || !_hasChanges) ? null : _save,
              icon: Icons.check_rounded,
            ),
          ),
          if (_hasChanges)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AuraSpace.s12,
                AuraSpace.s8,
                AuraSpace.s12,
                0,
              ),
              child: AuraGhostButton(
                label: 'Discard',
                onPressed: _busy ? null : _discardChanges,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNavItem(_SectionItem item) {
    final isActive = _activeSection == item.section;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() => _activeSection = item.section),
        child: Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s8,
            vertical: AuraSpace.s2,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s12,
            vertical: AuraSpace.s12,
          ),
          decoration: BoxDecoration(
            color: isActive
                ? AuraSurface.accentSoft
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AuraRadius.md),
          ),
          child: Row(
            children: [
              Icon(
                item.icon,
                size: 18,
                color: isActive ? AuraSurface.accentText : AuraSurface.muted,
              ),
              const SizedBox(width: AuraSpace.s10),
              Expanded(
                child: Text(
                  item.label,
                  style: AuraText.body.copyWith(
                    color: isActive ? AuraSurface.accentText : AuraSurface.ink,
                    fontWeight:
                        isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionChipRow() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AuraSurface.divider)),
      ),
      // Wrap (not horizontal scroll) so narrow viewports never hide the
      // trailing edit-profile sections behind a silent overflow edge.
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s16,
          vertical: AuraSpace.s10,
        ),
        child: Wrap(
          spacing: AuraSpace.s8,
          runSpacing: AuraSpace.s8,
          children: [
            ..._kSections.map((item) {
              final isActive = _activeSection == item.section;
              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => setState(() => _activeSection = item.section),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AuraSpace.s12,
                      vertical: AuraSpace.s8,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AuraSurface.accentSoft
                          : AuraSurface.card,
                      borderRadius: BorderRadius.circular(AuraRadius.pill),
                      border: Border.all(
                        color: isActive
                            ? AuraSurface.accentText.withValues(alpha: 0.45)
                              : AuraSurface.divider,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item.icon,
                            size: 14,
                            color: isActive
                                ? AuraSurface.accentText
                                : AuraSurface.muted,
                          ),
                          const SizedBox(width: AuraSpace.s6),
                          Text(
                            item.label,
                            style: AuraText.small.copyWith(
                              color: isActive
                                  ? AuraSurface.accentText
                                  : AuraSurface.ink,
                              fontWeight: isActive
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
            }),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => setState(() => _showPreview = !_showPreview),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AuraSpace.s12,
                    vertical: AuraSpace.s8,
                  ),
                  decoration: BoxDecoration(
                    color: _showPreview
                        ? AuraSurface.elevated
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AuraRadius.pill),
                    border: Border.all(color: AuraSurface.divider),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.preview_outlined,
                        size: 14,
                        color: AuraSurface.muted,
                      ),
                      SizedBox(width: AuraSpace.s6),
                      Text('Preview', style: AuraText.small),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionEditor() {
    switch (_activeSection) {
      case _EditSection.identity:
        return _buildIdentityBlock();
      case _EditSection.coverAndAvatar:
        return _buildCoverAndAvatarSection();
      case _EditSection.presence:
        return _buildPresenceBlock();
      case _EditSection.publications:
        return _buildPublicationsBlock();
      case _EditSection.links:
        return _buildLinksBlock();
      case _EditSection.account:
        return _buildAccountRecordBlock();
    }
  }

  Widget _buildCoverAndAvatarSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCoverSurface(),
        const SizedBox(height: AuraSpace.s24),
        Center(child: _buildAvatar()),
      ],
    );
  }

  Widget _buildPreviewPanel() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AuraSurface.divider)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(AuraSpace.s16),
        children: [
          Text(
            'PREVIEW',
            style: AuraText.muted.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: AuraSpace.s12),
          _buildPreviewCard(),
        ],
      ),
    );
  }

  Widget _buildPreviewCard() {
    final coverProvider = _imageProviderFromUrl(_coverUrl);
    final avatarProvider = _imageProviderFromUrl(_avatarUrl);
    return Container(
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                height: 80,
                width: double.infinity,
                child: coverProvider != null
                    ? Image(image: coverProvider, fit: BoxFit.cover)
                    : const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AuraSurface.elevated, AuraSurface.card],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
              ),
              Positioned(
                bottom: -26,
                left: AuraSpace.s16,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AuraSurface.card, width: 3),
                  ),
                  child: CircleAvatar(
                    radius: 26,
                    backgroundColor: AuraSurface.elevated,
                    backgroundImage: avatarProvider,
                    child: avatarProvider == null
                        ? Text(
                            _initials,
                            style: AuraText.label.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 38),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.s16,
              0,
              AuraSpace.s16,
              AuraSpace.s16,
            ),
            child: _buildIdentityPreview(),
          ),
        ],
      ),
    );
  }

  /// Dark-glass action pill used for cover overlays. Unlike a white surface
  /// button, this stays readable on **any** cover image — bright sky, dark
  /// scene, busy collage. The combination of `black @ 0.65` background,
  /// a hairline white border at `0.12` alpha, and a strong shadow means
  /// the button never dissolves into the underlying photo.
  Widget _glassActionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    final disabled = onPressed == null;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AuraRadius.pill),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s12,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: disabled ? 0.4 : 0.65),
            borderRadius: BorderRadius.circular(AuraRadius.pill),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: Colors.white.withValues(alpha: disabled ? 0.6 : 1),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AuraText.body.copyWith(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: disabled ? 0.6 : 1),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
  }) : titleController = TextEditingController(text: title),
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
      description: _firstPresent(map, const ['description', 'summary', 'note']),
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

    return {'title': title, 'link': link, 'description': description};
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
  }) : labelController = TextEditingController(text: label),
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

    return {'label': label, 'url': url};
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

List<Map<String, dynamic>> _extractPublications(Map<String, dynamic> data) {
  final raw = data['publications'];
  return _normalizeObjectList(raw)
      .map(
        (item) => {
          'title': _firstPresent(item, const ['title', 'name']),
          'link': _firstPresent(item, const ['link', 'url', 'href']),
          'description': _firstPresent(item, const [
            'description',
            'summary',
            'note',
          ]),
        },
      )
      .where(
        (item) =>
            item.values.any((value) => value.toString().trim().isNotEmpty),
      )
      .toList();
}

List<Map<String, dynamic>> _extractLinks(Map<String, dynamic> data) {
  final raw = data['links'];
  return _normalizeObjectList(raw)
      .map(
        (item) => {
          'label': _firstPresent(item, const ['label', 'title', 'name']),
          'url': _firstPresent(item, const ['url', 'link', 'href']),
        },
      )
      .where(
        (item) =>
            item.values.any((value) => value.toString().trim().isNotEmpty),
      )
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
        (item) =>
            item.map((key, value) => MapEntry(key, value.toString().trim())),
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
