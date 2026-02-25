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
  String? _error;

  String _safeRedirect(String? r) {
    final v = (r ?? '').trim();
    if (v.isEmpty) return '/home';
    if (!v.startsWith('/')) return '/home';
    return v;
  }

  Future<void> _login() async {
    if (_busy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await AuthController(ref).login(
        context,
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        redirectTo: _safeRedirect(widget.redirectTo),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final redirect = _safeRedirect(widget.redirectTo);

    return AuraScaffold(
      title: 'Login',
      body: Center(
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
                  Text('Sign in to continue.', style: AuraText.body),
                  const SizedBox(height: AuraSpace.s16),

                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isEmpty) return 'Email is required';
                      if (!s.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: AuraSpace.s12),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator: (v) {
                      if ((v ?? '').isEmpty) return 'Password is required';
                      return null;
                    },
                  ),

                  const SizedBox(height: AuraSpace.s10),

                  Row(
                    children: [
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => context.go(
                                  '/forgot-password?redirect=${Uri.encodeComponent(redirect)}',
                                ),
                        child: const Text('Forgot password'),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => context.go(
                                  '/verify-email?redirect=${Uri.encodeComponent(redirect)}&email=${Uri.encodeComponent(_emailCtrl.text.trim())}',
                                ),
                        child: const Text('Verify email'),
                      ),
                    ],
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: AuraSpace.s8),
                    Text(_error!, style: AuraText.body.copyWith(color: Colors.red)),
                  ],

                  const SizedBox(height: AuraSpace.s10),

                  Wrap(
                    spacing: AuraSpace.s10,
                    runSpacing: AuraSpace.s10,
                    children: [
                      FilledButton(
                        onPressed: _busy ? null : _login,
                        child: Text(_busy ? 'Signing in…' : 'Login'),
                      ),
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () {
                                final q = widget.redirectTo == null || widget.redirectTo!.trim().isEmpty
                                    ? ''
                                    : '?redirect=${Uri.encodeComponent(widget.redirectTo!)}';
                                context.go('/register$q');
                              },
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
    );
  }
}