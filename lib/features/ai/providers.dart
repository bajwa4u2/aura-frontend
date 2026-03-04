import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/net/dio_provider.dart';
import 'data/ai_repository.dart';

/// AI repository provider (kept separate from feed).
final aiRepoProvider = Provider<AiRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return AiRepository(dio);
});