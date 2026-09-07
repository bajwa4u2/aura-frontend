/// EXTERNAL SERVICE CONSUMERS — the data layer for the operator's side.
///
/// Aura Meetings is a meeting provider other systems build on. This is where an
/// operator admits one of those systems, gives it customers to act for, and
/// issues the credential it authenticates with.
///
/// WHY THIS FILE EXISTS AT ALL, written down because it is the second time:
/// the backend shipped nine governed admin endpoints for this and no client
/// ever called them. An admin API with no client surface is unreachable — the
/// permission exists, the route answers, the audit log is ready, and there is
/// no way for a person to use any of it. The same thing happened to the
/// DirectThread convergence admin API. A capability nobody can reach is
/// indistinguishable from one that was never built.
///
/// SECRETS PASS THROUGH AND ARE NOT KEPT. `showOnce` is returned by exactly two
/// calls and is never cached, never logged, never written to any store. It is
/// held in one widget's state for as long as that dialog is open, and it is
/// gone when the dialog closes. Aura keeps the API secret only as a hash, so
/// "shown again" is not a feature that could be added later — the value no
/// longer exists anywhere.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';
import 'admin_providers.dart';

// ── Models ───────────────────────────────────────────────────────────────

/// A credential, as an operator may see it. Never carries a secret.
class ExternalCredentialRow {
  const ExternalCredentialRow({
    required this.id,
    required this.keyId,
    required this.scopes,
    required this.status,
    this.createdAt,
    this.lastUsedAt,
    this.revokedAt,
    this.rotatedAt,
  });

  final String id;

  /// The public half. Safe to show, safe to log, safe to put in a support
  /// email — which is the point of splitting it from the secret.
  final String keyId;
  final List<String> scopes;
  final String status;
  final DateTime? createdAt;

  /// Whether this credential has ever been used. Null on a freshly issued one,
  /// and the single most useful field on this screen: it is how an operator
  /// tells "the customer has installed it" from "we think they have".
  final DateTime? lastUsedAt;
  final DateTime? revokedAt;
  final DateTime? rotatedAt;

  bool get isActive => status == 'ACTIVE';

  static DateTime? _date(dynamic v) =>
      // ABSOLUTE, NOT LOCAL. A data layer that applies toLocal() has
      // decided a timezone on behalf of every surface that will ever
      // render it. ProductTime.local is the single place that decision
      // belongs, and the C0 drift gate holds the line.
      v is String ? DateTime.tryParse(v) : null;

  factory ExternalCredentialRow.fromJson(Map<String, dynamic> j) {
    return ExternalCredentialRow(
      id: j['id'] as String? ?? '',
      keyId: j['keyId'] as String? ?? '',
      scopes: (j['scopes'] as List?)?.whereType<String>().toList() ?? const [],
      status: j['status'] as String? ?? 'UNKNOWN',
      createdAt: _date(j['createdAt']),
      lastUsedAt: _date(j['lastUsedAt']),
      revokedAt: _date(j['revokedAt']),
      rotatedAt: _date(j['rotatedAt']),
    );
  }
}

/// A bookable address belonging to one tenant.
class ExternalIdentityRow {
  const ExternalIdentityRow({
    required this.id,
    required this.slug,
    required this.name,
    required this.isActive,
  });

  final String id;

  /// The address itself. Immutable, and never reissued to another tenant even
  /// after retirement — which is why the UI says "retired", never "free".
  final String slug;
  final String name;
  final bool isActive;

  factory ExternalIdentityRow.fromJson(Map<String, dynamic> j) {
    return ExternalIdentityRow(
      id: j['id'] as String? ?? '',
      slug: j['slug'] as String? ?? '',
      name: j['name'] as String? ?? '',
      isActive: j['isActive'] == true,
    );
  }
}

/// One of the consumer's own customers.
class ExternalTenantRow {
  const ExternalTenantRow({
    required this.id,
    required this.externalRef,
    required this.displayName,
    required this.status,
    required this.identities,
    required this.meetingCount,
    this.defaultIdentity,
  });

  final String id;

  /// The CONSUMER's identifier for this customer, opaque to Aura. Unique per
  /// consumer and not globally: two consumers may use the same string for
  /// entirely different customers.
  final String externalRef;
  final String displayName;
  final String status;
  final List<ExternalIdentityRow> identities;
  final ExternalIdentityRow? defaultIdentity;
  final int meetingCount;

  bool get isActive => status == 'ACTIVE';

