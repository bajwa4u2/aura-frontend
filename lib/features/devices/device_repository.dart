import 'package:dio/dio.dart';

import 'device_model.dart';

class DeviceRepository {
  DeviceRepository(this._dio);

  final Dio _dio;

  Future<UserDevice> register(Map<String, dynamic> payload) async {
    final res = await _dio.post('/devices/register', data: payload);
    return UserDevice.fromJson(_unwrap(res.data));
  }

  Future<List<UserDevice>> getMyDevices() async {
    final res = await _dio.get('/devices/me');
    final raw = res.data;
    // Backend returns { ok: true, data: [...] } via ResponseWrapInterceptor.
    // Unwrap the outer envelope, then handle both array and { devices: [...] } shapes.
    List<dynamic>? list;
    if (raw is Map) {
      final inner = raw['data'];
      if (inner is List) {
        list = inner;
      } else if (inner is Map) {
        final nested = inner['devices'];
        if (nested is List) list = nested;
      }
    } else if (raw is List) {
      list = raw;
    }
    if (list == null) return const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(UserDevice.fromJson)
        .toList();
  }

  Future<UserDevice> updateDevice(
    String id,
    Map<String, dynamic> fields,
  ) async {
    final res = await _dio.patch('/devices/$id', data: fields);
    return UserDevice.fromJson(_unwrap(res.data));
  }

  Future<void> revokeDevice(String id) async {
    await _dio.delete('/devices/$id');
  }

  Map<String, dynamic> _unwrap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      final data = raw['data'];
      if (data is Map<String, dynamic>) return data;
      return raw;
    }
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return const {};
  }
}
