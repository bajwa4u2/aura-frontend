import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/session_providers.dart';
import '../data/meetings_repository.dart';
import '../data/availability_repository.dart';
import '../domain/meeting.dart';
import '../domain/availability_profile.dart';
import '../domain/meeting_asset.dart';
import '../domain/meeting_conversation_message.dart';
import '../domain/meeting_entry_resolution.dart';
import '../domain/meeting_identity.dart';
import '../../realtime/application/realtime_providers.dart';

class MeetingStateChangedEvent {
  final String meetingId;
  final String state;
  const MeetingStateChangedEvent({required this.meetingId, required this.state});
}

final meetingStateChangedEventProvider =
    StreamProvider<MeetingStateChangedEvent>((ref) {
      final socket = ref.watch(realtimeSocketServiceProvider);
      return socket.events
          .where((e) => e.name == 'meeting.state_changed')
          .map((e) => MeetingStateChangedEvent(
                meetingId: e.payload['meetingId'] as String? ?? '',
                state: e.payload['state'] as String? ?? '',
              ))
          .where((e) => e.meetingId.isNotEmpty);
    });

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

final institutionUpcomingMeetingsProvider =
    FutureProvider.family<List<Meeting>, String>((ref, institutionId) async {
      final repo = ref.watch(meetingsRepositoryProvider);
      return repo.listMeetings(
        filter: 'upcoming',
        institutionId: institutionId,
      );
    });

final institutionPastMeetingsProvider =
    FutureProvider.family<List<Meeting>, String>((ref, institutionId) async {
      final repo = ref.watch(meetingsRepositoryProvider);
      return repo.listMeetings(filter: 'past', institutionId: institutionId);
    });

// Single meeting by id
final meetingProvider = FutureProvider.family<Meeting, String>((ref, id) async {
  final repo = ref.watch(meetingsRepositoryProvider);
  return repo.getMeeting(id);
});

final meetingSummaryProvider = FutureProvider.family<MeetingSummary?, String>((
  ref,
  id,
) async {
  final repo = ref.watch(meetingsRepositoryProvider);
  return repo.getMeetingSummary(id);
});

final meetingOutcomesProvider =
    FutureProvider.family<List<MeetingOutcome>, String>((ref, meetingId) async {
      final repo = ref.watch(meetingsRepositoryProvider);
      return repo.getMeetingOutcomes(meetingId);
    });

// Establishment Pass — meeting assets (materials, shared files, recordings).
// Works for members AND guests (guest tokens see guest-visible READY assets).
final meetingAssetsProvider =
    FutureProvider.family<List<MeetingAsset>, String>((ref, meetingId) async {
      final repo = ref.watch(meetingsRepositoryProvider);
      return repo.listAssets(meetingId);
    });

// Phase 4 — Meeting Conversation Stream transcript (member/host post-meeting
// read; guests receive the live stream over the realtime socket instead).
final meetingConversationProvider =
    FutureProvider.family<List<MeetingConversationMessage>, String>((
      ref,
      meetingId,
    ) async {
      final repo = ref.watch(meetingsRepositoryProvider);
      return repo.getMeetingConversation(meetingId);
    });

// Personal follow-up continuity: open outcomes across ALL of my meetings
// (hosted or attended) — the meetings home re-surfaces them so commitments
// never vanish into past-meeting archives.
final myOpenOutcomesProvider = FutureProvider<List<MeetingOutcome>>((
  ref,
) async {
  final repo = ref.watch(meetingsRepositoryProvider);
  return repo.getMyOpenOutcomes();
});

final institutionOpenOutcomesProvider =
    FutureProvider.family<List<MeetingOutcome>, String>((ref, institutionId) async {
      final repo = ref.watch(meetingsRepositoryProvider);
      return repo.getInstitutionOutcomes(institutionId, status: 'OPEN');
    });

// Meeting by code (public, used in join flow)
final meetingByCodeProvider = FutureProvider.family<Meeting, String>((
  ref,
  code,
) async {
  final repo = ref.watch(meetingsRepositoryProvider);
  return repo.getMeetingByCode(code);
});

// Participation Architecture — the canonical backend entry resolution.
// The pre-join surface renders EXACTLY this outcome; no policy in Flutter.
class MeetingEntryKey {
  final String code;
  final String? bookerToken;
  final String? invitationToken;
  final String? guestSessionId;
  const MeetingEntryKey(
    this.code, {
    this.bookerToken,
    this.invitationToken,
    this.guestSessionId,
  });

  @override
  bool operator ==(Object other) =>
      other is MeetingEntryKey &&
      other.code == code &&
      other.bookerToken == bookerToken &&
      other.invitationToken == invitationToken &&
      other.guestSessionId == guestSessionId;

