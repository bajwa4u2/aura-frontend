import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.redirectTo});

  final String? redirectTo;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String _safeRedirect(String? r) {
    final v = (r ?? '').trim();
    if (v.isEmpty) return '/me';
    if (!v.startsWith('/')) return '/me';
    return v;
  }

  String _extractBackendError(dynamic body) {
    if (body == null) return '';

    // Most common shapes we need to support:
    // 1) Nest default: { statusCode, message, error }
    // 2) Your structured errors: { error: { code, message, ... } }
    // 3) Other APIs: { message: [..] } or { message: "..." }
    if (body is Map) {
      final map = Map<String, dynamic>.from(body);

      // Nest: message could be String or List
      final msg = map['message'];
      if (msg is String && msg.trim().isNotEmpty) return msg.trim();
      if (msg is List && msg.isNotEmpty) {
        return msg.map((e) => e.toString()).join(', ').trim();
      }

      // Your structured error object: error: { message: "..." }
      final err = map['error'];
      if (err is String && err.trim().isNotEmpty) return err.trim();
      if (err is Map) {
        final errMap = Map<String, dynamic>.from(err);
        final em = errMap['message'];
        if (em is String && em.trim().isNotEmpty) return em.trim();
        if (em is List && em.isNotEmpty) {
          return em.map((e) => e.toString()).join(', ').trim();
        }
        final code = errMap['code'];
        if (code is String && code.trim().isNotEmpty) return code.trim();
      }

      // Sometimes APIs use: { detail: "..." } or { errorMessage: "..." }
      for (final key in ['detail', 'errorMessage', 'reason']) {
        final v = map[key];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
    }

    if (body is String) return body.trim();
    return body.toString().trim();
  }

  String _friendlyAuthMessage(int? status, String raw) {
    final r = raw.toLowerCase();

    if (status == 401 || status == 403) {
      if (r.contains('invalid') || r.contains('credentials') || r.contains('unauthorized')) {
        return 'Invalid email or password.';
      }
    }
    return raw.isEmpty ? '' : raw;
  }

  Future<void> _login() async {
    if (_busy) return;

    final email = _email.text.trim();
    final password = _password.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Email and password are required.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);

      // If later you move refresh token to cookies on web, keep this.
      final options = !kIsWeb ? Options(headers: {'x-token-transport': 'body'}) : null;

      final res = await dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
        options: options,
      );

      final data = res.data;
      if (data is! Map) throw Exception('Unexpected response');

      final map = Map<String, dynamic>.from(data as Map);

      final access = (map['accessToken'] as String?)?.trim();
      final refresh = (map['refreshToken'] as String?)?.trim(); // may be null on web

      if (access == null || access.isEmpty) {
        throw Exception('Missing accessToken');
      }

      await ref.read(tokenStoreProvider).setTokens(
            accessToken: access,
            refreshToken: (refresh != null && refresh.isNotEmpty) ? refresh : null,
          );

      // Warm-up call (non-blocking)
      // ignore: unawaited_futures
      () async {
        try {
          await dio.get('/auth/me');
        } catch (_) {}
      }();

      if (!mounted) return;
      context.go(_safeRedirect(widget.redirectTo));
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final raw = _extractBackendError(e.response?.data);
      final friendly = _friendlyAuthMessage(status, raw);

      setState(() {
        if (friendly.isEmpty) {
          _error = 'Login failed (${status ?? 'no status'}).';
        } else {
          _error = 'Login failed (${status ?? 'no status'}). $friendly';
        }
      });
    } catch (e) {
      setState(() => _error = 'Login failed. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAuthed = ref.watch(isAuthedProvider);
    final store = ref.watch(tokenStoreProvider);

    return AuraScaffold(
      title: 'Login',
      actions: [
        TextButton(
          onPressed: () => context.go('/public'),
          child: const Text('Back'),
        ),
      ],
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: EdgeInsets.fromLTRB(AuraSpace.s16, AuraSpace.s16, AuraSpace.s16, AuraSpace.s24),
            children: [
              if (isAuthed) ...[
                AuraCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Already signed in', style: AuraText.title),
                      const SizedBox(height: AuraSpace.s6),
                      Text('User ID: ${store.userId ?? '-'}', style: AuraText.body),
                      const SizedBox(height: AuraSpace.s12),
                      Wrap(
                        spacing: AuraSpace.s10,
                        runSpacing: AuraSpace.s10,
                        children: [
                          FilledButton(
                            onPressed: () => context.go(_safeRedirect(widget.redirectTo)),
                            child: const Text('Continue'),
                          ),
                          OutlinedButton(
                            onPressed: () async {
                              await ref.read(tokenStoreProvider).clear();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Session cleared.')),
                              );
                            },
                            child: const Text('Clear session'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AuraSpace.s16),
              ],

              AuraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sign in', style: AuraText.title),
                    const SizedBox(height: AuraSpace.s10),

                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: AuraSpace.s10),

                    TextField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password'),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: AuraSpace.s12),
                      Text(_error!, style: AuraText.body.copyWith(color: Colors.red)),
                    ],

                    const SizedBox(height: AuraSpace.s16),
                    FilledButton(
                      onPressed: _busy ? null : _login,
                      child: Text(_busy ? 'Signing in…' : 'Login'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AuraSpace.s12),

              AuraCard(
                child: Text(
                  'If you just registered, you may need to verify your email. '
                  'If login succeeds, Aura will guide you to verification.',
                  style: AuraText.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
