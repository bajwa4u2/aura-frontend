import 'package:dio/dio.dart';
import '../domain/meeting.dart';

class MeetingsRepository {
  MeetingsRepository(this._dio);
  final Dio _dio;

  // All backend responses are wrapped: { ok: true, data: <payload> }
  // Extract the inner data field from every response before parsing.

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
    final data = res.data!['data'] as Map<String, dynamic>;
    return Meeting.fromJson(data);
  }

  Future<Meeting> startInstantMeeting() async {
    final res = await _dio.post<Map<String, dynamic>>('/meetings/instant');
    final data = res.data!['data'] as Map<String, dynamic>;
    return Meeting.fromJson(data);
  }

  Future<List<Meeting>> listMeetings({
    String? filter,
    String? institutionId,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/meetings',
      queryParameters: {
        if (filter != null) 'filter': filter,
        if (institutionId != null) 'institutionId': institutionId,
      },
    );
    final list = res.data!['data'] as List<dynamic>;
    return list
        .map((m) => Meeting.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  Future<Meeting> getMeeting(String id) async {
    final res = await _dio.get<Map<String, dynamic>>('/meetings/$id');
    final data = res.data!['data'] as Map<String, dynamic>;
    return Meeting.fromJson(data);
  }

  Future<MeetingSummary?> getMeetingSummary(String id) async {
    final res = await _dio.get<Map<String, dynamic>>('/meetings/$id/summary');
    final data = res.data?['data'];
    if (data is Map<String, dynamic>) return MeetingSummary.fromJson(data);
    if (data is Map) {
      return MeetingSummary.fromJson(Map<String, dynamic>.from(data));
    }
    return null;
  }

  Future<MeetingSummary> saveMeetingSummary(
    String id, {
    String? summaryText,
    Map<String, dynamic>? attendanceSnapshot,
    List<String>? decisions,
    List<String>? commitments,
    List<String>? actions,
    List<String>? issues,
    List<String>? followUps,
  }) async {
    final res = await _dio.put<Map<String, dynamic>>(
      '/meetings/$id/summary',
      data: {
        if (summaryText != null) 'summaryText': summaryText,
        if (attendanceSnapshot != null)
          'attendanceSnapshot': attendanceSnapshot,
        if (decisions != null) 'decisions': decisions,
        if (commitments != null) 'commitments': commitments,
        if (actions != null) 'actions': actions,
        if (issues != null) 'issues': issues,
        if (followUps != null) 'followUps': followUps,
      },
    );
    final data = res.data!['data'] as Map<String, dynamic>;
    return MeetingSummary.fromJson(data);
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
    final data = res.data!['data'] as Map<String, dynamic>;
    return Meeting.fromJson(data);
  }

  Future<Meeting> startMeeting(String id) async {
    final res = await _dio.post<Map<String, dynamic>>('/meetings/$id/start');
    final data = res.data!['data'] as Map<String, dynamic>;
    return Meeting.fromJson(data);
  }

  Future<Meeting> endMeeting(String id) async {
    final res = await _dio.post<Map<String, dynamic>>('/meetings/$id/end');
    final data = res.data!['data'] as Map<String, dynamic>;
    return Meeting.fromJson(data);
  }

  Future<Meeting> cancelMeeting(String id) async {
    final res = await _dio.post<Map<String, dynamic>>('/meetings/$id/cancel');
    final data = res.data!['data'] as Map<String, dynamic>;
    return Meeting.fromJson(data);
  }

  Future<Meeting> getMeetingByCode(String code) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/public/meetings/join/$code',
      options: Options(extra: const {'__skip_auth': true}),
    );
    final data = res.data!['data'] as Map<String, dynamic>;
    return Meeting.fromJson(data);
  }

  Future<JoinMeetingResult> joinMeeting(
    String code, {
    String? guestName,
    String? guestEmail,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/public/meetings/join/$code',
      data: {
        if (guestName != null) 'guestName': guestName,
        if (guestEmail != null) 'guestEmail': guestEmail,
      },
      options: Options(extra: const {'__skip_auth': true}),
    );
    final data = res.data!['data'] as Map<String, dynamic>;
    return JoinMeetingResult.fromJson(data);
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
