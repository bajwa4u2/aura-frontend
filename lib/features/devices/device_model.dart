class UserDevice {
  const UserDevice({
    required this.id,
    required this.userId,
    required this.platform,
    required this.provider,
    this.token,
    this.endpoint,
    this.webPushP256dh,
    this.webPushAuth,
    this.deviceName,
    this.appVersion,
    this.userAgent,
    this.locale,
    this.timezone,
    this.isActive = true,
    this.installationId,
    this.isPreferred = false,
    this.lastSeenAt,
    this.revokedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String platform;
  final String provider;
  final String? token;
  final String? endpoint;
  final String? webPushP256dh;
  final String? webPushAuth;
  final String? deviceName;
  final String? appVersion;
  final String? userAgent;
  final String? locale;
  final String? timezone;
  final bool isActive;

  /// THE PHONE THIS REGISTRATION BELONGS TO.
  ///
  /// One physical device may hold several registrations — an iPhone keeps an
  /// APNS endpoint for PushKit/CallKit and an FCM endpoint for the ordinary
  /// alert at the same time. This is what says they are the same phone, so the
  /// Devices screen shows one entry rather than two and preference means
  /// "prefer this iPhone".
  ///
  /// Stamped server-side from the request's client identity; null on rows
  /// registered before it existed, which are then each their own phone.
  final String? installationId;

  /// Advanced Device Preference / Transfer — item 12. User-designated
  /// primary device; at most one true per user, enforced backend-side.
  ///
  /// CORRECTED 2026-08-31: this said "preference capture only — does not change
  /// which devices ring (that remains ring-all, pending the still-open founder
  /// ring-policy decision)." The decision was taken 2026-08-15. Preference is a
  /// real input to PREFERRED_FIRST_THEN_ALL, and since 2026-08-31 it is scoped
  /// to the physical installation rather than to one transport row.
  final bool isPreferred;
  final String? lastSeenAt;
  final String? revokedAt;
  final String? createdAt;
  final String? updatedAt;

  factory UserDevice.fromJson(Map<String, dynamic> json) => UserDevice(
    id: (json['id'] ?? '').toString(),
    userId: (json['userId'] ?? '').toString(),
    platform: (json['platform'] ?? '').toString(),
    provider: (json['provider'] ?? '').toString(),
    token: json['token']?.toString(),
    endpoint: json['endpoint']?.toString(),
    webPushP256dh: json['webPushP256dh']?.toString(),
    webPushAuth: json['webPushAuth']?.toString(),
    deviceName: json['deviceName']?.toString(),
    appVersion: json['appVersion']?.toString(),
    userAgent: json['userAgent']?.toString(),
    locale: json['locale']?.toString(),
    timezone: json['timezone']?.toString(),
    isActive: json['isActive'] as bool? ?? true,
    installationId: json['installationId']?.toString(),
    isPreferred: json['isPreferred'] as bool? ?? false,
    lastSeenAt: json['lastSeenAt']?.toString(),
    revokedAt: json['revokedAt']?.toString(),
    createdAt: json['createdAt']?.toString(),
    updatedAt: json['updatedAt']?.toString(),
  );
}
