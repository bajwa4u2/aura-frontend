import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

const String _kAuraWebBaseUrl = String.fromEnvironment(
  'AURA_WEB_BASE_URL',
  defaultValue: 'https://app.auraplatform.org',
);

String canonicalPostUrl(String postId) {
  var base = _kAuraWebBaseUrl.trim();
  if (base.endsWith('/')) base = base.substring(0, base.length - 1);
  return '$base/posts/$postId';
}

String linkedInShareUrl(String postUrl) {
  final u = Uri.encodeComponent(postUrl);
  return 'https://www.linkedin.com/sharing/share-offsite/?url=$u';
}

String emailShareUrl(String postUrl) {
  final subject = Uri.encodeComponent('Aura post');
  final body = Uri.encodeComponent(postUrl);
  return 'mailto:?subject=$subject&body=$body';
}

Future<void> copyToClipboard(
  BuildContext context,
  String value, {
  required String message,
}) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<void> openExternalUrl(
  BuildContext context,
  String rawUrl, {
  String fallbackCopyMessage = 'Link copied',
}) async {
  final trimmed = rawUrl.trim();
  if (trimmed.isEmpty) return;

  Uri? uri = Uri.tryParse(trimmed);
  if (uri == null) {
    await copyToClipboard(context, trimmed, message: fallbackCopyMessage);
    return;
  }

  if (!uri.hasScheme) {
    uri = Uri.tryParse('https://$trimmed');
  }

  if (uri == null) {
    await copyToClipboard(context, trimmed, message: fallbackCopyMessage);
    return;
  }

  try {
    final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);

    if (!launched) {
      if (!context.mounted) return;
      await copyToClipboard(context, trimmed, message: fallbackCopyMessage);
    }
  } catch (_) {
    if (!context.mounted) return;
    await copyToClipboard(context, trimmed, message: fallbackCopyMessage);
  }
}
