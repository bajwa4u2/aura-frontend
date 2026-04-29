import 'package:dio/dio.dart';

String adminErrorMessage(Object e) {
  if (e is DioException) {
    final code = e.response?.statusCode;
    if (code != null) return 'Server returned an error ($code). Try again.';
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Request timed out. Check your connection and retry.';
      case DioExceptionType.connectionError:
        return 'Could not reach the server. Check your connection.';
      default:
        return 'A network error occurred. Please retry.';
    }
  }
  return 'Something went wrong. Please try again.';
}