  factory ExternalTenantRow.fromJson(Map<String, dynamic> j) {
    final def = j['defaultMeetingIdentity'];
    return ExternalTenantRow(
      id: j['id'] as String? ?? '',
      externalRef: j['externalRef'] as String? ?? '',
      displayName: j['displayName'] as String? ?? '',
      status: j['status'] as String? ?? 'UNKNOWN',
      identities: (j['meetingIdentities'] as List?)
              ?.whereType<Map>()
              .map((e) => ExternalIdentityRow.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
      defaultIdentity: def is Map
          ? ExternalIdentityRow.fromJson(Map<String, dynamic>.from(def))
          : null,
      meetingCount: (j['_count'] is Map ? j['_count']['meetings'] : null) as int? ?? 0,
    );
  }
}

/// An admitted external system.
class ExternalConsumerRow {
  const ExternalConsumerRow({
    required this.id,
    required this.displayName,
    required this.status,
    required this.credentials,
    required this.meetingCount,
    required this.eventCount,
    required this.isControlledCertification,
    required this.countsTowardMarketMetrics,
    this.webhookUrl,
    this.createdAt,
  });

  final String id;
  final String displayName;
  final String status;
  final String? webhookUrl;
  final List<ExternalCredentialRow> credentials;
  final int meetingCount;
  final int eventCount;

  /// A consumer created to prove the boundary works, not one that bought
  /// anything.
  final bool isControlledCertification;

  /// The server says this on every read rather than leaving it to be
  /// remembered, and the UI repeats it for the same reason: certification
  /// traffic must never be counted as customer traffic.
  final bool countsTowardMarketMetrics;
  final DateTime? createdAt;

  bool get isActive => status == 'ACTIVE';

  ExternalCredentialRow? get activeCredential {
    for (final c in credentials) {
      if (c.isActive) return c;
    }
    return null;
  }

  factory ExternalConsumerRow.fromJson(Map<String, dynamic> j) {
    final count = j['_count'];
    return ExternalConsumerRow(
      id: j['id'] as String? ?? '',
      displayName: j['displayName'] as String? ?? '',
      status: j['status'] as String? ?? 'UNKNOWN',
      webhookUrl: j['webhookUrl'] as String?,
      credentials: (j['credentials'] as List?)
              ?.whereType<Map>()
              .map((e) => ExternalCredentialRow.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
      meetingCount: (count is Map ? count['meetings'] : null) as int? ?? 0,
      eventCount: (count is Map ? count['events'] : null) as int? ?? 0,
      isControlledCertification: j['isControlledCertification'] == true,
      countsTowardMarketMetrics: j['countsTowardMarketMetrics'] != false,
      createdAt: j['createdAt'] is String
          ? DateTime.tryParse(j['createdAt'] as String)
          : null,
    );
  }
}

/// The two values that exist exactly once.
///
/// Deliberately not a field on any model and not stored anywhere: it is
/// returned by a create or a rotate, carried to one dialog, and dropped. There
/// is no provider holding it, because a provider outlives the moment.
class ExternalShowOnce {
  const ExternalShowOnce({this.bearer, this.webhookSigningSecret, this.notice});

  /// `keyId.secret` — the whole Authorization bearer, assembled server-side so
  /// nobody has to know how to join the halves.
  final String? bearer;
  final String? webhookSigningSecret;
  final String? notice;

  bool get hasAnything => bearer != null || webhookSigningSecret != null;

  factory ExternalShowOnce.fromJson(Map<String, dynamic> j) {
    return ExternalShowOnce(
      bearer: j['bearer'] as String?,
      webhookSigningSecret: j['webhookSigningSecret'] as String?,
      notice: j['notice'] as String?,
    );
  }
}

/// What a create returns: the consumer, and the one-time values.
class ExternalConsumerCreated {
  const ExternalConsumerCreated({required this.consumerId, required this.showOnce});

  final String consumerId;
  final ExternalShowOnce showOnce;
}

// ── Repository ───────────────────────────────────────────────────────────

class OperatorExternalRepository {
  const OperatorExternalRepository(this._dio);

  final Dio _dio;

  static const String _base = '/v1/admin/external-consumers';

  static Map<String, dynamic> _map(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return const {};
  }

  /// UNWRAP AURA'S ENVELOPE. The Dio layer does not do this.
  ///
  /// Every internal Aura response is `{ok: true, data: <payload>}`, applied
  /// globally on the server and never undone on the client — `AdminRepository`
  /// reaches through `m['data']` by hand for exactly this reason. Reading a
  /// field straight off `res.data` therefore finds nothing, always, and the
  /// failure is silent: a list parses as empty and a screen renders "none"
  /// over a database that has rows.
  ///
  /// It is worse than a blank list on the write paths. `showOnce` read off the
  /// wrong level is null, so the dialog that exists to show a credential
  /// exactly once would have shown an empty box — and the secret it was
  /// holding would be gone, since Aura keeps only a hash.
  ///
  /// Tolerates an already-bare body so this stays correct if the transport
  /// ever does unwrap.
  static dynamic _body(dynamic raw) {
    if (raw is Map) {
      final m = Map<String, dynamic>.from(raw);
      if (m['ok'] == true && m.containsKey('data')) return m['data'];
    }
    return raw;
  }

