import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Marketing/public host that owns the crawler-friendly share URLs
/// (`auraplatform.org/p/...`). Nginx on that host proxies `/p/*` to the
/// NestJS share controller, which renders an OG-rich HTML page and
/// bounces humans into the workspace SPA via meta-refresh. Override at
/// build time with `--dart-define=AURA_SHARE_BASE_URL=...` for staging
/// or alternate hosts.
const String _kAuraShareBaseUrl = String.fromEnvironment(
  'AURA_SHARE_BASE_URL',
  defaultValue: 'https://auraplatform.org',
);

/// Workspace host (Flutter SPA) where humans land after the redirect.
/// Used for internal in-app navigation and for legacy deep-link logic.
/// NOT used for externally shared URLs because the SPA host has no
/// crawler-readable OG metadata.
const String _kAuraWebBaseUrl = String.fromEnvironment(
  'AURA_WEB_BASE_URL',
  defaultValue: 'https://app.auraplatform.org',
);

String _trimSlash(String url) {
  var s = url.trim();
  if (s.endsWith('/')) s = s.substring(0, s.length - 1);
  return s;
}

/// External (crawler-friendly) share URL for a user post. This is the
/// URL we copy / surface in Share sheets / send to LinkedIn / Twitter /
/// Discord / Slack / Facebook. Crawlers fetch this URL and read OG
/// metadata; humans get redirected into the SPA.
String canonicalPostUrl(String postId) {
  return '${_trimSlash(_kAuraShareBaseUrl)}/p/${Uri.encodeComponent(postId)}';
}

/// External share URL for an institution post.
String canonicalInstitutionPostUrl(String institutionId, String postId) {
  final base = _trimSlash(_kAuraShareBaseUrl);
  final inst = Uri.encodeComponent(institutionId);
  final post = Uri.encodeComponent(postId);
  return '$base/p/i/$inst/$post';
}

/// External share URL for an announcement (by slug).
String canonicalAnnouncementUrl(String slug) {
  return '${_trimSlash(_kAuraShareBaseUrl)}/p/a/${Uri.encodeComponent(slug)}';
}

/// In-app deep-link for a user post. Use this when navigating WITHIN
/// the Flutter app, not for externally shared URLs.
String appPostUrl(String postId) {
  return '${_trimSlash(_kAuraWebBaseUrl)}/posts/${Uri.encodeComponent(postId)}';
}

String linkedInShareUrl(String postUrl) {
  final u = Uri.encodeComponent(postUrl);
  return 'https://www.linkedin.com/sharing/share-offsite/?url=$u';
}

String emailShareUrl(String postUrl, {String subject = 'Aura post'}) {
  final s = Uri.encodeComponent(subject);
  final body = Uri.encodeComponent(postUrl);
  return 'mailto:?subject=$s&body=$body';
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
