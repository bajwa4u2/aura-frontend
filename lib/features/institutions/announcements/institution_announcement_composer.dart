import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/institutions_repository.dart';

class InstitutionAnnouncementComposer extends ConsumerStatefulWidget {
  const InstitutionAnnouncementComposer({
    super.key,
    required this.institutionId,
    this.announcementId,
    this.initialData,
  });

  final String institutionId;
  final String? announcementId;
  final Map<String, dynamic>? initialData;

  bool get isEditing => announcementId != null;

  @override
  ConsumerState<InstitutionAnnouncementComposer> createState() =>
      _InstitutionAnnouncementComposerState();
}

class _InstitutionAnnouncementComposerState
    extends ConsumerState<InstitutionAnnouncementComposer> {
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _bodyController = TextEditingController();

  String _kind = 'GENERAL';
  String _audience = 'PUBLIC';

  bool _saving = false;
  bool _publishing = false;
  String? _error;
  String? _savedId;

  static const _kinds = ['GENERAL', 'RELEASE', 'SAFETY', 'GOVERNANCE'];
  static const _audiences = ['PUBLIC', 'MEMBERS', 'INTERNAL'];

  InstitutionsRepository get _repo => ref.read(institutionsRepositoryProvider);

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    if (d != null) {
      _titleController.text = d['title']?.toString() ?? '';
      _summaryController.text = d['summary']?.toString() ?? '';
      _bodyController.text = d['bodyMarkdown']?.toString() ?? '';
      _kind = d['kind']?.toString() ?? 'GENERAL';
      _audience = d['audience']?.toString() ?? 'PUBLIC';
    }
    _savedId = widget.announcementId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  String _message(Object error, String fallback) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final msg = data['message']?.toString().trim() ?? '';
        if (msg.isNotEmpty) return msg;
      }
    }
    return fallback;
  }

  Future<String?> _save() async {
    final title = _titleController.text.trim();
    final summary = _summaryController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty) { setState(() => _error = 'Title is required.'); return null; }
    if (summary.isEmpty) { setState(() => _error = 'Summary is required.'); return null; }
    if (body.isEmpty) { setState(() => _error = 'Body is required.'); return null; }

    setState(() { _saving = true; _error = null; });

    try {
      if (_savedId == null) {
        final result = await _repo.createInstitutionAnnouncement(
          widget.institutionId,
          title: title,
          summary: summary,
          bodyMarkdown: body,
          kind: _kind,
          audience: _audience,
        );
        _savedId = result['id']?.toString();
      } else {
        await _repo.updateInstitutionAnnouncement(
          widget.institutionId,
          _savedId!,
          title: title,
          summary: summary,
          bodyMarkdown: body,
          kind: _kind,
          audience: _audience,
        );
      }
      setState(() { _saving = false; });
      return _savedId;
    } catch (e) {
      setState(() { _error = _message(e, 'Could not save.'); _saving = false; });
      return null;
    }
  }

  Future<void> _saveAndPublish() async {
    setState(() { _publishing = true; _error = null; });
    try {
      final id = await _save();
      if (id == null) { setState(() => _publishing = false); return; }
      await _repo.publishInstitutionAnnouncement(widget.institutionId, id);
      if (mounted) context.pop(true);
    } catch (e) {
      setState(() { _error = _message(e, 'Could not publish.'); _publishing = false; });
    }
  }

  Future<void> _saveDraft() async {
    final id = await _save();
    if (id != null && mounted) context.pop(false);
  }

  Widget _buildDropdownRow(String label, String value, List<String> options, void Function(String) onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: AuraText.small.copyWith(color: AuraSurface.muted, fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            items: options.map((o) => DropdownMenuItem(
              value: o,
              child: Text(o[0] + o.substring(1).toLowerCase(), style: AuraText.small),
            )).toList(),
            onChanged: (v) { if (v != null) setState(() => onChanged(v)); },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _saving || _publishing;

    return AuraScaffold(
      showHeader: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AuraSpace.s16, AuraSpace.s20, AuraSpace.s16, AuraSpace.s32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 740),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: const Icon(Icons.arrow_back_rounded, size: 20, color: AuraSurface.muted),
                      ),
                      const SizedBox(width: AuraSpace.s12),
                      Expanded(
                        child: Text(
                          widget.isEditing ? 'Edit announcement' : 'New announcement',
                          style: AuraText.headline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AuraSpace.s24),
                  Container(
                    padding: const EdgeInsets.all(AuraSpace.s16),
                    decoration: BoxDecoration(
                      color: AuraSurface.card,
                      borderRadius: BorderRadius.circular(AuraRadius.card),
                      border: Border.all(color: AuraSurface.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _titleController,
                          style: AuraText.body.copyWith(fontWeight: FontWeight.w700, fontSize: 18),
                          decoration: const InputDecoration(
                            labelText: 'Title',
                            hintText: 'Announcement title',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                        const Divider(color: AuraSurface.divider),
                        const SizedBox(height: AuraSpace.s8),
                        TextFormField(
                          controller: _summaryController,
                          style: AuraText.body,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Summary',
                            hintText: 'One or two sentences summarising the announcement',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                        const Divider(color: AuraSurface.divider),
                        const SizedBox(height: AuraSpace.s8),
                        TextFormField(
                          controller: _bodyController,
                          style: AuraText.body,
                          maxLines: 12,
                          decoration: const InputDecoration(
                            labelText: 'Body (Markdown)',
                            hintText: 'Full announcement body…',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            alignLabelWithHint: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AuraSpace.s16),
                  Container(
                    padding: const EdgeInsets.all(AuraSpace.s16),
                    decoration: BoxDecoration(
                      color: AuraSurface.card,
                      borderRadius: BorderRadius.circular(AuraRadius.card),
                      border: Border.all(color: AuraSurface.divider),
                    ),
                    child: Column(
                      children: [
                        _buildDropdownRow('Kind', _kind, _kinds, (v) => _kind = v),
                        const SizedBox(height: AuraSpace.s8),
                        _buildDropdownRow('Audience', _audience, _audiences, (v) => _audience = v),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AuraSpace.s12),
                    Container(
                      padding: const EdgeInsets.all(AuraSpace.s12),
                      decoration: BoxDecoration(
                        color: AuraSurface.dangerBg,
                        borderRadius: BorderRadius.circular(AuraRadius.md),
                        border: Border.all(color: AuraSurface.dangerInk.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, size: 16, color: AuraSurface.dangerInk),
                          const SizedBox(width: AuraSpace.s8),
                          Expanded(child: Text(_error!, style: AuraText.small.copyWith(color: AuraSurface.dangerInk))),
                          GestureDetector(
                            onTap: () => setState(() => _error = null),
                            child: const Icon(Icons.close, size: 16, color: AuraSurface.dangerInk),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AuraSpace.s20),
                  Row(
                    children: [
                      Expanded(
                        child: AuraSecondaryButton(
                          label: _saving ? 'Saving…' : 'Save draft',
                          onPressed: isBusy ? null : _saveDraft,
                          icon: Icons.save_outlined,
                        ),
                      ),
                      const SizedBox(width: AuraSpace.s12),
                      Expanded(
                        child: AuraPrimaryButton(
                          label: _publishing ? 'Publishing…' : 'Publish',
                          onPressed: isBusy ? null : _saveAndPublish,
                          icon: Icons.send_rounded,
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