  Future<List<ExternalConsumerRow>> list() async {
    final res = await _dio.get(_base);
    final rows = _map(_body(res.data))['consumers'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map((e) => ExternalConsumerRow.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<ExternalConsumerRow> detail(String consumerId) async {
    final res = await _dio.get('$_base/$consumerId');
    return ExternalConsumerRow.fromJson(_map(_body(res.data)));
  }

  Future<List<ExternalTenantRow>> tenants(String consumerId) async {
    final res = await _dio.get('$_base/$consumerId/tenants');
    final rows = _map(_body(res.data))['tenants'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map((e) => ExternalTenantRow.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Admit a consumer. Returns the only copy of its secrets there will be.
  Future<ExternalConsumerCreated> create({
    required String displayName,
    required List<String> scopes,
    String? webhookUrl,
    required bool isControlledCertification,
  }) async {
    final res = await _dio.post(_base, data: {
      'displayName': displayName,
      'scopes': scopes,
      if (webhookUrl != null && webhookUrl.trim().isNotEmpty)
        'webhookUrl': webhookUrl.trim(),
      'isControlledCertification': isControlledCertification,
    });
    final body = _map(_body(res.data));
    return ExternalConsumerCreated(
      consumerId: _map(body['consumer'])['id'] as String? ?? '',
      showOnce: ExternalShowOnce.fromJson(_map(body['showOnce'])),
    );
  }

  /// Issue a new credential. The old one keeps working until it is revoked —
  /// that overlap is the whole point, so a customer can install the new one
  /// before the old stops.
  Future<ExternalShowOnce> rotate({
    required String consumerId,
    required List<String> scopes,
    String? supersedesCredentialId,
  }) async {
    final res = await _dio.post('$_base/$consumerId/credentials/rotate', data: {
      'scopes': scopes,
      if (supersedesCredentialId != null)
        'supersedesCredentialId': supersedesCredentialId,
    });
    return ExternalShowOnce.fromJson(_map(_map(_body(res.data))['showOnce']));
  }

  Future<void> revoke({
    required String consumerId,
    required String credentialId,
  }) async {
    await _dio.post('$_base/$consumerId/credentials/$credentialId/revoke');
  }

  /// Setting a webhook mints a NEW signing secret, so this returns show-once
  /// too. Changing the URL and keeping the old secret is not offered: a
  /// destination change is exactly when the secret should not be reused.
  Future<ExternalShowOnce> setWebhook({
    required String consumerId,
    required String? webhookUrl,
  }) async {
    final res = await _dio.post('$_base/$consumerId/webhook', data: {
      'webhookUrl': webhookUrl,
    });
    final once = _map(_body(res.data))['showOnce'];
    if (once is! Map) return const ExternalShowOnce();
    return ExternalShowOnce.fromJson(Map<String, dynamic>.from(once));
  }

  Future<void> setStatus({
    required String consumerId,
    required String status,
  }) async {
    await _dio.post('$_base/$consumerId/status', data: {'status': status});
  }

  /// Idempotent on `externalRef`: provisioning the same customer twice is a
  /// retry, not a second customer.
  Future<ExternalTenantRow> provisionTenant({
    required String consumerId,
    required String externalRef,
    required String displayName,
  }) async {
    final res = await _dio.post('$_base/$consumerId/tenants', data: {
      'externalRef': externalRef,
      'displayName': displayName,
    });
    return ExternalTenantRow.fromJson(_map(_map(_body(res.data))['tenant']));
  }

  Future<ExternalIdentityRow> provisionIdentity({
    required String consumerId,
    required String tenantRef,
    required String address,
    required String assignedHostUserId,
    String? meetingTitle,
    int? durationMinutes,
    String? timezone,
  }) async {
    final res = await _dio.post(
      '$_base/$consumerId/tenants/$tenantRef/identities',
      data: {
        'address': address,
        'assignedHostUserId': assignedHostUserId,
        if (meetingTitle != null && meetingTitle.trim().isNotEmpty)
          'meetingTitle': meetingTitle.trim(),
        if (durationMinutes != null) 'durationMinutes': durationMinutes,
        if (timezone != null && timezone.trim().isNotEmpty) 'timezone': timezone.trim(),
      },
    );
    return ExternalIdentityRow.fromJson(_map(_map(_body(res.data))['identity']));
  }
}

// ── Providers ────────────────────────────────────────────────────────────

final operatorExternalRepositoryProvider = Provider<OperatorExternalRepository>(
  (ref) => OperatorExternalRepository(ref.watch(dioProvider)),
);

/// Gated on `adminMeProvider` like every other operator read, so a signed-in
/// non-operator never issues the request at all — which is what stops a route
/// change writing an `admin.access.denied` audit entry.
final operatorExternalConsumersProvider =
    FutureProvider<List<ExternalConsumerRow>>((ref) async {
  final me = await ref.watch(adminMeProvider.future);
  if (me == null) return const [];
  return ref.watch(operatorExternalRepositoryProvider).list();
});

final operatorExternalTenantsProvider =
    FutureProvider.family<List<ExternalTenantRow>, String>((ref, consumerId) async {
  final me = await ref.watch(adminMeProvider.future);
  if (me == null) return const [];
  return ref.watch(operatorExternalRepositoryProvider).tenants(consumerId);
});
