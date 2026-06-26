class AvailabilityWindow {
  final String id;
  final String dayOfWeek;
  final String startTime;
  final String endTime;

  const AvailabilityWindow({
    required this.id,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  });

  factory AvailabilityWindow.fromJson(Map<String, dynamic> j) =>
      AvailabilityWindow(
        id: j['id'] as String,
        dayOfWeek: j['dayOfWeek'] as String,
        startTime: j['startTime'] as String,
        endTime: j['endTime'] as String,
      );

  String get label => '$startTime – $endTime';
}

class AvailabilityOverride {
  final String id;
  final DateTime date;
  final bool isBlocked;
  final String? startTime;
  final String? endTime;
  final String? reason;

  const AvailabilityOverride({
    required this.id,
    required this.date,
    required this.isBlocked,
    this.startTime,
    this.endTime,
    this.reason,
  });

  factory AvailabilityOverride.fromJson(Map<String, dynamic> j) =>
      AvailabilityOverride(
        id: j['id'] as String,
        date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
        isBlocked: j['isBlocked'] as bool? ?? true,
        startTime: j['startTime'] as String?,
        endTime: j['endTime'] as String?,
        reason: j['reason'] as String?,
      );
}

class ProfileOwner {
  final String id;
  final String? displayName;
  final String? handle;
  final String? avatarUrl;

  const ProfileOwner({
    required this.id,
    this.displayName,
    this.handle,
    this.avatarUrl,
  });

  factory ProfileOwner.fromJson(Map<String, dynamic> j) => ProfileOwner(
        id: j['id'] as String,
        displayName: j['displayName'] as String?,
        handle: j['handle'] as String?,
        avatarUrl: j['avatarUrl'] as String?,
      );

  String get name => displayName ?? handle ?? 'Unknown';
}

class AvailabilityProfile {
  final String id;
  final String name;
  final String slug;
  final String meetingTitle;
  final String? meetingDescription;
  final List<int> durationOptions;
  final int defaultDuration;
  final int bufferBefore;
  final int bufferAfter;
  final int minimumNotice;
  final int maximumAdvance;
  final String timezone;
  final bool isActive;
  final bool allowGuests;
  final bool waitingRoomEnabled;
  final bool requireApproval;
  final List<AvailabilityWindow> windows;
  final List<AvailabilityOverride> overrides;
  final ProfileOwner? owner;

  const AvailabilityProfile({
    required this.id,
    required this.name,
    required this.slug,
    required this.meetingTitle,
    this.meetingDescription,
    required this.durationOptions,
    required this.defaultDuration,
    required this.bufferBefore,
    required this.bufferAfter,
    required this.minimumNotice,
    required this.maximumAdvance,
    required this.timezone,
    required this.isActive,
    required this.allowGuests,
    required this.waitingRoomEnabled,
    required this.requireApproval,
    required this.windows,
    required this.overrides,
    this.owner,
  });

  factory AvailabilityProfile.fromJson(Map<String, dynamic> j) =>
      AvailabilityProfile(
        id: j['id'] as String,
        name: j['name'] as String,
        slug: j['slug'] as String,
        meetingTitle: j['meetingTitle'] as String,
        meetingDescription: j['meetingDescription'] as String?,
        durationOptions:
            (j['durationOptions'] as List<dynamic>? ?? [30])
                .map((e) => (e as num).toInt())
                .toList(),
        defaultDuration: (j['defaultDuration'] as num?)?.toInt() ?? 30,
        bufferBefore: (j['bufferBefore'] as num?)?.toInt() ?? 0,
        bufferAfter: (j['bufferAfter'] as num?)?.toInt() ?? 15,
        minimumNotice: (j['minimumNotice'] as num?)?.toInt() ?? 60,
        maximumAdvance: (j['maximumAdvance'] as num?)?.toInt() ?? 43200,
        timezone: j['timezone'] as String? ?? 'UTC',
        isActive: j['isActive'] as bool? ?? true,
        allowGuests: j['allowGuests'] as bool? ?? true,
        waitingRoomEnabled: j['waitingRoomEnabled'] as bool? ?? false,
        requireApproval: j['requireApproval'] as bool? ?? false,
        windows: (j['windows'] as List<dynamic>? ?? [])
            .map((w) => AvailabilityWindow.fromJson(w as Map<String, dynamic>))
            .toList(),
        overrides: (j['overrides'] as List<dynamic>? ?? [])
            .map((o) =>
                AvailabilityOverride.fromJson(o as Map<String, dynamic>))
            .toList(),
        owner: j['owner'] != null
            ? ProfileOwner.fromJson(j['owner'] as Map<String, dynamic>)
            : null,
      );

  String get publicUrl => '/meet/$slug';
}

class TimeSlot {
  final DateTime startAt;
  final DateTime endAt;

  const TimeSlot({required this.startAt, required this.endAt});

  factory TimeSlot.fromJson(Map<String, dynamic> j) => TimeSlot(
        startAt:
            DateTime.tryParse(j['startAt'] as String? ?? '') ?? DateTime.now(),
        endAt:
            DateTime.tryParse(j['endAt'] as String? ?? '') ?? DateTime.now(),
      );

  Duration get duration => endAt.difference(startAt);
  int get durationMinutes => duration.inMinutes;
}

class BookingConfirmation {
  final String bookingId;
  final String meetingId;
  final String meetingCode;
  final String joinUrl;
  final String cancelUrl;
  final DateTime scheduledAt;
  final int durationMinutes;
  final String timezone;
  final String hostName;
  final String meetingTitle;

  const BookingConfirmation({
    required this.bookingId,
    required this.meetingId,
    required this.meetingCode,
    required this.joinUrl,
    required this.cancelUrl,
    required this.scheduledAt,
    required this.durationMinutes,
    required this.timezone,
    required this.hostName,
    required this.meetingTitle,
  });

  factory BookingConfirmation.fromJson(Map<String, dynamic> j) =>
      BookingConfirmation(
        bookingId: j['bookingId'] as String,
        meetingId: j['meetingId'] as String,
        meetingCode: j['meetingCode'] as String,
        joinUrl: j['joinUrl'] as String,
        cancelUrl: j['cancelUrl'] as String,
        scheduledAt:
            DateTime.tryParse(j['scheduledAt'] as String? ?? '') ??
                DateTime.now(),
        durationMinutes: (j['durationMinutes'] as num?)?.toInt() ?? 30,
        timezone: j['timezone'] as String? ?? 'UTC',
        hostName: j['hostName'] as String? ?? '',
        meetingTitle: j['meetingTitle'] as String? ?? '',
      );
}
