import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/authority/authority_providers.dart';
import '../../../core/institutions/institution_destination_authority.dart';

import '../../../config.dart';
import '../../../core/auth/session_providers.dart';
import '../../../core/product/temporal.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../institutions/workspace/workspace_page.dart';
import '../application/meetings_provider.dart';
import '../domain/availability_profile.dart';
import '../domain/meeting.dart';
import '../domain/meeting_lifecycle.dart';
import '../domain/meeting_room.dart';
import 'institution_availability_screen.dart';
import '../../../core/product/product_language.dart';

/// MEETINGS (DD-43): one Collection page. Tabs Upcoming · Follow-up · Past ·
/// Booking pages; one gold "New meeting"; "Start now" and "Join by code"
/// under More. The two-column landing and its second "New meeting" are gone.
class MeetingsHomeScreen extends ConsumerStatefulWidget {
  final String? institutionId;

  /// 'upcoming' (default), 'followup', 'past' or 'booking'.
  final String? initialTab;

  const MeetingsHomeScreen({super.key, this.institutionId, this.initialTab});

  @override
  ConsumerState<MeetingsHomeScreen> createState() => _MeetingsHomeScreenState();
}

class _MeetingsHomeScreenState extends ConsumerState<MeetingsHomeScreen> {
  Timer? _pollTimer;
  late String _tab = const {'upcoming', 'followup', 'past', 'booking'}.contains(widget.initialTab)
      ? widget.initialTab!
      : 'upcoming';

  // The Past tab's search and relationship filter.
  static const int _pageSize = 8;
  static const _filters = ['All', 'Hosted', 'Attended', 'Booked', 'Cancelled'];
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _filter = 'All';
  int _visible = _pageSize;

