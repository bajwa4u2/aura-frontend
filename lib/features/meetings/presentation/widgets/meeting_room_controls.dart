/// THE MEETING ROOM'S CONTROLS, ON THEIR OWN.
///
/// Founder ruling 2026-08-25 §VIII. These were three private classes inside a
/// 3,934-line screen, which is why **no test instantiated any of them**: the
/// only way to reach a private widget is to build its host, and building the
/// host meant a socket, a media engine and twelve providers.
///
/// Nothing about a control bar needs any of that. It renders from a state
/// value and calls back — so moved out here it can be built in a widget test
/// in three lines, and the accessibility and labelling work §VII asks for
/// becomes verifiable rather than asserted.
///
/// This is the workspace/presentation boundary the ruling asks for, applied to
/// the piece with the most product surface. It moves no behaviour: the widgets
/// are the same widgets, at the same call site, with the same arguments.
library;

import 'package:flutter/material.dart';

import '../../../../core/ui/aura_space.dart';
import '../../../realtime/domain/realtime_state.dart';
import '../meeting_semantics.dart';

// ---------------------------------------------------------------------------
// E4 — Control bar: meeting vocabulary, no "call" language
// ---------------------------------------------------------------------------

class MeetingControlBar extends StatelessWidget {
  final RealtimeState state;
  final bool isHost;
  final bool showParticipants;
  final bool showNotes;
  final bool showChat;
  final int unreadChat;
  final bool endingMeeting;
  final bool togglingScreenShare;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleCamera;
  final VoidCallback onToggleParticipants;
  final VoidCallback onToggleNotes;
  final VoidCallback onToggleChat;
  final VoidCallback onInvite;
  final VoidCallback onFiles;
  final bool recordingSupported;
  final bool recording;
  final bool savingRecording;
  final VoidCallback onToggleRecording;
  final VoidCallback onShareScreen;
  final VoidCallback onFlipCamera;
  final VoidCallback onDeviceSettings;
  final VoidCallback onEndMeeting;
  final VoidCallback onLeaveMeeting;
  final bool handRaised;
  final VoidCallback onToggleHand;
  final VoidCallback onReact;

