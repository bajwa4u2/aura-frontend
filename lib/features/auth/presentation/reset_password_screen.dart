import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, this.initialToken = '', this.redirectTo});

  final String initialToken;
  final String? redirectTo;

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  late String _token = widget.initialToken.trim();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _busy = false;
  String? _msg;
  bool _done = false;

  String _safeRedirect(String? r) {
    final v = (r ?? '').trim();
    if (v.isEmpty) return '/home';
    if (!v.startsWith('/')) return '/home';
    return v;
  }

  Future<void> _submit() async {
    if (_busy) return;

    final pass = _password.text;
    final confirm = _confirm.text;

    if (_token.isEmpty) {
      setState(() => _msg = 'This reset link is missing a token. Request a new link.');
      return;
    }
    if (pass.length < 8) {
      setState(() => _msg = 'Password must be at least 8 characters.');
      return;
    }
    if (pass != confirm) {
      setState(() => _msg = 'Passwords do not match.');
      return;
    }

    setState(() {
      _busy = true;
      _msg = null;
      _done = false;
    });

    final dio = ref.read(dioProvider);

    try {
      await dio.post('/auth/reset-password', data: {
        'token': _token,
        'newPassword': pass,
      });

      setState(() {
        _done = true;
        _msg = 'Password updated successfully.';
      });
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      setState(() => _msg = 'Reset failed (${status ?? 'no status'}). The link may be expired.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final redirect = _safeRedirect(widget.redirectTo);

    return AuraScaffold(
      title: 'Reset password',
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Set a new password', style: AuraText.title),
                const SizedBox(height: AuraSpace.s10),
                Text(
                  'Choose a strong password you have not used before.',
                  style: AuraText.body,
                ),
                const SizedBox(height: AuraSpace.s14),

                if (_token.isEmpty) ...[
                  Text(
                    'This link is incomplete or expired.',
                    style: AuraText.body,
                  ),
                  const SizedBox(height: AuraSpace.s10),
                  TextButton(
                    onPressed: () => context.go('/forgot-password?redirect=${Uri.encodeComponent(redirect)}'),
                    child: const Text('Request a new reset link'),
                  ),
                  return const SizedBox(height: 0),
                ],

                TextField(
                  controller: _password,
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'New password'),
                ),
                const SizedBox(height: AuraSpace.s10),
                TextField(
                  controller: _confirm,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(labelText: 'Confirm new password'),
                  onSubmitted: (_) => _busy ? null : _submit(),
                ),
                const SizedBox(height: AuraSpace.s14),

                if (_msg != null) ...[
                  Text(_msg!, style: AuraText.body),
                  const SizedBox(height: AuraSpace.s10),
                ],

                Row(
                  children: [
                    ElevatedButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Update password'),
                    ),
                    const SizedBox(width: 12),
                    if (_done)
                      TextButton(
                        onPressed: () => context.go('/login?redirect=${Uri.encodeComponent(redirect)}'),
                        child: const Text('Go to login'),
                      )
                    else
                      TextButton(
                        onPressed: () => context.go('/login?redirect=${Uri.encodeComponent(redirect)}'),
                        child: const Text('Cancel'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}