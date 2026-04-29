import 'package:flutter/material.dart';

const Map<String, String> kTranslationLanguageLabels = {
  'en': 'English',
  'ur': 'Urdu',
  'ar': 'Arabic',
  'es': 'Spanish',
  'fr': 'French',
  'de': 'German',
  'it': 'Italian',
  'pt': 'Portuguese',
  'tr': 'Turkish',
  'fa': 'Persian',
  'hi': 'Hindi',
  'bn': 'Bengali',
  'zh': 'Chinese',
  'ja': 'Japanese',
  'ko': 'Korean',
  'ru': 'Russian',
};

String languageLabel(String code) {
  final key = code.trim().toLowerCase();
  return kTranslationLanguageLabels[key] ?? key.toUpperCase();
}

String defaultTranslationLanguage(BuildContext context) {
  final code = Localizations.localeOf(
    context,
  ).languageCode.trim().toLowerCase();
  if (kTranslationLanguageLabels.containsKey(code)) return code;
  return 'en';
}

bool hasRtlScript(String text) {
  final value = text.trim();
  if (value.isEmpty) return false;
  final rtl = RegExp(
    r'[֐-׿؀-ۿݐ-ݿࢠ-ࣿﭐ-﷿ﹰ-﻿]',
  );
  return rtl.hasMatch(value);
}

TextDirection directionForText(String text) {
  return hasRtlScript(text) ? TextDirection.rtl : TextDirection.ltr;
}

TextAlign alignForText(String text) {
  return hasRtlScript(text) ? TextAlign.right : TextAlign.left;
}

// ─── Primitive pickers ───────────────────────────────────────────────────────

String pickString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = (map[key] ?? '').toString().trim();
    if (value.isNotEmpty) return value;
  }
  return '';
}

String pickNested(Map<String, dynamic> map, List<List<String>> paths) {
  for (final path in paths) {
    dynamic current = map;
    for (final key in path) {
      if (current is! Map) {
        current = null;
        break;
      }
      current = current[key];
    }
    final text = (current ?? '').toString().trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}

int? pickInt(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is int) return value;
    final parsed = int.tryParse('${value ?? ''}');
    if (parsed != null) return parsed;
  }
  return null;
}

String pickDeepString(
  Map<String, dynamic> map,
  List<List<String>> paths, {
  String fallback = '',
}) {
  for (final path in paths) {
    final value = _valueAtPath(map, path);
    final text = _str(value);
    if (text.isNotEmpty) return text;
  }
  return fallback;
}

String firstNonEmpty(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = _str(map[key]);
    if (value.isNotEmpty) return value;
  }
  return '';
}

// ─── Map / list helpers ──────────────────────────────────────────────────────

Map<String, dynamic> asMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> listOfMap(dynamic raw) {
  if (raw is! List) return const [];
  return raw.map((e) => asMap(e)).toList();
}

List<Map<String, dynamic>> extractFindings(Map<String, dynamic> root) {
  for (final path in const [
    ['findings'],
    ['review', 'findings'],
    ['data', 'findings'],
    ['result', 'findings'],
    ['items'],
    ['data', 'items'],
  ]) {
    final value = _valueAtPath(root, path);
    if (value is List) {
      return value.map(asMap).where((item) {
        final id = firstNonEmpty(item, const ['id', 'findingId']);
        final message = firstNonEmpty(item, const [
          'message',
          'title',
          'finding',
        ]);
        final detail = firstNonEmpty(item, const [
          'suggestion',
          'detail',
          'description',
        ]);
        return id.isNotEmpty || message.isNotEmpty || detail.isNotEmpty;
      }).toList();
    }
  }
  return const [];
}

// ─── Message / sender helpers ─────────────────────────────────────────────────

Map<String, dynamic> extractAuthorMap(Map<String, dynamic> message) {
  const keys = ['author', 'sender', 'user', 'member', 'profile', 'createdBy'];
  for (final key in keys) {
    final value = message[key];
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
  }
  return const <String, dynamic>{};
}

