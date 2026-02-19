import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, required this.token});
  final String? token;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _busy = false;
  String? _error;
  bool _done = false;

  Future<void> _verify() async {
    if (_busy || _done) return;

    final token = (widget.token ?? '').trim();
    if (token.isEmpty) {
      setState(() => _error = 'Missing token. Please open the verification link from your email.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);

      // Backend may accept token via body or query. We send in body.
      await dio.post('/auth/verify-email', data: {'token': token});

      if (!mounted) return;
      setState(() => _done = true);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      setState(() => _error = 'Verification failed (${status ?? 'no status'}).');
    } catch (e) {
      setState(() => _error = 'Verification failed. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    // Auto-run once.
    WidgetsBinding.instance.addPostFrameCallback((_) => _verify());
  }

  @override
  Widget build(BuildContext context) {
    return AuraScaffold(
      title: 'Verify email',
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: EdgeInsets.fromLTRB(AuraSpace.s16, AuraSpace.s16, AuraSpace.s16, AuraSpace.s24),
            children: [
              AuraCard(
                child: Padding(
                  padding: const EdgeInsets.all(AuraSpace.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Verifying…', style: AuraText.title),
                      const SizedBox(height: AuraSpace.s10),
                      Text(
                        'If this takes more than a few seconds, you can retry.',
                        style: AuraText.muted,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AuraSpace.s14),

              if (_error != null)
                AuraCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AuraSpace.s16),
                    child: Text(_error!, style: AuraText.body.copyWith(color: Colors.red)),
                  ),
                ),

              if (_done) ...[
                AuraCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AuraSpace.s16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Email verified.', style: AuraText.title),
                        const SizedBox(height: AuraSpace.s10),
                        Text('You can now login and continue.', style: AuraText.body),
                        const SizedBox(height: AuraSpace.s14),
                        FilledButton(
                          onPressed: () => context.go('/login'),
                          child: const Text('Go to login'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              if (!_done) ...[
                const SizedBox(height: AuraSpace.s14),
                AuraCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AuraSpace.s16),
                    child: Wrap(
                      spacing: AuraSpace.s10,
                      runSpacing: AuraSpace.s10,
                      children: [
                        FilledButton(
                          onPressed: _busy ? null : _verify,
                          child: Text(_busy ? 'Verifying…' : 'Retry verification'),
                        ),
                        OutlinedButton(
                          onPressed: () => context.go('/login'),
                          child: const Text('Back to login'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
