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
import '../../../core/ui/substrate_chip.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/trust/trust_marks.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/institutions/institution_route_authority.dart';
import 'institution_kinds.dart';

// ─── Wizard entry point ───────────────────────────────────────────────────────

class InstitutionOnboardingWizard extends ConsumerStatefulWidget {
  const InstitutionOnboardingWizard({
    super.key,
    this.mode,
    this.inviteCode,
  });

  /// 'create' | 'claim' | 'join'
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
  // DD-42 (2026-10-08): the kind is asked first, from the seven kinds.
  InstitutionKind? _kind;
  Map<String, dynamic>? _selectedInstitution; // for claim path

  // Your role. The person is the one signed in: name and email come from
  // their account and are never typed again (DD-42).
  final _phone = TextEditingController();
  final _roleTitle = TextEditingController();
  final _purpose = TextEditingController();

  // Step 4 — Join by invite
  final _inviteCode = TextEditingController();

  // Submission state
  bool _submitting = false;
  bool _submitted = false;
  String? _error;
  Map<String, dynamic>? _submittedRequest;


  @override
  void initState() {
    super.initState();
    if (widget.inviteCode != null) {
      _inviteCode.text = widget.inviteCode!;
    }
    // "signin" used to send people to a separate institution sign-in. There
    // is one identity (founder ruling 2026-08-16; DD-42): it shows the
    // ordinary choices.
    _path = _pathFromMode(widget.mode);
  }

