import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/net/dio_provider.dart';
import 'device_repository.dart';
import 'device_service.dart';

final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  return DeviceRepository(ref.watch(dioProvider));
});

final deviceServiceProvider = Provider<DeviceService>((ref) {
  return DeviceService(ref.watch(deviceRepositoryProvider));
});
