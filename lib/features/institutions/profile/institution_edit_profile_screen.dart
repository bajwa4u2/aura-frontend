import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/attachments/aura_media_upload.dart';
import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../shared/media/profile_media_editor.dart';
import '../data/institutions_repository.dart';

class InstitutionEditProfileScreen extends ConsumerStatefulWidget {
  const InstitutionEditProfileScreen({super.key});

  @override
  ConsumerState<InstitutionEditProfileScreen> createState() =>
      _InstitutionEditProfileScreenState();
}

class _InstitutionEditProfileScreenState
    extends ConsumerState<InstitutionEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // ── Section 1: Basic identity ───────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _taglineCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  // ── Section 2: Branding ─────────────────────────────���────────────────────────
  final _picker = ImagePicker();
  String? _logoUrl;
  String? _coverUrl;
  bool _uploadingLogo = false;
  bool _uploadingCover = false;

  // ── Section 3: Public presence ───────────────────────────────────────────────
  final _websiteCtrl = TextEditingController();
  final _publicEmailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();

  // ── Section 4: Social links ──────────────────────────────────────────────────
  final _linkedinCtrl = TextEditingController();
  final _xCtrl = TextEditingController();
  final _facebookCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _youtubeCtrl = TextEditingController();

  // ── Section 5: Mission / representation ─────────────────────────────────────
  final _missionCtrl = TextEditingController();
  final _servicesCtrl = TextEditingController();
  final _audienceCtrl = TextEditingController();
  final _foundedYearCtrl = TextEditingController();

  bool _loaded = false;
  bool _saving = false;
  String? _error;
  String? _successMessage;

  // Hard caps required for the rebuild.
  static const int _kNameMax = 120;
  static const int _kTaglineMax = 160;
  static const int _kDescMax = 2000;

  // Image upload limits.
  static const int _kLogoMaxBytes = 2 * 1024 * 1024; // 2 MB
  static const int _kCoverMaxBytes = 4 * 1024 * 1024; // 4 MB
  static const Set<String> _kImageMimeWhitelist = {
    'image/jpeg',
    'image/png',
    'image/webp',
  };

  @override
  void initState() {
    super.initState();
    // Live counters: rebuild whenever name/tagline/description change so
    // the helper labels reflect the current input length.
    _nameCtrl.addListener(_onTextChanged);
    _taglineCtrl.addListener(_onTextChanged);
    _descCtrl.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onTextChanged);
    _taglineCtrl.removeListener(_onTextChanged);
    _descCtrl.removeListener(_onTextChanged);
    for (final c in _allControllers) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _exceedsLimits {
    return _nameCtrl.text.trim().length > _kNameMax ||
        _taglineCtrl.text.trim().length > _kTaglineMax ||
        _descCtrl.text.trim().length > _kDescMax;
  }

  List<TextEditingController> get _allControllers => [
        _nameCtrl, _taglineCtrl, _descCtrl, _categoryCtrl, _locationCtrl,
        _websiteCtrl, _publicEmailCtrl, _phoneCtrl, _addressCtrl,
        _cityCtrl, _regionCtrl, _countryCtrl,
        _linkedinCtrl, _xCtrl, _facebookCtrl, _instagramCtrl, _youtubeCtrl,
        _missionCtrl, _servicesCtrl, _audienceCtrl, _foundedYearCtrl,
      ];

  void _populate(Map<String, dynamic> inst) {
    if (_loaded) return;
    _loaded = true;

    String s(List<String> keys) {
      for (final k in keys) {
        final v = inst[k]?.toString().trim() ?? '';
        if (v.isNotEmpty) return v;
      }
      return '';
    }

    _nameCtrl.text = s(['name', 'displayName', 'organizationName']);
    _taglineCtrl.text = s(['tagline']);
    _descCtrl.text = s(['description', 'bio', 'summary']);
    _categoryCtrl.text = s(['category', 'type', 'institutionType']);
    _locationCtrl.text = s(['location', 'city']);
    _logoUrl = inst['logoUrl']?.toString().trim().isNotEmpty == true
        ? inst['logoUrl'].toString().trim()
        : (inst['avatarUrl']?.toString().trim().isNotEmpty == true
            ? inst['avatarUrl'].toString().trim()
            : null);
    _coverUrl = inst['coverUrl']?.toString().trim().isNotEmpty == true
        ? inst['coverUrl'].toString().trim()
        : (inst['bannerUrl']?.toString().trim().isNotEmpty == true
            ? inst['bannerUrl'].toString().trim()
            : null);
    _websiteCtrl.text = s(['website', 'websiteUrl']);
    _publicEmailCtrl.text = s(['publicEmail', 'contactEmail']);
    _phoneCtrl.text = s(['phone', 'phoneNumber']);
    _addressCtrl.text = s(['address']);
    _cityCtrl.text = s(['city']);
    _regionCtrl.text = s(['region', 'state']);
    _countryCtrl.text = s(['country']);
    _linkedinCtrl.text = s(['linkedinUrl', 'linkedin']);
    _xCtrl.text = s(['xUrl', 'twitterUrl', 'twitter']);
    _facebookCtrl.text = s(['facebookUrl', 'facebook']);
    _instagramCtrl.text = s(['instagramUrl', 'instagram']);
    _youtubeCtrl.text = s(['youtubeUrl', 'youtube']);
    _missionCtrl.text = s(['mission']);
    _servicesCtrl.text = s(['services']);
    _audienceCtrl.text = s(['audience']);
    final fy = inst['foundedYear'];
    if (fy != null) _foundedYearCtrl.text = fy.toString();
  }

  Future<void> _save(String institutionId) async {
    if (!_formKey.currentState!.validate()) return;

    // Hard-block submit when any tightened-limit field exceeds its cap.
    if (_exceedsLimits) {
      setState(() {
        _error = 'Some fields exceed character limits. Trim before saving.';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _successMessage = null;
    });

    try {
      final repo = ref.read(institutionsRepositoryProvider);

      final fields = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'tagline': _taglineCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'category': _categoryCtrl.text.trim(),
        'location': _locationCtrl.text.trim(),
        if (_logoUrl != null) 'logoUrl': _logoUrl,
        if (_coverUrl != null) 'coverUrl': _coverUrl,
        'website': _websiteCtrl.text.trim(),
        'publicEmail': _publicEmailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'region': _regionCtrl.text.trim(),
        'country': _countryCtrl.text.trim(),
        'linkedinUrl': _linkedinCtrl.text.trim(),
        'xUrl': _xCtrl.text.trim(),
        'facebookUrl': _facebookCtrl.text.trim(),
        'instagramUrl': _instagramCtrl.text.trim(),
        'youtubeUrl': _youtubeCtrl.text.trim(),
        'mission': _missionCtrl.text.trim(),
        'services': _servicesCtrl.text.trim(),
        'audience': _audienceCtrl.text.trim(),
        if (_foundedYearCtrl.text.trim().isNotEmpty)
          'foundedYear': int.tryParse(_foundedYearCtrl.text.trim()),
      };

      await repo.updateInstitutionProfile(institutionId, fields);

      ref.invalidate(institutionAccessProvider);

      setState(() {
        _saving = false;
        _successMessage = 'Profile saved successfully.';
      });
    } catch (e) {
      String msg = 'Could not save profile.';
      final raw = e.toString();
      // Try to extract backend message from DioException response
      final match = RegExp(r'"message"\s*:\s*"([^"]+)"').firstMatch(raw);
      if (match != null) {
        msg = match.group(1) ?? msg;
      } else if (raw.length < 200) {
        msg = raw.replaceFirst('Exception: ', '');
      }
      setState(() {
        _saving = false;
        _error = msg;
      });
    }
  }

  bool get _busy => _saving || _uploadingLogo || _uploadingCover;

  Future<void> _pickLogo() => _pickAndUploadImage(isLogo: true);
  Future<void> _pickCover() => _pickAndUploadImage(isLogo: false);

  /// "Edit current" — open the editor against the existing media URL so
  /// the user can pan/zoom + re-save without re-picking a file.
  Future<void> _editCurrentLogo() => _editFromCurrentUrl(isLogo: true);
  Future<void> _editCurrentCover() => _editFromCurrentUrl(isLogo: false);

  Future<void> _editFromCurrentUrl({required bool isLogo}) async {
    if (_busy) return;
    final url = (isLogo ? _logoUrl : _coverUrl)?.trim() ?? '';
    if (url.isEmpty) return;

    final cropped = await ProfileMediaEditor.openFromUrl(
      context,
      imageUrl: url,
      config: isLogo
          ? ProfileMediaEditorConfig.institutionLogo
          : ProfileMediaEditorConfig.institutionCover,
    );
    if (cropped == null || !mounted) return;

    setState(() {
      _error = null;
      if (isLogo) {
        _uploadingLogo = true;
      } else {
        _uploadingCover = true;
      }
    });

    try {
      final outW = isLogo
          ? ProfileMediaEditorConfig.institutionLogo.outputWidth
          : ProfileMediaEditorConfig.institutionCover.outputWidth;
      final outH = isLogo
          ? ProfileMediaEditorConfig.institutionLogo.outputHeight
          : ProfileMediaEditorConfig.institutionCover.outputHeight;
      final result = await uploadAuraMedia(
        dio: ref.read(dioProvider),
        bytes: cropped,
        fileName: isLogo ? 'logo-edit.png' : 'cover-edit.png',
        mimeType: 'image/png',
        kind: 'IMAGE',
        source: 'UPLOAD',
        width: outW,
        height: outH,
        metadataPatch: <String, dynamic>{
          'width': outW,
          'height': outH,
          'editDisclosure': true,
        },
      );
      final newUrl = result.url.trim();
      if (newUrl.isEmpty) throw Exception('Uploaded image URL missing.');
      if (!mounted) return;
      setState(() {
        if (isLogo) {
          _logoUrl = newUrl;
        } else {
          _coverUrl = newUrl;
        }
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _error = _readDioError(e, 'Could not upload image.'));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not upload image.');
    } finally {
      if (mounted) {
        setState(() {
          if (isLogo) {
            _uploadingLogo = false;
          } else {
            _uploadingCover = false;
          }
        });
      }
    }
  }

  Future<void> _pickAndUploadImage({required bool isLogo}) async {
    if (_busy) return;
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );
    if (file == null) return;

    final pickedBytes = await file.readAsBytes();

    // MIME + size validation runs before the editor so the user doesn't
    // tune a crop on a file we'll reject anyway.
    final mimeType = file.mimeType ?? _inferMime(file.name);
    if (pickedBytes.isEmpty) {
      if (mounted) setState(() => _error = 'Image file is empty.');
      return;
    }
    if (!_kImageMimeWhitelist.contains(mimeType.toLowerCase())) {
      if (mounted) {
        setState(() => _error =
            'Unsupported image type. Use JPEG, PNG, or WebP.');
      }
      return;
    }
    final maxBytes = isLogo ? _kLogoMaxBytes : _kCoverMaxBytes;
    if (pickedBytes.length > maxBytes) {
      final mb = (maxBytes / (1024 * 1024)).toStringAsFixed(0);
      if (mounted) {
        setState(() => _error = isLogo
            ? 'Logo must be $mb MB or smaller.'
            : 'Cover must be $mb MB or smaller.');
      }
      return;
    }

    if (!mounted) return;

    // Phase 5.2: route every picked file through the shared editor so the
    // user can frame the crop deliberately. Editor returns PNG bytes at the
    // mode's output resolution — or null on cancel.
    final cropped = await ProfileMediaEditor.open(
      context,
      imageBytes: pickedBytes,
      config: isLogo
          ? ProfileMediaEditorConfig.institutionLogo
          : ProfileMediaEditorConfig.institutionCover,
    );
    if (cropped == null || !mounted) return;

    setState(() {
      _error = null;
      if (isLogo) {
        _uploadingLogo = true;
      } else {
        _uploadingCover = true;
      }
    });

    try {
      final outW = isLogo
          ? ProfileMediaEditorConfig.institutionLogo.outputWidth
          : ProfileMediaEditorConfig.institutionCover.outputWidth;
      final outH = isLogo
          ? ProfileMediaEditorConfig.institutionLogo.outputHeight
          : ProfileMediaEditorConfig.institutionCover.outputHeight;
      final base = file.name.contains('.')
          ? file.name.substring(0, file.name.lastIndexOf('.'))
          : file.name;
      final processedName = '$base-${isLogo ? 'logo' : 'cover'}.png';

      final result = await uploadAuraMedia(
        dio: ref.read(dioProvider),
        bytes: cropped,
        fileName: processedName,
        mimeType: 'image/png',
        kind: 'IMAGE',
        source: 'UPLOAD',
        width: outW,
        height: outH,
        metadataPatch: <String, dynamic>{
          'width': outW,
          'height': outH,
          'editDisclosure': true,
        },
      );
      final url = result.url.trim();
      if (url.isEmpty) throw Exception('Uploaded image URL missing.');
      if (!mounted) return;
      setState(() {
        if (isLogo) {
          _logoUrl = url;
        } else {
          _coverUrl = url;
        }
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _readDioError(e, 'Could not upload image.');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not upload image.');
    } finally {
      if (mounted) {
        setState(() {
          if (isLogo) {
            _uploadingLogo = false;
          } else {
            _uploadingCover = false;
          }
        });
      }
    }
  }

  String _inferMime(String name) {
    final ext = name.split('.').last.toLowerCase();
    if (ext == 'png') return 'image/png';
    if (ext == 'webp') return 'image/webp';
    return 'image/jpeg';
  }

  String _readDioError(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      final m = data['message'].toString().trim();
      if (m.isNotEmpty) return m;
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final accessAsync = ref.watch(institutionAccessProvider);
    final identity = ref.watch(institutionIdentityProvider);

    return AuraScaffold(
      showHeader: false,
      body: accessAsync.when(
        loading: () => const AuraLoadingState(message: 'Loading…'),
        error: (e, _) => ListView(
          padding: _pagePad,
          children: [AuraErrorState(title: 'Unavailable', body: '$e')],
        ),
        data: (access) {
          if (identity == null || !identity.isAdmin) {
            return ListView(
              padding: _pagePad,
              children: [
                AuraErrorState(
                  title: 'Access denied',
                  body: 'Only institution admins can edit the profile.',
                  action: AuraSecondaryButton(
                    label: 'Back to profile',
                    onPressed: () => context.go('/institution/profile'),
                  ),
                ),
              ],
            );
          }

          final inst = access.institution ??
              (access.membership?['institution'] is Map
                  ? Map<String, dynamic>.from(
                      access.membership!['institution'] as Map,
                    )
                  : null);

          if (inst != null) _populate(inst);

          return _EditBody(
            formKey: _formKey,
            saving: _saving,
            error: _error,
            successMessage: _successMessage,
            nameCtrl: _nameCtrl,
            taglineCtrl: _taglineCtrl,
            descCtrl: _descCtrl,
            categoryCtrl: _categoryCtrl,
            locationCtrl: _locationCtrl,
            logoUrl: _logoUrl,
            coverUrl: _coverUrl,
            uploadingLogo: _uploadingLogo,
            uploadingCover: _uploadingCover,
            onPickLogo: _pickLogo,
            onPickCover: _pickCover,
            onEditCurrentLogo: _editCurrentLogo,
            onEditCurrentCover: _editCurrentCover,
            onRemoveLogo: () => setState(() => _logoUrl = null),
            onRemoveCover: () => setState(() => _coverUrl = null),
            websiteCtrl: _websiteCtrl,
            publicEmailCtrl: _publicEmailCtrl,
            phoneCtrl: _phoneCtrl,
            addressCtrl: _addressCtrl,
            cityCtrl: _cityCtrl,
            regionCtrl: _regionCtrl,
            countryCtrl: _countryCtrl,
            linkedinCtrl: _linkedinCtrl,
            xCtrl: _xCtrl,
            facebookCtrl: _facebookCtrl,
            instagramCtrl: _instagramCtrl,
            youtubeCtrl: _youtubeCtrl,
            missionCtrl: _missionCtrl,
            servicesCtrl: _servicesCtrl,
            audienceCtrl: _audienceCtrl,
            foundedYearCtrl: _foundedYearCtrl,
            onSave: () => _save(identity.id),
            onCancel: () => context.go('/institution/profile'),
          );
        },
      ),
    );
  }

  static const _pagePad = EdgeInsets.fromLTRB(
    AuraSpace.s16, AuraSpace.s20, AuraSpace.s16, AuraSpace.s32,
  );
}

// ── Edit body ──────────────────────────────────────────────────────────────────

class _EditBody extends StatelessWidget {
  const _EditBody({
    required this.formKey,
    required this.saving,
    required this.error,
    required this.successMessage,
    required this.nameCtrl,
    required this.taglineCtrl,
    required this.descCtrl,
    required this.categoryCtrl,
    required this.locationCtrl,
    required this.logoUrl,
    required this.coverUrl,
    required this.uploadingLogo,
    required this.uploadingCover,
    required this.onPickLogo,
    required this.onPickCover,
    required this.onEditCurrentLogo,
    required this.onEditCurrentCover,
    required this.onRemoveLogo,
    required this.onRemoveCover,
    required this.websiteCtrl,
    required this.publicEmailCtrl,
    required this.phoneCtrl,
    required this.addressCtrl,
    required this.cityCtrl,
    required this.regionCtrl,
    required this.countryCtrl,
    required this.linkedinCtrl,
    required this.xCtrl,
    required this.facebookCtrl,
    required this.instagramCtrl,
    required this.youtubeCtrl,
    required this.missionCtrl,
    required this.servicesCtrl,
    required this.audienceCtrl,
    required this.foundedYearCtrl,
    required this.onSave,
    required this.onCancel,
  });

  final GlobalKey<FormState> formKey;
  final bool saving;
  final String? error;
  final String? successMessage;
  final TextEditingController nameCtrl;
  final TextEditingController taglineCtrl;
  final TextEditingController descCtrl;
  final TextEditingController categoryCtrl;
  final TextEditingController locationCtrl;
  final String? logoUrl;
  final String? coverUrl;
  final bool uploadingLogo;
  final bool uploadingCover;
  final VoidCallback onPickLogo;
  final VoidCallback onPickCover;
  final VoidCallback onEditCurrentLogo;
  final VoidCallback onEditCurrentCover;
  final VoidCallback onRemoveLogo;
  final VoidCallback onRemoveCover;
  final TextEditingController websiteCtrl;
  final TextEditingController publicEmailCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController addressCtrl;
  final TextEditingController cityCtrl;
  final TextEditingController regionCtrl;
  final TextEditingController countryCtrl;
  final TextEditingController linkedinCtrl;
  final TextEditingController xCtrl;
  final TextEditingController facebookCtrl;
  final TextEditingController instagramCtrl;
  final TextEditingController youtubeCtrl;
  final TextEditingController missionCtrl;
  final TextEditingController servicesCtrl;
  final TextEditingController audienceCtrl;
  final TextEditingController foundedYearCtrl;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  static const Color _accent = Color(0xFF0D9488);

  InputDecoration _dec(String hint, {String? prefix}) => InputDecoration(
        hintText: hint,
        prefixText: prefix,
        hintStyle: AuraText.body.copyWith(color: AuraSurface.faint),
        filled: true,
        fillColor: AuraSurface.subtle,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AuraRadius.md),
          borderSide: const BorderSide(color: AuraSurface.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AuraRadius.md),
          borderSide: const BorderSide(color: AuraSurface.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AuraRadius.md),
          borderSide: const BorderSide(color: _accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AuraRadius.md),
          borderSide: const BorderSide(color: AuraSurface.dangerInk, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AuraRadius.md),
          borderSide: const BorderSide(color: AuraSurface.dangerInk, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s14,
          vertical: AuraSpace.s12,
        ),
      );

  String? _urlValidator(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final uri = Uri.tryParse(v.trim());
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      return 'Enter a valid URL (http:// or https://)';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.s16, AuraSpace.s20, AuraSpace.s16, AuraSpace.s32,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Edit institution profile', style: AuraText.headline),
                  const SizedBox(height: AuraSpace.s6),
                  Text(
                    'Update your institution\'s public-facing identity, contact, and representation.',
                    style: AuraText.body.copyWith(color: AuraSurface.muted, height: 1.5),
                  ),
                  const SizedBox(height: AuraSpace.s24),

                  if (error != null) ...[
                    _Banner(
                      message: error!,
                      color: AuraSurface.dangerBg,
                      textColor: AuraSurface.dangerInk,
                      icon: Icons.error_outline_rounded,
                    ),
                    const SizedBox(height: AuraSpace.s16),
                  ],

                  if (successMessage != null) ...[
                    _Banner(
                      message: successMessage!,
                      color: AuraSurface.goodBg,
                      textColor: AuraSurface.goodInk,
                      icon: Icons.check_circle_outline_rounded,
                    ),
                    const SizedBox(height: AuraSpace.s16),
                  ],

                  // ── 1. Basic identity ─────────────────────────────────────
                  const _SectionHeader(label: '1. BASIC IDENTITY'),
                  _CountedField(
                    label: 'Display name *',
                    controller: nameCtrl,
                    maxChars: 120,
                    child: TextFormField(
                      controller: nameCtrl,
                      style: AuraText.body,
                      decoration: _dec('Institution name'),
                      maxLength: 120,
                      buildCounter: _emptyCounter,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Name is required.';
                        }
                        if (v.trim().length > 120) return 'Max 120 characters.';
                        return null;
                      },
                    ),
                  ),
                  _CountedField(
                    label: 'Tagline',
                    controller: taglineCtrl,
                    maxChars: 160,
                    child: TextFormField(
                      controller: taglineCtrl,
                      style: AuraText.body,
                      decoration: _dec('Short tagline or motto…'),
                      maxLength: 160,
                      buildCounter: _emptyCounter,
                      validator: (v) {
                        if (v == null) return null;
                        if (v.trim().length > 160) return 'Max 160 characters.';
                        return null;
                      },
                    ),
                  ),
                  _CountedField(
                    label: 'About',
                    controller: descCtrl,
                    maxChars: 2000,
                    child: TextFormField(
                      controller: descCtrl,
                      style: AuraText.body,
                      decoration: _dec('Describe your institution…'),
                      minLines: 3,
                      maxLines: 8,
                      maxLength: 2000,
                      buildCounter: _emptyCounter,
                      validator: (v) {
                        if (v == null) return null;
                        if (v.trim().length > 2000) {
                          return 'Max 2000 characters.';
                        }
                        return null;
                      },
                    ),
                  ),
                  _TwoCol(
                    left: _Field(
                      label: 'Category / type',
                      child: TextFormField(
                        controller: categoryCtrl,
                        style: AuraText.body,
                        decoration: _dec('e.g. University, NGO…'),
                        maxLength: 128,
                      ),
                    ),
                    right: _Field(
                      label: 'Location',
                      child: TextFormField(
                        controller: locationCtrl,
                        style: AuraText.body,
                        decoration: _dec('City or region…'),
                        maxLength: 128,
                      ),
                    ),
                  ),

                  const SizedBox(height: AuraSpace.s20),

                  // ── 2. Branding ───────────────────────────────────────────
                  const _SectionHeader(label: '2. BRANDING'),
                  _Field(
                    label: 'Logo',
                    child: _MediaUploadControl(
                      imageUrl: logoUrl,
                      uploading: uploadingLogo,
                      aspectRatio: 1,
                      hint: 'Square image · at least 200×200 px · PNG, JPEG, or WebP',
                      onPick: onPickLogo,
                      onEditCurrent: onEditCurrentLogo,
                      onRemove: onRemoveLogo,
                    ),
                  ),
                  _Field(
                    label: 'Cover / banner',
                    child: _MediaUploadControl(
                      imageUrl: coverUrl,
                      uploading: uploadingCover,
                      aspectRatio: 4,
                      hint: 'Wide image · 1600×400 px or 4:1 ratio · PNG, JPEG, or WebP',
                      onPick: onPickCover,
                      onEditCurrent: onEditCurrentCover,
                      onRemove: onRemoveCover,
                    ),
                  ),

                  const SizedBox(height: AuraSpace.s20),

                  // ── 3. Public presence ────────────────────────────────────
                  const _SectionHeader(label: '3. PUBLIC PRESENCE'),
                  _Field(
                    label: 'Website',
                    child: TextFormField(
                      controller: websiteCtrl,
                      style: AuraText.body,
                      decoration: _dec('https://…'),
                      keyboardType: TextInputType.url,
                      validator: _urlValidator,
                      maxLength: 2048,
                    ),
                  ),
                  _TwoCol(
                    left: _Field(
                      label: 'Public email',
                      child: TextFormField(
                        controller: publicEmailCtrl,
                        style: AuraText.body,
                        decoration: _dec('contact@institution.edu'),
                        keyboardType: TextInputType.emailAddress,
                        maxLength: 256,
                      ),
                    ),
                    right: _Field(
                      label: 'Phone',
                      child: TextFormField(
                        controller: phoneCtrl,
                        style: AuraText.body,
                        decoration: _dec('+1 (555) 000-0000'),
                        keyboardType: TextInputType.phone,
                        maxLength: 50,
                      ),
                    ),
                  ),
                  _Field(
                    label: 'Address',
                    child: TextFormField(
                      controller: addressCtrl,
                      style: AuraText.body,
                      decoration: _dec('Street address…'),
                      maxLength: 500,
                    ),
                  ),
                  _ThreeCol(
                    a: _Field(
                      label: 'City',
                      child: TextFormField(
                        controller: cityCtrl,
                        style: AuraText.body,
                        decoration: _dec('City'),
                        maxLength: 128,
                      ),
                    ),
                    b: _Field(
                      label: 'Region / state',
                      child: TextFormField(
                        controller: regionCtrl,
                        style: AuraText.body,
                        decoration: _dec('State / province'),
                        maxLength: 128,
                      ),
                    ),
                    c: _Field(
                      label: 'Country',
                      child: TextFormField(
                        controller: countryCtrl,
                        style: AuraText.body,
                        decoration: _dec('Country'),
                        maxLength: 128,
                      ),
                    ),
                  ),

                  const SizedBox(height: AuraSpace.s20),

                  // ── 4. Social links ───────────────────────────────────────
                  const _SectionHeader(label: '4. SOCIAL LINKS'),
                  _TwoCol(
                    left: _Field(
                      label: 'LinkedIn',
                      child: TextFormField(
                        controller: linkedinCtrl,
                        style: AuraText.body,
                        decoration: _dec('https://linkedin.com/in/…'),
                        keyboardType: TextInputType.url,
                        validator: _urlValidator,
                        maxLength: 2048,
                      ),
                    ),
                    right: _Field(
                      label: 'X / Twitter',
                      child: TextFormField(
                        controller: xCtrl,
                        style: AuraText.body,
                        decoration: _dec('https://x.com/…'),
                        keyboardType: TextInputType.url,
                        validator: _urlValidator,
                        maxLength: 2048,
                      ),
                    ),
                  ),
                  _TwoCol(
                    left: _Field(
                      label: 'Facebook',
                      child: TextFormField(
                        controller: facebookCtrl,
                        style: AuraText.body,
                        decoration: _dec('https://facebook.com/…'),
                        keyboardType: TextInputType.url,
                        validator: _urlValidator,
                        maxLength: 2048,
                      ),
                    ),
                    right: _Field(
                      label: 'Instagram',
                      child: TextFormField(
                        controller: instagramCtrl,
                        style: AuraText.body,
                        decoration: _dec('https://instagram.com/…'),
                        keyboardType: TextInputType.url,
                        validator: _urlValidator,
                        maxLength: 2048,
                      ),
                    ),
                  ),
                  _Field(
                    label: 'YouTube',
                    child: TextFormField(
                      controller: youtubeCtrl,
                      style: AuraText.body,
                      decoration: _dec('https://youtube.com/@…'),
                      keyboardType: TextInputType.url,
                      validator: _urlValidator,
                      maxLength: 2048,
                    ),
                  ),

                  const SizedBox(height: AuraSpace.s20),

                  // ── 5. Mission / representation ───────────────────────────
                  const _SectionHeader(label: '5. MISSION & REPRESENTATION'),
                  _Field(
                    label: 'Mission',
                    child: TextFormField(
                      controller: missionCtrl,
                      style: AuraText.body,
                      decoration: _dec('Your institution\'s mission statement…'),
                      minLines: 2,
                      maxLines: 6,
                      maxLength: 2000,
                    ),
                  ),
                  _Field(
                    label: 'Services / programs',
                    child: TextFormField(
                      controller: servicesCtrl,
                      style: AuraText.body,
                      decoration: _dec('Key services or academic programs…'),
                      minLines: 2,
                      maxLines: 6,
                      maxLength: 2000,
                    ),
                  ),
                  _TwoCol(
                    left: _Field(
                      label: 'Target audience',
                      child: TextFormField(
                        controller: audienceCtrl,
                        style: AuraText.body,
                        decoration: _dec('e.g. Graduate students, researchers…'),
                        maxLength: 1000,
                      ),
                    ),
                    right: _Field(
                      label: 'Founded year',
                      child: TextFormField(
                        controller: foundedYearCtrl,
                        style: AuraText.body,
                        decoration: _dec('e.g. 1970'),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final n = int.tryParse(v.trim());
                          if (n == null || n < 1800 || n > 2100) {
                            return 'Enter a valid year (1800–2100)';
                          }
                          return null;
                        },
                        maxLength: 4,
                      ),
                    ),
                  ),

                  const SizedBox(height: AuraSpace.s28),

                  // ── Save / cancel ─────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: AuraPrimaryButton(
                          label: saving ? 'Saving…' : 'Save changes',
                          icon: saving ? null : Icons.check_rounded,
                          onPressed: saving ? null : onSave,
                        ),
                      ),
                      const SizedBox(width: AuraSpace.s10),
                      AuraSecondaryButton(label: 'Cancel', onPressed: onCancel),
                    ],
                  ),

                  const SizedBox(height: AuraSpace.s20),
                  _managedFieldsNote(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _managedFieldsNote() {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s14),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 14, color: AuraSurface.muted),
          const SizedBox(width: AuraSpace.s8),
          Expanded(
            child: Text(
              'Slug, domain, jurisdiction, and verification status are managed through separate workflows (Domains screen and admin review).',
              style: AuraText.small.copyWith(color: AuraSurface.faint, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Media upload control ──────────────────────────────────────────────────────

class _MediaUploadControl extends StatelessWidget {
  const _MediaUploadControl({
    required this.imageUrl,
    required this.uploading,
    required this.aspectRatio,
    required this.hint,
    required this.onPick,
    required this.onEditCurrent,
    required this.onRemove,
  });

  final String? imageUrl;
  final bool uploading;

  /// 1 for square logo, 4 for wide cover banner.
  final double aspectRatio;
  final String hint;
  final VoidCallback onPick;
  /// Phase 5.2: open the existing image in the unified editor (no re-pick).
  final VoidCallback onEditCurrent;
  final VoidCallback onRemove;

  // Hard caps for the preview surface so an uploaded image cannot bleed into
  // page content.
  static const double _kLogoMaxSize = 160;
  static const double _kCoverMaxWidth = 600;
  static const double _kCoverMaxHeight = 150;

  bool get _isLogo => aspectRatio == 1;

  BoxConstraints get _previewConstraints {
    if (_isLogo) {
      return const BoxConstraints(
        maxWidth: _kLogoMaxSize,
        maxHeight: _kLogoMaxSize,
      );
    }
    return const BoxConstraints(
      maxWidth: _kCoverMaxWidth,
      maxHeight: _kCoverMaxHeight,
    );
  }

  Widget _previewBox({required Widget child}) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: _previewConstraints,
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AuraRadius.md),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasImage) ...[
          _previewBox(
            child: Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AuraSurface.elevated,
                child: const Center(
                  child: Icon(Icons.broken_image_outlined,
                      color: AuraSurface.faint),
                ),
              ),
            ),
          ),
          const SizedBox(height: AuraSpace.s10),
        ],
        if (!hasImage && !uploading)
          _previewBox(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AuraSurface.subtle,
                border: Border.all(color: AuraSurface.divider),
              ),
              child: Center(
                child: Icon(
                  _isLogo ? Icons.image_outlined : Icons.panorama_outlined,
                  color: AuraSurface.faint,
                  size: 28,
                ),
              ),
            ),
          ),
        if (uploading) ...[
          _previewBox(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AuraSurface.subtle,
                border: Border.all(color: AuraSurface.divider),
              ),
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: AuraSpace.s8),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: uploading ? null : onPick,
              icon: Icon(hasImage ? Icons.swap_horiz_rounded : Icons.upload_rounded, size: 16),
              label: Text(uploading
                  ? 'Uploading…'
                  : hasImage
                      ? 'Replace'
                      : 'Upload'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                textStyle: AuraText.small.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (hasImage) ...[
              const SizedBox(width: AuraSpace.s8),
              OutlinedButton.icon(
                onPressed: uploading ? null : onEditCurrent,
                icon: const Icon(Icons.crop_rounded, size: 16),
                label: const Text('Edit current'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  textStyle:
                      AuraText.small.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: AuraSpace.s8),
              TextButton(
                onPressed: uploading ? null : onRemove,
                child: Text(
                  'Remove',
                  style: AuraText.small.copyWith(
                    color: AuraSurface.dangerInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AuraSpace.s6),
        Text(
          hint,
          style: AuraText.small.copyWith(color: AuraSurface.faint, height: 1.4),
        ),
      ],
    );
  }
}

// ── Layout helpers ──────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  static const Color _accent = Color(0xFF0D9488);
  static const Color _accentSoft = Color(0x1E0D9488);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s16),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s12,
          vertical: AuraSpace.s8,
        ),
        decoration: BoxDecoration(
          color: _accentSoft,
          borderRadius: BorderRadius.circular(AuraRadius.md),
          border: Border.all(color: _accent.withValues(alpha: 0.2)),
        ),
        child: Text(
          label,
          style: AuraText.micro.copyWith(
            color: const Color(0xFF5EEAD4),
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AuraText.micro.copyWith(
              color: AuraSurface.faint,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: AuraSpace.s8),
          child,
        ],
      ),
    );
  }
}

