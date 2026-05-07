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
import '../domain/communication_type.dart';
import '../ui/institution_ds.dart';

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

  /// Frontend-only institutional type — encoded into the stored `title` via
  /// `[OFFICIAL:TYPE]` marker. The backend `kind` field is a separate
  /// taxonomy (GENERAL / RELEASE / SAFETY / GOVERNANCE) and stays untouched.
  InsCommunicationType _communicationType = InsCommunicationType.announcement;

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
      // Edit mode: peel the [OFFICIAL:TYPE] marker so the user edits the
      // clean title and the chip group reflects the existing type.
      final rawTitle = d['title']?.toString() ?? '';
      final decoded = InsCommunicationDecoded.parse(rawTitle);
      _titleController.text =
          decoded.hadMarker ? decoded.cleanTitle : rawTitle;
      _communicationType = decoded.hadMarker
          ? decoded.type
          : InsCommunicationType.announcement;
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

  /// Returns the headline used at submission time. Falls back to the
  /// first non-empty body line (capped at 80 chars) when the user left
  /// the title field blank, so every institutional statement carries a
  /// headline.
  String _resolvedCleanTitle() {
    final t = _titleController.text.trim();
    if (t.isNotEmpty) return t;
    final body = _bodyController.text.trim();
    if (body.isEmpty) return '';
    final firstLine = body.split('\n').firstWhere(
          (l) => l.trim().isNotEmpty,
          orElse: () => '',
        ).trim();
    if (firstLine.isEmpty) return '';
    return firstLine.length > 80 ? firstLine.substring(0, 80).trim() : firstLine;
  }

  Future<String?> _save() async {
    final cleanTitle = _resolvedCleanTitle();
    final summary = _summaryController.text.trim();
    final body = _bodyController.text.trim();

    if (cleanTitle.isEmpty && body.isEmpty) {
      setState(() => _error = 'Title or body is required.');
      return null;
    }
    if (summary.isEmpty) { setState(() => _error = 'Summary is required.'); return null; }
    if (body.isEmpty) { setState(() => _error = 'Body is required.'); return null; }

    final encodedTitle = InsCommunicationDecoded.encode(
      type: _communicationType,
      cleanTitle: cleanTitle,
    );

    setState(() { _saving = true; _error = null; });

    try {
      if (_savedId == null) {
        final result = await _repo.createInstitutionAnnouncement(
          widget.institutionId,
          title: encodedTitle,
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
          title: encodedTitle,
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
      if (!mounted) return;
      _showAudienceToast(published: true);
      context.pop(true);
    } catch (e) {
      setState(() { _error = _message(e, 'Could not publish.'); _publishing = false; });
    }
  }

  Future<void> _saveDraft() async {
    final id = await _save();
    if (id != null && mounted) {
      _showAudienceToast(published: false);
      context.pop(false);
    }
  }

  /// Distribution Phase 1 — publish-confirmation toast that names the
  /// audience reach so the host knows which group just received the
  /// announcement. The backend may or may not actually trigger push;
  /// this snackbar communicates the *intent* of the action.
  void _showAudienceToast({required bool published}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    String reach;
    switch (_audience.toUpperCase()) {
      case 'PUBLIC':
        reach = 'Public audience';
        break;
      case 'MEMBERS':
        reach = 'Members';
        break;
      case 'INTERNAL':
        reach = 'Internal — admins and editors';
        break;
      default:
        reach = 'Public audience';
    }
    final headline =
        published ? 'Announcement published' : 'Draft saved';
    messenger.showSnackBar(
      SnackBar(
        content: Text('$headline · $reach'),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
        padding: const EdgeInsets.fromLTRB(
          InsSpacing.screenHPad,
          InsSpacing.screenVPad,
          InsSpacing.screenHPad,
          AuraSpace.s32,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: InsSpacing.contentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Icon(Icons.arrow_back_rounded, size: 20, color: AuraSurface.muted),
                        ),
                      ),
                      const SizedBox(width: AuraSpace.s12),
                      Expanded(
                        child: InsModeHeader(
                          title: widget.isEditing
                              ? 'Edit announcement'
                              : 'New announcement',
                          description:
                              'Publish official institutional notices and public statements.',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AuraSpace.s24),
                  _AnnouncementCommunicationTypePicker(
                    selected: _communicationType,
                    onChanged: (t) =>
                        setState(() => _communicationType = t),
                  ),
                  const SizedBox(height: AuraSpace.s14),
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
                            labelText: 'Title (optional — derived from body if empty)',
                            hintText: 'Headline for this statement',
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

class _AnnouncementCommunicationTypePicker extends StatelessWidget {
  const _AnnouncementCommunicationTypePicker({
    required this.selected,
    required this.onChanged,
  });

  final InsCommunicationType selected;
  final ValueChanged<InsCommunicationType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'COMMUNICATION TYPE',
          style: AuraText.micro.copyWith(
            color: AuraSurface.faint,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: AuraSpace.s8),
        Wrap(
          spacing: AuraSpace.s8,
          runSpacing: AuraSpace.s8,
          children: [
            for (final t in InsCommunicationType.values)
              InkWell(
                onTap: () => onChanged(t),
                borderRadius: BorderRadius.circular(AuraRadius.pill),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AuraSpace.s12,
                    vertical: AuraSpace.s8,
                  ),
                  decoration: BoxDecoration(
                    color: selected == t
                        ? AuraSurface.accentSoft
                        : AuraSurface.subtle,
                    borderRadius: BorderRadius.circular(AuraRadius.pill),
                    border: Border.all(
                      color: selected == t
                          ? AuraSurface.accent.withValues(alpha: 0.4)
                          : AuraSurface.divider,
                    ),
                  ),
                  child: Text(
                    t.label,
                    style: AuraText.small.copyWith(
                      color: selected == t
                          ? AuraSurface.accentText
                          : AuraSurface.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
