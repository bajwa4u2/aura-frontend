import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/net/dio_provider.dart';
import 'device_repository.dart';
import 'device_service.dart';

final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  return DeviceRepository(ref.watch(dioProvider));
});

final deviceServiceProvider = Provider<DeviceService>((ref) {
  // Pass an `isAuthed` callback the service consults before every device
  // endpoint hit. tokenStoreProvider is read (not watched) — we only need
  // the live value at call time, not a re-build dependency.
  return DeviceService(
    ref.watch(deviceRepositoryProvider),
    isAuthed: () {
      final store = ref.read(tokenStoreProvider);
      return store.isLoaded && store.isAuthed;
    },
  );
});
