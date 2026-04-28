import 'package:flutter/material.dart';

import '../../support_models.dart';

class SupportChatBubble extends StatelessWidget {
  const SupportChatBubble({super.key, required this.message});

  final SupportMessage message;

  bool get _isUser => message.role == 'user';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final bg = _isUser ? cs.primary : cs.surfaceContainerHighest;
    final fg = _isUser ? cs.onPrimary : cs.onSurface;
    final label = _isUser ? 'You' : (message.role == 'admin' ? 'Aura team' : 'Support AI');
    final labelColor = _isUser ? cs.primary : cs.outline;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: _isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: labelColor),
          ),
          const SizedBox(height: 2),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: _isUser ? const Radius.circular(12) : const Radius.circular(2),
                  bottomRight: _isUser ? const Radius.circular(2) : const Radius.circular(12),
                ),
              ),
              child: SelectableText(
                message.content,
                style: theme.textTheme.bodyMedium?.copyWith(color: fg),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