String extractSenderId(Map<String, dynamic> message) {
  final direct = pickString(message, const [
    'authorId',
    'senderId',
    'userId',
    'createdById',
    'memberId',
  ]);
  if (direct.isNotEmpty) return direct;

  final author = extractAuthorMap(message);
  if (author.isEmpty) return '';
  return pickString(author, const ['id', '_id', 'userId', 'memberId']);
}

bool isSameSender(
  Map<String, dynamic> current,
  Map<String, dynamic>? previous,
) {
  if (previous == null) return false;
  final currentSender = extractSenderId(current).trim();
  final previousSender = extractSenderId(previous).trim();
  if (currentSender.isEmpty || previousSender.isEmpty) return false;
  return currentSender == previousSender;
}

// ─── Attachment URL helpers ───────────────────────────────────────────────────

String resolveAttachmentUrl(Map<String, dynamic> attachment) {
  return pickString(attachment, const [
    'displayUrl',
    'playbackUrl',
    'url',
    'publicUrl',
    'signedUrl',
    'sourceUrl',
    'fileUrl',
    'href',
    'src',
    'downloadUrl',
    'originalUrl',
  ]);
}

String resolveAttachmentThumbUrl(Map<String, dynamic> attachment) {
  return pickString(attachment, const [
    'thumbnailUrl',
    'thumbUrl',
    'previewUrl',
    'posterUrl',
    'displayUrl',
    'publicUrl',
    'signedUrl',
    'url',
  ]);
}

// ─── Formatting helpers ───────────────────────────────────────────────────────

String formatMessageTimestamp(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return '';

  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;

  final local = parsed.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final targetDay = DateTime(local.year, local.month, local.day);
  final diffDays = today.difference(targetDay).inDays;

  String formatTime(DateTime dt) {
    final hour = dt.hour == 0
        ? 12
        : dt.hour > 12
        ? dt.hour - 12
        : dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  if (diffDays == 0) return formatTime(local);
  if (diffDays == 1) return 'Yesterday';
  if (diffDays > 1 && diffDays < 7) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[local.weekday - 1];
  }

  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[local.month - 1]} ${local.day}';
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
  final gb = mb / 1024;
  return '${gb.toStringAsFixed(gb >= 100 ? 0 : 1)} GB';
}

// ─── Attachment kind ─────────────────────────────────────────────────────────

enum ThreadAttachmentKind { image, video, audio, document }

ThreadAttachmentKind kindFromMime(String mime) {
  final lower = mime.toLowerCase();
  if (lower.startsWith('image/')) { return ThreadAttachmentKind.image; }
  if (lower.startsWith('video/')) { return ThreadAttachmentKind.video; }
  if (lower.startsWith('audio/')) { return ThreadAttachmentKind.audio; }
  if (lower == 'application/pdf') { return ThreadAttachmentKind.document; }
  if (lower.startsWith('application/vnd.')) { return ThreadAttachmentKind.document; }
  if (lower.startsWith('application/msword')) { return ThreadAttachmentKind.document; }
  if (lower == 'application/rtf') { return ThreadAttachmentKind.document; }
  if (lower.startsWith('text/')) { return ThreadAttachmentKind.document; }
  if (lower == 'application/zip' ||
      lower == 'application/x-zip-compressed') {
    return ThreadAttachmentKind.document;
  }
  if (lower.startsWith('application/')) { return ThreadAttachmentKind.document; }
  return ThreadAttachmentKind.document;
}

// ─── Response unwrapping ─────────────────────────────────────────────────────

Map<String, dynamic> unwrapDataMap(dynamic raw) {
  if (raw is Map) {
    final map = Map<String, dynamic>.from(raw);
    final data = map['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return map;
  }
  return <String, dynamic>{};
}

// ─── Internal helpers (not exported in name, but top-level) ──────────────────

dynamic _valueAtPath(Map<String, dynamic> map, List<String> path) {
  dynamic current = map;
  for (final segment in path) {
    if (current is! Map) return null;
    current = current[segment];
  }
  return current;
}

String _str(dynamic value) => (value ?? '').toString().trim();
