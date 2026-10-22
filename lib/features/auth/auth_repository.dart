import 'package:aura/core/errors/app_error_mapper.dart';
import 'package:aura/core/net/api_envelope.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/net/dio_provider.dart';

class AuthException implements Exception {
  final String message;

  const AuthException(this.message);

  @override
  String toString() => message;
}

class AuthRepository {
  final Dio _dio;

  AuthRepository(this._dio);

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String handle,
    required String displayName,
    required String firstName,
    required String lastName,
    /// Calendar date, `YYYY-MM-DD`. NOT a timestamp: a date of birth is a
    /// date a person states about themselves, and sending an instant is how a
    /// birthday moves by a day across a timezone — which, at a threshold, is
    /// the difference between an account and a refusal.
    required String dateOfBirth,
    /// ISO-3166 alpha-2, DECLARED by the person.
    ///
    /// Never inferred from IP, SIM, device locale, browser locale or
    /// timezone. Age rules differ by country, so this decides which floor
    /// applies; a guess here decides someone's eligibility on a fact nobody
    /// asserted.
    required String jurisdiction,
    // Apple Store §1.2 UGC compliance — caller must affirm acceptance
    // of the Terms / EULA at the version named in `kTermsVersion`.
    required bool termsAccepted,
    required String termsAcceptedVersion,
    /// The channel of the personal Invite to Aura link this person came
    /// through, if any. The server counts it as a daily total only.
    String? arrivedVia,
  }) async {
    try {
      final res = await _dio.post(
        '/auth/register',
        data: {
          'email': email.trim(),
          'password': password,
          'handle': handle.trim(),
          'displayName': displayName.trim(),
          'firstName': firstName.trim(),
          'lastName': lastName.trim(),
          // Both facts travel with the account request itself. The server
          // applies the age floor BEFORE creating anything, so an ineligible
          // applicant leaves no admitted person behind to clean up.
          'dateOfBirth': dateOfBirth.trim(),
          'jurisdiction': jurisdiction.trim().toUpperCase(),
          'termsAccepted': termsAccepted,
          'termsAcceptedVersion': termsAcceptedVersion,
          if (arrivedVia != null && arrivedVia.trim().isNotEmpty)
            'arrivedVia': arrivedVia.trim(),
        },
      );

      return _unwrap(res);
    } on DioException catch (e) {
      throw AuthException(authErrorMessage(e, AuthOperation.register));
    } catch (_) {
      throw const AuthException(
        'We could not create your account right now. Please try again.',
      );
    }
  }

  /// Apple Store §1.2 UGC compliance — record acceptance of a bumped
  /// Terms / EULA version for an already-signed-in user.
  Future<void> acceptTerms({required String version}) async {
    await _dio.post(
      '/auth/accept-terms',
      data: {'version': version},
    );
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    String? trustedDeviceToken,
  }) async {
    try {
      final data = <String, dynamic>{
        'email': email.trim(),
        'password': password,
      };
      if (trustedDeviceToken != null && trustedDeviceToken.trim().isNotEmpty) {
        data['trustedDeviceToken'] = trustedDeviceToken.trim();
      }
      final res = await _dio.post('/auth/login', data: data);
      return _unwrap(res);
    } on DioException catch (e) {
      throw AuthException(authErrorMessage(e, AuthOperation.signIn));
    } catch (_) {
      throw const AuthException(
        'We could not sign you in right now. Please try again.',
      );
    }
  }

  Future<Map<String, dynamic>> resendVerificationEmail({
    required String email,
  }) async {
    try {
      final res = await _dio.post(
        '/auth/resend-verification',
        data: {'email': email.trim()},
      );

      return _unwrap(res);
    } on DioException catch (e) {
      throw AuthException(authErrorMessage(e, AuthOperation.resendVerification));
    } catch (_) {
      throw const AuthException(
        'We could not resend the verification email right now. Please try again.',
      );
    }
  }

  Future<Map<String, dynamic>> verifyEmail({
    required String token,
  }) async {
    try {
      final res = await _dio.post(
        '/auth/verify-email',
        data: {'token': token},
      );

      return _unwrap(res);
    } on DioException catch (e) {
      throw AuthException(authErrorMessage(e, AuthOperation.verifyEmail));
    } catch (_) {
      throw const AuthException(
        'We could not verify your email right now. Please try again.',
      );
    }
  }

  Future<Map<String, dynamic>> forgotPassword({
    required String email,
  }) async {
    try {
      final res = await _dio.post(
        '/auth/forgot-password',
        data: {'email': email.trim()},
      );

      return _unwrap(res);
    } on DioException catch (e) {
      throw AuthException(authErrorMessage(e, AuthOperation.forgotPassword));
    } catch (_) {
      throw const AuthException(
        'We could not send the reset email right now. Please try again.',
      );
    }
  }

  Future<Map<String, dynamic>> verifyLoginCode({
    required String challengeId,
    required String code,
    bool trustDevice = false,
    String? deviceName,
  }) async {
    try {
      final data = <String, dynamic>{
        'challengeId': challengeId.trim(),
        'code': code.trim(),
        if (trustDevice) 'trustDevice': true,
        if (deviceName != null && deviceName.trim().isNotEmpty)
          'deviceName': deviceName.trim(),
      };
      final res = await _dio.post('/auth/login/verify-code', data: data);
      return _unwrap(res);
    } on DioException catch (e) {
      throw AuthException(authErrorMessage(e, AuthOperation.verifyCode));
    } catch (_) {
      throw const AuthException('We could not verify the code right now. Please try again.');
    }
  }

  Future<List<Map<String, dynamic>>> listSessions() async {
    try {
      final res = await _dio.get('/auth/sessions');
      return _readListResponse(res.data, fieldKeys: const ['sessions', 'data']);
    } on DioException catch (e) {
      throw AuthException(authErrorMessage(e, AuthOperation.account, fallback: 'Could not load sessions.'));
    } catch (_) {
      throw const AuthException('Could not load sessions.');
    }
  }

  Future<void> revokeSession(String sessionId) async {
    try {
      await _dio.delete('/auth/sessions/$sessionId');
    } on DioException catch (e) {
      throw AuthException(authErrorMessage(e, AuthOperation.account, fallback: 'Could not revoke session.'));
    } catch (_) {
      throw const AuthException('Could not revoke session.');
    }
  }

  Future<void> revokeOtherSessions() async {
    try {
      await _dio.delete('/auth/sessions/others');
    } on DioException catch (e) {
      throw AuthException(authErrorMessage(e, AuthOperation.account, fallback: 'Could not revoke other sessions.'));
    } catch (_) {
      throw const AuthException('Could not revoke other sessions.');
    }
  }

  Future<List<Map<String, dynamic>>> listTrustedDevices() async {
    try {
      final res = await _dio.get('/auth/trusted-devices');
      return _readListResponse(res.data, fieldKeys: const ['devices', 'data']);
    } on DioException catch (e) {
      throw AuthException(authErrorMessage(e, AuthOperation.account, fallback: 'Could not load trusted devices.'));
    } catch (_) {
      throw const AuthException('Could not load trusted devices.');
    }
  }

  Future<void> revokeTrustedDevice(String deviceId) async {
    try {
      await _dio.delete('/auth/trusted-devices/$deviceId');
    } on DioException catch (e) {
      throw AuthException(authErrorMessage(e, AuthOperation.account, fallback: 'Could not revoke device.'));
    } catch (_) {
      throw const AuthException('Could not revoke device.');
    }
  }

  Future<void> renameTrustedDevice(String deviceId, String name) async {
    try {
      await _dio.patch('/auth/trusted-devices/$deviceId', data: {'name': name.trim()});
    } on DioException catch (e) {
      throw AuthException(authErrorMessage(e, AuthOperation.account, fallback: 'Could not rename device.'));
    } catch (_) {
      throw const AuthException('Could not rename device.');
    }
  }

  Future<List<Map<String, dynamic>>> listLoginActivity() async {
    try {
      final res = await _dio.get('/auth/login-activity');
      return _readListResponse(res.data, fieldKeys: const ['activities', 'data']);
    } on DioException catch (e) {
      throw AuthException(authErrorMessage(e, AuthOperation.account, fallback: 'Could not load login activity.'));
    } catch (_) {
      throw const AuthException('Could not load login activity.');
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _dio.post('/auth/change-password', data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });
    } on DioException catch (e) {
      throw AuthException(authErrorMessage(e, AuthOperation.changePassword));
    } catch (_) {
      throw const AuthException('Could not change your password. Please try again.');
    }
  }

  Future<Map<String, dynamic>> resendLoginCode({
    required String challengeId,
  }) async {
    try {
      final res = await _dio.post(
        '/auth/login/resend-code',
        data: {'challengeId': challengeId.trim()},
      );
      return _unwrap(res);
    } on DioException catch (e) {
      throw AuthException(authErrorMessage(e, AuthOperation.resendCode));
    } catch (_) {
      throw const AuthException('We could not resend the code right now. Please try again.');
    }
  }

  Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      final res = await _dio.post(
        '/auth/reset-password',
        data: {
          'token': token,
          'password': newPassword,
        },
      );

      return _unwrap(res);
    } on DioException catch (e) {
      throw AuthException(authErrorMessage(e, AuthOperation.resetPassword));
    } catch (_) {
      throw const AuthException(
        'We could not reset your password right now. Please try again.',
      );
    }
  }

  /// The answer's `data` through the one envelope reader: a broken answer
  /// throws instead of becoming an empty map. When `data` is a list the
  /// whole envelope is returned, as before, for callers that read beside it.
  Map<String, dynamic> _unwrap(Response res) {
    final data = unwrapEnvelope(res.data);
    if (data is Map) return Map<String, dynamic>.from(data);
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// Robust reader for list endpoints that may return any of:
  /// - a raw JSON array (legacy)
  /// - `{ ok:true, data: [...] }` (Aura envelope)
  /// - `{ ok:true, data: { items: [...] } }` (rare wrapper)
  /// - `{ <fieldKey>: [...] }` (e.g. `sessions`, `devices`)
  ///
  /// Previously [_unwrap] was called on every response and would throw
  /// `Map.from(List)` for the second shape, which surfaced as
  /// "Could not load sessions / trusted devices" on the security screen.
  List<Map<String, dynamic>> _readListResponse(
    dynamic body, {
    required List<String> fieldKeys,
  }) {
    List<dynamic>? list;

    if (body is List) {
      list = body;
    } else if (body is Map) {
      // Aura envelope: { ok, data, ... }
      final outer = Map<String, dynamic>.from(body);
      final data = outer['data'];
      if (data is List) {
        list = data;
      } else if (data is Map) {
        final dataMap = Map<String, dynamic>.from(data);
        // Optional nested shape: { data: { items: [...] } } or { data: { sessions: [...] } }
        for (final key in [...fieldKeys, 'items']) {
          final nested = dataMap[key];
          if (nested is List) {
            list = nested;
            break;
          }
        }
      }
      // Top-level alias keys: { sessions: [...] } / { devices: [...] }
      if (list == null) {
        for (final key in fieldKeys) {
          final v = outer[key];
          if (v is List) {
            list = v;
            break;
          }
        }
      }
    }

    if (list == null) return const [];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return AuthRepository(dio);
});