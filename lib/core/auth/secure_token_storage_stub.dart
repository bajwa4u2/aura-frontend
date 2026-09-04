/// Unreachable default for the conditional import. Every target Aura builds
/// for resolves to either the `dart:io` or the `dart:html` branch.
const bool isUnitTest = false;

Future<String?> readSecret(String key) async => null;
Future<void> writeSecret(String key, String value) async {}
Future<void> deleteSecret(String key) async {}
