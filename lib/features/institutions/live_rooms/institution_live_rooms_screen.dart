import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/authority/authority_providers.dart';
import '../../../core/authority/capability_projection.dart';
import '../../../core/product/product_language.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/utils/relative_time.dart';
import '../data/institutions_repository.dart';
import '../live/institution_live_invite_widget.dart';
import '../workspace/workspace_page.dart';
import 'institution_session_meta.dart';

/// Public provider for the institution's live rooms response. Exposed
/// (renamed from the previous `_institutionLiveRoomsProvider`) so other
/// surfaces — Distribution Phase 1's "LIVE NOW" feed banner in the
/// explore screen — can reuse the same data without a parallel fetch.
final institutionLiveRoomsProvider =
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
    // Phase-7 regression fix — fail safe when this screen is rendered
    // without a real institution id. The repo otherwise throws
    // "Institution id is missing" and the user sees a red error card
    // in the workspace shell. The router-level redirect on the legacy
    // shorthand should already prevent this, but we keep the screen
    // defensive so a stale link can never produce a broken page.
    final cleanId = institutionId.trim();
    if (cleanId.isEmpty) {
      return WorkspacePage(
        type: WorkspacePageType.collection,
        title: 'Live',
        children: [
          WorkspaceEmpty(
            icon: Icons.podcasts_rounded,
            title: 'No active institution',
            body: 'Pick an institution from the workspace to view its live rooms.',
            action: WorkspaceAction(
              label: 'Open dashboard',
              icon: Icons.arrow_forward_rounded,
              onPressed: () => context.go('/institution/dashboard'),
            ),
          ),
        ],
      );
    }
    final roomsAsync = ref.watch(institutionLiveRoomsProvider(cleanId));
    final data = roomsAsync.valueOrNull;
    final activeSession = data?['activeSession'];

    return _LiveRoomsBody(
      institutionId: cleanId,
      loading: roomsAsync.isLoading && !roomsAsync.hasValue,
      loadError: roomsAsync.hasValue ? null : roomsAsync.error,
      sessions: _readList(data?['sessions']),
      activeSession: activeSession is Map ? Map<String, dynamic>.from(activeSession) : null,
      onRefresh: () => ref.invalidate(institutionLiveRoomsProvider(cleanId)),
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
    required this.loading,
    required this.loadError,
    required this.sessions,
    required this.activeSession,
    required this.onRefresh,
  });

  final String institutionId;
  final bool loading;
  final Object? loadError;
  final List<Map<String, dynamic>> sessions;
  final Map<String, dynamic>? activeSession;
  final VoidCallback onRefresh;

  @override
  ConsumerState<_LiveRoomsBody> createState() => _LiveRoomsBodyState();
}

class _LiveRoomsBodyState extends ConsumerState<_LiveRoomsBody> {
  bool _starting = false;
  String? _error;
  String _tab = 'now';

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
          'returnTo': '/institution/${widget.institutionId}/live-rooms',
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
          'returnTo': '/institution/${widget.institutionId}/live-rooms',
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

  static bool _isActive(Map<String, dynamic> s) => (s['status'] ?? '').toString().toUpperCase() == 'ACTIVE';

  @override
  Widget build(BuildContext context) {
    // C2 closeout — starting a live session is a consequential act; the
    // gate is the C1 capability projection (ConsequentialAct.startLive),
    // never a role label. Matches the backend's actual authority.
    final canStartLive = ref
            .watch(capabilityProjectionProvider)
            .presentationFor(ConsequentialAct.startLive) ==
        ControlPresentation.available;

    // Now: the active session and any other room still live. Past: the rest.
    final active = widget.activeSession;
    final activeId = (active?['id'] ?? '').toString();
    final now = <Map<String, dynamic>>[
      if (active != null) active,
      ...widget.sessions.where((s) => _isActive(s) && (s['id'] ?? '').toString() != activeId),
    ];
    final past = widget.sessions.where((s) => !_isActive(s)).toList();
    final showingNow = _tab == 'now';
    final list = showingNow ? now : past;

    final children = <Widget>[];
    if (widget.loadError != null) {
      children.add(WorkspaceEmpty(
        icon: Icons.error_outline_rounded,
        title: 'Failed to load rooms',
        body: '${widget.loadError}',
        action: WorkspaceAction(label: ProductLabels.of(ProductAction.retry), icon: Icons.refresh_rounded, onPressed: widget.onRefresh),
      ));
    } else {
      if (_error != null) {
        children.add(WorkspaceRow(
          leading: const WorkspaceIcon(Icons.error_outline_rounded, tone: WorkspaceTone.problem),
          title: _error!,
          emphasis: WorkspaceTone.problem,
          trailing: IconButton(
            tooltip: 'Dismiss',
            icon: const Icon(Icons.close_rounded, size: 18, color: AuraSurface.muted),
            onPressed: () => setState(() => _error = null),
          ),
        ));
      }
      if (showingNow) {
        // Live sessions nobody has joined yet — surfaced as "tap to join"
        // cards; dismissible per-viewer for this screen's lifetime.
        children.add(InstitutionLiveInviteWidget(institutionId: widget.institutionId));
      }
      if (list.isEmpty) {
        children.add(showingNow
            ? WorkspaceEmpty(
                icon: Icons.radio_outlined,
                title: 'No one is live',
                body: canStartLive
                    ? 'A live session is a room the institution hosts, audio or video. It appears here while it runs.'
                    : 'No active sessions.',
                action: canStartLive
                    ? WorkspaceAction(label: 'Start session', icon: Icons.podcasts_rounded, onPressed: _starting ? null : _startSessionFlow)
                    : null,
              )
            : const WorkspaceEmpty(
                icon: Icons.history_rounded,
                title: 'No past sessions',
                body: 'Sessions appear here once they end.',
              ));
      } else {
        for (final s in list) {
          children.add(_RoomRow(
            session: s,
            isActive: _isActive(s) || (s['id'] ?? '').toString() == activeId,
            onJoin: () => _joinRoom((s['id'] ?? '').toString()),
          ));
        }
      }
    }

    return WorkspacePage(
      type: WorkspacePageType.collection,
      title: 'Live',
      purpose: 'Audio and video sessions the institution hosts.',
      primary: canStartLive
          ? WorkspaceAction(
              label: _starting ? 'Starting…' : 'Start session',
              icon: Icons.podcasts_rounded,
              onPressed: _starting ? null : _startSessionFlow,
            )
          : null,
      tabs: [
        WorkspaceTab(id: 'now', label: 'Now', count: widget.loading ? null : now.length),
        WorkspaceTab(id: 'past', label: 'Past', count: widget.loading ? null : past.length),
      ],
      selectedTab: _tab,
      onTab: (id) => setState(() => _tab = id),
      loading: widget.loading,
      children: children,
    );
  }
}

