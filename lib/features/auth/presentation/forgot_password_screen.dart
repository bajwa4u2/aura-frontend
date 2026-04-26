import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon + heading
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AuraSurface.accentSoft,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_reset_rounded,
                          size: 22,
                          color: AuraSurface.accentText,
                        ),
                      ),
                      const SizedBox(height: AuraSpace.s14),
                      Text('Reset your password', style: AuraText.title),
                      const SizedBox(height: AuraSpace.s8),
                      Text(
                        'Enter your email and we will send you a secure link to set a new password.',
                        style: AuraText.body.copyWith(
                          color: AuraSurface.muted,
                          height: 1.5,
                        ),
                      ),
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
                          labelText: 'Email',
                          hintText: 'name@example.com',
                        ),
                        onSubmitted: (_) => _busy ? null : _submit(),
                      ),
                      const SizedBox(height: AuraSpace.s20),
                      if (_busy) ...[
                        AuraPrimaryButton(
                          label: 'Sending…',
                          onPressed: null,
                          icon: Icons.send_rounded,
                        ),
                      ] else ...[
                        AuraPrimaryButton(
                          label: 'Send reset link',
                          onPressed: _submit,
                          icon: Icons.send_rounded,
                        ),
                      ],
                      const SizedBox(height: AuraSpace.s10),
                      AuraGhostButton(
                        label: 'Back to login',
                        onPressed: _busy
                            ? null
                            : () => context.go(
                                  '/login?redirect=${Uri.encodeComponent(redirect)}',
                                ),
                      ),
                      if (_message != null) ...[
                        const SizedBox(height: AuraSpace.s16),
                        _MessageBanner(
                          message: _message!,
                          isError: _messageIsError,
                        ),
                      ],
                    ],
                  ),
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
