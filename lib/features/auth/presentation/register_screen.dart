import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _city = TextEditingController();
  final _country = TextEditingController();

  final _displayName = TextEditingController();
  final _handle = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _city.dispose();
    _country.dispose();
    _displayName.dispose();
    _handle.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
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

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _register() async {
    if (_busy) return;

    final firstName = _firstName.text.trim();
    final lastName = _lastName.text.trim();
    final city = _city.text.trim();
    final country = _country.text.trim();

    final displayName = _displayName.text.trim();
    final handle = _handle.text.trim();
    final email = _email.text.trim();
    final password = _password.text;

    if (firstName.isEmpty || lastName.isEmpty) {
      setState(() => _error = 'First name and last name are required.');
      return;
    }

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
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'password': password,
        'handle': handle,
        if (displayName.isNotEmpty) 'displayName': displayName,
        if (city.isNotEmpty) 'city': city,
        if (country.isNotEmpty) 'country': country,
      };

      final options = !kIsWeb ? Options(headers: {'x-token-transport': 'body'}) : null;

      await dio.post('/v1/auth/register', data: payload, options: options);

      if (!mounted) return;

      _snack('Verification email has been sent. Please verify to continue.');
      context.go('/login');
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
                    Text('Create your account. We’ll email you a verification link.', style: AuraText.body),
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
                      controller: _firstName,
                      inputFormatters: [LengthLimitingTextInputFormatter(40)],
                      decoration: const InputDecoration(
                        labelText: 'First name (private)',
                        border: InputBorder.none,
                      ),
                    ),
                    Divider(height: AuraSpace.s16),
                    TextField(
                      controller: _lastName,
                      inputFormatters: [LengthLimitingTextInputFormatter(40)],
                      decoration: const InputDecoration(
                        labelText: 'Last name (private)',
                        border: InputBorder.none,
                      ),
                    ),
                    Divider(height: AuraSpace.s16),
                    TextField(
                      controller: _displayName,
                      inputFormatters: [LengthLimitingTextInputFormatter(40)],
                      decoration: const InputDecoration(
                        labelText: 'Display name (public, optional)',
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
                        labelText: 'Handle (public)',
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
                        labelText: 'Password',
                        border: InputBorder.none,
                      ),
                    ),
                    Divider(height: AuraSpace.s16),
                    TextField(
                      controller: _city,
                      inputFormatters: [LengthLimitingTextInputFormatter(60)],
                      decoration: const InputDecoration(
                        labelText: 'City (optional, private)',
                        border: InputBorder.none,
                      ),
                    ),
                    Divider(height: AuraSpace.s16),
                    TextField(
                      controller: _country,
                      inputFormatters: [LengthLimitingTextInputFormatter(60)],
                      decoration: const InputDecoration(
                        labelText: 'Country (optional, private)',
                        border: InputBorder.none,
                      ),
                    ),
                    SizedBox(height: AuraSpace.s14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _busy ? null : _register,
                        child: Text(_busy ? 'Creating…' : 'Create account'),
                      ),
                    ),
                    SizedBox(height: AuraSpace.s10),
                    TextButton(
                      onPressed: _busy ? null : () => context.go('/login'),
                      child: const Text('Already have an account? Login'),
                    ),
                  ],
                ),
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
    return newValue.copyWith(
      text: lower,
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}
