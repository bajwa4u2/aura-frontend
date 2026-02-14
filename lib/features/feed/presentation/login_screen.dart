import 'package:flutter/material.dart';

import '../../auth/presentation/auth_screen.dart';

class LoginScreen extends StatelessWidget {
  // Kept only for backward compatibility with older callers.
  final VoidCallback? onDone;
  const LoginScreen({super.key, this.onDone});

  @override
  Widget build(BuildContext context) {
    return const AuthScreen();
  }
}
