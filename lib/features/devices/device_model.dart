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
    lastSeenAt: json['lastSeenAt']?.toString(),
    revokedAt: json['revokedAt']?.toString(),
    createdAt: json['createdAt']?.toString(),
    updatedAt: json['updatedAt']?.toString(),
  );
}
