import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:record/record.dart';
import 'package:web/web.dart' as web;

import 'voice_note_capture.dart';

/// Web capture.
///
/// Chrome and Firefox record Opus in a WebM container, which is what the
/// composer always claimed and the one platform where the claim was true.
/// Safari supports neither opus nor WebM recording, so it gets WAV — the only
/// encoder `record` reports working in all three browsers. Larger on the wire,
/// but a voice note is short and a refusal is worse than a few hundred KB.
VoiceNoteFormat voiceNoteFormat() {
  return _isSafari
      ? const VoiceNoteFormat(
          encoder: AudioEncoder.wav,
          extension: 'wav',
          mimeType: 'audio/wav',
        )
      : const VoiceNoteFormat(
          encoder: AudioEncoder.opus,
          extension: 'webm',
          mimeType: 'audio/webm',
        );
}

/// The browser owns the destination; `record` returns a `blob:` URL from
/// `stop()` regardless of what is passed here.
Future<String> voiceNoteTargetPath(String extension) async =>
    'voice-note.$extension';

/// `stop()` hands back a `blob:` URL, which an HTTP client can read.
Future<Uint8List> readCapturedVoiceNote(String handle) async {
  final res = await Dio().get<List<int>>(
    handle,
    options: Options(responseType: ResponseType.bytes),
  );
  final bytes = Uint8List.fromList(res.data ?? const []);
  if (bytes.isEmpty) {
    throw StateError('The recording came back empty.');
  }
  return bytes;
}

/// Nothing to clean up: the blob belongs to the browser and is released with
/// the page.
Future<void> discardCapturedVoiceNote(String handle) async {}

/// Safari, including every iOS browser, which are all Safari underneath.
bool get _isSafari {
  final ua = _userAgent.toLowerCase();
  if (ua.isEmpty) return false;
  final looksLikeSafari = ua.contains('safari') &&
      !ua.contains('chrome') &&
      !ua.contains('chromium') &&
      !ua.contains('android');
  // iOS forces every browser onto WebKit, so Chrome on an iPhone records
  // under exactly Safari's constraints while calling itself CriOS.
  final isIosWebKit =
      ua.contains('iphone') || ua.contains('ipad') || ua.contains('ipod');
  return looksLikeSafari || isIosWebKit;
}

String get _userAgent {
  try {
    return web.window.navigator.userAgent;
  } catch (_) {
    // A headless or restricted context. Falling back to the non-Safari branch
    // is the right default: it is what every desktop browser needs, and a
    // wrong guess here costs a refusal we would rather not manufacture.
    return '';
  }
}
