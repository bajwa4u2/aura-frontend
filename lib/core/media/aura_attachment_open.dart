/// OPEN A NON-VISUAL ATTACHMENT — F011.
///
/// Images, video and voice notes are presented in-product: the canonical
/// viewer and the playback control. Documents, spreadsheets, presentations,
/// archives and unrecognised files are not renderable in-app, and pretending
/// otherwise is how the generic "Attachment" pill came about — a surface that
/// showed nothing and did nothing.
///
/// The honest action for those kinds is to hand the file to the platform,
/// which knows how to open a PDF or save an archive. This helper is the single
/// place that happens, so every surface offers the same behaviour and reports
/// the same failure.
///
/// FAILURE IS VISIBLE. If the file cannot be handed off, the person is told.
/// A silent no-op is what made the old chip feel broken.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:aura/core/ui/aura_notice.dart';

Future<void> openAuraAttachment(
  BuildContext context, {
  required String url,
}) async {
  final messenger = AuraNotice.of(context);
  final uri = Uri.tryParse(url);

  if (uri == null || url.trim().isEmpty) {
    _tell(messenger, 'This attachment could not be opened.');
    return;
  }

  try {
    // externalApplication hands the file to the OS/browser, which is what a
    // person expects of a document. On web this opens a new tab; on mobile it
    // reaches the system handler for that type.
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) _tell(messenger, 'No app on this device can open this file.');
  } catch (_) {
    _tell(messenger, 'This attachment could not be opened.');
  }
}

void _tell(AuraNoticeHandle notice, String message) => notice.problem(message);
