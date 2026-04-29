import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/net/dio_provider.dart';
import '../../search/providers.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';

// ─── Wizard entry point ───────────────────────────────────────────────────────

class InstitutionOnboardingWizard extends ConsumerStatefulWidget {
  const InstitutionOnboardingWizard({
    super.key,
    this.mode,
    this.inviteCode,
  });

  /// 'create' | 'claim' | 'join' | 'signin'
  final String? mode;
  final String? inviteCode;

  @override
  ConsumerState<InstitutionOnboardingWizard> createState() =>
      _InstitutionOnboardingWizardState();
}

class _InstitutionOnboardingWizardState
    extends ConsumerState<InstitutionOnboardingWizard> {
  _WizardPath? _path;
  int _step = 0;

  // Form state
  final _formKey = GlobalKey<FormState>();

  // Step 2 — Institution identity
  final _orgName = TextEditingController();
  final _website = TextEditingController();
  final _jurisdiction = TextEditingController();
  final _description = TextEditingController();
  String? _institutionType;
  Map<String, dynamic>? _selectedInstitution; // for claim path

  // Step 3 — Representative
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _workEmail = TextEditingController();
  final _phone = TextEditingController();
  final _roleTitle = TextEditingController();
  final _purpose = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // Step 4 — Join by invite
  final _inviteCode = TextEditingController();

  // Submission state
  bool _submitting = false;
  bool _submitted = false;
  String? _error;
  Map<String, dynamic>? _submittedRequest;

  static const _institutionTypes = <String>[
    'Government',
    'University or school',
    'Nonprofit or foundation',
    'Company',
    'Media organization',
    'Research institute',
    'Faith institution',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.inviteCode != null) {
      _inviteCode.text = widget.inviteCode!;
    }
    _path = _pathFromMode(widget.mode);
    if (_path == _WizardPath.signin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/institution/sign-in');
      });
    }
  }

  @override
  void dispose() {
    _orgName.dispose();
    _website.dispose();
    _jurisdiction.dispose();
    _description.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _workEmail.dispose();
    _phone.dispose();
    _roleTitle.dispose();
    _purpose.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _inviteCode.dispose();
    super.dispose();
  }

  _WizardPath? _pathFromMode(String? mode) {
    switch (mode) {
      case 'create':
        return _WizardPath.create;
      case 'claim':
        return _WizardPath.claim;
      case 'join':
        return _WizardPath.join;
      case 'signin':
        return _WizardPath.signin;
      default:
        return null;
    }
  }

  bool get _isAuthed => ref.read(isAuthedProvider);

  int get _totalSteps {
    if (_path == _WizardPath.join) return 2; // invite code + status
    if (_path == _WizardPath.create) return 4; // identity + rep + review + status
    if (_path == _WizardPath.claim) return 4; // identity + rep + review + status
    return 1;
  }

  void _selectPath(_WizardPath path) {
    setState(() {
      _path = path;
      _step = 1;
      _error = null;
    });
  }

  void _next() {
    if (_path == _WizardPath.join) {
      _submitJoin();
      return;
    }

    if (_step == 2) {
      // identity step validation
      if (!_validateIdentityStep()) return;
    }

    setState(() {
      _step++;
      _error = null;
    });
  }

  void _back() {
    if (_step <= 1) {
      setState(() {
        _path = null;
        _step = 0;
        _error = null;
      });
      return;
    }
    setState(() {
      _step--;
      _error = null;
    });
  }

  bool _validateIdentityStep() {
    if (_orgName.text.trim().isEmpty) {
      setState(() => _error = 'Enter the institution name.');
      return false;
    }
    if (_institutionType == null) {
      setState(() => _error = 'Select an institution type.');
      return false;
    }
    if (_path == _WizardPath.claim && _selectedInstitution == null) {
      setState(() => _error = 'Search and select the institution you want to claim.');
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    if (_submitting) return;

    if (!_isAuthed && _path == _WizardPath.create) {
      // Validate account fields
      if (_firstName.text.trim().isEmpty || _lastName.text.trim().isEmpty) {
        setState(() => _error = 'Enter your first and last name.');
        return;
      }
      if (!_workEmail.text.trim().contains('@')) {
        setState(() => _error = 'Enter a valid work email.');
        return;
      }
      if (_password.text.length < 8) {
        setState(() => _error = 'Password must be at least 8 characters.');
        return;
      }
      if (_password.text != _confirmPassword.text) {
        setState(() => _error = 'Passwords do not match.');
        return;
      }
    }

    if (_isAuthed && (_path == _WizardPath.claim || _path == _WizardPath.create)) {
      if (_workEmail.text.trim().isEmpty) {
        // For authed claim flow, email defaults to their own; allow empty
      }
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      Map<String, dynamic> result;

      if (_path == _WizardPath.create && !_isAuthed) {
        result = await _submitCreate(dio);
      } else if (_path == _WizardPath.claim || (_path == _WizardPath.create && _isAuthed)) {
        result = await _submitClaim(dio);
      } else {
        throw Exception('Unexpected path state.');
      }

      setState(() {
        _submitting = false;
        _submitted = true;
        _submittedRequest = _extractRequest(result);
        _step = _totalSteps; // move to status step
      });
    } on DioException catch (e) {
      setState(() {
        _submitting = false;
        _error = _dioMessage(e, 'Submission failed. Please check your details and try again.');
      });
    } catch (e) {
      setState(() {
        _submitting = false;
        _error = e.toString();
      });
    }
  }

  Future<Map<String, dynamic>> _submitCreate(Dio dio) async {
    final res = await dio.post('/institutions/verification-request', data: {
      'firstName': _firstName.text.trim(),
      'lastName': _lastName.text.trim(),
      'organizationName': _orgName.text.trim(),
      'institutionType': _institutionType ?? 'Other',
      'websiteUrl': _website.text.trim().isNotEmpty ? _website.text.trim() : null,
      'workEmail': _workEmail.text.trim().toLowerCase(),
      'phone': _phone.text.trim().isNotEmpty ? _phone.text.trim() : null,
      'password': _password.text,
      'confirmPassword': _confirmPassword.text,
      'roleTitle': _roleTitle.text.trim().isNotEmpty ? _roleTitle.text.trim() : null,
      'jurisdiction': _jurisdiction.text.trim().isNotEmpty ? _jurisdiction.text.trim() : null,
      'purpose': _description.text.trim().isNotEmpty ? _description.text.trim() : (_purpose.text.trim().isNotEmpty ? _purpose.text.trim() : null),
    });
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> _submitClaim(Dio dio) async {
    final targetId = _selectedInstitution?['id']?.toString() ?? '';
    if (targetId.isEmpty) throw Exception('No institution selected to claim.');

    final res = await dio.post('/institutions/claim-request', data: {
      'claimTargetInstitutionId': targetId,
      'organizationName': _orgName.text.trim(),
      'websiteUrl': _website.text.trim().isNotEmpty ? _website.text.trim() : null,
      'workEmail': _workEmail.text.trim().isNotEmpty ? _workEmail.text.trim().toLowerCase() : null,
      'phone': _phone.text.trim().isNotEmpty ? _phone.text.trim() : null,
      'roleTitle': _roleTitle.text.trim().isNotEmpty ? _roleTitle.text.trim() : null,
      'jurisdiction': _jurisdiction.text.trim().isNotEmpty ? _jurisdiction.text.trim() : null,
      'purpose': _purpose.text.trim().isNotEmpty ? _purpose.text.trim() : null,
    });
    return _asMap(res.data);
  }

  Future<void> _submitJoin() async {
    final code = _inviteCode.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter the invite code.');
      return;
    }

    if (!_isAuthed) {
      setState(() => _error = 'Sign in to your Aura account before accepting an invite.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post('/institutions/invites/accept', data: {'code': code});
      setState(() {
        _submitting = false;
        _submitted = true;
        _submittedRequest = _asMap(res.data);
        _step = _totalSteps;
      });
    } on DioException catch (e) {
      setState(() {
        _submitting = false;
        _error = _dioMessage(e, 'Invalid or expired invite code.');
      });
    } catch (e) {
      setState(() {
        _submitting = false;
        _error = e.toString();
      });
    }
  }

  Map<String, dynamic> _extractRequest(Map<String, dynamic> data) {
    final inner = data['data'];
    if (inner is Map) return Map<String, dynamic>.from(inner);
    return data;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _dioMessage(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map) {
      final msg = data['message'];
      if (msg is String && msg.trim().isNotEmpty) return msg.trim();
    }
    return e.message?.trim().isNotEmpty == true ? e.message! : fallback;
  }

  @override
  Widget build(BuildContext context) {
    return AuraScaffold(
      showHeader: false,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _WizardHeader(
            path: _path,
            step: _step,
            totalSteps: _totalSteps,
            onBack: (_path != null && !_submitted) ? _back : null,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AuraSpace.s16, AuraSpace.s24, AuraSpace.s16, AuraSpace.s32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Form(
                  key: _formKey,
                  child: _buildCurrentStep(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    if (_path == null) return _buildPathChooser();

    if (_path == _WizardPath.signin) {
      return const _RedirectingStep(message: 'Redirecting to institution sign in…');
    }

    if (_path == _WizardPath.join) {
      if (_submitted) return _buildJoinSuccess();
      return _buildJoinStep();
    }

    // Create / Claim
    if (_submitted || _step >= _totalSteps) return _buildStatusStep();

    switch (_step) {
      case 1:
        return _buildIdentityStep();
      case 2:
        return _buildRepresentativeStep();
      case 3:
        return _buildReviewStep();
      default:
        return _buildStatusStep();
    }
  }

  // ── Step 0: Path chooser ───────────────────────────────────────────────────

  Widget _buildPathChooser() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Institution setup', style: AuraText.headline),
        const SizedBox(height: AuraSpace.s8),
        Text(
          'How would you like to get started?',
          style: AuraText.body.copyWith(color: AuraSurface.muted),
        ),
        const SizedBox(height: AuraSpace.s24),
        _PathCard(
          icon: Icons.apartment_outlined,
          title: 'Create new institution',
          subtitle: 'Register your institution on Aura for the first time.',
          onTap: () => _selectPath(_WizardPath.create),
        ),
        const SizedBox(height: AuraSpace.s12),
        _PathCard(
          icon: Icons.manage_search_rounded,
          title: 'Claim existing institution',
          subtitle: 'Your institution is already listed — request to represent it.',
          onTap: () {
            if (!_isAuthed) {
              _showAuthRequiredDialog();
              return;
            }
            _selectPath(_WizardPath.claim);
          },
        ),
        const SizedBox(height: AuraSpace.s12),
        _PathCard(
          icon: Icons.group_add_outlined,
          title: 'Join with invite',
          subtitle: 'You received an invitation code from your institution admin.',
          onTap: () {
            if (!_isAuthed) {
              _showAuthRequiredDialog();
              return;
            }
            _selectPath(_WizardPath.join);
          },
        ),
        const SizedBox(height: AuraSpace.s12),
        _PathCard(
          icon: Icons.login_rounded,
          title: 'Existing institution admin',
          subtitle: 'Sign in to your existing institution workspace.',
          onTap: () => context.go('/institution/sign-in'),
        ),
        const SizedBox(height: AuraSpace.s24),
        _TrustNote(),
      ],
    );
  }

  void _showAuthRequiredDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => _AuthRequiredDialog(
        onSignIn: () {
          Navigator.pop(ctx);
          context.push('/login?redirect=${Uri.encodeComponent('/institutions/get-started')}');
        },
      ),
    );
  }

  // ── Step 1: Institution identity ───────────────────────────────────────────

  Widget _buildIdentityStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepTitle(
          title: _path == _WizardPath.claim
              ? 'Which institution are you claiming?'
              : 'Institution identity',
          subtitle: _path == _WizardPath.claim
              ? 'Search for the institution already listed on Aura, then tell us about your role.'
              : 'Basic information about the institution.',
        ),
        const SizedBox(height: AuraSpace.s24),
        if (_path == _WizardPath.claim) ...[
          _InstitutionSearchField(
            selected: _selectedInstitution,
            onSelected: (inst) => setState(() {
              _selectedInstitution = inst;
              final name = (inst['name'] ?? inst['organizationName'] ?? '').toString().trim();
              if (name.isNotEmpty) _orgName.text = name;
              final website = (inst['website'] ?? inst['websiteUrl'] ?? inst['url'] ?? '').toString().trim();
              if (website.isNotEmpty) _website.text = website;
              final jurisdiction = (inst['jurisdiction'] ?? inst['country'] ?? inst['region'] ?? '').toString().trim();
              if (jurisdiction.isNotEmpty) _jurisdiction.text = jurisdiction;
              final description = (inst['description'] ?? inst['bio'] ?? inst['summary'] ?? '').toString().trim();
              if (description.isNotEmpty) _description.text = description;
            }),
            onCleared: () => setState(() => _selectedInstitution = null),
          ),
          const SizedBox(height: AuraSpace.s20),
        ],
        AuraInput(
          controller: _orgName,
          label: 'Institution name',
          hint: 'Official legal or display name',
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AuraSpace.s16),
        _TypeDropdown(
          value: _institutionType,
          items: _institutionTypes,
          onChanged: (v) => setState(() => _institutionType = v),
        ),
        const SizedBox(height: AuraSpace.s16),
        AuraInput(
          controller: _website,
          label: 'Official website',
          hint: 'https://yourorganisation.org',
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AuraSpace.s16),
        AuraInput(
          controller: _jurisdiction,
          label: 'Location / jurisdiction (optional)',
          hint: 'City, country, or region',
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AuraSpace.s16),
        AuraInput(
          controller: _description,
          label: 'Short description (optional)',
          hint: 'What does this institution do?',
          maxLines: 3,
          minLines: 2,
          textInputAction: TextInputAction.newline,
        ),
        if (_error != null) ...[
          const SizedBox(height: AuraSpace.s12),
          _ErrorBanner(message: _error!),
        ],
        const SizedBox(height: AuraSpace.s24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AuraPrimaryButton(
              label: 'Continue',
              icon: Icons.arrow_forward_rounded,
              onPressed: _next,
            ),
          ],
        ),
      ],
    );
  }

  // ── Step 2: Representative ─────────────────────────────────────────────────

  Widget _buildRepresentativeStep() {
    final showAccountFields = _path == _WizardPath.create && !_isAuthed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepTitle(
          title: 'Your authority',
          subtitle: 'Tell us who you are and your role at the institution.',
        ),
        const SizedBox(height: AuraSpace.s24),
        Row(
          children: [
            Expanded(
              child: AuraInput(
                controller: _firstName,
                label: 'First name',
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(width: AuraSpace.s12),
            Expanded(
              child: AuraInput(
                controller: _lastName,
                label: 'Last name',
                textInputAction: TextInputAction.next,
              ),
            ),
          ],
        ),
        const SizedBox(height: AuraSpace.s16),
        AuraInput(
          controller: _roleTitle,
          label: 'Your role / title',
          hint: 'e.g. Director of Communications',
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AuraSpace.s16),
        AuraInput(
          controller: _workEmail,
          label: showAccountFields ? 'Institution email (account)' : 'Work email',
          hint: 'name@yourinstitution.org',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AuraSpace.s16),
        AuraInput(
          controller: _phone,
          label: 'Phone number (optional)',
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AuraSpace.s16),
        AuraInput(
          controller: _purpose,
          label: 'Why are you submitting this request? (optional)',
          hint: 'Context for the review team',
          maxLines: 3,
          minLines: 2,
          textInputAction: TextInputAction.newline,
        ),
        if (showAccountFields) ...[
          const SizedBox(height: AuraSpace.s20),
          const _SectionLabel(label: 'Create your institution account'),
          const SizedBox(height: AuraSpace.s12),
          AuraInput(
            controller: _password,
            label: 'Password',
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18, color: AuraSurface.muted),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          const SizedBox(height: AuraSpace.s12),
          AuraInput(
            controller: _confirmPassword,
            label: 'Confirm password',
            obscureText: _obscureConfirm,
            textInputAction: TextInputAction.done,
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18, color: AuraSurface.muted),
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
          const SizedBox(height: AuraSpace.s12),
          Text(
            'This creates a dedicated institution account tied to your institution email. '
            'You can sign in at /institution/sign-in after your request is approved.',
            style: AuraText.small.copyWith(color: AuraSurface.muted),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: AuraSpace.s12),
          _ErrorBanner(message: _error!),
        ],
        const SizedBox(height: AuraSpace.s24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AuraPrimaryButton(
              label: 'Review submission',
              icon: Icons.checklist_rounded,
              onPressed: _next,
            ),
          ],
        ),
      ],
    );
  }

  // ── Step 3: Review & submit ────────────────────────────────────────────────

  Widget _buildReviewStep() {
    final showAccountInfo = _path == _WizardPath.create && !_isAuthed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepTitle(
          title: 'Review and submit',
          subtitle: 'Check everything before sending your request for review.',
        ),
        const SizedBox(height: AuraSpace.s24),
        _ReviewSection(title: 'Institution', rows: [
          _ReviewRow('Name', _orgName.text.trim()),
          _ReviewRow('Type', _institutionType ?? '—'),
          if (_website.text.trim().isNotEmpty) _ReviewRow('Website', _website.text.trim()),
          if (_jurisdiction.text.trim().isNotEmpty) _ReviewRow('Location', _jurisdiction.text.trim()),
          if (_description.text.trim().isNotEmpty) _ReviewRow('Description', _description.text.trim()),
        ]),
        const SizedBox(height: AuraSpace.s16),
        _ReviewSection(title: 'Representative', rows: [
          _ReviewRow('Name', '${_firstName.text.trim()} ${_lastName.text.trim()}'.trim()),
          if (_roleTitle.text.trim().isNotEmpty) _ReviewRow('Role', _roleTitle.text.trim()),
          _ReviewRow('Work email', _workEmail.text.trim()),
          if (_phone.text.trim().isNotEmpty) _ReviewRow('Phone', _phone.text.trim()),
          if (_purpose.text.trim().isNotEmpty) _ReviewRow('Notes', _purpose.text.trim()),
        ]),
        const SizedBox(height: AuraSpace.s20),
        _AuthorityNote(path: _path!),
        if (showAccountInfo) ...[
          const SizedBox(height: AuraSpace.s12),
          _AccountCreationNote(),
        ],
        if (_error != null) ...[
          const SizedBox(height: AuraSpace.s12),
          _ErrorBanner(message: _error!),
        ],
        const SizedBox(height: AuraSpace.s24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AuraPrimaryButton(
              label: _submitting ? 'Submitting…' : 'Submit request',
              icon: _submitting ? null : Icons.send_rounded,
              onPressed: _submitting ? null : _submit,
            ),
          ],
        ),
      ],
    );
  }

  // ── Join by invite ────────────────────────────────────────────────────────

  Widget _buildJoinStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepTitle(
          title: 'Join with invite',
          subtitle: 'Enter the invite code sent to you by your institution admin.',
        ),
        const SizedBox(height: AuraSpace.s24),
        if (!_isAuthed) ...[
          const _ErrorBanner(message: 'You must be signed in to accept an invite. Sign in first, then return here.'),
          const SizedBox(height: AuraSpace.s16),
          AuraPrimaryButton(
            label: 'Sign in',
            icon: Icons.login_rounded,
            onPressed: () => context.push('/login?redirect=${Uri.encodeComponent('/institutions/get-started?mode=join&code=${_inviteCode.text.trim()}')}'),
          ),
          const SizedBox(height: AuraSpace.s24),
        ],
        AuraInput(
          controller: _inviteCode,
          label: 'Invite code',
          hint: 'Paste the code from your invitation',
          textInputAction: TextInputAction.done,
        ),
        if (_error != null) ...[
          const SizedBox(height: AuraSpace.s12),
          _ErrorBanner(message: _error!),
        ],
        const SizedBox(height: AuraSpace.s24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AuraPrimaryButton(
              label: _submitting ? 'Accepting…' : 'Accept invite',
              icon: _submitting ? null : Icons.check_rounded,
              onPressed: (_submitting || !_isAuthed) ? null : _submitJoin,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildJoinSuccess() {
    final data = _submittedRequest ?? <String, dynamic>{};
    final institutionName = _asMap(data['institution'])['name']?.toString() ?? 'the institution';
    final role = data['role']?.toString() ?? 'member';

    return _SuccessPanel(
      title: 'Welcome!',
      message: 'You have joined $institutionName as a ${role.toLowerCase()}.',
      primaryLabel: 'Go to institution dashboard',
      onPrimary: () => context.go('/institution/dashboard'),
      secondaryLabel: 'Return home',
      onSecondary: () => context.go('/'),
    );
  }

  // ── Status step (after create/claim submission) ────────────────────────────

  Widget _buildStatusStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SubmittedStatusPanel(
          path: _path!,
          request: _submittedRequest,
        ),
        const SizedBox(height: AuraSpace.s24),
        _NextStepsPanel(path: _path!),
      ],
    );
  }
}

