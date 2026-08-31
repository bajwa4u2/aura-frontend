import 'device_model.dart';

/// ONE PHONE IS ONE DEVICE, HOWEVER MANY WAYS IT CAN BE REACHED.
///
/// An iPhone registers twice — an APNS endpoint for PushKit/CallKit and an FCM
/// endpoint for the ordinary alert — because the credentials are genuinely
/// different and must not be merged. That is an implementation fact, and it was
/// leaking into the product: the Devices screen listed one phone as two, named
/// *"iPhone"* and *"iPhone (calls)"*, and marking either "preferred" set a
/// routing preference over half a phone.
///
/// This is the projection that fixes the human-facing half. **It groups, it
/// does not merge** — every underlying registration is kept and remains
/// individually revocable, because two credentials really do exist and
/// operational diagnostics need to see them.
class PhysicalDevice {
  const PhysicalDevice({
    required this.key,
    required this.primary,
    required this.endpoints,
  });

  /// Stable identity for this phone within one person's device list.
  final String key;

  /// The registration whose name and timestamps represent the phone.
  final UserDevice primary;

  /// Every registration belonging to it, primary included.
  final List<UserDevice> endpoints;

  /// Preference belongs to the PHONE. Any endpoint carrying the flag means the
  /// person chose this phone — which is exactly how the backend's routing
  /// authority already reads it.
  bool get isPreferred => endpoints.any((e) => e.isPreferred);

  bool get isActive => endpoints.any((e) => e.isActive);

  /// Ids to act on when the person removes this phone.
  ///
  /// Revoking one endpoint would leave the other half registered and still
  /// receiving — a phone the person believes they removed, still ringing.
  List<String> get revocableIds => endpoints.map((e) => e.id).toList();

  /// The most recent contact across every transport.
  String get lastSeenAt => endpoints
      .map((e) => e.lastSeenAt ?? '')
      .fold<String>('', (a, b) => a.compareTo(b) >= 0 ? a : b);

  /// A description of the transports underneath, for diagnostics only.
  String get transportSummary =>
      endpoints.map((e) => e.provider).toSet().toList().join(' + ');
}

/// The suffix the client appends when registering the VoIP endpoint, so that
/// row is recognisable as the *same* phone rather than a second one.
const String kCallsEndpointSuffix = ' (calls)';

String _displayName(UserDevice device) {
  final name = (device.deviceName ?? '').trim();
  if (name.endsWith(kCallsEndpointSuffix)) {
    return name.substring(0, name.length - kCallsEndpointSuffix.length).trim();
  }
  return name;
}

/// Collapse a person's registrations into the phones behind them.
///
/// Grouped by `installationId` — the client's persisted per-installation id,
/// stamped server-side from the request's own client identity. **Never by push
/// token**: a token rotates, and grouping by one would split a phone in two the
/// moment APNs reissued a credential.
///
/// A registration with no `installationId` is its own phone. That is not a
/// fallback so much as the truth: rows written before the field existed carry
/// nothing that can group them, and inventing a grouping from a shared device
/// NAME would merge two people's identical iPhone models into one entry.
///
/// Ordering is preserved from the input, so the caller's sort still decides
/// what appears first.
List<PhysicalDevice> groupIntoPhysicalDevices(List<UserDevice> devices) {
  final order = <String>[];
  final groups = <String, List<UserDevice>>{};

  for (final device in devices) {
    final install = (device.installationId ?? '').trim();
    final key = install.isNotEmpty ? 'install:$install' : 'endpoint:${device.id}';
    final bucket = groups[key];
    if (bucket == null) {
      groups[key] = [device];
      order.add(key);
    } else {
      bucket.add(device);
    }
  }

  return [
    for (final key in order)
      PhysicalDevice(
        key: key,
        primary: _primaryOf(groups[key]!),
        endpoints: groups[key]!,
      ),
  ];
}

/// Which registration speaks for the phone.
///
/// The ordinary endpoint, because it carries the plain device name; the VoIP
/// endpoint's name is that same name with `" (calls)"` appended, and showing a
/// person "iPhone (calls)" as the name of their phone is the defect this
/// projection exists to remove. Falls back to the first registration, whose
/// name is then trimmed of the suffix anyway.
UserDevice _primaryOf(List<UserDevice> endpoints) {
  for (final endpoint in endpoints) {
    final name = (endpoint.deviceName ?? '').trim();
    if (name.isNotEmpty && !name.endsWith(kCallsEndpointSuffix)) return endpoint;
  }
  return endpoints.first;
}

/// The name a person should see for a phone.
String physicalDeviceLabel(PhysicalDevice phone) {
  final fromPrimary = _displayName(phone.primary);
  if (fromPrimary.isNotEmpty) return fromPrimary;
  for (final endpoint in phone.endpoints) {
    final name = _displayName(endpoint);
    if (name.isNotEmpty) return name;
  }
  final platform = phone.primary.platform.trim();
  return platform.isEmpty ? 'Unknown device' : platform;
}
