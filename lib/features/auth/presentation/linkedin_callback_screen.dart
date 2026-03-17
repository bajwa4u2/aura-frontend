import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth_controller.dart';

class LinkedInCallbackScreen extends ConsumerStatefulWidget {
  const LinkedInCallbackScreen({super.key});

  @override
  ConsumerState<LinkedInCallbackScreen> createState() =>
      _LinkedInCallbackScreenState();
}

class _LinkedInCallbackScreenState
    extends ConsumerState<LinkedInCallbackScreen> {
  bool _working = true;
  String? _error;
  bool _ran = false;

  String _safeRedirect(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return '/home';
    if (!v.startsWith('/')) return '/home';
    if (v == '/') return '/home';
    return v;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_finish());
  }

  Future<void> _finish() async {
    if (_ran) return;
    _ran = true;

    try {
      final uri = Uri.base;
      final controller = ref.read(authControllerProvider);
      final redirect = await controller.consumeLinkedInCallback(uri);

      if (!mounted) return;

      final target = _safeRedirect(redirect);
      context.go('/_boot?redirect=${Uri.encodeComponent(target)}');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = e.toString().trim().isEmpty
            ? 'LinkedIn sign-in could not be completed.'
            : e.toString().trim();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final redirectTo = _safeRedirect(Uri.base.queryParameters['redirect']);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _working
                ? const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      ),
                      SizedBox(height: 16),
                      Text('Completing LinkedIn sign-in…'),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 34),
                      const SizedBox(height: 16),
                      Text(
                        _error ?? 'LinkedIn sign-in could not be completed.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => context.go(
                          '/login?redirect=${Uri.encodeComponent(redirectTo)}',
                        ),
                        child: const Text('Back to sign in'),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}