import 'dart:io';

import 'package:dio/dio.dart';

import 'app_error.dart';

class AppErrorMapper {
  const AppErrorMapper._();

  static AppError from(
    Object error, {
    String? feature,
  }) {
    if (error is AppError) return error;

    if (error is DioException) {
      return _fromDio(error, feature: feature);
    }

    if (error is SocketException) {
      return const AppError(
        type: AppErrorType.network,
        message: 'Connection was interrupted. Try again.',
      );
    }

    final raw = error.toString().trim();

    return AppError(
      type: AppErrorType.unknown,
      message: 'Something went wrong. Try again.',
      debugMessage: raw.isEmpty ? null : raw,
    );
  }

  static AppError _fromDio(
    DioException error, {
    String? feature,
  }) {
    final status = error.response?.statusCode;
    final responseData = error.response?.data;
    final backendCode = _readBackendCode(responseData);
    final backendMessage = _readBackendMessage(responseData);

    if (_isAuthRequired(status, backendCode)) {
      return AppError(
        type: AppErrorType.authRequired,
        message: _authMessageForFeature(feature),
        action: AppError.signInAction,
        debugMessage: backendMessage ?? error.message,
        statusCode: status,
      );
    }

    if (status == 403) {
      return AppError(
        type: AppErrorType.forbidden,
        message: 'You do not have access to this.',
        debugMessage: backendMessage ?? error.message,
        statusCode: status,
      );
    }

    if (status == 404) {
      return AppError(
        type: AppErrorType.notFound,
        message: 'This could not be found.',
        debugMessage: backendMessage ?? error.message,
        statusCode: status,
      );
    }

    if (status == 400 || status == 422) {
      return AppError(
        type: AppErrorType.validation,
        message: backendMessage?.trim().isNotEmpty == true
            ? backendMessage!.trim()
            : 'Some information needs attention.',
        debugMessage: backendMessage ?? error.message,
        statusCode: status,
      );
    }

    if (status != null && status >= 500) {
      return AppError(
        type: AppErrorType.server,
        message: 'Something went wrong on our side. Try again.',
        debugMessage: backendMessage ?? error.message,
        statusCode: status,
      );
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return AppError(
          type: AppErrorType.timeout,
          message: 'The request took too long. Try again.',
          debugMessage: backendMessage ?? error.message,
          statusCode: status,
        );
      case DioExceptionType.connectionError:
        return AppError(
          type: AppErrorType.network,
          message: 'Connection was interrupted. Try again.',
          debugMessage: backendMessage ?? error.message,
          statusCode: status,
        );
      case DioExceptionType.cancel:
        return AppError(
          type: AppErrorType.cancelled,
          message: 'This request was cancelled.',
          debugMessage: backendMessage ?? error.message,
          statusCode: status,
        );
      case DioExceptionType.badCertificate:
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        break;
    }

    return AppError(
      type: AppErrorType.unknown,
      message: 'Something went wrong. Try again.',
      debugMessage: backendMessage ?? error.message,
      statusCode: status,
    );
  }

  static bool _isAuthRequired(int? status, String? backendCode) {
    if (status == 401) return true;
    if (backendCode == null) return false;
    const authCodes = {
      'UNAUTHORIZED',
      'AUTH_REQUIRED',
      'INVALID_TOKEN',
      'TOKEN_EXPIRED',
      'MISSING_REFRESH_TOKEN',
    };
    return authCodes.contains(backendCode.toUpperCase());
  }

  static String _authMessageForFeature(String? feature) {
    final cleaned = feature?.trim();
    if (cleaned == null || cleaned.isEmpty) {
      return 'Sign in to use this feature.';
    }
    return 'Sign in to $cleaned.';
  }

  static String? _readBackendCode(dynamic data) {
    final outer = _asMap(data);
    if (outer == null) return null;

    final error = _asMap(outer['error']);
    final code = error?['code']?.toString().trim();
    if (code != null && code.isNotEmpty) return code;

    final direct = outer['code']?.toString().trim();
    if (direct != null && direct.isNotEmpty) return direct;

    return null;
  }

  static String? _readBackendMessage(dynamic data) {
    final outer = _asMap(data);
    if (outer == null) return null;

    final error = _asMap(outer['error']);
    final message = error?['message']?.toString().trim();
    if (message != null && message.isNotEmpty) return message;

    final direct = outer['message']?.toString().trim();
    if (direct != null && direct.isNotEmpty) return direct;

    return null;
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }
}
