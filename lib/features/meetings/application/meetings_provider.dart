import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/net/dio_provider.dart';
import '../data/meetings_repository.dart';
import '../data/availability_repository.dart';
import '../domain/meeting.dart';
import '../domain/availability_profile.dart';

final meetingsRepositoryProvider = Provider<MeetingsRepository>((ref) {
  return MeetingsRepository(ref.watch(dioProvider));
});

final availabilityRepositoryProvider = Provider<AvailabilityRepository>((ref) {
  return AvailabilityRepository(ref.watch(dioProvider));
});

// Upcoming meetings for the home screen
final upcomingMeetingsProvider = FutureProvider<List<Meeting>>((ref) async {
  final repo = ref.watch(meetingsRepositoryProvider);
  return repo.listMeetings(filter: 'upcoming');
});

// Past meetings
final pastMeetingsProvider = FutureProvider<List<Meeting>>((ref) async {
  final repo = ref.watch(meetingsRepositoryProvider);
  return repo.listMeetings(filter: 'past');
});

// Single meeting by id
final meetingProvider =
    FutureProvider.family<Meeting, String>((ref, id) async {
  final repo = ref.watch(meetingsRepositoryProvider);
  return repo.getMeeting(id);
});

// Meeting by code (public, used in join flow)
final meetingByCodeProvider =
    FutureProvider.family<Meeting, String>((ref, code) async {
  final repo = ref.watch(meetingsRepositoryProvider);
  return repo.getMeetingByCode(code);
});

// My availability profiles
final myAvailabilityProfilesProvider =
    FutureProvider<List<AvailabilityProfile>>((ref) async {
  final repo = ref.watch(availabilityRepositoryProvider);
  return repo.listMyProfiles();
});

// Public booking profile
final publicProfileProvider =
    FutureProvider.family<AvailabilityProfile, String>((ref, slug) async {
  final repo = ref.watch(availabilityRepositoryProvider);
  return repo.getPublicProfile(slug);
});

// Available slots for booking
class SlotQueryParams {
  final String slug;
  final DateTime start;
  final DateTime end;
  final int duration;
  const SlotQueryParams({
    required this.slug,
    required this.start,
    required this.end,
    required this.duration,
  });
}

final availableSlotsProvider =
    FutureProvider.family<List<TimeSlot>, SlotQueryParams>(
        (ref, params) async {
  final repo = ref.watch(availabilityRepositoryProvider);
  return repo.getSlots(
    params.slug,
    start: params.start,
    end: params.end,
    durationMinutes: params.duration,
  );
});
