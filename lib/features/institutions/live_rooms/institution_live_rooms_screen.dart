import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/institutions_repository.dart';
import '../live/institution_live_invite_widget.dart';

final _institutionLiveRoomsProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, institutionId) async {
  final repo = ref.watch(institutionsRepositoryProvider);
  return repo.listInstitutionLiveRooms(institutionId);
});

class InstitutionLiveRoomsScreen extends ConsumerWidget {
  const InstitutionLiveRoomsScreen({
    super.key,
    required this.institutionId,
  });

  final String institutionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(institutionIdentityProvider);
    final roomsAsync = ref.watch(_institutionLiveRoomsProvider(institutionId));

    return AuraScaffold(
      showHeader: false,
      body: roomsAsync.when(
        loading: () => const AuraLoadingState(message: 'Loading live rooms…'),
        error: (e, _) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AuraSpace.s16,
            AuraSpace.s20,
            AuraSpace.s16,
            AuraSpace.s32,
          ),
          children: [
            AuraErrorState(
              title: 'Failed to load rooms',
              body: '$e',
              action: AuraSecondaryButton(
                label: 'Try again',
                onPressed: () => ref.invalidate(_institutionLiveRoomsProvider(institutionId)),
                icon: Icons.refresh_rounded,
              ),
            ),
          ],
        ),
        data: (data) {
          final sessions = _readList(data['sessions']);
          final activeSession = data['activeSession'];

          return _LiveRoomsBody(
            institutionId: institutionId,
            identity: identity,
            sessions: sessions,
            activeSession: activeSession is Map
                ? Map<String, dynamic>.from(activeSession)
                : null,
            onRefresh: () => ref.invalidate(_institutionLiveRoomsProvider(institutionId)),
          );
        },
      ),
    );
  }

  static List<Map<String, dynamic>> _readList(dynamic val) {
    if (val is List) {
      return val.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }
}

class _LiveRoomsBody extends ConsumerStatefulWidget {
  const _LiveRoomsBody({
    required this.institutionId,
    required this.identity,
    required this.sessions,
    required this.activeSession,
    required this.onRefresh,
  });

  final String institutionId;
  final InstitutionIdentity? identity;
  final List<Map<String, dynamic>> sessions;
  final Map<String, dynamic>? activeSession;
  final VoidCallback onRefresh;

  @override
  ConsumerState<_LiveRoomsBody> createState() => _LiveRoomsBodyState();
}

class _LiveRoomsBodyState extends ConsumerState<_LiveRoomsBody> {
  bool _starting = false;
  String? _error;

