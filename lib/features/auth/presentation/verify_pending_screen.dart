import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';

class VerifyPendingScreen extends ConsumerStatefulWidget {
  const VerifyPendingScreen({super.key, this.email, this.redirectTo});

  final String? email;
  final String? redirectTo;

  @override
  ConsumerState<VerifyPendingScreen> createState() => _VerifyPendingScreenState();
}

class _VerifyPendingScreenState extends ConsumerState<VerifyPendingScreen> {
  late final _emailCtrl = TextEditingController(text: (widget.email ?? '').trim());

  bool _busy = false;
  String? _msg;

  String _safeRedirect(String? r) {
    final v = (r ?? '').trim();
    if (v.isEmpty) return '/home';
    if (!v.startsWith('/')) return '/home';
    return v;
  }

  Future<void> _resend() async {
    if (_busy) return;

    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _msg = 'Enter a valid email to resend verification.');
      return;
    }

    setState(() {
      _busy = true;
      _msg = null;
    });

    final dio = ref.read(dioProvider);

    final candidates = <String>[
      '/auth/resend-verification',
      '/auth/resend-verify-email',
      '/auth/resend-verification-email',
    ];

    try {
      DioException? last;
      for (final path in candidates) {
        try {
          await dio.post(path, data: {'email': email});
          setState(() => _msg = 'Verification email sent. Check inbox and spam.');
          return;
        } on DioException catch (e) {
          last = e;
          if (e.response?.statusCode == 404) continue;
          rethrow;
        }
      }
      final s = last?.response?.statusCode;
      setState(() => _msg = 'Resend failed (${s ?? 'no status'}).');
    } catch (_) {
      setState(() => _msg = 'Resend failed. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final redirect = _safeRedirect(widget.redirectTo);

    return AuraScaffold(
      title: 'Verify your email',
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('One more step', style: AuraText.title),
                const SizedBox(height: AuraSpace.s10),
                Text(
                  'We sent a verification link to your email. Verify first, then log in.',
                  style: AuraText.body,
                ),
                const SizedBox(height: AuraSpace.s14),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: AuraSpace.s12),
                if (_busy) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: AuraSpace.s12),
                ],
                Wrap(
                  spacing: AuraSpace.s10,
                  runSpacing: AuraSpace.s10,
                  children: [
                    FilledButton(
                      onPressed: _busy ? null : _resend,
                      child: const Text('Resend verification'),
                    ),
                    OutlinedButton(
                      onPressed: () => context.go(
                        '/verify-email?redirect=${Uri.encodeComponent(redirect)}&email=${Uri.encodeComponent(_emailCtrl.text.trim())}',
                      ),
                      child: const Text('I have a token'),
                    ),
                    TextButton(
                      onPressed: () => context.go('/login?redirect=${Uri.encodeComponent(redirect)}'),
                      child: const Text('Go to login'),
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