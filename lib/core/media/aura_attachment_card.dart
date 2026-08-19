/// AURA ATTACHMENT CARD — F011.
///
/// THE DEFECT THIS REPLACES. Every attachment that was not an image, a voice
/// note or a video rendered as `_fileChip('Attachment')`: a grey pill with a
/// generic paperclip icon, the literal word "Attachment", and nothing else. No
/// file name. No type. No size. No tap target. A PDF, a spreadsheet, a
/// presentation and a zip archive were indistinguishable from one another and
/// from a failure state, and none of them could be opened from the message.
///
/// The backend already knew what each file was — CH-11's content-truth
/// authority resolves the real type from the bytes, correcting the client's
/// claim where it lied. That truth simply never reached the surface. F011 is
/// the presentation half: THE RESOLVED ATTACHMENT KIND MUST BE PRESENTED
/// HONESTLY AND WITH THE ACTIONS APPROPRIATE TO THAT KIND.
///
/// WHAT THIS DOES NOT DO. It does not decide what a file IS — that is CH-11's
/// authority and this widget only consumes the resolved values. It renders no
/// document content and no thumbnail of its own: presenting a preview it
/// cannot verify would be the same dishonesty in a nicer shape.
library;

import 'package:flutter/material.dart';

import '../ui/aura_radius.dart';
import '../ui/aura_space.dart';
import '../ui/aura_surface.dart';
import '../ui/aura_text.dart';

/// The presentation kinds an attachment can take. Derived from the canonical
/// resolved MIME, never from a file extension — an extension is a claim and
/// content truth already corrected it.
enum AttachmentPresentationKind {
  image,
  video,
  audio,
  pdf,
  document,
  spreadsheet,
  presentation,
  archive,
  text,
  unknown,
}

extension AttachmentPresentationKindX on AttachmentPresentationKind {
  IconData get icon => switch (this) {
        AttachmentPresentationKind.image => Icons.image_outlined,
        AttachmentPresentationKind.video => Icons.movie_outlined,
        AttachmentPresentationKind.audio => Icons.graphic_eq_rounded,
        AttachmentPresentationKind.pdf => Icons.picture_as_pdf_outlined,
        AttachmentPresentationKind.document => Icons.description_outlined,
        AttachmentPresentationKind.spreadsheet => Icons.table_chart_outlined,
        AttachmentPresentationKind.presentation => Icons.slideshow_outlined,
        AttachmentPresentationKind.archive => Icons.folder_zip_outlined,
        AttachmentPresentationKind.text => Icons.notes_rounded,
        AttachmentPresentationKind.unknown => Icons.insert_drive_file_outlined,
      };

  /// Short, human, honest. Never the raw MIME string — a person should not
  /// have to read `application/vnd.openxmlformats-officedocument…` to learn
  /// they were sent a slide deck.
  String get label => switch (this) {
        AttachmentPresentationKind.image => 'Image',
        AttachmentPresentationKind.video => 'Video',
        AttachmentPresentationKind.audio => 'Audio',
        AttachmentPresentationKind.pdf => 'PDF document',
        AttachmentPresentationKind.document => 'Document',
        AttachmentPresentationKind.spreadsheet => 'Spreadsheet',
        AttachmentPresentationKind.presentation => 'Presentation',
        AttachmentPresentationKind.archive => 'Archive',
        AttachmentPresentationKind.text => 'Text file',
        // Deliberately not "Attachment": the honest statement is that the
        // product does not recognise this kind, not that it is a generic thing.
        AttachmentPresentationKind.unknown => 'File',
      };

  /// The verb offered for this kind. An archive cannot be previewed in-app, so
  /// promising to "open" it would be a false offer.
  String get actionLabel => switch (this) {
        AttachmentPresentationKind.archive => 'Download',
        AttachmentPresentationKind.unknown => 'Download',
        _ => 'Open',
      };
}