// ─── Enums ────────────────────────────────────────────────────────────────────

enum _WizardPath { create, claim, join, signin }

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _WizardHeader extends StatelessWidget {
  const _WizardHeader({
    required this.path,
    required this.step,
    required this.totalSteps,
    this.onBack,
  });

  final _WizardPath? path;
  final int step;
  final int totalSteps;
  final VoidCallback? onBack;

  String get _pathLabel {
    switch (path) {
      case _WizardPath.create:
        return 'Create institution';
      case _WizardPath.claim:
        return 'Claim institution';
      case _WizardPath.join:
        return 'Join with invite';
      case _WizardPath.signin:
        return 'Institution sign in';
      case null:
        return 'Get started';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(AuraSpace.s16, AuraSpace.s20, AuraSpace.s16, AuraSpace.s16),
      decoration: const BoxDecoration(
        color: AuraSurface.card,
        border: Border(bottom: BorderSide(color: AuraSurface.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (onBack != null) ...[
                GestureDetector(
                  onTap: onBack,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chevron_left, size: 18, color: AuraSurface.muted),
                      SizedBox(width: 2),
                      Text('Back', style: TextStyle(fontSize: 13, color: AuraSurface.muted)),
                    ],
                  ),
                ),
                const SizedBox(width: AuraSpace.s12),
              ],
              Text(
                _pathLabel,
                style: AuraText.subtitle,
              ),
              const Spacer(),
              if (path != null && totalSteps > 1 && step > 0)
                Text(
                  'Step $step of ${totalSteps - 1}',
                  style: AuraText.small.copyWith(color: AuraSurface.muted),
                ),
            ],
          ),
          if (path != null && totalSteps > 2 && step > 0 && step < totalSteps) ...[
            const SizedBox(height: AuraSpace.s12),
            ClipRRect(
              borderRadius: BorderRadius.circular(AuraRadius.pill),
              child: LinearProgressIndicator(
                value: (step - 1) / (totalSteps - 2).clamp(1, double.infinity),
                minHeight: 3,
                backgroundColor: AuraSurface.elevated,
                valueColor: const AlwaysStoppedAnimation<Color>(AuraSurface.accent),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AuraText.title),
        if (subtitle != null) ...[
          const SizedBox(height: AuraSpace.s6),
          Text(subtitle!, style: AuraText.body.copyWith(color: AuraSurface.muted)),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AuraText.small.copyWith(
        fontWeight: FontWeight.w700,
        color: AuraSurface.muted,
        letterSpacing: 0.08,
      ),
    );
  }
}

class _PathCard extends StatelessWidget {
  const _PathCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AuraRadius.xl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AuraRadius.xl),
        child: Container(
          padding: const EdgeInsets.all(AuraSpace.s20),
          decoration: BoxDecoration(
            color: AuraSurface.card,
            borderRadius: BorderRadius.circular(AuraRadius.xl),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AuraSurface.elevated,
                  borderRadius: BorderRadius.circular(AuraRadius.card),
                  border: Border.all(color: AuraSurface.divider),
                ),
                child: Icon(icon, size: 20, color: AuraSurface.accent),
              ),
              const SizedBox(width: AuraSpace.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AuraText.body.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: AuraText.small.copyWith(color: AuraSurface.muted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: AuraSurface.faint),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeDropdown extends StatelessWidget {
  const _TypeDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      // ignore: deprecated_member_use
      value: value,
      hint: const Text('Institution type'),
      decoration: const InputDecoration(labelText: 'Institution type'),
      items: items
          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
          .toList(),
      onChanged: onChanged,
      style: AuraText.body,
    );
  }
}

