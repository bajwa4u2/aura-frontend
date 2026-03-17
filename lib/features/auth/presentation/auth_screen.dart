import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../auth_controller.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.redirectTo});

  final String? redirectTo;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _busy = false;
  bool _obscurePassword = true;
  String? _error;

  String? _safeRedirectOrNull(String? r) {
    final v = (r ?? '').trim();
    if (v.isEmpty) return null;
    if (!v.startsWith('/')) return null;
    return v;
  }

  String _withRedirect(String path) {
    final redirect = _safeRedirectOrNull(widget.redirectTo);
    if (redirect == null) return path;
    return '$path?redirect=${Uri.encodeComponent(redirect)}';
  }

  String? _emailValidator(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Email is required';

    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
    if (!ok) return 'Enter a valid email';

    return null;
  }

  String? _passwordValidator(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Password is required';
    return null;
  }

  String _humanizeLoginError(Object error) {
    final raw = error.toString().trim();
    final msg = raw.toLowerCase();

    if (msg.isEmpty) {
      return 'We could not sign you in right now. Please try again.';
    }

    if (msg.contains('invalid credentials') ||
        msg.contains('invalid login') ||
        msg.contains('wrong password') ||
        msg.contains('incorrect password') ||
        msg.contains('incorrect email') ||
        msg.contains('incorrect email or password') ||
        msg.contains('wrong email or password') ||
        msg.contains('email or password is incorrect') ||
        msg.contains('invalid email or password') ||
        msg.contains('unauthorized') ||
        msg.contains('401')) {
      return 'The email or password does not look right.';
    }

    if (msg.contains('email not verified') ||
        msg.contains('verify your email') ||
        msg.contains('email verification required') ||
        msg.contains('unverified')) {
      return 'Please verify your email first, then try signing in again.';
    }

    if (msg.contains('account disabled') ||
        msg.contains('account locked') ||
        msg.contains('account suspended')) {
      return 'This account is not available right now. Please contact support if needed.';
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

    if (msg.contains('429') || msg.contains('too many requests')) {
      return 'Too many attempts in a short time. Please wait a little and try again.';
    }

    if (msg.contains('403') || msg.contains('forbidden')) {
      return 'This sign-in request could not be completed right now.';
    }

    return 'We could not sign you in right now. Please try again.';
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    if (_busy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final email = _emailCtrl.text.trim();
      final pass = _passwordCtrl.text;

      await AuthController(ref).login(email: email, password: pass);

      // Router remains the single authority after auth state changes.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _humanizeLoginError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
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
    return AuraScaffold(
      title: 'Login',
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: AuraCard(
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Welcome back', style: AuraText.title),
                      const SizedBox(height: AuraSpace.s10),
                      Text(
                        'Sign in to continue.',
                        style: AuraText.body,
                      ),
                      const SizedBox(height: AuraSpace.s14),
                      if (_error != null) ...[
                        Container(
                          width: double.infinity,
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
                            style: AuraText.body.copyWith(
                              color: Colors.red,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: AuraSpace.s10),
                      ],
                      TextFormField(
                        controller: _emailCtrl,
                        enabled: !_busy,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _decoration(
                          label: 'Email',
                          hint: 'name@example.com',
                        ),
                        validator: _emailValidator,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.username, AutofillHints.email],
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(RegExp(r'\s')),
                        ],
                      ),
                      const SizedBox(height: AuraSpace.s10),
                      TextFormField(
                        controller: _passwordCtrl,
                        enabled: !_busy,
                        obscureText: _obscurePassword,
                        decoration: _decoration(
                          label: 'Password',
                          suffixIcon: IconButton(
                            onPressed: _busy
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
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _busy ? null : _login(),
                      ),
                      const SizedBox(height: AuraSpace.s14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _busy ? null : _login,
                          child: Text(_busy ? 'Signing in…' : 'Sign in'),
                        ),
                      ),
                      const SizedBox(height: AuraSpace.s10),
                      Row(
                        children: [
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => context.push(_withRedirect('/forgot-password')),
                            child: const Text('Forgot password'),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => context.push(_withRedirect('/register')),
                            child: const Text('Create account'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}