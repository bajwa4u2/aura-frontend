import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../ui/aura_space.dart';
import '../ui/aura_surface.dart';
import 'call_readiness.dart';
import 'device_permission.dart';

/// BEFORE THE CALL STARTS — the explicit ask, with a reason.
///
/// Founder ruling, A/V reconstruction §6 and §8.
///
/// ## What this replaces
///
/// Measured in the released client: pressing **Call** in a Conversation
/// created the session and pushed straight into the room. Consequences, in
/// order of severity:
///
/// 1. The OS permission prompt appeared **mid-join**, with no explanation of
///    what was being asked for or why — the exact "do not merely request
///    permissions immediately on screen load" failure the ruling names.
/// 2. The other person was **rung before the caller knew they had a working
///    microphone**. A call that cannot carry audio still woke somebody up.
/// 3. A refusal surfaced as a failure inside the room, where the only offer
///    was to leave.
///
/// So the ask moved in front of the call, where it can be explained, and the
/// session is not created until the person has actually decided to proceed.
///
/// ## Why it is shared
///
/// §8: one preflight, reusable by Meetings, thread calls, and any other
/// legitimate synchronous entry point. The presentation is deliberately plain
/// so the surfaces above it differ in framing, not in behaviour.
class CallPreflightSheet extends StatefulWidget {
  const CallPreflightSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.wantsCamera,
    required this.confirmLabel,
  });

  /// Who this call is with, in their real name. §13: never "User" or
  /// "Someone" where governed identity exists.
  final String title;

  /// What kind of call, and any context worth knowing before joining.
  final String subtitle;

  /// A voice call must not ask for a camera it will never use.
  final bool wantsCamera;

  final String confirmLabel;

  /// Returns true when the person chose to proceed, false or null otherwise.
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool wantsCamera,
    String confirmLabel = 'Start call',
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CallPreflightSheet(
        title: title,
        subtitle: subtitle,
        wantsCamera: wantsCamera,
        confirmLabel: confirmLabel,
      ),
    );
  }

  @override
  State<CallPreflightSheet> createState() => _CallPreflightSheetState();
}

class _CallPreflightSheetState extends State<CallPreflightSheet> {
  late final CallReadiness _readiness = CallReadiness(
    wantsCamera: widget.wantsCamera,
  );
  RTCVideoRenderer? _renderer;

  @override
  void initState() {
    super.initState();
    _readiness.addListener(_onReadiness);
    // The ask happens on open, but the person is already looking at WHAT is
    // being asked for and WHY — which is the difference between an explained
    // request and a prompt that ambushes them mid-join.
    _readiness.check();
  }

