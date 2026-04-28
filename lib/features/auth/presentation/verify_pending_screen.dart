import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class VerifyPendingScreen extends ConsumerStatefulWidget {
  const VerifyPendingScreen({
    super.key,
    this.email,
    this.redirectTo,
    this.emailSent = true,
  });

  final String? email;
  final String? redirectTo;
  final bool emailSent;

  @override
  ConsumerState<VerifyPendingScreen> createState() =>
      _VerifyPendingScreenState();
}

class _VerifyPendingScreenState extends ConsumerState<VerifyPendingScreen> {
  late final _email = TextEditingController(text: (widget.email ?? '').trim());

  bool _busy = false;
  String? _msg;
  bool _msgIsError = false;

  String? _safeRedirectOrNull(String? r) {
    final v = (r ?? '').trim();
    if (v.isEmpty) return null;
    if (!v.startsWith('/')) return null;
    return v;
  }

  bool _isValidEmail(String value) {
    final s = value.trim();
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
  }

  String _humanizeResendError(DioException? e) {
    final code = e?.response?.statusCode;
    final raw = e?.response?.data?.toString().toLowerCase() ?? '';
    final msg = (e?.message ?? '').toLowerCase();

    if (code == 400 && raw.contains('already verified')) {
      return 'This email is already verified. You can sign in now.';
    }

    if (code == 404 && raw.contains('not found')) {
      return 'We could not find an account with that email.';
    }

    if (code == 429 || raw.contains('too many requests')) {
      return 'Too many attempts in a short time. Please wait a little and try again.';
    }

    if (msg.contains('socketexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('connection refused') ||
        msg.contains('network') ||
        e?.type == DioExceptionType.connectionError ||
        e?.type == DioExceptionType.connectionTimeout ||
        e?.type == DioExceptionType.sendTimeout ||
        e?.type == DioExceptionType.receiveTimeout) {
      return 'We could not reach the server. Check your connection and try again.';
    }

    if (code != null && code >= 500) {
      return 'Something went wrong on our side. Please try again in a moment.';
    }

    return 'We could not resend the verification email right now. Please try again.';
  }

  Future<void> _resend() async {
    if (_busy) return;

    FocusScope.of(context).unfocus();

    final email = _email.text.trim();
    if (!_isValidEmail(email)) {
      setState(() {
        _msg = 'Please enter a valid email address to resend verification.';
        _msgIsError = true;
      });
      return;
    }

    setState(() {
      _busy = true;
      _msg = null;
      _msgIsError = false;
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
          final res = await dio.post(path, data: {'email': email});
          final body = res.data;
          bool emailSent = true;

          if (body is Map) {
            final raw = body['emailSent'];
            if (raw is bool) emailSent = raw;
            final data = body['data'];
            if (raw == null && data is Map && data['emailSent'] is bool) {
              emailSent = data['emailSent'] as bool;
            }
          }

          if (!mounted) return;
          setState(() {
            _msg = emailSent
                ? 'Verification email sent. Please check your inbox and spam folder.'
                : 'We could not send the verification email just now. Please try again.';
            _msgIsError = !emailSent;
          });
          return;
        } on DioException catch (e) {
          last = e;
          if (e.response?.statusCode == 404) continue;
          rethrow;
        }
      }

      debugPrint(
        'resend verify failed: ${last?.response?.statusCode} ${last?.response?.data}',
      );

      if (!mounted) return;
      setState(() {
        _msg = _humanizeResendError(last);
        _msgIsError = true;
      });
    } on DioException catch (e) {
      debugPrint(
        'resend verify failed: ${e.response?.statusCode} ${e.response?.data}',
      );

      if (!mounted) return;
      setState(() {
        _msg = _humanizeResendError(e);
        _msgIsError = true;
      });
    } catch (e) {
      debugPrint('resend verify failed: $e');

      if (!mounted) return;
      setState(() {
        _msg =
            'We could not resend the verification email right now. Please try again.';
        _msgIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final redirect = _safeRedirectOrNull(widget.redirectTo);
    final verifiedAsync = ref.watch(emailVerifiedProvider);
    final isAuthed = ref.watch(isAuthedProvider);
    final emailSent = widget.emailSent;

    if (isAuthed && verifiedAsync.value == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final qp = <String, String>{'verified': '1'};
        final email = _email.text.trim();
        if (email.isNotEmpty) qp['email'] = email;
        if (redirect != null) qp['redirect'] = redirect;

        final uri = Uri(
          path: '/verify-email',
          queryParameters: qp,
        );
        context.go(uri.toString());
      });
    }

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
                      decoration: const BoxDecoration(
                        color: AuraSurface.accentSoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mark_email_unread_outlined,
                        size: 22,
                        color: AuraSurface.accentText,
                      ),
                    ),
                    const SizedBox(height: AuraSpace.s14),
                    const Text('Almost there', style: AuraText.title),
                    const SizedBox(height: AuraSpace.s8),
                    Text(
                      'We need to verify your email before you can continue. Open the email we sent and click the link.',
                      style: AuraText.body.copyWith(
                        color: AuraSurface.muted,
                        height: 1.5,
                      ),
                    ),
                    if (!emailSent) ...[
                      const SizedBox(height: AuraSpace.s14),
                      const _MessageBanner(
                        message:
                            'Your account was created, but we could not send the verification email just now. You can resend it below.',
                        isError: true,
                      ),
                    ],
                    const SizedBox(height: AuraSpace.s20),
                    TextField(
                      controller: _email,
                      enabled: !_busy,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.email],
                      autocorrect: false,
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(RegExp(r'\s')),
                      ],
                      style: AuraText.body,
                      decoration: const InputDecoration(
                        labelText: 'Email (for resend)',
                        hintText: 'name@example.com',
                      ),
                      onSubmitted: (_) => _busy ? null : _resend(),
                    ),
                    const SizedBox(height: AuraSpace.s20),
                    if (_busy) ...[
                      const AuraPrimaryButton(
                        label: 'Sending…',
                        onPressed: null,
                        icon: Icons.refresh_rounded,
                      ),
                    ] else ...[
                      AuraPrimaryButton(
                        label: 'Resend verification',
                        onPressed: _resend,
                        icon: Icons.send_rounded,
                      ),
                    ],
                    const SizedBox(height: AuraSpace.s10),
                    AuraGhostButton(
                      label: 'Back to login',
                      onPressed: _busy
                          ? null
                          : () {
                              if (redirect != null) {
                                context.go(
                                  '/login?redirect=${Uri.encodeComponent(redirect)}',
                                );
                              } else {
                                context.go('/login');
                              }
                            },
                    ),
                    if (_msg != null) ...[
                      const SizedBox(height: AuraSpace.s16),
                      _MessageBanner(message: _msg!, isError: _msgIsError),
                    ],
                    if (verifiedAsync.isLoading) ...[
                      const SizedBox(height: AuraSpace.s14),
                      Row(
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AuraSurface.accent,
                            ),
                          ),
                          const SizedBox(width: AuraSpace.s10),
                          Text(
                            'Checking verification status…',
                            style: AuraText.small.copyWith(
                              color: AuraSurface.muted,
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
