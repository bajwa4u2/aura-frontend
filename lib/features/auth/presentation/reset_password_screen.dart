import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
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
      await dio.post('/auth/reset-password', data: {
        'token': token,
        'password': pass,
      });

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

  InputDecoration _decoration({
    required String label,
    String? hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixIcon: suffixIcon,
      border: const OutlineInputBorder(),
    );
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
      
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: AuraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Set a new password', style: AuraText.title),
                  const SizedBox(height: AuraSpace.s10),
                  Text(
                    hasToken
                        ? 'Choose a new password for $accountLabel.'
                        : 'This reset link looks incomplete. Please request a new one.',
                    style: AuraText.body,
                  ),
                  const SizedBox(height: AuraSpace.s14),
                  if (hasToken) ...[
                    TextField(
                      controller: _password,
                      enabled: enabled,
                      obscureText: _obscurePassword,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.next,
                      decoration: _decoration(
                        label: 'New password',
                        hint: 'At least 8 characters',
                        suffixIcon: IconButton(
                          onPressed: enabled
                              ? () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                }
                              : null,
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
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
                      decoration: _decoration(
                        label: 'Confirm password',
                        hint: 'Re-enter your password',
                        suffixIcon: IconButton(
                          onPressed: enabled
                              ? () {
                                  setState(() {
                                    _obscureConfirm = !_obscureConfirm;
                                  });
                                }
                              : null,
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                        ),
                      ),
                      onSubmitted: (_) => enabled ? _submit() : null,
                    ),
                    const SizedBox(height: AuraSpace.s14),
                    Wrap(
                      spacing: AuraSpace.s10,
                      runSpacing: AuraSpace.s10,
                      children: [
                        FilledButton(
                          onPressed: enabled ? _submit : null,
                          child: Text(
                            _done
                                ? 'Done'
                                : (_busy ? 'Updating…' : 'Update password'),
                          ),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => context.go(
                                    '/login?redirect=${Uri.encodeComponent(redirect)}',
                                  ),
                          child: const Text('Back to login'),
                        ),
                      ],
                    ),
                  ] else ...[
                    Wrap(
                      spacing: AuraSpace.s10,
                      runSpacing: AuraSpace.s10,
                      children: [
                        FilledButton(
                          onPressed: () => context.go(
                            '/forgot-password?redirect=${Uri.encodeComponent(redirect)}',
                          ),
                          child: const Text('Request new reset link'),
                        ),
                        TextButton(
                          onPressed: () => context.go(
                            '/login?redirect=${Uri.encodeComponent(redirect)}',
                          ),
                          child: const Text('Back to login'),
                        ),
                      ],
                    ),
                  ],
                  if (_msg != null) ...[
                    const SizedBox(height: AuraSpace.s12),
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
                        _msg!,
                        style: AuraText.body.copyWith(
                          color: _msgIsError ? Colors.red : Colors.green,
                          height: 1.35,
                        ),
                      ),
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