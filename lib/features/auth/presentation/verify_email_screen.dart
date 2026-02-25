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

  bool _loading = false;
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

    // Auto-verify if token present in URL.
    if ((widget.token ?? '').trim().isNotEmpty) {
      _runVerify();
    }
  }

  Future<void> _runVerify() async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _msg = null;
      _verified = false;
    });

    try {
      final dio = ref.read(dioProvider);
      final token = _tokenCtrl.text.trim();

      if (token.isEmpty) {
        setState(() {
          _msg = 'Paste the verification token from your email.';
        });
        return;
      }

      await dio.post('/auth/verify-email', data: {'token': token});

      // Best-effort confirm
      try {
        await dio.get('/auth/me');
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _verified = true;
        _msg = 'Verified. You are good to go.';
      });
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      setState(() {
        _msg = 'Verification failed (${status ?? 'no status'}). The link may be expired or already used.';
      });
    } catch (_) {
      setState(() {
        _msg = 'Verification failed. The link may be expired or already used.';
      });
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _msg = null;
    });

    final dio = ref.read(dioProvider);

    try {
      final email = _emailCtrl.text.trim();
      await dio.post('/auth/resend-verification', data: {'email': email});
      setState(() {
        _msg = 'We sent a verification email. Check inbox and spam.';
      });
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      setState(() {
        _msg = 'Could not resend (${status ?? 'no status'}).';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _continue() {
    final target = _safeRedirect(widget.redirectTo);
    context.go(target);
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
                  'If you opened a link from email, verification should complete automatically. '
                  'If not, paste the token below.',
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

                if (_loading) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: AuraSpace.s12),
                ],

                Wrap(
                  spacing: AuraSpace.s10,
                  runSpacing: AuraSpace.s10,
                  children: [
                    FilledButton(
                      onPressed: _loading ? null : _runVerify,
                      child: const Text('Verify'),
                    ),
                    OutlinedButton(
                      onPressed: _loading ? null : _resend,
                      child: const Text('Resend email'),
                    ),
                    TextButton(
                      onPressed: _loading ? null : () => context.go('/login?redirect=${Uri.encodeComponent(redirect)}'),
                      child: const Text('Back to login'),
                    ),
                    if (_verified)
                      FilledButton(
                        onPressed: _continue,
                        child: const Text('Continue'),
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