import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/aura_card.dart';
import '../../../../core/ui/aura_platform_components.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_surface.dart';
import '../../../../core/ui/aura_text.dart';
import '../../domain/communications_models.dart';
import '../../providers.dart';
import 'communication_empty_error_states.dart';

class AdminAiDraftPanel extends ConsumerStatefulWidget {
  const AdminAiDraftPanel({super.key});

  @override
  ConsumerState<AdminAiDraftPanel> createState() => _AdminAiDraftPanelState();
}

class _AdminAiDraftPanelState extends ConsumerState<AdminAiDraftPanel> {
  final _draftTypeCtrl = TextEditingController(text: 'support_reply');
  final _categoryCtrl = TextEditingController(text: 'support');
  final _audienceCtrl = TextEditingController(text: 'member');
  final _goalCtrl = TextEditingController(
    text: 'Reply to the member clearly and kindly.',
  );
  final _sourceCtrl = TextEditingController(
    text: 'The member asked for help with account access.',
  );

  CommunicationDraftResult? _draftResult;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _draftTypeCtrl.dispose();
    _categoryCtrl.dispose();
    _audienceCtrl.dispose();
    _goalCtrl.dispose();
    _sourceCtrl.dispose();
    super.dispose();
  }

  Future<void> _createAiDraft() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final draft = await ref
          .read(communicationsRepositoryProvider)
          .createAiDraft(
            draftType: _draftTypeCtrl.text.trim(),
            category: _categoryCtrl.text.trim(),
            audience: _audienceCtrl.text.trim(),
            goal: _goalCtrl.text.trim(),
            sourceText: _sourceCtrl.text.trim(),
          );
      if (!mounted) return;
      setState(() => _draftResult = draft);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text('AI draft assistant', style: AuraText.subtitle),
              ),
              AuraStatusChip(
                label: 'Draft only',
                backgroundColor: AuraSurface.infoBg,
                textColor: AuraSurface.infoInk,
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s8),
          const Text(
            'Create a communication draft with AI, then review it before any campaign work begins.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s12),
          CommTwoColumnFields(
            fields: [
              AuraInput(controller: _draftTypeCtrl, label: 'Draft type'),
              AuraInput(controller: _categoryCtrl, label: 'Category'),
              AuraInput(controller: _audienceCtrl, label: 'Audience'),
              AuraInput(controller: _goalCtrl, label: 'Goal'),
            ],
          ),
          const SizedBox(height: AuraSpace.s12),
          AuraInput(
            controller: _sourceCtrl,
            label: 'Source text',
            maxLines: 6,
            minLines: 4,
          ),
          const SizedBox(height: AuraSpace.s12),
          AuraPrimaryButton(
            label: _busy ? 'Working…' : 'Create AI draft',
            onPressed: _busy ? null : _createAiDraft,
            icon: Icons.auto_awesome_outlined,
          ),
          if (_error != null) ...[
            const SizedBox(height: AuraSpace.s12),
            AuraErrorState(title: 'AI draft failed', body: _error!),
          ],
          if (_draftResult != null) ...[
            const SizedBox(height: AuraSpace.s12),
            CommResultCard(
              title: _draftResult!.subject.isNotEmpty
                  ? _draftResult!.subject
                  : 'AI draft created',
              body:
                  'Status: ${_draftResult!.status} · ${_draftResult!.sendStatus.isNotEmpty ? _draftResult!.sendStatus : 'NOT_SENT'}',
              chipLabel: _draftResult!.source.isNotEmpty
                  ? _draftResult!.source
                  : 'AI',
            ),
            const SizedBox(height: AuraSpace.s12),
            AuraCard(
              borderColor: AuraSurface.divider,
              color: AuraSurface.subtle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Draft body preview', style: AuraText.body),
                  const SizedBox(height: AuraSpace.s8),
                  Text(
                    _draftResult!.bodyText.isNotEmpty
                        ? _draftResult!.bodyText
                        : 'No body returned.',
                    style: AuraText.muted,
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
