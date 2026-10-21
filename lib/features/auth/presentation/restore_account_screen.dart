import '../../../core/ui/aura_chamber.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_responsive.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';

/// RESTORE A DELETED ACCOUNT (founder decision 2026-10-21: a real 30-day
/// restore).
///
/// Reached from the sign-in screen. The person proves they still hold the
/// account's email with a 6-digit code; the account comes back with its
/// profile, and they sign in with their usual password. The server never says
/// whether an email has a deleted account, so neither does this screen.
class RestoreAccountScreen extends ConsumerStatefulWidget {
  const RestoreAccountScreen({super.key, this.email});

  final String? email;

  @override
  ConsumerState<RestoreAccountScreen> createState() =>
      _RestoreAccountScreenState();
}

enum _Step { email, code, restored }

class _RestoreAccountScreenState extends ConsumerState<RestoreAccountScreen> {
  late final _email = TextEditingController(text: (widget.email ?? '').trim());
  final _code = TextEditingController();

  _Step _step = _Step.email;
  bool _busy = false;
  String? _message;
  bool _messageIsError = false;

  static const _sendFailed =
      'We could not send the code right now. Please try again in a moment.';
  static const _restoreFailed =
      'We could not restore the account right now. Please try again in a moment.';

  bool _isValidEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());

  String? _serverMessage(Object e) {
    if (e is! DioException) return null;
    final body = e.response?.data;
    if (body is Map) {
      final error = body['error'];
      if (error is Map && error['message'] is String) {
        return error['message'] as String;
      }
      if (body['message'] is String) return body['message'] as String;
    }
    return null;
  }

  Future<void> _sendCode() async {
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
    });
    try {
      final res = await ref
          .read(dioProvider)
          .post('/auth/account-restore/start', data: {'email': email});
      final body = res.data;
      final said = body is Map
          ? (body['message'] ?? (body['data'] is Map ? body['data']['message'] : null))
          : null;
      if (!mounted) return;
      setState(() {
        _step = _Step.code;
        _message = said is String && said.isNotEmpty
            ? said
            : 'If a deleted account with this email can still be restored, we have sent a code to it. The code expires in 15 minutes.';
        _messageIsError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = _sendFailed;
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    final code = _code.text.replaceAll(RegExp(r'\s'), '');
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() {
        _message = 'Enter the 6-digit code from the email.';
        _messageIsError = true;
      });
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref.read(dioProvider).post(
        '/auth/account-restore/complete',
        data: {'email': _email.text.trim(), 'code': code},
      );
      if (!mounted) return;
      setState(() {
        _step = _Step.restored;
        _message = null;
      });
    } catch (e) {
      if (!mounted) return;
      final status = e is DioException ? e.response?.statusCode : null;
      setState(() {
        // 400 (wrong or expired code) and 409 (the email now belongs to
        // another account) carry sentences written for the person.
        _message = (status == 400 || status == 409)
            ? (_serverMessage(e) ?? _restoreFailed)
            : _restoreFailed;
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toSignIn() {
    final email = _email.text.trim();
    context.go(
      email.isEmpty ? '/login' : '/login?email=${Uri.encodeComponent(email)}',
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final muted = AuraText.body.copyWith(
      color: chamberTone(context, AuraSurface.muted),
      height: 1.5,
    );

    final List<Widget> content;
    switch (_step) {
      case _Step.restored:
        content = [
          const Text('Your account is back', style: AuraText.title),
          const SizedBox(height: AuraSpace.s8),
          Text(
            'Sign in to continue with your usual password. Your profile is as you left it. Any Facebook Page, Instagram, LinkedIn or TikTok account you had connected needs connecting again.',
            style: muted,
          ),
          const SizedBox(height: AuraSpace.s20),
          AuraPrimaryButton(
            label: 'Sign in',
            onPressed: _toSignIn,
            icon: Icons.login_rounded,
          ),
        ];
      case _Step.email:
      case _Step.code:
        final codeStep = _step == _Step.code;
        content = [
          const Text('Restore a deleted account', style: AuraText.title),
          const SizedBox(height: AuraSpace.s8),
          Text(
            'For 30 days after you delete your account, you can bring it back. Enter the email the account used and we will send you a code.',
            style: muted,
          ),
          const SizedBox(height: AuraSpace.s20),
          TextField(
            controller: _email,
            enabled: !_busy && !codeStep,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
            style: AuraText.body,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'name@example.com',
            ),
            onSubmitted: (_) => codeStep ? null : _sendCode(),
          ),
          if (codeStep) ...[
            const SizedBox(height: AuraSpace.s14),
            TextField(
              controller: _code,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              style: AuraText.body,
              decoration: const InputDecoration(
                labelText: 'Code from the email',
                hintText: '6 digits',
              ),
              onSubmitted: (_) => _restore(),
            ),
          ],
          const SizedBox(height: AuraSpace.s20),
          AuraPrimaryButton(
            label: _busy
                ? (codeStep ? 'Restoring…' : 'Sending…')
                : (codeStep ? 'Restore account' : 'Send code'),
            onPressed: _busy ? null : (codeStep ? _restore : _sendCode),
            icon: codeStep ? Icons.restore_rounded : Icons.send_rounded,
          ),
          if (codeStep) ...[
            const SizedBox(height: AuraSpace.s10),
            AuraGhostButton(
              label: 'Send a new code',
              onPressed: _busy ? null : _sendCode,
              icon: Icons.refresh_rounded,
            ),
          ],
          const SizedBox(height: AuraSpace.s10),
          AuraGhostButton(
            label: 'Back to sign in',
            onPressed: _busy ? null : _toSignIn,
          ),
        ];
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
              constraints: const BoxConstraints(maxWidth: kFormWidth),
              child: AuraCard(
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: chamberTone(context, AuraSurface.accentSoft),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _step == _Step.restored
                              ? Icons.check_rounded
                              : Icons.restore_rounded,
                          size: 22,
                          color: chamberTone(context, AuraSurface.accentText),
                        ),
                      ),
                      const SizedBox(height: AuraSpace.s14),
                      ...content,
                      if (_message != null) ...[
                        const SizedBox(height: AuraSpace.s16),
                        Semantics(
                          liveRegion: true,
                          child: _RestoreMessage(
                            message: _message!,
                            isError: _messageIsError,
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
      ),
    );
  }
}

class _RestoreMessage extends StatelessWidget {
  const _RestoreMessage({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final ink = isError ? AuraSurface.coRose : AuraSurface.coVerdant;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AuraSpace.s14),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: 0.16),
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