  /// RECONCILIATION, NOT THE SIGNAL.
  ///
  /// `meeting.state_changed` over the socket is how this screen learns that
  /// something happened; this timer only catches the case where the socket was
  /// down and reconnected without replay. It used to run every 30 seconds,
  /// which meant six refetches a minute on a screen that already had a live
  /// feed of exactly the events it cares about.
  static const _reconcileEvery = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(_reconcileEvery, (_) {
      if (!mounted) return;
      _refresh();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _refresh() {
    final institutionId = widget.institutionId;
    // `meetingStateChangedEventProvider` IS DELIBERATELY NOT INVALIDATED.
    //
    // It is a StreamProvider over the live socket, not a query. Invalidating
    // it tears the subscription down and builds a new one, so this screen was
    // dropping and re-establishing its realtime feed every 30 seconds and
    // losing whatever arrived in the gap.
    //
    // Worse, it closed a loop with the listener in build(): an event fired
    // _refresh(), _refresh() invalidated the stream, the rebuilt stream
    // notified the listener, and the listener called _refresh() again.
    //
    // A live subscription is not refreshed. It is listened to.
    ref.invalidate(upcomingMeetingsProvider);
    ref.invalidate(pastMeetingsProvider);
    ref.invalidate(myOpenOutcomesProvider);
    ref.invalidate(myAvailabilityProfilesProvider);
    if (institutionId != null && institutionId.isNotEmpty) {
      ref.invalidate(institutionUpcomingMeetingsProvider(institutionId));
      ref.invalidate(institutionPastMeetingsProvider(institutionId));
      ref.invalidate(institutionProfilesProvider(institutionId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final institutionId = widget.institutionId;

    ref.listen(meetingStateChangedEventProvider, (_, next) {
      next.whenData((_) => _refresh());
    });

    if (institutionId == null || institutionId.isEmpty) {
      return WorkspacePage(
        type: WorkspacePageType.collection,
        title: 'Meetings',
        children: [
          WorkspaceEmpty(
            icon: Icons.apartment_rounded,
            title: 'Meetings live in an institution workspace.',
            body: 'Open an institution to create, host, or review meetings.',
            action: WorkspaceAction(
              label: 'Browse institutions',
              icon: Icons.apartment_rounded,
              onPressed: () => context.push('/institutions'),
            ),
          ),
        ],
      );
    }

    final meId = ref.watch(authMeDataProvider).maybeWhen(
          data: (me) {
            final user = me['user'];
            if (user is Map) {
              return (user['id'] ?? '').toString().trim();
            }
            return (me['id'] ?? '').toString().trim();
          },
          orElse: () => '',
        );
    final upcomingAsync = ref.watch(institutionUpcomingMeetingsProvider(institutionId));
    final pastAsync = ref.watch(institutionPastMeetingsProvider(institutionId));
    final outcomesAsync = ref.watch(myOpenOutcomesProvider);
    final projection = ref.watch(capabilityProjectionForProvider(institutionId));
    // Creating a meeting in the institution's name needs HOST_MEETINGS or
    // MANAGE_MEETINGS here. The buttons used to show to every member and lead
    // to a form the server then refused (phase 2, 2026-10-09).
    final canCreate = institutionDestinationPermits(projection, 'meetings/new');
    // Booking pages are managed with MANAGE_AVAILABILITY. Without it the tab
    // shows the person's own booking page instead.
    final canManageBooking = institutionDestinationPermits(projection, 'availability');
    final bookingCount = canManageBooking
        ? ref.watch(institutionProfilesProvider(institutionId)).valueOrNull?.length
        : ref.watch(myAvailabilityProfilesProvider).valueOrNull?.length;

    final upcoming = _ordered(upcomingAsync.valueOrNull ?? const <Meeting>[]);
    final outcomes = outcomesAsync.valueOrNull ?? const <MeetingOutcome>[];
    final past = pastAsync.valueOrNull ?? const <Meeting>[];

    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 760;
        final search = _tab == 'past' && past.isNotEmpty ? _pastSearch(wide: wide) : null;

        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: WorkspacePage(
            type: WorkspacePageType.collection,
            title: 'Meetings',
            purpose: 'Meetings you host or attend here, what came out of them, and your booking pages.',
            primary: canCreate
                ? WorkspaceAction(
                    label: 'New meeting',
                    icon: Icons.add_rounded,
                    onPressed: () => context.push(_createPath(instant: false)),
                  )
                : null,
            more: [
              if (canCreate)
                WorkspaceAction(
                  label: 'Start now',
                  icon: Icons.bolt_rounded,
                  onPressed: () => context.push(_createPath(instant: true)),
                ),
              WorkspaceAction(
                label: 'Join by code',
                icon: Icons.tag_rounded,
                onPressed: () => _showJoinDialog(context),
              ),
            ],
            tabs: [
              WorkspaceTab(id: 'upcoming', label: 'Upcoming', count: upcomingAsync.hasValue ? upcoming.length : null),
              WorkspaceTab(id: 'followup', label: 'Follow-up', count: outcomesAsync.hasValue ? outcomes.length : null),
              WorkspaceTab(id: 'past', label: 'Past', count: pastAsync.hasValue ? past.length : null),
              WorkspaceTab(id: 'booking', label: 'Booking pages', count: bookingCount),
            ],
            selectedTab: _tab,
            onTab: (id) => setState(() => _tab = id),
            tabTrailing: wide ? search : null,
            loading: switch (_tab) {
              'upcoming' => upcomingAsync.isLoading && !upcomingAsync.hasValue,
              'followup' => outcomesAsync.isLoading && !outcomesAsync.hasValue,
              'past' => pastAsync.isLoading && !pastAsync.hasValue,
              _ => false,
            },
            children: switch (_tab) {
              'followup' => _followUp(outcomesAsync, outcomes, institutionId),
              'past' => [
                  if (!wide && search != null) ...[search, const SizedBox(height: AuraSpace.s16)],
                  ..._past(pastAsync, past, meId, institutionId),
                ],
              'booking' => [
                  canManageBooking
                      ? InstitutionBookingPages(institutionId: institutionId)
                      : const _OwnBookingPage(),
                ],
              _ => _upcoming(upcomingAsync, upcoming, meId, institutionId, canCreate: canCreate),
            },
          ),
        );
      },
    );
  }

  /// Live first, then the soonest; instant meetings without a time last.
  static List<Meeting> _ordered(List<Meeting> meetings) {
    bool live(Meeting m) => m.phase == MeetingPhase.active || m.phase == MeetingPhase.ready;
    final list = [...meetings];
    list.sort((a, b) {
      if (live(a) != live(b)) return live(a) ? -1 : 1;
      final sa = a.scheduledAt, sb = b.scheduledAt;
      if (sa == null && sb == null) return 0;
      if (sa == null) return 1;
      if (sb == null) return -1;
      return sa.compareTo(sb);
    });
    return list;
  }

  List<Widget> _upcoming(
    AsyncValue<List<Meeting>> async,
    List<Meeting> upcoming,
    String meId,
    String institutionId, {
    required bool canCreate,
  }) {
    if (async.hasError && !async.hasValue) {
      return [_error('Your meetings could not be loaded')];
    }
    if (upcoming.isEmpty) {
      return [
        WorkspaceEmpty(
          icon: Icons.event_available_rounded,
          title: 'Nothing scheduled',
          body: 'When you schedule a meeting, or someone books time with you, it appears here with everything that came out of it.',
          action: canCreate
              ? WorkspaceAction(
                  label: 'New meeting',
                  icon: Icons.add_rounded,
                  onPressed: () => context.push(_createPath(instant: false)),
                )
              : null,
        ),
      ];
    }
    final attention = meetingsNeedingAttention(upcoming, null, meId).map((m) => m.id).toSet();
    return [
      for (final m in upcoming)
        _MeetingRow(
          meeting: m,
          relationship: _relationshipLabel(m, meId: meId, institutionId: institutionId),
          attention: attention.contains(m.id),
          onTap: () => context.push(_meetingPathFor(m, institutionId)),
        ),
    ];
  }

  List<Widget> _followUp(AsyncValue<List<MeetingOutcome>> async, List<MeetingOutcome> outcomes, String institutionId) {
    if (async.hasError && !async.hasValue) {
      return [_error('Your follow-up could not be loaded')];
    }
    if (outcomes.isEmpty) {
      return const [
        WorkspaceEmpty(
          icon: Icons.checklist_rounded,
          title: 'No follow-up waiting',
          body: 'Actions and commitments assigned to you in a meeting stay here until they are done.',
        ),
      ];
    }
    return [
      for (final o in outcomes) _OutcomeRow(outcome: o, institutionId: institutionId),
    ];
  }

  bool _matchesFilter(Meeting meeting, String meId) {
    switch (_filter) {
      case 'Hosted':
        return (meeting.host?.id ?? '') == meId;
      case 'Attended':
        return meeting.participants.any(
          (p) => (p.userId ?? '').trim() == meId && p.attended,
        );
      case 'Booked':
        final identity = meeting.booking?.bookerIdentity;
        return identity != null && (identity.auraUserId == meId || identity.memberId == meId);
      case 'Cancelled':
        return meeting.state == 'CANCELLED';
      default:
        return true;
    }
  }

  bool _matchesQuery(Meeting meeting) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return meeting.title.toLowerCase().contains(q) ||
        (meeting.host?.name ?? '').toLowerCase().contains(q) ||
        (meeting.owningInstitution?.name ?? '').toLowerCase().contains(q);
  }

  /// Search past meetings, with one Filter beside it.
  Widget _pastSearch({required bool wide}) {
    final field = SizedBox(
      width: wide ? 240 : null,
      height: 40,
      child: TextField(
        controller: _searchCtrl,
        style: AuraText.body.copyWith(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search past meetings',
          prefixIcon: const Icon(Icons.search_rounded, size: 18),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear the search',
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {
                      _query = '';
                      _visible = _pageSize;
                    });
                  },
                ),
        ),
        onChanged: (value) => setState(() {
          _query = value.trim();
          _visible = _pageSize;
        }),
      ),
    );
    final filter = PopupMenuButton<String>(
      tooltip: 'Filter',
      color: AuraSurface.overlay,
      position: PopupMenuPosition.under,
      onSelected: (f) => setState(() {
        _filter = f;
        _visible = _pageSize;
      }),
      itemBuilder: (_) => [
        for (final f in _filters)
          CheckedPopupMenuItem<String>(value: f, checked: f == _filter, child: Text(f)),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _filter == 'All' ? AuraSurface.divider : AuraSurface.accent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_list_rounded, size: 18, color: AuraSurface.muted),
            const SizedBox(width: AuraSpace.s6),
            Text(
              _filter == 'All' ? 'Filter' : _filter,
              style: AuraText.small.copyWith(fontWeight: FontWeight.w600, color: AuraSurface.muted),
            ),
          ],
        ),
      ),
    );
    return Row(
      mainAxisSize: wide ? MainAxisSize.min : MainAxisSize.max,
      children: [
        if (wide) field else Expanded(child: field),
        const SizedBox(width: AuraSpace.s8),
        filter,
      ],
    );
  }

  List<Widget> _past(AsyncValue<List<Meeting>> async, List<Meeting> past, String meId, String institutionId) {
    if (async.hasError && !async.hasValue) {
      return [_error('Your past meetings could not be loaded')];
    }
    if (past.isEmpty) {
      return const [
        WorkspaceEmpty(
          icon: Icons.history_rounded,
          title: 'No past meetings yet',
          body: 'Meetings you have held are kept here.',
        ),
      ];
    }
    final filtered = past.where((m) => _matchesFilter(m, meId)).where(_matchesQuery).toList(growable: false);
    if (filtered.isEmpty) {
      return const [
        WorkspaceEmpty(
          icon: Icons.search_off_rounded,
          title: 'No past meetings match',
          body: 'Try a different search or filter.',
        ),
      ];
    }
    final shown = filtered.take(_visible).toList(growable: false);
    return [
      for (final m in shown)
        _MeetingRow(
          meeting: m,
          relationship: _relationshipLabel(m, meId: meId, institutionId: institutionId),
          onTap: () => context.push(_meetingPathFor(m, institutionId)),
        ),
      if (filtered.length > shown.length)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: AuraSurface.accentText),
            icon: const Icon(Icons.expand_more_rounded, size: 18),
            label: Text('Show more (${filtered.length - shown.length} remaining)'),
            onPressed: () => setState(() => _visible += _pageSize),
          ),
        )
      else if (filtered.length > _pageSize)
        Padding(
          padding: const EdgeInsets.only(top: AuraSpace.s4),
          child: Text('Showing all ${filtered.length} meetings', style: AuraText.small.copyWith(color: AuraSurface.faint)),
        ),
    ];
  }

  Widget _error(String title) => WorkspaceEmpty(
        icon: Icons.error_outline_rounded,
        title: title,
        body: 'Check the connection and try again.',
        action: WorkspaceAction(label: ProductLabels.of(ProductAction.retry), icon: Icons.refresh_rounded, onPressed: _refresh),
      );

  String _createPath({required bool instant}) {
    final suffix = instant ? '?instant=1' : '';
    final institutionId = widget.institutionId!;
    return '/institution/$institutionId/meetings/new$suffix';
  }

  void _showJoinDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Join by code'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Meeting code',
            prefixIcon: Icon(Icons.tag_rounded),
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _submitJoin(context, ctrl),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => _submitJoin(context, ctrl),
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  void _submitJoin(BuildContext context, TextEditingController ctrl) {
    final code = ctrl.text.trim();
    if (code.isEmpty) return;
    Navigator.pop(context);
    context.push('/meetings/join/$code');
  }
}

