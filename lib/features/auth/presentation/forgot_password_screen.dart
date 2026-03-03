import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.redirectTo});

  final String? redirectTo;

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _busy = false;
  String? _msg;
  bool _sent = false;

  String _safeRedirect(String? r) {
    final v = (r ?? '').trim();
    if (v.isEmpty) return '/home';
    if (!v.startsWith('/')) return '/home';
    return v;
  }

  Future<void> _submit() async {
    if (_busy) return;

    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _msg = 'Enter a valid email address.');
      return;
    }

    setState(() {
      _busy = true;
      _msg = null;
      _sent = false;
    });

    final dio = ref.read(dioProvider);

    try {
      await dio.post('/auth/forgot-password', data: {'email': email});
      setState(() {
        _sent = true;
        _msg = 'If an account exists for this email, we sent a password reset link. Check inbox and spam.';
      });
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      setState(() => _msg = 'Request failed (${status ?? 'no status'}). Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final redirect = _safeRedirect(widget.redirectTo);

    return AuraScaffold(
      title: 'Forgot password',
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reset your password', style: AuraText.title),
                const SizedBox(height: AuraSpace.s10),
                Text(
                  'Enter your email and we will send you a reset link.',
                  style: AuraText.body,
                ),
                const SizedBox(height: AuraSpace.s14),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(labelText: 'Email'),
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
                          : const Text('Send reset link'),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () => context.go('/login?redirect=${Uri.encodeComponent(redirect)}'),
                      child: const Text('Back to login'),
                    ),
                  ],
                ),
                if (_sent) ...[
                  const SizedBox(height: AuraSpace.s10),
                  Text(
                    'Tip: If you do not see it, wait a minute and check spam.',
                    style: AuraText.subtle,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}