import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/net/dio_provider.dart';
import 'data/ai_repository.dart';

final aiRepoProvider = Provider<AiRepository>((ref) {
  return AiRepository(ref.watch(dioProvider));
});
