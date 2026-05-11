import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_providers.dart';
import '../core/net/dio_provider.dart';

/// Self-serve account deletion.
///
/// Apple App Store guideline 5.1.1(v) and Google Play data-deletion
/// policy both require this flow to live inside the app. The original
/// version of this screen redirected users to email support, which is
/// non-compliant and could trigger automatic review rejection.
///
/// Safety pattern (irreversible action):
///   1. Re-authenticate with current password (defense-in-depth — a
///      stolen JWT alone cannot trigger deletion).
///   2. Require the user to type "DELETE" verbatim — guards against
///      accidental taps and confirms intent.
///   3. Two-stage UI: review → confirm → submit. Each stage requires an
///      explicit action.
///   4. After success: clear local tokens and route to /auth. The
///      backend has already revoked every session and scrubbed PII.
///
/// Email support remains as a secondary path for users who cannot
/// access the in-app flow (locked out, etc.) — see the footer note.
class AccountDeletionScreen extends ConsumerStatefulWidget {
  const AccountDeletionScreen({super.key});

  @override
  ConsumerState<AccountDeletionScreen> createState() =>
      _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends ConsumerState<AccountDeletionScreen> {
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _submitting = false;
  String? _error;
  bool _stagedConfirm = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  bool get _confirmTextValid =>
      _confirmationController.text.trim() == 'DELETE';

  bool get _canSubmit =>
      _passwordController.text.isNotEmpty &&
      _confirmTextValid &&
      _stagedConfirm &&
      !_submitting;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    final dio = ref.read(dioProvider);
    try {
      await dio.delete<dynamic>(
        '/v1/users/me',
        data: {
          'currentPassword': _passwordController.text,
          'confirmation': 'DELETE',
        },
      );

      if (!mounted) return;

      // Backend already revoked every session; locally we must also
      // clear tokens so the next route eval sees unauthed state.
      try {
        await ref.read(tokenStoreProvider).clearTokens();
      } catch (_) {}

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Account deleted'),
          content: const Text(
            'Your account has been deactivated and your personal data has '
            'been scrubbed. You will be signed out now.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      context.go('/auth');
    } on DioException catch (e) {
      if (!mounted) return;
      final code = _readErrorCode(e);
      final message = _readErrorMessage(e);
      setState(() {
        _error = _mapErrorMessage(code, message);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not delete account: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  String _readErrorCode(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final err = data['error'];
      if (err is Map && err['code'] is String) return err['code'] as String;
      if (data['code'] is String) return data['code'] as String;
    }
    return '';
  }

  String _readErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final err = data['error'];
      if (err is Map && err['message'] is String) {
        return err['message'] as String;
      }
      if (data['message'] is String) return data['message'] as String;
    }
    return e.message ?? 'Request failed';
  }

  String _mapErrorMessage(String code, String message) {
    switch (code) {
      case 'PASSWORD_INVALID':
        return 'That password is not correct.';
      case 'PASSWORD_REQUIRED':
        return 'Enter your current password to continue.';
      case 'CONFIRMATION_REQUIRED':
        return 'Type the word DELETE to confirm.';
      default:
        return message.isNotEmpty
            ? message
            : 'Could not delete account. Try again or email support.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delete account'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Delete your Aura account',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const Text(
                'Deletion is permanent. Your profile, posts, replies, '
                'media, and direct correspondence will be removed from '
                'Aura. Some operational records (audit logs, billing '
                'history) are retained where legal compliance, fraud '
                'prevention, or platform safety obligations require it.',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 24),
              const _Divider(),
              const SizedBox(height: 16),
              const Text(
                'Step 1 — confirm your password',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: true,
                enabled: !_submitting,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              const Text(
                'Step 2 — type DELETE to confirm',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmationController,
                enabled: !_submitting,
                decoration: const InputDecoration(
                  labelText: 'Type DELETE',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              CheckboxListTile(
                value: _stagedConfirm,
                onChanged: _submitting
                    ? null
                    : (v) => setState(() => _stagedConfirm = v ?? false),
                title: const Text(
                  'I understand this is permanent and cannot be undone.',
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _canSubmit ? _submit : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4),
                        )
                      : const Text(
                          'Permanently delete my account',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              const _Divider(),
              const SizedBox(height: 12),
              Text(
                'Unable to sign in? Email support@auraplatform.org with '
                'the subject "Account Deletion Request" and we will verify '
                'and remove your account manually.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: Theme.of(context).dividerColor,
    );
  }
}
