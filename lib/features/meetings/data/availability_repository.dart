import 'package:dio/dio.dart';
import '../domain/availability_profile.dart';

class AvailabilityRepository {
  AvailabilityRepository(this._dio);
  final Dio _dio;

  // All backend responses are wrapped: { ok: true, data: <payload> }
  // Extract the inner data field from every response before parsing.
  //
  // Booking pages are institution-governed: creation and management use the
  // institution endpoints below. The legacy personal profile CRUD was
  // removed with the personal booking-page product.

  Future<List<AvailabilityProfile>> listMyProfiles() async {
    final res = await _dio.get<Map<String, dynamic>>('/availability');
    final list = res.data!['data'] as List<dynamic>;
    return list
        .map((p) => AvailabilityProfile.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  Future<AvailabilityProfile> getPublicProfile(String slug) async {
    final res = await _dio.get<Map<String, dynamic>>('/book/$slug');
    final data = res.data!['data'] as Map<String, dynamic>;
    return AvailabilityProfile.fromJson(data);
  }

  Future<List<TimeSlot>> getSlots(
    String slug, {
    required DateTime start,
    required DateTime end,
    required int durationMinutes,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/book/$slug/slots',
      queryParameters: {
        'start': start.toUtc().toIso8601String(),
        'end': end.toUtc().toIso8601String(),
        'duration': durationMinutes.toString(),
      },
    );
    final list = res.data!['data'] as List<dynamic>;
    return list
        .map((s) => TimeSlot.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  // Identity fields are ANONYMOUS-only: an authenticated member's booking
  // identity is derived server-side from their Aura account, so members omit
  // name/email entirely (submitted values would be ignored anyway).
  Future<BookingConfirmation> createBooking(
    String slug, {
    String? bookerName,
    String? bookerEmail,
    String? bookerNotes,
    required DateTime scheduledAt,
    required int durationMinutes,
    required String timezone,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/book/$slug',
      data: {
        if (bookerName != null) 'bookerName': bookerName,
        if (bookerEmail != null) 'bookerEmail': bookerEmail,
        if (bookerNotes != null) 'bookerNotes': bookerNotes,
        'scheduledAt': scheduledAt.toUtc().toIso8601String(),
        'durationMinutes': durationMinutes,
        'timezone': timezone,
      },
    );
    final data = res.data!['data'] as Map<String, dynamic>;
    return BookingConfirmation.fromJson(data);
  }

  Future<void> cancelBookingByToken(String token) async {
    await _dio.patch<void>('/book/cancel/$token');
  }

  Future<Map<String, dynamic>> rescheduleBookingByToken(
    String token, {
    required DateTime scheduledAt,
    String? timezone,
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/book/reschedule/$token',
      data: {
        'scheduledAt': scheduledAt.toUtc().toIso8601String(),
        if (timezone != null) 'timezone': timezone,
      },
    );
    final data = res.data!['data'] as Map<String, dynamic>;
    return data;
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
    final data = res.data!['data'] as Map<String, dynamic>;
    return AvailabilityProfile.fromJson(data);
  }

  Future<List<AvailabilityProfile>> listInstitutionProfiles(String institutionId) async {
    final res = await _dio.get<Map<String, dynamic>>(
        '/institution/$institutionId/availability');
    final list = res.data!['data'] as List<dynamic>;
    return list
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
    bool clearAssignedHost = false,
    bool? isActive,
    bool? allowGuests,
    bool? waitingRoomEnabled,
    bool? requireApproval,
    int? bufferBefore,
    int? bufferAfter,
    int? minimumNotice,
    int? maxBookingsPerDay,
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/institution/$institutionId/availability/$profileId',
      data: {
        if (name != null) 'name': name,
        if (meetingTitle != null) 'meetingTitle': meetingTitle,
        if (meetingDescription != null) 'meetingDescription': meetingDescription,
        if (clearAssignedHost || assignedHostId != null)
          'assignedHostId': clearAssignedHost ? null : assignedHostId,
        if (isActive != null) 'isActive': isActive,
        if (allowGuests != null) 'allowGuests': allowGuests,
        if (waitingRoomEnabled != null) 'waitingRoomEnabled': waitingRoomEnabled,
        if (requireApproval != null) 'requireApproval': requireApproval,
        if (bufferBefore != null) 'bufferBefore': bufferBefore,
        if (bufferAfter != null) 'bufferAfter': bufferAfter,
        if (minimumNotice != null) 'minimumNotice': minimumNotice,
        if (maxBookingsPerDay != null) 'maxBookingsPerDay': maxBookingsPerDay,
      },
    );
    final data = res.data!['data'] as Map<String, dynamic>;
    return AvailabilityProfile.fromJson(data);
  }

  Future<void> deleteInstitutionProfile(
      String institutionId, String profileId) async {
    await _dio.delete<void>(
        '/institution/$institutionId/availability/$profileId');
  }

  // J1: Returns all non-cancelled bookings for an institution-owned profile.
  Future<List<Map<String, dynamic>>> listInstitutionProfileBookings(
      String institutionId, String profileId) async {
    final res = await _dio.get<Map<String, dynamic>>(
        '/institution/$institutionId/availability/$profileId/bookings');
    final list = res.data!['data'] as List<dynamic>;
    return list.map((b) => Map<String, dynamic>.from(b as Map)).toList();
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
    final data = res.data!['data'] as Map<String, dynamic>;
    return AvailabilityProfile.fromJson(data);
  }

  Future<List<TimeSlot>> getInstitutionSlots(
    String institutionSlug,
    String slug, {
    required DateTime start,
    required DateTime end,
    required int durationMinutes,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/i/$institutionSlug/meet/$slug/slots',
      queryParameters: {
        'start': start.toUtc().toIso8601String(),
        'end': end.toUtc().toIso8601String(),
        'duration': durationMinutes.toString(),
      },
    );
    final list = res.data!['data'] as List<dynamic>;
    return list
        .map((s) => TimeSlot.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  // Same doctrine as [createBooking]: identity fields are anonymous-only.
  Future<BookingConfirmation> createInstitutionBooking(
    String institutionSlug,
    String slug, {
    String? bookerName,
    String? bookerEmail,
    String? bookerNotes,
    required DateTime scheduledAt,
    required int durationMinutes,
    required String timezone,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/i/$institutionSlug/meet/$slug',
      data: {
        if (bookerName != null) 'bookerName': bookerName,
        if (bookerEmail != null) 'bookerEmail': bookerEmail,
        if (bookerNotes != null) 'bookerNotes': bookerNotes,
        'scheduledAt': scheduledAt.toUtc().toIso8601String(),
        'durationMinutes': durationMinutes,
        'timezone': timezone,
      },
    );
    final data = res.data!['data'] as Map<String, dynamic>;
    return BookingConfirmation.fromJson(data);
  }
}
