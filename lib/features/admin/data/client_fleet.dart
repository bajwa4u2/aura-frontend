/// THE RELEASED-CLIENT FLEET.
///
/// This authority was fully built server-side — seven endpoints under
/// `admin/clients` covering distributions, channels, versions, protocols,
/// capabilities and incompatible attempts — and consumed by NOTHING. The
/// client repository had never heard of it. Aura could tell you what its
/// released clients were doing and no operator could see the answer.
///
/// It matters most right now: Aura ships four clients, the identity and
/// continuation work both carry release consequences, and "which versions are
/// actually out there" is the question those consequences turn on.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';

class FleetDistribution {
  const FleetDistribution({
    required this.distribution,
    required this.channel,
    required this.count,
    required this.percentage,
  });

  final String distribution;
  final String channel;
  final int count;
  final double percentage;

  factory FleetDistribution.fromJson(Map<String, dynamic> j) =>
      FleetDistribution(
        distribution: j['distribution']?.toString() ?? 'unknown',
        channel: j['channel']?.toString() ?? 'unknown',
        count: (j['count'] as num?)?.toInt() ?? 0,
        percentage: (j['percentage'] as num?)?.toDouble() ?? 0,
      );
}

class FleetVersion {
  const FleetVersion({
    required this.distribution,
    required this.channel,
    required this.appVersion,
    required this.count,
    required this.percentage,
    required this.staleVsRecommended,
  });

  final String distribution;
  final String channel;

  /// Null when a client did not report one. Shown as unknown rather than
  /// guessed at.
  final String? appVersion;
  final int count;
  final double percentage;
  final bool staleVsRecommended;

  factory FleetVersion.fromJson(Map<String, dynamic> j) => FleetVersion(
        distribution: j['distribution']?.toString() ?? 'unknown',
        channel: j['channel']?.toString() ?? 'unknown',
        appVersion: j['appVersion']?.toString(),
        count: (j['count'] as num?)?.toInt() ?? 0,
        percentage: (j['percentage'] as num?)?.toDouble() ?? 0,
        staleVsRecommended: j['isStaleVsRecommended'] == true,
      );
}

class FleetIncompatible {
  const FleetIncompatible({
    required this.distribution,
    required this.channel,
    required this.count,
  });

  final String distribution;
  final String channel;
  final int count;

  factory FleetIncompatible.fromJson(Map<String, dynamic> j) =>
      FleetIncompatible(
        distribution: j['distribution']?.toString() ?? 'unknown',
        channel: j['channel']?.toString() ?? 'unknown',
        count: (j['count'] as num?)?.toInt() ?? 0,
      );
}

class FleetStale {
  const FleetStale({
    required this.distribution,
    required this.channel,
    required this.totalCount,
    required this.staleCount,
    required this.stalePercentage,
  });

  final String distribution;
  final String channel;
  final int totalCount;
  final int staleCount;
  final double stalePercentage;

  factory FleetStale.fromJson(Map<String, dynamic> j) => FleetStale(
        distribution: j['distribution']?.toString() ?? 'unknown',
        channel: j['channel']?.toString() ?? 'unknown',
        totalCount: (j['totalCount'] as num?)?.toInt() ?? 0,
        staleCount: (j['staleCount'] as num?)?.toInt() ?? 0,
        stalePercentage: (j['stalePercentage'] as num?)?.toDouble() ?? 0,
      );
}

class ClientFleet {
  const ClientFleet({
    required this.windowHours,
    required this.totalObservations,
    required this.uniqueClients,
    required this.distributions,
    required this.versions,
    required this.incompatible,
    required this.stale,
  });

  final int windowHours;
  final int totalObservations;
  final int uniqueClients;
  final List<FleetDistribution> distributions;
  final List<FleetVersion> versions;
  final List<FleetIncompatible> incompatible;
  final List<FleetStale> stale;

  /// True when nothing has been observed at all — different from a healthy
  /// fleet, and the console must not report it as one.
  bool get isSilent => totalObservations == 0;

  static List<T> _list<T>(dynamic raw, T Function(Map<String, dynamic>) parse) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => parse(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  factory ClientFleet.fromJson(Map<String, dynamic> j) => ClientFleet(
        windowHours: (j['windowHours'] as num?)?.toInt() ?? 0,
        totalObservations: (j['totalObservations'] as num?)?.toInt() ?? 0,
        uniqueClients: (j['uniqueClientFingerprints'] as num?)?.toInt() ?? 0,
        distributions: _list(j['byDistribution'], FleetDistribution.fromJson),
        versions: _list(j['byVersion'], FleetVersion.fromJson),
        incompatible:
            _list(j['incompatibleAttempts'], FleetIncompatible.fromJson),
        stale: _list(j['stalePercentageByDistribution'], FleetStale.fromJson),
      );
}

class ClientFleetRepository {
  const ClientFleetRepository(this._dio);

  final Dio _dio;

  Future<ClientFleet> overview({int windowHours = 168}) async {
    final res = await _dio.get(
      '/v1/admin/clients/overview',
      queryParameters: {'windowHours': windowHours},
    );
    final data = res.data;
    return ClientFleet.fromJson(
      data is Map ? Map<String, dynamic>.from(data) : const {},
    );
  }
}

final clientFleetRepositoryProvider = Provider<ClientFleetRepository>((ref) {
  return ClientFleetRepository(ref.watch(dioProvider));
});

/// A one-week window by default: long enough that a weekend does not look like
/// a dead fleet, short enough to reflect a release.
final clientFleetProvider =
    FutureProvider.autoDispose<ClientFleet>((ref) async {
  return ref.watch(clientFleetRepositoryProvider).overview();
});
