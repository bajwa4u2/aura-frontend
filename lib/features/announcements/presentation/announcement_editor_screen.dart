import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';

enum AnnouncementEditorScope {
  platform,
  institution,
}

class AnnouncementEditorScreen extends ConsumerStatefulWidget {
  const AnnouncementEditorScreen({
    super.key,
    required this.scope,
  });

  final AnnouncementEditorScope scope;

  @override
  ConsumerState<AnnouncementEditorScreen> createState() =>
      _AnnouncementEditorScreenState();
}

class _AnnouncementEditorScreenState
    extends ConsumerState<AnnouncementEditorScreen> {
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _bodyController = TextEditingController();

  bool _pinNotice = false;
  bool _publishToAura = true;
  bool _publishToLinkedIn = false;
  bool _publishToTikTok = false;

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  String get _scopeLabel {
    switch (widget.scope) {
      case AnnouncementEditorScope.platform:
        return 'Platform';
      case AnnouncementEditorScope.institution:
        return 'Institution';
    }
  }

  String get _pageTitle {
    switch (widget.scope) {
      case AnnouncementEditorScope.platform:
        return 'Platform announcement';
      case AnnouncementEditorScope.institution:
        return 'Institution announcement';
    }
  }

  String get _introText {
    switch (widget.scope) {
      case AnnouncementEditorScope.platform:
        return 'Use this surface for official notices issued in the platform voice. Distribution controls stay deliberate and limited.';
      case AnnouncementEditorScope.institution:
        return 'Use this surface for institution-facing notices. Distribution remains controlled and should reflect institutional standing and intent.';
    }
  }

  String get _publishButtonText {
    switch (widget.scope) {
      case AnnouncementEditorScope.platform:
        return 'Publish platform notice';
      case AnnouncementEditorScope.institution:
        return 'Publish institution notice';
    }
  }

  String _institutionName() {
    final access = ref.read(institutionAccessProvider).maybeWhen(
          data: (value) => value,
          orElse: () => null,
        );

    if (access == null) return 'Institution';
    final institution = access.institution;
    if (institution is Map) {
      final fromInstitution = (institution['name'] ?? '').toString().trim();
      if (fromInstitution.isNotEmpty) return fromInstitution;
    }
    final request = access.request;
    if (request is Map) {
      final fromRequest = (request['organizationName'] ?? '').toString().trim();
      if (fromRequest.isNotEmpty) return fromRequest;
    }
    return 'Institution';
  }

  void _notWiredYet() {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Editor surface is ready. Publish wiring can be connected next.',
        ),
      ),
    );
  }

  Widget _textField({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AuraText.body.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: AuraSpace.s8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _distributionCard() {
    final linkedInSubtitle = widget.scope == AnnouncementEditorScope.platform
        ? 'Connected'
        : 'Connected for authorized institutional use';

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Distribution', style: AuraText.title),
          const SizedBox(height: AuraSpace.s8),
          Text(
            'Choose where this notice should be issued. This is an administrative decision surface, not a casual sharing layer.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s12),
          _DistributionRow(
            icon: Icons.blur_on_outlined,
            title: 'Aura',
            subtitle: 'Primary publication',
            value: _publishToAura,
            onChanged: (value) {
              setState(() => _publishToAura = value);
            },
          ),
          const Divider(height: 1),
          _DistributionRow(
            icon: Icons.work_outline,
            title: 'LinkedIn',
            subtitle: linkedInSubtitle,
            value: _publishToLinkedIn,
            onChanged: (value) {
              setState(() => _publishToLinkedIn = value);
            },
          ),
          const Divider(height: 1),
          _DistributionRow(
            icon: Icons.music_note_outlined,
            title: 'TikTok',
            subtitle: 'Requires compatible video media',
            value: _publishToTikTok,
            onChanged: (value) {
              setState(() => _publishToTikTok = value);
            },
          ),
        ],
      ),
    );
  }

  Widget _metadataCard() {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Controls', style: AuraText.title),
          const SizedBox(height: AuraSpace.s8),
          Text(
            'Keep the announcement surface quiet and official. Pinned notices should be used sparingly.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Pin this notice'),
            subtitle: const Text('Keep visible at the top of announcement surfaces'),
            value: _pinNotice,
            onChanged: (value) {
              setState(() => _pinNotice = value);
            },
          ),
        ],
      ),
    );
  }

  Widget _attachmentsCard() {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Attachments', style: AuraText.title),
          const SizedBox(height: AuraSpace.s8),
          Text(
            'Attachments are not wired in this editor yet. When connected, this section should follow the same controlled media rules used elsewhere in Aura.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s12),
          OutlinedButton.icon(
            onPressed: _notWiredYet,
            icon: const Icon(Icons.add),
            label: const Text('Add attachment'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final institutionName = _institutionName();

    return AuraScaffold(
      title: _pageTitle,
      showHomeAction: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AuraSpace.s16,
          AuraSpace.s12,
          AuraSpace.s16,
          AuraSpace.s24,
        ),
        children: [
          AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_pageTitle, style: AuraText.title),
                const SizedBox(height: AuraSpace.s8),
                Text(_introText, style: AuraText.body),
                const SizedBox(height: AuraSpace.s12),
                Wrap(
                  spacing: AuraSpace.s10,
                  runSpacing: AuraSpace.s10,
                  children: [
                    _EditorChip(label: 'Scope: $_scopeLabel'),
                    if (widget.scope == AnnouncementEditorScope.institution)
                      _EditorChip(label: institutionName),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AuraSpace.s12),
          AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _textField(
                  label: 'Title',
                  controller: _titleController,
                  hint: 'Write the formal notice title',
                ),
                const SizedBox(height: AuraSpace.s16),
                _textField(
                  label: 'Summary',
                  controller: _summaryController,
                  maxLines: 3,
                  hint: 'Short orientation line for archive and detail views',
                ),
                const SizedBox(height: AuraSpace.s16),
                _textField(
                  label: 'Body',
                  controller: _bodyController,
                  maxLines: 12,
                  hint: 'Write the full announcement body',
                ),
              ],
            ),
          ),
          const SizedBox(height: AuraSpace.s12),
          _metadataCard(),
          const SizedBox(height: AuraSpace.s12),
          _attachmentsCard(),
          const SizedBox(height: AuraSpace.s12),
          _distributionCard(),
          const SizedBox(height: AuraSpace.s12),
          AuraCard(
            child: Wrap(
              spacing: AuraSpace.s10,
              runSpacing: AuraSpace.s10,
              children: [
                FilledButton.icon(
                  onPressed: _notWiredYet,
                  icon: const Icon(Icons.publish_outlined),
                  label: Text(_publishButtonText),
                ),
                OutlinedButton.icon(
                  onPressed: _notWiredYet,
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Save draft'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DistributionRow extends StatelessWidget {
  const _DistributionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _EditorChip extends StatelessWidget {
  const _EditorChip({required this.label});

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
