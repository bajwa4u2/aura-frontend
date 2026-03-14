import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    this.email,
    this.redirectTo,
  });

  final String? email;
  final String? redirectTo;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  late final _email = TextEditingController(text: (widget.email ?? '').trim());

  bool _busy = false;
  String? _message;
  bool _messageIsError = false;

  String _safeRedirect(String? r) {
    final v = (r ?? '').trim();
    if (v.isEmpty) return '/home';
    if (!v.startsWith('/')) return '/home';
    return v;
  }

  bool _isValidEmail(String value) {
    final s = value.trim();
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
  }

  Future<void> _submit() async {
    if (_busy) return;

    FocusScope.of(context).unfocus();

    final email = _email.text.trim();
    if (!_isValidEmail(email)) {
      setState(() {
        _message = 'Please enter a valid email address.';
        _messageIsError = true;
      });
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
      _messageIsError = false;
    });

    final dio = ref.read(dioProvider);

    try {
      await dio.post('/auth/forgot-password', data: {'email': email});

      if (!mounted) return;
      setState(() {
        _message =
            'If that email is connected to an account, we sent a reset link. Please check your inbox and spam folder.';
        _messageIsError = false;
      });
    } on DioException catch (e) {
      debugPrint(
        'forgot-password failed: ${e.response?.statusCode} ${e.response?.data}',
      );

      if (!mounted) return;
      setState(() {
        _message =
            'If that email is connected to an account, we sent a reset link. Please check your inbox and spam folder.';
        _messageIsError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message =
            'If that email is connected to an account, we sent a reset link. Please check your inbox and spam folder.';
        _messageIsError = false;
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
    final redirect = _safeRedirect(widget.redirectTo);

    return AuraScaffold(
      title: 'Forgot password',
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: AuraCard(
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reset your password', style: AuraText.title),
                    const SizedBox(height: AuraSpace.s10),
                    Text(
                      'Enter your email and we will send you a secure link to set a new password.',
                      style: AuraText.body,
                    ),
                    const SizedBox(height: AuraSpace.s14),
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
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'name@example.com',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _busy ? null : _submit(),
                    ),
                    const SizedBox(height: AuraSpace.s14),
                    Wrap(
                      spacing: AuraSpace.s10,
                      runSpacing: AuraSpace.s10,
                      children: [
                        FilledButton(
                          onPressed: _busy ? null : _submit,
                          child: Text(_busy ? 'Sending…' : 'Send reset link'),
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
                    if (_message != null) ...[
                      const SizedBox(height: AuraSpace.s12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _messageIsError
                              ? Colors.red.withValues(alpha: 0.08)
                              : Colors.blue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _messageIsError
                                ? Colors.red.withValues(alpha: 0.22)
                                : Colors.blue.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Text(
                          _message!,
                          style: AuraText.body.copyWith(
                            color:
                                _messageIsError ? Colors.red : Colors.blue,
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
      ),
    );
  }
}