  Future<void> _startRoom(String kind) async {
    setState(() {
      _starting = true;
      _error = null;
    });

    try {
      final repo = ref.read(institutionsRepositoryProvider);
      final result = await repo.startInstitutionLiveRoom(
        widget.institutionId,
        kind: kind,
      );
      widget.onRefresh();

      final session = result['session'] is Map
          ? Map<String, dynamic>.from(result['session'] as Map)
          : result;
      final sessionId = (session['id'] ?? '').toString().trim();
      if (sessionId.isNotEmpty && mounted) {
        context.push('/realtime/$sessionId?action=join&returnTo=/institution/live-rooms');
      }
    } catch (e) {
      setState(() => _error = 'Could not start room: $e');
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _joinRoom(String sessionId) async {
    try {
      final repo = ref.read(institutionsRepositoryProvider);
      await repo.joinInstitutionLiveRoom(widget.institutionId, sessionId);
      if (mounted) {
        context.push('/realtime/$sessionId?action=join&returnTo=/institution/live-rooms');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not join room: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.identity?.isAdmin ?? false;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.s16,
        AuraSpace.s20,
        AuraSpace.s16,
        AuraSpace.s32,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Live Rooms', style: AuraText.headline),
                    ),
                    if (isAdmin) ...[
                      AuraSecondaryButton(
                        label: _starting ? 'Starting…' : 'Audio room',
                        icon: Icons.mic_rounded,
                        onPressed: _starting ? null : () => _startRoom('AUDIO'),
                      ),
                      const SizedBox(width: AuraSpace.s10),
                      AuraPrimaryButton(
                        label: _starting ? 'Starting…' : 'Video room',
                        icon: Icons.videocam_rounded,
                        onPressed: _starting ? null : () => _startRoom('VIDEO'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AuraSpace.s6),
                Text(
                  'Live audio and video rooms for your institution workspace.',
                  style: AuraText.body.copyWith(color: AuraSurface.muted),
                ),

                if (_error != null) ...[
                  const SizedBox(height: AuraSpace.s14),
                  Container(
                    padding: const EdgeInsets.all(AuraSpace.s14),
                    decoration: BoxDecoration(
                      color: AuraSurface.dangerBg,
                      borderRadius: BorderRadius.circular(AuraRadius.card),
                      border: Border.all(
                        color: AuraSurface.dangerInk.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 16, color: AuraSurface.dangerInk),
                        const SizedBox(width: AuraSpace.s10),
                        Expanded(
                          child: Text(
                            _error!,
                            style: AuraText.small.copyWith(
                              color: AuraSurface.dangerInk,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: AuraSpace.s24),

                // Live invite cards (incoming/outgoing ringing) — handled by
                // the institution live invite widget; auto-dismisses on TTL.
                InstitutionLiveInviteWidget(
                  institutionId: widget.institutionId,
                ),

                if (widget.activeSession != null) ...[
                  const _SectionLabel(label: 'ACTIVE'),
                  const SizedBox(height: AuraSpace.s10),
                  _RoomCard(
                    session: widget.activeSession!,
                    isActive: true,
                    onJoin: () => _joinRoom(
                      (widget.activeSession!['id'] ?? '').toString(),
                    ),
                  ),
                  const SizedBox(height: AuraSpace.s24),
                ],

                if (widget.sessions.isEmpty && widget.activeSession == null) ...[
                  _EmptyState(isAdmin: isAdmin, onStart: () => _startRoom('AUDIO')),
                ] else ...[
                  if (widget.sessions.isNotEmpty) ...[
                    const _SectionLabel(label: 'ALL ROOMS'),
                    const SizedBox(height: AuraSpace.s10),
                    ...widget.sessions.map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(bottom: AuraSpace.s10),
                        child: _RoomCard(
                          session: s,
                          isActive: (s['status'] ?? '').toString().toUpperCase() == 'ACTIVE',
                          onJoin: () => _joinRoom((s['id'] ?? '').toString()),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AuraText.micro.copyWith(
        color: AuraSurface.faint,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.session,
    required this.isActive,
    required this.onJoin,
  });

  final Map<String, dynamic> session;
  final bool isActive;
  final VoidCallback onJoin;

  static const Color _accent = Color(0xFF0D9488);
  static const Color _accentSoft = Color(0x1E0D9488);

  @override
  Widget build(BuildContext context) {
    final title = (session['title'] ?? 'Live room').toString();
    final kind = (session['kind'] ?? '').toString().toUpperCase();
    final status = (session['status'] ?? '').toString().toUpperCase();
    final participantCount = session['participantCount'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(
          color: isActive ? _accent.withValues(alpha: 0.3) : AuraSurface.divider,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isActive ? _accentSoft : AuraSurface.subtle,
              shape: BoxShape.circle,
            ),
            child: Icon(
              kind == 'VIDEO' ? Icons.videocam_rounded : Icons.mic_rounded,
              size: 18,
              color: isActive ? _accent : AuraSurface.muted,
            ),
          ),
          const SizedBox(width: AuraSpace.s14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AuraText.body.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: AuraSpace.s4),
                Row(
                  children: [
                    _StatusChip(status: status, isActive: isActive),
                    const SizedBox(width: AuraSpace.s8),
                    if (participantCount is num && participantCount > 0) ...[
                      const Icon(Icons.people_outline_rounded,
                          size: 12, color: AuraSurface.faint),
                      const SizedBox(width: 3),
                      Text(
                        '$participantCount',
                        style: AuraText.micro.copyWith(color: AuraSurface.faint),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isActive)
            AuraPrimaryButton(
              label: 'Join',
              icon: Icons.call_rounded,
              onPressed: onJoin,
            ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.isActive});

  final String status;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color ink;
    final String label;

    if (isActive) {
      bg = AuraSurface.goodBg;
      ink = AuraSurface.goodInk;
      label = 'Live';
    } else if (status == 'ENDED') {
      bg = AuraSurface.subtle;
      ink = AuraSurface.faint;
      label = 'Ended';
    } else {
      bg = AuraSurface.subtle;
      ink = AuraSurface.muted;
      label = status.isNotEmpty ? status : 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
      ),
      child: Text(label, style: AuraText.micro.copyWith(color: ink, fontWeight: FontWeight.w700)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isAdmin, required this.onStart});

  final bool isAdmin;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s24),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        children: [
          const Icon(Icons.radio_outlined, size: 40, color: AuraSurface.faint),
          const SizedBox(height: AuraSpace.s14),
          const Text('No live rooms', style: AuraText.subtitle),
          const SizedBox(height: AuraSpace.s6),
          Text(
            isAdmin
                ? 'Start a live audio or video room for your institution members.'
                : 'No live rooms are active right now. Check back later.',
            style: AuraText.body.copyWith(color: AuraSurface.muted),
            textAlign: TextAlign.center,
          ),
          if (isAdmin) ...[
            const SizedBox(height: AuraSpace.s16),
            AuraPrimaryButton(
              label: 'Start audio room',
              icon: Icons.mic_rounded,
              onPressed: onStart,
            ),
          ],
        ],
      ),
    );
  }
}
