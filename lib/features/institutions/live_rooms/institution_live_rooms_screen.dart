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
import '../ui/institution_ds.dart';
import 'institution_session_meta.dart';

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
        error: (e, _) => InsScreen(
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

  Future<void> _startSessionFlow() async {
    if (_starting) return;
    final picked = await showModalBottomSheet<_StartSessionResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AuraSurface.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AuraRadius.lg)),
      ),
      builder: (ctx) => const _StartSessionSheet(),
    );
    if (picked == null) return;

    setState(() {
      _starting = true;
      _error = null;
    });

    try {
      final repo = ref.read(institutionsRepositoryProvider);
      final result = await repo.startInstitutionLiveRoom(
        widget.institutionId,
        kind: picked.kind,
      );
      widget.onRefresh();

      final session = result['session'] is Map
          ? Map<String, dynamic>.from(result['session'] as Map)
          : result;
      final sessionId = (session['id'] ?? '').toString().trim();

      // Persist the picker output keyed by sessionId so the room list and
      // the realtime room screen can render the institutional context
      // (type + audience + title). Frontend-only — backend
      // `startInstitutionLiveRoom` does not accept metadata today.
      if (sessionId.isNotEmpty) {
        await InsSessionMetaCache.save(
          sessionId,
          InsSessionMeta(
            type: picked.type,
            audience: picked.audience,
            title: picked.title,
          ),
        );
      }

      if (sessionId.isNotEmpty && mounted) {
        // Pass type/audience/title via query params so the realtime room
        // screen can show the in-session header even before the cache
        // round-trips.
        final qp = <String, String>{
          'action': 'join',
          'returnTo': '/institution/live-rooms',
          'sessionType': picked.type.wire,
          'sessionAudience': picked.audience.wire,
          if (picked.title != null && picked.title!.trim().isNotEmpty)
            'sessionTitle': picked.title!.trim(),
        };
        final qs = qp.entries
            .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
            .join('&');
        context.push('/realtime/$sessionId?$qs');
      }
    } catch (e) {
      setState(() => _error = 'Could not start session: $e');
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _joinRoom(String sessionId) async {
    try {
      final repo = ref.read(institutionsRepositoryProvider);
      await repo.joinInstitutionLiveRoom(widget.institutionId, sessionId);
      // If we have locally-cached session meta for this room, propagate
      // it via query params so the realtime room header can render the
      // institutional context immediately on join.
      final meta = await InsSessionMetaCache.read(sessionId);
      if (mounted) {
        final qp = <String, String>{
          'action': 'join',
          'returnTo': '/institution/live-rooms',
          if (meta != null) 'sessionType': meta.type.wire,
          if (meta != null) 'sessionAudience': meta.audience.wire,
          if (meta != null && (meta.title?.trim().isNotEmpty ?? false))
            'sessionTitle': meta.title!.trim(),
        };
        final qs = qp.entries
            .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
            .join('&');
        context.push('/realtime/$sessionId?$qs');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not join room: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.identity?.isAdmin ?? false;

    Widget? primaryAction;
    if (isAdmin) {
      primaryAction = AuraPrimaryButton(
        label: _starting ? 'Starting…' : 'Start session',
        icon: Icons.podcasts_rounded,
        onPressed: _starting ? null : _startSessionFlow,
      );
    }

    return InsScreen(
      children: [
        InsModeHeader(
          title: 'Live Sessions',
          description:
              'Host internal meetings, public briefings, classes, hearings, and broadcasts.',
          primaryAction: primaryAction,
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

        const InsModeHeaderGap(),

        // Live invite cards (incoming/outgoing ringing) — handled by the
        // institution live invite widget; auto-dismisses on TTL.
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
          InsEmptyState(
            icon: Icons.radio_outlined,
            title: 'No live rooms',
            description: isAdmin
                ? 'Start a live audio or video room from the action above to host members, briefings, or public sessions.'
                : 'No live rooms are active right now. Check back later.',
          ),
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

class _RoomCard extends ConsumerStatefulWidget {
  const _RoomCard({
    required this.session,
    required this.isActive,
    required this.onJoin,
  });

  final Map<String, dynamic> session;
  final bool isActive;
  final VoidCallback onJoin;

  @override
  ConsumerState<_RoomCard> createState() => _RoomCardState();
}

class _RoomCardState extends ConsumerState<_RoomCard> {
  static const Color _accent = Color(0xFF0D9488);
  static const Color _accentSoft = Color(0x1E0D9488);

  /// Locally-cached session metadata (type/audience/title). Async-loaded
  /// because `SharedPreferences` is async; the card renders the kind-only
  /// fallback while the lookup is in flight.
  InsSessionMeta? _meta;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  @override
  void didUpdateWidget(covariant _RoomCard old) {
    super.didUpdateWidget(old);
    final oldId = (old.session['id'] ?? '').toString();
    final newId = (widget.session['id'] ?? '').toString();
    if (oldId != newId) _loadMeta();
  }

  Future<void> _loadMeta() async {
    final id = (widget.session['id'] ?? '').toString();
    final m = await InsSessionMetaCache.read(id);
    if (mounted) setState(() => _meta = m);
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final isActive = widget.isActive;
    final kind = (session['kind'] ?? '').toString().toUpperCase();
    final status = (session['status'] ?? '').toString().toUpperCase();
    final participantCount = session['participantCount'] ?? 0;

    // Title resolution — prefer the locally-cached session title (set by
    // the host at start time), fall back to the meta type label, then to
    // the server-provided title (legacy rooms), then to "Live session".
    final serverTitle = (session['title'] ?? '').toString().trim();
    final title = (_meta?.title?.trim().isNotEmpty ?? false)
        ? _meta!.title!.trim()
        : (_meta != null
            ? _meta!.type.label
            : (serverTitle.isNotEmpty ? serverTitle : 'Live session'));

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
                _SessionEyebrow(meta: _meta),
                if (_meta != null) const SizedBox(height: 2),
                Text(title, style: AuraText.body.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: AuraSpace.s4),
                _InstitutionTrustLine(
                  identity: ref.watch(institutionIdentityProvider),
                ),
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
              onPressed: widget.onJoin,
            ),
        ],
      ),
    );
  }
}

/// `[SESSION TYPE] • [Audience]` eyebrow rendered above the session title.
/// Renders nothing for legacy rooms with no cached meta — keeping their
/// original layout intact.
class _SessionEyebrow extends StatelessWidget {
  const _SessionEyebrow({required this.meta});

  final InsSessionMeta? meta;

  @override
  Widget build(BuildContext context) {
    if (meta == null) return const SizedBox.shrink();
    return Text(
      '${meta!.type.label.toUpperCase()} • ${meta!.audience.label}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AuraText.micro.copyWith(
        color: AuraSurface.faint,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.7,
        fontSize: 10,
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
    final bool showDot;

    if (isActive) {
      bg = AuraSurface.goodBg;
      ink = AuraSurface.goodInk;
      // Phase 3 — "Live now" reads as event-presence rather than just
      // a transport-level status. The leading dot is the only indicator
      // we ship; no animation libraries.
      label = 'Live now';
      showDot = true;
    } else if (status == 'ENDED') {
      bg = AuraSurface.subtle;
      ink = AuraSurface.faint;
      label = 'Ended';
      showDot = false;
    } else {
      bg = AuraSurface.subtle;
      ink = AuraSurface.muted;
      label = status.isNotEmpty ? status : 'Unknown';
      showDot = false;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: showDot ? AuraSpace.s8 : AuraSpace.s8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: ink,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: AuraText.micro.copyWith(
              color: ink,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Start-session bottom sheet — captures type, audience, and AUDIO/VIDEO kind
// before the host actually creates the room. The host has to feel they are
// "running a session", not opening a generic call.
// ─────────────────────────────────────────────────────────────────────────────

class _StartSessionResult {
  const _StartSessionResult({
    required this.type,
    required this.audience,
    required this.kind,
    this.title,
  });

  final InsSessionType type;
  final InsSessionAudience audience;

  /// Wire kind for the existing `startInstitutionLiveRoom` endpoint —
  /// 'AUDIO' or 'VIDEO'. Picked inside the sheet.
  final String kind;
  final String? title;
}

class _StartSessionSheet extends StatefulWidget {
  const _StartSessionSheet();

  @override
  State<_StartSessionSheet> createState() => _StartSessionSheetState();
}

enum _SheetStep { configure, review }

class _StartSessionSheetState extends State<_StartSessionSheet> {
  InsSessionType _type = InsSessionType.internalMeeting;
  late InsSessionAudience _audience = _type.defaultAudience;
  String _kind = 'VIDEO';
  final _titleCtrl = TextEditingController();
  _SheetStep _step = _SheetStep.configure;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  void _selectType(InsSessionType t) {
    setState(() {
      _type = t;
      _audience = t.defaultAudience;
    });
  }

  /// Resolved title shown on the review step. Falls back to the type's
  /// label when the host left the field empty so every session has a
  /// visible headline ("Public Briefing", "Internal Meeting", etc.).
  String get _effectiveTitle {
    final t = _titleCtrl.text.trim();
    if (t.isNotEmpty) return t;
    return _type.label;
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AuraSpace.s20,
            AuraSpace.s20,
            AuraSpace.s20,
            AuraSpace.s20,
          ),
          child: _step == _SheetStep.configure
              ? _buildConfigure()
              : _buildReview(),
        ),
      ),
    );
  }

  Widget _buildConfigure() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Drag handle
        Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AuraSurface.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: AuraSpace.s14),
        const Text('Start session', style: AuraText.headline),
        const SizedBox(height: AuraSpace.s6),
        Text(
          'Pick the kind of institutional session you’re hosting. '
          'Members and the public see this on the room and in-session.',
          style: AuraText.body.copyWith(color: AuraSurface.muted, height: 1.5),
        ),
        const SizedBox(height: AuraSpace.s20),

        const _SheetEyebrow(label: 'SESSION TYPE'),
        const SizedBox(height: AuraSpace.s8),
        Wrap(
          spacing: AuraSpace.s8,
          runSpacing: AuraSpace.s8,
          children: [
            for (final t in InsSessionType.values)
              _SheetChip(
                label: t.label,
                selected: _type == t,
                onTap: () => _selectType(t),
              ),
          ],
        ),
        const SizedBox(height: AuraSpace.s18),

        const _SheetEyebrow(label: 'AUDIENCE'),
        const SizedBox(height: AuraSpace.s8),
        Row(
          children: [
            for (final a in InsSessionAudience.values)
              Padding(
                padding: const EdgeInsets.only(right: AuraSpace.s8),
                child: _SheetChip(
                  label: a.label,
                  selected: _audience == a,
                  onTap: () => setState(() => _audience = a),
                ),
              ),
          ],
        ),
        const SizedBox(height: AuraSpace.s18),

        const _SheetEyebrow(label: 'CHANNEL'),
        const SizedBox(height: AuraSpace.s8),
        Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: AuraSpace.s8),
              child: _SheetChip(
                label: 'Audio',
                selected: _kind == 'AUDIO',
                onTap: () => setState(() => _kind = 'AUDIO'),
              ),
            ),
            _SheetChip(
              label: 'Video',
              selected: _kind == 'VIDEO',
              onTap: () => setState(() => _kind = 'VIDEO'),
            ),
          ],
        ),
        const SizedBox(height: AuraSpace.s18),

        const _SheetEyebrow(label: 'SESSION TITLE (OPTIONAL)'),
        const SizedBox(height: AuraSpace.s8),
        TextField(
          controller: _titleCtrl,
          style: AuraText.body,
          decoration: InputDecoration(
            hintText: 'e.g. "City Infrastructure Update"',
            isDense: true,
            filled: true,
            fillColor: AuraSurface.subtle,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AuraRadius.md),
              borderSide: const BorderSide(color: AuraSurface.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AuraRadius.md),
              borderSide: const BorderSide(color: AuraSurface.divider),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.s12,
              vertical: AuraSpace.s10,
            ),
          ),
        ),

        const SizedBox(height: AuraSpace.s20),
        Row(
          children: [
            Expanded(
              child: AuraSecondaryButton(
                label: 'Cancel',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: AuraSpace.s10),
            Expanded(
              child: AuraPrimaryButton(
                label: 'Review',
                icon: Icons.arrow_forward_rounded,
                onPressed: () =>
                    setState(() => _step = _SheetStep.review),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Pre-session summary — prevents accidental sessions and reinforces
  /// the institutional weight of the action. Host sees TYPE, AUDIENCE,
  /// CHANNEL, TITLE before the room is actually created.
  Widget _buildReview() {
    final isPublic = _audience == InsSessionAudience.publicAudience;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AuraSurface.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: AuraSpace.s14),
        const Text('Review session', style: AuraText.headline),
        const SizedBox(height: AuraSpace.s6),
        Text(
          'Confirm the session details before starting. '
          'Participants will see this throughout the call.',
          style: AuraText.body.copyWith(color: AuraSurface.muted, height: 1.5),
        ),
        const SizedBox(height: AuraSpace.s20),

        Container(
          padding: const EdgeInsets.all(AuraSpace.s14),
          decoration: BoxDecoration(
            color: AuraSurface.subtle,
            borderRadius: BorderRadius.circular(AuraRadius.card),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_type.label.toUpperCase()} • ${_audience.label}',
                style: AuraText.micro.copyWith(
                  color: isPublic
                      ? AuraSurface.accentText
                      : AuraSurface.faint,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: AuraSpace.s6),
              Text(
                _effectiveTitle,
                style: AuraText.subtitle
                    .copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AuraSpace.s10),
              // Phase 3 — explicit intent line. Reads back the host's
              // configuration as a sentence so the consequence of
              // tapping Start is unambiguous.
              Text(
                'You are about to start a ${_type.label} '
                'for ${_audience.label} audience.',
                style: AuraText.small.copyWith(
                  color: AuraSurface.muted,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: AuraSpace.s10),
              _ReviewRow(
                icon: _kind == 'VIDEO'
                    ? Icons.videocam_rounded
                    : Icons.mic_rounded,
                label: _kind == 'VIDEO' ? 'Video session' : 'Audio session',
              ),
              const SizedBox(height: 6),
              _ReviewRow(
                icon: isPublic
                    ? Icons.public_rounded
                    : Icons.lock_outline_rounded,
                label: isPublic
                    ? 'Visible to anyone joining'
                    : 'Internal — institution members only',
              ),
            ],
          ),
        ),

        const SizedBox(height: AuraSpace.s20),
        Row(
          children: [
            Expanded(
              child: AuraSecondaryButton(
                label: 'Back',
                icon: Icons.arrow_back_rounded,
                onPressed: () =>
                    setState(() => _step = _SheetStep.configure),
              ),
            ),
            const SizedBox(width: AuraSpace.s10),
            Expanded(
              child: AuraPrimaryButton(
                label: 'Start',
                icon: Icons.podcasts_rounded,
                onPressed: () {
                  final title = _titleCtrl.text.trim();
                  Navigator.of(context).pop(
                    _StartSessionResult(
                      type: _type,
                      audience: _audience,
                      kind: _kind,
                      // Persist null when the field was empty so the
                      // SessionMeta.displayTitle fallback can substitute
                      // the type label later — the meta layer is the
                      // single source of truth for "title always exists".
                      title: title.isEmpty ? null : title,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AuraSurface.muted),
        const SizedBox(width: AuraSpace.s8),
        Expanded(
          child: Text(
            label,
            style: AuraText.small.copyWith(color: AuraSurface.muted),
          ),
        ),
      ],
    );
  }
}

class _SheetEyebrow extends StatelessWidget {
  const _SheetEyebrow({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AuraText.micro.copyWith(
        color: AuraSurface.faint,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        fontSize: 10,
      ),
    );
  }
}

class _SheetChip extends StatelessWidget {
  const _SheetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AuraRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s12,
          vertical: AuraSpace.s8,
        ),
        decoration: BoxDecoration(
          color: selected ? AuraSurface.accentSoft : AuraSurface.subtle,
          borderRadius: BorderRadius.circular(AuraRadius.pill),
          border: Border.all(
            color: selected
                ? AuraSurface.accent.withValues(alpha: 0.4)
                : AuraSurface.divider,
          ),
        ),
        child: Text(
          label,
          style: AuraText.small.copyWith(
            color: selected ? AuraSurface.accentText : AuraSurface.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Compact trust line rendered on every live-room card under the title.
/// Phase 3: explicitly framed as "Hosted by …" so the card reads as an
/// event with a host, not just a generic call. Verified glyph still
/// trails the name when the institution is verified. Renders nothing
/// when identity is missing.
class _InstitutionTrustLine extends StatelessWidget {
  const _InstitutionTrustLine({required this.identity});

  final InstitutionIdentity? identity;

  @override
  Widget build(BuildContext context) {
    final id = identity;
    if (id == null) return const SizedBox.shrink();
    final name = id.name.trim();
    if (name.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.apartment_rounded,
          size: 11,
          color: AuraSurface.faint,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            'Hosted by $name',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AuraText.micro.copyWith(
              color: AuraSurface.faint,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (id.isVerified) ...[
          const SizedBox(width: 4),
          const Icon(
            Icons.verified_rounded,
            size: 11,
            color: AuraSurface.accentText,
          ),
        ],
      ],
    );
  }
}

