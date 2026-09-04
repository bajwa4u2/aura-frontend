import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// AUTHENTICATION SECRETS MUST NOT REST IN A READABLE FILE.
///
/// The access and refresh tokens were persisted in `SharedPreferences` — the
/// app's own plist on iOS, an XML file on Android, a roaming-profile file on
/// Windows. Every one of those is readable by anything that can read the app
/// container, so a bearer token in there is a session anyone holding the file
/// can resume.
///
/// The behaviour lives in platform channels and cannot be exercised off a
/// device. The WIRING can be, and the wiring is what a future auth change
/// would undo by accident.
String _read(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    throw StateError('missing: $path');
  }
  return file.readAsStringSync();
}

void main() {
  final store = _read('lib/core/auth/auth_providers.dart');
  final secure = _read('lib/core/auth/secure_token_storage.dart');
  final io = _read('lib/core/auth/secure_token_storage_io.dart');
  final swift = _read('ios/Runner/SecureStore.swift');
  final kotlin =
      _read('android/app/src/main/kotlin/org/auraplatform/app/SecureStore.kt');
  final pbxproj = _read('ios/Runner.xcodeproj/project.pbxproj');
  final gradle = _read('android/app/build.gradle.kts');
  final pubspec = _read('pubspec.yaml');

  group('Secure token storage', () {
    test('each platform reaches its own credential store', () {
      // Windows: Credential Manager through FFI, so no native build step and
      // therefore no Visual Studio ATL component in the release prerequisites.
      expect(pubspec.contains('win32:'), isTrue);
      expect(io.contains('CredWrite'), isTrue);
      expect(io.contains('CredRead'), isTrue);
      expect(io.contains('CredDelete'), isTrue);
      // Apple: Keychain.
      expect(swift.contains('kSecClassGenericPassword'), isTrue);
      // Android: AES-256-GCM under a key held in the Android Keystore.
      expect(kotlin.contains('AndroidKeyStore'), isTrue);
      expect(kotlin.contains('AES/GCM/NoPadding'), isTrue);
      expect(kotlin.contains('setKeySize(256)'), isTrue);
    });

    test('the rejected plugin stays rejected, with the reason recorded', () {
      expect(pubspec.contains('flutter_secure_storage:'), isFalse,
          reason: 'Its Windows plugin compiles against <atlstr.h>, which adds '
              'a Visual Studio component to the Windows release '
              'prerequisites to build a file it no longer uses.');
      expect(secure.contains('atlstr.h'), isTrue,
          reason: 'The reason must survive next to the decision, or someone '
              'adds the package back and rediscovers the build failure.');
    });

    test('the native sources are actually in their build', () {
      // A Swift file not in the Xcode target compiles into nothing, and the
      // channel would be missing at runtime — which reads as "signed out".
      expect(pbxproj.contains('SecureStore.swift in Sources'), isTrue);
      expect(pbxproj.contains('path = SecureStore.swift'), isTrue);
    });

    test('the channel handler is registered before a token is asked for', () {
      final activity = _read(
        'android/app/src/main/kotlin/org/auraplatform/app/MainActivity.kt',
      );
      expect(activity.contains('SecureStore.CHANNEL'), isTrue);
      final appDelegate = _read('ios/Runner/AppDelegate.swift');
      expect(appDelegate.contains('SecureStore.channelName'), isTrue);
    });

    test('TokenStore no longer writes tokens to SharedPreferences', () {
      // The only permitted mention is the defensive cleanup on clear, which
      // removes a legacy copy rather than creating one.
      expect(store.contains('prefs.setString(_kAccess'), isFalse,
          reason: 'An access token written to SharedPreferences is readable '
              'by anything that can read the app container.');
      expect(store.contains('prefs.setString(_kRefresh'), isFalse);
      expect(store.contains('prefs.getString(_kAccess)'), isFalse,
          reason: 'Reading from the old location would resurrect it as the '
              'source of truth.');
    });

    test('tokens are read and written through the credential store', () {
      expect(store.contains('SecureTokenStorage.read(_kAccess)'), isTrue);
      expect(store.contains('SecureTokenStorage.write(_kAccess'), isTrue);
      expect(store.contains('SecureTokenStorage.delete(_kAccess)'), isTrue);
    });

    test('migration runs before the read, so an upgrade cannot sign anyone out',
        () {
      final migrate = store.indexOf('SecureTokenStorage.migrateFromPreferences');
      final read = store.indexOf('SecureTokenStorage.read(_kAccess)');
      expect(migrate, greaterThan(-1));
      expect(read, greaterThan(-1));
      expect(migrate < read, isTrue,
          reason: 'Reading before migrating would find nothing on the first '
              'launch after upgrade and report the person signed out.');
    });

    test('migration writes the new place before clearing the old one', () {
      final body = secure.substring(
        secure.indexOf('static Future<void> migrateFromPreferences'),
      );
      final write = body.indexOf('await write(legacyAccessKey, legacyAccess)');
      final remove = body.indexOf('prefs.remove(legacyAccessKey)');
      expect(write, greaterThan(-1));
      expect(remove, greaterThan(-1));
      expect(write < remove, isTrue,
          reason: 'Removing first means a crash in between loses the session '
              'outright. This order can only ever repeat work.');
    });

    test('web is excluded, because a browser has no credential store', () {
      expect(secure.contains('static bool get isApplicable => !kIsWeb;'), isTrue);
      expect(secure.contains('if (!isApplicable) return'), isTrue,
          reason: '"Secure storage on web" would be localStorage wearing a '
              'better name. Web persists no token at all.');
    });

    test('iOS accessibility allows a locked phone to answer a call', () {
      expect(
        swift.contains('kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly'),
        isTrue,
        reason: 'WhenUnlocked would make the token unreadable while a call '
            'arrives on a locked phone, so CallKit would present a call the '
            'app then fails to join. ThisDeviceOnly stops a device-scoped '
            'session travelling through an iCloud Keychain sync.',
      );
    });

    test('the Windows credential does not roam to other machines', () {
      expect(io.contains('CRED_PERSIST_LOCAL_MACHINE'), isTrue,
          reason: 'ENTERPRISE persistence would put a live session on a '
              'machine that never authenticated.');
    });

    test('the Windows blob length is in bytes, not characters', () {
      expect(io.contains('value.length * 2'), isTrue);
      expect(io.contains('CredentialBlobSize ~/ 2'), isTrue,
          reason: 'A credential blob is measured in bytes and a Dart string '
              'in UTF-16 code units. Confusing them truncates every token at '
              'exactly half its length.');
    });

    test('no auth secret is placed in a shared container', () {
      // The iOS Share Extension is capture-only by founder ruling. A token in
      // an App Group would be readable by it.
      expect(secure.contains('App Group'), isFalse);
      expect(swift.contains('kSecAttrAccessGroup'), isFalse,
          reason: 'A Keychain access group is exactly how a Share Extension '
              'would gain the session it must never hold.');
    });

    test('Android owns its Keystore use rather than importing an alpha', () {
      // The name appears in the comment recording WHY it was rejected. What
      // must be absent is the use, and the import that enables it.
      expect(kotlin.contains('EncryptedSharedPreferences.create'), isFalse,
          reason: 'It arrives only via security-crypto, whose sole release '
              'carrying it is an alpha, and the class is deprecated upstream. '
              'The session must not depend on that.');
      expect(kotlin.contains('import androidx.security'), isFalse);
      expect(gradle.contains('androidx.security:security-crypto'), isFalse);
      expect(gradle.contains('NO androidx.security HERE'), isTrue,
          reason: 'The reason must survive next to the absence, or someone '
              'adds it back for brevity.');
    });

    test('the Android key is usable while the phone is locked', () {
      // Assert on the CALL, not the word. Both names appear in the comment
      // that records why they are absent, and a gate that trips on the
      // documentation of its own rule is a gate nobody can explain.
      expect(kotlin.contains('setUserAuthenticationRequired(true)'), isFalse,
          reason: 'A token that cannot be decrypted until someone unlocks '
              'cannot refresh while an incoming call is presenting, so the '
              'call would ring and then fail to join.');
      expect(kotlin.contains('setUnlockedDeviceRequired(true)'), isFalse);
    });

    test('every GCM encryption gets a fresh IV, enforced by the platform', () {
      expect(kotlin.contains('setRandomizedEncryptionRequired(true)'), isTrue,
          reason: 'IV reuse under GCM is catastrophic. This makes it '
              'impossible rather than merely discouraged.');
      expect(kotlin.contains('cipher.iv'), isTrue,
          reason: 'A system-generated IV must be stored beside the ciphertext '
              'or nothing can be decrypted.');
    });

    test('Android never falls back to storing the token in the clear', () {
      expect(kotlin.contains('refusing to persist an unencrypted session'),
          isTrue,
          reason: 'Writing the token unencrypted "so it works" is the defect '
              'this file exists to remove.');
    });

    test('an unreadable blob is cleared rather than failing every launch', () {
      expect(kotlin.contains('session unrecoverable'), isTrue);
      expect(kotlin.contains('Do not leave an unreadable blob behind'), isTrue,
          reason: 'A restore onto another device brings the ciphertext without '
              'the key. That is no longer a session.');
    });

    test('a credential store failure degrades, it does not crash the boot', () {
      expect(secure.contains('read failed for'), isTrue);
      expect(secure.contains('write failed for'), isTrue);
      expect(kotlin.contains('keystore unavailable'), isTrue,
          reason: 'A Keystore can be unavailable. Losing a session is '
              'recoverable; failing app start is not.');
    });

    test('session semantics are untouched', () {
      // The derivation, the load latch and the hint writes must all survive a
      // storage change. This is hardening, not a second auth authority.
      expect(store.contains('bool get isAuthed'), isTrue);
      expect(store.contains('bool get isMemberSession'), isTrue);
      expect(store.contains('_loadedCompleter'), isTrue);
      expect(store.contains('setSessionHint(true)'), isTrue);
      expect(store.contains('setSessionHint(false)'), isTrue);
    });
  });
}
