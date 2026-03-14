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
  bool _msgIsError = false;

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

  String _humanizeVerifyError(DioException e) {
    final code = e.response?.statusCode;
    final raw = e.response?.data?.toString().toLowerCase() ?? '';
    final msg = (e.message ?? '').toLowerCase();

    if (code == 400 ||
        code == 404 ||
        code == 410 ||
        raw.contains('invalid token') ||
        raw.contains('expired token') ||
        raw.contains('token expired') ||
        raw.contains('invalid or expired')) {
      return 'This verification link is no longer valid. Please request a new one.';
    }

    if (code == 409 || raw.contains('already verified')) {
      return 'This email is already verified. You can sign in now.';
    }

    if (code == 429 || raw.contains('too many requests')) {
      return 'Too many attempts in a short time. Please wait a little and try again.';
    }

    if (msg.contains('socketexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('connection refused') ||
        msg.contains('network') ||
        e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'We could not reach the server. Check your connection and try again.';
    }

    if (code != null && code >= 500) {
      return 'Something went wrong on our side. Please try again in a moment.';
    }

    return 'We could not verify your email right now. Please try again.';
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
        _msg = 'This verification link is incomplete. Please request a new one.';
        _msgIsError = true;
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
        _msgIsError = false;
      });
    } on DioException catch (e) {
      debugPrint('verify-email failed: ${e.response?.statusCode} ${e.response?.data}');

      if (!mounted) return;

      final human = _humanizeVerifyError(e);
      final alreadyVerified = human.toLowerCase().contains('already verified');

      setState(() {
        _busy = false;
        _ok = alreadyVerified;
        _msg = human;
        _msgIsError = !alreadyVerified;
      });
    } catch (e) {
      debugPrint('verify-email failed: $e');

      if (!mounted) return;

      setState(() {
        _busy = false;
        _ok = false;
        _msg = 'We could not verify your email right now. Please try again.';
        _msgIsError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final redirect = _safeRedirectOrNull(widget.redirectTo);
    final email = (widget.email ?? '').trim();

    return AuraScaffold(
      
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: AuraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Email verification', style: AuraText.title),
                  const SizedBox(height: AuraSpace.s10),
                  Text(
                    _busy
                        ? 'Verifying your email…'
                        : (_msg ?? ''),
                    style: AuraText.body,
                  ),
                  const SizedBox(height: AuraSpace.s14),
                  if (_busy) ...[
                    const LinearProgressIndicator(),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _msgIsError
                            ? Colors.red.withValues(alpha: 0.08)
                            : Colors.green.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _msgIsError
                              ? Colors.red.withValues(alpha: 0.22)
                              : Colors.green.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Text(
                        _msg ?? '',
                        style: AuraText.body.copyWith(
                          color: _msgIsError ? Colors.red : Colors.green,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: AuraSpace.s14),
                    if (_ok)
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}