enum _SearchErrorKind { network, server, unknown }

class _InstitutionSearchField extends ConsumerStatefulWidget {
  const _InstitutionSearchField({
    required this.selected,
    required this.onSelected,
    required this.onCleared,
  });

  final Map<String, dynamic>? selected;
  final ValueChanged<Map<String, dynamic>> onSelected;
  final VoidCallback onCleared;

  @override
  ConsumerState<_InstitutionSearchField> createState() =>
      _InstitutionSearchFieldState();
}

class _InstitutionSearchFieldState
    extends ConsumerState<_InstitutionSearchField> {
  final _query = TextEditingController();
  List<Map<String, dynamic>> _results = const [];
  bool _searching = false;
  _SearchErrorKind? _errorKind;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.length < 2) {
      setState(() => _results = const []);
      return;
    }

    setState(() {
      _searching = true;
      _errorKind = null;
    });

    try {
      final result = await ref.read(searchRepositoryProvider).search(q);
      if (!mounted) return;
      setState(() {
        _results = result.institutions;
        _searching = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _errorKind = switch (e.type) {
          DioExceptionType.connectionError ||
          DioExceptionType.connectionTimeout ||
          DioExceptionType.sendTimeout ||
          DioExceptionType.receiveTimeout =>
            _SearchErrorKind.network,
          DioExceptionType.badResponse => _SearchErrorKind.server,
          _ => _SearchErrorKind.unknown,
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _errorKind = _SearchErrorKind.unknown;
      });
    }
  }

  String get _errorMessage => switch (_errorKind) {
        _SearchErrorKind.network =>
          'No connection — check your network and retry.',
        _SearchErrorKind.server =>
          'Search is temporarily unavailable. Try again.',
        _ => 'Search failed. Try again.',
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.selected != null) ...[
          Container(
            padding: const EdgeInsets.all(AuraSpace.s12),
            decoration: BoxDecoration(
              color: AuraSurface.goodBg,
              borderRadius: BorderRadius.circular(AuraRadius.card),
              border: Border.all(
                color: AuraSurface.goodInk.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 16,
                  color: AuraSurface.goodInk,
                ),
                const SizedBox(width: AuraSpace.s8),
                Expanded(
                  child: Text(
                    widget.selected!['name']?.toString() ??
                        'Selected institution',
                    style: AuraText.small.copyWith(
                      color: AuraSurface.goodInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: widget.onCleared,
                  child: const Icon(
                    Icons.close,
                    size: 16,
                    color: AuraSurface.goodInk,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AuraSpace.s12),
        ],
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _query,
                decoration: const InputDecoration(
                  labelText: 'Search institution name',
                  prefixIcon: Icon(Icons.search, size: 18),
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
              ),
            ),
            const SizedBox(width: AuraSpace.s8),
            AuraPrimaryButton(
              label: _searching ? '…' : 'Search',
              onPressed: _searching ? null : _search,
            ),
          ],
        ),
        if (_errorKind != null) ...[
          const SizedBox(height: AuraSpace.s8),
          Row(
            children: [
              Expanded(
                child: Text(
                  _errorMessage,
                  style: AuraText.small.copyWith(color: AuraSurface.dangerInk),
                ),
              ),
              const SizedBox(width: AuraSpace.s8),
              GestureDetector(
                onTap: _search,
                child: Text(
                  'Retry',
                  style: AuraText.small.copyWith(
                    color: AuraSurface.accentText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (_results.isNotEmpty) ...[
          const SizedBox(height: AuraSpace.s8),
          Container(
            decoration: BoxDecoration(
              color: AuraSurface.card,
              borderRadius: BorderRadius.circular(AuraRadius.card),
              border: Border.all(color: AuraSurface.divider),
            ),
            child: Column(
              children: [
                for (int i = 0; i < _results.length; i++) ...[
                  _InstitutionResultTile(
                    data: _results[i],
                    onTap: () {
                      widget.onSelected(_results[i]);
                      setState(() => _results = const []);
                    },
                  ),
                  if (i != _results.length - 1)
                    const Divider(
                      height: 1,
                      indent: AuraSpace.s14,
                      endIndent: AuraSpace.s14,
                    ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _InstitutionResultTile extends StatelessWidget {
  const _InstitutionResultTile({required this.data, required this.onTap});

  final Map<String, dynamic> data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = (data['name'] ?? '').toString().trim();
    final slug = (data['slug'] ?? data['handle'] ?? '').toString().trim();
    final domain = (data['domain'] ?? '').toString().trim();
    final jurisdiction =
        (data['jurisdiction'] ?? data['country'] ?? '').toString().trim();
    final description =
        (data['description'] ?? data['bio'] ?? '').toString().trim();
    final rawVerified = data['isVerified'] ?? data['verified'];
    final isVerified = rawVerified is bool
        ? rawVerified
        : rawVerified is num
            ? rawVerified != 0
            : false;

    final subline = <String>[
      if (domain.isNotEmpty) domain,
      if (jurisdiction.isNotEmpty) jurisdiction,
    ].join(' · ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(AuraSpace.s14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AuraSurface.subtle,
                  borderRadius: BorderRadius.circular(AuraRadius.r10),
                  border: Border.all(color: AuraSurface.divider),
                ),
                child: const Icon(
                  Icons.apartment_outlined,
                  size: 18,
                  color: AuraSurface.muted,
                ),
              ),
              const SizedBox(width: AuraSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name.isNotEmpty ? name : 'Institution',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AuraText.small
                                .copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: AuraSpace.s6),
                          const Icon(
                            Icons.verified_rounded,
                            size: 14,
                            color: AuraSurface.accentText,
                          ),
                        ],
                      ],
                    ),
                    if (slug.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        slug,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            AuraText.micro.copyWith(color: AuraSurface.muted),
                      ),
                    ],
                    if (subline.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            AuraText.micro.copyWith(color: AuraSurface.muted),
                      ),
                    ],
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: AuraSpace.s4),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            AuraText.micro.copyWith(color: AuraSurface.muted),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AuraSpace.s8),
              const Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: AuraSurface.faint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({required this.title, required this.rows});

  final String title;
  final List<_ReviewRow> rows;

  @override
  Widget build(BuildContext context) {
    final visibleRows = rows.where((r) => r.value.isNotEmpty).toList();
    if (visibleRows.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.xl),
        border: Border.all(color: AuraSurface.divider),
      ),
      padding: const EdgeInsets.all(AuraSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AuraText.small.copyWith(fontWeight: FontWeight.w700, color: AuraSurface.muted)),
          const SizedBox(height: AuraSpace.s12),
          ...visibleRows.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: AuraSpace.s8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(r.label, style: AuraText.small.copyWith(color: AuraSurface.muted)),
                    ),
                    Expanded(
                      child: Text(r.value, style: AuraText.small.copyWith(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _ReviewRow {
  const _ReviewRow(this.label, this.value);
  final String label;
  final String value;
}

class _AuthorityNote extends StatelessWidget {
  const _AuthorityNote({required this.path});

  final _WizardPath path;

  @override
  Widget build(BuildContext context) {
    final text = path == _WizardPath.claim
        ? 'Claim requests are reviewed by Aura admins. Authority over this institution is granted only after verification. Submitting this does not grant access immediately.'
        : 'Create requests are reviewed by Aura admins. Your institution workspace will become active only after approval. No institutional authority is granted before that point.';

    return Container(
      padding: const EdgeInsets.all(AuraSpace.s12),
      decoration: BoxDecoration(
        color: AuraSurface.infoBg,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.infoInk.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 16, color: AuraSurface.infoInk),
          const SizedBox(width: AuraSpace.s8),
          Expanded(
            child: Text(text, style: AuraText.small.copyWith(color: AuraSurface.infoInk)),
          ),
        ],
      ),
    );
  }
}

class _AccountCreationNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s12),
      decoration: BoxDecoration(
        color: AuraSurface.elevated,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Text(
        'A dedicated institution account will be created with the email and password you provided. '
        'This is separate from any personal Aura account.',
        style: AuraText.small.copyWith(color: AuraSurface.muted),
      ),
    );
  }
}

class _SubmittedStatusPanel extends StatelessWidget {
  const _SubmittedStatusPanel({required this.path, this.request});

  final _WizardPath path;
  final Map<String, dynamic>? request;

  @override
  Widget build(BuildContext context) {
    final status = request?['request'] is Map
        ? (request!['request'] as Map)['status']?.toString() ?? 'UNDER_REVIEW'
        : 'UNDER_REVIEW';

    final orgName = request?['request'] is Map
        ? (request!['request'] as Map)['organizationName']?.toString() ?? ''
        : '';

    return Container(
      padding: const EdgeInsets.all(AuraSpace.s24),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.xl),
        border: Border.all(color: AuraSurface.goodInk.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline_rounded, size: 32, color: AuraSurface.goodInk),
          const SizedBox(height: AuraSpace.s16),
          const Text('Request submitted', style: AuraText.title),
          const SizedBox(height: AuraSpace.s8),
          if (orgName.isNotEmpty) ...[
            Text(
              orgName,
              style: AuraText.body.copyWith(color: AuraSurface.muted),
            ),
            const SizedBox(height: AuraSpace.s8),
          ],
          Text(
            _statusDescription(status),
            style: AuraText.body.copyWith(color: AuraSurface.muted),
          ),
          const SizedBox(height: AuraSpace.s16),
          _StatusPill(status: status),
        ],
      ),
    );
  }

  String _statusDescription(String status) {
    switch (status) {
      case 'UNDER_REVIEW':
        return 'Your request has been submitted and is under review. '
            'Check your email for updates. This typically takes 1–5 business days.';
      case 'APPROVED':
        return 'Your request has been approved! You can now access your institution workspace.';
      case 'NEEDS_INFO':
        return 'The review team has requested additional information. Check your email for details.';
      default:
        return 'Your request has been submitted and is being processed.';
    }
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'APPROVED':
        bg = AuraSurface.goodBg;
        fg = AuraSurface.goodInk;
        label = 'Approved';
      case 'REJECTED':
        bg = AuraSurface.dangerBg;
        fg = AuraSurface.dangerInk;
        label = 'Not approved';
      case 'NEEDS_INFO':
        bg = AuraSurface.warnBg;
        fg = AuraSurface.warnInk;
        label = 'Needs information';
      case 'UNDER_REVIEW':
      default:
        bg = AuraSurface.infoBg;
        fg = AuraSurface.infoInk;
        label = 'Under review';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: AuraText.small.copyWith(color: fg, fontWeight: FontWeight.w700)),
    );
  }
}

