import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_surface.dart';
import '../../application/meetings_provider.dart';
import '../../domain/meeting_asset.dart';
import 'meeting_section.dart';

/// One asset surface for the whole lifecycle. The same widget renders
/// "Materials" (preparation briefing pack), "Shared in meeting" files, and
/// "Recording" — filtered views over the meeting's single asset collection.
class MeetingAssetsSection extends ConsumerStatefulWidget {
  final String meetingId;
  final String title;
  final String emptyText;

  /// Which assets this view shows.
  final bool Function(MeetingAsset asset) filter;

  /// Host-only management (add/remove/visibility).
  final bool canManage;

  /// Stage stamped on assets added through THIS section.
  final String addStage;

  /// Offer link adding / file uploading (recordings are captured, not added).
  final bool allowAdd;

  /// Hide the whole section when empty and not manageable.
  final bool hideWhenEmpty;

  const MeetingAssetsSection({
    super.key,
    required this.meetingId,
    required this.title,
    required this.emptyText,
    required this.filter,
    required this.canManage,
    this.addStage = 'PREPARATION',
    this.allowAdd = true,
    this.hideWhenEmpty = false,
  });

  @override
  ConsumerState<MeetingAssetsSection> createState() =>
      _MeetingAssetsSectionState();
}

class _MeetingAssetsSectionState extends ConsumerState<MeetingAssetsSection> {
  bool _busy = false;

  Future<void> _open(MeetingAsset asset) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final url = asset.kind == MeetingAssetKind.link
          ? asset.url
          : await ref
              .read(meetingsRepositoryProvider)
              .assetUrl(widget.meetingId, asset.id);
      if (url == null || url.isEmpty) throw Exception('no url');
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) throw Exception('launch failed');
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open this item.')),
      );
    }
  }

  Future<void> _addLink() async {
    final urlCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add a link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlCtrl,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'https://…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AuraSpace.s12),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Title (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Add link'),
          ),
        ],
      ),
    );
    final url = urlCtrl.text.trim();
    final title = titleCtrl.text.trim();
    urlCtrl.dispose();
    titleCtrl.dispose();
    if (submitted != true || url.isEmpty || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(meetingsRepositoryProvider).addAssetLink(
            widget.meetingId,
            url: url,
            title: title.isEmpty ? null : title,
            stage: widget.addStage,
          );
      ref.invalidate(meetingAssetsProvider(widget.meetingId));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not add the link.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uploadFile() async {
    final picked = await FilePicker.platform.pickFiles(withData: true);
    final file = picked?.files.firstOrNull;
    if (file == null || file.bytes == null || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(meetingsRepositoryProvider).uploadAsset(
            widget.meetingId,
            fileName: file.name,
            mimeType: _mimeFor(file.name),
            bytes: file.bytes!,
            stage: widget.addStage,
          );
      ref.invalidate(meetingAssetsProvider(widget.meetingId));
      messenger.showSnackBar(
        SnackBar(content: Text('${file.name} attached to the meeting')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Upload failed. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _mimeFor(String name) {
    final ext = name.split('.').last.toLowerCase();
    const map = {
      'pdf': 'application/pdf',
      'png': 'image/png',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'gif': 'image/gif',
      'txt': 'text/plain',
      'md': 'text/markdown',
      'csv': 'text/csv',
      'doc': 'application/msword',
      'docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'ppt': 'application/vnd.ms-powerpoint',
      'pptx':
          'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'webm': 'video/webm',
      'mp4': 'video/mp4',
      'zip': 'application/zip',
    };
    return map[ext] ?? 'application/octet-stream';
  }

  Future<void> _toggleGuests(MeetingAsset asset) async {
    try {
      await ref.read(meetingsRepositoryProvider).updateAsset(
            widget.meetingId,
            asset.id,
            visibleToGuests: !asset.visibleToGuests,
          );
      ref.invalidate(meetingAssetsProvider(widget.meetingId));
    } catch (_) {}
  }

  Future<void> _remove(MeetingAsset asset) async {
    try {
      await ref
          .read(meetingsRepositoryProvider)
          .deleteAsset(widget.meetingId, asset.id);
      ref.invalidate(meetingAssetsProvider(widget.meetingId));
    } catch (_) {}
  }

  IconData _iconFor(MeetingAsset a) {
    switch (a.kind) {
      case MeetingAssetKind.link:
        return Icons.link_rounded;
      case MeetingAssetKind.recording:
        return Icons.play_circle_outline_rounded;
      case MeetingAssetKind.file:
        return Icons.description_outlined;
    }
  }

  String _subtitle(MeetingAsset a) {
    final parts = <String>[];
    if (a.kind == MeetingAssetKind.recording) {
      final d = a.durationSeconds ?? 0;
      if (d > 0) {
        parts.add('${(d ~/ 60)}m ${(d % 60).toString().padLeft(2, '0')}s');
      }
      if (a.status == 'RECORDING') parts.add('processing');
    } else if (a.sizeBytes != null && a.sizeBytes! > 0) {
      final kb = a.sizeBytes! / 1024;
      parts.add(kb >= 1024
          ? '${(kb / 1024).toStringAsFixed(1)} MB'
          : '${kb.ceil()} KB');
    }
    parts.add('added by ${a.addedByName}');
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assetsAsync = ref.watch(meetingAssetsProvider(widget.meetingId));
    final assets =
        (assetsAsync.valueOrNull ?? const <MeetingAsset>[])
            .where(widget.filter)
            .toList();

    if (assets.isEmpty && widget.hideWhenEmpty && !widget.canManage) {
      return const SizedBox.shrink();
    }

    return MeetingSection(
      title: widget.title,
      trailing: _busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (assets.isEmpty)
            MeetingSection.emptyLine(context, widget.emptyText),
          for (final asset in assets)
            Padding(
              padding: const EdgeInsets.only(bottom: AuraSpace.s6),
              child: Row(
                children: [
                  Icon(_iconFor(asset),
                      size: 18, color: AuraSurface.accentText),
                  const SizedBox(width: AuraSpace.s10),
                  Expanded(
                    child: InkWell(
                      onTap: asset.isReady ? () => _open(asset) : null,
                      borderRadius: BorderRadius.circular(6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            asset.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _subtitle(asset),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AuraSurface.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (widget.canManage) ...[
                    IconButton(
                      tooltip: asset.visibleToGuests
                          ? 'Visible to guests — tap to restrict'
                          : 'Members only — tap to share with guests',
                      icon: Icon(
                        asset.visibleToGuests
                            ? Icons.public_rounded
                            : Icons.lock_outline_rounded,
                        size: 17,
                        color: asset.visibleToGuests
                            ? AuraSurface.goodInk
                            : AuraSurface.muted,
                      ),
                      onPressed: () => _toggleGuests(asset),
                    ),
                    IconButton(
                      tooltip: 'Remove',
                      icon: const Icon(Icons.close_rounded,
                          size: 17, color: AuraSurface.faint),
                      onPressed: () => _remove(asset),
                    ),
                  ],
                ],
              ),
            ),
          if (widget.canManage && widget.allowAdd)
            Wrap(
              spacing: AuraSpace.s8,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.add_link_rounded, size: 18),
                  label: const Text('Add link'),
                  onPressed: _busy ? null : _addLink,
                ),
                TextButton.icon(
                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                  label: const Text('Upload file'),
                  onPressed: _busy ? null : _uploadFile,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
