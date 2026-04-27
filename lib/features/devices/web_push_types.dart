/// Result of a successful Web Push subscription.
class WebPushResult {
  const WebPushResult({
    required this.endpoint,
    this.p256dh,
    this.auth,
  });

  final String endpoint;
  final String? p256dh;
  final String? auth;
}
