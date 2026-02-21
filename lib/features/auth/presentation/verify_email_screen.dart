import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/auth/token_store.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, this.redirectTo});

  final String? redirectTo;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _busy = false;
  String? _msg;

  String _safeRedirect(String? r) {
    final v = (r ?? '').trim();
    if (v.isEmpty) return '/home';
    if (!v.startsWith('/')) return '/home';
    return v;
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _resend() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _msg = null;
    });

    try {
      final dio = ref.read(dioProvider);

      // Backend standardized: { success: true, data: ... }
      await dio.post('/v1/auth/resend-verification');

      if (!mounted) return;
      _snack('Verification email resent. Check inbox/spam.');
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      setState(() => _msg = 'Resend failed (${status ?? 'no status'}).');
    } catch (e) {
      setState(() => _msg = 'Resend failed. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkAndContinue() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _msg = null;
    });

    try {
      // Force refresh of verification status
      ref.invalidate(emailVerifiedProvider);
      final ok = await ref.read(emailVerifiedProvider.future);

      if (!ok) {
        setState(() => _msg = 'Still not verified. Please verify, then try again.');
        return;
      }

      if (!mounted) return;
      context.go(_safeRedirect(widget.redirectTo));
    } catch (e) {
      setState(() => _msg = 'Could not check status. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _msg = null;
    });

    try {
      final dio = ref.read(dioProvider);
      try {
        await dio.post('/v1/auth/logout');
      } catch (_) {}

      await ref.read(tokenStoreProvider).clear();
      ref.invalidate(emailVerifiedProvider);

      if (!mounted) return;
      context.go('/login');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAuthed = ref.watch(isAuthedProvider);

    if (!isAuthed) {
      return AuraScaffold(
        title: 'Verify email',
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: AuraCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('You are not signed in.', style: AuraText.body),
                  const SizedBox(height: AuraSpace.s16),
                  FilledButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return AuraScaffold(
      title: 'Verify email',
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('One more step', style: AuraText.title),
                const SizedBox(height: AuraSpace.s10),
                Text(
                  'Your account is created, but email is not verified yet. Please verify to continue.',
                  style: AuraText.body,
                ),
                const SizedBox(height: AuraSpace.s12),
                if (_msg != null) ...[
                  Text(_msg!, style: AuraText.body.copyWith(color: Colors.red)),
                  const SizedBox(height: AuraSpace.s10),
                ],
                Wrap(
                  spacing: AuraSpace.s10,
                  runSpacing: AuraSpace.s10,
                  children: [
                    FilledButton(
                      onPressed: _busy ? null : _resend,
                      child: Text(_busy ? 'Working…' : 'Resend verification email'),
                    ),
                    OutlinedButton(
                      onPressed: _busy ? null : _checkAndContinue,
                      child: const Text("I've verified, continue"),
                    ),
                    TextButton(
                      onPressed: _busy ? null : _logout,
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
