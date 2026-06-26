import 'package:dio/dio.dart';
import '../domain/meeting.dart';

class MeetingsRepository {
  MeetingsRepository(this._dio);
  final Dio _dio;

  Future<Meeting> createMeeting({
    required String title,
    String? description,
    required String type,
    String? scheduledAt,
    int? durationMinutes,
    String? timezone,
    bool? waitingRoomEnabled,
    bool? recordingEnabled,
    bool? allowGuests,
    bool? guestApprovalRequired,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/meetings',
      data: {
        'title': title,
        if (description != null) 'description': description,
        'type': type,
        if (scheduledAt != null) 'scheduledAt': scheduledAt,
        if (durationMinutes != null) 'durationMinutes': durationMinutes,
        if (timezone != null) 'timezone': timezone,
        if (waitingRoomEnabled != null)
          'waitingRoomEnabled': waitingRoomEnabled,
        if (recordingEnabled != null) 'recordingEnabled': recordingEnabled,
        if (allowGuests != null) 'allowGuests': allowGuests,
        if (guestApprovalRequired != null)
          'guestApprovalRequired': guestApprovalRequired,
      },
    );
    return Meeting.fromJson(res.data!);
  }

  Future<Meeting> startInstantMeeting() async {
    final res = await _dio.post<Map<String, dynamic>>('/meetings/instant');
    return Meeting.fromJson(res.data!);
  }

  Future<List<Meeting>> listMeetings({String? filter}) async {
    final res = await _dio.get<List<dynamic>>(
      '/meetings',
      queryParameters: {if (filter != null) 'filter': filter},
    );
    return (res.data ?? [])
        .map((m) => Meeting.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  Future<Meeting> getMeeting(String id) async {
    final res = await _dio.get<Map<String, dynamic>>('/meetings/$id');
    return Meeting.fromJson(res.data!);
  }

  Future<Meeting> updateMeeting(
    String id, {
    String? title,
    String? description,
    String? scheduledAt,
    int? durationMinutes,
    String? timezone,
    bool? waitingRoomEnabled,
    bool? recordingEnabled,
    bool? allowGuests,
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/meetings/$id',
      data: {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (scheduledAt != null) 'scheduledAt': scheduledAt,
        if (durationMinutes != null) 'durationMinutes': durationMinutes,
        if (timezone != null) 'timezone': timezone,
        if (waitingRoomEnabled != null)
          'waitingRoomEnabled': waitingRoomEnabled,
        if (recordingEnabled != null) 'recordingEnabled': recordingEnabled,
        if (allowGuests != null) 'allowGuests': allowGuests,
      },
    );
    return Meeting.fromJson(res.data!);
  }

  Future<Meeting> startMeeting(String id) async {
    final res = await _dio.post<Map<String, dynamic>>('/meetings/$id/start');
    return Meeting.fromJson(res.data!);
  }

  Future<Meeting> endMeeting(String id) async {
    final res = await _dio.post<Map<String, dynamic>>('/meetings/$id/end');
    return Meeting.fromJson(res.data!);
  }

  Future<Meeting> cancelMeeting(String id) async {
    final res = await _dio.post<Map<String, dynamic>>('/meetings/$id/cancel');
    return Meeting.fromJson(res.data!);
  }

  Future<Meeting> getMeetingByCode(String code) async {
    final res =
        await _dio.get<Map<String, dynamic>>('/meetings/join/$code');
    return Meeting.fromJson(res.data!);
  }

  Future<JoinMeetingResult> joinMeeting(
    String code, {
    String? guestName,
    String? guestEmail,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/meetings/join/$code',
      data: {
        if (guestName != null) 'guestName': guestName,
        if (guestEmail != null) 'guestEmail': guestEmail,
      },
    );
    return JoinMeetingResult.fromJson(res.data!);
  }

  Future<void> inviteToMeeting(
    String meetingId, {
    String? userId,
    String? email,
    String? name,
  }) async {
    await _dio.post<void>(
      '/meetings/$meetingId/invite',
      data: {
        if (userId != null) 'userId': userId,
        if (email != null) 'email': email,
        if (name != null) 'name': name,
      },
    );
  }
}
