import 'package:flutter/material.dart';

import '../core/ui/document_scaffold.dart';

class AccountDeletionScreen extends StatelessWidget {
  const AccountDeletionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DocumentScaffold(
      title: 'Account Deletion',
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Delete your Aura account',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'To delete your Aura account and associated personal data, email support@auraplatform.org with the subject line "Account Deletion Request".',
            style: TextStyle(fontSize: 16, height: 1.6),
          ),
          SizedBox(height: 20),
          Text(
            'Include the following information:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 10),
          Text('• Full name', style: TextStyle(fontSize: 16, height: 1.6)),
          Text(
            '• Email address linked to your Aura account',
            style: TextStyle(fontSize: 16, height: 1.6),
          ),
          Text(
            '• A short statement confirming the deletion request',
            style: TextStyle(fontSize: 16, height: 1.6),
          ),
          SizedBox(height: 20),
          Text(
            'After verification, Aura begins the deletion process for the account and associated personal data.',
            style: TextStyle(fontSize: 16, height: 1.6),
          ),
          SizedBox(height: 20),
          Text(
            'Some limited information may be retained where required for legal compliance, fraud prevention, security, or platform integrity obligations.',
            style: TextStyle(fontSize: 16, height: 1.6),
          ),
          SizedBox(height: 20),
          Text(
            'Deletion requests are processed within a reasonable period after verification.',
            style: TextStyle(fontSize: 16, height: 1.6),
          ),
        ],
      ),
    );
  }
}
