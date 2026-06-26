import 'package:dio/dio.dart';
import '../domain/availability_profile.dart';

class AvailabilityRepository {
  AvailabilityRepository(this._dio);
  final Dio _dio;

  Future<AvailabilityProfile> createProfile({
    required String name,
    required String slug,
    required String meetingTitle,
    String? meetingDescription,
    required List<int> durationOptions,
    required int defaultDuration,
    required String timezone,
    int bufferBefore = 0,
    int bufferAfter = 15,
    int minimumNotice = 60,
    int maximumAdvance = 43200,
    bool allowGuests = true,
    bool requireApproval = false,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/availability',
      data: {
        'name': name,
        'slug': slug,
        'meetingTitle': meetingTitle,
        if (meetingDescription != null)
          'meetingDescription': meetingDescription,
        'durationOptions': durationOptions,
        'defaultDuration': defaultDuration,
        'timezone': timezone,
        'bufferBefore': bufferBefore,
        'bufferAfter': bufferAfter,
        'minimumNotice': minimumNotice,
        'maximumAdvance': maximumAdvance,
        'allowGuests': allowGuests,
        'requireApproval': requireApproval,
      },
    );
    return AvailabilityProfile.fromJson(res.data!);
  }

  Future<List<AvailabilityProfile>> listMyProfiles() async {
    final res = await _dio.get<List<dynamic>>('/availability');
    return (res.data ?? [])
        .map((p) =>
            AvailabilityProfile.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  Future<AvailabilityProfile> getPublicProfile(String slug) async {
    final res = await _dio.get<Map<String, dynamic>>('/book/$slug');
    return AvailabilityProfile.fromJson(res.data!);
  }

  Future<List<TimeSlot>> getSlots(
    String slug, {
    required DateTime start,
    required DateTime end,
    required int durationMinutes,
  }) async {
    final res = await _dio.get<List<dynamic>>(
      '/book/$slug/slots',
      queryParameters: {
        'start': start.toUtc().toIso8601String(),
        'end': end.toUtc().toIso8601String(),
        'duration': durationMinutes.toString(),
      },
    );
    return (res.data ?? [])
        .map((s) => TimeSlot.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  Future<BookingConfirmation> createBooking(
    String slug, {
    required String bookerName,
    required String bookerEmail,
    String? bookerNotes,
    required DateTime scheduledAt,
    required int durationMinutes,
    required String timezone,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/book/$slug',
      data: {
        'bookerName': bookerName,
        'bookerEmail': bookerEmail,
        if (bookerNotes != null) 'bookerNotes': bookerNotes,
        'scheduledAt': scheduledAt.toUtc().toIso8601String(),
        'durationMinutes': durationMinutes,
        'timezone': timezone,
      },
    );
    return BookingConfirmation.fromJson(res.data!);
  }

  Future<void> addWindow(
    String profileId, {
    required String dayOfWeek,
    required String startTime,
    required String endTime,
  }) async {
    await _dio.post<void>(
      '/availability/$profileId/windows',
      data: {
        'dayOfWeek': dayOfWeek,
        'startTime': startTime,
        'endTime': endTime,
      },
    );
  }

  Future<void> removeWindow(String profileId, String windowId) async {
    await _dio.delete<void>('/availability/$profileId/windows/$windowId');
  }

  Future<void> addOverride(
    String profileId, {
    required String date,
    required bool isBlocked,
    String? startTime,
    String? endTime,
    String? reason,
  }) async {
    await _dio.post<void>(
      '/availability/$profileId/overrides',
      data: {
        'date': date,
        'isBlocked': isBlocked,
        if (startTime != null) 'startTime': startTime,
        if (endTime != null) 'endTime': endTime,
        if (reason != null) 'reason': reason,
      },
    );
  }

  // ── Institution-owned booking profiles ──────────────────────────────

  Future<AvailabilityProfile> createInstitutionProfile(
    String institutionId, {
    required String name,
    required String slug,
    required String meetingTitle,
    String? meetingDescription,
    required List<int> durationOptions,
    required int defaultDuration,
    required String timezone,
    String? assignedHostId,
    int bufferBefore = 0,
    int bufferAfter = 15,
    int minimumNotice = 60,
    int maximumAdvance = 43200,
    bool allowGuests = true,
    bool waitingRoomEnabled = false,
    bool requireApproval = false,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/institution/$institutionId/availability',
      data: {
        'name': name,
        'slug': slug,
        'meetingTitle': meetingTitle,
        if (meetingDescription != null) 'meetingDescription': meetingDescription,
        'durationOptions': durationOptions,
        'defaultDuration': defaultDuration,
        'timezone': timezone,
        if (assignedHostId != null) 'assignedHostId': assignedHostId,
        'bufferBefore': bufferBefore,
        'bufferAfter': bufferAfter,
        'minimumNotice': minimumNotice,
        'maximumAdvance': maximumAdvance,
        'allowGuests': allowGuests,
        'waitingRoomEnabled': waitingRoomEnabled,
        'requireApproval': requireApproval,
      },
    );
    return AvailabilityProfile.fromJson(res.data!);
  }

  Future<List<AvailabilityProfile>> listInstitutionProfiles(String institutionId) async {
    final res = await _dio.get<List<dynamic>>(
        '/institution/$institutionId/availability');
    return (res.data ?? [])
        .map((p) => AvailabilityProfile.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  Future<AvailabilityProfile> updateInstitutionProfile(
    String institutionId,
    String profileId, {
    String? name,
    String? meetingTitle,
    String? meetingDescription,
    String? assignedHostId,
    bool? isActive,
    bool? allowGuests,
    bool? waitingRoomEnabled,
    bool? requireApproval,
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/institution/$institutionId/availability/$profileId',
      data: {
        if (name != null) 'name': name,
        if (meetingTitle != null) 'meetingTitle': meetingTitle,
        if (meetingDescription != null) 'meetingDescription': meetingDescription,
        if (assignedHostId != null) 'assignedHostId': assignedHostId,
        if (isActive != null) 'isActive': isActive,
        if (allowGuests != null) 'allowGuests': allowGuests,
        if (waitingRoomEnabled != null) 'waitingRoomEnabled': waitingRoomEnabled,
        if (requireApproval != null) 'requireApproval': requireApproval,
      },
    );
    return AvailabilityProfile.fromJson(res.data!);
  }

  Future<void> disableInstitutionProfile(
      String institutionId, String profileId) async {
    await _dio.delete<void>(
        '/institution/$institutionId/availability/$profileId');
  }

  Future<void> addInstitutionWindow(
    String institutionId,
    String profileId, {
    required String dayOfWeek,
    required String startTime,
    required String endTime,
  }) async {
    await _dio.post<void>(
      '/institution/$institutionId/availability/$profileId/windows',
      data: {
        'dayOfWeek': dayOfWeek,
        'startTime': startTime,
        'endTime': endTime,
      },
    );
  }

  Future<void> removeInstitutionWindow(
      String institutionId, String profileId, String windowId) async {
    await _dio.delete<void>(
        '/institution/$institutionId/availability/$profileId/windows/$windowId');
  }

  // Institution public booking (no auth)
  Future<AvailabilityProfile> getInstitutionPublicProfile(
      String institutionSlug, String slug) async {
    final res = await _dio.get<Map<String, dynamic>>(
        '/i/$institutionSlug/meet/$slug');
    return AvailabilityProfile.fromJson(res.data!);
  }

  Future<List<TimeSlot>> getInstitutionSlots(
    String institutionSlug,
    String slug, {
    required DateTime start,
    required DateTime end,
    required int durationMinutes,
  }) async {
    final res = await _dio.get<List<dynamic>>(
      '/i/$institutionSlug/meet/$slug/slots',
      queryParameters: {
        'start': start.toUtc().toIso8601String(),
        'end': end.toUtc().toIso8601String(),
        'duration': durationMinutes.toString(),
      },
    );
    return (res.data ?? [])
        .map((s) => TimeSlot.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  Future<BookingConfirmation> createInstitutionBooking(
    String institutionSlug,
    String slug, {
    required String bookerName,
    required String bookerEmail,
    String? bookerNotes,
    required DateTime scheduledAt,
    required int durationMinutes,
    required String timezone,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/i/$institutionSlug/meet/$slug',
      data: {
        'bookerName': bookerName,
        'bookerEmail': bookerEmail,
        if (bookerNotes != null) 'bookerNotes': bookerNotes,
        'scheduledAt': scheduledAt.toUtc().toIso8601String(),
        'durationMinutes': durationMinutes,
        'timezone': timezone,
      },
    );
    return BookingConfirmation.fromJson(res.data!);
  }
}
