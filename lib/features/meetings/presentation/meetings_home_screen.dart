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
import '../../share/aura_share_sheet.dart';
import '../application/meetings_provider.dart';
import '../domain/availability_profile.dart';
import '../domain/meeting.dart';
import '../domain/meeting_room.dart';

class MeetingsHomeScreen extends ConsumerStatefulWidget {
  final String? institutionId;

  const MeetingsHomeScreen({super.key, this.institutionId});

  @override
  ConsumerState<MeetingsHomeScreen> createState() => _MeetingsHomeScreenState();
}

class _MeetingsHomeScreenState extends ConsumerState<MeetingsHomeScreen> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
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
    ref.invalidate(meetingStateChangedEventProvider);
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
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: ListView(
          padding: const EdgeInsets.all(AuraSpace.s16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(
                      onCreate: () => context.push(_createPath(instant: false)),
                      onInstant: () => context.push(_createPath(instant: true)),
                      onJoinByCode: () => _showJoinDialog(context),
                    ),
                    const SizedBox(height: AuraSpace.s18),
                    _BookingLinkCard(
                      profilesAsync: profilesAsync,
                      institutionId: institutionId,
                    ),
                    const SizedBox(height: AuraSpace.s18),
                    _SectionShell(
                      title: 'Needs attention',
                      child: upcomingAsync.when(
                        loading: () => const _SectionLoading(),
                        error: (e, _) => _SectionError(message: '$e'),
                        data: (meetings) {
                          final items = meetings
                              .where(
                                (meeting) => _isAttentionItem(meeting, meId),
                              )
                              .toList(growable: false);
                          if (items.isEmpty) {
                            return const _SectionEmpty(
                              message: 'No meetings need attention.',
                            );
                          }
                          return Column(
                            children: [
                              for (final meeting in items)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AuraSpace.s10,
                                  ),
                                  child: _MeetingCard(
                                    meeting: meeting,
                                    meId: meId,
                                    institutionId: institutionId,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AuraSpace.s18),
                    _SectionShell(
                      title: 'Upcoming',
                      child: upcomingAsync.when(
                        loading: () => const _SectionLoading(),
                        error: (e, _) => _SectionError(message: '$e'),
                        data: (meetings) => _MeetingListSection(
                          meetings: meetings,
                          emptyMessage: 'No upcoming meetings.',
                          meId: meId,
                          institutionId: institutionId,
                        ),
                      ),
                    ),
                    const SizedBox(height: AuraSpace.s18),
                    _SectionShell(
                      title: 'Invitations',
                      child: upcomingAsync.when(
                        loading: () => const _SectionLoading(),
                        error: (e, _) => _SectionError(message: '$e'),
                        data: (meetings) {
                          final invited = meetings
                              .where(
                                (meeting) => _relationshipLabel(
                                  meeting,
                                  meId: meId,
                                  institutionId: institutionId,
                                ) ==
                                'Invited',
                              )
                              .toList(growable: false);
                          if (invited.isEmpty) {
                            return const _SectionEmpty(
                              message: 'No pending invitations.',
                            );
                          }
                          return Column(
                            children: [
                              for (final meeting in invited)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AuraSpace.s10,
                                  ),
                                  child: _MeetingCard(
                                    meeting: meeting,
                                    meId: meId,
                                    institutionId: institutionId,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AuraSpace.s18),
                    _SectionShell(
                      title: 'Follow-up',
                      child: outcomesAsync.when(
                        loading: () => const _SectionLoading(),
                        error: (e, _) => _SectionError(message: '$e'),
                        data: (outcomes) {
                          if (outcomes.isEmpty) {
                            return const _SectionEmpty(
                              message: 'No open follow-up items.',
                            );
                          }
                          return Column(
                            children: [
                              for (final outcome in outcomes)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AuraSpace.s10,
                                  ),
                                  child: _OutcomeCard(
                                    outcome: outcome,
                                    institutionId: institutionId,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AuraSpace.s18),
                    _SectionShell(
                      title: 'Past',
                      child: pastAsync.when(
                        loading: () => const _SectionLoading(),
                        error: (e, _) => _SectionError(message: '$e'),
                        data: (meetings) => _PastMeetingsSection(
                          meetings: meetings,
                          meId: meId,
                          institutionId: institutionId,
                        ),
                      ),
                    ),
                    const SizedBox(height: AuraSpace.s32),
                  ],
                ),
              ),
            ),
          ],
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

class _Header extends StatelessWidget {
  final VoidCallback onCreate;
  final VoidCallback onInstant;
  final VoidCallback onJoinByCode;

  const _Header({
    required this.onCreate,
    required this.onInstant,
    required this.onJoinByCode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Meetings',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: AuraSpace.s6),
        Text(
          'Host, attend, and manage your meetings.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AuraSurface.muted,
              ),
        ),
        const SizedBox(height: AuraSpace.s14),
        Wrap(
          spacing: AuraSpace.s10,
          runSpacing: AuraSpace.s10,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create meeting'),
              onPressed: onCreate,
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.video_call_rounded),
              label: const Text('Start instant meeting'),
              onPressed: onInstant,
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.tag_rounded),
              label: const Text('Join by code'),
              onPressed: onJoinByCode,
            ),
          ],
        ),
      ],
    );
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

class _BookingLinkCard extends ConsumerWidget {
  final AsyncValue<List<AvailabilityProfile>> profilesAsync;
  final String? institutionId;

  const _BookingLinkCard({
    required this.profilesAsync,
    required this.institutionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AuraCard(
      padding: const EdgeInsets.all(AuraSpace.s16),
      child: profilesAsync.when(
        loading: () => const _BookingLinkLoading(),
        error: (e, _) => _SectionError(message: '$e'),
        data: (profiles) {
          final profile = _pickProfile(profiles);
          if (profile == null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your booking page',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: AuraSpace.s8),
                const Text('Your booking page has not been enabled yet.'),
                const SizedBox(height: AuraSpace.s12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Open booking pages'),
                  onPressed: () => context.push(_manageBookingPath()),
                ),
              ],
            );
          }

          final publicUrl = '${AppConfig.publicWebUrl}${profile.publicUrl}';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your booking page',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: AuraSpace.s6),
              Text(
                publicUrl,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AuraSpace.s12),
              Wrap(
                spacing: AuraSpace.s10,
                runSpacing: AuraSpace.s10,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copy link'),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: publicUrl));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Booking link copied')),
                        );
                      }
                    },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Open page'),
                    onPressed: () => context.push(profile.publicUrl),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Share'),
                    onPressed: () => showAuraShareSheet(
                      context,
                      shareUrl: publicUrl,
                      headline: 'Your booking page',
                      subtitle: profile.name,
                      copyMessage: 'Booking link copied',
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  AvailabilityProfile? _pickProfile(List<AvailabilityProfile> profiles) {
    if (profiles.isEmpty) return null;
    final active = profiles.where((p) => p.isActive).toList(growable: false);
    if (active.isNotEmpty) return active.first;
    return profiles.first;
  }

  // Booking pages are institution-governed; this card only renders inside
  // an institution workspace, so the institution route is the only path.
  String _manageBookingPath() => '/institution/$institutionId/availability';
}

class _SectionShell extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionShell({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: AuraSpace.s10),
        child,
      ],
    );
  }
}

class _SectionLoading extends StatelessWidget {
  const _SectionLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AuraSpace.s16),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _SectionError extends StatelessWidget {
  final String message;

  const _SectionError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Unable to load. $message',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AuraSurface.muted,
          ),
    );
  }
}

