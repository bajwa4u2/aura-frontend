import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
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
      if (mounted) ref.read(supportConversationProvider.notifier).start();
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
      if (_scrollCtrl.hasClients &&
          _scrollCtrl.position.hasContentDimensions) {
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

  Future<void> _restart() async {
    ref.read(supportConversationProvider.notifier).reset();
    await ref.read(supportConversationProvider.notifier).start();
  }

  Future<void> _escalate() async {
    final email = _emailCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final result = await ref
        .read(supportConversationProvider.notifier)
        .escalate(
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

    if (state.messages.isNotEmpty) _scrollToBottom();

    return AuraScaffold(
      title: 'Support',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ─────────────────────────────────────────────────────────
          _SupportPageHeader(caseRef: state.caseRef),

          // ── Error banner (non-fatal — conversation already started) ────────
          if (state.error != null && state.messages.isNotEmpty)
            const _ErrorBanner(
              message: 'Something went wrong. Your conversation is preserved.',
            ),

          // ── Main content area ──────────────────────────────────────────────
          Expanded(
            child: _buildContent(state),
          ),

          // ── Escalate-success banner ────────────────────────────────────────
          if (_escalated && state.caseRef != null)
            _EscalateSuccessBanner(caseRef: state.caseRef!),

          // ── Escalate form ─────────────────────────────────────────────────
          if (_showEscalateForm && !_escalated)
            _EscalateForm(
              emailCtrl: _emailCtrl,
              nameCtrl: _nameCtrl,
              onSubmit: _escalate,
              onCancel: () => setState(() => _showEscalateForm = false),
            ),

          // ── Composer ──────────────────────────────────────────────────────
          if (!_escalated) ...[
            const Divider(color: AuraSurface.divider, height: 1),
            _ComposerBar(
              ctrl: _msgCtrl,
              sending: state.sending,
              disabled: state.loading,
              onSend: _send,
              onEscalate: (state.messages.any((m) => m.role == 'user') &&
                      !_showEscalateForm)
                  ? () => setState(() => _showEscalateForm = true)
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent(SupportConversationState state) {
    // Loading — initial session start
    if (state.loading) {
      return const _LoadingState();
    }

    // Fatal error — failed to start and no messages
    if (state.error != null && state.messages.isEmpty) {
      return _ErrorState(
        error: state.error!,
        onRetry: _restart,
      );
    }

    // Empty — conversation started but no messages yet
    if (state.messages.isEmpty) {
      return _EmptyStartState(
        sending: state.sending,
        onChipSelected: (t) {
          _msgCtrl.text = t;
          _send();
        },
      );
    }

    // Chat messages
    return _ChatArea(
      messages: state.messages,
      scrollCtrl: _scrollCtrl,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _SupportPageHeader extends StatelessWidget {
  const _SupportPageHeader({this.caseRef});

  final String? caseRef;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AuraSpace.s20, AuraSpace.s16, AuraSpace.s20, AuraSpace.s14),
      decoration: const BoxDecoration(
        color: AuraSurface.subtle,
        border:
            Border(bottom: BorderSide(color: AuraSurface.divider)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AuraSurface.accentSoft,
              borderRadius: BorderRadius.circular(AuraRadius.pill),
              border: Border.all(
                color: AuraSurface.accent.withValues(alpha: 0.35),
              ),
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              size: 18,
              color: AuraSurface.accentText,
            ),
          ),
          const SizedBox(width: AuraSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Aura Support', style: AuraText.subtitle),
                Text(
                  'Powered by AI · Responses may take a moment',
                  style:
                      AuraText.micro.copyWith(color: AuraSurface.muted),
                ),
              ],
            ),
          ),
          if (caseRef != null)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpace.s10, vertical: AuraSpace.s4),
              decoration: BoxDecoration(
                color: AuraSurface.accentSoft,
                borderRadius: BorderRadius.circular(AuraRadius.pill),
                border: Border.all(
                    color: AuraSurface.accent.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.label_outline_rounded,
                      size: 13, color: AuraSurface.accentText),
                  const SizedBox(width: AuraSpace.s4),
                  Text(
                    caseRef!,
                    style: AuraText.micro.copyWith(
                      color: AuraSurface.accentText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONTENT STATES
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AuraSurface.accentText,
            ),
          ),
          SizedBox(height: AuraSpace.s12),
          Text(
            'Starting your support session…',
            style: AuraText.body,
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AuraSurface.dangerBg,
                borderRadius: BorderRadius.circular(AuraRadius.pill),
                border: Border.all(
                    color: AuraSurface.dangerInk.withValues(alpha: 0.3)),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 22,
                color: AuraSurface.dangerInk,
              ),
            ),
            const SizedBox(height: AuraSpace.s16),
            const Text('Could not connect to support', style: AuraText.subtitle),
            const SizedBox(height: AuraSpace.s8),
            Text(
              'The support service is temporarily unavailable.\nYour conversation will start automatically when it\'s back.',
              style: AuraText.body.copyWith(color: AuraSurface.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AuraSpace.s20),
            _AuraFilledButton(
              label: 'Try again',
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyStartState extends StatelessWidget {
  const _EmptyStartState({
    required this.sending,
    required this.onChipSelected,
  });

  final bool sending;
  final void Function(String) onChipSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AuraSpace.s20, AuraSpace.s24, AuraSpace.s20, AuraSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('How can we help?', style: AuraText.title),
          const SizedBox(height: AuraSpace.s8),
          Text(
            'Describe your issue or pick a topic below to get started. '
            'Our AI support agent will respond right away.',
            style: AuraText.body.copyWith(color: AuraSurface.muted),
          ),
          const SizedBox(height: AuraSpace.s20),
          Text(
            'COMMON TOPICS',
            style: AuraText.micro.copyWith(
              color: AuraSurface.muted,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AuraSpace.s10),
          SupportQuickChips(
            enabled: !sending,
            onSelected: onChipSelected,
          ),
        ],
      ),
    );
  }
}

class _ChatArea extends StatelessWidget {
  const _ChatArea({
    required this.messages,
    required this.scrollCtrl,
  });

  final List<dynamic> messages;
  final ScrollController scrollCtrl;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(
          AuraSpace.s20, AuraSpace.s12, AuraSpace.s20, AuraSpace.s12),
      itemCount: messages.length,
      itemBuilder: (_, i) => SupportChatBubble(message: messages[i]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BANNERS
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AuraSpace.s16, AuraSpace.s10, AuraSpace.s16, 0),
      padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s14, vertical: AuraSpace.s10),
      decoration: BoxDecoration(
        color: AuraSurface.dangerBg,
        borderRadius: BorderRadius.circular(AuraRadius.md),
        border:
            Border.all(color: AuraSurface.dangerInk.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 16, color: AuraSurface.dangerInk),
          const SizedBox(width: AuraSpace.s8),
          Expanded(
            child: Text(
              message,
              style: AuraText.small.copyWith(color: AuraSurface.dangerInk),
            ),
          ),
        ],
      ),
    );
  }
}

