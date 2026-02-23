import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_repository.dart';
import '../../../core/auth/auth_providers.dart';

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

  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  /// Extract access/refresh tokens from varying backend response shapes.
  /// Supports:
  /// - { accessToken, refreshToken }
  /// - { data: { accessToken, refreshToken } }
  /// - { tokens: { accessToken, refreshToken } }
  /// - snake_case variants
  ({String? accessToken, String? refreshToken}) _extractTokens(Map<String, dynamic> root) {
    String? pick(Map<String, dynamic> m, List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return null;
    }

    final directAccess = pick(root, ['accessToken', 'access_token', 'token']);
    final directRefresh = pick(root, ['refreshToken', 'refresh_token']);

    if (directAccess != null) {
      return (accessToken: directAccess, refreshToken: directRefresh);
    }

    final data = _asMap(root['data']);
    final tokens = _asMap(root['tokens']);

    final nestedAccess =
        pick(data, ['accessToken', 'access_token', 'token']) ??
        pick(tokens, ['accessToken', 'access_token', 'token']);
    final nestedRefresh =
        pick(data, ['refreshToken', 'refresh_token']) ??
        pick(tokens, ['refreshToken', 'refresh_token']);

    return (accessToken: nestedAccess, refreshToken: nestedRefresh);
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

  Future<void> _submit() async {
    setState(() {
      _error = null;
    });

    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_password.text != _confirmPassword.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() => _loading = true);

    try {
      final repo = ref.read(authRepositoryProvider);

      final email = _email.text.trim();
      final firstName = _firstName.text.trim();
      final lastName = _lastName.text.trim();

      // Keep fields optional in UI, but satisfy non-null backend contract.
      final handle = _handle.text.trim().isEmpty
          ? _defaultHandleFromEmail(email)
          : _handle.text.trim();

      final displayName = _displayName.text.trim().isEmpty
          ? _defaultDisplayName(firstName, lastName, handle)
          : _displayName.text.trim();

      final out = await repo.register(
        email: email,
        password: _password.text,
        firstName: firstName,
        lastName: lastName,
        handle: handle,
        displayName: displayName,
      );

      final tokens = _extractTokens(out);

      // Persist tokens using your real TokenStore API.
      // On web, refresh may be cookie-based; that's fine if refreshToken is null.
      if (tokens.accessToken != null) {
        await ref.read(tokenStoreProvider).setSession(
              accessToken: tokens.accessToken!,
              refreshToken: tokens.refreshToken,
            );
      }

      if (!mounted) return;

      final rt = widget.redirectTo;
      if (rt != null && rt.trim().isNotEmpty) {
        context.go(rt);
      } else {
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
                  const Text('Create your account. We’ll email you a verification link.'),
                  const SizedBox(height: 16),
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _firstName,
                    decoration: const InputDecoration(labelText: 'First name (private)'),
                    validator: (v) => _req(v, 'First name'),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _lastName,
                    decoration: const InputDecoration(labelText: 'Last name (private)'),
                    validator: (v) => _req(v, 'Last name'),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _displayName,
                    decoration: const InputDecoration(labelText: 'Display name (public, optional)'),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _handle,
                    decoration: const InputDecoration(labelText: 'Handle (optional)'),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) => _req(v, 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _password,
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator: (v) => _req(v, 'Password'),
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _confirmPassword,
                    decoration: const InputDecoration(labelText: 'Confirm password'),
                    validator: (v) => _req(v, 'Confirm password'),
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: Text(_loading ? 'Creating…' : 'Create account'),
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