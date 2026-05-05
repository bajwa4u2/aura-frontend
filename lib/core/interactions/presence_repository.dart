import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../net/dio_provider.dart';
import 'actor_context.dart';
import 'follows_repository.dart';

enum PresenceStatus { online, recent, offline }

class PresenceState {
  const PresenceState({
    required this.actorType,
    this.userId,
    this.institutionId,
    this.lastActiveAt,
    required this.status,
  });

  final ActorType actorType;
  final String? userId;
  final String? institutionId;
  final DateTime? lastActiveAt;
  final PresenceStatus status;

  static const empty = PresenceState(
    actorType: ActorType.user,
    status: PresenceStatus.offline,
  );

  factory PresenceState.fromJson(Map<String, dynamic> json) {
    final t = (json['actorType'] ?? '').toString().trim().toUpperCase();
    final s = (json['status'] ?? '').toString().trim().toUpperCase();
    return PresenceState(
      actorType:
          t == 'INSTITUTION' ? ActorType.institution : ActorType.user,
      userId: json['userId']?.toString(),
      institutionId: json['institutionId']?.toString(),
      lastActiveAt:
          DateTime.tryParse(json['lastActiveAt']?.toString() ?? ''),
      status: switch (s) {
        'ONLINE' => PresenceStatus.online,
        'RECENT' => PresenceStatus.recent,
        _ => PresenceStatus.offline,
      },
    );
  }
}

class PresenceRepository {
  PresenceRepository(this._dio);

  final Dio _dio;

  Future<PresenceState> ping(ActorRef actor) async {
    final body = <String, dynamic>{...actor.toFields('actor')};
    final res = await _dio.post('/presence/ping', data: body);
    if (res.data is Map) {
      return PresenceState.fromJson(
        Map<String, dynamic>.from(res.data as Map),
      );
    }
    return PresenceState.empty;
  }

  Future<PresenceState> getState(ActorRef actor) async {
    final query = <String, dynamic>{...actor.toQuery('actor')};
    final res = await _dio.get('/presence/state', queryParameters: query);
    if (res.data is Map) {
      return PresenceState.fromJson(
        Map<String, dynamic>.from(res.data as Map),
      );
    }
    return PresenceState.empty;
  }
}

final presenceRepositoryProvider = Provider<PresenceRepository>(
  (ref) => PresenceRepository(ref.read(dioProvider)),
);

/// Reads a target actor's presence state. Refreshed manually or by callers
/// invalidating the family entry.
final presenceStateProvider = FutureProvider.autoDispose
    .family<PresenceState, ActorRef>((ref, actor) async {
  final repo = ref.read(presenceRepositoryProvider);
  return repo.getState(actor);
});

/// Top-level provider that pings the active actor's presence on a fixed
/// cadence. Holds itself alive — register it once at app shell scope.
class PresencePinger extends StatefulWidget {
  const PresencePinger({super.key, required this.child});

  final Widget child;

  @override
  State<PresencePinger> createState() => _PresencePingerState();
}

class _PresencePingerState extends State<PresencePinger>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _ping();
    }
  }

  void _ensureTimer() {
    _timer?.cancel();
    // Heartbeat every 45s — within the 60s online window the backend uses.
    _timer = Timer.periodic(const Duration(seconds: 45), (_) => _ping());
  }

  Future<void> _ping() async {
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      final actor = container.read(activeActorContextProvider);
      if (actor == null) return;
      final actorRef = actor.isInstitution
          ? ActorRef.institution(actor.institutionId ?? '')
          : ActorRef.user(actor.userId ?? '');
      if (actorRef.id.isEmpty) return;
      await container.read(presenceRepositoryProvider).ping(actorRef);
    } catch (_) {
      // Swallow — presence is best-effort and must not crash the app.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_started) {
      _started = true;
      _ensureTimer();
      WidgetsBinding.instance.addPostFrameCallback((_) => _ping());
    }
    return widget.child;
  }
}
