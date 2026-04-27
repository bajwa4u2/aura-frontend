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
    final data = _unwrap(res.data);
    final list = data['devices'];
    if (list is List) {
      return list
          .whereType<Map<String, dynamic>>()
          .map(UserDevice.fromJson)
          .toList();
    }
    return const [];
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
