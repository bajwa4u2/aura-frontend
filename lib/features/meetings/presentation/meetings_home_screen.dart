import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../config.dart';
import '../../../core/auth/session_providers.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../application/meetings_provider.dart';
import '../domain/availability_profile.dart';
import '../domain/meeting.dart';
import '../domain/meeting_lifecycle.dart';
import 'widgets/meeting_card.dart';
import 'widgets/meeting_surfaces.dart';
import 'meeting_semantics.dart';
import '../domain/meeting_room.dart';

class MeetingsHomeScreen extends ConsumerStatefulWidget {
  final String? institutionId;

  const MeetingsHomeScreen({super.key, this.institutionId});

  @override
  ConsumerState<MeetingsHomeScreen> createState() => _MeetingsHomeScreenState();
}

class _MeetingsHomeScreenState extends ConsumerState<MeetingsHomeScreen> {
  Timer? _pollTimer;

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
    // notified the listener, and the listener called _refresh() again. Every
    // real meeting state change kicked off a self-feeding cycle of
    // re-subscriptions and six-endpoint refetches.
    //
    // A live subscription is not refreshed. It is listened to.
    ref.invalidate(upcomingMeetingsProvider);
    ref.invalidate(pastMeetingsProvider);
    ref.invalidate(myOpenOutcomesProvider);
    ref.invalidate(myAvailabilityProfilesProvider);
    if (institutionId != null && institutionId.isNotEmpty) {
      ref.invalidate(institutionUpcomingMeetingsProvider(institutionId));
      ref.invalidate(institutionPastMeetingsProvider(institutionId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final institutionId = widget.institutionId;

    ref.listen(meetingStateChangedEventProvider, (_, next) {
      next.whenData((_) => _refresh());
    });

    if (institutionId == null || institutionId.isEmpty) {
      return AuraScaffold(
        title: 'Meetings',
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(AuraSpace.s16),
              child: _InstitutionRequiredCard(
                onBrowseInstitutions: () => context.push('/institutions'),
              ),
            ),
          ),
        ),
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
    final upcomingAsync = ref.watch(
      institutionUpcomingMeetingsProvider(institutionId),
    );
    final pastAsync = ref.watch(institutionPastMeetingsProvider(institutionId));
    final outcomesAsync = ref.watch(myOpenOutcomesProvider);
    final profilesAsync = ref.watch(myAvailabilityProfilesProvider);

    return AuraScaffold(
      title: 'Meetings',
      // AuraScaffold clamps to 920 by default, which is BELOW this page's own
      // 900 breakpoint - so a full desktop window still resolved as narrow and
      // stacked the actions edge to edge. The page needs the room it lays out
      // for.
      maxWidth: 1180,
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // §14/§15. One breakpoint, chosen because it is where a second
            // column stops crowding the first — not because 900 is a round
            // number. Below it the page is one column and the actions stack.
            final wide = constraints.maxWidth >= 900;
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AuraSpace.s16,
                AuraSpace.s8,
                AuraSpace.s16,
                AuraSpace.s32,
              ),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _MeetingsActions(
                          wide: wide,
                          onCreate: () =>
                              context.push(_createPath(instant: false)),
                          onInstant: () =>
                              context.push(_createPath(instant: true)),
                          onJoinByCode: () => _showJoinDialog(context),
                        ),
                        const SizedBox(height: AuraSpace.s20),
                        _MeetingsBody(
                          wide: wide,
                          meId: meId,
                          institutionId: institutionId,
                          upcomingAsync: upcomingAsync,
                          pastAsync: pastAsync,
                          outcomesAsync: outcomesAsync,
                          profilesAsync: profilesAsync,
                          onCreate: () =>
                              context.push(_createPath(instant: false)),
                          onRetry: _refresh,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

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

/// THE ACTION ROW - ONE PRIMARY, TWO QUIET.
///
/// Founder ruling section 5 and 7. What this replaces: the screen's own
/// `Meetings` heading (a SECOND one, because `AuraScaffold` already draws the
/// page title), the subtitle "Host, attend, and manage your meetings." which
/// described the page to somebody already looking at it, and three buttons of
/// which TWO were filled purple - so nothing was primary and the eye had
/// nowhere to land.
///
/// Creating a meeting is the primary act. Starting one immediately and joining
/// by code are real but occasional, and now look it.
class _MeetingsActions extends StatelessWidget {
  const _MeetingsActions({
    required this.wide,
    required this.onCreate,
    required this.onInstant,
    required this.onJoinByCode,
  });

  final bool wide;
  final VoidCallback onCreate;
  final VoidCallback onInstant;
  final VoidCallback onJoinByCode;

  @override
  Widget build(BuildContext context) {
    final primary = MeetingAction(
      label: 'Create a meeting',
      child: FilledButton.icon(
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('New meeting'),
        onPressed: onCreate,
      ),
    );
    final instant = MeetingAction(
      label: 'Start a meeting immediately',
      child: TextButton.icon(
        icon: const Icon(Icons.bolt_rounded, size: 18),
        label: const Text('Start now'),
        onPressed: onInstant,
      ),
    );
    final byCode = MeetingAction(
      label: 'Join a meeting using a code',
      child: TextButton.icon(
        icon: const Icon(Icons.tag_rounded, size: 18),
        label: const Text('Join by code'),
        onPressed: onJoinByCode,
      ),
    );

    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          primary,
          const SizedBox(height: AuraSpace.s8),
          Row(
            children: [
              Expanded(child: instant),
              const SizedBox(width: AuraSpace.s8),
              Expanded(child: byCode),
            ],
          ),
        ],
      );
    }
    return Row(
      children: [
        instant,
        byCode,
        const Spacer(),
        primary,
      ],
    );
  }
}

/// THE PAGE ITSELF.
///
/// Section 6: do not overwhelm the surface with every historical record;
/// prioritize relevance. The version this replaces rendered six sections
/// unconditionally - Needs attention, Upcoming, Invitations, Follow-up, Past,
/// plus a booking card - so somebody with an empty calendar was shown five
/// grey boxes each telling them, separately, that there was nothing there.
///
/// Now a section with nothing in it is not drawn, and when there is genuinely
/// nothing at all the page says so ONCE, properly, with the action that fixes
/// it.
class _MeetingsBody extends StatelessWidget {
  const _MeetingsBody({
    required this.wide,
    required this.meId,
    required this.institutionId,
    required this.upcomingAsync,
    required this.pastAsync,
    required this.outcomesAsync,
    required this.profilesAsync,
    required this.onCreate,
    required this.onRetry,
  });

