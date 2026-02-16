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
    if (body is Map) {
      final msg = body['message'];
      if (msg is List) return msg.map((e) => e.toString()).join(', ');
      if (msg is String) return msg;
      if (body['error'] is String) return body['error'] as String;
    }
    if (body is String) return body;
    return '';
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

      // Backend contract:
      // - Web: refresh token is httpOnly cookie; body usually { user, accessToken }
      // - Non-web: request body transport to also receive refreshToken in body
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
      final refresh = (map['refreshToken'] as String?)?.trim(); // may be null on web (cookie-based)

      if (access == null || access.isEmpty) {
        throw Exception('Missing accessToken');
      }

      await ref.read(tokenStoreProvider).setTokens(
            accessToken: access,
            refreshToken: (refresh != null && refresh.isNotEmpty) ? refresh : null,
          );

      // Optional: warm up session validity (won't block navigation if it fails)
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
      final extra = _extractBackendError(e.response?.data).trim();
      setState(() {
        _error = extra.isEmpty ? 'Login failed (${status ?? 'no status'}).' : 'Login failed (${status ?? 'no status'}). $extra';
      });
    } catch (e) {
      setState(() => _error = 'Login failed. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fillTestAccount() {
    _email.text = 'test@aura.local';
    _password.text = 'Passw0rd!';
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final redirect = widget.redirectTo ?? '/me';
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
                      SizedBox(height: AuraSpace.s6),
                      Text('User ID: ${store.userId ?? '-'}', style: AuraText.body),
                      SizedBox(height: AuraSpace.s12),
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
                SizedBox(height: AuraSpace.s16),
              ],
              AuraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome back', style: AuraText.title),
                    SizedBox(height: AuraSpace.s10),
                    Text(
                      'Login keeps the work accountable and protects writers from anonymous extraction.',
                      style: AuraText.body,
                    ),
                  ],
                ),
              ),
              SizedBox(height: AuraSpace.s14),
              if (_error != null) ...[
                AuraCard(
                  child: Text(_error!, style: AuraText.body.copyWith(color: Colors.red)),
                ),
                SizedBox(height: AuraSpace.s12),
              ],
              AuraCard(
                child: Column(
                  children: [
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: InputBorder.none,
                      ),
                    ),
                    Divider(height: AuraSpace.s16),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: InputBorder.none,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: AuraSpace.s18),
              FilledButton(
                onPressed: _busy ? null : _login,
                child: _busy
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Login'),
              ),
              SizedBox(height: AuraSpace.s10),
              TextButton(
                onPressed: _busy ? null : () => context.push('/register?redirect=${Uri.encodeComponent(redirect)}'),
                child: const Text('Create account'),
              ),
              SizedBox(height: AuraSpace.s6),
              TextButton(
                onPressed: _busy ? null : _fillTestAccount,
                child: const Text('Use test account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
