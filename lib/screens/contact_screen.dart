// lib/screens/contact_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/net/dio_provider.dart';
import '../core/ui/document_scaffold.dart';

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

String _topicValue(ContactTopic t) {
  switch (t) {
    case ContactTopic.support:
      return 'support';
    case ContactTopic.bug:
      return 'bug';
    case ContactTopic.institutions:
      return 'institutions';
    case ContactTopic.investors:
      return 'investors';
    case ContactTopic.privacy:
      return 'privacy';
    case ContactTopic.other:
      return 'other';
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

class _ContactBody extends ConsumerStatefulWidget {
  const _ContactBody();

  @override
  ConsumerState<_ContactBody> createState() => _ContactBodyState();
}

class _ContactBodyState extends ConsumerState<_ContactBody> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  ContactTopic _topic = ContactTopic.support;
  bool _submitting = false;
  bool _sent = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
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
      final dio = ref.read(dioProvider);

      await dio.post(
        '/v1/contact',
        data: {
          'topic': _topicValue(_topic),
          'name': name.isEmpty ? null : name,
          'email': email,
          'message': msg,
        },
      );

      if (!mounted) return;

      setState(() {
        _sent = true;
        _submitting = false;
      });

      _messageCtrl.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sent. Thank you.'),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not send. Please try again.'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Doc.title('Contact'),
        const SizedBox(height: 10),

        Doc.p('Send a message. We will route it to the right place.'),
        const SizedBox(height: 10),

        Doc.p('We will never ask for your password. Avoid sharing sensitive personal data in the message body.'),
        const SizedBox(height: 14),

        if (_sent) ...[
          Doc.callout('Message received. If a reply is needed, you will hear back by email.'),
          const SizedBox(height: 14),
        ],

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
            onPressed: _submitting ? null : _submit,
            child: Text(_submitting ? 'Sending…' : 'Send'),
          ),
        ),
      ],
    );
  }
}