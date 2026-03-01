import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../net/dio_provider.dart';

/// ApiClient is a lightweight wrapper around the app's single Dio instance.
/// IMPORTANT:
/// Do NOT create a separate Dio here. If you do, you bypass:
/// - Authorization header injection
/// - refresh single-flight logic
/// - web cookie (withCredentials) behavior
class ApiClient {
  ApiClient._(this.dio);

  final Dio dio;
}

/// Prefer this everywhere instead of ApiClient.create().
final apiClientProvider = Provider<ApiClient>((ref) {
  final dio = ref.watch(dioProvider);
  return ApiClient._(dio);
});