/// One meeting: when, who hosts, how you are in it; and where it stands.
class _MeetingRow extends StatelessWidget {
  const _MeetingRow({
    required this.meeting,
    required this.relationship,
    required this.onTap,
    this.attention = false,
  });

  final Meeting meeting;
  final String relationship;
  final VoidCallback onTap;
  final bool attention;

  @override
  Widget build(BuildContext context) {
    final phase = meeting.phase;
    final live = phase == MeetingPhase.active || phase == MeetingPhase.ready;
    final at = meeting.scheduledAt;
    final now = DateTime.now();
    final today = at != null && DateUtils.isSameDay(at.toUtc().add(now.timeZoneOffset), now);
    final when = at == null ? 'Instant meeting' : AuraTemporal.fullShort(at);
    final host = meeting.host?.name.trim() ?? '';

    final WorkspacePill pill;
    if (live) {
      pill = const WorkspacePill(label: 'Live', tone: WorkspaceTone.live);
    } else if (meeting.state == 'CANCELLED' || phase == MeetingPhase.cancelled) {
      pill = const WorkspacePill(label: 'Cancelled');
    } else if (meeting.isEnded) {
      pill = const WorkspacePill(label: 'Ended');
    } else if (meeting.room?.status == MeetingRoomStatus.scheduledTimePassed) {
      pill = const WorkspacePill(label: 'Not started', tone: WorkspaceTone.problem);
    } else if (today) {
      pill = const WorkspacePill(label: 'Today', tone: WorkspaceTone.waiting);
    } else {
      pill = const WorkspacePill(label: 'Scheduled');
    }

    return WorkspaceRow(
      leading: WorkspaceIcon(
        meeting.isInstant ? Icons.bolt_rounded : Icons.videocam_outlined,
        tone: live ? WorkspaceTone.live : WorkspaceTone.neutral,
      ),
      title: meeting.title.trim().isEmpty ? 'Meeting' : meeting.title,
      context: [when, if (host.isNotEmpty) host, relationship].join(' · '),
      pill: pill,
      emphasis: live ? WorkspaceTone.live : (attention ? WorkspaceTone.waiting : null),
      onTap: onTap,
    );
  }
}