  Future<void> _onReadiness() async {
    final stream = _readiness.preview;
    if (stream != null && stream.getVideoTracks().isNotEmpty) {
      final renderer = _renderer ?? RTCVideoRenderer();
      if (_renderer == null) {
        await renderer.initialize();
        _renderer = renderer;
      }
      renderer.srcObject = stream;
    } else if (_renderer != null) {
      _renderer!.srcObject = null;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _readiness.removeListener(_onReadiness);
    // Release BEFORE the room opens its own capture. Two live captures of one
    // camera is the orphaned-device leak §17 forbids.
    _readiness.dispose();
    _renderer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final concern = _readiness.concern;
    final showPreview = widget.wantsCamera && _renderer?.srcObject != null;

    // FOUND BY USING IT — 2026-08-25, a real call from a 1512x812 browser
    // window: the self-preview plus the header and device lines pushed
    // "Start video call" and "Not now" off the bottom of the screen, and the
    // sheet could not scroll to reach them. The call could not be started and
    // the sheet could not be dismissed by any visible control. It fitted on the
    // Pixel's tall screen, which is exactly why a phone-only check would have
    // missed it.
    //
    // Two changes: the sheet is bounded to a fraction of the viewport and
    // scrolls, and the preview is capped so it can never crowd out the
    // actions. The actions themselves stay OUTSIDE the scrollable, so they are
    // always on screen — a decision control that can scroll away is the same
    // defect wearing a scrollbar.
    final maxSheet = MediaQuery.sizeOf(context).height * 0.85;
    // Deliberately modest: on a short laptop window the actions matter
    // more than a large self-view.
    final previewHeight = (MediaQuery.sizeOf(context).height * 0.26).clamp(
      120.0,
      240.0,
    );

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(AuraSpace.s12),
        padding: const EdgeInsets.all(AuraSpace.s20),
        constraints: BoxConstraints(maxHeight: maxSheet),
        decoration: BoxDecoration(
          color: AuraSurface.elevated,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                widget.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AuraSurface.muted,
              ),
            ),
            const SizedBox(height: AuraSpace.s16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showPreview) ...[
                      // A FIXED HEIGHT, not an aspect ratio.
                      //
                      // ConstrainedBox around AspectRatio did not clamp in
                      // practice: the sheet's stretch cross-axis gives the
                      // preview the full width, and 16:10 of that is taller
                      // than the cap. The preview is a reassurance, not the
                      // point of the screen — the actions are — so its height
                      // is stated outright and it crops to fill.
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          height: previewHeight,
                          width: double.infinity,
                          child: RTCVideoView(
                            _renderer!,
                            mirror: true,
                            objectFit: RTCVideoViewObjectFit
                                .RTCVideoViewObjectFitCover,
                          ),
                        ),
                      ),
                      const SizedBox(height: AuraSpace.s16),
                    ],
                    _DeviceLine(
                      readiness: _readiness.readiness.microphone,
                      checking: _readiness.checking,
                    ),
                    if (widget.wantsCamera) ...[
                      const SizedBox(height: AuraSpace.s8),
                      _DeviceLine(
                        readiness: _readiness.readiness.camera,
                        checking: _readiness.checking,
                      ),
                    ],
                    if (concern?.recovery != null) ...[
                      const SizedBox(height: AuraSpace.s12),
                      Text(
                        concern!.recovery!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AuraSurface.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AuraSpace.s20),
            // "Open settings" appears ONLY where such a place exists and is
            // the actual remaining fix. An affordance that does nothing is
            // worse than none at all.
            if (_readiness.shouldOfferSettings) ...[
              OutlinedButton.icon(
                icon: const Icon(Icons.settings_outlined, size: 18),
                label: const Text('Open settings'),
                onPressed: () => _readiness.openSettings(),
              ),
              const SizedBox(height: AuraSpace.s8),
            ],
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Not now'),
                  ),
                ),
                const SizedBox(width: AuraSpace.s8),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    // Joining is never barred: listening is a legitimate way
                    // to attend, and refusing entry would be worse than
                    // joining silent. Only the WORDING changes.
                    onPressed: _readiness.checking
                        ? null
                        : () => Navigator.of(context).pop(true),
                    child: Text(
                      _readiness.checking ? 'Checking…' : widget.confirmLabel,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One device, said plainly, with its state carried by words and not by colour
/// alone — the same accessibility rule the Meetings chapter froze.
class _DeviceLine extends StatelessWidget {
  const _DeviceLine({required this.readiness, required this.checking});

  final DeviceReadiness readiness;
  final bool checking;

  @override
  Widget build(BuildContext context) {
    final ok = readiness.isUsable;
    final icon = readiness.kind == MediaDeviceKind.camera
        ? (ok ? Icons.videocam_rounded : Icons.videocam_off_rounded)
        : (ok ? Icons.mic_rounded : Icons.mic_off_rounded);

    return Semantics(
      liveRegion: true,
      label: checking
          ? 'Checking your ${readiness.deviceLabel.toLowerCase()}'
          : readiness.summary,
      child: ExcludeSemantics(
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: ok ? AuraSurface.accentText : AuraSurface.muted,
            ),
            const SizedBox(width: AuraSpace.s10),
            Expanded(
              child: Text(
                checking
                    ? 'Checking your ${readiness.deviceLabel.toLowerCase()}…'
                    : readiness.summary,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ok ? null : AuraSurface.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
