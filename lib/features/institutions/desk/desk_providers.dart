import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';
import 'desk_models.dart';

Map<String, dynamic> _unwrap(Object? body) {
  if (body is Map<String, dynamic>) return body;
  if (body is Map) return Map<String, dynamic>.from(body);
  return {};
}

/// The Desk for one institution (by id).
final deskProvider = FutureProvider.autoDispose.family<DeskSnapshot, String>((ref, institutionId) async {
  final res = await ref.watch(dioProvider).get('/institutions/$institutionId/desk');
  return DeskSnapshot.fromJson(_unwrap(res.data));
});

/// Memory beside one question or issue: (institutionId, recordId).
final institutionMemoryProvider =
    FutureProvider.autoDispose.family<InstitutionMemory, (String, String)>((ref, args) async {
  final (institutionId, recordId) = args;
  final res = await ref.watch(dioProvider).get('/institutions/$institutionId/engagement/$recordId/memory');
  return InstitutionMemory.fromJson(_unwrap(res.data));
});
