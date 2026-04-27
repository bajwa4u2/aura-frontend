import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENUMS
// ─────────────────────────────────────────────────────────────────────────────

enum PostVisibility { public, followers, private }

enum ComposeAttachmentType { image, video }

enum ComposeAttachmentSource { camera, gallery }

// ─────────────────────────────────────────────────────────────────────────────
// LANGUAGE CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

const Map<String, String> kComposeLanguageLabels = {
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

String composeLanguageLabel(String code) {
  final key = code.trim().toLowerCase();
  if (key.isEmpty) return '';
  return kComposeLanguageLabels[key] ?? key.toUpperCase();
}

// ─────────────────────────────────────────────────────────────────────────────
// ATTACHMENT MODEL
// ─────────────────────────────────────────────────────────────────────────────

class ComposeAttachment {
  ComposeAttachment({
    required this.localId,
    required this.type,
    required this.source,
    required this.captionController,
    this.localFile,
    this.localBytes,
    this.width,
    this.height,
    this.durationMs,
    this.mediaId,
    this.url,
    this.thumbUrl,
    this.uploading = false,
    this.attachedToDraft = false,
  });

  final String localId;
  final ComposeAttachmentType type;
  final ComposeAttachmentSource source;
  final TextEditingController captionController;

  XFile? localFile;
  Uint8List? localBytes;

  int? width;
  int? height;
  int? durationMs;

  String? mediaId;
  String? url;
  String? thumbUrl;

  bool uploading;
  bool attachedToDraft;
  String? error;

  bool get isImage => type == ComposeAttachmentType.image;
  bool get isVideo => type == ComposeAttachmentType.video;
  bool get isUploaded => (mediaId ?? '').trim().isNotEmpty;

  void dispose() {
    captionController.dispose();
  }
}
