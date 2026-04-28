import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({
    super.key,
    this.token,
    this.email,
    this.redirectTo,
  });

  final String? token;
  final String? email;
  final String? redirectTo;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _busy = false;
  bool _done = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _msg;
  bool _msgIsError = false;

  String _safeRedirect(String? r) {
    final v = (r ?? '').trim();
    if (v.isEmpty) return '/home';
    if (!v.startsWith('/')) return '/home';
    return v;
  }

  String _humanizeResetError(DioException e) {
    final code = e.response?.statusCode;
    final raw = e.response?.data?.toString().toLowerCase() ?? '';
    final msg = (e.message ?? '').toLowerCase();

    if (code == 400 ||
        raw.contains('invalid token') ||
        raw.contains('expired token') ||
        raw.contains('token expired') ||
        raw.contains('reset token') ||
        raw.contains('invalid or expired')) {
      return 'This reset link is no longer valid. Please request a new one.';
    }

    if (raw.contains('at least 8') ||
        (raw.contains('password') && raw.contains('too short'))) {
      return 'Password must be at least 8 characters.';
    }

    if (raw.contains('weak password') ||
        (raw.contains('password') && raw.contains('weak'))) {
      return 'Please choose a stronger password.';
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

    return 'We could not reset your password right now. Please try again.';
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (_busy || _done) return;

    final token = (widget.token ?? '').trim();
    if (token.isEmpty) {
      setState(() {
        _msg = 'This reset link is incomplete. Please request a new one.';
        _msgIsError = true;
      });
      return;
    }

    final pass = _password.text;
    final confirm = _confirm.text;

    if (pass.isEmpty || confirm.isEmpty) {
      setState(() {
        _msg = 'Please enter your new password in both fields.';
        _msgIsError = true;
      });
      return;
    }

    if (pass.length < 8) {
      setState(() {
        _msg = 'Password must be at least 8 characters.';
        _msgIsError = true;
      });
      return;
    }

    if (pass.length > 72) {
      setState(() {
        _msg = 'Password must be 72 characters or fewer.';
        _msgIsError = true;
      });
      return;
    }

    if (pass != confirm) {
      setState(() {
        _msg = 'Password and confirm password do not match.';
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

    try {
      await dio.post(
        '/auth/reset-password',
        data: {'token': token, 'password': pass},
      );

      if (!mounted) return;

      setState(() {
        _done = true;
        _msg = 'Password updated. You can sign in now.';
        _msgIsError = false;
      });
    } on DioException catch (e) {
      debugPrint(
        'reset-password failed: ${e.response?.statusCode} ${e.response?.data}',
      );
      if (!mounted) return;

      setState(() {
        _msg = _humanizeResetError(e);
        _msgIsError = true;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _msg = 'We could not reset your password right now. Please try again.';
        _msgIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final redirect = _safeRedirect(widget.redirectTo);
    final hasToken = (widget.token ?? '').trim().isNotEmpty;
    final enabled = !_busy && !_done;
    final accountLabel = ((widget.email ?? '').trim().isEmpty)
        ? 'your account'
        : widget.email!.trim();

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
                        Icons.key_rounded,
                        size: 22,
                        color: AuraSurface.accentText,
                      ),
                    ),
                    const SizedBox(height: AuraSpace.s14),
                    const Text('Set a new password', style: AuraText.title),
                    const SizedBox(height: AuraSpace.s8),
                    Text(
                      hasToken
                          ? 'Choose a new password for $accountLabel.'
                          : 'This reset link looks incomplete. Please request a new one.',
                      style: AuraText.body.copyWith(
                        color: AuraSurface.muted,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: AuraSpace.s20),
                    if (hasToken) ...[
                      TextField(
                        controller: _password,
                        enabled: enabled,
                        obscureText: _obscurePassword,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.next,
                        style: AuraText.body,
                        decoration: InputDecoration(
                          labelText: 'New password',
                          hintText: 'At least 8 characters',
                          suffixIcon: IconButton(
                            onPressed: enabled
                                ? () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  )
                                : null,
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: AuraSurface.muted,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AuraSpace.s12),
                      TextField(
                        controller: _confirm,
                        enabled: enabled,
                        obscureText: _obscureConfirm,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.done,
                        style: AuraText.body,
                        decoration: InputDecoration(
                          labelText: 'Confirm password',
                          hintText: 'Re-enter your password',
                          suffixIcon: IconButton(
                            onPressed: enabled
                                ? () => setState(
                                    () => _obscureConfirm = !_obscureConfirm,
                                  )
                                : null,
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: AuraSurface.muted,
                              size: 20,
                            ),
                          ),
                        ),
                        onSubmitted: (_) => enabled ? _submit() : null,
                      ),
                      const SizedBox(height: AuraSpace.s20),
                      AuraPrimaryButton(
                        label: _done
                            ? 'Continue to sign in'
                            : (_busy ? 'Updating…' : 'Update password'),
                        onPressed: _done
                            ? () {
                                final qp = <String, String>{
                                  'reset': '1',
                                };
                                final email = (widget.email ?? '').trim();
                                if (email.isNotEmpty) {
                                  qp['email'] = email;
                                }
                                context.go(Uri(path: '/login', queryParameters: qp).toString());
                              }
                            : (enabled ? _submit : null),
                        icon: _done
                            ? Icons.check_rounded
                            : Icons.lock_outline_rounded,
                      ),
                      const SizedBox(height: AuraSpace.s10),
                      AuraGhostButton(
                        label: 'Back to login',
                        onPressed: _busy
                            ? null
                            : () => context.go(
                                '/login?redirect=${Uri.encodeComponent(redirect)}',
                              ),
                      ),
                    ] else ...[
                      AuraPrimaryButton(
                        label: 'Request new reset link',
                        onPressed: () => context.go(
                          '/forgot-password?redirect=${Uri.encodeComponent(redirect)}',
                        ),
                        icon: Icons.refresh_rounded,
                      ),
                      const SizedBox(height: AuraSpace.s10),
                      AuraGhostButton(
                        label: 'Back to login',
                        onPressed: () => context.go(
                          '/login?redirect=${Uri.encodeComponent(redirect)}',
                        ),
                      ),
                    ],
                    if (_msg != null) ...[
                      const SizedBox(height: AuraSpace.s16),
                      _MessageBanner(message: _msg!, isError: _msgIsError),
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
