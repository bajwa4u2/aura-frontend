import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class VerifyPendingScreen extends StatelessWidget {
  const VerifyPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify your email'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'One more step',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text(
              'We sent a verification link to your email. Please verify to continue.',
            ),
            const SizedBox(height: 16),
            const Text(
              'If you did not receive it, you can resend from the verification screen.',
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton(
                  onPressed: () => context.go('/verify-email'),
                  child: const Text('Open verification'),
                ),
                OutlinedButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('Go to home'),
                ),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Back to login'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}