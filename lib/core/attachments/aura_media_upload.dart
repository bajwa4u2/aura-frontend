import 'dart:typed_data';

import 'package:dio/dio.dart';

class AuraMediaUploadResult {
  const AuraMediaUploadResult({
    required this.mediaId,
    required this.storageKey,
    required this.url,
    required this.thumbUrl,
    required this.kind,
    required this.source,
    required this.raw,
  });

  final String mediaId;
  final String storageKey;
  final String url;
  final String thumbUrl;
  final String kind;
  final String source;
  final Map<String, dynamic> raw;
}

Future<AuraMediaUploadResult> uploadAuraMedia({
  required Dio dio,
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
  required String kind,
  required String source,

  /// What the content was BEFORE Aura transcoded it, when it did.
  ///
  /// Sent only when it differs from [mimeType]. A HEIC photograph re-encoded
  /// to JPEG so recipients can see it is still a HEIC photograph the person
  /// took, and the stored row must not quietly claim they attached a JPEG.
  /// The server drops it when it does not differ, so a persisted value always
  /// means a real transformation.
  String? originalMimeType,
  int? width,
  int? height,
  int? duration,

  /// WHAT THE CREATOR SAYS about this media's origin.
  ///
  /// One of `AI_GENERATED`, `AI_EDITED`, `NOT_AI`. Recorded server-side as an
  /// UPLOADER_DECLARATION — attributable to a person, and ranked beneath
  /// verified evidence, so a declaration cannot override a content credential
  /// that disagrees with it.
  ///
  /// Null means the person said nothing, which records NOTHING. "I don't know"
  /// is the absence of a claim, and a stored non-answer would make an
  /// unexamined object look examined.
  String? originDeclaration,
  Map<String, dynamic> metadataPatch = const <String, dynamic>{},
  void Function(int sent, int total)? onProgress,
}) async {
  final presign = await dio.post(
    '/media/presign',
    data: <String, dynamic>{
      'fileName': fileName,
      'mimeType': mimeType,
      'bytes': bytes.length,
      'kind': kind,
      'source': source,
      if (originalMimeType != null &&
          originalMimeType.trim().isNotEmpty &&
          originalMimeType.trim().toLowerCase() !=
              mimeType.trim().toLowerCase())
        'originalMimeType': originalMimeType.trim().toLowerCase(),
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (duration != null) 'duration': duration,
      if (originDeclaration != null && originDeclaration.trim().isNotEmpty)
        'originDeclaration': originDeclaration.trim(),
    },
  );

  final presigned = _asMap(_unwrapData(presign.data));
  final mediaMap = _asMap(presigned['media']);
  final upload = _asMap(presigned['upload']);

  final mediaId = _firstNonEmpty([
    _stringOf(mediaMap['id']),
    _stringOf(mediaMap['mediaId']),
    _stringOf(presigned['id']),
    _stringOf(presigned['mediaId']),
  ]);
  final uploadUrl = _firstNonEmpty([
    _stringOf(upload['url']),
    _stringOf(presigned['uploadUrl']),
  ]);

  if (mediaId.isEmpty || uploadUrl.isEmpty) {
    throw Exception('Media upload could not be initialized.');
  }

  final uploadHeaders = <String, String>{};
  final rawHeaders = _asMap(upload['headers']);
  rawHeaders.forEach((key, value) {
    if (value == null) return;
    uploadHeaders[key.toString()] = value.toString();
  });
  if (!uploadHeaders.containsKey('Content-Type')) {
    uploadHeaders['Content-Type'] = mimeType;
  }

  final uploadDio = Dio(
    BaseOptions(responseType: ResponseType.plain, followRedirects: true),
  );

  await uploadDio.put(
    uploadUrl,
    data: bytes,
    options: Options(
      headers: uploadHeaders,
      contentType: uploadHeaders['Content-Type'],
      responseType: ResponseType.plain,
      followRedirects: true,
      validateStatus: (code) => code != null && code >= 200 && code < 300,
    ),
    onSendProgress: onProgress,
  );

  await dio.post('/media/$mediaId/confirm');

  final patchPayload = <String, dynamic>{...metadataPatch};
  final patch = await dio.patch('/media/$mediaId', data: patchPayload);
  final patched = _asMap(_unwrapData(patch.data));

  final storageKey = _firstNonEmpty([
    _stringOf(patched['storageKey']),
    _stringOf(patched['objectKey']),
    _stringOf(patched['key']),
    _stringOf(patched['path']),
    _stringOf(upload['objectKey']),
    _stringOf(upload['storageKey']),
    _stringOf(upload['key']),
    _stringOf(upload['path']),
    _stringOf(presigned['storageKey']),
    _stringOf(presigned['objectKey']),
    _stringOf(presigned['key']),
    _stringOf(presigned['path']),
  ]);

  if (storageKey.isEmpty) {
    throw Exception('Storage key missing from upload response.');
  }

  final url = _firstNonEmpty([
    _stringOf(patched['displayUrl']),
    _stringOf(patched['url']),
    _stringOf(patched['publicUrl']),
    _stringOf(patched['signedUrl']),
    _stringOf(patched['sourceUrl']),
    _stringOf(patched['fileUrl']),
    _stringOf(mediaMap['displayUrl']),
    _stringOf(mediaMap['url']),
    _stringOf(mediaMap['publicUrl']),
    _stringOf(mediaMap['signedUrl']),
    _stringOf(mediaMap['sourceUrl']),
    _stringOf(mediaMap['fileUrl']),
  ]);

  // A POSTER IS A PICTURE OF THE OBJECT. FOR VIDEO IT IS NEVER THE OBJECT.
  //
  // `url` used to close this list unconditionally, so `thumbUrl` was NEVER
  // empty. For a video that handed back the .mp4 as its own poster, an image
  // decoder was pointed at it, and the composition strip showed a blank tile
  // after fetching the whole file. It also suppressed the real preview:
  // `AuraVideoSurface` decodes a frame only when no poster appears to exist.
  //
  // This is the layer the rule belongs in. The institution composer was fixed
  // first and the fix was DEAD CODE — it tested `result.thumbUrl.isNotEmpty`,
  // which this fallback had already guaranteed. Every composer shares this
  // helper, so every composer shared the defect.
  //
  // For a still the object IS its own picture, so the fallback stays there.
  final thumbUrl = posterUrlForUpload(
    candidates: [
      _stringOf(patched['thumbnailUrl']),
      _stringOf(patched['thumbUrl']),
      _stringOf(patched['previewUrl']),
      _stringOf(mediaMap['thumbnailUrl']),
      _stringOf(mediaMap['thumbUrl']),
      _stringOf(mediaMap['previewUrl']),
    ],
    url: url,
    kind: kind,
  );

  return AuraMediaUploadResult(
    mediaId: mediaId,
    storageKey: storageKey,
    url: url,
    thumbUrl: thumbUrl,
    kind: kind,
    source: source,
    raw: patched.isNotEmpty ? patched : presigned,
  );
}

dynamic _unwrapData(dynamic raw) {
  final map = _asMap(raw);
  final data = map['data'];
  if (data is Map) return data;
  if (data is List) return data;
  return map;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

String _stringOf(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text;
}

/// The poster for a freshly uploaded object, or `''` when there is none.
///
/// Pure, and public, because the last fix of this defect was DEAD CODE: the
/// institution composer's guard tested `result.thumbUrl.isNotEmpty` while this
/// helper's `url` fallback guaranteed it was never empty. A test that reads the
/// composer's source cannot see that. This one is asserted on the VALUE.
String posterUrlForUpload({
  required List<String> candidates,
  required String url,
  required String kind,
}) {
  final isVideo = kind.trim().toUpperCase() == 'VIDEO';
  return _firstNonEmpty([...candidates, if (!isVideo) url]);
}

String _firstNonEmpty(List<String> values) {
  for (final value in values) {
    final text = value.trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}
