import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({
    super.key,
    this.token,
    this.email,
    this.redirectTo,
    this.verified = false,
  });

  final String? token;
  final String? email;
  final String? redirectTo;
  final bool verified;

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
    final token = (widget.token ?? '').trim();
    if (widget.verified && token.isEmpty) {
      _busy = false;
      _ok = true;
      _msg = 'Your email has been verified successfully.';
      _msgIsError = false;
      unawaited(_refreshAuthState());
      return;
    }
    unawaited(_verify());
  }

  Future<void> _verify() async {
    final token = (widget.token ?? '').trim();

    if (token.isEmpty) {
      setState(() {
        _busy = false;
        _ok = false;
        _msg =
            'This verification link is incomplete. Please request a new one.';
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
      debugPrint(
        'verify-email failed: ${e.response?.statusCode} ${e.response?.data}',
      );

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
    final title = _ok ? 'Email verified' : 'Email verification';

    return AuraScaffold(
      showHeader: false,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.s16,
              vertical: AuraSpace.s24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: AuraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon + heading
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _busy
                            ? AuraSurface.accentSoft
                            : (_ok
                                  ? const Color(0xFF0E2318)
                                  : const Color(0xFF231010)),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _busy
                            ? Icons.hourglass_top_rounded
                            : (_ok
                                  ? Icons.verified_rounded
                                  : Icons.error_outline_rounded),
                        size: 22,
                        color: _busy
                            ? AuraSurface.accentText
                            : (_ok
                                  ? AuraSurface.goodInk
                                  : AuraSurface.dangerInk),
                      ),
                    ),
                    const SizedBox(height: AuraSpace.s14),
                    Text(title, style: AuraText.title),
                    const SizedBox(height: AuraSpace.s8),
                    Text(
                      _busy ? 'Verifying your email…' : (_msg ?? ''),
                      style: AuraText.body.copyWith(
                        color: AuraSurface.muted,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: AuraSpace.s20),
                    if (_busy) ...[
                      Row(
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AuraSurface.accent,
                            ),
                          ),
                          const SizedBox(width: AuraSpace.s12),
                          Text(
                            'Please wait…',
                            style: AuraText.small.copyWith(
                              color: AuraSurface.muted,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      if (_msg != null)
                        _MessageBanner(message: _msg!, isError: _msgIsError),
                      const SizedBox(height: AuraSpace.s16),
                      if (_ok) ...[
                        AuraPrimaryButton(
                          label: 'Continue to sign in',
                          icon: Icons.login_rounded,
                          onPressed: () {
                            final qp = <String, String>{'verified': '1'};
                            if (email.isNotEmpty) qp['email'] = email;
                            if (redirect != null) {
                              qp['redirect'] = redirect;
                            }
                            context.go(
                              Uri(path: '/login', queryParameters: qp).toString(),
                            );
                          },
                        ),
                        const SizedBox(height: AuraSpace.s10),
                        AuraGhostButton(
                          label: 'Back to public home',
                          onPressed: () => context.go('/public'),
                        ),
                      ] else ...[
                        AuraPrimaryButton(
                          label: 'Resend verification',
                          icon: Icons.send_rounded,
                          onPressed: () {
                            final qp = <String, String>{};
                            if (email.isNotEmpty) qp['email'] = email;
                            if (redirect != null) qp['redirect'] = redirect;

                            final uri = Uri(
                              path: '/verify-pending',
                              queryParameters: qp.isEmpty ? null : qp,
                            );
                            context.go(uri.toString());
                          },
                        ),
                        const SizedBox(height: AuraSpace.s10),
                        AuraGhostButton(
                          label: 'Back to login',
                          onPressed: () {
                            if (redirect != null) {
                              context.go(
                                '/login?redirect=${Uri.encodeComponent(redirect)}',
                              );
                            } else {
                              context.go('/login');
                            }
                          },
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared message banner ─────────────────────────────────────────────────────

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final bg = isError ? AuraSurface.dangerBg : AuraSurface.goodBg;
    final ink = isError ? AuraSurface.dangerInk : AuraSurface.goodInk;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AuraSpace.s14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AuraRadius.md),
        border: Border.all(color: ink.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            size: 16,
            color: ink,
          ),
          const SizedBox(width: AuraSpace.s10),
          Expanded(
            child: Text(
              message,
              style: AuraText.small.copyWith(color: ink, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
