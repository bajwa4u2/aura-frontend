import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/ui/aura_radius.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_surface.dart';
import '../../../../core/ui/aura_text.dart';
import '../../../meetings/application/meetings_provider.dart';
import '../../../meetings/domain/meeting.dart';
import 'me_widgets.dart';

/// Profile → Participation — the member's continuity home for institutional
/// meeting participation.
///
/// Everything rendered here is a PROJECTION of the canonical institution
/// meeting record: nothing is user-owned, nothing is duplicated, and every
/// item resolves back into its owning institution's meeting, subject to that
/// institution's authorization. There is deliberately no personal meeting
/// route and no "My Meetings" inventory — meetings belong to institutions;
/// members participate in them.
class MeParticipationContinuity extends ConsumerStatefulWidget {
  const MeParticipationContinuity({
    super.key,
    required this.meId,
    required this.meEmail,
  });

  /// The signed-in member's user id — participation is identity-centric.
  final String meId;
  final String meEmail;

  @override
  ConsumerState<MeParticipationContinuity> createState() =>
      _MeParticipationContinuityState();
}

class _MeParticipationContinuityState
    extends ConsumerState<MeParticipationContinuity> {
  static const int _sectionCap = 5;

  @override
  void initState() {
    super.initState();
    // Continuity must reflect backend truth on every Profile visit — these
    // are cached FutureProviders shared with the institution workspace.
    Future.microtask(() {
      if (!mounted) return;
      ref.invalidate(upcomingMeetingsProvider);
      ref.invalidate(pastMeetingsProvider);
      ref.invalidate(myOpenOutcomesProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final upcomingAsync = ref.watch(upcomingMeetingsProvider);
    final pastAsync = ref.watch(pastMeetingsProvider);
    final outcomesAsync = ref.watch(myOpenOutcomesProvider);

    final loading =
        upcomingAsync.isLoading || pastAsync.isLoading || outcomesAsync.isLoading;

    final upcoming = upcomingAsync.valueOrNull ?? const <Meeting>[];
    final past = pastAsync.valueOrNull ?? const <Meeting>[];
    final outcomes = outcomesAsync.valueOrNull ?? const <MeetingOutcome>[];

    final invitations = upcoming
        .where((m) => _isPendingInvitation(m))
        .toList(growable: false);
    final upcomingConfirmed = upcoming
        .where((m) => !_isPendingInvitation(m))
        .toList(growable: false);
    final sharedSummaries = past
        .where((m) => m.summary?.sharedAt != null)
        .toList(growable: false);
    final sharedRecordings =
        past.where((m) => m.recordingCount > 0).toList(growable: false);

    final hasAny = upcoming.isNotEmpty ||
        past.isNotEmpty ||
        outcomes.isNotEmpty;

    if (loading && !hasAny) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AuraSpace.s16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (!hasAny) {
      final failed = upcomingAsync.hasError || pastAsync.hasError;
      return _EmptyCard(
        title: failed ? 'Participation unavailable' : 'No participation yet',
        body: failed
            ? 'Your participation record could not be loaded. Pull to refresh '
                'or try again later.'
            : 'Institution meetings you are invited to, book, or attend will '
                'build your participation record here.',
      );
    }

    final sections = <Widget>[
      if (invitations.isNotEmpty)
        _meetingSection(
          title: 'Meeting Invitations',
          icon: Icons.mail_outline_rounded,
          meetings: invitations,
          badgeBuilder: (_) => const MeStatusBadge(
            label: 'Response needed',
            style: MeStatusStyle.warn,
          ),
        ),
      if (upcomingConfirmed.isNotEmpty)
        _meetingSection(
          title: 'Upcoming Participation',
          icon: Icons.event_outlined,
          meetings: upcomingConfirmed,
          badgeBuilder: _relationshipBadge,
        ),
      if (outcomes.isNotEmpty) _commitmentsSection(outcomes),
      if (past.isNotEmpty)
        _meetingSection(
          title: 'Past Participation',
          icon: Icons.history_rounded,
          meetings: past,
          badgeBuilder: _attendanceBadge,
        ),
      if (sharedSummaries.isNotEmpty)
        _meetingSection(
          title: 'Shared Summaries',
          icon: Icons.description_outlined,
          meetings: sharedSummaries,
          badgeBuilder: (_) => const MeStatusBadge(
            label: 'Summary shared',
            style: MeStatusStyle.good,
          ),
        ),
      if (sharedRecordings.isNotEmpty)
        _meetingSection(
          title: 'Shared Recordings',
          icon: Icons.play_circle_outline_rounded,
          meetings: sharedRecordings,
          badgeBuilder: (m) => MeStatusBadge(
            label: m.recordingCount == 1
                ? '1 recording'
                : '${m.recordingCount} recordings',
            style: MeStatusStyle.neutral,
          ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: AuraSpace.s16),
          sections[i],
        ],
      ],
    );
  }

  // ── SECTIONS ───────────────────────────────────────────────────────────────

  Widget _meetingSection({
    required String title,
    required IconData icon,
    required List<Meeting> meetings,
    required Widget? Function(Meeting) badgeBuilder,
  }) {
    return MeSection(
      title: title,
      children: [
        for (final meeting in meetings.take(_sectionCap))
          MeSettingsItem(
            label: meeting.title,
            icon: icon,
            subtitle: _meetingSubtitle(meeting),
            trailing: badgeBuilder(meeting),
            onTap: _meetingOnTap(meeting),
          ),
      ],
    );
  }

  Widget _commitmentsSection(List<MeetingOutcome> outcomes) {
    // Assigned commitments first — follow-up requiring the member outranks
    // open items they merely witnessed.
    final ordered = [...outcomes]..sort((a, b) {
        final aMine = a.ownerId == widget.meId ? 0 : 1;
        final bMine = b.ownerId == widget.meId ? 0 : 1;
        if (aMine != bMine) return aMine - bMine;
        return a.createdAt.compareTo(b.createdAt);
      });

    return MeSection(
      title: 'Commitments & Follow-up',
      children: [
        for (final outcome in ordered.take(_sectionCap))
          MeSettingsItem(
            label: outcome.text,
            icon: Icons.task_alt_rounded,
            subtitle: _outcomeSubtitle(outcome),
            trailing: outcome.ownerId == widget.meId
                ? const MeStatusBadge(
                    label: 'Assigned to you',
                    style: MeStatusStyle.warn,
                  )
                : null,
            onTap: _outcomeOnTap(outcome),
          ),
      ],
    );
  }

  // ── PROJECTION HELPERS ─────────────────────────────────────────────────────

  MeetingParticipant? _myParticipant(Meeting meeting) {
    for (final participant in meeting.participants) {
      if ((participant.userId ?? '').trim() == widget.meId) return participant;
    }
    return null;
  }

  bool _isBooker(Meeting meeting) {
    final identity = meeting.booking?.bookerIdentity;
    if (identity == null) return false;
    if (identity.auraUserId == widget.meId ||
        identity.memberId == widget.meId) {
      return true;
    }
    final email = widget.meEmail.trim().toLowerCase();
    return email.isNotEmpty && identity.email.trim().toLowerCase() == email;
  }

  bool _isPendingInvitation(Meeting meeting) {
    if ((meeting.host?.id ?? '') == widget.meId) return false;
    return _myParticipant(meeting)?.rsvpStatus == 'PENDING';
  }

  Widget? _relationshipBadge(Meeting meeting) {
    if ((meeting.host?.id ?? '') == widget.meId) {
      return const MeStatusBadge(label: 'Host', style: MeStatusStyle.neutral);
    }
    if (_isBooker(meeting)) {
      return const MeStatusBadge(label: 'Booked', style: MeStatusStyle.neutral);
    }
    return null;
  }

  Widget? _attendanceBadge(Meeting meeting) {
    if (meeting.state == 'CANCELLED') {
      return const MeStatusBadge(
        label: 'Cancelled',
        style: MeStatusStyle.neutral,
      );
    }
    final attended = _myParticipant(meeting)?.attended ??
        ((meeting.host?.id ?? '') == widget.meId);
    return attended
        ? const MeStatusBadge(label: 'Attended', style: MeStatusStyle.good)
        : null;
  }

  String _meetingSubtitle(Meeting meeting) {
    final institution = meeting.owningInstitution?.name.trim() ?? '';
    final scheduledAt = meeting.scheduledAt;
    final when = scheduledAt == null
        ? (meeting.isInstant ? 'Instant meeting' : '')
        : DateFormat('EEE, MMM d, yyyy · h:mm a').format(scheduledAt.toLocal());
    return [institution, when]
        .where((part) => part.isNotEmpty)
        .join(' · ');
  }

  String _outcomeSubtitle(MeetingOutcome outcome) {
    final title = (outcome.meetingTitle ?? '').trim();
    final scheduledAt = outcome.meetingScheduledAt;
    final when = scheduledAt == null
        ? ''
        : DateFormat('MMM d, yyyy').format(scheduledAt.toLocal());
    final due = outcome.dueDate == null
        ? ''
        : 'Due ${DateFormat('MMM d, yyyy').format(outcome.dueDate!.toLocal())}';
    return [title, when, due].where((part) => part.isNotEmpty).join(' · ');
  }

  // ── CANONICAL ROUTING ──────────────────────────────────────────────────────
  // Every participation item opens the owning institution's meeting record.
  // Authorization is the institution's: the meeting screen re-resolves access
  // on arrival, so revoked access degrades there, not here. Items whose
  // institution is unknown are inert — there is no personal meeting route.

  VoidCallback? _meetingOnTap(Meeting meeting) {
    final institutionId = (meeting.owningInstitutionId ?? '').trim();
    if (institutionId.isEmpty) return null;
    return () =>
        context.push('/institution/$institutionId/meetings/${meeting.id}');
  }

  VoidCallback? _outcomeOnTap(MeetingOutcome outcome) {
    final institutionId = (outcome.meetingInstitutionId ?? '').trim();
    if (institutionId.isEmpty) return null;
    return () => context
        .push('/institution/$institutionId/meetings/${outcome.meetingId}');
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s20),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.xl),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AuraText.title),
          const SizedBox(height: AuraSpace.s8),
          Text(
            body,
            style: AuraText.small.copyWith(
              color: AuraSurface.muted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
