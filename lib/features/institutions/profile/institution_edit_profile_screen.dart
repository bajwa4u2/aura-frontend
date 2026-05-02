import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
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

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  bool _loaded = false;
  bool _saving = false;
  String? _error;
  String? _successMessage;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _websiteCtrl.dispose();
    _categoryCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  void _populate(Map<String, dynamic> inst) {
    if (_loaded) return;
    _loaded = true;

    String readField(List<String> keys) {
      for (final k in keys) {
        final v = inst[k]?.toString().trim() ?? '';
        if (v.isNotEmpty) return v;
      }
      return '';
    }

    _nameCtrl.text = readField(['name', 'displayName', 'organizationName']);
    _descCtrl.text = readField(['description', 'bio', 'summary']);
    _websiteCtrl.text = readField(['website', 'websiteUrl']);
    _categoryCtrl.text = readField(['category', 'type', 'institutionType']);
    _locationCtrl.text = readField(['location', 'city']);
  }

  Future<void> _save(String institutionId) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
      _successMessage = null;
    });

    try {
      final repo = ref.read(institutionsRepositoryProvider);
      await repo.updateInstitutionProfile(
        institutionId,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        website: _websiteCtrl.text.trim(),
        category: _categoryCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
      );

      // Invalidate access provider so the rest of the UI sees updated data.
      ref.invalidate(institutionAccessProvider);

      setState(() {
        _saving = false;
        _successMessage = 'Profile updated.';
      });
    } catch (e) {
      String msg = 'Could not save profile.';
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data['message'] != null) {
          msg = data['message'].toString().trim();
        } else if (e.message != null && e.message!.isNotEmpty) {
          msg = e.message!.trim();
        }
      }
      setState(() {
        _saving = false;
        _error = msg;
      });
    }
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
          padding: const EdgeInsets.fromLTRB(
            AuraSpace.s16,
            AuraSpace.s20,
            AuraSpace.s16,
            AuraSpace.s32,
          ),
          children: [
            AuraErrorState(title: 'Unavailable', body: '$e'),
          ],
        ),
        data: (access) {
          if (identity == null || !identity.isAdmin) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AuraSpace.s16,
                AuraSpace.s20,
                AuraSpace.s16,
                AuraSpace.s32,
              ),
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

          return _EditForm(
            formKey: _formKey,
            nameCtrl: _nameCtrl,
            descCtrl: _descCtrl,
            websiteCtrl: _websiteCtrl,
            categoryCtrl: _categoryCtrl,
            locationCtrl: _locationCtrl,
            saving: _saving,
            error: _error,
            successMessage: _successMessage,
            onSave: () => _save(identity.id),
            onCancel: () => context.go('/institution/profile'),
          );
        },
      ),
    );
  }
}

class _EditForm extends StatelessWidget {
  const _EditForm({
    required this.formKey,
    required this.nameCtrl,
    required this.descCtrl,
    required this.websiteCtrl,
    required this.categoryCtrl,
    required this.locationCtrl,
    required this.saving,
    required this.error,
    required this.successMessage,
    required this.onSave,
    required this.onCancel,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController descCtrl;
  final TextEditingController websiteCtrl;
  final TextEditingController categoryCtrl;
  final TextEditingController locationCtrl;
  final bool saving;
  final String? error;
  final String? successMessage;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  static const Color _accent = Color(0xFF0D9488);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.s16,
        AuraSpace.s20,
        AuraSpace.s16,
        AuraSpace.s32,
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
                  const Text('Edit institution profile',
                      style: AuraText.headline),
                  const SizedBox(height: AuraSpace.s6),
                  Text(
                    'Update your institution\'s public-facing identity and details.',
                    style: AuraText.body.copyWith(
                      color: AuraSurface.muted,
                      height: 1.5,
                    ),
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

                  _FieldSection(
                    title: 'DISPLAY NAME',
                    child: TextFormField(
                      controller: nameCtrl,
                      style: AuraText.body,
                      decoration: _inputDecoration('Institution name'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Name is required.';
                        }
                        if (v.trim().length > 128) {
                          return 'Name must be 128 characters or fewer.';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: AuraSpace.s16),

                  _FieldSection(
                    title: 'ABOUT',
                    child: TextFormField(
                      controller: descCtrl,
                      style: AuraText.body,
                      decoration: _inputDecoration(
                        'Describe your institution…',
                      ),
                      minLines: 3,
                      maxLines: 8,
                      maxLength: 1000,
                    ),
                  ),
                  const SizedBox(height: AuraSpace.s16),

                  _FieldSection(
                    title: 'WEBSITE',
                    child: TextFormField(
                      controller: websiteCtrl,
                      style: AuraText.body,
                      decoration: _inputDecoration('https://…'),
                      keyboardType: TextInputType.url,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final uri = Uri.tryParse(v.trim());
                        if (uri == null ||
                            (!uri.isScheme('http') &&
                                !uri.isScheme('https'))) {
                          return 'Enter a valid URL starting with http:// or https://';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: AuraSpace.s16),

                  _FieldSection(
                    title: 'CATEGORY',
                    child: TextFormField(
                      controller: categoryCtrl,
                      style: AuraText.body,
                      decoration: _inputDecoration(
                        'e.g. University, NGO, Research institute…',
                      ),
                    ),
                  ),
                  const SizedBox(height: AuraSpace.s16),

                  _FieldSection(
                    title: 'LOCATION',
                    child: TextFormField(
                      controller: locationCtrl,
                      style: AuraText.body,
                      decoration: _inputDecoration('City, country…'),
                    ),
                  ),
                  const SizedBox(height: AuraSpace.s28),

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
                      AuraSecondaryButton(
                        label: 'Cancel',
                        onPressed: onCancel,
                      ),
                    ],
                  ),

                  const SizedBox(height: AuraSpace.s20),
                  Container(
                    padding: const EdgeInsets.all(AuraSpace.s14),
                    decoration: BoxDecoration(
                      color: AuraSurface.subtle,
                      borderRadius: BorderRadius.circular(AuraRadius.card),
                      border: Border.all(color: AuraSurface.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 14,
                              color: AuraSurface.muted,
                            ),
                            const SizedBox(width: AuraSpace.s8),
                            Text(
                              'Fields not shown here',
                              style: AuraText.small.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AuraSurface.muted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AuraSpace.s8),
                        Text(
                          'Logo upload, cover banner, domain, jurisdiction, and verification status are managed through separate workflows (Domains screen and admin review).',
                          style: AuraText.small.copyWith(
                            color: AuraSurface.faint,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
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
        borderSide:
            const BorderSide(color: AuraSurface.dangerInk, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AuraRadius.md),
        borderSide:
            const BorderSide(color: AuraSurface.dangerInk, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s14,
        vertical: AuraSpace.s12,
      ),
    );
  }
}

class _FieldSection extends StatelessWidget {
  const _FieldSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AuraText.micro.copyWith(
            color: AuraSurface.faint,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: AuraSpace.s8),
        child,
      ],
    );
  }
}

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
