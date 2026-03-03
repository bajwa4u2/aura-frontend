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
  const ForgotPasswordScreen({super.key, this.email, this.redirectTo});

  final String? email;
  final String? redirectTo;

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  late final _email = TextEditingController(text: (widget.email ?? '').trim());

  bool _busy = false;
  String? _msg;

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
      setState(() => _msg = 'Enter a valid email.');
      return;
    }

    setState(() {
      _busy = true;
      _msg = null;
    });

    final dio = ref.read(dioProvider);

    try {
      await dio.post('/auth/forgot-password', data: {'email': email});
      setState(() {
        _msg = 'If that email exists, we sent a reset link. Check inbox and spam.';
      });
    } on DioException catch (e) {
      // Keep it generic to avoid account enumeration.
      debugPrint('forgot-password failed: ${e.response?.statusCode} ${e.response?.data}');
      setState(() {
        _msg = 'If that email exists, we sent a reset link. Check inbox and spam.';
      });
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
                  'Enter your email. We will send you a secure link to set a new password.',
                  style: AuraText.body,
                ),
                const SizedBox(height: AuraSpace.s14),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'Email'),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AuraSpace.s14),
                Wrap(
                  spacing: AuraSpace.s10,
                  runSpacing: AuraSpace.s10,
                  children: [
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Text(_busy ? 'Sending…' : 'Send reset link'),
                    ),
                    TextButton(
                      onPressed: () => context.go('/login?redirect=${Uri.encodeComponent(redirect)}'),
                      child: const Text('Back to login'),
                    ),
                  ],
                ),
                if (_msg != null) ...[
                  const SizedBox(height: AuraSpace.s12),
                  Text(_msg!, style: AuraText.body),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}