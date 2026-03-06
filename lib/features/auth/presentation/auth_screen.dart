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

  Future<void> _login() async {
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

      // IMPORTANT:
      // Do not navigate here.
      // Router must be the single authority after auth state changes.
      // It will send:
      // - verified users to redirect/home
      // - unverified users to verify-pending
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
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
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: AuraText.body.copyWith(height: 1.3),
                    ),
                    const SizedBox(height: AuraSpace.s10),
                  ],
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
                  const SizedBox(height: AuraSpace.s10),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isEmpty) return 'Password is required';
                      return null;
                    },
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
    );
  }
}