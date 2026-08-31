/// THE GOVERNED ACTION.
///
/// Every consequential thing an operator does follows one shape:
///
///   INTENT → CONSEQUENCE PREVIEW → CONFIRM → ACTION → OUTCOME → RECORD
///
/// The preview is the part that matters and the part usually missing. An
/// operator approving an identity, revoking a grant or upholding an appeal is
/// changing someone's standing, and often sending them a notification. They
/// should be told THAT before they commit, not discover it afterwards from the
/// audit log.
///
/// This does not perform authority. The action itself calls the owning
/// authority, which decides; this is the ceremony around it, and the honest
/// reporting of what came back.
library;

import 'package:flutter/material.dart';

import '../../../core/product/product_language.dart';
import '../../../core/ui/aura_bounded_editor.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import 'operator_kit.dart';

/// One consequence of taking an action, stated plainly.
class OperatorConsequence {
  const OperatorConsequence({
    required this.text,
    this.tone = OperatorTone.neutral,
    this.icon,
  });

  /// "The person is notified." — not "notifyUser=true".
  final String text;
  final OperatorTone tone;
  final IconData? icon;

  /// Something becomes visible outside Aura. Called out separately because it
  /// is the consequence operators most regret discovering late.
  factory OperatorConsequence.becomesPublic(String what) => OperatorConsequence(
    text: '$what becomes publicly visible.',
    tone: OperatorTone.warn,
    icon: Icons.public_rounded,
  );

  /// Someone is told. Notification is a consequence, not an implementation
  /// detail.
  factory OperatorConsequence.notifies(String who) => OperatorConsequence(
    text: '$who is notified.',
    tone: OperatorTone.pending,
    icon: Icons.notifications_active_rounded,
  );

  factory OperatorConsequence.irreversible(String what) => OperatorConsequence(
    text: '$what cannot be undone.',
    tone: OperatorTone.danger,
    icon: Icons.report_gmailerrorred_rounded,
  );

  factory OperatorConsequence.recorded(String what) => OperatorConsequence(
    text: '$what is recorded against your authority.',
    icon: Icons.history_edu_rounded,
  );
}

/// The definition of a governed action.
class OperatorAction {
  const OperatorAction({
    required this.title,
    required this.subject,
    required this.confirmLabel,
    required this.consequences,
    required this.perform,
    this.detail,
    this.requiresReason = false,
    this.reasonLabel = 'Reason',
    this.destructive = false,
  });

  final String title;

  /// Who or what this happens to. Always shown — an operator must never
  /// confirm an action without seeing its subject.
  final String subject;

  final String? detail;
  final String confirmLabel;
  final List<OperatorConsequence> consequences;

  /// Some authorities refuse an action without a recorded reason. Where that
  /// is true, the field is required here too rather than failing at the API.
  final bool requiresReason;
  final String reasonLabel;

  final bool destructive;

  /// Calls the owning authority. Returns a short outcome line on success and
  /// throws on failure — both are reported honestly.
  final Future<String> Function(String? reason) perform;
}

/// Runs the ceremony. Returns true when the action completed.
Future<bool> runOperatorAction(
  BuildContext context,
  OperatorAction action,
) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ActionSheet(action: action),
  );
  return result ?? false;
}

class _ActionSheet extends StatefulWidget {
  const _ActionSheet({required this.action});

  final OperatorAction action;

  @override
  State<_ActionSheet> createState() => _ActionSheetState();
}

enum _Phase { preview, running, done, failed }

class _ActionSheetState extends State<_ActionSheet> {
  final _reason = TextEditingController();
  _Phase _phase = _Phase.preview;
  String? _outcome;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  bool get _canConfirm {
    if (_phase != _Phase.preview) return false;
    if (widget.action.requiresReason && _reason.text.trim().isEmpty) {
      return false;
    }
    return true;
  }

