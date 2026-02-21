import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, this.initialToken = ''});

  final String initialToken;

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  late final _token = TextEditingController(text: widget.initialToken);
  final _password = TextEditingController();

  bool _busy = false;
  String? _msg;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _msg = null;
    });

    final dio = ref.read(dioProvider);

    try {
      await dio.post('/v1/auth/reset-password', data: {
        'token': _token.text.trim(),
        'newPassword': _password.text,
      });
      setState(() => _msg = 'Password updated. You can log in now.');
    } on DioException catch (e) {
      setState(() => _msg = e.response?.data?.toString() ?? 'Reset failed.');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _token.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Paste your reset token/link token and set a new password.'),
            const SizedBox(height: 12),
            TextField(
              controller: _token,
              decoration: const InputDecoration(labelText: 'Reset token'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? 'Updating…' : 'Update password'),
            ),
            if (_msg != null) ...[
              const SizedBox(height: 14),
              Text(_msg!),
            ],
          ],
        ),
      ),
    );
  }
}
