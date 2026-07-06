import 'package:flutter/material.dart';

import '../../domain/meeting_conversation_message.dart';

/// Phase 4 — Meeting Conversation Stream panel (live room, right side).
///
/// Meeting-scoped conversation, NOT generic chat: messages can be typed as
/// decisions / commitments / actions / issues / follow-ups at capture time so
/// the stream feeds meeting continuity (outcomes, summary) later. The panel is
/// presentational — the live room owns the message list, socket wiring, and
/// unread accounting so the badge works while this panel is closed.
class MeetingConversationPanel extends StatefulWidget {
  final List<MeetingConversationMessage> messages;
  final String localUserId;
  final bool isHost;
  final bool chatEnabled;
  final VoidCallback onClose;
  final Future<bool> Function(String body, MeetingMessageType type) onSend;
  final void Function(String messageId)? onDelete;

  /// Phase 4.5 — host-only: lift a message into a MeetingOutcome. The live
  /// room owns the REST call and the local promoted-state update.
  final Future<bool> Function(String messageId, MeetingMessageType type)?
      onPromote;

  const MeetingConversationPanel({
    super.key,
    required this.messages,
    required this.localUserId,
    required this.isHost,
    required this.chatEnabled,
    required this.onClose,
    required this.onSend,
    this.onDelete,
    this.onPromote,
  });

  @override
  State<MeetingConversationPanel> createState() =>
      _MeetingConversationPanelState();
}

class _MeetingConversationPanelState extends State<MeetingConversationPanel> {
  final _ctrl = TextEditingController();
  MeetingMessageType _type = MeetingMessageType.chat;
  bool _sending = false;
  final Set<String> _promoting = {};

