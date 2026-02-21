import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _busy = false;
  String? _msg;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _msg = null;
    });

    final dio = ref.read(dioProvider);

    try {
      await dio.post('/v1/auth/forgot-password', data: {'email': _email.text.trim()});
      setState(() => _msg = 'If the email exists, we sent a reset link/code. Check inbox/spam.');
    } on DioException catch (e) {
      setState(() => _msg = e.response?.data?.toString() ?? 'Failed to request reset.');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot password')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Enter your email and we will send a password reset link/token.'),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? 'Sending…' : 'Send reset'),
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
