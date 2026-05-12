import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_providers.dart';
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
/// cadence. Mounted once at app shell scope.
///
/// LIFECYCLE OWNERSHIP (why this widget has a `_generation` counter):
///
/// The heartbeat must run ONLY while the user is signed in. Earlier
/// versions started a periodic timer on first build and never reacted
/// to auth changes — when the access token went away (cookie expired,
/// refresh failed, logout, account switch), the timer kept firing and
/// `/v1/presence/ping` returned 401 every 45 seconds, filling the
/// network panel with auth noise. Worse, an in-flight ping that
/// returned AFTER a logout could touch state belonging to the previous
/// session.
///
/// The widget now:
///   * Watches `isAuthedProvider` and treats auth==true as the only
///     condition that arms the heartbeat. Any flip away (logout, token
///     clear, refresh failure that drops the access token) cancels the
///     timer in the same frame.
///   * Stamps every `_ping()` invocation with the current `_generation`.
///     Lifecycle events (auth flip, dispose) bump the generation; an
///     in-flight ping that completes against a stale generation drops
///     its result silently — it cannot re-arm the timer, cannot
///     re-trigger logging, cannot affect the next user's session.
///   * On a 401 from `/presence/ping`, cancels the timer immediately.
///     The existing Dio refresh interceptor handles real session
///     recovery; the pinger does not retry. One 401, then silent.
///   * On app resume, only re-pings when a live timer is in place —
///     never speculatively creates a new timer.
class PresencePinger extends ConsumerStatefulWidget {
  const PresencePinger({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PresencePinger> createState() => _PresencePingerState();
}

class _PresencePingerState extends ConsumerState<PresencePinger>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _disposed = false;

  /// Incremented on every meaningful state transition (auth flip,
  /// dispose). In-flight pings that started under an older generation
  /// silently drop their results on completion so they cannot reach
  /// across a session boundary.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++; // invalidate any in-flight ping
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only nudge presence on resume when the heartbeat is already
    // running. Resuming a backgrounded signed-out tab must NOT start a
    // new timer or fire a ping.
    if (state == AppLifecycleState.resumed && _timer != null) {
      _ping(_generation);
    }
  }

  void _start() {
    if (_disposed) return;
    if (_timer != null) return; // idempotent
    // Heartbeat every 45s — within the 60s online window the backend
    // uses. The first ping is scheduled post-frame so we don't race
    // with the initial provider settle.
    _timer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => _ping(_generation),
    );
    final gen = _generation;
    WidgetsBinding.instance.addPostFrameCallback((_) => _ping(gen));
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _ping(int gen) async {
    // Generation guard — if state has moved on, drop the call before
    // it leaves the process.
    if (_disposed || gen != _generation) return;
    final container = ProviderScope.containerOf(context, listen: false);
    // Defensive: if the auth provider says we're signed out by the time
    // a delayed timer tick fires, refuse the request entirely.
    if (!container.read(isAuthedProvider)) {
      _stop();
      return;
    }
    final actor = container.read(activeActorContextProvider);
    if (actor == null) return;
    final actorRef = actor.isInstitution
        ? ActorRef.institution(actor.institutionId ?? '')
        : ActorRef.user(actor.userId ?? '');
    if (actorRef.id.isEmpty) return;
    try {
      await container.read(presenceRepositoryProvider).ping(actorRef);
    } on DioException catch (e) {
      // Generation may have advanced while the request was in flight
      // (e.g. user signed out mid-request). Honor that first.
      if (_disposed || gen != _generation) return;
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        // Auth dropped — stop pinging immediately. The Dio refresh
        // interceptor will drive session recovery; if the user signs
        // back in, the auth-watcher in build() re-arms the timer.
        _stop();
      }
      // Other failures are best-effort: the next tick will retry.
    } catch (_) {
      // Non-Dio errors are silent — presence is best-effort.
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAuthed = ref.watch(isAuthedProvider);

    // React to auth flips at the same priority as the rest of the
    // build. listen() fires once per transition; the build itself sets
    // the desired arm/disarm state on first mount.
    ref.listen<bool>(isAuthedProvider, (prev, next) {
      _generation++; // any transition invalidates in-flight pings
      if (next) {
        _start();
      } else {
        _stop();
      }
    });

    // First-mount arm: listen() does not fire for the initial value, so
    // we make the desired state explicit here.
    if (isAuthed && _timer == null && !_disposed) {
      _start();
    } else if (!isAuthed && _timer != null) {
      _generation++;
      _stop();
    }

    return widget.child;
  }
}