  final bool wide;
  final String meId;
  final String institutionId;
  final AsyncValue<List<Meeting>> upcomingAsync;
  final AsyncValue<List<Meeting>> pastAsync;
  final AsyncValue<List<MeetingOutcome>> outcomesAsync;
  final AsyncValue<List<AvailabilityProfile>> profilesAsync;
  final VoidCallback onCreate;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (upcomingAsync.isLoading && !upcomingAsync.hasValue) {
      // Section 19 - the shape of what is coming, not a spinner in a void.
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MeetingSkeleton(height: 26),
          SizedBox(height: AuraSpace.s10),
          MeetingSkeletonList(count: 2),
        ],
      );
    }
    if (upcomingAsync.hasError && !upcomingAsync.hasValue) {
      return MeetingError(
        what: 'your meetings',
        onRetry: onRetry,
        technical: '${upcomingAsync.error}',
      );
    }

    final upcoming = upcomingAsync.valueOrNull ?? const <Meeting>[];
    final attention =
        upcoming.where((m) => _isAttentionItem(m, meId)).toList(growable: false);
    final invited = upcoming
        .where((m) =>
            _relationshipLabel(m, meId: meId, institutionId: institutionId) ==
            'Invited')
        .toList(growable: false);
    final outcomes = outcomesAsync.valueOrNull ?? const <MeetingOutcome>[];
    final past = pastAsync.valueOrNull ?? const <Meeting>[];

    // The single most imminent thing. A person opening Meetings is nearly
    // always asking "what is next", and the old page made them find out by
    // reading a list.
    final next = _pickUpNext(upcoming);
    final rest = upcoming.where((m) => m.id != next?.id).toList(growable: false);

    final nothingAtAll = upcoming.isEmpty && outcomes.isEmpty && past.isEmpty;
    if (nothingAtAll) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MeetingEmpty(
            icon: Icons.event_available_rounded,
            headline: 'No meetings yet',
            detail: 'When you schedule a meeting, or someone books time with '
                'you, it appears here with everything that came out of it.',
            action: MeetingAction(
              label: 'Create your first meeting',
              child: FilledButton.icon(
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New meeting'),
                onPressed: onCreate,
              ),
            ),
          ),
          const SizedBox(height: AuraSpace.s16),
          _BookingLinkRow(
            profilesAsync: profilesAsync,
            institutionId: institutionId,
          ),
        ],
      );
    }

    final main = <Widget>[
      if (next != null) ...[
        _UpNext(
          meeting: next,
          meId: meId,
          institutionId: institutionId,
          dense: !wide,
        ),
        const SizedBox(height: AuraSpace.s20),
      ],
      if (attention.isNotEmpty) ...[
        MeetingSection(
          title: 'Needs attention',
          count: attention.length,
          emphasis: true,
          child: _cards(context, attention),
        ),
        const SizedBox(height: AuraSpace.s20),
      ],
      if (rest.isNotEmpty) ...[
        MeetingSection(
          title: 'Upcoming',
          count: rest.length,
          child: _cards(context, rest),
        ),
        const SizedBox(height: AuraSpace.s20),
      ],
      if (invited.isNotEmpty) ...[
        MeetingSection(
          title: 'Invitations',
          count: invited.length,
          child: _cards(context, invited),
        ),
        const SizedBox(height: AuraSpace.s20),
      ],
      if (upcoming.isEmpty)
        MeetingEmpty(
          compact: true,
          icon: Icons.event_available_rounded,
          headline: 'Nothing scheduled',
          detail: 'Your past meetings and follow-up are below.',
          action: MeetingAction(
            label: 'Create a meeting',
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('New meeting'),
              onPressed: onCreate,
            ),
          ),
        ),
    ];

    final aside = <Widget>[
      if (outcomes.isNotEmpty) ...[
        MeetingSection(
          title: 'Follow-up',
          count: outcomes.length,
          child: Column(
            children: [
              for (final outcome in outcomes)
                Padding(
                  padding: const EdgeInsets.only(bottom: AuraSpace.s10),
                  child: _OutcomeCard(
                    outcome: outcome,
                    institutionId: institutionId,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AuraSpace.s20),
      ],
      _BookingLinkRow(
        profilesAsync: profilesAsync,
        institutionId: institutionId,
      ),
      if (past.isNotEmpty) ...[
        const SizedBox(height: AuraSpace.s20),
        MeetingSection(
          title: 'Past',
          child: _PastMeetingsSection(
            meetings: past,
            meId: meId,
            institutionId: institutionId,
          ),
        ),
      ],
    ];

    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [...main, ...aside],
      );
    }
    // Section 15 - a desktop window is not a tall phone. The secondary column
    // keeps follow-up and the booking link permanently in view instead of
    // pushing them a screen and a half below the meetings.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: main,
          ),
        ),
        const SizedBox(width: AuraSpace.s24),
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: aside,
          ),
        ),
      ],
    );
  }

  Widget _cards(BuildContext context, List<Meeting> meetings) => Column(
        children: [
          for (final meeting in meetings)
            Padding(
              padding: const EdgeInsets.only(bottom: AuraSpace.s10),
              child: MeetingCard(
                meeting: meeting,
                relationship: _relationshipLabel(
                  meeting,
                  meId: meId,
                  institutionId: institutionId,
                ),
                dense: !wide,
                onOpen: () => context.push(_pathFor(meeting)),
                onPrimaryAction: () => context.push(_pathFor(meeting)),
                primaryActionLabel: _meetingActionLabel(meeting),
              ),
            ),
        ],
      );

  String _pathFor(Meeting meeting) {
    final owning = meeting.owningInstitutionId ?? meeting.organizationId ?? '';
    return owning.trim().isNotEmpty
        ? '/institution/$owning/meetings/${meeting.id}'
        : '/meetings/${meeting.id}';
  }

  /// The next meeting worth leading with: a live one first, otherwise the
  /// soonest scheduled one.
  static Meeting? _pickUpNext(List<Meeting> meetings) {
    if (meetings.isEmpty) return null;
    final live = meetings.where(
      (m) => m.phase == MeetingPhase.active || m.phase == MeetingPhase.ready,
    );
    if (live.isNotEmpty) return live.first;
    final dated =
        meetings.where((m) => m.scheduledAt != null && !m.isEnded).toList()
          ..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));
    return dated.isEmpty ? null : dated.first;
  }
}