class _TwoCol extends StatelessWidget {
  const _TwoCol({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 480) {
          return Column(children: [left, right]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: AuraSpace.s14),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class _ThreeCol extends StatelessWidget {
  const _ThreeCol({required this.a, required this.b, required this.c});

  final Widget a;
  final Widget b;
  final Widget c;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 480) {
          return Column(children: [a, b, c]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: a),
            const SizedBox(width: AuraSpace.s14),
            Expanded(child: b),
            const SizedBox(width: AuraSpace.s14),
            Expanded(child: c),
          ],
        );
      },
    );
  }
}

/// Counted version of [_Field] — wraps a TextFormField with a live `used/max`
/// counter under the label. Counter color goes red within the last 10% and
/// bold red when at limit.
class _CountedField extends StatelessWidget {
  const _CountedField({
    required this.label,
    required this.controller,
    required this.maxChars,
    required this.child,
  });

  final String label;
  final TextEditingController controller;
  final int maxChars;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final used = controller.text.length;
    final ratio = maxChars == 0 ? 0.0 : used / maxChars;
    final atLimit = used >= maxChars;
    final danger = atLimit || ratio >= 0.9;
    final color = danger ? AuraSurface.dangerInk : AuraSurface.faint;
    final fontWeight = atLimit ? FontWeight.w800 : FontWeight.w600;

    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AuraText.micro.copyWith(
                    color: AuraSurface.faint,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              Text(
                '$used/$maxChars',
                style: AuraText.micro.copyWith(
                  color: color,
                  fontWeight: fontWeight,
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s8),
          child,
        ],
      ),
    );
  }
}

Widget? _emptyCounter(
  BuildContext context, {
  required int currentLength,
  required int? maxLength,
  required bool isFocused,
}) =>
    const SizedBox.shrink();

class _Banner extends StatelessWidget {
  const _Banner({
    required this.message,
    required this.color,
    required this.textColor,
    required this.icon,
  });

  final String message;
  final Color color;
  final Color textColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: textColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: AuraSpace.s10),
          Expanded(
            child: Text(
              message,
              style: AuraText.small.copyWith(color: textColor, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
