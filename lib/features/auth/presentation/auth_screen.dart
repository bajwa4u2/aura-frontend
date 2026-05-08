import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/remembered_identifier.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../auth_controller.dart';

enum _LoginStep { credentials, emailCode }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.redirectTo, this.email, this.notice});

  final String? redirectTo;
  final String? email;
  final String? notice;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeFormKey = GlobalKey<FormState>();
  late final TextEditingController _emailCtrl;
  final _passwordCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  _LoginStep _step = _LoginStep.credentials;
  bool _busy = false;
  bool _obscurePassword = true;
  String? _error;
  bool _needsVerification = false;

  // Remember email
  bool _rememberEmail = false;

  // Challenge state
  String _challengeId = '';
  String _maskedEmail = '';
  bool _codeSent = true;

  // Trust device
  bool _trustDevice = false;

  // Resend cooldown
  int _resendCooldown = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: (widget.email ?? '').trim());
    _loadRememberedIdentifier();
  }

  Future<void> _loadRememberedIdentifier() async {
    if ((widget.email ?? '').trim().isNotEmpty) return;
    final saved = await RememberedIdentifier.load();
    if (saved != null && saved.isNotEmpty && mounted) {
      setState(() {
        _emailCtrl.text = saved;
        _rememberEmail = true;
      });
    }
  }

  String? _safeRedirectOrNull(String? r) {
    final v = (r ?? '').trim();
    if (v.isEmpty) return null;
    if (!v.startsWith('/')) return null;
    return v;
  }

  String _withRedirect(String path) {
    final redirect = _safeRedirectOrNull(widget.redirectTo);
    if (redirect == null) return path;
    return '$path?redirect=${Uri.encodeComponent(redirect)}';
  }

  String? _emailValidator(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Email is required';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
    if (!ok) return 'Enter a valid email';
    return null;
  }

  String? _passwordValidator(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Password is required';
    return null;
  }

  String? _codeValidator(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Code is required';
    if (s.length < 4) return 'Enter the full code';
    return null;
  }

  String _humanizeLoginError(Object error) {
    final raw = error.toString().trim();
    final msg = raw.toLowerCase();
    if (msg.isEmpty) return 'We could not sign you in right now. Please try again.';
    if (msg.contains('invalid credentials') ||
        msg.contains('does not look right') ||
        msg.contains('401') ||
        msg.contains('unauthorized')) {
      return 'The email or password does not look right.';
    }
    if (msg.contains('verify your email') ||
        msg.contains('email not verified') ||
        msg.contains('unverified')) {
      return 'Please verify your email first, then try signing in again.';
    }
    if (msg.contains('account disabled') ||
        msg.contains('account locked') ||
        msg.contains('account suspended') ||
        msg.contains('forbidden')) {
      return 'This account is not available right now. Please contact support.';
    }
    if (msg.contains('socketexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('connection') ||
        msg.contains('timed out')) {
      return 'We could not reach the server. Check your connection and try again.';
    }
    if (msg.contains('500') || msg.contains('server error')) {
      return 'Something went wrong on our side. Please try again in a moment.';
    }
    if (msg.contains('429') || msg.contains('too many')) {
      return 'Too many attempts in a short time. Please wait a little and try again.';
    }
    return 'We could not sign you in right now. Please try again.';
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (_busy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _error = null;
      _needsVerification = false;
    });

    final email = _emailCtrl.text.trim();
    final pass = _passwordCtrl.text;

    try {
      // Persist or clear remembered identifier
      if (_rememberEmail) {
        await RememberedIdentifier.save(email);
      } else {
        await RememberedIdentifier.remove();
      }

      final result = await AuthController(ref).login(email: email, password: pass);

      if (!mounted) return;

      if (result['status'] == 'challenge') {
        // Email-code flow
        final codeSentRaw = result['codeSent'];
        final codeSent = codeSentRaw is bool ? codeSentRaw : true;
        setState(() {
          _step = _LoginStep.emailCode;
          _challengeId = result['challengeId']?.toString() ?? '';
          _maskedEmail = result['maskedEmail']?.toString() ?? email;
          _codeSent = codeSent;
          _error = codeSent
              ? null
              : 'We could not send the sign-in code email just now. Tap "Resend" to try again.';
          _busy = false;
        });
        _startResendCooldown(60);
        return;
      }

      // Logged in — router handles redirect
    } catch (e) {
      if (!mounted) return;
      final msg = _humanizeLoginError(e);
      setState(() {
        _error = msg;
        _needsVerification = msg.toLowerCase().contains('verify your email first');
      });
    } finally {
      if (mounted && _step == _LoginStep.credentials) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _verifyCode() async {
    FocusScope.of(context).unfocus();
    if (_busy) return;
    if (!(_codeFormKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await AuthController(ref).verifyLoginCode(
        challengeId: _challengeId,
        code: _codeCtrl.text.trim(),
        trustDevice: _trustDevice,
      );
      // Session set — router redirects automatically
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resendCode() async {
    if (_busy || _resendCooldown > 0) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final result = await AuthController(ref).resendLoginCode(_challengeId);
      if (!mounted) return;
      // Server may report the resend failed at the email layer.
      final codeSentRaw = result['codeSent'];
      final codeSent = codeSentRaw is bool ? codeSentRaw : true;
      setState(() {
        _codeSent = codeSent;
        _error = codeSent
            ? null
            : 'We could not send the sign-in code email just now. Please try again in a moment.';
      });
      _startResendCooldown(60);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startResendCooldown(int seconds) {
    _resendTimer?.cancel();
    setState(() => _resendCooldown = seconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) {
          _resendCooldown = 0;
          t.cancel();
        }
      });
    });
  }

  void _backToLogin() {
    _resendTimer?.cancel();
    setState(() {
      _step = _LoginStep.credentials;
      _challengeId = '';
      _maskedEmail = '';
      _codeSent = true;
      _codeCtrl.clear();
      _error = null;
      _resendCooldown = 0;
      _trustDevice = false;
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _codeCtrl.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final redirect = _safeRedirectOrNull(widget.redirectTo);
    final successNotice = (widget.notice ?? '').trim().toLowerCase();
    final hasNotice = successNotice == 'verified' || successNotice == 'reset';

    final formWidget = _step == _LoginStep.emailCode
        ? _EmailCodeCard(
            maskedEmail: _maskedEmail,
            busy: _busy,
            error: _error,
            codeSent: _codeSent,
            formKey: _codeFormKey,
            codeCtrl: _codeCtrl,
            codeValidator: _codeValidator,
            resendCooldown: _resendCooldown,
            trustDevice: _trustDevice,
            onTrustDeviceChanged: (v) => setState(() => _trustDevice = v ?? false),
            onVerify: _verifyCode,
            onResend: _resendCode,
            onBack: _backToLogin,
          )
        : _LoginFormCard(
            successNotice: hasNotice ? successNotice : null,
            busy: _busy,
            error: _error,
            needsVerification: _needsVerification,
            formKey: _formKey,
            emailCtrl: _emailCtrl,
            passwordCtrl: _passwordCtrl,
            obscurePassword: _obscurePassword,
            rememberEmail: _rememberEmail,
            emailValidator: _emailValidator,
            passwordValidator: _passwordValidator,
            onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword),
            onRememberEmailChanged: (v) => setState(() => _rememberEmail = v ?? false),
            onLogin: _login,
            onForgotPassword: () => context.push(_withRedirect('/forgot-password')),
            onCreateAccount: () => context.push(_withRedirect('/register')),
            onResendVerification: _needsVerification
                ? () => context.push(
                    '/verify-pending?email=${Uri.encodeComponent(_emailCtrl.text.trim())}'
                    '${redirect != null ? '&redirect=${Uri.encodeComponent(redirect)}' : ''}',
                  )
                : null,
          );

    return AuraScaffold(
      title: 'Login',
      body: AuraPageShell(
        maxWidth: 1160,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 960;
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 24 + bottomInset),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1160),
                    child: isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Expanded(
                                child: _AuthHero(
                                  title: 'Welcome back',
                                  body:
                                      'Sign in to continue your work, conversations, institutions, and publishing history.',
                                  accent:
                                      'Aura keeps communication, identity, and publication in one place.',
                                ),
                              ),
                              const SizedBox(width: AuraSpace.s16),
                              SizedBox(width: 460, child: formWidget),
                            ],
                          )
                        : Column(
                            children: [
                              const _AuthHero(
                                title: 'Welcome back',
                                body:
                                    'Sign in to continue your work, conversations, institutions, and publishing history.',
                                accent:
                                    'Aura keeps communication, identity, and publication in one place.',
                              ),
                              const SizedBox(height: AuraSpace.s16),
                              formWidget,
                            ],
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Email-code card ───────────────────────────────────────────────────────────

class _EmailCodeCard extends StatelessWidget {
  const _EmailCodeCard({
    required this.maskedEmail,
    required this.busy,
    required this.error,
    required this.codeSent,
    required this.formKey,
    required this.codeCtrl,
    required this.codeValidator,
    required this.resendCooldown,
    required this.trustDevice,
    required this.onTrustDeviceChanged,
    required this.onVerify,
    required this.onResend,
    required this.onBack,
  });

  final String maskedEmail;
  final bool busy;
  final String? error;
  final bool codeSent;
  final GlobalKey<FormState> formKey;
  final TextEditingController codeCtrl;
  final String? Function(String?) codeValidator;
  final int resendCooldown;
  final bool trustDevice;
  final ValueChanged<bool?> onTrustDeviceChanged;
  final VoidCallback onVerify;
  final VoidCallback onResend;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AuraSurface.accentSoft,
                    borderRadius: BorderRadius.circular(AuraRadius.sm),
                  ),
                  child: const Icon(
                    Icons.mark_email_unread_outlined,
                    size: 16,
                    color: AuraSurface.accentText,
                  ),
                ),
                const SizedBox(width: AuraSpace.s10),
                Text(
                  'Check your email',
                  style: AuraText.title.copyWith(fontSize: 22),
                ),
              ],
            ),
            const SizedBox(height: AuraSpace.s10),
            Text(
              codeSent
                  ? 'We sent a 6-digit code to $maskedEmail. Enter it below to continue.'
                  : 'A code is required to continue, but our email service did not deliver it just now. Tap "Resend" to try again.',
              style: AuraText.body.copyWith(color: AuraSurface.muted, height: 1.5),
            ),
            const SizedBox(height: AuraSpace.s16),
            if (error != null) ...[
              AuraErrorState(title: 'Verification failed', body: error!),
              const SizedBox(height: AuraSpace.s10),
            ],
            AuraInput(
              controller: codeCtrl,
              label: 'Sign-in code',
              hint: '000000',
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              validator: codeValidator,
              prefixIcon: const Icon(Icons.pin_outlined),
            ),
            const SizedBox(height: AuraSpace.s10),
            Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: trustDevice,
                    onChanged: busy ? null : onTrustDeviceChanged,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: AuraSpace.s8),
                GestureDetector(
                  onTap: busy ? null : () => onTrustDeviceChanged(!trustDevice),
                  child: Text(
                    'Trust this device for 60 days',
                    style: AuraText.small.copyWith(color: AuraSurface.muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AuraSpace.s14),
            SizedBox(
              width: double.infinity,
              child: AuraPrimaryButton(
                label: busy ? 'Verifying…' : 'Verify code',
                onPressed: busy ? null : onVerify,
                icon: Icons.check_rounded,
              ),
            ),
            const SizedBox(height: AuraSpace.s10),
            Row(
              children: [
                AuraGhostButton(
                  label: 'Back to login',
                  onPressed: busy ? null : onBack,
                  icon: Icons.arrow_back_rounded,
                ),
                const Spacer(),
                AuraSecondaryButton(
                  label: resendCooldown > 0
                      ? 'Resend in ${resendCooldown}s'
                      : 'Resend code',
                  onPressed: (busy || resendCooldown > 0) ? null : onResend,
                  icon: Icons.refresh_rounded,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Credentials card ──────────────────────────────────────────────────────────

class _LoginFormCard extends StatelessWidget {
  const _LoginFormCard({
    required this.successNotice,
    required this.busy,
    required this.error,
    required this.needsVerification,
    required this.formKey,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.obscurePassword,
    required this.rememberEmail,
    required this.emailValidator,
    required this.passwordValidator,
    required this.onTogglePassword,
    required this.onRememberEmailChanged,
    required this.onLogin,
    required this.onForgotPassword,
    required this.onCreateAccount,
    required this.onResendVerification,
  });

  final String? successNotice;
  final bool busy;
  final String? error;
  final bool needsVerification;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final bool obscurePassword;
  final bool rememberEmail;
  final String? Function(String?) emailValidator;
  final String? Function(String?) passwordValidator;
  final VoidCallback onTogglePassword;
  final ValueChanged<bool?> onRememberEmailChanged;
  final VoidCallback onLogin;
  final VoidCallback onForgotPassword;
  final VoidCallback onCreateAccount;
  final VoidCallback? onResendVerification;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Form(
        key: formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (successNotice != null) ...[
                _NoticeBanner(
                  title: successNotice == 'reset' ? 'Password updated' : 'Email verified',
                  body: successNotice == 'reset'
                      ? 'Your password has been updated. Sign in with your new password.'
                      : 'Your email has been verified. You can sign in now.',
                ),
                const SizedBox(height: AuraSpace.s12),
              ],
              Text('Sign in', style: AuraText.title.copyWith(fontSize: 26)),
              const SizedBox(height: AuraSpace.s8),
              const Text(
                'Continue with your current session and keep your work connected.',
                style: AuraText.body,
              ),
              const SizedBox(height: AuraSpace.s14),
              if (error != null) ...[
                AuraErrorState(title: 'Sign-in failed', body: error!),
                const SizedBox(height: AuraSpace.s10),
                if (needsVerification && onResendVerification != null) ...[
                  AuraSecondaryButton(
                    label: 'Resend verification',
                    onPressed: busy ? null : onResendVerification,
                    icon: Icons.mark_email_unread_outlined,
                  ),
                  const SizedBox(height: AuraSpace.s8),
                ],
              ],
              AuraInput(
                controller: emailCtrl,
                label: 'Email',
                hint: 'name@example.com',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: emailValidator,
                prefixIcon: const Icon(Icons.email_outlined),
              ),
              const SizedBox(height: AuraSpace.s10),
              AuraInput(
                controller: passwordCtrl,
                label: 'Password',
                obscureText: obscurePassword,
                textInputAction: TextInputAction.done,
                validator: passwordValidator,
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: busy ? null : onTogglePassword,
                  icon: Icon(
                    obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
              const SizedBox(height: AuraSpace.s8),
              // Remember email checkbox
              Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: rememberEmail,
                      onChanged: busy ? null : onRememberEmailChanged,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: AuraSpace.s8),
                  GestureDetector(
                    onTap: busy ? null : () => onRememberEmailChanged(!rememberEmail),
                    child: Text(
                      'Remember email',
                      style: AuraText.small.copyWith(color: AuraSurface.muted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AuraSpace.s14),
              SizedBox(
                width: double.infinity,
                child: AuraPrimaryButton(
                  label: busy ? 'Signing in…' : 'Sign in',
                  onPressed: busy ? null : onLogin,
                  icon: Icons.arrow_forward_rounded,
                ),
              ),
              const SizedBox(height: AuraSpace.s10),
              Row(
                children: [
                  AuraGhostButton(
                    label: 'Forgot password',
                    onPressed: busy ? null : onForgotPassword,
                    icon: Icons.lock_reset_rounded,
                  ),
                  const Spacer(),
                  AuraSecondaryButton(
                    label: 'Create account',
                    onPressed: busy ? null : onCreateAccount,
                    icon: Icons.person_add_alt_1_rounded,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Hero ──────────────────────────────────────────────────────────────────────

class _AuthHero extends StatelessWidget {
  const _AuthHero({required this.title, required this.body, required this.accent});

  final String title;
  final String body;
  final String accent;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      padding: const EdgeInsets.all(AuraSpace.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AuraBadge(label: 'Trusted access', icon: Icons.shield_outlined),
          const SizedBox(height: AuraSpace.s16),
          Text(title, style: AuraText.title.copyWith(fontSize: 34, height: 1.05)),
          const SizedBox(height: AuraSpace.s12),
          Text(
            body,
            style: AuraText.body.copyWith(color: AuraSurface.muted, height: 1.6),
          ),
          const SizedBox(height: AuraSpace.s20),
          const _AuthFeatureRow(
            icon: Icons.edit_note_rounded,
            label: 'Your publishing record and work history',
          ),
          const SizedBox(height: AuraSpace.s10),
          const _AuthFeatureRow(
            icon: Icons.apartment_rounded,
            label: 'Institutional affiliations and credentials',
          ),
          const SizedBox(height: AuraSpace.s10),
          const _AuthFeatureRow(
            icon: Icons.mail_outline_rounded,
            label: 'Direct correspondence and shared spaces',
          ),
          const SizedBox(height: AuraSpace.s20),
          Text(
            accent,
            style: AuraText.small.copyWith(color: AuraSurface.faint, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _AuthFeatureRow extends StatelessWidget {
  const _AuthFeatureRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AuraSurface.accentSoft,
            borderRadius: BorderRadius.circular(AuraRadius.sm),
            border: Border.all(color: AuraSurface.accent.withValues(alpha: 0.2)),
          ),
          child: Icon(icon, size: 14, color: AuraSurface.accentText),
        ),
        const SizedBox(width: AuraSpace.s10),
        Expanded(
          child: Text(
            label,
            style: AuraText.small.copyWith(color: AuraSurface.muted, height: 1.4),
          ),
        ),
      ],
    );
  }
}

// ── Notice banner ─────────────────────────────────────────────────────────────

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AuraSpace.s14),
      decoration: BoxDecoration(
        color: AuraSurface.goodBg,
        borderRadius: BorderRadius.circular(AuraRadius.md),
        border: Border.all(color: AuraSurface.goodInk.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AuraText.small.copyWith(
              color: AuraSurface.goodInk,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: AuraText.small.copyWith(color: AuraSurface.goodInk, height: 1.45),
          ),
        ],
      ),
    );
  }
}
