import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../realtime/application/realtime_providers.dart';

/// The active meeting a user has open somewhere in the app: the live-room
/// route to return to and a display title. Set by the live room on mount,
/// cleared on leave/end. The pill ALSO requires the realtime controller to
/// still be joined, so a stale entry can never show a dead pill.
final activeMeetingReturnProvider =
    StateProvider<({String path, String title})?>((ref) => null);

/// Persistent-session UX: while a meeting is live and the user navigates
/// anywhere else inside Aura, a floating pill keeps the meeting present —
/// the session is never "abandoned", it is one tap away.
class ActiveMeetingReturnLayer extends ConsumerWidget {
  final Widget child;

  const ActiveMeetingReturnLayer({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(activeMeetingReturnProvider);
    final joined = ref.watch(
      realtimeControllerProvider.select((s) => s.isJoined),
    );
    final path = GoRouterState.of(context).uri.path;
    final onLiveSurface =
        path.contains('/meetings/') && path.endsWith('/live');

    final show = entry != null && joined && !onLiveSurface;

    return Stack(
      children: [
        child,
        if (show)
          Positioned(
            left: 0,
            right: 0,
            bottom: 18,
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => context.go(entry.path),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xF00F172A),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.55),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 220),
                          child: Text(
                            entry.title.isEmpty
                                ? 'Meeting in progress'
                                : entry.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Return',
                          style: TextStyle(
                            color: Color(0xFF34D399),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.chevron_right_rounded,
                            size: 18, color: Color(0xFF34D399)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
