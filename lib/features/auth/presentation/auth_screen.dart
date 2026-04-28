import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../auth_controller.dart';

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
  late final TextEditingController _emailCtrl;
  final _passwordCtrl = TextEditingController();

  bool _busy = false;
  bool _obscurePassword = true;
  String? _error;
  bool _needsVerification = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: (widget.email ?? '').trim());
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

  String _humanizeLoginError(Object error) {
    final raw = error.toString().trim();
    final msg = raw.toLowerCase();

    if (msg.isEmpty) {
      return 'We could not sign you in right now. Please try again.';
    }

    if (msg.contains('the email or password does not look right')) {
      return 'The email or password does not look right.';
    }

    if (msg.contains('please verify your email first')) {
      return 'Please verify your email first, then try signing in again.';
    }

    if (msg.contains('this account is not available right now')) {
      return 'This account is not available right now. Please contact support if needed.';
    }

    if (msg.contains('invalid credentials') ||
        msg.contains('invalid login') ||
        msg.contains('wrong password') ||
        msg.contains('incorrect password') ||
        msg.contains('incorrect email') ||
        msg.contains('incorrect email or password') ||
        msg.contains('wrong email or password') ||
        msg.contains('email or password is incorrect') ||
        msg.contains('invalid email or password') ||
        msg.contains('unauthorized') ||
        msg.contains('401')) {
      return 'The email or password does not look right.';
    }

    if (msg.contains('email not verified') ||
        msg.contains('verify your email') ||
        msg.contains('email verification required') ||
        msg.contains('unverified')) {
      return 'Please verify your email first, then try signing in again.';
    }

    if (msg.contains('account disabled') ||
        msg.contains('account locked') ||
        msg.contains('account suspended')) {
      return 'This account is not available right now. Please contact support if needed.';
    }

    if (msg.contains('network error') ||
        msg.contains('socketexception') ||
        msg.contains('connection error') ||
        msg.contains('connection refused') ||
        msg.contains('failed host lookup') ||
        msg.contains('timed out') ||
        msg.contains('timeoutexception')) {
      return 'We could not reach the server. Check your connection and try again.';
    }

    if (msg.contains('500') ||
        msg.contains('internal server error') ||
        msg.contains('server error')) {
      return 'Something went wrong on our side. Please try again in a moment.';
    }

    if (msg.contains('429') || msg.contains('too many requests')) {
      return 'Too many attempts in a short time. Please wait a little and try again.';
    }

    if (msg.contains('403') || msg.contains('forbidden')) {
      return 'This sign-in request could not be completed right now.';
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
    });

    try {
      final email = _emailCtrl.text.trim();
      final pass = _passwordCtrl.text;

      await AuthController(ref).login(email: email, password: pass);

      // Router remains the single authority after auth state changes.
    } catch (e) {
      if (!mounted) return;
      final msg = _humanizeLoginError(e);
      setState(() {
        _error = msg;
        _needsVerification = msg.toLowerCase().contains('verify your email first');
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
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final redirect = _safeRedirectOrNull(widget.redirectTo);
    final successNotice = (widget.notice ?? '').trim().toLowerCase();
    final hasNotice = successNotice == 'verified' || successNotice == 'reset';

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
                              SizedBox(
                                width: 460,
                                child: _LoginFormCard(
                                  successNotice: hasNotice ? successNotice : null,
                                  busy: _busy,
                                  error: _error,
                                  needsVerification: _needsVerification,
                                  formKey: _formKey,
                                  emailCtrl: _emailCtrl,
                                  passwordCtrl: _passwordCtrl,
                                  obscurePassword: _obscurePassword,
                                  emailValidator: _emailValidator,
                                  passwordValidator: _passwordValidator,
                                  onTogglePassword: () => setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  }),
                                  onLogin: _login,
                                  onForgotPassword: () => context.push(
                                    _withRedirect('/forgot-password'),
                                  ),
                                  onCreateAccount: () =>
                                      context.push(_withRedirect('/register')),
                                  onResendVerification: _needsVerification
                                      ? () => context.push(
                                          '/verify-pending?email=${Uri.encodeComponent(_emailCtrl.text.trim())}${redirect != null ? '&redirect=${Uri.encodeComponent(redirect)}' : ''}',
                                        )
                                      : null,
                                ),
                              ),
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
                              _LoginFormCard(
                                successNotice: hasNotice ? successNotice : null,
                                busy: _busy,
                                error: _error,
                                needsVerification: _needsVerification,
                                formKey: _formKey,
                                emailCtrl: _emailCtrl,
                                passwordCtrl: _passwordCtrl,
                                obscurePassword: _obscurePassword,
                                emailValidator: _emailValidator,
                                passwordValidator: _passwordValidator,
                                onTogglePassword: () => setState(() {
                                  _obscurePassword = !_obscurePassword;
                                }),
                                onLogin: _login,
                                onForgotPassword: () => context.push(
                                  _withRedirect('/forgot-password'),
                                ),
                                onCreateAccount: () =>
                                    context.push(_withRedirect('/register')),
                                onResendVerification: _needsVerification
                                    ? () => context.push(
                                        '/verify-pending?email=${Uri.encodeComponent(_emailCtrl.text.trim())}${redirect != null ? '&redirect=${Uri.encodeComponent(redirect)}' : ''}',
                                      )
                                    : null,
                              ),
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

class _AuthHero extends StatelessWidget {
  const _AuthHero({
    required this.title,
    required this.body,
    required this.accent,
  });

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
          Text(
            title,
            style: AuraText.title.copyWith(fontSize: 34, height: 1.05),
          ),
          const SizedBox(height: AuraSpace.s12),
          Text(
            body,
            style: AuraText.body.copyWith(
              color: AuraSurface.muted,
              height: 1.6,
            ),
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
            style: AuraText.small.copyWith(
              color: AuraSurface.faint,
              height: 1.5,
            ),
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
            border: Border.all(
              color: AuraSurface.accent.withValues(alpha: 0.2),
            ),
          ),
          child: Icon(icon, size: 14, color: AuraSurface.accentText),
        ),
        const SizedBox(width: AuraSpace.s10),
        Expanded(
          child: Text(
            label,
            style: AuraText.small.copyWith(
              color: AuraSurface.muted,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

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
    required this.emailValidator,
    required this.passwordValidator,
    required this.onTogglePassword,
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
  final String? Function(String?) emailValidator;
  final String? Function(String?) passwordValidator;
  final VoidCallback onTogglePassword;
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
                  title: successNotice == 'reset'
                      ? 'Password updated'
                      : 'Email verified',
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
            style: AuraText.small.copyWith(
              color: AuraSurface.goodInk,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