  const MeetingControlBar({
    super.key,
    required this.state,
    required this.isHost,
    required this.showParticipants,
    required this.showNotes,
    required this.showChat,
    required this.unreadChat,
    required this.endingMeeting,
    required this.togglingScreenShare,
    required this.onToggleMic,
    required this.onToggleCamera,
    required this.onToggleParticipants,
    required this.onToggleNotes,
    required this.onToggleChat,
    required this.onInvite,
    required this.onFiles,
    required this.recordingSupported,
    required this.recording,
    required this.savingRecording,
    required this.onToggleRecording,
    required this.onShareScreen,
    required this.onFlipCamera,
    required this.onDeviceSettings,
    required this.onEndMeeting,
    required this.onLeaveMeeting,
    required this.handRaised,
    required this.onToggleHand,
    required this.onReact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xEE030712), Colors.transparent],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      // Control maturity: three intentional clusters — voice & picture,
      // participation, meeting management — instead of one flat feature row.
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AuraSpace.s14,
        runSpacing: AuraSpace.s10,
        children: [
          ControlGroup(
            children: [
              ControlButton(
                icon: state.microphoneEnabled
                    ? Icons.mic_rounded
                    : Icons.mic_off_rounded,
                label: state.microphoneEnabled ? 'Mute' : 'Unmute',
                semanticLabel: MeetingSemantics.toggle(
                  thing: 'Microphone',
                  on: state.microphoneEnabled,
                ),
                active: state.microphoneEnabled,
                onTap: onToggleMic,
              ),
              ControlButton(
                icon: state.cameraEnabled
                    ? Icons.videocam_rounded
                    : Icons.videocam_off_rounded,
                // Was 'Camera' in BOTH states — the one control in the bar
                // whose word never changed, so it never said what pressing it
                // would do. Every other control here names its action.
                label: state.cameraEnabled ? 'Stop video' : 'Start video',
                semanticLabel: MeetingSemantics.toggle(
                  thing: 'Camera',
                  on: state.cameraEnabled,
                ),
                active: state.cameraEnabled,
                onTap: onToggleCamera,
              ),
              ControlButton(
                icon: state.isScreenSharing
                    ? Icons.stop_screen_share_rounded
                    : Icons.screen_share_rounded,
                label: state.isScreenSharing ? 'Stop share' : 'Share',
                semanticLabel: MeetingSemantics.toggle(
                  thing: 'Screen sharing',
                  on: state.isScreenSharing,
                ),
                active: state.isScreenSharing,
                onTap: togglingScreenShare ? null : onShareScreen,
              ),
            ],
          ),
          ControlGroup(
            children: [
              ControlButton(
                icon: Icons.add_reaction_outlined,
                label: 'React',
                semanticLabel: 'Send a reaction',
                active: false,
                onTap: onReact,
              ),
              ControlButton(
                icon: handRaised
                    ? Icons.back_hand_rounded
                    : Icons.back_hand_outlined,
                label: handRaised ? 'Lower' : 'Hand',
                semanticLabel: handRaised
                    ? 'Hand raised. Activate to lower it'
                    : 'Raise your hand to ask to speak',
                active: handRaised,
                onTap: onToggleHand,
              ),
              ControlButton(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Chat',
                // The unread count is a small coloured bubble, which is not
                // information anybody can hear.
                semanticLabel: unreadChat > 0
                    ? 'Meeting notes, $unreadChat unread'
                    : 'Meeting notes',
                active: showChat,
                badge: unreadChat,
                onTap: onToggleChat,
              ),
              ControlButton(
                icon: Icons.people_rounded,
                label: 'People',
                semanticLabel: 'Participants',
                active: showParticipants,
                onTap: onToggleParticipants,
              ),
            ],
          ),
          ControlGroup(
            children: [
              if (recordingSupported)
                ControlButton(
                  icon: recording
                      ? Icons.stop_circle_outlined
                      : Icons.fiber_manual_record_rounded,
                  label: savingRecording
                      ? 'Saving…'
                      : (recording ? 'Stop rec' : 'Record'),
                  active: recording,
                  danger: recording,
                  onTap: savingRecording ? null : onToggleRecording,
                ),
              // Secondary actions live in one place instead of widening the
              // bar: notes & agenda, files, invite, devices, flip camera.
              PopupMenuButton<String>(
                tooltip: 'More',
                color: const Color(0xFF0F172A),
                offset: const Offset(0, -8),
                position: PopupMenuPosition.over,
                onSelected: (value) {
                  switch (value) {
                    case 'notes':
                      onToggleNotes();
                      break;
                    case 'files':
                      onFiles();
                      break;
                    case 'invite':
                      onInvite();
                      break;
                    case 'devices':
                      onDeviceSettings();
                      break;
                    case 'flip':
                      onFlipCamera();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  _moreItem('notes', Icons.notes_rounded, 'Notes & agenda',
                      highlighted: showNotes),
                  _moreItem(
                      'files', Icons.folder_shared_outlined, 'Files & materials'),
                  _moreItem(
                      'invite', Icons.person_add_alt_rounded, 'Invite'),
                  _moreItem('devices', Icons.tune_rounded, 'Devices'),
                  if (state.isVideoMode && state.cameraEnabled)
                    _moreItem(
                        'flip', Icons.flip_camera_ios_rounded, 'Flip camera'),
                ],
                child: const ControlButton(
                  icon: Icons.more_horiz_rounded,
                  label: 'More',
                  active: false,
                  menuChild: true,
                ),
              ),
              if (isHost)
                ControlButton(
                  icon: Icons.stop_rounded,
                  label: endingMeeting ? 'Ending...' : 'End',
                  active: false,
                  danger: true,
                  onTap: endingMeeting ? null : onEndMeeting,
                )
              else
                ControlButton(
                  icon: Icons.logout_rounded,
                  label: 'Leave',
                  active: false,
                  danger: true,
                  onTap: onLeaveMeeting,
                ),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _moreItem(
    String value,
    IconData icon,
    String label, {
    bool highlighted = false,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 40,
      child: Row(
        children: [
          Icon(icon,
              size: 18,
              color: highlighted
                  ? const Color(0xFF8B85FF)
                  : const Color(0xFF9CA3AF)),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: highlighted ? const Color(0xFF8B85FF) : const Color(0xFFE5E7EB),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// A quiet cluster container — related controls read as one unit.
class ControlGroup extends StatelessWidget {
  final List<Widget> children;

  const ControlGroup({
    super.key,required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x66101B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x331E293B)),
      ),
      child: Wrap(
        spacing: AuraSpace.s8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      ),
    );
  }
}

class ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool danger;
  // Unread count bubble (e.g. chat); hidden when 0.
  final int badge;
  final VoidCallback? onTap;

  /// True when this button is the CHILD of a PopupMenuButton: taps must pass
  /// through to the menu (onTap stays null) but the button must not render
  /// as disabled.
  final bool menuChild;

  /// WHAT THIS CONTROL IS, SPOKEN.
  ///
  /// §VII. The visible label is a single word chosen to fit under a 48px
  /// square — "Mute", "Hand", "People". Read aloud with no picture beside it,
  /// those say almost nothing: "Hand" does not tell a person whether their
  /// hand is currently raised, and "Camera" (which this bar showed in BOTH
  /// states) does not tell them whether they are on screen. Every control in
  /// the bar therefore carries a spoken form that includes its state and its
  /// effect, and this is the one place it is attached.
  final String? semanticLabel;

  const ControlButton({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    this.danger = false,
    this.badge = 0,
    this.onTap,
    this.menuChild = false,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final bg = danger
        ? const Color(0xFFDC2626)
        : active
            ? const Color(0xFF1E293B)
            : const Color(0xFF0F172A);
    final fg = danger ? Colors.white : const Color(0xFFE5E7EB);

    return Semantics(
      button: true,
      enabled: onTap != null || menuChild,
      toggled: danger ? null : active,
      label: semanticLabel ?? label,
      // The visible word would otherwise be read a second time after the
      // spoken label — "Microphone on. Activate to turn off. Mute."
      excludeSemantics: true,
      child: GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: (onTap == null && !menuChild)
                      ? bg.withValues(alpha: 0.5)
                      : bg,
                  borderRadius: BorderRadius.circular(12),
                  border: active && !danger
                      ? Border.all(
                          color:
                              const Color(0xFF6C63FF).withValues(alpha: 0.5),
                        )
                      : null,
                ),
                child: Icon(icon, color: fg, size: 22),
              ),
              if (badge > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    constraints: const BoxConstraints(minWidth: 16),
                    child: Text(
                      badge > 99 ? '99+' : '$badge',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: danger ? const Color(0xFFFCA5A5) : const Color(0xFF9CA3AF),
              fontSize: 11,
            ),
          ),
        ],
      ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// E5 — Participant panel
// ---------------------------------------------------------------------------

