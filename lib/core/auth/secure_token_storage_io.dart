import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:win32/win32.dart';

/// Native credential storage, one implementation per platform family.
///
/// **Windows** goes straight to the Credential Manager through FFI. The
/// Credential Manager encrypts each blob with DPAPI under the signed-in
/// user's key, so another user on the same machine cannot read it and it does
/// not travel in a plain file. No native build step, and therefore no ATL and
/// no extra Visual Studio component in the release prerequisites.
///
/// **iOS, Android and macOS** go through the channel Aura's own native code
/// serves — Keychain on Apple, EncryptedSharedPreferences over the Keystore on
/// Android — for the same reason every other native seam in this app is
/// first-party: the behaviour is small, the platform APIs are stable, and a
/// plugin here would own the most security-sensitive bytes in the product.
const MethodChannel _channel = MethodChannel('org.auraplatform.app/secure_store');

/// The Credential Manager target name. Namespaced so it cannot collide with
/// another application's entry, and stable so migration is idempotent.
String _target(String key) => 'org.auraplatform.app/$key';

/// A UNIT TEST MUST NOT READ THE MACHINE'S REAL CREDENTIAL STORE.
///
/// `TokenStore.load()` runs on the first frame of every widget test. Reaching
/// the OS from there makes the whole suite depend on machine state: a
/// credential left behind by an earlier run signs the test app IN, which starts
/// the notification poller, which leaves a periodic timer pending, which fails
/// the test with `!timersPending` — nowhere near the cause.
///
/// Under `flutter test` this falls back to `SharedPreferences`, which is
/// exactly where the suite already seeds sessions with
/// `setMockInitialValues`. That keeps every existing test seeding the same way
/// it always did, with no per-test reset to remember and no module state
/// leaking between cases.
///
/// `flutter test` sets `FLUTTER_TEST`; a real launch and an `integration_test`
/// run on a device do not — verified rather than assumed, by writing from the
/// integration test and finding the entry with `cmdkey /list`.
final bool isUnitTest = Platform.environment.containsKey('FLUTTER_TEST');

Future<String?> readSecret(String key) async {
  if (isUnitTest) {
    return (await SharedPreferences.getInstance()).getString(key);
  }
  if (Platform.isWindows) return _windowsRead(key);
  return _channel.invokeMethod<String>('read', {'key': key});
}

Future<void> writeSecret(String key, String value) async {
  if (isUnitTest) {
    await (await SharedPreferences.getInstance()).setString(key, value);
    return;
  }
  if (Platform.isWindows) return _windowsWrite(key, value);
  await _channel.invokeMethod<void>('write', {'key': key, 'value': value});
}

Future<void> deleteSecret(String key) async {
  if (isUnitTest) {
    await (await SharedPreferences.getInstance()).remove(key);
    return;
  }
  if (Platform.isWindows) return _windowsDelete(key);
  await _channel.invokeMethod<void>('delete', {'key': key});
}

// ── Windows Credential Manager, via win32 ───────────────────────────────────

Future<String?> _windowsRead(String key) async {
  final target = _target(key).toNativeUtf16();
  final out = calloc<Pointer<CREDENTIAL>>();
  try {
    final ok = CredRead(target, CRED_TYPE_GENERIC, 0, out);
    if (ok == 0) return null; // absent, or unreadable — both mean "no session"
    final cred = out.value.ref;
    if (cred.CredentialBlobSize == 0) return null;
    // Stored as UTF-16, so the blob length is bytes and the string length is
    // half of it. Reading it as UTF-8 would truncate at the first NUL.
    final value = cred.CredentialBlob
        .cast<Utf16>()
        .toDartString(length: cred.CredentialBlobSize ~/ 2);
    CredFree(out.value);
    return value.isEmpty ? null : value;
  } finally {
    free(target);
    calloc.free(out);
  }
}

Future<void> _windowsWrite(String key, String value) async {
  final target = _target(key).toNativeUtf16();
  final blob = value.toNativeUtf16();
  final cred = calloc<CREDENTIAL>();
  try {
    cred.ref
      ..Type = CRED_TYPE_GENERIC
      ..TargetName = target
      ..CredentialBlobSize = value.length * 2
      ..CredentialBlob = blob.cast<Uint8>()
      // LOCAL_MACHINE, deliberately not ENTERPRISE.
      //
      // ENTERPRISE persistence roams the credential to other machines the
      // person signs into. An Aura session belongs to the device it was
      // established on — the backend issues device-scoped refresh — so roaming
      // it would put a live session on a machine that never authenticated.
      ..Persist = CRED_PERSIST_LOCAL_MACHINE;
    final ok = CredWrite(cred, 0);
    if (ok == 0) {
      throw StateError('CredWrite failed: ${GetLastError()}');
    }
  } finally {
    calloc.free(cred);
    free(blob);
    free(target);
  }
}

Future<void> _windowsDelete(String key) async {
  final target = _target(key).toNativeUtf16();
  try {
    // A missing entry is a successful delete. Anything else would make signing
    // out fail because there was nothing to sign out of.
    CredDelete(target, CRED_TYPE_GENERIC, 0);
  } finally {
    free(target);
  }
}