/// One follow-up: what to do, the meeting it came from, when it is due.
class _OutcomeRow extends ConsumerWidget {
  const _OutcomeRow({required this.outcome, required this.institutionId});

  final MeetingOutcome outcome;
  final String institutionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The outcome usually carries its meeting's title; when it does not, the
    // meeting is asked for, and the row reads immediately either way.
    final carried = (outcome.meetingTitle ?? '').trim();
    final meeting = carried.isEmpty ? ref.watch(meetingProvider(outcome.meetingId)).valueOrNull : null;
    final title = carried.isNotEmpty ? carried : (meeting?.title ?? '');
    final due = outcome.dueDate;
    final overdue = due != null && due.isBefore(DateTime.now());

    return WorkspaceRow(
      leading: WorkspaceIcon(Icons.checklist_rounded, tone: overdue ? WorkspaceTone.problem : WorkspaceTone.neutral),
      title: outcome.text,
      context: title.isEmpty ? 'Follow-up' : 'from $title',
      pill: due == null
          ? const WorkspacePill(label: 'Open')
          : WorkspacePill(
              label: overdue ? 'Was due ${AuraTemporal.dueDay(due)}' : 'Due ${AuraTemporal.dueDay(due)}',
              tone: overdue ? WorkspaceTone.problem : WorkspaceTone.waiting,
            ),
      emphasis: overdue ? WorkspaceTone.problem : null,
      onTap: () {
        context.push(_meetingPath(outcome.meetingInstitutionId, outcome.meetingId, institutionId));
      },
    );
  }
}

