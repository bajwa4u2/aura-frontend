import '../domain/meeting.dart';
import '../domain/meeting_room.dart';

enum MeetingLifecycleStatus {
  scheduled,
  startingSoon,
  guestWaiting,
  hostWaiting,
  inProgress,
  ended,
  missed,
  cancelled,
  connectionIssue,
  unknown,
}

class MeetingLifecycleViewModel {
  final MeetingLifecycleStatus status;
  final String label;
  final String subtitle;
  final String cue;
  final String primaryAction;
  final bool canStart;
  final bool canEnter;
  final bool canRetryTransport;
  final bool isTerminal;

  const MeetingLifecycleViewModel({
    required this.status,
    required this.label,
    required this.subtitle,
    required this.cue,
    required this.primaryAction,
    required this.canStart,
    required this.canEnter,
    required this.canRetryTransport,
    required this.isTerminal,
  });

  bool get isLive => status == MeetingLifecycleStatus.inProgress;
}

class MeetingLifecyclePresenter {
  const MeetingLifecyclePresenter._();

  static MeetingLifecycleViewModel present(
    Meeting meeting, {
    MeetingRoom? room,
    DateTime? now,
    bool isHost = false,
  }) {
    final current = now ?? DateTime.now();
    final scheduledStart = meeting.scheduledAt;
    final scheduledEnd =
        scheduledStart?.add(Duration(minutes: meeting.durationMinutes));
    final roomStatus = room?.status ?? MeetingRoomStatus.unknown;
    final minutesToStart = scheduledStart?.difference(current).inMinutes;
    final isPastScheduledEnd =
        scheduledEnd != null && current.isAfter(scheduledEnd);

    MeetingLifecycleStatus status;
    String label;
    String subtitle;
    String cue;
    String primaryAction;
    bool canStart;
    bool canEnter;
    bool canRetryTransport;
    bool isTerminal = false;

    switch (roomStatus) {
      case MeetingRoomStatus.cancelled:
        status = MeetingLifecycleStatus.cancelled;
        label = 'Cancelled';
        subtitle = 'This meeting was cancelled.';
        cue = 'The meeting is no longer available.';
        primaryAction = 'View summary';
        canStart = false;
        canEnter = false;
        canRetryTransport = false;
        isTerminal = true;
        break;
      case MeetingRoomStatus.ended:
        status = MeetingLifecycleStatus.ended;
        label = 'Ended';
        subtitle = 'This meeting has ended.';
        cue = 'You can still review the details and follow-up items.';
        primaryAction = 'View summary';
        canStart = false;
        canEnter = false;
        canRetryTransport = false;
        isTerminal = true;
        break;
      case MeetingRoomStatus.missed:
        status = MeetingLifecycleStatus.missed;
        label = 'Missed';
        subtitle = 'The meeting window passed without a live session.';
        cue = 'Review the meeting and decide whether to follow up.';
        primaryAction = 'View summary';
        canStart = false;
        canEnter = false;
        canRetryTransport = false;
        isTerminal = true;
        break;
      case MeetingRoomStatus.connectionIssue:
        status = MeetingLifecycleStatus.connectionIssue;
        label = 'Connection issue';
        subtitle =
            'The meeting room is still active, but the connection needs a retry.';
        cue = 'The meeting is still open.';
        primaryAction = 'Retry connection';
        canStart = true;
        canEnter = true;
        canRetryTransport = true;
        break;
      case MeetingRoomStatus.live:
      case MeetingRoomStatus.inProgress:
        status = MeetingLifecycleStatus.inProgress;
        label = 'In progress';
        subtitle = 'The meeting is live.';
        cue = '${room?.activeParticipantCount ?? 0} participants in the room.';
        primaryAction = 'Enter room';
        canStart = false;
        canEnter = true;
        canRetryTransport = true;
        break;
      case MeetingRoomStatus.hostWaiting:
        status = MeetingLifecycleStatus.hostWaiting;
        label = 'Host waiting';
        subtitle = 'The host is in the room and waiting.';
        cue = 'The guest can join when ready.';
        primaryAction = 'Enter room';
        canStart = false;
        canEnter = true;
        canRetryTransport = true;
        break;
      case MeetingRoomStatus.guestWaiting:
        status = MeetingLifecycleStatus.guestWaiting;
        label = 'Guest waiting';
        subtitle = 'The guest is here and waiting.';
        cue = 'The host can open the room at any time.';
        primaryAction = 'Enter room';
        canStart = false;
        canEnter = true;
        canRetryTransport = true;
        break;
      case MeetingRoomStatus.startingSoon:
        if (isPastScheduledEnd) {
          status = MeetingLifecycleStatus.missed;
          label = 'Missed';
          subtitle = 'The scheduled time passed without an active meeting.';
          cue = 'Review the meeting and decide whether to follow up.';
          primaryAction = 'View summary';
          canStart = false;
          canEnter = false;
          canRetryTransport = false;
          isTerminal = true;
        } else {
          status = MeetingLifecycleStatus.startingSoon;
          label = 'Starting soon';
          subtitle = minutesToStart == null
              ? 'The meeting is about to begin.'
              : 'Starts in ${minutesToStart.abs()} min';
          cue = 'Everything is ready.';
          primaryAction = 'Start meeting';
          canStart = true;
          canEnter = true;
          canRetryTransport = true;
        }
        break;
      case MeetingRoomStatus.waiting:
      case MeetingRoomStatus.scheduled:
      case MeetingRoomStatus.unknown:
        // Entry truthfulness: when the realtime room carries no signal (empty
        // room, no session yet, public by-code fetch), the meeting RECORD is
        // the ground truth. A started meeting is live even with nobody in the
        // room yet, and an ended/cancelled meeting is terminal — neither may
        // fall through to "Scheduled"/"Missed".
        final recordState = meeting.state.toUpperCase();
        if (recordState == 'ACTIVE') {
          status = MeetingLifecycleStatus.inProgress;
          label = 'Live now';
          subtitle = 'The meeting is live.';
          cue = (room?.activeParticipantCount ?? 0) > 0
              ? '${room?.activeParticipantCount} participants in the room.'
              : 'You can join now.';
          primaryAction = isHost ? 'Enter room' : 'Join meeting';
          canStart = false;
          canEnter = true;
          canRetryTransport = true;
          break;
        }
        if (recordState == 'ENDED') {
          status = MeetingLifecycleStatus.ended;
          label = 'Ended';
          subtitle = 'This meeting has ended.';
          cue = 'You can still review the details and follow-up items.';
          primaryAction = 'View summary';
          canStart = false;
          canEnter = false;
          canRetryTransport = false;
          isTerminal = true;
          break;
        }
        if (recordState == 'CANCELLED') {
          status = MeetingLifecycleStatus.cancelled;
          label = 'Cancelled';
          subtitle = 'This meeting was cancelled.';
          cue = 'The meeting is no longer available.';
          primaryAction = 'View summary';
          canStart = false;
          canEnter = false;
          canRetryTransport = false;
          isTerminal = true;
          break;
        }
        if (isPastScheduledEnd) {
          status = MeetingLifecycleStatus.missed;
          label = 'Missed';
          subtitle = 'The scheduled time passed without an active meeting.';
          cue = 'Review the meeting and decide whether to follow up.';
          primaryAction = 'View summary';
          canStart = false;
          canEnter = false;
          canRetryTransport = false;
          isTerminal = true;
        } else if (scheduledStart != null &&
            minutesToStart != null &&
            minutesToStart <= 15 &&
            minutesToStart > 0) {
          status = MeetingLifecycleStatus.startingSoon;
          label = 'Starting soon';
          subtitle = 'Starts in $minutesToStart min';
          cue = isHost
              ? 'Prepare to open the room.'
              : 'You are in the right place.';
          primaryAction = isHost ? 'Start meeting' : 'Wait for host';
          canStart = true;
          canEnter = true;
          canRetryTransport = true;
        } else if ((room?.activeParticipantCount ?? 0) > 0) {
          status = isHost
              ? MeetingLifecycleStatus.hostWaiting
              : MeetingLifecycleStatus.guestWaiting;
          label = isHost ? 'Host waiting' : 'Guest waiting';
          subtitle = isHost
              ? 'The host is ready and waiting for the guest.'
              : 'The guest is ready and waiting for the host.';
          cue = 'The meeting stays open until the host ends it.';
          primaryAction = 'Enter room';
          canStart = true;
          canEnter = true;
          canRetryTransport = true;
        } else {
          status = MeetingLifecycleStatus.scheduled;
          label = 'Scheduled';
          subtitle = scheduledStart == null
              ? 'The meeting is scheduled.'
              : 'Starts at ${_formatTime(scheduledStart)}';
          cue = 'The meeting will open when the host starts it.';
          primaryAction = 'Start meeting';
          canStart = true;
          canEnter = true;
          canRetryTransport = true;
        }
        break;
    }

    return MeetingLifecycleViewModel(
      status: status,
      label: label,
      subtitle: subtitle,
      cue: cue,
      primaryAction: primaryAction,
      canStart: canStart,
      canEnter: canEnter,
      canRetryTransport: canRetryTransport,
      isTerminal: isTerminal,
    );
  }
}

String _formatTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}