/// One live room (DD-43): what it is, who it is for, who is there, and a
/// quiet Join while it runs. Never a second gold button.
class _RoomRow extends ConsumerStatefulWidget {
  const _RoomRow({
    required this.session,
    required this.isActive,
    required this.onJoin,
  });

  final Map<String, dynamic> session;
  final bool isActive;
  final VoidCallback onJoin;

  @override
  ConsumerState<_RoomRow> createState() => _RoomRowState();
}

class _RoomRowState extends ConsumerState<_RoomRow> {
  /// Locally-cached session metadata (type/audience/title). Async-loaded
  /// because `SharedPreferences` is async; the row renders the kind-only
  /// fallback while the lookup is in flight.
  InsSessionMeta? _meta;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  @override
  void didUpdateWidget(covariant _RoomRow old) {
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

  /// Best-effort start timestamp for the room. Tries common keys the
  /// server might ship; returns null when none are present so the
  /// "Started X min ago" segment can fall back to nothing rather than
  /// guessing.
  static DateTime? _readSessionStartedAt(Map<String, dynamic> session) {
    for (final key in const ['startedAt', 'firstJoinedAt', 'answeredAt', 'createdAt']) {
      final raw = session[key];
      if (raw == null) continue;
      if (raw is DateTime) return raw;
      final parsed = DateTime.tryParse(raw.toString());
      if (parsed != null) return parsed;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final isActive = widget.isActive;
    final kind = (session['kind'] ?? '').toString().toUpperCase();
    final status = (session['status'] ?? '').toString().toUpperCase();
    final participantCount = session['participantCount'];

    // Title resolution — prefer the locally-cached session title (set by
    // the host at start time), fall back to the meta type label, then to
    // the server-provided title (legacy rooms), then to "Live session".
    final serverTitle = (session['title'] ?? '').toString().trim();
    final title = (_meta?.title?.trim().isNotEmpty ?? false)
        ? _meta!.title!.trim()
        : (_meta != null ? _meta!.type.label : (serverTitle.isNotEmpty ? serverTitle : 'Live session'));

    // "Town hall · Public · 12 people attending · Started 5 min ago", each
    // segment dropped when it is not known, so the line never reads
    // "0 people" or "Started ?".
    final context0 = <String>[
      if (_meta != null) ...[_meta!.type.label, _meta!.audience.label] else (kind == 'VIDEO' ? 'Video' : 'Audio'),
      if (isActive)
        if (participantCount is num && participantCount > 0)
          participantCount.toInt() == 1 ? '1 person attending' : '${participantCount.toInt()} people attending'
        else
          'People are attending',
      if (isActive)
        if (formatStartedAgo(_readSessionStartedAt(session)) case final s?) s,
    ].join(' · ');

    return WorkspaceRow(
      leading: WorkspaceIcon(
        kind == 'VIDEO' ? Icons.videocam_rounded : Icons.mic_rounded,
        tone: isActive ? WorkspaceTone.live : WorkspaceTone.neutral,
      ),
      title: title,
      context: context0,
      pill: isActive
          ? const WorkspacePill(label: 'Live now', tone: WorkspaceTone.live)
          : WorkspacePill(label: status == 'ENDED' ? 'Ended' : (status.isNotEmpty ? status : 'Unknown')),
      emphasis: isActive ? WorkspaceTone.live : null,
      trailing: isActive
          ? TextButton.icon(
              onPressed: widget.onJoin,
              icon: const Icon(Icons.call_rounded, size: 16),
              label: const Text('Join'),
              style: TextButton.styleFrom(
                foregroundColor: AuraSurface.infoInk,
                textStyle: const TextStyle(fontFamily: 'AuraSans', fontSize: 14, fontWeight: FontWeight.w700),
              ),
            )
          : null,
      onTap: isActive ? widget.onJoin : null,
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

/// Phase 4 — combined presence line for the live room card.
///
