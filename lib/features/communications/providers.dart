import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/net/dio_provider.dart';
import 'communications_repository.dart';

final communicationsRepositoryProvider =
    Provider<CommunicationsRepository>((ref) {
  return CommunicationsRepository(ref.watch(dioProvider));
});
