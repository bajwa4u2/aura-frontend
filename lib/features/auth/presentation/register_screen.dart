import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, this.redirectTo});

  final String? redirectTo;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _handle = TextEditingController();
  final _displayName = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _handle.dispose();
    _displayName.dispose();
    super.dispose();
  }

  String _safeRedirect(String? r) {
    final v = (r ?? '').trim();
    if (v.isEmpty) return '/me';
    if (!v.startsWith('/')) return '/me';
    return v;
  }

  bool _validHandle(String h) {
    final v = h.trim();
    if (v.length < 3 || v.length > 24) return false;
    return RegExp(r'^[a-z0-9_]+$').hasMatch(v);
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

  Future<void> _register() async {
    if (_busy) return;

    final email = _email.text.trim();
    final password = _password.text;
    final handle = _handle.text.trim();
    final displayName = _displayName.text.trim();

    if (email.isEmpty || password.isEmpty || handle.isEmpty) {
      setState(() => _error = 'Email, password, and handle are required.');
      return;
    }

    if (!_validHandle(handle)) {
      setState(() => _error = 'Handle must be 3–24 chars, lowercase letters/numbers/underscores only.');
      return;
    }

    if (password.length < 8 || password.length > 72) {
      setState(() => _error = 'Password must be 8–72 characters.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);

      final payload = <String, dynamic>{
        'email': email,
        'password': password,
        'handle': handle,
        if (displayName.isNotEmpty) 'displayName': displayName,
      };

      // Backend contract:
      // - Web: refresh token is httpOnly cookie; body usually { user, accessToken }
      // - Non-web: request body transport to also receive refreshToken in body
      final options = !kIsWeb ? Options(headers: {'x-token-transport': 'body'}) : null;

      final res = await dio.post('/auth/register', data: payload, options: options);

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
        _error = extra.isEmpty
            ? 'Register failed (${status ?? 'no status'}).'
            : 'Register failed (${status ?? 'no status'}). $extra';
      });
    } catch (e) {
      setState(() => _error = 'Register failed. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuraScaffold(
      title: 'Create account',
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
              AuraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Join Aura', style: AuraText.title),
                    SizedBox(height: AuraSpace.s10),
                    Text(
                      'A calm place to read and publish with responsibility.',
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
                      controller: _displayName,
                      inputFormatters: [LengthLimitingTextInputFormatter(40)],
                      decoration: const InputDecoration(
                        labelText: 'Display name (optional)',
                        border: InputBorder.none,
                      ),
                    ),
                    Divider(height: AuraSpace.s16),
                    TextField(
                      controller: _handle,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_]')),
                        _LowercaseTextFormatter(),
                        LengthLimitingTextInputFormatter(24),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Handle (lowercase, a-z 0-9 _)',
                        hintText: 'e.g. bajwa4u2',
                        border: InputBorder.none,
                      ),
                    ),
                    Divider(height: AuraSpace.s16),
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
                        labelText: 'Password (8–72 chars)',
                        border: InputBorder.none,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: AuraSpace.s18),
              FilledButton(
                onPressed: _busy ? null : _register,
                child: _busy
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Create account'),
              ),
              SizedBox(height: AuraSpace.s10),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => context.go(
                          '/login?redirect=${Uri.encodeComponent(_safeRedirect(widget.redirectTo))}',
                        ),
                child: const Text('Already have an account? Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LowercaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final lower = newValue.text.toLowerCase();
    if (lower == newValue.text) return newValue;
    return newValue.copyWith(
      text: lower,
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}
