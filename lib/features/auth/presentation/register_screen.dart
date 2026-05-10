import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../auth/auth_repository.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({
    super.key,
    this.redirectTo,
  });

  final String? redirectTo;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _displayName = TextEditingController();
  final _handle = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _error;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _displayName.dispose();
    _handle.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  String? _req(String? v, String label) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return '$label is required';
    return null;
  }

  String? _nameValidator(String? v, String label) {
    final required = _req(v, label);
    if (required != null) return required;
    final t = (v ?? '').trim();
    if (t.length < 2) return '$label looks too short';
    return null;
  }

  String? _handleValidator(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    final ok = RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(t);
    if (!ok) return 'Handle can use letters, numbers, underscores, and dots only';
    if (t.length < 3) return 'Handle must be at least 3 characters';
    if (t.length > 30) return 'Handle is too long';
    return null;
  }

  String? _emailValidator(String? v) {
    final required = _req(v, 'Email');
    if (required != null) return required;
    final t = (v ?? '').trim();
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t);
    if (!ok) return 'Enter a valid email';
    return null;
  }

  String? _passwordValidator(String? v) {
    final required = _req(v, 'Password');
    if (required != null) return required;
    final t = v ?? '';
    if (t.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  String _defaultHandleFromEmail(String email) {
    final e = email.trim();
    final at = e.indexOf('@');
    if (at > 0) return e.substring(0, at);
    return e.isEmpty ? 'member' : e;
  }

  String _defaultDisplayName(String firstName, String lastName, String handle) {
    final fn = firstName.trim();
    final ln = lastName.trim();
    final full = ('$fn $ln').trim();
    if (full.isNotEmpty) return full;
    return handle.trim().isEmpty ? 'Member' : handle.trim();
  }

  String _safeRedirect(String? r) {
    final v = (r ?? '').trim();
    if (v.isEmpty) return '/home';
    if (!v.startsWith('/')) return '/home';
    return v;
  }

  bool _isInstitutionRedirect(String? r) {
    final v = _safeRedirect(r);
    return v == '/enter-institution' || v.startsWith('/enter-institution?');
  }

  String _humanizeRegisterError(Object error) {
    final raw = error.toString().trim();
    final msg = raw.toLowerCase();

    if (msg.isEmpty) return 'We could not create your account right now. Please try again.';

    if (msg.contains('email already') ||
        msg.contains('email is already') ||
        msg.contains('already exists') && msg.contains('email') ||
        msg.contains('duplicate') && msg.contains('email') ||
        msg.contains('unique') && msg.contains('email')) {
      return 'That email is already in use. Try signing in instead.';
    }

    if (msg.contains('handle already') ||
        msg.contains('username already') ||
        msg.contains('duplicate') && msg.contains('handle') ||
        msg.contains('unique') && msg.contains('handle') ||
        msg.contains('unique') && msg.contains('username')) {
      return 'That handle is already taken. Please choose another one.';
    }

    if (msg.contains('invalid email') || msg.contains('email is invalid') ||
        msg.contains('must be a valid email')) {
      return 'Please enter a valid email address.';
    }

    if (msg.contains('password') && msg.contains('weak')) {
      return 'Please choose a stronger password.';
    }

    if (msg.contains('network error') ||
        msg.contains('socketexception') ||
        msg.contains('connection error') ||
        msg.contains('failed host lookup') ||
        msg.contains('timed out')) {
      return 'We could not reach the server. Check your connection and try again.';
    }

    if (msg.contains('500') || msg.contains('internal server error')) {
      return 'Something went wrong on our side. Please try again in a moment.';
    }

    if (msg.contains('429') || msg.contains('too many requests')) {
      return 'Too many attempts in a short time. Please wait a little and try again.';
    }

    return 'We could not create your account right now. Please try again.';
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);

    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_password.text != _confirmPassword.text) {
      setState(() => _error = 'Password and confirm password do not match.');
      return;
    }

    setState(() => _loading = true);

    try {
      final repo = ref.read(authRepositoryProvider);
      final email = _email.text.trim();
      final firstName = _firstName.text.trim();
      final lastName = _lastName.text.trim();

      final handle = _handle.text.trim().isEmpty
          ? _defaultHandleFromEmail(email)
          : _handle.text.trim();

      final displayName = _displayName.text.trim().isEmpty
          ? _defaultDisplayName(firstName, lastName, handle)
          : _displayName.text.trim();

      final result = await repo.register(
        email: email,
        password: _password.text,
        firstName: firstName,
        lastName: lastName,
        handle: handle,
        displayName: displayName,
      );

      final emailSent = result['emailSent'] != false;

      ref.invalidate(emailVerifiedProvider);
      ref.invalidate(authStatusProvider);
      ref.invalidate(isAuthedProvider);

      if (!mounted) return;

      final redirect = _safeRedirect(widget.redirectTo);
      final qp = <String, String>{
        'email': email,
        'redirect': redirect,
      };
      if (!emailSent) qp['emailSent'] = '0';

      context.go(
        Uri(path: '/verify-pending', queryParameters: qp).toString(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _humanizeRegisterError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final redirectPath = _safeRedirect(widget.redirectTo);
    final redirect = Uri.encodeComponent(redirectPath);
    final isInstitutionEntry = _isInstitutionRedirect(widget.redirectTo);

    final title = isInstitutionEntry ? 'Continue to institution access' : 'Join Aura';
    final subtitle = isInstitutionEntry
        ? 'Create your account first. After sign-in, Aura will continue to the institutional access check.'
        : "Create your account. We'll email you a verification link.";

    return AuraScaffold(
      showHeader: false,
      body: AuraPageShell(
        maxWidth: 1160,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 960;
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 24 + bottomInset),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1160),
                    child: isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _RegisterHero(
                                  isInstitution: isInstitutionEntry,
                                ),
                              ),
                              const SizedBox(width: AuraSpace.s16),
                              SizedBox(
                                width: 480,
                                child: _RegisterFormCard(
                                  title: title,
                                  subtitle: subtitle,
                                  loading: _loading,
                                  error: _error,
                                  formKey: _formKey,
                                  firstName: _firstName,
                                  lastName: _lastName,
                                  displayName: _displayName,
                                  handle: _handle,
                                  email: _email,
                                  password: _password,
                                  confirmPassword: _confirmPassword,
                                  obscurePassword: _obscurePassword,
                                  obscureConfirmPassword: _obscureConfirmPassword,
                                  nameValidator: _nameValidator,
                                  handleValidator: _handleValidator,
                                  emailValidator: _emailValidator,
                                  passwordValidator: _passwordValidator,
                                  onTogglePassword: () => setState(
                                      () => _obscurePassword = !_obscurePassword),
                                  onToggleConfirmPassword: () => setState(() =>
                                      _obscureConfirmPassword = !_obscureConfirmPassword),
                                  onSubmit: _submit,
                                  onSignIn: () => context.go('/login?redirect=$redirect'),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              _RegisterHero(isInstitution: isInstitutionEntry),
                              const SizedBox(height: AuraSpace.s16),
                              _RegisterFormCard(
                                title: title,
                                subtitle: subtitle,
                                loading: _loading,
                                error: _error,
                                formKey: _formKey,
                                firstName: _firstName,
                                lastName: _lastName,
                                displayName: _displayName,
                                handle: _handle,
                                email: _email,
                                password: _password,
                                confirmPassword: _confirmPassword,
                                obscurePassword: _obscurePassword,
                                obscureConfirmPassword: _obscureConfirmPassword,
                                nameValidator: _nameValidator,
                                handleValidator: _handleValidator,
                                emailValidator: _emailValidator,
                                passwordValidator: _passwordValidator,
                                onTogglePassword: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                                onToggleConfirmPassword: () => setState(() =>
                                    _obscureConfirmPassword = !_obscureConfirmPassword),
                                onSubmit: _submit,
                                onSignIn: () => context.go('/login?redirect=$redirect'),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Hero panel ─────────────────────────────────────────────────────────────

class _RegisterHero extends StatelessWidget {
  const _RegisterHero({required this.isInstitution});

  final bool isInstitution;

  @override
  Widget build(BuildContext context) {
    final features = isInstitution
        ? const [
            _HeroFeatureRow(icon: Icons.apartment_rounded, label: 'Access institutional resources and announcements'),
            _HeroFeatureRow(icon: Icons.verified_user_outlined, label: 'Verify your affiliation with trusted institutions'),
            _HeroFeatureRow(icon: Icons.lock_outline_rounded, label: 'Private by default — only handle and name are public'),
          ]
        : const [
            _HeroFeatureRow(icon: Icons.edit_note_rounded, label: 'Publish writing, media, and long-form works'),
            _HeroFeatureRow(icon: Icons.apartment_rounded, label: 'Connect with institutions and build credentials'),
            _HeroFeatureRow(icon: Icons.mail_outline_rounded, label: 'Structured correspondence with the people that matter'),
          ];

    return AuraCard(
      padding: const EdgeInsets.all(AuraSpace.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuraBadge(
            label: isInstitution ? 'Institution access' : 'New membership',
            icon: isInstitution
                ? Icons.apartment_outlined
                : Icons.person_add_alt_1_rounded,
          ),
          const SizedBox(height: AuraSpace.s16),
          Text(
            isInstitution ? 'Create your account' : 'Join Aura',
            style: AuraText.title.copyWith(fontSize: 34, height: 1.05),
          ),
          const SizedBox(height: AuraSpace.s12),
          Text(
            isInstitution
                ? 'An account is needed to continue to institutional access. Your account stays private; only your handle and display name are public.'
                : 'Aura is a place for serious work — writing, correspondence, institutions, and publishing history.',
            style: AuraText.body.copyWith(color: AuraSurface.muted, height: 1.6),
          ),
          const SizedBox(height: AuraSpace.s20),
          ...features.expand((f) => [f, const SizedBox(height: AuraSpace.s10)]).toList()..removeLast(),
          const SizedBox(height: AuraSpace.s20),
          Text(
            isInstitution
                ? 'After creating your account, you will be guided through the institutional verification flow.'
                : 'Your identity, publication record, and conversations stay with you.',
            style: AuraText.small.copyWith(color: AuraSurface.faint, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _HeroFeatureRow extends StatelessWidget {
  const _HeroFeatureRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AuraSurface.accentSoft,
            borderRadius: BorderRadius.circular(AuraRadius.sm),
            border: Border.all(color: AuraSurface.accent.withValues(alpha: 0.2)),
          ),
          child: Icon(icon, size: 14, color: AuraSurface.accentText),
        ),
        const SizedBox(width: AuraSpace.s10),
        Expanded(
          child: Text(label, style: AuraText.small.copyWith(color: AuraSurface.muted, height: 1.4)),
        ),
      ],
    );
  }
}

// ── Form card ──────────────────────────────────────────────────────────────

class _RegisterFormCard extends StatelessWidget {
  const _RegisterFormCard({
    required this.title,
    required this.subtitle,
    required this.loading,
    required this.error,
    required this.formKey,
    required this.firstName,
    required this.lastName,
    required this.displayName,
    required this.handle,
    required this.email,
    required this.password,
    required this.confirmPassword,
    required this.obscurePassword,
    required this.obscureConfirmPassword,
    required this.nameValidator,
    required this.handleValidator,
    required this.emailValidator,
    required this.passwordValidator,
    required this.onTogglePassword,
    required this.onToggleConfirmPassword,
    required this.onSubmit,
    required this.onSignIn,
  });

  final String title;
  final String subtitle;
  final bool loading;
  final String? error;
  final GlobalKey<FormState> formKey;
  final TextEditingController firstName;
  final TextEditingController lastName;
  final TextEditingController displayName;
  final TextEditingController handle;
  final TextEditingController email;
  final TextEditingController password;
  final TextEditingController confirmPassword;
  final bool obscurePassword;
  final bool obscureConfirmPassword;
  final String? Function(String?, String) nameValidator;
  final String? Function(String?) handleValidator;
  final String? Function(String?) emailValidator;
  final String? Function(String?) passwordValidator;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirmPassword;
  final VoidCallback onSubmit;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Form(
        key: formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: AuraText.title.copyWith(fontSize: 22)),
              const SizedBox(height: AuraSpace.s6),
              Text(
                subtitle,
                style: AuraText.small.copyWith(color: AuraSurface.muted, height: 1.4),
              ),
              if (error != null) ...[
                const SizedBox(height: AuraSpace.s12),
                AuraErrorState(title: 'Registration failed', body: error!),
              ],
              const SizedBox(height: AuraSpace.s14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: firstName,
                      enabled: !loading,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.givenName],
                      style: AuraText.body,
                      validator: (v) => nameValidator(v, 'First name'),
                      decoration: const InputDecoration(
                        labelText: 'First name',
                        hintText: 'Private',
                      ),
                    ),
                  ),
                  const SizedBox(width: AuraSpace.s10),
                  Expanded(
                    child: TextFormField(
                      controller: lastName,
                      enabled: !loading,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.familyName],
                      style: AuraText.body,
                      validator: (v) => nameValidator(v, 'Last name'),
                      decoration: const InputDecoration(
                        labelText: 'Last name',
                        hintText: 'Private',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AuraSpace.s10),
              TextFormField(
                controller: displayName,
                enabled: !loading,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.nickname],
                style: AuraText.body,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  hintText: 'Public name shown on Aura',
                ),
              ),
              const SizedBox(height: AuraSpace.s10),
              TextFormField(
                controller: handle,
                enabled: !loading,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_.]')),
                ],
                style: AuraText.body,
                validator: handleValidator,
                decoration: const InputDecoration(
                  labelText: 'Handle',
                  hintText: 'Your public identity handle',
                ),
              ),
              const SizedBox(height: AuraSpace.s10),
              TextFormField(
                controller: email,
                enabled: !loading,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                style: AuraText.body,
                validator: emailValidator,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'name@example.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: AuraSpace.s10),
              TextFormField(
                controller: password,
                enabled: !loading,
                obscureText: obscurePassword,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                style: AuraText.body,
                validator: passwordValidator,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'At least 8 characters',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: loading ? null : onTogglePassword,
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: AuraSurface.muted,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AuraSpace.s10),
              TextFormField(
                controller: confirmPassword,
                enabled: !loading,
                obscureText: obscureConfirmPassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                style: AuraText.body,
                onFieldSubmitted: (_) => loading ? null : onSubmit(),
                decoration: InputDecoration(
                  labelText: 'Confirm password',
                  hintText: 'Re-enter your password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: loading ? null : onToggleConfirmPassword,
                    icon: Icon(
                      obscureConfirmPassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: AuraSurface.muted,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AuraSpace.s16),
              SizedBox(
                width: double.infinity,
                child: AuraPrimaryButton(
                  label: loading ? 'Creating account…' : 'Create account',
                  onPressed: loading ? null : onSubmit,
                  icon: Icons.arrow_forward_rounded,
                ),
              ),
              const SizedBox(height: AuraSpace.s10),
              Center(
                child: AuraGhostButton(
                  label: 'Already have an account? Sign in',
                  onPressed: loading ? null : onSignIn,
                  icon: Icons.login_rounded,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