/// For someone who does not manage the institution's booking pages: their
/// own booking page, to copy or open.
class _OwnBookingPage extends ConsumerWidget {
  const _OwnBookingPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myAvailabilityProfilesProvider);
    return async.when(
      loading: () => const WorkspaceLoading(type: WorkspacePageType.settings, rows: 1),
      error: (e, _) => WorkspaceEmpty(
        icon: Icons.error_outline_rounded,
        title: 'Your booking page could not be loaded',
        body: 'Check the connection and try again.',
        action: WorkspaceAction(
          label: ProductLabels.of(ProductAction.retry),
          icon: Icons.refresh_rounded,
          onPressed: () => ref.invalidate(myAvailabilityProfilesProvider),
        ),
      ),
      data: (profiles) {
        final profile = _pick(profiles);
        if (profile == null) {
          return const WorkspaceEmpty(
            icon: Icons.link_rounded,
            title: 'No booking page yet',
            body: 'A booking page lets people find a time with you without an account. Whoever manages booking pages here can set one up for you.',
          );
        }
        final publicUrl = '${AppConfig.publicWebUrl}${profile.publicUrl}';
        final shown = publicUrl.replaceFirst(RegExp(r'^https?://'), '');
        return WorkspaceSection(
          title: 'Your booking page',
          description: profile.name,
          child: Row(
            children: [
              const Icon(Icons.link_rounded, size: 16, color: AuraSurface.faint),
              const SizedBox(width: AuraSpace.s8),
              Expanded(
                child: Text(shown, maxLines: 1, overflow: TextOverflow.ellipsis, style: AuraText.small),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: AuraSurface.accentText),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: publicUrl));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Booking link copied')),
                  );
                },
                child: const Text('Copy'),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: AuraSurface.muted),
                onPressed: () => context.push(profile.publicUrl),
                child: const Text('Open'),
              ),
            ],
          ),
        );
      },
    );
  }

  AvailabilityProfile? _pick(List<AvailabilityProfile> profiles) {
    if (profiles.isEmpty) return null;
    final active = profiles.where((p) => p.isActive).toList(growable: false);
    return active.isNotEmpty ? active.first : profiles.first;
  }
}

