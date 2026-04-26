import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
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
    if (!ok) {
      return 'Handle can use letters, numbers, underscores, and dots only';
    }

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
    if (t.length < 8) {
      return 'Password must be at least 8 characters';
    }
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

    if (msg.isEmpty) {
      return 'We could not create your account right now. Please try again.';
    }

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

    if (msg.contains('invalid email') ||
        msg.contains('email is invalid') ||
        msg.contains('must be a valid email')) {
      return 'Please enter a valid email address.';
    }

    if (msg.contains('password') && msg.contains('weak')) {
      return 'Please choose a stronger password.';
    }

    if (msg.contains('password') && msg.contains('at least 8')) {
      return 'Password must be at least 8 characters.';
    }

    if (msg.contains('network error') ||
        msg.contains('socketexception') ||
        msg.contains('connection error') ||
        msg.contains('connection refused') ||
        msg.contains('failed host lookup') ||
        msg.contains('timed out') ||
        msg.contains('timeoutexception')) {
      return 'We could not reach the server. Check your connection and try again.';
    }

    if (msg.contains('500') ||
        msg.contains('internal server error') ||
        msg.contains('server error')) {
      return 'Something went wrong on our side. Please try again in a moment.';
    }

    if (msg.contains('400') ||
        msg.contains('bad request') ||
        msg.contains('validation')) {
      return 'Some details need another look. Please review the form and try again.';
    }

    if (msg.contains('403') || msg.contains('forbidden')) {
      return 'This request could not be completed right now.';
    }

    if (msg.contains('429') || msg.contains('too many requests')) {
      return 'Too many attempts in a short time. Please wait a little and try again.';
    }

    return 'We could not create your account right now. Please try again.';
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _error = null;
    });

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

      await repo.register(
        email: email,
        password: _password.text,
        firstName: firstName,
        lastName: lastName,
        handle: handle,
        displayName: displayName,
      );

      ref.invalidate(emailVerifiedProvider);
      ref.invalidate(authStatusProvider);
      ref.invalidate(isAuthedProvider);

      if (!mounted) return;

      final redirect = _safeRedirect(widget.redirectTo);
      context.go(
        '/verify-pending?email=${Uri.encodeComponent(email)}&redirect=${Uri.encodeComponent(redirect)}',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _humanizeRegisterError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _decoration({
    required String label,
    String? hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixIcon: suffixIcon,
      border: const OutlineInputBorder(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final redirectPath = _safeRedirect(widget.redirectTo);
    final redirect = Uri.encodeComponent(redirectPath);
    final isInstitutionEntry = _isInstitutionRedirect(widget.redirectTo);

    final title =
        isInstitutionEntry ? 'Continue to institution access' : 'Join Aura';

    final subtitle = isInstitutionEntry
        ? 'Create your account first. After sign-in, Aura will continue to the institutional access check.'
        : 'Create your account. We’ll email you a verification link.';

    final ctaLabel = _loading ? 'Creating…' : 'Create account';

    final loginLabel = isInstitutionEntry
        ? 'Already have an account? Sign in to continue'
        : 'Already have an account? Log in';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    const SizedBox(height: 24),
                    if (isInstitutionEntry) ...[
                      const Text(
                        'Institutional access',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(subtitle),
                    const SizedBox(height: 16),
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _firstName,
                      enabled: !_loading,
                      decoration: _decoration(
                        label: 'First name',
                        hint: 'Private',
                      ),
                      validator: (v) => _nameValidator(v, 'First name'),
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.givenName],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _lastName,
                      enabled: !_loading,
                      decoration: _decoration(
                        label: 'Last name',
                        hint: 'Private',
                      ),
                      validator: (v) => _nameValidator(v, 'Last name'),
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.familyName],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _displayName,
                      enabled: !_loading,
                      decoration: _decoration(
                        label: 'Display name',
                        hint: 'Public name shown on Aura',
                      ),
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.nickname],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _handle,
                      enabled: !_loading,
                      decoration: _decoration(
                        label: 'Handle',
                        hint: 'Your public identity handle',
                      ),
                      validator: _handleValidator,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-Z0-9_.]'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _email,
                      enabled: !_loading,
                      decoration: _decoration(
                        label: 'Email',
                        hint: 'name@example.com',
                      ),
                      validator: _emailValidator,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.email],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _password,
                      enabled: !_loading,
                      decoration: _decoration(
                        label: 'Password',
                        hint: 'At least 8 characters',
                        suffixIcon: IconButton(
                          onPressed: _loading
                              ? null
                              : () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                        ),
                      ),
                      validator: _passwordValidator,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _confirmPassword,
                      enabled: !_loading,
                      decoration: _decoration(
                        label: 'Confirm password',
                        hint: 'Re-enter your password',
                        suffixIcon: IconButton(
                          onPressed: _loading
                              ? null
                              : () {
                                  setState(() {
                                    _obscureConfirmPassword =
                                        !_obscureConfirmPassword;
                                  });
                                },
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                        ),
                      ),
                      validator: (v) => _req(v, 'Confirm password'),
                      obscureText: _obscureConfirmPassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.newPassword],
                      onFieldSubmitted: (_) => _loading ? null : _submit(),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: Text(ctaLabel),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => context.go('/login?redirect=$redirect'),
                      child: Text(loginLabel),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}