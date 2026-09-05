import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/audio_output.dart';
import '../../../core/media/audio_output_controller.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/aura_radius.dart';

/// CHOOSING WHERE A CALL IS HEARD.
///
/// A native communication control, not a settings page: the routes that exist,
/// a tick on the one in use, one tap to move. It appears from the call's own
/// audio button and closes as soon as a choice is made, so the call surface
/// gains no permanent clutter.
///
/// It shows only what the platform reported. There is no "Bluetooth" row when
/// no Bluetooth device is connected, and no row Aura cannot actually switch to
/// — an option that does nothing when tapped is worse than an option that is
/// not there.
///
/// The tick follows the route the PLATFORM confirms, not the one that was
/// tapped. If a request is refused or the system substitutes another route, the
/// tick stays where the sound is.
class AudioOutputSheet extends ConsumerWidget {
  const AudioOutputSheet._();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AuraSurface.elevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AuraRadius.r18)),
      ),
      builder: (_) => const AudioOutputSheet._(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioOutputControllerProvider);
    final controller = ref.read(audioOutputControllerProvider.notifier);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AuraSpace.s12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AuraSpace.s16,
                AuraSpace.s4,
                AuraSpace.s16,
                AuraSpace.s12,
              ),
              child: Text('Audio', style: AuraText.title),
            ),
            for (final route in state.routes)
              _RouteRow(
                route: route,
                selected: state.current?.id == route.id,
                // Disabled while a switch is settling, so a second tap cannot
                // race the first and leave the tick describing neither.
                onTap: state.isSwitching
                    ? null
                    : () async {
                        await controller.select(route);
                        if (context.mounted) Navigator.of(context).pop();
                      },
              ),
            if (state.routes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpace.s16,
                  vertical: AuraSpace.s8,
                ),
                child: Text(
                  // Honest rather than empty: the platform was asked and said
                  // nothing, which is different from "you have no speakers".
                  'Aura could not read this device’s audio outputs.',
                  style: AuraText.body.copyWith(color: AuraSurface.muted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({
    required this.route,
    required this.selected,
    required this.onTap,
  });

  final AudioOutputRoute route;
  final bool selected;
  final VoidCallback? onTap;

  IconData get _icon => switch (route.kind) {
        AudioOutputKind.earpiece => Icons.hearing_rounded,
        AudioOutputKind.speaker => Icons.volume_up_rounded,
        AudioOutputKind.bluetooth => Icons.bluetooth_audio_rounded,
        AudioOutputKind.wiredHeadset => Icons.headset_rounded,
        AudioOutputKind.other => Icons.speaker_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s16,
          vertical: AuraSpace.s12,
        ),
        child: Row(
          children: [
            Icon(
              _icon,
              size: 22,
              color: selected ? AuraSurface.accent : AuraSurface.muted,
            ),
            const SizedBox(width: AuraSpace.s16),
            Expanded(
              child: Text(
                route.label,
                style: AuraText.body.copyWith(
                  color: selected ? AuraSurface.accent : AuraSurface.ink,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_rounded,
                  size: 20, color: AuraSurface.accent),
          ],
        ),
      ),
    );
  }
}
