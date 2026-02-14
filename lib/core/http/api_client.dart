import 'package:dio/dio.dart';
import '../config.dart';

class ApiClient {
  ApiClient._(this.dio);

  final Dio dio;

  factory ApiClient.create() {
    final dio = Dio(
      BaseOptions(
        baseUrl: '${AppConfig.apiBaseUrl}${AppConfig.apiPrefix}',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 10),
        headers: {'Accept': 'application/json'},
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Later: attach auth token here.
          // options.headers['Authorization'] = 'Bearer $token';
          handler.next(options);
        },
        onError: (e, handler) {
          handler.next(e);
        },
      ),
    );

    return ApiClient._(dio);
  }
}
