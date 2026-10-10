import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/media/media_url_resolver.dart';
import 'package:aura/core/net/dio_provider.dart';

/// 10 Oct 2026: a feed card rebuilt after ten minutes reused the signed link
/// it was first given, which storage then refused — the poster failed, then
/// the video, and the card became "Video unavailable". The providers now
/// re-ask once the link turns stale.
void main() {
  test('refresh is due one second after the link turns stale', () {
    final now = DateTime.utc(2026, 10, 10, 17, 38, 26);
    final expires = now.add(const Duration(minutes: 10));
    expect(
      mediaLinkRefreshDelay(expires, now: now),
      const Duration(minutes: 9, seconds: 31),
    );
    expect(mediaLinkRefreshDelay(null, now: now), isNull);
    expect(
      mediaLinkRefreshDelay(now.subtract(const Duration(minutes: 1)), now: now),
      Duration.zero,
    );
  });

  test('a held video link and its poster are re-asked before they expire', () async {
    final calls = <String>[];
    final container = ProviderContainer(
      overrides: [dioProvider.overrideWithValue(_door(calls))],
    );
    addTearDown(container.dispose);

    final video = container.listen(mediaUrlProvider('m-film'), (_, __) {});
    final poster = container.listen(mediaPosterUrlProvider('m-film'), (_, __) {});
    expect((await container.read(mediaUrlProvider('m-film').future)).url,
        'https://store.test/m-film?n=1');
    expect(await container.read(mediaPosterUrlProvider('m-film').future),
        'https://store.test/m-film-thumb?n=1');

    // The first links expire inside the stale window, so the refresh is due
    // at once; the second ones are long-lived and are not re-asked.
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(video.read().value?.url, 'https://store.test/m-film?n=2');
    expect(poster.read().value, 'https://store.test/m-film-thumb?n=2');
    expect(calls, ['m-film', 'm-film?thumb', 'm-film', 'm-film?thumb']);
  });
}

Dio _door(List<String> calls) {
  final asked = <String, int>{};
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final id = options.path.split('/')[2];
        final thumb = options.queryParameters['v'] == 'thumb';
        final key = thumb ? '$id?thumb' : id;
        calls.add(key);
        final n = asked[key] = (asked[key] ?? 0) + 1;
        final expiresAt = n == 1
            ? DateTime.now().toUtc().add(const Duration(seconds: 29))
            : DateTime.now().toUtc().add(const Duration(minutes: 10));
        return handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'data': {
                'id': id,
                'url': 'https://store.test/$id${thumb ? '-thumb' : ''}?n=$n',
                'visibility': 'RESTRICTED',
                'expiresAt': expiresAt.toIso8601String(),
                'servedVariant': thumb ? 'thumb' : 'original',
              },
            },
          ),
        );
      },
    ),
  );
  return dio;
}