class _SectionEmpty extends StatelessWidget {
  final String message;

  const _SectionEmpty({required this.message});

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      padding: const EdgeInsets.all(AuraSpace.s16),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AuraSurface.muted,
            ),
      ),
    );
  }
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
      return const _SectionEmpty(message: 'No past meetings.');
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
          const _SectionEmpty(message: 'No past meetings match.')
        else ...[
          for (final meeting in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: AuraSpace.s10),
              child: _MeetingCard(
                meeting: meeting,
                meId: widget.meId,
                institutionId: widget.institutionId,
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

class _MeetingListSection extends StatelessWidget {
  final List<Meeting> meetings;
  final String emptyMessage;
  final String meId;
  final String? institutionId;

  const _MeetingListSection({
    required this.meetings,
    required this.emptyMessage,
    required this.meId,
    required this.institutionId,
  });

  @override
  Widget build(BuildContext context) {
    if (meetings.isEmpty) {
      return _SectionEmpty(message: emptyMessage);
    }

    return Column(
      children: [
        for (final meeting in meetings)
          Padding(
            padding: const EdgeInsets.only(bottom: AuraSpace.s10),
            child: _MeetingCard(
              meeting: meeting,
              meId: meId,
              institutionId: institutionId,
            ),
          ),
      ],
    );
  }
}

class _MeetingCard extends StatelessWidget {
  final Meeting meeting;
  final String meId;
  final String? institutionId;

  const _MeetingCard({
    required this.meeting,
    required this.meId,
    required this.institutionId,
  });

  @override
  Widget build(BuildContext context) {
    final relationship = _relationshipLabel(
      meeting,
      meId: meId,
      institutionId: institutionId,
    );
    final status = _statusLabel(meeting);
    final hostName = meeting.host?.name ?? 'Unknown host';
    final meetingInstitution =
        meeting.owningInstitution?.name ?? meeting.institution?.name ?? '';
    final scheduledAt = meeting.scheduledAt;
    final timeLabel = scheduledAt == null
        ? 'Instant meeting'
        : DateFormat('EEE, MMM d, h:mm a').format(scheduledAt.toLocal());

    return AuraCard(
      padding: const EdgeInsets.all(AuraSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  meeting.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              _Pill(label: status),
            ],
          ),
          const SizedBox(height: AuraSpace.s8),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: [
              _Pill(label: relationship),
              if (meetingInstitution.trim().isNotEmpty)
                _Pill(label: meetingInstitution),
            ],
          ),
          const SizedBox(height: AuraSpace.s10),
          Text(
            '$timeLabel · $hostName',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AuraSurface.muted,
                ),
          ),
          const SizedBox(height: AuraSpace.s10),
          Text(
            _meetingActionLabel(meeting),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AuraSurface.faint,
                ),
          ),
          const SizedBox(height: AuraSpace.s12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              icon: Icon(_actionIcon(meeting)),
              label: Text(_meetingActionLabel(meeting)),
              onPressed: () => _openMeeting(context),
            ),
          ),
        ],
      ),
    );
  }

  void _openMeeting(BuildContext context) {
    final path = _meetingPath();
    context.push(path);
  }

  String _meetingPath() {
    final owningInstitutionId = meeting.owningInstitutionId ??
        meeting.organizationId ??
        '';
    if (owningInstitutionId.trim().isNotEmpty) {
      return '/institution/$owningInstitutionId/meetings/${meeting.id}';
    }
    return '/home';
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
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: AuraSpace.s8),
          child: Center(child: CircularProgressIndicator()),
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

class _BookingLinkLoading extends StatelessWidget {
  const _BookingLinkLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AuraSpace.s12),
      child: SizedBox(
        height: 24,
        child: LinearProgressIndicator(),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;

  const _Pill({required this.label});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AuraSurface.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AuraSurface.accentText,
              ),
        ),
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

String _statusLabel(Meeting meeting) {
  if (meeting.isEnded) {
    return meeting.state == 'CANCELLED' ? 'Cancelled' : 'Completed';
  }
  final room = meeting.room?.status;
  if (room == MeetingRoomStatus.live || room == MeetingRoomStatus.inProgress) {
    return 'Live';
  }
  if (room == MeetingRoomStatus.startingSoon) {
    return 'Starting soon';
  }
  if (meeting.participants.any((p) => p.rsvpStatus == 'PENDING')) {
    return 'Awaiting response';
  }
  return 'Scheduled';
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

IconData _actionIcon(Meeting meeting) {
  final room = meeting.room?.status;
  if (room == MeetingRoomStatus.live || room == MeetingRoomStatus.inProgress) {
    return Icons.meeting_room_rounded;
  }
  if (meeting.isEnded) {
    return Icons.visibility_rounded;
  }
  return Icons.open_in_new_rounded;
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
  return '/home';
}