/// WHAT IS NEXT - the one question the landing exists to answer.
class _UpNext extends StatelessWidget {
  const _UpNext({
    required this.meeting,
    required this.meId,
    required this.institutionId,
    required this.dense,
  });

  final Meeting meeting;
  final String meId;
  final String institutionId;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final live = meeting.phase == MeetingPhase.active ||
        meeting.phase == MeetingPhase.ready;
    return MeetingSection(
      title: live ? 'Happening now' : 'Up next',
      emphasis: live,
      child: MeetingCard(
        meeting: meeting,
        relationship: _relationshipLabel(
          meeting,
          meId: meId,
          institutionId: institutionId,
        ),
        dense: dense,
        onOpen: () => context.push(_path()),
        onPrimaryAction: () => context.push(_path()),
        primaryActionLabel: live ? 'Join' : 'Open',
      ),
    );
  }

  String _path() {
    final owning = meeting.owningInstitutionId ?? meeting.organizationId ?? '';
    return owning.trim().isNotEmpty
        ? '/institution/$owning/meetings/${meeting.id}'
        : '/meetings/${meeting.id}';
  }
}

class _InstitutionRequiredCard extends StatelessWidget {
  final VoidCallback onBrowseInstitutions;

  const _InstitutionRequiredCard({required this.onBrowseInstitutions});

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      padding: const EdgeInsets.all(AuraSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Meetings live in an institution workspace.',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(
            'Open an institution to create, host, or review meetings.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AuraSurface.muted,
                ),
          ),
          const SizedBox(height: AuraSpace.s12),
          OutlinedButton.icon(
            icon: const Icon(Icons.apartment_rounded),
            label: const Text('Browse institutions'),
            onPressed: onBrowseInstitutions,
          ),
        ],
      ),
    );
  }
}

