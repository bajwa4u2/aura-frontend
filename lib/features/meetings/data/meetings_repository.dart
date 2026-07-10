import 'dart:typed_data';

import 'package:dio/dio.dart';
import '../domain/meeting.dart';
import '../domain/meeting_asset.dart';
import '../domain/meeting_conversation_message.dart';

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
    // Ownership: a meeting created from an institution workspace belongs to
    // that institution end to end.
    String? organizationId,
    // GOVERNANCE V1 — explicit meeting audience (PUBLIC/GUEST/INSTITUTION/
    // SELECTED/PRIVATE). When SELECTED, [audienceTargets] carries the cohort.
    String? audience,
    List<Map<String, dynamic>>? audienceTargets,
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
        if (organizationId != null && organizationId.isNotEmpty)
          'organizationId': organizationId,
        if (audience != null) 'audience': audience,
        if (audienceTargets != null && audienceTargets.isNotEmpty)
          'audienceTargets': audienceTargets,
      },
    );
    final data = res.data!['data'] as Map<String, dynamic>;
    return Meeting.fromJson(data);
  }

  Future<Meeting> startInstantMeeting({String? organizationId}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/meetings/instant',
      data: {
        if (organizationId != null && organizationId.isNotEmpty)
          'organizationId': organizationId,
      },
    );
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

  Future<List<MeetingOutcome>> getMeetingOutcomes(String meetingId) async {
    final res = await _dio.get<Map<String, dynamic>>('/meetings/$meetingId/outcomes');
    final data = res.data?['data'];
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(MeetingOutcome.fromJson)
          .toList();
    }
    return const [];
  }

  // Phase 4 — Meeting Conversation Stream transcript (member/host only; the
  // live stream itself flows over the realtime socket).
  Future<List<MeetingConversationMessage>> getMeetingConversation(
    String meetingId,
  ) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/meetings/$meetingId/conversation',
    );
    final data = res.data?['data'];
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(MeetingConversationMessage.fromJson)
          .toList();
    }
    return const [];
  }

  // Establishment Pass — meeting assets (materials, shared files, recordings).
  Future<List<MeetingAsset>> listAssets(String meetingId) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/meetings/$meetingId/assets',
    );
    final data = res.data?['data'];
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(MeetingAsset.fromJson)
          .toList();
    }
    return const [];
  }

  Future<MeetingAsset> addAssetLink(
    String meetingId, {
    required String url,
    String? title,
    String stage = 'PREPARATION',
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/meetings/$meetingId/assets/link',
      data: {'url': url, if (title != null) 'title': title, 'stage': stage},
    );
    return MeetingAsset.fromJson(res.data!['data'] as Map<String, dynamic>);
  }

  /// Presign → direct PUT to storage → confirm. Returns the READY asset.
  Future<MeetingAsset> uploadAsset(
    String meetingId, {
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
    String stage = 'PREPARATION',
    String kind = 'FILE',
    int? durationSeconds,
  }) async {
    final presign = await _dio.post<Map<String, dynamic>>(
      '/meetings/$meetingId/assets/presign',
      data: {
        'fileName': fileName,
        'mimeType': mimeType,
        'bytes': bytes.length,
        'stage': stage,
        'kind': kind,
      },
    );
    final data = presign.data!['data'] as Map<String, dynamic>;
    final asset = data['asset'] as Map<String, dynamic>;
    final uploadUrl = (data['uploadUrl'] ?? '').toString();
    final headers = (data['uploadHeaders'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        ) ??
        {'Content-Type': mimeType};

    // Direct-to-storage PUT with a bare Dio: the presigned URL must not
    // receive our API auth headers or base URL.
    final raw = Dio();
    await raw.put<void>(
      uploadUrl,
      data: Stream.fromIterable([bytes]),
      options: Options(
        headers: {...headers, 'Content-Length': bytes.length},
        // Signed PUTs reject redirects and love exact lengths.
        followRedirects: false,
        validateStatus: (s) => s != null && s >= 200 && s < 300,
      ),
    );

    final confirm = await _dio.post<Map<String, dynamic>>(
      '/meetings/$meetingId/assets/${asset['id']}/confirm',
      data: {
        if (durationSeconds != null) 'durationSeconds': durationSeconds,
      },
    );
    return MeetingAsset.fromJson(confirm.data!['data'] as Map<String, dynamic>);
  }

  // ── Durable recording upload (multipart) ──────────────────────────────
  // Parts stream to storage while the meeting runs; completion enumerates
  // them server-side. A crashed recording browser loses at most the
  // unflushed tail.

  /// Opens a multipart recording upload. Returns the asset id and the
  /// uploadId the part/complete calls carry.
  Future<({String assetId, String uploadId})> beginRecordingUpload(
    String meetingId, {
    required String fileName,
    required String mimeType,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/meetings/$meetingId/assets/recording/begin',
      data: {'fileName': fileName, 'mimeType': mimeType},
    );
    final data = res.data!['data'] as Map<String, dynamic>;
    final asset = data['asset'] as Map<String, dynamic>;
    return (
      assetId: (asset['id'] ?? '').toString(),
      uploadId: (data['uploadId'] ?? '').toString(),
    );
  }

  /// Presign + PUT one recording part directly to storage.
  Future<void> uploadRecordingPart(
    String meetingId, {
    required String assetId,
    required String uploadId,
    required int partNumber,
    required Uint8List bytes,
  }) async {
    final presign = await _dio.post<Map<String, dynamic>>(
      '/meetings/$meetingId/assets/$assetId/recording/part',
      data: {'uploadId': uploadId, 'partNumber': partNumber},
    );
    final data = presign.data!['data'] as Map<String, dynamic>;
    final url = (data['url'] ?? '').toString();

    final raw = Dio();
    await raw.put<void>(
      url,
      data: Stream.fromIterable([bytes]),
      options: Options(
        headers: {'Content-Length': bytes.length},
        followRedirects: false,
        validateStatus: (s) => s != null && s >= 200 && s < 300,
      ),
    );
  }

  Future<MeetingAsset> completeRecordingUpload(
    String meetingId, {
    required String assetId,
    required String uploadId,
    int? durationSeconds,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/meetings/$meetingId/assets/$assetId/recording/complete',
      data: {
        'uploadId': uploadId,
        if (durationSeconds != null) 'durationSeconds': durationSeconds,
      },
    );
    return MeetingAsset.fromJson(res.data!['data'] as Map<String, dynamic>);
  }

  Future<void> abortRecordingUpload(
    String meetingId, {
    required String assetId,
    required String uploadId,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/meetings/$meetingId/assets/$assetId/recording/abort',
      data: {'uploadId': uploadId},
    );
  }

  Future<MeetingAsset> updateAsset(
    String meetingId,
    String assetId, {
    String? title,
    bool? visibleToGuests,
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/meetings/$meetingId/assets/$assetId',
      data: {
        if (title != null) 'title': title,
        if (visibleToGuests != null) 'visibleToGuests': visibleToGuests,
      },
    );
    return MeetingAsset.fromJson(res.data!['data'] as Map<String, dynamic>);
  }

  Future<void> deleteAsset(String meetingId, String assetId) async {
    await _dio.delete<Map<String, dynamic>>(
      '/meetings/$meetingId/assets/$assetId',
    );
  }

  Future<String?> assetUrl(String meetingId, String assetId) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/meetings/$meetingId/assets/$assetId/url',
    );
    final data = res.data?['data'];
    if (data is Map) return (data['url'] ?? '').toString();
    return null;
  }

  // Phase 4.5 — promote a conversation message into a MeetingOutcome (host
  // only, server-enforced). Returns the created/existing outcome id.
  Future<String?> promoteConversationMessage(
    String meetingId,
    String messageId, {
    required String type,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/meetings/$meetingId/conversation/$messageId/promote',
      data: {'type': type},
    );
    final data = res.data?['data'];
    if (data is Map) {
      final id = (Map<String, dynamic>.from(data)['promotedOutcomeId'] ?? '')
          .toString()
          .trim();
      return id.isEmpty ? null : id;
    }
    return null;
  }

  Future<MeetingOutcome> updateOutcome(
    String outcomeId, {
    String? status,
    String? ownerId,
    String? dueDate,
    String? text,
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/meetings/outcomes/$outcomeId',
      data: {
        if (status != null) 'status': status,
        if (ownerId != null) 'ownerId': ownerId,
        if (dueDate != null) 'dueDate': dueDate,
        if (text != null) 'text': text,
      },
    );
    final data = res.data!['data'] as Map<String, dynamic>;
    return MeetingOutcome.fromJson(data);
  }

  // One outcome representation — direct row CRUD (host only).
  Future<MeetingOutcome> createOutcome(
    String meetingId, {
    required String type,
    required String text,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/meetings/$meetingId/outcomes',
      data: {'type': type, 'text': text},
    );
    final data = res.data!['data'] as Map<String, dynamic>;
    return MeetingOutcome.fromJson(data);
  }

  Future<void> deleteOutcome(String outcomeId) async {
    await _dio.delete<Map<String, dynamic>>('/meetings/outcomes/$outcomeId');
  }

  // Continuity distribution — host shares the saved summary with attendees.
  Future<({bool alreadyShared, int recipients})> shareSummary(
    String meetingId, {
    bool force = false,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/meetings/$meetingId/summary/share',
      data: {'force': force},
    );
    final data = res.data?['data'];
    final map = data is Map ? Map<String, dynamic>.from(data) : const {};
    return (
      alreadyShared: map['alreadyShared'] == true,
      recipients: (map['recipients'] as num?)?.toInt() ?? 0,
    );
  }

  // Personal follow-up continuity (open outcomes across my meetings).
  Future<List<MeetingOutcome>> getMyOpenOutcomes() async {
    final res = await _dio.get<Map<String, dynamic>>('/meetings/my/outcomes');
    final data = res.data?['data'];
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(MeetingOutcome.fromJson)
          .toList();
    }
    return const [];
  }

  Future<List<MeetingOutcome>> getInstitutionOutcomes(
    String institutionId, {
    String? status,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/meetings/institution/$institutionId/outcomes',
      queryParameters: {if (status != null) 'status': status},
    );
    final data = res.data?['data'];
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(MeetingOutcome.fromJson)
          .toList();
    }
    return const [];
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
    String? preparationNotes,
    String? liveNotes,
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
        if (preparationNotes != null) 'preparationNotes': preparationNotes,
        if (liveNotes != null) 'liveNotes': liveNotes,
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

  /// Loads meeting metadata using the guest JWT stored in the token store.
  /// Used as a fallback when the guest reaches the live room via a direct
  /// deep-link that does not carry a ?code= query parameter.
  /// The backend cross-checks that the JWT's meetingId matches the path param.
  Future<Meeting> getGuestMeetingContext(String meetingId) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/public/meetings/$meetingId/guest-context',
    );
    final data = res.data!['data'] as Map<String, dynamic>;
    return Meeting.fromJson(data);
  }

  Future<JoinMeetingResult> joinMeeting(
    String code, {
    String? guestName,
    String? guestEmail,
    String? bookerToken,
    // Participant continuity: a signed-in MEMBER joins as themselves — the
    // backend upserts their member participant row (and consumes a booker
    // token as a claim), so the meeting lives in their own inventory.
    // Guests and anonymous visitors keep the auth-less path unchanged.
    bool asMember = false,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/public/meetings/join/$code',
      data: {
        if (guestName != null) 'guestName': guestName,
        if (guestEmail != null) 'guestEmail': guestEmail,
        if (bookerToken != null && bookerToken.isNotEmpty)
          'bookerToken': bookerToken,
      },
      options: Options(extra: {'__skip_auth': !asMember}),
    );
    final data = res.data!['data'] as Map<String, dynamic>;
    return JoinMeetingResult.fromJson(data);
  }

  Future<GuestAuthResult> exchangeGuestAuth(String guestSessionId) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/public/meetings/guest-auth',
      data: {'guestSessionId': guestSessionId},
      options: Options(extra: const {'__skip_auth': true}),
    );
    final data = res.data!['data'] as Map<String, dynamic>;
    return GuestAuthResult.fromJson(data);
  }

  // Participant continuity: a signed-in member presents their booking
  // reference (`bt`) and the booked meeting attaches to their account.
  // Returns the attached meeting.
  Future<Meeting> keepBookedMeeting(String bookerToken) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/meetings/claim',
      data: {'bookerToken': bookerToken},
    );
    final data = res.data!['data'] as Map<String, dynamic>;
    return Meeting.fromJson(data['meeting'] as Map<String, dynamic>);
  }

  // Participant continuity: confirm or decline a meeting attached to this
  // account (an email-matched booking arrives as a pending attachment).
  Future<void> respondToMeeting(String meetingId, String status) async {
    await _dio.post<void>(
      '/meetings/$meetingId/rsvp',
      data: {'status': status},
    );
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

  // Guest-approval — waiting guest polls its admission by guestSessionId (no
  // token; a PENDING guest has none yet). Returns 'PENDING' | 'ADMITTED' | 'DENIED'.
  Future<String?> guestAdmissionStatus(
    String meetingId,
    String guestSessionId,
  ) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/public/meetings/$meetingId/admission/$guestSessionId',
      options: Options(extra: const {'__skip_auth': true}),
    );
    final data = res.data!['data'] as Map<String, dynamic>;
    return data['admissionState'] as String?;
  }

  // Guest-approval — host side.
  Future<List<Map<String, dynamic>>> pendingGuests(String meetingId) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/meetings/$meetingId/pending',
    );
    final list = res.data!['data'] as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> admitGuest(String meetingId, String participantId) async {
    await _dio.post<void>(
      '/meetings/$meetingId/admit',
      data: {'participantId': participantId},
    );
  }

  Future<void> denyGuest(String meetingId, String participantId) async {
    await _dio.post<void>(
      '/meetings/$meetingId/deny',
      data: {'participantId': participantId},
    );
  }
}

class GuestAuthResult {
  final String accessToken;
  final String? refreshToken;

  const GuestAuthResult({required this.accessToken, this.refreshToken});

  factory GuestAuthResult.fromJson(Map<String, dynamic> j) => GuestAuthResult(
    accessToken: j['accessToken'] as String? ?? '',
    refreshToken: j['refreshToken'] as String?,
  );
}
