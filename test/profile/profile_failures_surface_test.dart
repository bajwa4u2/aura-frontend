import 'package:aura/core/net/api_envelope.dart';
import 'package:aura/features/profile/data/profile_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// A failed read used to come back as "no posts", "no followers" or "not
/// following", so a person who already follows someone was shown Follow.
/// Failures now surface; only a real empty answer reads as empty.
void main() {
  ProfileRepository repoAnswering(
    Object? Function(RequestOptions o) answer, {
    int status = 200,
  }) {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test/v1'));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      if (status >= 400) {
        handler.reject(DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: options,
            statusCode: status,
            data: {'ok': false, 'error': {'code': 'INTERNAL'}},
          ),
        ));
        return;
      }
      handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: answer(options),
      ));
    }));
    return ProfileRepository(dio);
  }

  test('a failed follow-state read is an error, not "none"', () async {
    final repo = repoAnswering((_) => null, status: 500);
    expect(repo.getFollowStateDetail('amina'), throwsA(isA<DioException>()));
  });

  test('failed lists are errors, not empty lists', () async {
    final repo = repoAnswering((_) => null, status: 500);
    expect(repo.getFollowers('amina'), throwsA(isA<DioException>()));
    expect(repo.getFollowing('amina'), throwsA(isA<DioException>()));
    expect(repo.getUserPosts('amina'), throwsA(isA<DioException>()));
    expect(repo.getFollowRequestsInbox(), throwsA(isA<DioException>()));
    expect(repo.getFollowRequestsOutbox(), throwsA(isA<DioException>()));
  });

  test('an answer of the wrong shape is an error, not empty', () async {
    final repo = repoAnswering((_) => {'followers': []});
    expect(repo.getFollowers('amina'), throwsA(isA<ApiEnvelopeException>()));
  });

  test('a real answer still reads, and a real empty list is empty', () async {
    final repo = repoAnswering((o) => o.path.endsWith('/follow/state')
        ? {
            'ok': true,
            'data': {'state': 'following'},
          }
        : {'ok': true, 'data': {'items': []}});
    expect((await repo.getFollowStateDetail('amina')).state, 'following');
    expect(await repo.getFollowers('amina'), isEmpty);
  });
}
