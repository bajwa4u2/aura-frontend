import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The Windows push channel, and an honest account of when there isn't one.
///
/// A WNS channel URI is issued by the OS to a **packaged** application — it is
/// a property of the MSIX identity, not of the executable. A debug run or a
/// bare `Release\aura.exe` has no identity, so there is no channel to get, and
/// this returns null rather than pretending. That distinction matters: "no
/// channel because unpackaged" is a development condition, while "no channel
/// from the installed app" would be a real defect, and collapsing the two would
/// hide the second behind the first.
class WindowsPushChannel {
  const WindowsPushChannel({required this.uri, this.expiresAt});

  final String uri;
  final DateTime? expiresAt;

  /// The OS retires channels. Re-registering while a good margin remains is
  /// cheaper than discovering expiry from a 410 on the next incoming call —
  /// which would be discovered by a call that failed to ring.
  bool get nearingExpiry {
    final at = expiresAt;
    if (at == null) return false;
    return at.difference(DateTime.now().toUtc()) < const Duration(days: 2);
  }
}

class WindowsPushService {
  static const MethodChannel _channel =
      MethodChannel('org.auraplatform.app/wns');

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  /// Ask the OS for this install's channel. Null means no channel is available
  /// here, with the reason logged — never an exception into the caller, because
  /// device registration must not fail wholesale over one platform's transport.
  static Future<WindowsPushChannel?> createChannel() async {
    if (!isSupported) return null;
    try {
      final result =
          await _channel.invokeMapMethod<String, dynamic>('createChannel');
      final uri = (result?['channelUri'] as String?)?.trim() ?? '';
      if (uri.isEmpty) return null;

      DateTime? expires;
      final raw = result?['expiresAt'];
      if (raw is int && raw > 0) {
        expires = DateTime.fromMillisecondsSinceEpoch(raw * 1000, isUtc: true);
      }
      return WindowsPushChannel(uri: uri, expiresAt: expires);
    } on PlatformException catch (e) {
      // WNS_UNAVAILABLE is the expected answer when running unpackaged.
      debugPrint('WindowsPushService.createChannel unavailable: ${e.code}');
      return null;
    } catch (e) {
      debugPrint('WindowsPushService.createChannel failed: $e');
      return null;
    }
  }
}
