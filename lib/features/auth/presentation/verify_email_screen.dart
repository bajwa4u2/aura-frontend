import 'dart:async';

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
  const VerifyEmailScreen({super.key, this.token, this.email, this.redirectTo});

  final String? token;
  final String? email;
  final String? redirectTo;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _busy = true;
  bool _ok = false;
  String? _msg;

  String _safeRedirect(String? r) {
    final v = (r ?? '').trim();
    if (v.isEmpty) return '/home';
    if (!v.startsWith('/')) return '/home';
    return v;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_verify());
  }

  Future<void> _verify() async {
    final token = (widget.token ?? '').trim();
    if (token.isEmpty) {
      setState(() {
        _busy = false;
        _ok = false;
        _msg = 'This verification link is missing a token.';
      });
      return;
    }

    final dio = ref.read(dioProvider);

    try {
      await dio.post('/auth/verify-email', data: {'token': token});
      setState(() {
        _busy = false;
        _ok = true;
        _msg = 'Email verified.';
      });
    } on DioException catch (e) {
      debugPrint('verify-email failed: ${e.response?.statusCode} ${e.response?.data}');
      setState(() {
        _busy = false;
        _ok = false;
        _msg = 'Verification failed. The link may be expired.';
      });
    } catch (e) {
      debugPrint('verify-email failed: $e');
      setState(() {
        _busy = false;
        _ok = false;
        _msg = 'Verification failed.';
      });
    }
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
                Text('Email verification', style: AuraText.title),
                const SizedBox(height: AuraSpace.s10),
                if (_busy) ...[
                  Text('Verifying…', style: AuraText.body),
                  const SizedBox(height: AuraSpace.s12),
                  const LinearProgressIndicator(),
                ] else ...[
                  Text(_msg ?? '', style: AuraText.body),
                  const SizedBox(height: AuraSpace.s14),
                  if (_ok)
                    Wrap(
                      spacing: AuraSpace.s10,
                      runSpacing: AuraSpace.s10,
                      children: [
                        FilledButton(
                          onPressed: () => context.go('/login?redirect=${Uri.encodeComponent(redirect)}'),
                          child: const Text('Continue to login'),
                        ),
                        TextButton(
                          onPressed: () => context.go('/public'),
                          child: const Text('Back to home'),
                        ),
                      ],
                    )
                  else
                    Wrap(
                      spacing: AuraSpace.s10,
                      runSpacing: AuraSpace.s10,
                      children: [
                        FilledButton(
                          onPressed: () => context.go(
                            '/verify-pending?email=${Uri.encodeComponent((widget.email ?? '').trim())}&redirect=${Uri.encodeComponent(redirect)}',
                          ),
                          child: const Text('Resend verification'),
                        ),
                        TextButton(
                          onPressed: () => context.go('/login?redirect=${Uri.encodeComponent(redirect)}'),
                          child: const Text('Back to login'),
                        ),
                      ],
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