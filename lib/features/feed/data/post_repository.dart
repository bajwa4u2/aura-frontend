import 'package:dio/dio.dart';

class PostsRepository {
  PostsRepository(this._dio);

  final Dio _dio;

  /// Expected backend:
  /// POST /posts { text: "..." }
  /// Returns: { post: {...} } OR the post object itself
  Future<void> createPost({required String text}) async {
    await _dio.post(
      '/v1/posts',
      data: {'text': text},
    );
  }
}
