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
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _busy = false;
  bool _done = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _msg;

  String _safeRedirect(String? r) {
    final v = (r ?? '').trim();
    if (v.isEmpty) return '/home';
    if (!v.startsWith('/')) return '/home';
    return v;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (_busy || _done) return;

    final token = (widget.token ?? '').trim();
    if (token.isEmpty) {
      setState(() {
        _msg = 'This reset link is missing a token. Please request a new link.';
      });
      return;
    }

    final pass = _password.text;
    final confirm = _confirm.text;

    if (pass.isEmpty || confirm.isEmpty) {
      setState(() {
        _msg = 'New password and confirm password are required.';
      });
      return;
    }

    if (pass.length < 8) {
      setState(() {
        _msg = 'Password must be at least 8 characters.';
      });
      return;
    }

    if (pass.length > 72) {
      setState(() {
        _msg = 'Password must be 72 characters or fewer.';
      });
      return;
    }

    if (pass != confirm) {
      setState(() {
        _msg = 'Password and confirm password do not match.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _msg = null;
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
        _msg = 'Password updated. You can log in now.';
      });
    } on DioException catch (e) {
      debugPrint('reset-password failed: ${e.response?.statusCode} ${e.response?.data}');
      if (!mounted) return;

      setState(() {
        _msg = 'Reset failed. The link may be expired. Please request a new link.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _msg = 'Something went wrong. Please try again.';
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
      title: 'Reset password',
      body: Center(
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
                    onSubmitted: (_) => _submit(),
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
                        onPressed: () => context.go(
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