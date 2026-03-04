// lib/screens/contact_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/ui/document_scaffold.dart';

/// Contact routing (topic -> inbox).
///
/// Override any of these at build time:
/// flutter build web --dart-define=AURA_EMAIL_SUPPORT=support@yourdomain.com ...
const String _emailGeneral = String.fromEnvironment(
  'AURA_EMAIL_GENERAL',
  defaultValue: 'contact@auraplatform.org',
);

const String _emailSupport = String.fromEnvironment(
  'AURA_EMAIL_SUPPORT',
  defaultValue: 'support@auraplatform.org',
);

const String _emailInstitutions = String.fromEnvironment(
  'AURA_EMAIL_INSTITUTIONS',
  defaultValue: 'institutions@auraplatform.org',
);

const String _emailInvestors = String.fromEnvironment(
  'AURA_EMAIL_INVESTORS',
  defaultValue: 'investors@auraplatform.org',
);

const String _emailPrivacy = String.fromEnvironment(
  'AURA_EMAIL_PRIVACY',
  defaultValue: 'privacy@auraplatform.org',
);

enum ContactTopic {
  support,
  bug,
  institutions,
  investors,
  privacy,
  other,
}

String _topicLabel(ContactTopic t) {
  switch (t) {
    case ContactTopic.support:
      return 'Support';
    case ContactTopic.bug:
      return 'Bug report';
    case ContactTopic.institutions:
      return 'Institutions';
    case ContactTopic.investors:
      return 'Investors';
    case ContactTopic.privacy:
      return 'Privacy request';
    case ContactTopic.other:
      return 'Other';
  }
}

String _topicEmail(ContactTopic t) {
  switch (t) {
    case ContactTopic.support:
      return _emailSupport;
    case ContactTopic.bug:
      return _emailSupport; // bugs go to support by default
    case ContactTopic.institutions:
      return _emailInstitutions;
    case ContactTopic.investors:
      return _emailInvestors;
    case ContactTopic.privacy:
      return _emailPrivacy;
    case ContactTopic.other:
      return _emailGeneral;
  }
}

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DocumentScaffold(
      title: 'Contact',
      child: _ContactBody(),
    );
  }
}

class _ContactBody extends StatefulWidget {
  const _ContactBody();

  @override
  State<_ContactBody> createState() => _ContactBodyState();
}

class _ContactBodyState extends State<_ContactBody> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  ContactTopic _topic = ContactTopic.support;
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(BuildContext context) async {
    if (_submitting) return;

    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final msg = _messageCtrl.text.trim();

    if (email.isEmpty || msg.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email and message are required.')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      // Routing stays internal. Nothing is shown on the UI.
      final to = _topicEmail(_topic);

      final subject = 'Aura contact: ${_topicLabel(_topic)}';

      final body = [
        'Topic: ${_topicLabel(_topic)}',
        'Name: ${name.isEmpty ? '—' : name}',
        'Email: $email',
        '',
        msg,
      ].join('\n');

      // Dependency-free for now: copy a ready-to-send email payload to clipboard.
      // The page never displays addresses; this only prepares the message.
      final payload = 'To: $to\nSubject: $subject\n\n$body';
      await Clipboard.setData(ClipboardData(text: payload));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copied. Paste into your email and send.'),
          duration: Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Doc.title('Contact'),
        const SizedBox(height: 10),

        Doc.meta('Support, institutions, investors, privacy requests.'),
        const SizedBox(height: 8),

        Doc.p(
          'Send a message and we will route it to the right place.',
        ),

        const SizedBox(height: 14),

        Doc.p(
          'We will never ask for your password. Avoid sharing sensitive personal data in the message body.',
        ),

        const SizedBox(height: 12),

        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Name (optional)',
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),

        TextField(
          controller: _emailCtrl,
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),

        DropdownButtonFormField<ContactTopic>(
          value: _topic,
          decoration: const InputDecoration(
            labelText: 'Topic',
            border: OutlineInputBorder(),
          ),
          items: ContactTopic.values
              .map(
                (t) => DropdownMenuItem(
                  value: t,
                  child: Text(_topicLabel(t)),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _topic = v ?? _topic),
        ),
        const SizedBox(height: 12),

        TextField(
          controller: _messageCtrl,
          decoration: const InputDecoration(
            labelText: 'Message',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          maxLines: 8,
        ),

        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _submitting ? null : () => _submit(context),
            child: Text(_submitting ? 'Preparing…' : 'Copy message'),
          ),
        ),
      ],
    );
  }
}