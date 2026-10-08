import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aura/features/composition/data/composition_repository.dart';
import 'package:aura/features/composition/domain/composition_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// INSTITUTION CREDITS NEED A PLACE TO BE SPENT (2026-10-08).
///
/// A Pro plan's monthly credits pay for writing assistance done FOR the
/// institution. The institution's own composers had no writing assistance,
/// and the announcement editor's posted to `/v1/v1/composition/...` and failed
/// for everyone.
void main() {
  group('CompositionRepository', () {
    test('posts to the shared client at /composition/*, never /v1/v1', () async {
      final adapter = _CaptureAdapter({'translatedText': 'Hola'});
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test/v1'))
        ..httpClientAdapter = adapter;

      final out = await CompositionRepository(dio).translate(text: 'Hello', targetLanguage: 'es');

      expect(adapter.lastUri.toString(), 'https://api.example.test/v1/composition/translate');
      expect(adapter.lastBody.containsKey('actingForInstitutionId'), isFalse);
      expect(out.translatedText, 'Hola');
    });

    test('names the acting institution so its allowance is used', () async {
      final adapter = _CaptureAdapter({'sessionId': 's1', 'suggestions': []});
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test/v1'))
        ..httpClientAdapter = adapter;

      await CompositionRepository(dio, actingForInstitutionId: 'inst_1')
          .review(text: 'Hello', surface: CompositionSurface.announcement);

      expect(adapter.lastUri?.path, '/v1/composition/review');
      expect(adapter.lastBody['actingForInstitutionId'], 'inst_1');
    });
  });

  group('institution composers carry writing assistance as the institution', () {
    for (final path in const [
      'lib/features/institutions/posts/institution_post_composer_screen.dart',
      'lib/features/institutions/announcements/institution_announcement_composer.dart',
    ]) {
      test(path.split('/').last, () {
        final src = File(path).readAsStringSync();
        expect(src.contains('CompositionAssist('), isTrue);
        expect(src.contains('actingForInstitutionId: widget.institutionId'), isTrue);
      });
    }
  });
}

class _CaptureAdapter implements HttpClientAdapter {
  _CaptureAdapter(this.reply);

  final Map<String, dynamic> reply;
  Uri? lastUri;
  Map<String, dynamic> lastBody = const {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastUri = options.uri;
    lastBody = Map<String, dynamic>.from(options.data as Map);
    return ResponseBody.fromString(
      jsonEncode(reply),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
