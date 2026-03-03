import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  final String? token;
  final String? redirectTo;
  final String? email;

  const VerifyEmailScreen({super.key, this.token, this.redirectTo, this.email});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _busy = false;
  String? _msg;
  bool _verified = false;

  late final String _token = (widget.token ?? '').trim();
  late final TextEditingController _emailCtrl = TextEditingController(text: (widget.email ?? '').trim());

  String _safeRedirect(String? r) {
    final v = (r ?? '').trim();
    if (v.isEmpty) return '/home';
    if (!v.startsWith('/')) return '/home';
    return v;
  }

  @override
  void initState() {
    super.initState();
    if (_token.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _verify());
    }
  }

  Future<void> _verify() async {
    if (_busy) return;

    if (_token.isEmpty) {
      setState(() => _msg = 'This verification link is missing a token. Request a new verification email.');
      return;
    }

    setState(() {
      _busy = true;
      _msg = null;
      _verified = false;
    });

    try {
      final dio = ref.read(dioProvider);
      await dio.post('/auth/verify-email', data: {'token': _token});

      setState(() {
        _verified = true;
        _msg = 'Email verified.';
      });
    } on DioException catch (e) {
      final s = e.response?.statusCode;
      setState(() => _msg = 'Verification failed (${s ?? 'no status'}). The link may be expired.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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

    try {
      await dio.post('/auth/resend-verification', data: {'email': email});
      setState(() => _msg = 'Verification email sent. Check inbox and spam.');
    } on DioException catch (e) {
      final s = e.response?.statusCode;
      setState(() => _msg = 'Resend failed (${s ?? 'no status'}).');
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
      title: 'Verify email',
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Verify your email', style: AuraText.title),
                const SizedBox(height: AuraSpace.s10),
                Text(
                  _token.isNotEmpty
                      ? 'We are verifying your email now.'
                      : 'Request a new verification email.',
                  style: AuraText.body,
                ),
                const SizedBox(height: AuraSpace.s14),

                if (_msg != null) ...[
                  Text(_msg!, style: AuraText.body),
                  const SizedBox(height: AuraSpace.s10),
                ],

                if (_verified) ...[
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () => context.go('/login?redirect=${Uri.encodeComponent(redirect)}'),
                        child: const Text('Continue to login'),
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: _busy ? null : _verify,
                        child: _busy
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Verify now'),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: () => context.go('/login?redirect=${Uri.encodeComponent(redirect)}'),
                        child: const Text('Back to login'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AuraSpace.s14),
                  Text('Need a new email?', style: AuraText.body),
                  const SizedBox(height: AuraSpace.s10),
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: AuraSpace.s10),
                  TextButton(
                    onPressed: _busy ? null : _resend,
                    child: const Text('Resend verification email'),
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