import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../data/messages_repository.dart';
import '../data/threads_repository.dart';

final _threadDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, threadId) async {
  final repo = ref.watch(threadsRepositoryProvider);
  return repo.getThread(threadId);
});

final _messagesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, threadId) async {
  final repo = ref.watch(messagesRepositoryProvider);
  return repo.listMessages(threadId: threadId);
});

class ThreadScreen extends ConsumerWidget {
  const ThreadScreen({super.key, required this.threadId});

  final String threadId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadAsync = ref.watch(_threadDetailProvider(threadId));
    final messagesAsync = ref.watch(_messagesProvider(threadId));

    return AuraScaffold(
      title: 'Thread',
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(_threadDetailProvider(threadId));
                ref.invalidate(_messagesProvider(threadId));
                await Future.wait([
                  ref.read(_threadDetailProvider(threadId).future),
                  ref.read(_messagesProvider(threadId).future),
                ]);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  threadAsync.when(
                    loading: () => const AuraCard(
                      child: _LoadingBlock(label: 'Loading thread...'),
                    ),
                    error: (error, _) => AuraCard(
                      child: _ErrorBlock(
                        title: 'Could not load thread',
                        body: '$error',
                        onRetry: () =>
                            ref.invalidate(_threadDetailProvider(threadId)),
                      ),
                    ),
                    data: (thread) => _ThreadHeaderCard(thread: thread),
                  ),
                  const SizedBox(height: AuraSpace.s14),
                  Text('Messages', style: AuraText.title),
                  const SizedBox(height: AuraSpace.s10),
                  messagesAsync.when(
                    loading: () => const AuraCard(
                      child: _LoadingBlock(label: 'Loading messages...'),
                    ),
                    error: (error, _) => AuraCard(
                      child: _ErrorBlock(
                        title: 'Could not load messages',
                        body: '$error',
                        onRetry: () =>
                            ref.invalidate(_messagesProvider(threadId)),
                      ),
                    ),
                    data: (messages) {
                      if (messages.isEmpty) {
                        return const AuraCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('No messages yet', style: AuraText.title),
                              SizedBox(height: AuraSpace.s8),
                              Text(
                                'Send the first message in this thread.',
                                style: AuraText.body,
                              ),
                            ],
                          ),
                        );
                      }

                      return Column(
                        children: [
                          for (var i = 0; i < messages.length; i++) ...[
                            _MessageTile(
                              message: messages[i],
                              onEdit: () => _showEditMessageDialog(
                                context,
                                ref,
                                messages[i],
                              ),
                              onDelete: () async {
                                final messageId = _pickString(
                                  messages[i],
                                  const ['id', 'messageId'],
                                );
                                if (messageId.isEmpty) return;
                                await ref
                                    .read(messagesRepositoryProvider)
                                    .deleteMessage(messageId);
                                ref.invalidate(_messagesProvider(threadId));
                              },
                            ),
                            if (i != messages.length - 1)
                              const SizedBox(height: AuraSpace.s10),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          _ComposerBar(
            onSend: (text) async {
              await ref.read(messagesRepositoryProvider).sendMessage(
                    threadId: threadId,
                    body: text,
                  );
              ref.invalidate(_messagesProvider(threadId));
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showEditMessageDialog(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> message,
  ) async {
    final edited = await showDialog<bool>(
      context: context,
      builder: (_) => _EditMessageDialog(message: message),
    );

    if (edited == true) {
      ref.invalidate(_messagesProvider(threadId));
    }
  }
}

class _ThreadHeaderCard extends StatelessWidget {
  const _ThreadHeaderCard({required this.thread});

  final Map<String, dynamic> thread;

  @override
  Widget build(BuildContext context) {
    final title = _pickString(thread, const ['title', 'name']);
    final kind = _pickString(thread, const ['kind', 'type']);
    final archived = thread['archived'] == true;

    return AuraCard(
      child: Wrap(
        spacing: AuraSpace.s8,
        runSpacing: AuraSpace.s8,
        children: [
          Text(
            title.isEmpty ? 'Untitled thread' : title,
            style: AuraText.title,
          ),
          if (kind.isNotEmpty) _Pill(label: kind),
          if (archived) _Pill(label: 'ARCHIVED'),
        ],
      ),
    );
  }
}

class _ComposerBar extends ConsumerStatefulWidget {
  const _ComposerBar({required this.onSend});

  final Future<void> Function(String text) onSend;

  @override
  ConsumerState<_ComposerBar> createState() => _ComposerBarState();
}

class _ComposerBarState extends ConsumerState<_ComposerBar> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);

    try {
      await widget.onSend(text);
      _controller.clear();
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.black12)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Write a message',
                ),
                onSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(width: AuraSpace.s10),
            FilledButton(
              onPressed: _sending ? null : _submit,
              child: Text(_sending ? 'Sending...' : 'Send'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditMessageDialog extends ConsumerStatefulWidget {
  const _EditMessageDialog({required this.message});

  final Map<String, dynamic> message;

  @override
  ConsumerState<_EditMessageDialog> createState() => _EditMessageDialogState();
}

class _EditMessageDialogState extends ConsumerState<_EditMessageDialog> {
  late final TextEditingController _controller;
  bool _saving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: _pickString(widget.message, const ['body', 'text', 'content']),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final messageId = _pickString(widget.message, const ['id', 'messageId']);
    final body = _controller.text.trim();

    if (messageId.isEmpty || body.isEmpty) {
      setState(() {
        _errorText = 'Message body cannot be empty.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _errorText = null;
    });

    try {
      await ref.read(messagesRepositoryProvider).editMessage(
            messageId: messageId,
            body: body,
          );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _errorText = '$e';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit message'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Message',
              ),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: AuraSpace.s12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _errorText!,
                  style: AuraText.small.copyWith(
                    color: Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(_saving ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({
    required this.message,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> message;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final body = _pickString(message, const ['body', 'text', 'content']);
    final author = _pickString(message, const ['authorName', 'senderName', 'userName']);
    final createdAt =
        _pickString(message, const ['createdAt', 'sentAt', 'timestamp']);

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (author.isNotEmpty) ...[
            Text(author, style: AuraText.small.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AuraSpace.s6),
          ],
          Text(
            body.isEmpty ? '(empty message)' : body,
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s10),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (createdAt.isNotEmpty) _MetaChip(label: 'Sent', value: createdAt),
              TextButton(
                onPressed: onEdit,
                child: const Text('Edit'),
              ),
              TextButton(
                onPressed: onDelete,
                child: const Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: AuraSpace.s10),
        Text(label, style: AuraText.body),
      ],
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({
    required this.title,
    required this.body,
    required this.onRetry,
  });

  final String title;
  final String body;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AuraText.title),
        const SizedBox(height: AuraSpace.s8),
        Text(body, style: AuraText.body),
        const SizedBox(height: AuraSpace.s12),
        OutlinedButton(
          onPressed: onRetry,
          child: const Text('Try again'),
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s10,
        vertical: AuraSpace.s6,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: AuraText.small.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s10,
        vertical: AuraSpace.s6,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AuraText.small.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

String _pickString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = (map[key] ?? '').toString().trim();
    if (value.isNotEmpty) return value;
  }
  return '';
}