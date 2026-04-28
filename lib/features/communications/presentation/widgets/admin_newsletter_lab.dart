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

class AdminNewsletterLab extends ConsumerStatefulWidget {
  const AdminNewsletterLab({super.key});

  @override
  ConsumerState<AdminNewsletterLab> createState() => _AdminNewsletterLabState();
}

class _AdminNewsletterLabState extends ConsumerState<AdminNewsletterLab> {
  final _subjectCtrl = TextEditingController(text: 'Aura update');
  final _headlineCtrl = TextEditingController(text: 'What is new in Aura');
  final _bodyCtrl = TextEditingController(
    text: 'A short update on the latest product improvements.',
  );
  final _ctaLabelCtrl = TextEditingController(text: 'Open Aura');
  final _ctaUrlCtrl = TextEditingController(text: 'https://auraplatform.org');
  final _toCtrl = TextEditingController();

  CommunicationRenderPreview? _preview;
  NewsletterTestResult? _testResult;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _headlineCtrl.dispose();
    _bodyCtrl.dispose();
    _ctaLabelCtrl.dispose();
    _ctaUrlCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  Future<void> _previewNewsletter() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(communicationsRepositoryProvider)
          .previewNewsletter(
            subject: _subjectCtrl.text.trim(),
            headline: _headlineCtrl.text.trim(),
            body: _bodyCtrl.text.trim(),
            ctaLabel: _ctaLabelCtrl.text.trim(),
            ctaUrl: _ctaUrlCtrl.text.trim(),
          );
      if (!mounted) return;
      setState(() => _preview = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _testNewsletter() async {
    if (_busy) return;
    final to = _toCtrl.text.trim();
    if (to.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a recipient email first.')),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(communicationsRepositoryProvider)
          .testNewsletter(
            to: to,
            subject: _subjectCtrl.text.trim(),
            headline: _headlineCtrl.text.trim(),
            body: _bodyCtrl.text.trim(),
            ctaLabel: _ctaLabelCtrl.text.trim(),
            ctaUrl: _ctaUrlCtrl.text.trim(),
          );
      if (!mounted) return;
      setState(() => _testResult = result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.skipped
                ? 'Newsletter test was suppressed.'
                : 'Newsletter test queued.',
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
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Newsletter preview and test send',
                  style: AuraText.subtitle,
                ),
              ),
              AuraStatusChip(
                label: 'Admin only',
                backgroundColor: AuraSurface.warnBg,
                textColor: AuraSurface.warnInk,
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s8),
          const Text(
            'Render the newsletter before queueing a test send. Normal members never see this surface.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s12),
          CommTwoColumnFields(
            fields: [
              AuraInput(controller: _subjectCtrl, label: 'Subject'),
              AuraInput(controller: _headlineCtrl, label: 'Headline'),
              AuraInput(controller: _ctaLabelCtrl, label: 'CTA label'),
              AuraInput(controller: _ctaUrlCtrl, label: 'CTA URL'),
            ],
          ),
          const SizedBox(height: AuraSpace.s12),
          AuraInput(
            controller: _bodyCtrl,
            label: 'Body',
            maxLines: 6,
            minLines: 4,
          ),
          const SizedBox(height: AuraSpace.s12),
          AuraInput(
            controller: _toCtrl,
            label: 'Test recipient email',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: AuraSpace.s12),
          Wrap(
            spacing: AuraSpace.s10,
            runSpacing: AuraSpace.s10,
            children: [
              AuraPrimaryButton(
                label: _busy ? 'Working…' : 'Preview newsletter',
                onPressed: _busy ? null : _previewNewsletter,
                icon: Icons.visibility_outlined,
              ),
              AuraSecondaryButton(
                label: _busy ? 'Working…' : 'Test send',
                onPressed: _busy ? null : _testNewsletter,
                icon: Icons.send_outlined,
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: AuraSpace.s12),
            AuraErrorState(title: 'Newsletter action failed', body: _error!),
          ],
          if (_testResult != null) ...[
            const SizedBox(height: AuraSpace.s12),
            CommResultCard(
              title: _testResult!.skipped
                  ? 'Test send suppressed'
                  : 'Test send queued',
              body: _testResult!.skipped
                  ? (_testResult!.reason.isNotEmpty
                      ? _testResult!.reason
                      : 'The backend suppressed this test send.')
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
        ],
      ),
    );
  }
}
