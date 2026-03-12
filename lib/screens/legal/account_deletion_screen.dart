import 'package:flutter/material.dart';

class AccountDeletionScreen extends StatelessWidget {
  const AccountDeletionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Deletion'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: const [
              Text(
                'Aura Account Deletion',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'If you would like to delete your Aura account and associated personal data, please email us at support@auraplatform.org with the subject line "Account Deletion Request".',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              SizedBox(height: 20),
              Text(
                'Please include the following information in your request:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 10),
              Text('• Full name', style: TextStyle(fontSize: 16, height: 1.5)),
              Text(
                '• Email address linked to your Aura account',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              Text(
                '• A short statement confirming that you want your account deleted',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              SizedBox(height: 20),
              Text(
                'Once we verify your request, we will begin the deletion process for your account and associated personal data.',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              SizedBox(height: 20),
              Text(
                'Some limited information may be retained where required for legal compliance, fraud prevention, security, or enforcement of platform integrity and safety obligations.',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              SizedBox(height: 20),
              Text(
                'Deletion requests are processed within a reasonable period after verification.',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}