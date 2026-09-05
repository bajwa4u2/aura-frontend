import 'package:flutter/services.dart';

/// THE OPERATING SYSTEM'S OWN ZONE IDENTIFIER.
///
/// Every native platform Aura ships on knows its IANA zone and will say so;
/// Dart simply has no API that exposes it. `DateTime.now().timeZoneName` gives
/// an abbreviation or a display name — "PKT", "Pakistan Standard Time" — which
/// is not a zone identifier and cannot be turned into one without a lookup
/// table. Relying on such a table is what limited this to the United States.
///
/// The native side returns:
///   Android  java.util.TimeZone.getDefault().getID()   (IANA)
///   iOS      TimeZone.current.identifier               (IANA)
///   Windows  the CLDR mapping of the OS zone key       (IANA, or nothing)
const MethodChannel _channel = MethodChannel('org.auraplatform.app/timezone');

Future<String?> resolvePlatformZoneId() async {
  try {
    final result = await _channel.invokeMethod<String>('zoneId');
    final value = (result ?? '').trim();
    return value.isEmpty ? null : value;
  } on MissingPluginException {
    // A platform build without the handler has not answered. Callers treat
    // that as unknown; nothing substitutes a plausible default.
    return null;
  } catch (_) {
    return null;
  }
}