  Future<void> _promote(String messageId, MeetingMessageType type) async {
    if (widget.onPromote == null || _promoting.contains(messageId)) return;
    setState(() => _promoting.add(messageId));
    await widget.onPromote!(messageId, type);
    if (mounted) setState(() => _promoting.remove(messageId));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _ctrl.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    final ok = await widget.onSend(body, _type);
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      _ctrl.clear();
      // A typed marker is usually a one-off; drop back to plain chat.
      if (_type != MeetingMessageType.chat) {
        setState(() => _type = MeetingMessageType.chat);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      color: const Color(0xFF0F172A),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 48, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Conversation',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF9CA3AF)),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF1E293B), height: 1),
          Expanded(
            child: widget.messages.isEmpty
                ? const Center(
                    child: Text(
                      'No messages yet.\nDecisions and commitments you tag\nhere feed the meeting summary.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF4B5563), fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    itemCount: widget.messages.length,
                    itemBuilder: (context, i) {
                      final msg =
                          widget.messages[widget.messages.length - 1 - i];
                      return _ConversationTile(
                        message: msg,
                        isOwn: msg.senderId == widget.localUserId,
                        promoting: _promoting.contains(msg.id),
                        onDelete: widget.isHost && widget.onDelete != null
                            ? () => widget.onDelete!(msg.id)
                            : null,
                        onPromote: widget.isHost &&
                                widget.onPromote != null &&
                                !msg.isPromoted
                            ? (type) => _promote(msg.id, type)
                            : null,
                      );
                    },
                  ),
          ),
          const Divider(color: Color(0xFF1E293B), height: 1),
          if (!widget.chatEnabled)
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Chat is disabled for this meeting.',
                style: TextStyle(color: Color(0xFF4B5563), fontSize: 12),
              ),
            )
          else
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_type != MeetingMessageType.chat)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _TypeChip(
                          type: _type,
                          onClear: () => setState(
                            () => _type = MeetingMessageType.chat,
                          ),
                        ),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Continuity tag picker: mark a message as a
                        // decision / commitment / action / issue / follow-up.
                        PopupMenuButton<MeetingMessageType>(
                          tooltip: 'Tag message',
                          color: const Color(0xFF1E293B),
                          icon: Icon(
                            Icons.label_outline_rounded,
                            size: 20,
                            color: _type == MeetingMessageType.chat
                                ? const Color(0xFF9CA3AF)
                                : _typeColor(_type),
                          ),
                          onSelected: (t) => setState(() => _type = t),
                          itemBuilder: (context) => [
                            for (final t in const [
                              MeetingMessageType.chat,
                              MeetingMessageType.decision,
                              MeetingMessageType.commitment,
                              MeetingMessageType.action,
                              MeetingMessageType.issue,
                              MeetingMessageType.followUp,
                            ])
                              PopupMenuItem(
                                value: t,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: t == MeetingMessageType.chat
                                            ? const Color(0xFF9CA3AF)
                                            : _typeColor(t),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      t.label,
                                      style: const TextStyle(
                                        color: Color(0xFFE5E7EB),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        Expanded(
                          child: TextField(
                            controller: _ctrl,
                            minLines: 1,
                            maxLines: 4,
                            maxLength: 2000,
                            textCapitalization: TextCapitalization.sentences,
                            style: const TextStyle(
                              color: Color(0xFFE5E7EB),
                              fontSize: 13,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Message the meeting…',
                              hintStyle: TextStyle(color: Color(0xFF4B5563)),
                              border: InputBorder.none,
                              counterText: '',
                              isDense: true,
                            ),
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                        IconButton(
                          onPressed: _sending ? null : _send,
                          icon: _sending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF6C63FF),
                                  ),
                                )
                              : const Icon(
                                  Icons.send_rounded,
                                  size: 20,
                                  color: Color(0xFF6C63FF),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Color _typeColor(MeetingMessageType type) {
  switch (type) {
    case MeetingMessageType.decision:
      return const Color(0xFF10B981);
    case MeetingMessageType.commitment:
      return const Color(0xFFF59E0B);
    case MeetingMessageType.action:
      return const Color(0xFF38BDF8);
    case MeetingMessageType.issue:
      return const Color(0xFFF43F5E);
    case MeetingMessageType.followUp:
      return const Color(0xFF8B5CF6);
    case MeetingMessageType.chat:
    case MeetingMessageType.system:
      return const Color(0xFF9CA3AF);
  }
}

class _TypeChip extends StatelessWidget {
  final MeetingMessageType type;
  final VoidCallback? onClear;

  const _TypeChip({required this.type, this.onClear});

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            type.label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (onClear != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onClear,
              child: Icon(Icons.close, size: 12, color: color),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final MeetingConversationMessage message;
  final bool isOwn;
  final bool promoting;
  final VoidCallback? onDelete;
  final void Function(MeetingMessageType type)? onPromote;

  const _ConversationTile({
    required this.message,
    required this.isOwn,
    this.promoting = false,
    this.onDelete,
    this.onPromote,
  });

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay.fromDateTime(message.createdAt).format(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  message.senderName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isOwn
                        ? const Color(0xFF6C63FF)
                        : const Color(0xFFE5E7EB),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (message.isGuest) ...[
                const SizedBox(width: 5),
                const Text(
                  'Guest',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 10),
                ),
              ],
              const SizedBox(width: 8),
              Text(
                time,
                style: const TextStyle(color: Color(0xFF4B5563), fontSize: 10),
              ),
              const Spacer(),
              if (message.isPromoted)
                Tooltip(
                  message: 'Promoted to a meeting outcome',
                  child: Icon(
                    Icons.task_alt_rounded,
                    size: 14,
                    // Typed messages keep their type colour; a promoted plain
                    // chat message gets the outcome emerald, not neutral grey.
                    color: message.messageType == MeetingMessageType.chat
                        ? const Color(0xFF10B981)
                        : _typeColor(message.messageType),
                  ),
                )
              else if (promoting)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Color(0xFF6C63FF),
                  ),
                )
              else if (onPromote != null)
                // Host-only: promote this message into a meeting outcome.
                PopupMenuButton<MeetingMessageType>(
                  tooltip: 'Promote to outcome',
                  color: const Color(0xFF1E293B),
                  padding: EdgeInsets.zero,
                  iconSize: 14,
                  icon: const Icon(
                    Icons.arrow_circle_up_rounded,
                    size: 14,
                    color: Color(0xFF6C63FF),
                  ),
                  onSelected: (t) => onPromote!(t),
                  itemBuilder: (context) => [
                    for (final t in const [
                      MeetingMessageType.decision,
                      MeetingMessageType.commitment,
                      MeetingMessageType.action,
                      MeetingMessageType.issue,
                      MeetingMessageType.followUp,
                    ])
                      PopupMenuItem(
                        value: t,
                        height: 36,
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _typeColor(t),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Promote to ${t.label}',
                              style: TextStyle(
                                color: t == message.messageType
                                    ? _typeColor(t)
                                    : const Color(0xFFE5E7EB),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              if (onDelete != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onDelete,
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    size: 14,
                    color: Color(0xFF4B5563),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          if (message.messageType != MeetingMessageType.chat)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: _TypeChip(type: message.messageType),
            ),
          Text(
            message.body,
            style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
          ),
        ],
      ),
    );
  }
}
