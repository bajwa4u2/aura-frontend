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

class AdminCampaignWorkflow extends ConsumerStatefulWidget {
  const AdminCampaignWorkflow({super.key});

  @override
  ConsumerState<AdminCampaignWorkflow> createState() =>
      _AdminCampaignWorkflowState();
}

class _AdminCampaignWorkflowState
    extends ConsumerState<AdminCampaignWorkflow> {
  final _nameCtrl = TextEditingController(text: 'April product update');
  final _categoryCtrl = TextEditingController(text: 'newsletter');
  final _audienceKindCtrl = TextEditingController(text: 'manual');
  final _subjectCtrl = TextEditingController(text: 'Aura update');
  final _bodyCtrl = TextEditingController(
    text: 'Draft body for the approved communication.',
  );
  final _ctaLabelCtrl = TextEditingController(text: 'Open Aura');
  final _ctaUrlCtrl = TextEditingController(text: 'https://auraplatform.org');
  final _toCtrl = TextEditingController();
  final _draftIdCtrl = TextEditingController();

  CampaignCreationResult? _creationResult;
  CommunicationRenderPreview? _preview;
  CampaignActionResult? _approveResult;
  CampaignQueueResult? _testResult;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    _audienceKindCtrl.dispose();
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    _ctaLabelCtrl.dispose();
    _ctaUrlCtrl.dispose();
    _toCtrl.dispose();
    _draftIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _createCampaign() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(communicationsRepositoryProvider)
          .createCampaign(
            name: _nameCtrl.text.trim(),
            category: _categoryCtrl.text.trim(),
            audienceKind: _audienceKindCtrl.text.trim(),
            subject: _subjectCtrl.text.trim(),
            bodyText: _bodyCtrl.text.trim(),
            ctaLabel: _ctaLabelCtrl.text.trim(),
            ctaUrl: _ctaUrlCtrl.text.trim(),
          );
      if (!mounted) return;
      setState(() {
        _creationResult = result;
        _draftIdCtrl.text = result.draftId;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _previewCampaign() async {
    final draftId = _draftIdCtrl.text.trim();
    if (draftId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create or enter a draft id first.')),
      );
      return;
    }
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(communicationsRepositoryProvider)
          .previewCampaignDraft(draftId);
      if (!mounted) return;
      setState(() => _preview = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approveCampaign() async {
    final draftId = _draftIdCtrl.text.trim();
    if (draftId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create or enter a draft id first.')),
      );
      return;
    }
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(communicationsRepositoryProvider)
          .approveCampaignDraft(draftId);
      if (!mounted) return;
      setState(() => _approveResult = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _testCampaign() async {
    final draftId = _draftIdCtrl.text.trim();
    final to = _toCtrl.text.trim();
    if (draftId.isEmpty || to.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a draft id and recipient email first.'),
        ),
      );
      return;
    }
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(communicationsRepositoryProvider)
          .testCampaignDraft(draftId: draftId, to: to);
      if (!mounted) return;
      setState(() => _testResult = result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.skipped
                ? 'Campaign test was skipped.'
                : 'Campaign test queued.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draftId = _draftIdCtrl.text.trim();
    final approved =
        _approveResult?.status.toUpperCase() == 'APPROVED';

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Campaign draft workflow',
                  style: AuraText.subtitle,
                ),
              ),
              AuraStatusChip(
                label: approved ? 'Approved' : 'Draft',
                backgroundColor:
                    approved ? AuraSurface.coVerdant.withValues(alpha: 0.16) : AuraSurface.subtle,
                textColor: approved ? AuraSurface.coVerdant : AuraSurface.muted,
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s8),
          const Text(
            'Create a draft, preview it, approve it explicitly, and only then run a test send.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s12),
          CommTwoColumnFields(
            fields: [
              AuraInput(controller: _nameCtrl, label: 'Name'),
              AuraInput(controller: _categoryCtrl, label: 'Category'),
              AuraInput(
                controller: _audienceKindCtrl,
                label: 'Audience kind',
              ),
              AuraInput(controller: _subjectCtrl, label: 'Subject'),
            ],
          ),
          const SizedBox(height: AuraSpace.s12),
          AuraInput(
            controller: _bodyCtrl,
            label: 'Body text',
            maxLines: 6,
            minLines: 4,
          ),
          const SizedBox(height: AuraSpace.s12),
          CommTwoColumnFields(
            fields: [
              AuraInput(controller: _ctaLabelCtrl, label: 'CTA label'),
              AuraInput(controller: _ctaUrlCtrl, label: 'CTA URL'),
              AuraInput(controller: _draftIdCtrl, label: 'Draft id'),
              AuraInput(
                controller: _toCtrl,
                label: 'Test recipient email',
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s12),
          Wrap(
            spacing: AuraSpace.s10,
            runSpacing: AuraSpace.s10,
            children: [
              AuraPrimaryButton(
                label: _busy ? 'Working…' : 'Create campaign',
                onPressed: _busy ? null : _createCampaign,
                icon: Icons.add_circle_outline,
              ),
              AuraSecondaryButton(
                label: _busy ? 'Working…' : 'Preview',
                onPressed: _busy ? null : _previewCampaign,
                icon: Icons.visibility_outlined,
              ),
              AuraSecondaryButton(
                label: _busy ? 'Working…' : 'Approve',
                onPressed: _busy ? null : _approveCampaign,
                icon: Icons.verified_outlined,
              ),
              AuraGhostButton(
                label: _busy ? 'Working…' : 'Test send',
                onPressed: _busy ? null : _testCampaign,
                icon: Icons.send_outlined,
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: AuraSpace.s12),
            AuraErrorState(
              title: 'Campaign action failed',
              body: _error!,
            ),
          ],
          if (_creationResult != null) ...[
            const SizedBox(height: AuraSpace.s12),
            CommResultCard(
              title: 'Campaign created',
              body:
                  'Campaign ${_creationResult!.campaignId} · Draft ${_creationResult!.draftId}',
              chipLabel:
                  '${_creationResult!.campaignStatus} / ${_creationResult!.draftStatus}',
            ),
          ],
          if (_approveResult != null) ...[
            const SizedBox(height: AuraSpace.s12),
            CommResultCard(
              title: 'Campaign approval',
              body: 'Status: ${_approveResult!.status}',
              chipLabel: _approveResult!.status,
            ),
          ],
          if (_testResult != null) ...[
            const SizedBox(height: AuraSpace.s12),
            CommResultCard(
              title: _testResult!.skipped
                  ? 'Campaign test skipped'
                  : 'Campaign test queued',
              body: _testResult!.skipped
                  ? (_testResult!.reason.isNotEmpty
                      ? _testResult!.reason
                      : 'The backend skipped this test send.')
                  : 'Outbox ${_testResult!.outboxId}',
              chipLabel: _testResult!.queued
                  ? 'Queued'
                  : (_testResult!.skipped ? 'Skipped' : 'Ok'),
            ),
          ],
          if (_preview != null) ...[
            const SizedBox(height: AuraSpace.s12),
            CommPreviewPanel(
              title: _preview!.subject,
              previewText: _preview!.previewText,
              text: _preview!.text,
              html: _preview!.html,
            ),
          ],
          if (draftId.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s8),
            Text(
              approved
                  ? 'Draft $draftId is approved and can be tested.'
                  : 'Draft $draftId is not approved yet. Approve it before test sends.',
              style: AuraText.small.copyWith(color: AuraSurface.muted),
            ),
          ],
        ],
      ),
    );
  }
}
