// Redirect to the AI support agent. POST /contact is preserved as a backend shim.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Redirect on first frame so the route can complete cleanly.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) context.go('/support/agent');
    });
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
