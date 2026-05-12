import 'package:flutter/material.dart';

import '../../../ai_safety/presentation/ai_response_report_sheet.dart';
import '../../support_models.dart';

/// One row in the Aura Support AI conversation.
///
/// Assistant messages carry an overflow menu with a single action:
/// "Report response". The action opens the shared AI-response report
/// sheet so the operator can audit AI output, satisfying the Microsoft
/// Store §11.16 (Live Generative AI Content) requirement that every
/// AI surface offers a way to report inappropriate output. User-
/// authored messages and human "admin" replies don't get the menu —
/// only AI-generated text is reportable.
class SupportChatBubble extends StatelessWidget {
  const SupportChatBubble({
    super.key,
    required this.message,
    this.conversationId,
  });

  final SupportMessage message;
  final String? conversationId;

  bool get _isUser => message.role == 'user';
  bool get _isAiAssistant => message.role == 'assistant';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final bg = _isUser ? cs.primary : cs.surfaceContainerHighest;
    final fg = _isUser ? cs.onPrimary : cs.onSurface;
    final label = _isUser
        ? 'You'
        : (message.role == 'admin' ? 'Aura team' : 'Support AI');
    final labelColor = _isUser ? cs.primary : cs.outline;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment:
            _isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: labelColor),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment:
                _isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(12),
                        topRight: const Radius.circular(12),
                        bottomLeft: _isUser
                            ? const Radius.circular(12)
                            : const Radius.circular(2),
                        bottomRight: _isUser
                            ? const Radius.circular(2)
                            : const Radius.circular(12),
                      ),
                    ),
                    child: SelectableText(
                      message.content,
                      style: theme.textTheme.bodyMedium?.copyWith(color: fg),
                    ),
                  ),
                ),
              ),
              if (_isAiAssistant)
                _AiResponseOverflowMenu(
                  message: message,
                  conversationId: conversationId,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AiResponseOverflowMenu extends StatelessWidget {
  const _AiResponseOverflowMenu({
    required this.message,
    required this.conversationId,
  });

  final SupportMessage message;
  final String? conversationId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      tooltip: 'AI response options',
      icon: Icon(
        Icons.more_horiz_rounded,
        size: 18,
        color: cs.outline,
      ),
      // Subtle padding so the icon sits flush with the bubble's tail
      // edge instead of stealing layout space.
      padding: EdgeInsets.zero,
      itemBuilder: (_) => const [
        PopupMenuItem<String>(
          value: 'report',
          child: Row(
            children: [
              Icon(Icons.flag_outlined, size: 16),
              SizedBox(width: 10),
              Text('Report response'),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        if (value == 'report') {
          showAiResponseReportSheet(
            context,
            contentSnapshot: message.content,
            surface: 'support_agent',
            conversationId: conversationId,
            messageId: message.id.isNotEmpty ? message.id : null,
            metadata: <String, dynamic>{
              'role': message.role,
              'messageCreatedAt': message.createdAt.toIso8601String(),
            },
          );
        }
      },
    );
  }
}
