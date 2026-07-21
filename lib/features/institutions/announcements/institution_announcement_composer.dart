import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/attachments/aura_media_upload.dart';
import '../../../core/tagging/tag_entities.dart';
import '../../../core/tagging/governed_tag_field.dart';
import '../../../core/tagging/tag_text_hydration.dart';
import '../../../core/media/attachment.dart';
import '../../../core/media/media_mime.dart';
import '../../../core/net/dio_provider.dart';
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
  // AXR-1 — explicit focus node for governed tag autocomplete on the body.
  final _bodyFocus = FocusNode();

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

  /// Canonical media attached to this announcement. On edit, prepopulated
  /// from `initialData['media']` so the host can review or remove what's
  /// already attached. New picks are appended via [_pickMedia]. The list
  /// is always the source of truth for what we POST/PATCH as `mediaIds`.
  final List<Attachment> _attachments = <Attachment>[];
  final List<TagReference> _selectedTagReferences = <TagReference>[];
  bool _mediaUploading = false;

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
      _titleController.text = decoded.hadMarker ? decoded.cleanTitle : rawTitle;
      _communicationType = decoded.hadMarker
          ? decoded.type
          : InsCommunicationType.announcement;
      _summaryController.text = d['summary']?.toString() ?? '';
      final tagRefs = _parseTagReferences(d['tagReferences']);
      final hydrated = hydrateTextWithDisplayTags(
        d['bodyMarkdown']?.toString() ?? '',
        tagRefs,
      );
      _bodyController.text = hydrated.text;
      _selectedTagReferences.addAll(hydrated.references);
      _kind = d['kind']?.toString() ?? 'GENERAL';
      _audience = d['audience']?.toString() ?? 'PUBLIC';

      final media = d['media'];
      if (media is List) {
        for (var i = 0; i < media.length; i++) {
          final item = media[i];
          if (item is! Map) continue;
          final mediaId = item['id']?.toString().trim() ?? '';
          if (mediaId.isEmpty) continue;
          _attachments.add(
            Attachment(
              localId: 'existing_$mediaId',
              kind: _attachmentKindFromServerType(item['type']?.toString()),
              source: AttachmentSource.upload,
              fileName: (item['caption']?.toString().trim().isNotEmpty ?? false)
                  ? item['caption'].toString()
                  : 'Attached media ${i + 1}',
              mimeType: null,
              mediaId: mediaId,
              url: item['url']?.toString(),
              thumbUrl: item['thumbUrl']?.toString(),
              uploading: false,
            ),
          );
        }
      }
    }
    _savedId = widget.announcementId;
  }

  AttachmentKind _attachmentKindFromServerType(String? type) {
    switch ((type ?? '').toUpperCase()) {
      case 'VIDEO':
        return AttachmentKind.video;
      case 'AUDIO':
        return AttachmentKind.audio;
      case 'DOCUMENT':
        return AttachmentKind.document;
      case 'IMAGE':
      default:
        return AttachmentKind.image;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _bodyController.dispose();
    _bodyFocus.dispose();
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

  void _rememberSelectedTag(TagReference reference) {
    if (!reference.isMention) return;
    final id = reference.durableEntityId;
    final sourceText = reference.durableSourceText;
    if (id.isEmpty || sourceText.isEmpty) return;
    _selectedTagReferences.removeWhere(
      (existing) =>
          existing.kind == reference.kind && existing.durableEntityId == id,
    );
    _selectedTagReferences.add(reference);
  }

  List<Map<String, dynamic>> _currentMentionPayload() {
    final text = _bodyController.text;
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final reference in _selectedTagReferences) {
      if (!reference.isMention) continue;
      if (!text.contains(reference.durableSourceText)) continue;
      final key = '${reference.kind.name}:${reference.durableEntityId}';
      if (!seen.add(key)) continue;
      out.add(reference.toJson());
    }
    return out;
  }

  List<TagReference> _parseTagReferences(Object? raw) {
    if (raw is! List) return const <TagReference>[];
    final out = <TagReference>[];
    for (final item in raw) {
      if (item is Map) {
        out.add(TagReference.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    return out;
  }

  Future<void> _pickMedia() async {
    if (_saving || _publishing || _mediaUploading) return;

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const [
        'png',
        'jpg',
        'jpeg',
        'webp',
        'gif',
        'mp4',
        'mov',
        'webm',
      ],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final picked = <Attachment>[];
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) continue;
      final mime =
          inferMimeFromFileName(file.name) ?? 'application/octet-stream';
      picked.add(
        Attachment(
          localId:
              '${DateTime.now().microsecondsSinceEpoch}_${file.name}_${picked.length}',
          kind: kindFromMime(mime),
          source: AttachmentSource.gallery,
          fileName: file.name,
          bytes: bytes,
          mimeType: mime,
          sizeBytes: bytes.length,
          uploading: true,
        ),
      );
    }

    if (picked.isEmpty) return;

    setState(() {
      _attachments.addAll(picked);
      _mediaUploading = true;
      _error = null;
    });

    for (final attachment in picked) {
      await _uploadAttachment(attachment);
    }

    if (!mounted) return;
    setState(() {
      _mediaUploading = _attachments.any((item) => item.uploading);
    });
  }

  Future<void> _uploadAttachment(Attachment attachment) async {
    try {
      final result = await uploadAuraMedia(
        dio: ref.read(dioProvider),
        bytes: attachment.bytes ?? Uint8List(0),
        fileName: attachment.fileName ?? '',
        mimeType: attachment.mimeType ?? '',
        kind: wireKind(attachment.kind),
        source: wireSource(attachment.source),
        metadataPatch: const <String, dynamic>{'caption': null},
      );

      if (!mounted) return;
      setState(() {
        attachment.mediaId = result.mediaId;
        attachment.url = result.url.isNotEmpty ? result.url : null;
        attachment.thumbUrl = result.thumbUrl.isNotEmpty
            ? result.thumbUrl
            : null;
        attachment.storageKey = result.storageKey.isNotEmpty
            ? result.storageKey
            : null;
        attachment.uploading = false;
        attachment.error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        attachment.uploading = false;
        attachment.error = e.toString();
      });
    }
  }

  void _removeAttachment(Attachment attachment) {
    setState(() {
      _attachments.removeWhere((item) => item.localId == attachment.localId);
      _mediaUploading = _attachments.any((item) => item.uploading);
    });
  }

  /// Collect server-issued mediaIds from successfully-uploaded items.
  /// Excludes still-uploading items (no mediaId yet) and errored items.
  List<String> _collectMediaIds() {
    return _attachments
        .where(
          (a) => !a.uploading && (a.error == null || a.error!.trim().isEmpty),
        )
        .map((a) => (a.mediaId ?? '').trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
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
    final firstLine = body
        .split('\n')
        .firstWhere((l) => l.trim().isNotEmpty, orElse: () => '')
        .trim();
    if (firstLine.isEmpty) return '';
    return firstLine.length > 80
        ? firstLine.substring(0, 80).trim()
        : firstLine;
  }

  Future<String?> _save() async {
    final cleanTitle = _resolvedCleanTitle();
    final summary = _summaryController.text.trim();
    final body = _bodyController.text.trim();

    if (cleanTitle.isEmpty && body.isEmpty) {
      setState(() => _error = 'Title or body is required.');
      return null;
    }
    if (summary.isEmpty) {
      setState(() => _error = 'Summary is required.');
      return null;
    }
    if (body.isEmpty) {
      setState(() => _error = 'Body is required.');
      return null;
    }

    if (_mediaUploading || _attachments.any((a) => a.uploading)) {
      setState(
        () => _error = 'Wait for media uploads to finish before saving.',
      );
      return null;
    }
    final failed = _attachments
        .where(
          (a) => (a.error ?? '').trim().isNotEmpty && (a.mediaId ?? '').isEmpty,
        )
        .toList(growable: false);
    if (failed.isNotEmpty) {
      setState(
        () => _error = 'Remove or retry the failed media before saving.',
      );
      return null;
    }

    final encodedTitle = InsCommunicationDecoded.encode(
      type: _communicationType,
      cleanTitle: cleanTitle,
    );
    final mediaIds = _collectMediaIds();
    final tagReferences = _currentMentionPayload();

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (_savedId == null) {
        final result = await _repo.createInstitutionAnnouncement(
          widget.institutionId,
          title: encodedTitle,
          summary: summary,
          bodyMarkdown: body,
          kind: _kind,
          audience: _audience,
          mediaIds: mediaIds,
          tagReferences: tagReferences,
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
          mediaIds: mediaIds,
          tagReferences: tagReferences,
        );
      }
      setState(() {
        _saving = false;
      });
      return _savedId;
    } catch (e) {
      setState(() {
        _error = _message(e, 'Could not save.');
        _saving = false;
      });
      return null;
    }
  }

  Future<void> _saveAndPublish() async {
    setState(() {
      _publishing = true;
      _error = null;
    });
    try {
      final id = await _save();
      if (id == null) {
        setState(() => _publishing = false);
        return;
      }
      await _repo.publishInstitutionAnnouncement(widget.institutionId, id);
      if (!mounted) return;
      _showAudienceToast(published: true);
      context.pop(true);
    } catch (e) {
      setState(() {
        _error = _message(e, 'Could not publish.');
        _publishing = false;
      });
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
    final headline = published ? 'Announcement published' : 'Draft saved';
    messenger.showSnackBar(
      SnackBar(
        content: Text('$headline · $reach'),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildMediaCard({required bool disabled}) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Media',
            style: AuraText.body.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AuraSpace.s8),
          AuraSecondaryButton(
            label: _mediaUploading ? 'Uploading…' : 'Add image or video',
            icon: Icons.attach_file,
            onPressed: (disabled || _mediaUploading) ? null : _pickMedia,
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(
            'Attach images or videos to this announcement. PUBLIC audience uses public delivery; MEMBERS or INTERNAL audience routes media through the signed-URL access gate automatically.',
            style: AuraText.small.copyWith(color: AuraSurface.muted),
          ),
          if (_attachments.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s12),
            ..._attachments.map(
              (attachment) => Container(
                margin: const EdgeInsets.only(bottom: AuraSpace.s8),
                padding: const EdgeInsets.all(AuraSpace.s12),
                decoration: BoxDecoration(
                  color: AuraSurface.subtle,
                  borderRadius: BorderRadius.circular(AuraRadius.md),
                  border: Border.all(color: AuraSurface.divider),
                ),
                child: Row(
                  children: [
                    Icon(
                      attachment.isVideo
                          ? Icons.videocam_outlined
                          : Icons.image_outlined,
                      size: 18,
                      color: AuraSurface.muted,
                    ),
                    const SizedBox(width: AuraSpace.s10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            attachment.fileName ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AuraText.small.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            attachment.uploading
                                ? 'Uploading…'
                                : ((attachment.error ?? '').trim().isNotEmpty
                                      ? attachment.error!
                                      : 'Ready'),
                            style: AuraText.micro.copyWith(
                              color: (attachment.error ?? '').trim().isNotEmpty
                                  ? AuraSurface.coRose
                                  : AuraSurface.faint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: disabled
                          ? null
                          : () => _removeAttachment(attachment),
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Remove',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDropdownRow(
    String label,
    String value,
    List<String> options,
    void Function(String) onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: AuraText.small.copyWith(
              color: AuraSurface.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            items: options
                .map(
                  (o) => DropdownMenuItem(
                    value: o,
                    child: Text(
                      o[0] + o.substring(1).toLowerCase(),
                      style: AuraText.small,
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => onChanged(v));
            },
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
                          child: Icon(
                            Icons.arrow_back_rounded,
                            size: 20,
                            color: AuraSurface.muted,
                          ),
                        ),
                      ),
                      const SizedBox(width: AuraSpace.s12),
                      Expanded(
                        child: InsModeHeader(
                          title: widget.isEditing
                              ? 'Edit announcement'
                              : 'New announcement',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AuraSpace.s12),
                  _AnnouncementCommunicationTypePicker(
                    selected: _communicationType,
                    onChanged: (t) => setState(() => _communicationType = t),
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
                          style: AuraText.body.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                          decoration: const InputDecoration(
                            labelText:
                                'Title (optional — derived from body if empty)',
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
                            hintText:
                                'One or two sentences summarising the announcement',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                        const Divider(color: AuraSurface.divider),
                        const SizedBox(height: AuraSpace.s8),
                        // AXR-1 — governed @/# autocomplete in announcements.
                        GovernedTagAutocomplete(
                          controller: _bodyController,
                          focusNode: _bodyFocus,
                          onTagSelected: _rememberSelectedTag,
                          child: TextFormField(
                            controller: _bodyController,
                            focusNode: _bodyFocus,
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
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AuraSpace.s16),
                  _buildMediaCard(disabled: isBusy),
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
                        _buildDropdownRow(
                          'Kind',
                          _kind,
                          _kinds,
                          (v) => _kind = v,
                        ),
                        const SizedBox(height: AuraSpace.s8),
                        _buildDropdownRow(
                          'Audience',
                          _audience,
                          _audiences,
                          (v) => _audience = v,
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AuraSpace.s12),
                    Container(
                      padding: const EdgeInsets.all(AuraSpace.s12),
                      decoration: BoxDecoration(
                        color: AuraSurface.coRose.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(AuraRadius.md),
                        border: Border.all(
                          color: AuraSurface.coRose.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 16,
                            color: AuraSurface.coRose,
                          ),
                          const SizedBox(width: AuraSpace.s8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: AuraText.small.copyWith(
                                color: AuraSurface.coRose,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _error = null),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: AuraSurface.coRose,
                            ),
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
