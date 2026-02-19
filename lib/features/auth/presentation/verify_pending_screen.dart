import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../../../app/app_router.dart'; // for meForGateProvider

class VerifyPendingScreen extends ConsumerStatefulWidget {
  const VerifyPendingScreen({super.key, this.redirectTo});
  final String? redirectTo;

  @override
  ConsumerState<VerifyPendingScreen> createState() => _VerifyPendingScreenState();
}

class _VerifyPendingScreenState extends ConsumerState<VerifyPendingScreen> {
  bool _busy = false;
  String? _error;
  String? _info;

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
      _error = null;
      _info = null;
    });

    try {
      final dio = ref.read(dioProvider);

      // Try to pass email if we can, but backend may not require it.
      final me = await ref.read(meForGateProvider.future);
      final email = (me?['email'] ?? '').toString().trim();

      final data = <String, dynamic>{};
      if (email.isNotEmpty) data['email'] = email;

      await dio.post('/auth/resend-verification', data: data.isEmpty ? null : data);

      if (!mounted) return;
      setState(() => _info = 'Verification email sent. Check your inbox and spam folder.');
      _snack('Verification email sent.');
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      setState(() => _error = 'Resend failed (${status ?? 'no status'}).');
    } catch (e) {
      setState(() => _error = 'Resend failed. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    final store = ref.read(tokenStoreProvider);
    await store.clear();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final meAsync = ref.watch(meForGateProvider);

    return AuraScaffold(
      title: 'Verify your email',
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: EdgeInsets.fromLTRB(AuraSpace.s16, AuraSpace.s16, AuraSpace.s16, AuraSpace.s24),
            children: [
              AuraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('One last step.', style: AuraText.title),
                    const SizedBox(height: AuraSpace.s10),
                    Text(
                      'To protect the space, Aura requires email verification before you can continue.',
                      style: AuraText.body,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AuraSpace.s14),

              meAsync.when(
                loading: () => const AuraCard(child: Padding(
                  padding: EdgeInsets.all(AuraSpace.s16),
                  child: Text('Loading account…'),
                )),
                error: (e, _) => AuraCard(child: Padding(
                  padding: const EdgeInsets.all(AuraSpace.s16),
                  child: Text('Could not load account: $e'),
                )),
                data: (me) {
                  final email = (me?['email'] ?? '').toString().trim();
                  return AuraCard(
                    child: Padding(
                      padding: const EdgeInsets.all(AuraSpace.s16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Email', style: AuraText.title),
                          const SizedBox(height: AuraSpace.s8),
                          Text(email.isEmpty ? '—' : email, style: AuraText.body),
                          const SizedBox(height: AuraSpace.s12),
                          Text(
                            'Check inbox and spam. The link expires; if needed, resend below.',
                            style: AuraText.muted,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: AuraSpace.s14),

              if (_error != null)
                AuraCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AuraSpace.s16),
                    child: Text(_error!, style: AuraText.body.copyWith(color: Colors.red)),
                  ),
                ),

              if (_info != null) ...[
                const SizedBox(height: AuraSpace.s12),
                AuraCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AuraSpace.s16),
                    child: Text(_info!, style: AuraText.body),
                  ),
                ),
              ],

              const SizedBox(height: AuraSpace.s14),

              AuraCard(
                child: Padding(
                  padding: const EdgeInsets.all(AuraSpace.s16),
                  child: Wrap(
                    spacing: AuraSpace.s10,
                    runSpacing: AuraSpace.s10,
                    children: [
                      FilledButton(
                        onPressed: _busy ? null : _resend,
                        child: Text(_busy ? 'Sending…' : 'Resend verification email'),
                      ),
                      OutlinedButton(
                        onPressed: _busy ? null : () {
                          // If user already verified in another tab, a refresh will release gate.
                          ref.invalidate(meForGateProvider);
                          _snack('Refreshing…');
                        },
                        child: const Text('I already verified'),
                      ),
                      OutlinedButton(
                        onPressed: _busy ? null : _logout,
                        child: const Text('Log out'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
