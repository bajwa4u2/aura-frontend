import 'package:flutter/material.dart';
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
    if (!s.contains('@') || !s.contains('.')) return 'Enter a valid email';
    return null;
  }

  String? _passwordValidator(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Password is required';
    return null;
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
        _error = e.toString().replaceFirst('Exception: ', '');
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
                      Text(
                        _error!,
                        style: AuraText.body.copyWith(height: 1.3),
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
    );
  }
}