/// Web never reaches here.
///
/// `SecureTokenStorage.isApplicable` is false off native, and every entry point
/// returns before the platform layer is consulted. Present so the conditional
/// import has a `dart.library.html` branch, matching the pattern the rest of
/// `core/` uses.
const bool isUnitTest = false;

Future<String?> readSecret(String key) async => null;
Future<void> writeSecret(String key, String value) async {}
Future<void> deleteSecret(String key) async {}
