import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/net/dio_provider.dart';
import 'data/announcements_repository.dart';
import 'domain/announcement.dart';

final announcementsRepoProvider = Provider<AnnouncementsRepository>((ref) {
  return AnnouncementsRepository(ref.watch(dioProvider));
});

final pinnedAnnouncementsProvider = FutureProvider<List<Announcement>>((ref) async {
  final repo = ref.watch(announcementsRepoProvider);
  return repo.pinned();
});

final announcementsProvider = FutureProvider<List<Announcement>>((ref) async {
  final repo = ref.watch(announcementsRepoProvider);
  return repo.list();
});

final announcementBySlugProvider = FutureProvider.family<Announcement?, String>((ref, slug) async {
  final repo = ref.watch(announcementsRepoProvider);
  return repo.getBySlug(slug);
});
