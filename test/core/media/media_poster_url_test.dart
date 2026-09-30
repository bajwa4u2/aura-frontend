import 'package:aura/core/media/media_url_resolver.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A RESTRICTED FILM ASKS THE DOOR FOR ITS SERVER POSTER (2026-09-30).
///
/// The feed ships no poster URL for non-public media, so the card decoded its
/// own frames: black on films that open dark, nothing where the platform
/// cannot decode. The door falls through to the film itself when no poster
/// exists, and a video file is never a poster — `servedVariant` tells them
/// apart.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.body);

  final String body;
  final List<RequestOptions> seen = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seen.add(options);
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<(String?, _Adapter)> _poster(String served) async {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example'));
  final adapter = _Adapter(
    '{"id":"v1","url":"https://r2.example/signed","visibility":"RESTRICTED",'
    '"servedVariant":"$served"}',
  );
  dio.httpClientAdapter = adapter;
  final container = ProviderContainer(
    overrides: [
      mediaUrlResolverProvider.overrideWithValue(MediaUrlResolver(dio)),
    ],
  );
  addTearDown(container.dispose);
  return (await container.read(mediaPosterUrlProvider('v1').future), adapter);
}

void main() {
  test('a served poster is used, asked for as v=thumb', () async {
    final (url, adapter) = await _poster('thumb');
    expect(url, 'https://r2.example/signed');
    expect(adapter.seen.single.queryParameters, {'v': 'thumb'});
  });

  test('the film itself is never taken as a poster', () async {
    final (url, _) = await _poster('primary');
    expect(url, isNull);
  });

  test('the poster and the film are cached apart', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example'));
    final adapter = _Adapter(
      '{"id":"v1","url":"https://r2.example/x","visibility":"RESTRICTED"}',
    );
    dio.httpClientAdapter = adapter;
    final resolver = MediaUrlResolver(dio);
    await resolver.resolve('v1');
    await resolver.resolve('v1', variant: 'thumb');
    expect(adapter.seen, hasLength(2));
  });
}
