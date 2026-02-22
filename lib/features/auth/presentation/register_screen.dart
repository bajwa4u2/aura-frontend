import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth_repository.dart';
import '../../../core/auth/session_providers.dart';

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

  Future<void> _submit() async {
    setState(() {
      _error = null;
    });

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final pw = _password.text;
    final cpw = _confirmPassword.text;

    if (pw != cpw) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() => _loading = true);

    try {
      final repo = ref.read(authRepositoryProvider);

      final out = await repo.register(
        email: _email.text.trim(),
        password: pw,
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        handle: _handle.text.trim(),
        displayName: _displayName.text.trim(),
      );

      await ref.read(sessionControllerProvider.notifier).onAuthSuccess(out);

      if (!mounted) return;

      // If user came here from a protected route, go back there.
      if (widget.redirectTo != null && widget.redirectTo!.isNotEmpty) {
        context.go(widget.redirectTo!);
      } else {
        // Otherwise go to verify pending (your router enforces verification anyway)
        context.go('/verify-pending');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
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
                  const Text(
                    'Join Aura',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create your account. We’ll email you a verification link.',
                  ),
                  const SizedBox(height: 16),

                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 12),
                  ],

                  TextFormField(
                    controller: _firstName,
                    decoration: const InputDecoration(
                      labelText: 'First name (private)',
                    ),
                    validator: (v) => _req(v, 'First name'),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 10),

                  TextFormField(
                    controller: _lastName,
                    decoration: const InputDecoration(
                      labelText: 'Last name (private)',
                    ),
                    validator: (v) => _req(v, 'Last name'),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 10),

                  TextFormField(
                    controller: _displayName,
                    decoration: const InputDecoration(
                      labelText: 'Display name (public, optional)',
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 10),

                  TextFormField(
                    controller: _handle,
                    decoration: const InputDecoration(
                      labelText: 'Handle (optional)',
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 10),

                  TextFormField(
                    controller: _email,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                    ),
                    validator: (v) => _req(v, 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 10),

                  TextFormField(
                    controller: _password,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                    ),
                    validator: (v) => _req(v, 'Password'),
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 10),

                  TextFormField(
                    controller: _confirmPassword,
                    decoration: const InputDecoration(
                      labelText: 'Confirm password',
                    ),
                    validator: (v) => _req(v, 'Confirm password'),
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 18),

                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: Text(
                      _loading ? 'Creating…' : 'Create account',
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}