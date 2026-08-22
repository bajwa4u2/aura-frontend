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

/// Item 14 — presentation-routing hint only, mirroring the backend's
/// `isInternalAuraUrl` host check against the same two hosts this file
/// already knows about. NOT a security boundary: the real authorization
/// decision always happens server-side in `InternalReferenceService` on
/// every resolve. A wrong guess here only affects which widget a link
/// renders with, never what data it can expose.
bool isInternalAuraUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || uri.host.isEmpty) return false;
  final host = uri.host.toLowerCase();
  final internalHosts = {
    Uri.parse(_kAuraShareBaseUrl).host.toLowerCase(),
    Uri.parse(_kAuraWebBaseUrl).host.toLowerCase(),
  };
  return internalHosts.contains(host);
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

/// External share URL for an article (by slug).
///
/// `/p/art/` rather than `/p/a/`, which announcements hold. This is the only
/// address that produces a real preview card: the SPA host serves no
/// crawler-readable metadata, so sharing an in-app `/articles/...` link shows
/// the generic Aura homepage card instead of the author's own title and cover.
String canonicalArticleUrl(String slug) {
  return '${_trimSlash(_kAuraShareBaseUrl)}/p/art/${Uri.encodeComponent(slug)}';
}

/// External share URL for a person's profile (by handle).
///
/// Mirrors the server's `PERSON_PROFILE` share definition. Person and
/// institution profiles had crawler markup for months that no crawler could
/// reach, because only `/p/` is proxied by the marketing host — these helpers
/// exist so no surface ever again invents its own address for a profile.
String canonicalPersonProfileUrl(String handle) {
  return '${_trimSlash(_kAuraShareBaseUrl)}/p/u/${Uri.encodeComponent(handle)}';
}

/// External share URL for an institution profile (by slug).
String canonicalInstitutionProfileUrl(String slug) {
  return '${_trimSlash(_kAuraShareBaseUrl)}/p/org/${Uri.encodeComponent(slug)}';
}

/// External share URL for a PUBLIC meeting (by meeting code).
///
/// The server publishes a card only for meetings whose visibility is genuinely
/// PUBLIC; anything else renders the safe unavailable page. The link still
/// works either way — only its subject is withheld from crawlers.
String canonicalMeetingUrl(String meetingCode) {
  return '${_trimSlash(_kAuraShareBaseUrl)}/p/m/${Uri.encodeComponent(meetingCode)}';
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
