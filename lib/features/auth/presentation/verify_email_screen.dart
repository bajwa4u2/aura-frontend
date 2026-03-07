import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({
    super.key,
    this.token,
    this.email,
    this.redirectTo,
  });

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

  String? _safeRedirectOrNull(String? r) {
    final v = (r ?? '').trim();
    if (v.isEmpty) return null;
    if (!v.startsWith('/')) return null;
    return v;
  }

  Future<void> _refreshAuthState() async {
    try {
      ref.invalidate(emailVerifiedProvider);
      ref.invalidate(authStatusProvider);
      ref.invalidate(isAuthedProvider);
      await ref.read(emailVerifiedProvider.future);
    } catch (_) {
      // Let router state settle naturally if refresh is not immediately available.
    }
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

      await _refreshAuthState();

      if (!mounted) return;

      setState(() {
        _busy = false;
        _ok = true;
        _msg = 'Your email has been verified successfully.';
      });
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      debugPrint('verify-email failed: $code ${e.response?.data}');

      String msg = 'Verification failed.';
      if (code == 400 || code == 404 || code == 410) {
        msg = 'This verification link is invalid or expired.';
      } else if (code == 409) {
        msg = 'This email appears to be already verified.';
      }

      if (!mounted) return;

      setState(() {
        _busy = false;
        _ok = false;
        _msg = msg;
      });
    } catch (e) {
      debugPrint('verify-email failed: $e');

      if (!mounted) return;

      setState(() {
        _busy = false;
        _ok = false;
        _msg = 'Verification failed.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final redirect = _safeRedirectOrNull(widget.redirectTo);
    final email = (widget.email ?? '').trim();

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
                Text(
                  _busy ? 'Verifying your email…' : (_msg ?? ''),
                  style: AuraText.body,
                ),
                const SizedBox(height: AuraSpace.s14),
                if (_busy)
                  const SizedBox.shrink()
                else if (_ok)
                  Wrap(
                    spacing: AuraSpace.s10,
                    runSpacing: AuraSpace.s10,
                    children: [
                      FilledButton(
                        onPressed: () {
                          if (redirect != null) {
                            context.go(
                              '/login?redirect=${Uri.encodeComponent(redirect)}',
                            );
                          } else {
                            context.go('/login');
                          }
                        },
                        child: const Text('Continue'),
                      ),
                      TextButton(
                        onPressed: () => context.go('/public'),
                        child: const Text('Back to public home'),
                      ),
                    ],
                  )
                else
                  Wrap(
                    spacing: AuraSpace.s10,
                    runSpacing: AuraSpace.s10,
                    children: [
                      FilledButton(
                        onPressed: () {
                          final qp = <String, String>{};
                          if (email.isNotEmpty) {
                            qp['email'] = email;
                          }
                          if (redirect != null) {
                            qp['redirect'] = redirect;
                          }

                          final uri = Uri(
                            path: '/verify-pending',
                            queryParameters: qp.isEmpty ? null : qp,
                          );
                          context.go(uri.toString());
                        },
                        child: const Text('Resend verification'),
                      ),
                      TextButton(
                        onPressed: () {
                          if (redirect != null) {
                            context.go(
                              '/login?redirect=${Uri.encodeComponent(redirect)}',
                            );
                          } else {
                            context.go('/login');
                          }
                        },
                        child: const Text('Back to login'),
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