/// THE BOOKING LINK - A UTILITY, NOT A HEADLINE.
///
/// Founder ruling section 5 and 6. This was a full-width card sitting directly
/// under the page actions, above every meeting, with the raw booking URL as
/// its body text and three buttons under it. It was the most prominent thing
/// on the Meetings page and it is not the most important thing about meetings.
///
/// It is now a quiet row in the secondary column: still one tap from copying,
/// no longer competing with what is actually happening today.
class _BookingLinkRow extends ConsumerWidget {
  const _BookingLinkRow({
    required this.profilesAsync,
    required this.institutionId,
  });

  final AsyncValue<List<AvailabilityProfile>> profilesAsync;
  final String? institutionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return profilesAsync.when(
      loading: () => const MeetingSkeleton(lines: 1),
      error: (e, _) => MeetingError(
        what: 'your booking page',
        technical: '$e',
      ),
      data: (profiles) {
        final profile = _pickProfile(profiles);
        if (profile == null) {
          return MeetingEmpty(
            compact: true,
            icon: Icons.link_rounded,
            headline: 'No booking page yet',
            detail: 'A booking page lets people find a time with you without '
                'an account.',
            action: MeetingAction(
              label: 'Set up a booking page',
              child: OutlinedButton(
                onPressed: () => context.push(_manageBookingPath()),
                child: const Text('Set one up'),
              ),
            ),
          );
        }

        final publicUrl = '${AppConfig.publicWebUrl}${profile.publicUrl}';
        return AuraCard(
          padding: const EdgeInsets.all(AuraSpace.s14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.link_rounded,
                      size: 16, color: AuraSurface.muted),
                  const SizedBox(width: AuraSpace.s8),
                  Semantics(
                    header: true,
                    child: Text(
                      'Your booking page',
                      style: theme.textTheme.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AuraSpace.s8),
              // The address, quietly. It is reference, not a headline.
              Text(
                profile.publicUrl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AuraSurface.muted),
              ),
              const SizedBox(height: AuraSpace.s10),
              Row(
                children: [
                  MeetingAction(
                    label: 'Copy your booking link',
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy_rounded, size: 15),
                      label: const Text('Copy'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: publicUrl));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Booking link copied')),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: AuraSpace.s8),
                  MeetingAction(
                    label: 'Open your booking page',
                    child: TextButton(
                      onPressed: () => context.push(profile.publicUrl),
                      child: const Text('Open'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  AvailabilityProfile? _pickProfile(List<AvailabilityProfile> profiles) {
    if (profiles.isEmpty) return null;
    final active = profiles.where((p) => p.isActive).toList(growable: false);
    if (active.isNotEmpty) return active.first;
    return profiles.first;
  }
  String _manageBookingPath() => institutionId == null
      ? '/me'
      : '/institution/$institutionId/availability';
}

/// Managed past-meetings archive: search + relationship filter + progressive
/// reveal instead of an unbounded scroll of every past meeting.
class _PastMeetingsSection extends StatefulWidget {
  final List<Meeting> meetings;
  final String meId;
  final String? institutionId;

  const _PastMeetingsSection({
    required this.meetings,
    required this.meId,
    required this.institutionId,
  });

  @override
  State<_PastMeetingsSection> createState() => _PastMeetingsSectionState();
}

class _PastMeetingsSectionState extends State<_PastMeetingsSection> {
  static const int _pageSize = 8;
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _filter = 'All';
  int _visible = _pageSize;

  static const _filters = ['All', 'Hosted', 'Attended', 'Booked', 'Cancelled'];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _matchesFilter(Meeting meeting) {
    switch (_filter) {
      case 'Hosted':
        return (meeting.host?.id ?? '') == widget.meId;
      case 'Attended':
        return meeting.participants.any(
          (p) => (p.userId ?? '').trim() == widget.meId && p.attended,
        );
      case 'Booked':
        final identity = meeting.booking?.bookerIdentity;
        return identity != null &&
            (identity.auraUserId == widget.meId ||
                identity.memberId == widget.meId);
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

  @override
  Widget build(BuildContext context) {
    if (widget.meetings.isEmpty) {
      return const MeetingEmpty(
        compact: true,
        icon: Icons.history_rounded,
        headline: 'No past meetings yet',
        detail: 'Meetings you have held are kept here.',
      );
    }

    final filtered = widget.meetings
        .where(_matchesFilter)
        .where(_matchesQuery)
        .toList(growable: false);
    final shown = filtered.take(_visible).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Search past meetings',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            border: const OutlineInputBorder(),
            isDense: true,
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear the search',
                    icon: const Icon(Icons.clear_rounded, size: 18),
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
        const SizedBox(height: AuraSpace.s10),
        Wrap(
          spacing: AuraSpace.s8,
          runSpacing: AuraSpace.s8,
          children: [
            for (final filter in _filters)
              ChoiceChip(
                label: Text(filter),
                selected: _filter == filter,
                onSelected: (_) => setState(() {
                  _filter = filter;
                  _visible = _pageSize;
                }),
              ),
          ],
        ),
        const SizedBox(height: AuraSpace.s12),
        if (filtered.isEmpty)
          const MeetingEmpty(
            compact: true,
            icon: Icons.search_off_rounded,
            headline: 'No past meetings match',
            detail: 'Try a different search or filter.',
          )
        else ...[
          for (final meeting in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: AuraSpace.s10),
              child: MeetingCard(
                meeting: meeting,
                relationship: _relationshipLabel(
                  meeting,
                  meId: widget.meId,
                  institutionId: widget.institutionId,
                ),
                onOpen: () => context.push(
                  _meetingPathFor(meeting, widget.institutionId),
                ),
              ),
            ),
          if (filtered.length > shown.length)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.expand_more_rounded, size: 18),
                label: Text(
                  'Show more (${filtered.length - shown.length} remaining)',
                ),
                onPressed: () => setState(() => _visible += _pageSize),
              ),
            )
          else if (filtered.length > _pageSize)
            Padding(
              padding: const EdgeInsets.only(top: AuraSpace.s4),
              child: Text(
                'Showing all ${filtered.length} meetings',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AuraSurface.faint,
                    ),
              ),
            ),
        ],
      ],
    );
  }
}

class _OutcomeCard extends ConsumerWidget {
  final MeetingOutcome outcome;
  final String? institutionId;

  const _OutcomeCard({
    required this.outcome,
    required this.institutionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meetingAsync = ref.watch(meetingProvider(outcome.meetingId));
    return AuraCard(
      padding: const EdgeInsets.all(AuraSpace.s16),
      child: meetingAsync.when(
        // The outcome's own text is already known - only the meeting it came
        // from is still resolving. Showing a spinner hid information that was
        // in hand, so the follow-up item reads immediately and the meeting's
        // name arrives when it arrives.
        loading: () => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              outcome.text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AuraSpace.s6),
            Text(
              'Loading the meeting this came from...',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AuraSurface.muted),
            ),
          ],
        ),
        error: (e, _) => Text(
          outcome.text,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        data: (meeting) {
          final title = meeting.title;
          final scheduled = meeting.scheduledAt == null
              ? 'Instant meeting'
              : DateFormat('EEE, MMM d, h:mm a')
                  .format(meeting.scheduledAt!.toLocal());
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: AuraSpace.s6),
              Text(
                outcome.text,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AuraSpace.s6),
              Text(
                scheduled,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AuraSurface.muted,
                    ),
              ),
              const SizedBox(height: AuraSpace.s10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('View meeting'),
                  onPressed: () => context.push(
                    _meetingPathFor(meeting, institutionId),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
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
    return institutionId != null && institutionId == meeting.owningInstitutionId
        ? 'Institution meeting'
        : 'Institution meeting';
  }

  return 'Attending';
}

bool _isAttentionItem(Meeting meeting, String meId) {
  if (meeting.isEnded) return false;
  final room = meeting.room?.status;
  if (room == MeetingRoomStatus.guestWaiting ||
      room == MeetingRoomStatus.hostWaiting ||
      room == MeetingRoomStatus.waiting) {
    return true;
  }
  if (_relationshipLabel(meeting, meId: meId, institutionId: null) == 'Invited') {
    return true;
  }
  final scheduled = meeting.scheduledAt;
  if (scheduled == null) return false;
  final delta = scheduled.toLocal().difference(DateTime.now());
  return delta.inMinutes <= 180 && delta.inMinutes >= -15;
}

String _meetingActionLabel(Meeting meeting) {
  if (meeting.isEnded) {
    return 'View meeting';
  }
  final room = meeting.room?.status;
  if (room == MeetingRoomStatus.live || room == MeetingRoomStatus.inProgress) {
    return 'Enter room';
  }
  if (room == MeetingRoomStatus.startingSoon ||
      room == MeetingRoomStatus.waiting ||
      room == MeetingRoomStatus.hostWaiting ||
      room == MeetingRoomStatus.guestWaiting) {
    return 'Open meeting';
  }
  if (meeting.isInstant) {
    return 'Open meeting';
  }
  return 'Open meeting';
}

String _meetingPathFor(Meeting meeting, String? institutionId) {
  final owningInstitutionId =
      (meeting.owningInstitutionId ?? meeting.organizationId ?? '').trim();
  if (owningInstitutionId.isNotEmpty) {
    return '/institution/$owningInstitutionId/meetings/${meeting.id}';
  }
  if (institutionId != null && institutionId.isNotEmpty) {
    return '/institution/$institutionId/meetings/${meeting.id}';
  }
  // A personal meeting has a canonical address. Sending its own card to
  // `/home` was the same defect fixed on the other path during the structural
  // pass -- this is its second copy.
  return '/meetings/${meeting.id}';
}