class _NextStepsPanel extends StatelessWidget {
  const _NextStepsPanel({required this.path});

  final _WizardPath path;

  @override
  Widget build(BuildContext context) {
    final steps = [
      if (path == _WizardPath.create)
        const _NextStep(
          icon: Icons.mark_email_unread_outlined,
          title: 'Verify your email',
          subtitle: 'Check your inbox and click the verification link.',
        ),
      const _NextStep(
        icon: Icons.hourglass_empty_rounded,
        title: 'Wait for review',
        subtitle: 'Aura admins will review your request and follow up by email.',
      ),
      const _NextStep(
        icon: Icons.dashboard_outlined,
        title: 'Access your workspace',
        subtitle: 'Once approved, sign in at /institution/sign-in to access your institution dashboard.',
      ),
      const _NextStep(
        icon: Icons.domain_verification_outlined,
        title: 'Verify your domain',
        subtitle: 'After approval, add a DNS record to verify your institution\'s domain.',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(AuraSpace.s20),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.xl),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('What happens next', style: AuraText.title),
          const SizedBox(height: AuraSpace.s16),
          ...steps.asMap().entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: AuraSpace.s12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AuraSurface.elevated,
                        borderRadius: BorderRadius.circular(AuraRadius.pill),
                        border: Border.all(color: AuraSurface.divider),
                      ),
                      child: Icon(entry.value.icon, size: 15, color: AuraSurface.accent),
                    ),
                    const SizedBox(width: AuraSpace.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.value.title, style: AuraText.small.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(entry.value.subtitle, style: AuraText.small.copyWith(color: AuraSurface.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: AuraSpace.s8),
          GestureDetector(
            onTap: () => context.go('/institution/sign-in'),
            child: Text(
              'Go to institution sign in →',
              style: AuraText.small.copyWith(color: AuraSurface.accent, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _NextStep {
  const _NextStep({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;
}

class _SuccessPanel extends StatelessWidget {
  const _SuccessPanel({
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_outline_rounded, size: 36, color: AuraSurface.goodInk),
        const SizedBox(height: AuraSpace.s16),
        Text(title, style: AuraText.headline),
        const SizedBox(height: AuraSpace.s8),
        Text(message, style: AuraText.body.copyWith(color: AuraSurface.muted)),
        const SizedBox(height: AuraSpace.s24),
        AuraPrimaryButton(label: primaryLabel, onPressed: onPrimary),
        if (secondaryLabel != null && onSecondary != null) ...[
          const SizedBox(height: AuraSpace.s12),
          GestureDetector(
            onTap: onSecondary,
            child: Text(secondaryLabel!, style: AuraText.small.copyWith(color: AuraSurface.muted)),
          ),
        ],
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s12),
      decoration: BoxDecoration(
        color: AuraSurface.dangerBg,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.dangerInk.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, size: 16, color: AuraSurface.dangerInk),
          const SizedBox(width: AuraSpace.s8),
          Expanded(child: Text(message, style: AuraText.small.copyWith(color: AuraSurface.dangerInk))),
        ],
      ),
    );
  }
}

class _TrustNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        color: AuraSurface.elevated,
        borderRadius: BorderRadius.circular(AuraRadius.xl),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How Aura institution trust works', style: AuraText.small.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AuraSpace.s8),
          const _TrustLine(icon: Icons.person_outlined, text: 'Personal and institutional identities are kept separate.'),
          const _TrustLine(icon: Icons.verified_outlined, text: 'Authority is granted only after review and verification.'),
          const _TrustLine(icon: Icons.lock_outlined, text: 'Institutional actions are audited and role-gated.'),
          const _TrustLine(icon: Icons.domain_verification_outlined, text: 'Domain verification confirms institutional ownership.'),
        ],
      ),
    );
  }
}

class _TrustLine extends StatelessWidget {
  const _TrustLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AuraSurface.muted),
          const SizedBox(width: AuraSpace.s8),
          Expanded(child: Text(text, style: AuraText.small.copyWith(color: AuraSurface.muted))),
        ],
      ),
    );
  }
}

class _RedirectingStep extends StatelessWidget {
  const _RedirectingStep({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: AuraSpace.s32),
          const CircularProgressIndicator(),
          const SizedBox(height: AuraSpace.s16),
          Text(message, style: AuraText.body.copyWith(color: AuraSurface.muted)),
        ],
      ),
    );
  }
}

class _AuthRequiredDialog extends StatelessWidget {
  const _AuthRequiredDialog({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AuraSurface.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AuraRadius.xl)),
      title: const Text('Sign in required', style: AuraText.title),
      content: Text(
        'This path requires you to be signed in to your personal Aura account. '
        'Sign in first, then return here.',
        style: AuraText.body.copyWith(color: AuraSurface.muted),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        AuraPrimaryButton(
          label: 'Sign in',
          onPressed: onSignIn,
        ),
      ],
    );
  }
}