  @override
  int get hashCode =>
      Object.hash(code, bookerToken, invitationToken, guestSessionId);
}

final meetingEntryResolutionProvider =
    FutureProvider.family<MeetingEntryResolution, MeetingEntryKey>((
  ref,
  key,
) async {
  final repo = ref.watch(meetingsRepositoryProvider);
  final isMember = ref.watch(tokenStoreProvider).isMemberSession;
  return repo.resolveMeetingEntry(
    key.code,
    bookerToken: key.bookerToken,
    invitationToken: key.invitationToken,
    guestSessionId: key.guestSessionId,
    asMember: isMember,
  );
});

// Meeting context for guest deep-links that arrive without a ?code= param.
// Requires a valid guest JWT in the token store; the backend validates the
// JWT's meetingId claim against the path parameter before returning data.
final guestMeetingContextProvider = FutureProvider.family<Meeting, String>((
  ref,
  meetingId,
) async {
  final repo = ref.watch(meetingsRepositoryProvider);
  return repo.getGuestMeetingContext(meetingId);
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

final currentBookingIdentityProvider = FutureProvider<MeetingIdentityRef?>((
  ref,
) async {
  if (!ref.watch(isAuthedProvider)) return null;

  final dio = ref.watch(dioProvider);
  try {
    final res = await dio.get('/users/me');
    final data = res.data;
    if (data is Map<String, dynamic>) {
      return MeetingIdentityRef.fromUserJson(data);
    }
    if (data is Map) {
      return MeetingIdentityRef.fromUserJson(Map<String, dynamic>.from(data));
    }
  } catch (_) {
    return null;
  }
  return null;
});

// Available slots for booking
class SlotQueryParams {
  final String slug;
  final DateTime start;
  final DateTime end;
  final int duration;
  // Optional institution slug for institution-owned booking pages
  final String? institutionSlug;
  const SlotQueryParams({
    required this.slug,
    required this.start,
    required this.end,
    required this.duration,
    this.institutionSlug,
  });

  @override
  bool operator ==(Object other) =>
      other is SlotQueryParams &&
      other.slug == slug &&
      other.start == start &&
      other.end == end &&
      other.duration == duration &&
      other.institutionSlug == institutionSlug;

  @override
  int get hashCode => Object.hash(slug, start, end, duration, institutionSlug);
}

final availableSlotsProvider =
    FutureProvider.family<List<TimeSlot>, SlotQueryParams>((ref, params) async {
      final repo = ref.watch(availabilityRepositoryProvider);
      if (params.institutionSlug != null) {
        return repo.getInstitutionSlots(
          params.institutionSlug!,
          params.slug,
          start: params.start,
          end: params.end,
          durationMinutes: params.duration,
        );
      }
      return repo.getSlots(
        params.slug,
        start: params.start,
        end: params.end,
        durationMinutes: params.duration,
      );
    });

// Institution availability profiles (for admin screens)
final institutionProfilesProvider =
    FutureProvider.family<List<AvailabilityProfile>, String>((
      ref,
      institutionId,
    ) async {
      final repo = ref.watch(availabilityRepositoryProvider);
      return repo.listInstitutionProfiles(institutionId);
    });

// Institution public booking profile (by institutionSlug/bookingSlug)
class InstitutionBookingKey {
  final String institutionSlug;
  final String bookingSlug;
  const InstitutionBookingKey(this.institutionSlug, this.bookingSlug);
  @override
  bool operator ==(Object other) =>
      other is InstitutionBookingKey &&
      other.institutionSlug == institutionSlug &&
      other.bookingSlug == bookingSlug;
  @override
  int get hashCode => Object.hash(institutionSlug, bookingSlug);
}

final institutionPublicProfileProvider =
    FutureProvider.family<AvailabilityProfile, InstitutionBookingKey>((
      ref,
      key,
    ) async {
      final repo = ref.watch(availabilityRepositoryProvider);
      return repo.getInstitutionPublicProfile(
        key.institutionSlug,
        key.bookingSlug,
      );
    });

// J1: Booking inbox — all non-cancelled bookings for an institution profile.
class InstitutionProfileBookingsKey {
  final String institutionId;
  final String profileId;
  const InstitutionProfileBookingsKey(this.institutionId, this.profileId);
  @override
  bool operator ==(Object other) =>
      other is InstitutionProfileBookingsKey &&
      other.institutionId == institutionId &&
      other.profileId == profileId;
  @override
  int get hashCode => Object.hash(institutionId, profileId);
}

final institutionProfileBookingsProvider = FutureProvider.family<
    List<Map<String, dynamic>>, InstitutionProfileBookingsKey>((
  ref,
  key,
) async {
  final repo = ref.watch(availabilityRepositoryProvider);
  return repo.listInstitutionProfileBookings(key.institutionId, key.profileId);
});