class _EscalateSuccessBanner extends StatelessWidget {
  const _EscalateSuccessBanner({required this.caseRef});

  final String caseRef;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AuraSpace.s16, AuraSpace.s10, AuraSpace.s16, 0),
      padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s14, vertical: AuraSpace.s12),
      decoration: BoxDecoration(
        color: AuraSurface.goodBg,
        borderRadius: BorderRadius.circular(AuraRadius.md),
        border: Border.all(
            color: AuraSurface.goodInk.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded,
              size: 16, color: AuraSurface.goodInk),
          const SizedBox(width: AuraSpace.s8),
          Expanded(
            child: Text(
              'Case $caseRef submitted. The Aura team will follow up by email.',
              style:
                  AuraText.small.copyWith(color: AuraSurface.goodInk),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPOSER BAR
// ─────────────────────────────────────────────────────────────────────────────

class _ComposerBar extends StatelessWidget {
  const _ComposerBar({
    required this.ctrl,
    required this.sending,
    required this.disabled,
    required this.onSend,
    this.onEscalate,
  });

  final TextEditingController ctrl;
  final bool sending;
  final bool disabled;
  final VoidCallback onSend;
  final VoidCallback? onEscalate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AuraSpace.s16, AuraSpace.s10, AuraSpace.s16, AuraSpace.s12),
      color: AuraSurface.subtle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AuraSurface.card,
                    borderRadius: BorderRadius.circular(AuraRadius.r14),
                    border: Border.all(color: AuraSurface.divider),
                  ),
                  child: TextField(
                    controller: ctrl,
                    style: AuraText.body,
                    decoration: InputDecoration(
                      hintText: 'Describe your issue…',
                      hintStyle:
                          AuraText.body.copyWith(color: AuraSurface.muted),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: AuraSpace.s14, vertical: AuraSpace.s10),
                    ),
                    minLines: 1,
                    maxLines: 4,
                    enabled: !sending && !disabled,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                  ),
                ),
              ),
              const SizedBox(width: AuraSpace.s8),
              _SendButton(sending: sending, disabled: disabled, onSend: onSend),
            ],
          ),
          if (onEscalate != null) ...[
            const SizedBox(height: AuraSpace.s6),
            GestureDetector(
              onTap: onEscalate,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_outline_rounded,
                      size: 14, color: AuraSurface.muted),
                  const SizedBox(width: AuraSpace.s4),
                  Text(
                    'Talk to the Aura team',
                    style: AuraText.micro.copyWith(
                      color: AuraSurface.muted,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.sending,
    required this.disabled,
    required this.onSend,
  });

  final bool sending;
  final bool disabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final active = !sending && !disabled;
    return GestureDetector(
      onTap: active ? onSend : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: active ? AuraSurface.accent : AuraSurface.card,
          borderRadius: BorderRadius.circular(AuraRadius.r14),
          border: Border.all(
            color: active
                ? AuraSurface.accent.withValues(alpha: 0.6)
                : AuraSurface.divider,
          ),
        ),
        child: Center(
          child: sending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  Icons.send_rounded,
                  size: 18,
                  color: active ? Colors.white : AuraSurface.muted,
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ESCALATE FORM
// ─────────────────────────────────────────────────────────────────────────────

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
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AuraSpace.s16, AuraSpace.s10, AuraSpace.s16, 0),
      padding: const EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        color: AuraSurface.overlay,
        borderRadius: BorderRadius.circular(AuraRadius.md),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Submit to the Aura team', style: AuraText.subtitle),
          const SizedBox(height: AuraSpace.s4),
          Text(
            'Add your contact details so we can follow up by email.',
            style: AuraText.small.copyWith(color: AuraSurface.muted),
          ),
          const SizedBox(height: AuraSpace.s12),
          _AuraTextField(ctrl: nameCtrl, label: 'Name (optional)'),
          const SizedBox(height: AuraSpace.s8),
          _AuraTextField(
            ctrl: emailCtrl,
            label: 'Email (optional)',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: AuraSpace.s12),
          Row(
            children: [
              _AuraFilledButton(
                  label: 'Submit case', onPressed: onSubmit),
              const SizedBox(width: AuraSpace.s8),
              GestureDetector(
                onTap: onCancel,
                child: Text(
                  'Cancel',
                  style:
                      AuraText.small.copyWith(color: AuraSurface.muted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED ATOMS
// ─────────────────────────────────────────────────────────────────────────────

class _AuraTextField extends StatelessWidget {
  const _AuraTextField({
    required this.ctrl,
    required this.label,
    this.keyboardType,
  });

  final TextEditingController ctrl;
  final String label;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.md),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: TextField(
        controller: ctrl,
        style: AuraText.body,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              AuraText.small.copyWith(color: AuraSurface.muted),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.s14, vertical: AuraSpace.s10),
        ),
      ),
    );
  }
}

class _AuraFilledButton extends StatelessWidget {
  const _AuraFilledButton({
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s16, vertical: AuraSpace.s10),
        decoration: BoxDecoration(
          color: AuraSurface.accent,
          borderRadius: BorderRadius.circular(AuraRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: Colors.white),
              const SizedBox(width: AuraSpace.s6),
            ],
            Text(
              label,
              style: AuraText.small.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
