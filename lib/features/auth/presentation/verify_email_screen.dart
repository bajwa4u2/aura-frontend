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
  late final _tokenCtrl = TextEditingController(text: (widget.token ?? '').trim());
  late final _emailCtrl = TextEditingController(text: (widget.email ?? '').trim());

  bool _busy = false;
  String? _msg;
  bool _verified = false;

  String _safeRedirect(String? r) {
    final v = (r ?? '').trim();
    if (v.isEmpty) return '/home';
    if (!v.startsWith('/')) return '/home';
    return v;
  }

  @override
  void initState() {
    super.initState();
    if ((widget.token ?? '').trim().isNotEmpty) {
      _verify();
    }
  }

  Future<void> _verify() async {
    if (_busy) return;

    final token = _tokenCtrl.text.trim();
    if (token.isEmpty) {
      setState(() => _msg = 'Paste the verification token from your email.');
      return;
    }

    setState(() {
      _busy = true;
      _msg = null;
      _verified = false;
    });

    try {
      final dio = ref.read(dioProvider);
      await dio.post('/auth/verify-email', data: {'token': token});

      setState(() {
        _verified = true;
        _msg = 'Verified. Now log in to continue.';
      });
    } on DioException catch (e) {
      final s = e.response?.statusCode;
      setState(() => _msg = 'Verification failed (${s ?? 'no status'}). The token may be expired.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_busy) return;

    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _msg = 'Enter your email to resend verification.');
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
      setState(() => _msg = 'Resend failed.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final redirect = _safeRedirect(widget.redirectTo);

    return AuraScaffold(
      title: 'Verify Email',
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Email verification', style: AuraText.title),
                const SizedBox(height: AuraSpace.s10),
                Text(
                  'Verify your email to unlock the app.',
                  style: AuraText.body,
                ),
                const SizedBox(height: AuraSpace.s14),
                TextField(
                  controller: _tokenCtrl,
                  decoration: const InputDecoration(labelText: 'Verification token'),
                ),
                const SizedBox(height: AuraSpace.s12),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email (for resend)'),
                ),
                const SizedBox(height: AuraSpace.s14),
                if (_busy) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: AuraSpace.s12),
                ],
                Wrap(
                  spacing: AuraSpace.s10,
                  runSpacing: AuraSpace.s10,
                  children: [
                    FilledButton(
                      onPressed: _busy ? null : _verify,
                      child: const Text('Verify'),
                    ),
                    OutlinedButton(
                      onPressed: _busy ? null : _resend,
                      child: const Text('Resend email'),
                    ),
                    TextButton(
                      onPressed: _busy ? null : () => context.go('/verify-pending?redirect=${Uri.encodeComponent(redirect)}&email=${Uri.encodeComponent(_emailCtrl.text.trim())}'),
                      child: const Text('Back'),
                    ),
                    if (_verified)
                      FilledButton(
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