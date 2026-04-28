import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/document_scaffold.dart';
import '../providers.dart';
import 'widgets/support_chat_bubble.dart';
import 'widgets/support_quick_chips.dart';

class SupportAgentScreen extends ConsumerStatefulWidget {
  const SupportAgentScreen({super.key});

  @override
  ConsumerState<SupportAgentScreen> createState() => _SupportAgentScreenState();
}

class _SupportAgentScreenState extends ConsumerState<SupportAgentScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  bool _showEscalateForm = false;
  bool _escalated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(supportConversationProvider.notifier).start();
    });
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();
    await ref.read(supportConversationProvider.notifier).send(text);
    _scrollToBottom();
  }

  Future<void> _escalate() async {
    final email = _emailCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final result = await ref.read(supportConversationProvider.notifier).escalate(
          requesterEmail: email.isNotEmpty ? email : null,
          requesterName: name.isNotEmpty ? name : null,
        );
    if (result != null && mounted) {
      setState(() {
        _escalated = true;
        _showEscalateForm = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(supportConversationProvider);
    final theme = Theme.of(context);

    if (state.messages.isNotEmpty) _scrollToBottom();

    return DocumentScaffold(
      title: 'Support',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.support_agent, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text('Aura support agent', style: theme.textTheme.titleMedium),
              const Spacer(),
              if (state.caseRef != null)
                Chip(
                  label: Text(state.caseRef!, style: theme.textTheme.labelSmall),
                  avatar: const Icon(Icons.label_outline, size: 14),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (state.error != null)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Something went wrong. Please try again.',
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ),

          // Chat area
          Expanded(
            child: state.loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: state.messages.length,
                    itemBuilder: (_, i) => SupportChatBubble(message: state.messages[i]),
                  ),
          ),

          const Divider(height: 1),

          // Quick chips (only before user has typed)
          if (state.messages.where((m) => m.role == 'user').isEmpty && !state.loading) ...[
            const SizedBox(height: 10),
            SupportQuickChips(
              enabled: !state.sending,
              onSelected: (t) {
                _msgCtrl.text = t;
                _send();
              },
            ),
            const SizedBox(height: 8),
          ],

          // Escalate success banner
          if (_escalated && state.caseRef != null)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.green.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Case ${state.caseRef} submitted. Check your email for confirmation.',
                      style: TextStyle(color: Colors.green.shade800, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          // Escalate form
          if (_showEscalateForm && !_escalated)
            _EscalateForm(
              emailCtrl: _emailCtrl,
              nameCtrl: _nameCtrl,
              onSubmit: _escalate,
              onCancel: () => setState(() => _showEscalateForm = false),
            ),

          // Input row
          if (!_escalated)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Describe your issue…',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      minLines: 1,
                      maxLines: 4,
                      enabled: !state.sending && !state.loading,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: state.sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send),
                    onPressed: state.sending || state.loading ? null : _send,
                    tooltip: 'Send',
                  ),
                ],
              ),
            ),

          // Escalate to human CTA
          if (!_escalated && !_showEscalateForm && state.messages.where((m) => m.role == 'user').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton.icon(
                icon: const Icon(Icons.person_outline, size: 16),
                label: const Text('Talk to the Aura team'),
                onPressed: () => setState(() => _showEscalateForm = true),
              ),
            ),
        ],
      ),
    );
  }
}

class _EscalateForm extends StatelessWidget {
  const _EscalateForm({
    required this.emailCtrl,
    required this.nameCtrl,
    required this.onSubmit,
    required this.onCancel,
  });

  final TextEditingController emailCtrl;
  final TextEditingController nameCtrl;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Submit to Aura team',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Optionally add your contact details so we can follow up by email.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Name (optional)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: emailCtrl,
            decoration: const InputDecoration(
              labelText: 'Email (optional)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              FilledButton(
                onPressed: onSubmit,
                child: const Text('Submit case'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onCancel,
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
