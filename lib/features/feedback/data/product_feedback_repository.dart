import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/client_identity/client_identity.dart';
import '../../../core/client_identity/client_identity_provider.dart';
import '../../../core/net/dio_provider.dart';

/// What a person can be telling us.
///
/// Three, and deliberately only three. A longer list asks the person to
/// classify their own experience into our engineering categories before they
/// are allowed to say anything, which is a tax on exactly the people most
/// worth hearing from.
enum FeedbackIntent {
  problem('PROBLEM', 'Report a problem', 'Something is not working.'),
  feedback('FEEDBACK', 'Share feedback', 'How the product feels to use.'),
  idea('IDEA', 'Suggest an idea', 'Something Aura does not do yet.');

  const FeedbackIntent(this.wire, this.label, this.hint);

  final String wire;
  final String label;
  final String hint;
}

/// Where a piece of feedback got to.
enum FeedbackState {
  received('RECEIVED', 'Received'),
  reviewed('REVIEWED', 'Read'),
  actioned('ACTIONED', 'Acted on'),
  closed('CLOSED', 'Closed');

  const FeedbackState(this.wire, this.label);

  final String wire;
  final String label;

  static FeedbackState fromWire(String? raw) => values.firstWhere(
        (v) => v.wire == raw,
        orElse: () => FeedbackState.received,
      );
}

class FeedbackRecord {
  const FeedbackRecord({
    required this.id,
    required this.ref,
    required this.intent,
    required this.state,
    required this.message,
    this.outcome,
    this.submittedAt,
  });

  final String id;
  final String ref;
  final FeedbackIntent intent;
  final FeedbackState state;
  final String message;

  /// What was actually done. The only operator-written field a person sees —
  /// the internal note is not sent to this client at all.
  final String? outcome;
  final DateTime? submittedAt;

  factory FeedbackRecord.fromJson(Map<String, dynamic> json) => FeedbackRecord(
        id: (json['id'] ?? '').toString(),
        ref: (json['ref'] ?? '').toString(),
        intent: FeedbackIntent.values.firstWhere(
          (v) => v.wire == json['intent'],
          orElse: () => FeedbackIntent.feedback,
        ),
        state: FeedbackState.fromWire(json['state']?.toString()),
        message: (json['message'] ?? '').toString(),
        outcome: (json['outcome'] as String?)?.trim().isEmpty ?? true
            ? null
            : (json['outcome'] as String).trim(),
        submittedAt: DateTime.tryParse((json['submittedAt'] ?? '').toString()),
      );
}

/// THE DIAGNOSTIC CONTEXT, AND NOTHING BESIDE IT.
///
/// Everything here is about the SOFTWARE. Nothing here is about what the
/// person was doing in it. That distinction is the whole boundary: a build
/// number tells us where to look, a conversation id tells us who they were
/// talking to.
///
/// `surface` is a route PATTERN, never the path the person is on. The server
/// normalises it again regardless, because a client is not the right place for
/// that promise to be kept.
class FeedbackContext {
  const FeedbackContext({
    required this.product,
    required this.platform,
    this.appVersion,
    this.buildNumber,
    this.osVersion,
    this.surface,
    this.locale,
    this.releaseChannel,
  });

  final String product;
  final String platform;
  final String? appVersion;
  final String? buildNumber;
  final String? osVersion;
  final String? surface;
  final String? locale;
  final String? releaseChannel;

  Map<String, dynamic> toJson() => {
        'product': product,
        'platform': platform,
        if (appVersion != null) 'appVersion': appVersion,
        if (buildNumber != null) 'buildNumber': buildNumber,
        if (osVersion != null) 'osVersion': osVersion,
        if (surface != null) 'surface': surface,
        if (locale != null) 'locale': locale,
        if (releaseChannel != null) 'releaseChannel': releaseChannel,
      };

  /// Read from the client identity the app already establishes at boot, rather
  /// than gathering a second, subtly different set of build facts.
  static FeedbackContext from({
    required ClientIdentity? identity,
    required String? surface,
    required String? locale,
  }) {
    return FeedbackContext(
      product: 'aura',
      platform: identity?.platform.wireValue ?? _platformFallback(),
      appVersion: identity?.appVersion,
      buildNumber: identity?.buildNumber?.toString(),
      osVersion: _osVersion(),
      surface: surface,
      locale: locale,
      releaseChannel: identity?.channel.wireValue,
    );
  }

  static String _platformFallback() {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name;
  }

  /// The OS version string only. Never a device identifier, never a model that
  /// narrows to one person.
  static String? _osVersion() {
    if (kIsWeb) return null;
    try {
      return Platform.operatingSystemVersion;
    } catch (_) {
      return null;
    }
  }
}

class ProductFeedbackRepository {
  ProductFeedbackRepository(this._dio);

  final Dio _dio;

  Future<FeedbackRecord> submit({
    required FeedbackIntent intent,
    required String message,
    required FeedbackContext context,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/feedback',
      data: {
        'intent': intent.wire,
        'message': message,
        ...context.toJson(),
      },
    );
    return FeedbackRecord.fromJson(_unwrap(res.data));
  }

  Future<List<FeedbackRecord>> listMine() async {
    final res = await _dio.get<dynamic>('/feedback/mine');
    final body = res.data;
    final list = body is Map<String, dynamic> ? body['data'] ?? body : body;
    if (list is! List) return const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(FeedbackRecord.fromJson)
        .toList(growable: false);
  }

  Map<String, dynamic> _unwrap(Map<String, dynamic>? body) {
    if (body == null) return const {};
    final data = body['data'];
    return data is Map<String, dynamic> ? data : body;
  }
}

final productFeedbackRepositoryProvider = Provider<ProductFeedbackRepository>(
  (ref) => ProductFeedbackRepository(ref.watch(dioProvider)),
);

final myFeedbackProvider = FutureProvider<List<FeedbackRecord>>((ref) async {
  return ref.watch(productFeedbackRepositoryProvider).listMine();
});

/// The client identity, or null while it is still resolving. Feedback is never
/// blocked on it: a person with something to say should not wait on telemetry.
final feedbackClientIdentityProvider = Provider<ClientIdentity?>(
  (ref) => ref.watch(clientIdentitySnapshotProvider),
);