  Future<void> _confirm() async {
    setState(() => _phase = _Phase.running);
    try {
      final outcome = await widget.action.perform(
        widget.action.requiresReason ? _reason.text.trim() : null,
      );
      if (!mounted) return;
      setState(() {
        _phase = _Phase.done;
        _outcome = outcome;
      });
    } catch (e) {
      if (!mounted) return;
      // The action failed. Saying so plainly matters more than a tidy sheet:
      // an operator who thinks a decision landed when it did not will not
      // retry it.
      setState(() {
        _phase = _Phase.failed;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return PopScope(
      // The barrier holds for exactly one phase. An operator who dismissed
      // while the action was in flight would never learn whether the decision
      // landed — and a decision believed not to have landed gets taken twice.
      // Every other phase dismisses freely: a preview that cannot be abandoned
      // is a trap, and an outcome already recorded loses nothing by closing.
      canPop: _phase != _Phase.running,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: AuraSurface.card,
            border: Border(top: BorderSide(color: AuraSurface.divider)),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AuraRadius.xl),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            AuraSpace.s20,
            AuraSpace.s12,
            AuraSpace.s20,
            AuraSpace.s20,
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: AuraSpace.s16),
                      decoration: BoxDecoration(
                        color: AuraSurface.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    action.title,
                    style: const TextStyle(
                      color: AuraSurface.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    action.subject,
                    style: const TextStyle(
                      color: AuraSurface.muted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: AuraSpace.s16),
                  ..._body(action),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _body(OperatorAction action) {
    switch (_phase) {
      case _Phase.preview:
        return [
          if (action.detail != null) ...[
            Text(
              action.detail!,
              style: const TextStyle(
                color: AuraSurface.muted,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AuraSpace.s16),
          ],
          const Text(
            'WHAT THIS CHANGES',
            style: TextStyle(
              color: AuraSurface.faint,
              fontSize: 11,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AuraSpace.s8),
          for (final c in action.consequences)
            Padding(
              padding: const EdgeInsets.only(bottom: AuraSpace.s8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    c.icon ?? Icons.arrow_right_rounded,
                    size: 16,
                    color: c.tone.ink,
                  ),
                  const SizedBox(width: AuraSpace.s8),
                  Expanded(
                    child: Text(
                      c.text,
                      style: const TextStyle(
                        color: AuraSurface.ink,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (action.requiresReason) ...[
            const SizedBox(height: AuraSpace.s8),
            // A bounded multi-line field otherwise claims the wheel and
            // strands the sheet scrolling behind it. AuraBoundedEditor hands
            // the scrolling back; the field must adopt BOTH pieces it gives.
            AuraBoundedEditor(
              builder: (context, scrollController, physics) => TextField(
                controller: _reason,
                onChanged: (_) => setState(() {}),
                maxLines: 3,
                minLines: 2,
                scrollController: scrollController,
                scrollPhysics: physics,
                style: const TextStyle(color: AuraSurface.ink, fontSize: 13),
                decoration: InputDecoration(
                  labelText: action.reasonLabel,
                  helperText: 'Recorded with this decision.',
                  filled: true,
                  fillColor: AuraSurface.page,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AuraRadius.md),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: AuraSpace.s20),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: AuraSpace.s12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _canConfirm ? _confirm : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: action.destructive
                        ? AuraSurface.dangerInk
                        : AuraSurface.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: AuraSpace.s14,
                    ),
                  ),
                  child: Text(action.confirmLabel),
                ),
              ),
            ],
          ),
        ];

      case _Phase.running:
        return const [
          Padding(
            padding: EdgeInsets.symmetric(vertical: AuraSpace.s20),
            child: LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: AuraSurface.divider,
              color: AuraSurface.accent,
            ),
          ),
          Text(
            'Applying…',
            textAlign: TextAlign.center,
            style: TextStyle(color: AuraSurface.muted, fontSize: 13),
          ),
        ];

      case _Phase.done:
        return [
          OperatorPanel(
            tone: OperatorTone.good,
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: AuraSurface.goodInk,
                ),
                const SizedBox(width: AuraSpace.s12),
                Expanded(
                  child: Text(
                    _outcome ?? 'Done.',
                    style: const TextStyle(
                      color: AuraSurface.ink,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AuraSpace.s16),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AuraSurface.elevated,
              foregroundColor: AuraSurface.ink,
              padding: const EdgeInsets.symmetric(vertical: AuraSpace.s14),
            ),
            child: const Text('Close'),
          ),
        ];

      case _Phase.failed:
        return [
          OperatorFailure(title: 'The action did not complete', detail: _error),
          const SizedBox(height: AuraSpace.s16),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  // Popping false is important: the caller must not treat a
                  // failed action as a completed one and refresh as though
                  // something changed.
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Close'),
                ),
              ),
              const SizedBox(width: AuraSpace.s12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: () => setState(() => _phase = _Phase.preview),
                  style: FilledButton.styleFrom(
                    backgroundColor: AuraSurface.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: AuraSpace.s14,
                    ),
                  ),
                  child: Text(ProductLabels.of(ProductAction.retry)),
                ),
              ),
            ],
          ),
        ];
    }
  }
}
