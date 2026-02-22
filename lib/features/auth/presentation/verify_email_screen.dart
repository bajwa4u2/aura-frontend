import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_scaffold.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  final String? token;
  final String? redirectTo;

  const VerifyEmailScreen({super.key, this.token, this.redirectTo});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _loading = false;
  String? _error;
  bool _verified = false;

  @override
  void initState() {
    super.initState();

    // Auto-verify if token present in URL.
    if (widget.token != null && widget.token!.trim().isNotEmpty) {
      _runVerify();
    } else {
      // No token: show a helpful message.
      _error = 'Missing verification token.';
    }
  }

  Future<void> _runVerify() async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _error = null;
      _verified = false;
    });

    try {
      final dio = ref.read(dioProvider);

      // 1) Verify email using token
      await dio.post('/auth/verify-email', data: {'token': widget.token});

      // 2) Confirm status (best-effort)
      try {
        await dio.get('/auth/me');
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _verified = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Verification failed. The link may be expired or already used.';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  void _continue() {
    final target = (widget.redirectTo != null && widget.redirectTo!.trim().isNotEmpty)
        ? widget.redirectTo!
        : '/home';
    context.go(target);
  }

  @override
  Widget build(BuildContext context) {
    return AuraScaffold(
      title: 'Verify Email',
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Email verification',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  if (_loading) ...[
                    const Text('Verifying your email…'),
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                  ] else if (_verified) ...[
                    const Text('Verified. You are good to go.'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _continue,
                      child: const Text('Continue'),
                    ),
                  ] else ...[
                    Text(_error ?? 'Unable to verify.'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: (widget.token != null && widget.token!.trim().isNotEmpty)
                                ? _runVerify
                                : null,
                            child: const Text('Try again'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => context.go('/login'),
                            child: const Text('Go to login'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}