/// Resolve a presentation kind from the canonical resolved MIME and kind.
///
/// The MIME wins. `kind` is the coarse canonical enum (IMAGE/VIDEO/AUDIO/
/// OTHER) and cannot distinguish a PDF from a zip — both are OTHER — which is
/// exactly why every document collapsed into one pill.
AttachmentPresentationKind attachmentKindFrom({
  String? mimeType,
  String? canonicalKind,
}) {
  final m = (mimeType ?? '').trim().toLowerCase();

  if (m.startsWith('image/')) return AttachmentPresentationKind.image;
  if (m.startsWith('video/')) return AttachmentPresentationKind.video;
  if (m.startsWith('audio/')) return AttachmentPresentationKind.audio;

  if (m == 'application/pdf') return AttachmentPresentationKind.pdf;

  if (m == 'application/msword' ||
      m == 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' ||
      m == 'application/rtf') {
    return AttachmentPresentationKind.document;
  }
  if (m == 'application/vnd.ms-excel' ||
      m == 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet') {
    return AttachmentPresentationKind.spreadsheet;
  }
  if (m == 'application/vnd.ms-powerpoint' ||
      m == 'application/vnd.openxmlformats-officedocument.presentationml.presentation') {
    return AttachmentPresentationKind.presentation;
  }
  if (m == 'application/zip' || m == 'application/x-zip-compressed') {
    return AttachmentPresentationKind.archive;
  }
  if (m == 'text/plain' || m == 'text/csv') {
    return AttachmentPresentationKind.text;
  }

  // Fall back to the coarse canonical kind only when the MIME says nothing.
  switch ((canonicalKind ?? '').toUpperCase()) {
    case 'IMAGE':
      return AttachmentPresentationKind.image;
    case 'VIDEO':
      return AttachmentPresentationKind.video;
    case 'AUDIO':
      return AttachmentPresentationKind.audio;
  }
  return AttachmentPresentationKind.unknown;
}

/// Human file size. Returns null when the size is genuinely unknown, so the
/// caller omits it rather than printing a confident "0 B".
String? humanFileSize(int? bytes) {
  if (bytes == null || bytes <= 0) return null;
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final rounded = unit == 0 || value >= 100
      ? value.round().toString()
      : value.toStringAsFixed(1);
  return '$rounded ${units[unit]}';
}

/// A non-visual attachment presented with its real identity and its action.
class AuraAttachmentCard extends StatelessWidget {
  const AuraAttachmentCard({
    super.key,
    required this.kind,
    this.fileName,
    this.sizeBytes,
    this.onOpen,
    this.unavailableReason,
  });

  final AttachmentPresentationKind kind;
  final String? fileName;
  final int? sizeBytes;

  /// Null when the file cannot be opened — the action is then omitted rather
  /// than rendered dead. A button that does nothing is worse than no button.
  final VoidCallback? onOpen;

  /// When set, the card states plainly that the attachment is unavailable
  /// instead of offering an action that cannot succeed.
  final String? unavailableReason;

  @override
  Widget build(BuildContext context) {
    final unavailable = unavailableReason != null;
    final name = (fileName ?? '').trim();
    final size = humanFileSize(sizeBytes);

    // Type first, then size — the two facts a person needs before deciding
    // whether to open something. Joined only when both are known.
    final meta = <String>[
      if (unavailable) unavailableReason! else kind.label,
      if (size != null && !unavailable) size,
    ].join(' · ');

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Material(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AuraRadius.card),
          onTap: unavailable ? null : onOpen,
          child: Padding(
            padding: const EdgeInsets.all(AuraSpace.s12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AuraSurface.card,
                    borderRadius: BorderRadius.circular(AuraRadius.card),
                  ),
                  child: Icon(
                    unavailable ? Icons.error_outline_rounded : kind.icon,
                    size: 20,
                    color: unavailable ? AuraSurface.muted : AuraSurface.accentText,
                  ),
                ),
                const SizedBox(width: AuraSpace.s10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        // The file's own name is its identity. Only when it is
                        // genuinely absent do we fall back to the kind.
                        name.isNotEmpty ? name : kind.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AuraText.small.copyWith(
                          color: AuraSurface.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AuraText.micro.copyWith(color: AuraSurface.muted),
                      ),
                    ],
                  ),
                ),
                if (!unavailable && onOpen != null) ...[
                  const SizedBox(width: AuraSpace.s8),
                  Text(
                    kind.actionLabel,
                    style: AuraText.micro.copyWith(
                      color: AuraSurface.accentText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