String _relationshipLabel(
  Meeting meeting, {
  required String meId,
  required String? institutionId,
}) {
  final myId = meId.trim();
  if (myId.isNotEmpty && (meeting.host?.id ?? '') == myId) {
    return 'Hosting';
  }

  final bookingIdentity = meeting.booking?.bookerIdentity;
  if (bookingIdentity != null &&
      (bookingIdentity.auraUserId == myId ||
          bookingIdentity.memberId == myId)) {
    return 'Booked';
  }

  final participantMatch = meeting.participants.any(
    (participant) => (participant.userId ?? '').trim() == myId,
  );
  if (participantMatch) {
    return 'Attending';
  }

  final invitedGuest = meeting.participants.any(
    (participant) => participant.isGuest && !participant.attended,
  );
  if (invitedGuest) {
    return 'Invited';
  }

  if ((meeting.organizationId ?? '').trim().isNotEmpty ||
      (meeting.owningInstitutionId ?? '').trim().isNotEmpty) {
    return 'Institution meeting';
  }

  return 'Attending';
}

/// The meetings that want a decision soon: a waiting room, a time that went
/// by unstarted, an invitation, or a start within three hours.
///
/// Exposed so the one rule that matters here can be tested directly: a meeting
/// already shown as [upNext] is NOT repeated (production, 2026-08-25: the
/// same card twice on one screen read as two meetings). The Upcoming tab
/// passes null and uses this to give those rows a gold edge.
List<Meeting> meetingsNeedingAttention(
  List<Meeting> upcoming,
  Meeting? upNext,
  String meId,
) =>
    upcoming
        .where((m) => m.id != upNext?.id && _isAttentionItem(m, meId))
        .toList(growable: false);

bool _isAttentionItem(Meeting meeting, String meId) {
  if (meeting.isEnded) return false;
  final room = meeting.room?.status;
  if (room == MeetingRoomStatus.guestWaiting ||
      room == MeetingRoomStatus.hostWaiting ||
      room == MeetingRoomStatus.waiting) {
    return true;
  }
  // THE BOOKED TIME WENT BY AND NOBODY STARTED IT. That is the definition of
  // something wanting a decision, and it must be stated before the time
  // window below gets a chance to drop it.
  if (room == MeetingRoomStatus.scheduledTimePassed) return true;
  if (_relationshipLabel(meeting, meId: meId, institutionId: null) == 'Invited') {
    return true;
  }
  final scheduled = meeting.scheduledAt;
  if (scheduled == null) return false;
  final delta = scheduled.difference(DateTime.now());
  return delta.inMinutes <= 180 && delta.inMinutes >= -15;
}

String _meetingPathFor(Meeting meeting, String? institutionId) =>
    _meetingPath(meeting.owningInstitutionId ?? meeting.organizationId, meeting.id, institutionId);

/// Where a meeting opens: inside the institution that owns it, else inside
/// this one, else at its personal address.
String _meetingPath(String? owningInstitutionId, String meetingId, String? institutionId) {
  final owning = (owningInstitutionId ?? '').trim();
  final inst = owning.isNotEmpty ? owning : (institutionId ?? '').trim();
  if (inst.isNotEmpty) {
    return '/institution/$inst/meetings/$meetingId';
  }
  // A personal meeting has a canonical address. Sending its own card to
  // `/home` was the same defect fixed on the other path during the structural
  // pass -- this is its second copy.
  return '/meetings/$meetingId';
}
