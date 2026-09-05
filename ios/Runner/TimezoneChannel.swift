import Flutter
import Foundation

/// THE DEVICE'S IANA TIMEZONE.
///
/// Dart has no API for this. `DateTime.now().timeZoneName` gives an
/// abbreviation or a display name — "PKT", "Pakistan Standard Time" — neither
/// of which is a zone identifier, and converting one needs a lookup table.
/// Carrying such a table is how this was limited to the United States, and how
/// someone in Karachi could be shown a wrong meeting time while someone in New
/// York was shown the right one. Foundation already knows the answer.
///
/// ── WHY THIS IS ITS OWN FILE ─────────────────────────────────────────────
///
/// It lived in AppDelegate for about an hour, and a release gate correctly
/// refused it: `AppDelegate.swift` must not reference `TimeZone` at all,
/// because Apple's China CallKit restriction is resolved from the STOREFRONT
/// and never from the device. The gate scans the whole file rather than
/// reasoning about intent — which is the right design, since a device-derived
/// jurisdiction check is exactly the thing that would otherwise arrive looking
/// innocuous.
///
/// Scheduling and jurisdiction are different questions. This answers the first
/// one, somewhere the gate for the second one cannot be weakened by it.
enum TimezoneChannel {
  static let channelName = "org.auraplatform.app/timezone"

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "zoneId" else {
        result(FlutterMethodNotImplemented)
        return
      }
      // e.g. "Asia/Karachi", "Europe/Istanbul", "Europe/Berlin".
      result(Foundation.TimeZone.current.identifier)
    }
    retained = channel
  }

  /// Held for the process lifetime, matching the other Runner channels.
  private static var retained: FlutterMethodChannel?
}
