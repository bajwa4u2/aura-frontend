import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/attachments/aura_media_upload.dart';
import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/institutions/institution_paths.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../shared/media/profile_media_editor.dart';
import '../../institution_ontology/models.dart';
import '../../institution_ontology/providers.dart';
import '../data/institutions_repository.dart';
import '../ui/institution_ds.dart';

/// Phase 6.6b — Institution Edit Profile / Identity Studio.
///
/// The form contract is unchanged: same controllers, same validators, same
/// save endpoint. Everything on top of that is rewritten on the institution
/// design system primitives so this screen feels like one cohesive editor
/// rather than five stacked admin forms.
///
/// Layout:
///   1. Title + identity-led live preview (mirrors what the public profile
///      will look like as the user types).
///   2. Five `InsCard`-wrapped sections — Basic / About / Contact /
///      Representation / Social — each introduced by an `InsSection`.
///   3. Sticky save bar pinned to the bottom of the viewport so the save
///      action is always one click away.
class InstitutionEditProfileScreen extends ConsumerStatefulWidget {
  const InstitutionEditProfileScreen({super.key});

  @override
  ConsumerState<InstitutionEditProfileScreen> createState() =>
      _InstitutionEditProfileScreenState();
}

class _InstitutionEditProfileScreenState
    extends ConsumerState<InstitutionEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // ── Basic identity ──────────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _taglineCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  // ── About ───────────────────────────────────────────────────────────────
  final _descCtrl = TextEditingController();

  // ── Branding ────────────────────────────────────────────────────────────
  final _picker = ImagePicker();
  String? _logoUrl;
  String? _coverUrl;
  bool _uploadingLogo = false;
  bool _uploadingCover = false;

  // ── Contact ─────────────────────────────────────────────────────────────
  final _websiteCtrl = TextEditingController();
  final _publicEmailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();

  // ── Representation ──────────────────────────────────────────────────────
  final _missionCtrl = TextEditingController();
  final _servicesCtrl = TextEditingController();
  final _audienceCtrl = TextEditingController();
  final _foundedYearCtrl = TextEditingController();

  // ── Social ──────────────────────────────────────────────────────────────
  final _linkedinCtrl = TextEditingController();
  final _xCtrl = TextEditingController();
  final _facebookCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _youtubeCtrl = TextEditingController();

  // ── Ontology (Phase 1B) ─────────────────────────────────────────────────
  // Curated class / type / domain-tag selection. Wire tokens stored;
  // labels resolved against `institutionOntologyProvider` at render time.
  String? _institutionClass;
  String? _institutionType;
  final List<String> _domainTags = [];

  /// Public mutator for the ontology editor section (avoids external
  /// callers reaching for `setState` on this State directly).
  void setInstitutionClass(String? cls) {
    setState(() {
      _institutionClass = cls;
      // Clearing the class also clears the type — server reconciles
      // the same way; mirroring locally keeps the UI honest.
      _institutionType = null;
    });
  }

  void setInstitutionType(String? typeId) {
    setState(() => _institutionType = typeId);
  }

  void toggleDomainTag(String id) {
    setState(() {
      if (_domainTags.contains(id)) {
        _domainTags.remove(id);
      } else {
        _domainTags.add(id);
      }
    });
  }

  bool _loaded = false;
  bool _saving = false;
  String? _error;
  String? _successMessage;

  static const int _kNameMax = 120;
  static const int _kTaglineMax = 160;
  static const int _kDescMax = 2000;

  static const int _kLogoMaxBytes = 2 * 1024 * 1024;
  static const int _kCoverMaxBytes = 4 * 1024 * 1024;
  static const Set<String> _kImageMimeWhitelist = {
    'image/jpeg',
    'image/png',
    'image/webp',
  };

  @override
  void initState() {
    super.initState();
    // Live counters + live preview rebuild whenever name/tagline/description
    // change so the preview tile and counters reflect the current input.
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

    // Ontology hydrate — wire tokens are kept as-is; the selectors
    // resolve display labels via `institutionOntologyProvider`.
    final cls = inst['institutionClass']?.toString().trim() ?? '';
    final typ = inst['institutionType']?.toString().trim() ?? '';
    _institutionClass = cls.isEmpty ? null : cls;
    _institutionType = typ.isEmpty ? null : typ;
    final rawTags = inst['domainTags'];
    if (rawTags is List) {
      _domainTags
        ..clear()
        ..addAll(rawTags
            .map((e) => e?.toString().trim() ?? '')
            .where((s) => s.isNotEmpty));
    }
  }

  // ── Save ────────────────────────────────────────────────────────────────

  Future<void> _save(String institutionId) async {
    if (!_formKey.currentState!.validate()) return;

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
        // Ontology — null clears the value on the server, '' is treated
        // as null by the service-layer trim. We always send these three
        // fields so partial PATCH reconciliation has correct inputs.
        'institutionClass': _institutionClass ?? '',
        'institutionType': _institutionType ?? '',
        'domainTags': List<String>.from(_domainTags),
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

  void clearLogo() => setState(() => _logoUrl = null);
  void clearCover() => setState(() => _coverUrl = null);

  Future<void> _pickLogo() => _pickAndUploadImage(isLogo: true);
  Future<void> _pickCover() => _pickAndUploadImage(isLogo: false);
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
    final mimeType = file.mimeType ?? _inferMime(file.name);
    if (pickedBytes.isEmpty) {
      if (mounted) setState(() => _error = 'Image file is empty.');
      return;
    }
    if (!_kImageMimeWhitelist.contains(mimeType.toLowerCase())) {
      if (mounted) {
        setState(() =>
            _error = 'Unsupported image type. Use JPEG, PNG, or WebP.');
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

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final accessAsync = ref.watch(institutionAccessProvider);
    final identity = ref.watch(institutionIdentityProvider);

    return AuraScaffold(
      showHeader: false,
      body: accessAsync.when(
        loading: () =>
            const AuraLoadingState(message: 'Loading identity studio…'),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(InsSpacing.screenHPad),
          child: AuraErrorState(title: 'Unavailable', body: '$e'),
        ),
        data: (access) {
          if (identity == null || !identity.isAdmin) {
            return Padding(
              padding: const EdgeInsets.all(InsSpacing.screenHPad),
              child: AuraErrorState(
                title: 'Access denied',
                body: 'Only institution admins can edit the profile.',
                action: AuraSecondaryButton(
                  label: 'Back to profile',
                  onPressed: () => context.go(
                    (identity?.id.isNotEmpty ?? false)
                        ? institutionWorkspacePath(
                            identity!.id, InstitutionSection.profile)
                        : '/institution/dashboard',
                  ),
                ),
              ),
            );
          }

          final inst = access.institution ??
              (access.membership?['institution'] is Map
                  ? Map<String, dynamic>.from(
                      access.membership!['institution'] as Map,
                    )
                  : null);
          if (inst != null) _populate(inst);

          return _StudioBody(state: this, institutionId: identity.id);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Studio body — composes the live preview, sectioned form, and sticky save bar
// ─────────────────────────────────────────────────────────────────────────────

class _StudioBody extends StatelessWidget {
  const _StudioBody({required this.state, required this.institutionId});

  final _InstitutionEditProfileScreenState state;
  final String institutionId;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Form(
          key: state._formKey,
          child: InsScreen(
            children: [
              // ── Mode header ───────────────────────────────────────────
              InsModeHeader(
                title: 'Identity studio',
                description:
                    'A guided editor for everything the public sees about this institution.',
                primaryAction: AuraSecondaryButton(
                  label: 'Cancel',
                  icon: Icons.close_rounded,
                  onPressed: () => context.go(
                    institutionId.isNotEmpty
                        ? institutionWorkspacePath(
                            institutionId, InstitutionSection.profile)
                        : '/institution/dashboard',
                  ),
                ),
              ),
              const SizedBox(height: AuraSpace.s20),

              // ── Live preview ──────────────────────────────────────────
              _LivePreviewCard(
                name: state._nameCtrl.text,
                tagline: state._taglineCtrl.text,
                logoUrl: state._logoUrl,
                coverUrl: state._coverUrl,
                location: state._locationCtrl.text,
                category: state._categoryCtrl.text,
              ),

              const InsSectionGap(),

              // ── Banners ───────────────────────────────────────────────
              if (state._error != null) ...[
                _ToneBanner(
                  tone: InsTone.danger,
                  message: state._error!,
                ),
                const SizedBox(height: AuraSpace.s14),
              ],
              if (state._successMessage != null) ...[
                _ToneBanner(
                  tone: InsTone.ok,
                  message: state._successMessage!,
                ),
                const SizedBox(height: AuraSpace.s14),
              ],

              // ── 1. Basic identity ─────────────────────────────────────
              InsSection(
                eyebrow: 'Section 1',
                title: 'Basic identity',
                helper:
                    'Display name, tagline, category, and the institution’s public media.',
                child: InsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StudioCountedField(
                        label: 'Display name',
                        required: true,
                        controller: state._nameCtrl,
                        maxChars: _InstitutionEditProfileScreenState._kNameMax,
                        child: _StudioTextField(
                          controller: state._nameCtrl,
                          hint: 'Institution name',
                          maxLength:
                              _InstitutionEditProfileScreenState._kNameMax,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Name is required.';
                            }
                            if (v.trim().length >
                                _InstitutionEditProfileScreenState
                                    ._kNameMax) {
                              return 'Max ${_InstitutionEditProfileScreenState._kNameMax} characters.';
                            }
                            return null;
                          },
                        ),
                      ),
                      _StudioCountedField(
                        label: 'Tagline',
                        controller: state._taglineCtrl,
                        maxChars:
                            _InstitutionEditProfileScreenState._kTaglineMax,
                        helper:
                            'A single line of identity — shown beside the name.',
                        child: _StudioTextField(
                          controller: state._taglineCtrl,
                          hint: 'Short tagline or motto…',
                          maxLength: _InstitutionEditProfileScreenState
                              ._kTaglineMax,
                          validator: (v) {
                            if (v == null) return null;
                            if (v.trim().length >
                                _InstitutionEditProfileScreenState
                                    ._kTaglineMax) {
                              return 'Max ${_InstitutionEditProfileScreenState._kTaglineMax} characters.';
                            }
                            return null;
                          },
                        ),
                      ),
                      _StudioTwoCol(
                        left: _StudioField(
                          label: 'Category / type',
                          child: _StudioTextField(
                            controller: state._categoryCtrl,
                            hint: 'e.g. University · NGO · Foundation',
                            maxLength: 128,
                          ),
                        ),
                        right: _StudioField(
                          label: 'Headquarters',
                          child: _StudioTextField(
                            controller: state._locationCtrl,
                            hint: 'City or region',
                            maxLength: 128,
                          ),
                        ),
                      ),
                      const SizedBox(height: AuraSpace.s10),
                      // ── Global Institution Ontology (Phase 1B) ────────────
                      // Curated Class / Type / Domain tag selectors. The
                      // legacy free-text `category` field above is preserved
                      // during the transition; this section is the canonical
                      // classification path.
                      _OntologyEditSection(
                        institutionClass: state._institutionClass,
                        institutionType: state._institutionType,
                        domainTags: state._domainTags,
                        onClassChanged: state.setInstitutionClass,
                        onTypeChanged: state.setInstitutionType,
                        onTagToggled: state.toggleDomainTag,
                      ),
                      const SizedBox(height: AuraSpace.s10),
                      const Divider(height: 1, color: AuraSurface.divider),
                      const SizedBox(height: AuraSpace.s14),
                      _MediaSlot(
                        label: 'Logo',
                        helper:
                            'Square image · at least 200×200 px · PNG, JPEG, or WebP',
                        child: _MediaUploadControl(
                          imageUrl: state._logoUrl,
                          uploading: state._uploadingLogo,
                          aspectRatio: 1,
                          onPick: state._pickLogo,
                          onEditCurrent: state._editCurrentLogo,
                          onRemove: state.clearLogo,
                        ),
                      ),
                      const SizedBox(height: AuraSpace.s14),
                      _MediaSlot(
                        label: 'Cover banner',
                        helper:
                            'Wide image · 4:1 ratio · 1600×400 recommended',
                        child: _MediaUploadControl(
                          imageUrl: state._coverUrl,
                          uploading: state._uploadingCover,
                          aspectRatio: 4,
                          onPick: state._pickCover,
                          onEditCurrent: state._editCurrentCover,
                          onRemove: state.clearCover,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const InsSectionGap(),

              // ── 2. About ──────────────────────────────────────────────
              InsSection(
                eyebrow: 'Section 2',
                title: 'About',
                helper:
                    'A long-form description of the institution. Plain text, will appear on the public profile.',
                child: InsCard(
                  child: _StudioCountedField(
                    label: 'Description',
                    controller: state._descCtrl,
                    maxChars: _InstitutionEditProfileScreenState._kDescMax,
                    child: _StudioTextField(
                      controller: state._descCtrl,
                      hint:
                          'What is this institution, who does it serve, and what does it stand for?',
                      maxLength:
                          _InstitutionEditProfileScreenState._kDescMax,
                      minLines: 4,
                      maxLines: 10,
                      validator: (v) {
                        if (v == null) return null;
                        if (v.trim().length >
                            _InstitutionEditProfileScreenState._kDescMax) {
                          return 'Max ${_InstitutionEditProfileScreenState._kDescMax} characters.';
                        }
                        return null;
                      },
                    ),
                  ),
                ),
              ),

              const InsSectionGap(),

              // ── 3. Contact ────────────────────────────────────────────
              InsSection(
                eyebrow: 'Section 3',
                title: 'Contact',
                helper:
                    'How members of the public can reach this institution off-platform.',
                child: InsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StudioField(
                        label: 'Website',
                        child: _StudioTextField(
                          controller: state._websiteCtrl,
                          hint: 'https://…',
                          keyboardType: TextInputType.url,
                          validator: _urlValidator,
                          maxLength: 2048,
                        ),
                      ),
                      _StudioTwoCol(
                        left: _StudioField(
                          label: 'Public email',
                          child: _StudioTextField(
                            controller: state._publicEmailCtrl,
                            hint: 'contact@institution.edu',
                            keyboardType: TextInputType.emailAddress,
                            maxLength: 256,
                          ),
                        ),
                        right: _StudioField(
                          label: 'Phone',
                          child: _StudioTextField(
                            controller: state._phoneCtrl,
                            hint: '+1 (555) 000-0000',
                            keyboardType: TextInputType.phone,
                            maxLength: 50,
                          ),
                        ),
                      ),
                      _StudioField(
                        label: 'Street address',
                        child: _StudioTextField(
                          controller: state._addressCtrl,
                          hint: 'Street address',
                          maxLength: 500,
                        ),
                      ),
                      _StudioThreeCol(
                        a: _StudioField(
                          label: 'City',
                          child: _StudioTextField(
                            controller: state._cityCtrl,
                            hint: 'City',
                            maxLength: 128,
                          ),
                        ),
                        b: _StudioField(
                          label: 'Region / state',
                          child: _StudioTextField(
                            controller: state._regionCtrl,
                            hint: 'State or province',
                            maxLength: 128,
                          ),
                        ),
                        c: _StudioField(
                          label: 'Country',
                          child: _StudioTextField(
                            controller: state._countryCtrl,
                            hint: 'Country',
                            maxLength: 128,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const InsSectionGap(),

              // ── 4. Representation ─────────────────────────────────────
              InsSection(
                eyebrow: 'Section 4',
                title: 'Representation',
                helper:
                    'Mission, services, audience, and history. The substance behind the identity.',
                child: InsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StudioField(
                        label: 'Mission',
                        child: _StudioTextField(
                          controller: state._missionCtrl,
                          hint: 'What this institution exists to do.',
                          minLines: 2,
                          maxLines: 6,
                          maxLength: 2000,
                        ),
                      ),
                      _StudioField(
                        label: 'Services or programs',
                        child: _StudioTextField(
                          controller: state._servicesCtrl,
                          hint: 'Key services, programs, or offerings.',
                          minLines: 2,
                          maxLines: 6,
                          maxLength: 2000,
                        ),
                      ),
                      _StudioTwoCol(
                        left: _StudioField(
                          label: 'Target audience',
                          child: _StudioTextField(
                            controller: state._audienceCtrl,
                            hint: 'e.g. Researchers, alumni, the public',
                            maxLength: 1000,
                          ),
                        ),
                        right: _StudioField(
                          label: 'Founded year',
                          child: _StudioTextField(
                            controller: state._foundedYearCtrl,
                            hint: 'e.g. 1970',
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return null;
                              final n = int.tryParse(v.trim());
                              if (n == null || n < 1800 || n > 2100) {
                                return 'Enter a valid year (1800–2100)';
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const InsSectionGap(),

              // ── 5. Social ─────────────────────────────────────────────
              InsSection(
                eyebrow: 'Section 5',
                title: 'Social',
                helper:
                    'Optional links to where this institution lives elsewhere on the web.',
                child: InsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StudioTwoCol(
                        left: _SocialField(
                          label: 'LinkedIn',
                          icon: Icons.business_center_outlined,
                          controller: state._linkedinCtrl,
                          hint: 'https://linkedin.com/in/…',
                          validator: _urlValidator,
                        ),
                        right: _SocialField(
                          label: 'X / Twitter',
                          icon: Icons.alternate_email_rounded,
                          controller: state._xCtrl,
                          hint: 'https://x.com/…',
                          validator: _urlValidator,
                        ),
                      ),
                      _StudioTwoCol(
                        left: _SocialField(
                          label: 'Facebook',
                          icon: Icons.facebook_rounded,
                          controller: state._facebookCtrl,
                          hint: 'https://facebook.com/…',
                          validator: _urlValidator,
                        ),
                        right: _SocialField(
                          label: 'Instagram',
                          icon: Icons.camera_alt_outlined,
                          controller: state._instagramCtrl,
                          hint: 'https://instagram.com/…',
                          validator: _urlValidator,
                        ),
                      ),
                      _SocialField(
                        label: 'YouTube',
                        icon: Icons.play_circle_outline_rounded,
                        controller: state._youtubeCtrl,
                        hint: 'https://youtube.com/@…',
                        validator: _urlValidator,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AuraSpace.s24),

              const _ManagedFieldsNote(),

              // Bottom breath — leaves room above the sticky save bar so
              // the last field is never trapped under it.
              const SizedBox(height: 96),
            ],
          ),
        ),
        // Sticky save bar.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _SaveBar(
            saving: state._saving,
            busy: state._busy,
            dirty: true,
            onSave: () => state._save(institutionId),
            onCancel: () => context.go(
              institutionId.isNotEmpty
                  ? institutionWorkspacePath(
                      institutionId, InstitutionSection.profile)
                  : '/institution/dashboard',
            ),
            onPreview: () => context.go(
              institutionId.isNotEmpty
                  ? '${institutionWorkspacePath(institutionId, InstitutionSection.profile)}?preview=1'
                  : '/institution/dashboard',
            ),
          ),
        ),
      ],
    );
  }

  String? _urlValidator(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final uri = Uri.tryParse(v.trim());
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      return 'Enter a valid URL (http:// or https://)';
    }
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live preview — small InsIdentityHeader that updates while editing
// ─────────────────────────────────────────────────────────────────────────────

class _LivePreviewCard extends StatelessWidget {
  const _LivePreviewCard({
    required this.name,
    required this.tagline,
    required this.logoUrl,
    required this.coverUrl,
    required this.location,
    required this.category,
  });

  final String name;
  final String tagline;
  final String? logoUrl;
  final String? coverUrl;
  final String location;
  final String category;

  @override
  Widget build(BuildContext context) {
    final facts = <InsFact>[];
    if (category.trim().isNotEmpty) {
      facts.add(InsFact(icon: Icons.workspaces_outlined, text: category.trim()));
    }
    if (location.trim().isNotEmpty) {
      facts.add(InsFact(icon: Icons.place_outlined, text: location.trim()));
    }

    final hasCover = coverUrl != null && coverUrl!.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Eyebrow.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              InsSpacing.cardPadding,
              InsSpacing.cardPadding,
              InsSpacing.cardPadding,
              0,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.visibility_outlined,
                  size: 14,
                  color: AuraSurface.faint,
                ),
                const SizedBox(width: 6),
                Text(
                  'LIVE PREVIEW',
                  style: AuraText.micro.copyWith(
                    color: AuraSurface.faint,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.9,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          // Cover band.
          if (hasCover)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                InsSpacing.cardPadding,
                AuraSpace.s10,
                InsSpacing.cardPadding,
                0,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AuraRadius.md),
                child: AspectRatio(
                  aspectRatio: 4,
                  child: Image.network(
                    coverUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AuraSurface.subtle,
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(InsSpacing.cardPadding),
            child: InsIdentityHeader(
              name: name.trim().isEmpty ? 'Institution name' : name,
              tagline: tagline.trim().isEmpty ? null : tagline,
              logoUrl: logoUrl,
              facts: facts,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sticky save bar
// ─────────────────────────────────────────────────────────────────────────────

class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.saving,
    required this.busy,
    required this.dirty,
    required this.onSave,
    required this.onCancel,
    required this.onPreview,
  });

  final bool saving;
  final bool busy;
  final bool dirty;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AuraSurface.page.withValues(alpha: 0.96),
        border: const Border(
          top: BorderSide(color: AuraSurface.divider),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44000000),
            blurRadius: 14,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            InsSpacing.screenHPad,
            AuraSpace.s10,
            InsSpacing.screenHPad,
            AuraSpace.s10,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: InsSpacing.contentMaxWidth,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: dirty
                                ? AuraSurface.warnInk
                                : AuraSurface.faint,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            saving
                                ? 'Saving changes…'
                                : (dirty
                                    ? 'You have unsaved changes'
                                    : 'All changes saved'),
                            style: AuraText.small.copyWith(
                              color: AuraSurface.muted,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AuraGhostButton(
                    label: 'Preview',
                    icon: Icons.visibility_outlined,
                    onPressed: busy ? null : onPreview,
                  ),
                  const SizedBox(width: AuraSpace.s8),
                  AuraSecondaryButton(
                    label: 'Cancel',
                    onPressed: busy ? null : onCancel,
                  ),
                  const SizedBox(width: AuraSpace.s8),
                  AuraPrimaryButton(
                    label: saving ? 'Saving…' : 'Save changes',
                    icon: saving ? null : Icons.check_rounded,
                    onPressed: busy ? null : onSave,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Studio form atoms — labels, fields, layout helpers, banners
// ─────────────────────────────────────────────────────────────────────────────

class _StudioField extends StatelessWidget {
  const _StudioField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AuraText.small.copyWith(
              color: AuraSurface.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AuraSpace.s6),
          child,
        ],
      ),
    );
  }
}

class _StudioCountedField extends StatelessWidget {
  const _StudioCountedField({
    required this.label,
    required this.controller,
    required this.maxChars,
    required this.child,
    this.required = false,
    this.helper,
  });

  final String label;
  final TextEditingController controller;
  final int maxChars;
  final Widget child;
  final bool required;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final used = controller.text.length;
    final ratio = maxChars == 0 ? 0.0 : used / maxChars;
    final atLimit = used >= maxChars;
    final danger = atLimit || ratio >= 0.9;
    final color = danger ? AuraSurface.dangerInk : AuraSurface.faint;
    final fontWeight = atLimit ? FontWeight.w800 : FontWeight.w600;

    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      label,
                      style: AuraText.small.copyWith(
                        color: AuraSurface.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (required) ...[
                      const SizedBox(width: 4),
                      Text(
                        '*',
                        style: AuraText.small
                            .copyWith(color: AuraSurface.dangerInk),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                '$used / $maxChars',
                style: AuraText.micro.copyWith(
                  color: color,
                  fontWeight: fontWeight,
                ),
              ),
            ],
          ),
          if (helper != null && helper!.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              helper!,
              style: AuraText.small.copyWith(color: AuraSurface.muted),
            ),
          ],
          const SizedBox(height: AuraSpace.s6),
          child,
        ],
      ),
    );
  }
}

class _StudioTextField extends StatelessWidget {
  const _StudioTextField({
    required this.controller,
    required this.hint,
    this.maxLength,
    this.minLines,
    this.maxLines,
    this.keyboardType,
    this.validator,
    this.prefix,
  });

  final TextEditingController controller;
  final String hint;
  final int? maxLength;
  final int? minLines;
  final int? maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? prefix;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      style: AuraText.body,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: prefix,
        hintStyle: AuraText.body.copyWith(color: AuraSurface.faint),
        filled: true,
        fillColor: AuraSurface.subtle,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s14,
          vertical: AuraSpace.s12,
        ),
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
          borderSide: const BorderSide(color: AuraSurface.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AuraRadius.md),
          borderSide:
              const BorderSide(color: AuraSurface.dangerInk, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AuraRadius.md),
          borderSide:
              const BorderSide(color: AuraSurface.dangerInk, width: 1.5),
        ),
      ),
      keyboardType: keyboardType,
      maxLength: maxLength,
      minLines: minLines,
      maxLines: maxLines ?? 1,
      validator: validator,
      buildCounter: _emptyCounter,
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

class _SocialField extends StatelessWidget {
  const _SocialField({
    required this.label,
    required this.icon,
    required this.controller,
    required this.hint,
    this.validator,
  });

  final String label;
  final IconData icon;
  final TextEditingController controller;
  final String hint;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return _StudioField(
      label: label,
      child: _StudioTextField(
        controller: controller,
        hint: hint,
        keyboardType: TextInputType.url,
        maxLength: 2048,
        validator: validator,
        prefix: Padding(
          padding: const EdgeInsets.only(left: 6, right: 2),
          child: Icon(icon, size: 18, color: AuraSurface.faint),
        ),
      ),
    );
  }
}

class _StudioTwoCol extends StatelessWidget {
  const _StudioTwoCol({required this.left, required this.right});

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

class _StudioThreeCol extends StatelessWidget {
  const _StudioThreeCol(
      {required this.a, required this.b, required this.c});

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

class _MediaSlot extends StatelessWidget {
  const _MediaSlot({
    required this.label,
    required this.helper,
    required this.child,
  });

  final String label;
  final String helper;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: AuraText.small.copyWith(
                color: AuraSurface.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          helper,
          style: AuraText.small.copyWith(color: AuraSurface.muted),
        ),
        const SizedBox(height: AuraSpace.s10),
        child,
      ],
    );
  }
}

class _ToneBanner extends StatelessWidget {
  const _ToneBanner({required this.tone, required this.message});

  final InsTone tone;
  final String message;

  @override
  Widget build(BuildContext context) {
    final t = InsToneStyle.of(tone);
    return Container(
      padding: const EdgeInsets.all(InsSpacing.cardPaddingDense),
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          Icon(t.icon, size: 16, color: t.fg),
          const SizedBox(width: AuraSpace.s10),
          Expanded(
            child: Text(
              message,
              style: AuraText.small.copyWith(color: t.fg, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagedFieldsNote extends StatelessWidget {
  const _ManagedFieldsNote();

  @override
  Widget build(BuildContext context) {
    return const InsCard(
      padding: EdgeInsets.all(InsSpacing.cardPaddingDense),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 14,
            color: AuraSurface.muted,
          ),
          SizedBox(width: AuraSpace.s8),
          Expanded(
            child: Text(
              'Slug, domain, jurisdiction, and verification status are managed through separate workflows (Domains screen and admin review).',
              style: TextStyle(
                color: AuraSurface.faint,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Media upload control — visual chrome refreshed; flow unchanged from prior
// implementation (pick → editor → upload, plus "Edit current" against the
// existing CDN URL).
// ─────────────────────────────────────────────────────────────────────────────

class _MediaUploadControl extends StatelessWidget {
  const _MediaUploadControl({
    required this.imageUrl,
    required this.uploading,
    required this.aspectRatio,
    required this.onPick,
    required this.onEditCurrent,
    required this.onRemove,
  });

  final String? imageUrl;
  final bool uploading;
  final double aspectRatio;
  final VoidCallback onPick;
  final VoidCallback onEditCurrent;
  final VoidCallback onRemove;

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
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: AuraSurface.faint,
                  ),
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
        if (uploading)
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
        const SizedBox(height: AuraSpace.s10),
        Wrap(
          spacing: AuraSpace.s8,
          runSpacing: AuraSpace.s8,
          children: [
            OutlinedButton.icon(
              onPressed: uploading ? null : onPick,
              icon: Icon(
                hasImage ? Icons.swap_horiz_rounded : Icons.upload_rounded,
                size: 16,
              ),
              label: Text(uploading
                  ? 'Uploading…'
                  : hasImage
                      ? 'Replace'
                      : 'Upload'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                textStyle:
                    AuraText.small.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (hasImage)
              OutlinedButton.icon(
                onPressed: uploading ? null : onEditCurrent,
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: const Text('Reframe / re-edit'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  textStyle:
                      AuraText.small.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            if (hasImage)
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
        ),
      ],
    );
  }
}

/// Phase 1B — Global Institution Ontology editor.
///
/// Compact three-row composition: class dropdown · type dropdown
/// (filtered to the parent class) · domain-tag toggle row. Wire tokens
/// stored on the parent state; labels resolved from
/// `institutionOntologyProvider`. No fake data — when the ontology
/// hasn't loaded yet the dropdowns render empty.
class _OntologyEditSection extends ConsumerWidget {
  const _OntologyEditSection({
    required this.institutionClass,
    required this.institutionType,
    required this.domainTags,
    required this.onClassChanged,
    required this.onTypeChanged,
    required this.onTagToggled,
  });

  final String? institutionClass;
  final String? institutionType;
  final List<String> domainTags;
  final ValueChanged<String?> onClassChanged;
  final ValueChanged<String?> onTypeChanged;
  final void Function(String tagId) onTagToggled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ontologyAsync = ref.watch(institutionOntologyProvider);
    final ontology = ontologyAsync.valueOrNull;
    final classes = ontology?.classes ?? const [];
    final types = ontology == null
        ? const []
        : (institutionClass == null
            ? const <InstitutionTypeDef>[]
            : ontology.typesForClass(institutionClass!));
    final domainTagDefs = ontology?.domainTags ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StudioTwoCol(
          left: _StudioField(
            label: 'Institution class',
            child: DropdownButtonFormField<String?>(
              value: institutionClass,
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Choose a class',
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('— Not classified —'),
                ),
                for (final c in classes)
                  DropdownMenuItem<String?>(
                    value: c.id,
                    child: Text(c.label),
                  ),
              ],
              onChanged: onClassChanged,
            ),
          ),
          right: _StudioField(
            label: 'Institution type',
            child: DropdownButtonFormField<String?>(
              value: institutionType,
              decoration: InputDecoration(
                isDense: true,
                hintText: institutionClass == null
                    ? 'Pick a class first'
                    : 'Choose a type',
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('— None —'),
                ),
                for (final t in types)
                  DropdownMenuItem<String?>(
                    value: t.id,
                    child: Text(t.label),
                  ),
              ],
              onChanged: institutionClass == null ? null : onTypeChanged,
            ),
          ),
        ),
        const SizedBox(height: AuraSpace.s10),
        _StudioField(
          label:
              'Domain tags (up to ${ontology?.maxDomainTagsPerInstitution ?? 8})',
          child: Wrap(
            spacing: AuraSpace.s6,
            runSpacing: AuraSpace.s6,
            children: [
              for (final tag in domainTagDefs)
                _DomainTagToggleChip(
                  label: tag.label,
                  selected: domainTags.contains(tag.id),
                  onTap: () {
                    final atCap = domainTags.length >=
                        (ontology?.maxDomainTagsPerInstitution ?? 8);
                    if (atCap && !domainTags.contains(tag.id)) return;
                    onTagToggled(tag.id);
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DomainTagToggleChip extends StatelessWidget {
  const _DomainTagToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AuraRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s10,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: selected ? AuraSurface.accentSoft : AuraSurface.subtle,
          borderRadius: BorderRadius.circular(AuraRadius.pill),
          border: Border.all(
            color: selected
                ? AuraSurface.accent.withValues(alpha: 0.4)
                : AuraSurface.divider,
          ),
        ),
        child: Text(
          label,
          style: AuraText.small.copyWith(
            color: selected ? AuraSurface.accentText : AuraSurface.ink,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
