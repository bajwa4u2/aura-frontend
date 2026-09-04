import Flutter
import Foundation
import Security

/// KEYCHAIN, FOR THE ONLY BYTES IN AURA THAT ARE A SESSION.
///
/// The access and refresh tokens were persisted in `UserDefaults`, which on
/// iOS is a plist inside the app container: readable from a device backup, and
/// readable outright on a jailbroken phone. A bearer token there is a session
/// anyone holding the file can resume.
///
/// This is deliberately small and first-party rather than a plugin. The
/// equivalent package's Windows implementation would have added a Visual
/// Studio ATL component to Aura's release prerequisites in order to compile a
/// file it no longer uses, and the surface needed here is four SecItem calls.
///
/// ACCESSIBILITY IS `AfterFirstUnlock`, NOT `WhenUnlocked`, AND THAT IS A CALL
/// REQUIREMENT RATHER THAN A CONVENIENCE. Aura receives calls on a locked
/// phone. A token the app cannot read until the person unlocks is a token that
/// cannot refresh while a call is arriving, so CallKit would present a call the
/// app then fails to join. `AfterFirstUnlock` keeps the item unreadable until
/// the device has been unlocked once since boot, which is the strongest setting
/// compatible with answering from the lock screen.
///
/// `ThisDeviceOnly` is deliberate too: the backend issues device-scoped
/// refresh, so a session must not travel to another device through an iCloud
/// Keychain sync or an encrypted backup restore.
enum SecureStore {
  static let channelName = "org.auraplatform.app/secure_store"

  /// Namespaced so the item cannot collide with anything else the app stores.
  private static let service = "org.auraplatform.app.session"

  /// Registered by `AppDelegate` on the FlutterViewController's messenger, so
  /// the handler exists before `TokenStore.load()` asks for a token on the
  /// first frame. A missing handler there would read as "signed out".
  static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let key = args["key"] as? String,
      !key.isEmpty
    else {
      result(FlutterError(code: "bad_args", message: "key required", details: nil))
      return
    }

    switch call.method {
    case "read":
      result(read(key))
    case "write":
      guard let value = args["value"] as? String else {
        result(FlutterError(code: "bad_args", message: "value required", details: nil))
        return
      }
      write(key, value)
      result(nil)
    case "delete":
      delete(key)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func query(_ key: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key,
    ]
  }

  static func read(_ key: String) -> String? {
    var q = query(key)
    q[kSecReturnData as String] = true
    q[kSecMatchLimit as String] = kSecMatchLimitOne

    var item: CFTypeRef?
    let status = SecItemCopyMatching(q as CFDictionary, &item)
    guard status == errSecSuccess, let data = item as? Data else { return nil }
    return String(data: data, encoding: .utf8)
  }

  static func write(_ key: String, _ value: String) {
    guard let data = value.data(using: .utf8) else { return }

    // Update in place when it exists, so the accessibility attribute set at
    // creation is never quietly replaced by a default on a later write.
    let updated = SecItemUpdate(
      query(key) as CFDictionary,
      [kSecValueData as String: data] as CFDictionary
    )
    if updated == errSecSuccess { return }

    var q = query(key)
    q[kSecValueData as String] = data
    q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    SecItemAdd(q as CFDictionary, nil)
  }

  static func delete(_ key: String) {
    // `errSecItemNotFound` is a successful delete. Signing out must not fail
    // because there was nothing to sign out of.
    SecItemDelete(query(key) as CFDictionary)
  }
}