  @override
  void dispose() {
    _orgName.dispose();
    _website.dispose();
    _jurisdiction.dispose();
    _description.dispose();
    _phone.dispose();
    _roleTitle.dispose();
    _purpose.dispose();
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
      default:
        return null;
    }
  }

  bool get _isAuthed => ref.read(isAuthedProvider);

  int get _totalSteps {
    if (_path == _WizardPath.join) return 2; // invite code + status
    // kind + institution + what you'll need + your role + review, then status
    if (_path == _WizardPath.create) return 6;
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

    if (_path == _WizardPath.create && _step == 1 && _kind == null) {
      setState(() => _error = 'Choose what kind of institution this is.');
      return;
    }
    if (_isIdentityStep && !_validateIdentityStep()) return;

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

  bool get _isIdentityStep =>
      (_path == _WizardPath.create && _step == 2) ||
      (_path == _WizardPath.claim && _step == 1);

  bool _validateIdentityStep() {
    if (_orgName.text.trim().isEmpty) {
      setState(() => _error = 'Enter the institution name.');
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
    if (!_isAuthed) {
      _showAuthRequiredDialog();
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      Map<String, dynamic> result;

      if (_path == _WizardPath.create) {
        result = await _submitCreate(dio);
      } else if (_path == _WizardPath.claim) {
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
    String? opt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    final res = await dio.post('/institutions/create-request', data: {
      'kind': _kind!.wire,
      'organizationName': _orgName.text.trim(),
      'websiteUrl': opt(_website),
      'jurisdiction': opt(_jurisdiction),
      'roleTitle': opt(_roleTitle),
      'phone': opt(_phone),
      'purpose': opt(_description) ?? opt(_purpose),
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
      final err = data['error'];
      final msg = err is Map ? err['message'] : data['message'];
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

    if (_path == _WizardPath.join) {
      if (_submitted) return _buildJoinSuccess();
      return _buildJoinStep();
    }

    // Create / Claim
    if (_submitted || _step >= _totalSteps) return _buildStatusStep();

    if (_path == _WizardPath.create) {
      switch (_step) {
        case 1:
          return _buildKindStep();
        case 2:
          return _buildIdentityStep();
        case 3:
          return _buildProofStep();
        case 4:
          return _buildRepresentativeStep();
        case 5:
          return _buildReviewStep();
      }
      return _buildStatusStep();
    }
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
        if (_isAuthed) ...[
          const _MyRequestsSection(),
        ],
        _PathCard(
          icon: Icons.apartment_outlined,
          title: 'Create new institution',
          subtitle: 'Set up your institution on Aura for the first time.',
          onTap: () {
            if (!_isAuthed) {
              _showAuthRequiredDialog();
              return;
            }
            _selectPath(_WizardPath.create);
          },
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
        // RETIRED (founder ruling 2026-08-16): "Existing institution admin /
        // Sign in to your existing institution workspace." Aura has ONE
        // authenticated Person identity — an Institution is not a second
        // authentication universe. A Person with an institution relationship
        // reaches it through canonical workspace access; a Person without
        // one is here to establish one. The three legitimate onboarding
        // intentions remain below. NOTE: "Join with invite" still runs on
        // legacy institution invite-code mechanics
        // (POST /institutions/invites/accept) — its convergence onto the
        // foundational Invitation System is C7-chartered (Institutional
        // Conversation & Desk: membership/join/invite reconstruction).
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
              : 'The institution',
          subtitle: _path == _WizardPath.claim
              ? 'Search for the institution already listed on Aura, then tell us about your role.'
              : (_kind == null ? 'Basic information about the institution.' : _kind!.title),
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
        AuraInput(
          controller: _website,
          label: 'Website (optional)',
          hint: 'https://yourorganisation.org — leave blank if there is none',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepTitle(
          title: 'Your role',
          subtitle: 'You are asking as yourself. Your name and email come from your Aura account.',
        ),
        const SizedBox(height: AuraSpace.s16),
        const _YouCard(),
        const SizedBox(height: AuraSpace.s20),
        AuraInput(
          controller: _roleTitle,
          label: 'Your role or title',
          hint: 'e.g. Secretary, Imam, Principal, Director',
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
          label: 'Anything the reviewer should know? (optional)',
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
              label: 'Review',
              icon: Icons.checklist_rounded,
              onPressed: _next,
            ),
          ],
        ),
      ],
    );
  }

  // ── Create, step 1: what kind of institution ──────────────────────────────

  Widget _buildKindStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepTitle(
          title: 'What kind of institution is it?',
          subtitle: 'This decides what you are asked to show and how Aura sets up your workspace.',
        ),
        const SizedBox(height: AuraSpace.s20),
        for (final k in InstitutionKind.all) ...[
          _KindOption(
            kind: k,
            selected: _kind?.wire == k.wire,
            onTap: () => setState(() {
              _kind = k;
              _error = null;
            }),
          ),
          const SizedBox(height: AuraSpace.s10),
        ],
        if (_error != null) ...[
          const SizedBox(height: AuraSpace.s12),
          _ErrorBanner(message: _error!),
        ],
        const SizedBox(height: AuraSpace.s16),
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

  // ── Create, step 3: what you'll need, in this kind's words ────────────────

  Widget _buildProofStep() {
    final k = _kind!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepTitle(
          title: 'What you will be asked to show',
          subtitle: 'After your request is approved, you show two things. You can prepare them now.',
        ),
        const SizedBox(height: AuraSpace.s20),
        _NeedCard(
          icon: Icons.verified_outlined,
          title: 'That the institution exists',
          body: k.existenceProof,
        ),
        const SizedBox(height: AuraSpace.s12),
        _NeedCard(
          icon: Icons.badge_outlined,
          title: 'That you may speak for it',
          body: k.authorityProof,
        ),
        const SizedBox(height: AuraSpace.s12),
        Text(
          k.alwaysReviewed
              ? 'A person at Aura reviews every ${k.title.toLowerCase()}.'
              : 'A person at Aura reviews it when the checks cannot confirm it on their own.',
          style: AuraText.small.copyWith(color: AuraSurface.muted),
        ),
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

  // ── Step 3: Review & submit ────────────────────────────────────────────────

  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepTitle(
          title: 'Review and send',
          subtitle: 'Check everything before sending your request for review.',
        ),
        const SizedBox(height: AuraSpace.s24),
        _ReviewSection(title: 'Institution', rows: [
          _ReviewRow('Name', _orgName.text.trim()),
          if (_kind != null) _ReviewRow('Kind', _kind!.title),
          if (_website.text.trim().isNotEmpty) _ReviewRow('Website', _website.text.trim()),
          if (_jurisdiction.text.trim().isNotEmpty) _ReviewRow('Location', _jurisdiction.text.trim()),
          if (_description.text.trim().isNotEmpty) _ReviewRow('Description', _description.text.trim()),
        ]),
        const SizedBox(height: AuraSpace.s16),
        _ReviewSection(title: 'You', rows: [
          const _ReviewRow('Asking as', 'Yourself, from your Aura account'),
          if (_roleTitle.text.trim().isNotEmpty) _ReviewRow('Role', _roleTitle.text.trim()),
          if (_phone.text.trim().isNotEmpty) _ReviewRow('Phone', _phone.text.trim()),
          if (_purpose.text.trim().isNotEmpty) _ReviewRow('Notes', _purpose.text.trim()),
        ]),
        const SizedBox(height: AuraSpace.s20),
        _AuthorityNote(path: _path!),
        if (_error != null) ...[
          const SizedBox(height: AuraSpace.s12),
          _ErrorBanner(message: _error!),
        ],
        const SizedBox(height: AuraSpace.s24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AuraPrimaryButton(
              label: _submitting ? 'Sending…' : 'Send for review',
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
      primaryLabel: 'Open the institution',
      // Overview is for administrators; a new member enters the
      // institution where members belong (inventory 2026-10-08).
      onPrimary: () {
        final id = _asMap(data['institution'])['id']?.toString() ?? '';
        context.go(institutionEntryDestination(id));
      },
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

enum _WizardPath { create, claim, join }

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
              // The final status screen is not a step ('Step 6 of 5').
              if (path != null && totalSteps > 1 && step > 0 && step < totalSteps)
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
              color: AuraSurface.coVerdant.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AuraRadius.card),
              border: Border.all(
                color: AuraSurface.coVerdant.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 16,
                  color: AuraSurface.coVerdant,
                ),
                const SizedBox(width: AuraSpace.s8),
                Expanded(
                  child: Text(
                    widget.selected!['name']?.toString() ??
                        'Selected institution',
                    style: AuraText.small.copyWith(
                      color: AuraSurface.coVerdant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: widget.onCleared,
                  child: const Icon(
                    Icons.close,
                    size: 16,
                    color: AuraSurface.coVerdant,
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
                  style: AuraText.small.copyWith(color: AuraSurface.coRose),
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
                          const InstitutionVerifiedIcon(
                            iconSize: 14,
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
        ? 'A person at Aura reviews this. You can speak for the institution only after your authority is confirmed.'
        : 'A person at Aura reviews this. The workspace opens on approval; you speak for the institution only after its proofs are confirmed.';

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
        border: Border.all(color: AuraSurface.coVerdant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline_rounded, size: 32, color: AuraSurface.coVerdant),
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
        return 'A person at Aura is reviewing it. You will get an email, and you can follow it '
            'under Your requests on this page.';
      case 'APPROVED':
        return 'Approved. Your institution is set up and awaits verification of its proofs.';
      case 'NEEDS_INFO':
        return 'The reviewer asked a question. Answer it under Your requests on this page.';
      default:
        return 'Your request has been submitted and is being processed.';
    }
  }
}

/// Onboarding-wizard review status rendered as a canonical SubstrateChip.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, state) = switch (status) {
      'APPROVED' => ('Approved', SubstrateChipState.verdant),
      'REJECTED' => ('Not approved', SubstrateChipState.rose),
      'NEEDS_INFO' => ('Needs information', SubstrateChipState.sun),
      _ => ('Under review', SubstrateChipState.teal),
    };
    return SubstrateChip(label: label, state: state);
  }
}

class _NextStepsPanel extends StatelessWidget {
  const _NextStepsPanel({required this.path});

  final _WizardPath path;

  @override
  Widget build(BuildContext context) {
    final steps = [
      const _NextStep(
        icon: Icons.hourglass_empty_rounded,
        title: 'A person reviews your request',
        subtitle: 'You get an email when it is decided. If they ask something, answer it here under Your requests.',
      ),
      const _NextStep(
        icon: Icons.apartment_outlined,
        title: 'Your workspace opens',
        subtitle: 'Once approved, the institution appears in your account. No separate sign-in.',
      ),
      const _NextStep(
        icon: Icons.verified_outlined,
        title: 'Show your proofs',
        subtitle: 'From the workspace, show that the institution exists and that you may speak for it.',
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
        const Icon(Icons.check_circle_outline_rounded, size: 36, color: AuraSurface.coVerdant),
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
        color: AuraSurface.coRose.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.coRose.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, size: 16, color: AuraSurface.coRose),
          const SizedBox(width: AuraSpace.s8),
          Expanded(child: Text(message, style: AuraText.small.copyWith(color: AuraSurface.coRose))),
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
          const _TrustLine(icon: Icons.person_outlined, text: 'You act as yourself. An institution speaks only through people it has authorised.'),
          const _TrustLine(icon: Icons.verified_outlined, text: 'Authority to speak for it is confirmed separately, after review.'),
          const _TrustLine(icon: Icons.lock_outlined, text: 'Institutional actions are audited and role-gated.'),
          const _TrustLine(icon: Icons.domain_verification_outlined, text: 'That the institution exists is shown with proof suited to its kind.'),
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

// ─── Onboarding by kind (DD-42, 2026-10-08) ──────────────────────────────────

/// One of the seven kinds, as a choice.
class _KindOption extends StatelessWidget {
  const _KindOption({required this.kind, required this.selected, required this.onTap});

  final InstitutionKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${kind.title}. ${kind.examples}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        child: Container(
          padding: const EdgeInsets.all(AuraSpace.s16),
          decoration: BoxDecoration(
            color: selected ? AuraSurface.elevated : AuraSurface.card,
            borderRadius: BorderRadius.circular(AuraRadius.card),
            border: Border.all(
              color: selected ? AuraSurface.accent : AuraSurface.divider,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(kind.icon, size: 22, color: selected ? AuraSurface.accent : AuraSurface.muted),
              const SizedBox(width: AuraSpace.s14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(kind.title, style: AuraText.body.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(kind.examples, style: AuraText.small.copyWith(color: AuraSurface.muted)),
                  ],
                ),
              ),
              if (selected) const Icon(Icons.check_circle_rounded, size: 20, color: AuraSurface.accent),
            ],
          ),
        ),
      ),
    );
  }
}

/// One thing the person will be asked to show.
class _NeedCard extends StatelessWidget {
  const _NeedCard({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AuraSurface.accent),
          const SizedBox(width: AuraSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AuraText.body.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: AuraSpace.s4),
                Text(body, style: AuraText.body.copyWith(color: AuraSurface.muted, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The signed-in person, as the account knows them — never retyped.
class _YouCard extends ConsumerWidget {
  const _YouCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authMeDataProvider).valueOrNull ?? const <String, dynamic>{};
    final user = me['user'] is Map ? Map<String, dynamic>.from(me['user'] as Map) : me;
    final name = (user['displayName'] ?? user['name'] ?? '').toString().trim();
    final email = (user['email'] ?? '').toString().trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AuraSpace.s14),
      decoration: BoxDecoration(
        color: AuraSurface.elevated,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_outline_rounded, size: 20, color: AuraSurface.muted),
          const SizedBox(width: AuraSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isEmpty ? 'You' : name, style: AuraText.body.copyWith(fontWeight: FontWeight.w700)),
                if (email.isNotEmpty) Text(email, style: AuraText.small.copyWith(color: AuraSurface.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The person's institution requests, and their answer when a reviewer asks.
class _MyRequestsSection extends ConsumerStatefulWidget {
  const _MyRequestsSection();

  @override
  ConsumerState<_MyRequestsSection> createState() => _MyRequestsSectionState();
}

class _MyRequestsSectionState extends ConsumerState<_MyRequestsSection> {
  List<Map<String, dynamic>> _rows = const [];
  bool _loaded = false;
  final Map<String, TextEditingController> _answers = {};
  String? _sendingId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _answers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await ref.read(dioProvider).get('/institutions/my-requests');
      final data = res.data is Map ? (res.data as Map)['data'] : res.data;
      final list = data is List ? data : const [];
      if (!mounted) return;
      setState(() {
        _rows = [for (final r in list) if (r is Map) Map<String, dynamic>.from(r)];
        _loaded = true;
      });
    } catch (_) {
      // Nothing to show is the honest fallback here; the paths below still work.
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _send(String id) async {
    final text = _answers[id]?.text.trim() ?? '';
    if (text.isEmpty) {
      setState(() => _error = 'Write your answer first.');
      return;
    }
    setState(() {
      _sendingId = id;
      _error = null;
    });
    try {
      await ref.read(dioProvider).post('/institutions/my-requests/$id/respond', data: {'message': text});
      _answers[id]?.clear();
      await _load();
    } catch (_) {
      if (mounted) setState(() => _error = 'Your answer could not be sent. Try again.');
    } finally {
      if (mounted) setState(() => _sendingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your requests', style: AuraText.title.copyWith(fontSize: 18)),
          const SizedBox(height: AuraSpace.s12),
          for (final r in _rows) ...[
            _requestCard(r),
            const SizedBox(height: AuraSpace.s10),
          ],
          if (_error != null) _ErrorBanner(message: _error!),
        ],
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> r) {
    final id = (r['id'] ?? '').toString();
    final status = (r['status'] ?? '').toString();
    final name = (r['organizationName'] ?? '').toString();
    final kind = InstitutionKind.fromWire(r['requestedKind']?.toString());
    final question = (r['reviewNotes'] ?? '').toString().trim();
    final waiting = status == 'NEEDS_INFO';
    final controller = _answers.putIfAbsent(id, TextEditingController.new);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: waiting ? AuraSurface.accent : AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AuraText.body.copyWith(fontWeight: FontWeight.w700)),
                    if (kind != null) Text(kind.title, style: AuraText.small.copyWith(color: AuraSurface.muted)),
                  ],
                ),
              ),
              _StatusPill(status: status),
            ],
          ),
          if (question.isNotEmpty && (waiting || status == 'REJECTED')) ...[
            const SizedBox(height: AuraSpace.s12),
            Text(
              waiting ? 'The reviewer asks' : 'The reviewer wrote',
              style: AuraText.small.copyWith(color: AuraSurface.muted),
            ),
            const SizedBox(height: AuraSpace.s4),
            Text(question, style: AuraText.body.copyWith(height: 1.4)),
          ],
          if (waiting) ...[
            const SizedBox(height: AuraSpace.s12),
            AuraInput(
              controller: controller,
              label: 'Your answer',
              maxLines: 4,
              minLines: 2,
              textInputAction: TextInputAction.newline,
            ),
            const SizedBox(height: AuraSpace.s12),
            Align(
              alignment: Alignment.centerRight,
              child: AuraPrimaryButton(
                label: _sendingId == id ? 'Sending…' : 'Send answer',
                icon: _sendingId == id ? null : Icons.send_rounded,
                onPressed: _sendingId == null ? () => _send(id) : null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
