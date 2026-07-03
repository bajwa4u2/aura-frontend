import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Camera / microphone / speaker pickers, driven by `enumerateDevices`.
/// Reused on the pre-join surface and inside the live meeting — the parent
/// wires each `onChanged` to the right behaviour (pre-join re-acquires its
/// preview + records the preference; in-meeting live-switches the device).
///
/// Device labels are only populated once media permission is granted, so this
/// is meant to sit alongside an active preview/stream.
class MeetingDevicePicker extends StatefulWidget {
  const MeetingDevicePicker({
    super.key,
    required this.cameraId,
    required this.micId,
    required this.speakerId,
    required this.onCameraChanged,
    required this.onMicChanged,
    required this.onSpeakerChanged,
  });

  final String? cameraId;
  final String? micId;
  final String? speakerId;
  final ValueChanged<String> onCameraChanged;
  final ValueChanged<String> onMicChanged;
  final ValueChanged<String> onSpeakerChanged;

  @override
  State<MeetingDevicePicker> createState() => _MeetingDevicePickerState();
}

class _MeetingDevicePickerState extends State<MeetingDevicePicker> {
  List<MediaDeviceInfo> _devices = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    // Re-enumerate when devices are plugged/unplugged.
    navigator.mediaDevices.ondevicechange = (_) => _load();
  }

  @override
  void dispose() {
    navigator.mediaDevices.ondevicechange = null;
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final devices = await navigator.mediaDevices.enumerateDevices();
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<MediaDeviceInfo> _of(String kind) =>
      _devices.where((d) => d.kind == kind && d.deviceId.isNotEmpty).toList();

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    final cameras = _of('videoinput');
    final mics = _of('audioinput');
    final speakers = _of('audiooutput'); // absent on some browsers/mobile

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _row(
          icon: Icons.videocam_rounded,
          label: 'Camera',
          devices: cameras,
          value: widget.cameraId,
          onChanged: widget.onCameraChanged,
          emptyLabel: 'No camera detected',
        ),
        const SizedBox(height: 10),
        _row(
          icon: Icons.mic_rounded,
          label: 'Microphone',
          devices: mics,
          value: widget.micId,
          onChanged: widget.onMicChanged,
          emptyLabel: 'No microphone detected',
        ),
        if (speakers.isNotEmpty) ...[
          const SizedBox(height: 10),
          _row(
            icon: Icons.volume_up_rounded,
            label: 'Speaker',
            devices: speakers,
            value: widget.speakerId,
            onChanged: widget.onSpeakerChanged,
            emptyLabel: 'System default',
          ),
        ],
      ],
    );
  }

  Widget _row({
    required IconData icon,
    required String label,
    required List<MediaDeviceInfo> devices,
    required String? value,
    required ValueChanged<String> onChanged,
    required String emptyLabel,
  }) {
    final ids = devices.map((d) => d.deviceId).toSet();
    final selected = (value != null && ids.contains(value))
        ? value
        : (devices.isNotEmpty ? devices.first.deviceId : null);

    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 10),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF243244)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: devices.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        emptyLabel,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 13,
                        ),
                      ),
                    )
                  : DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: selected,
                        borderRadius: BorderRadius.circular(8),
                        icon: const Icon(Icons.expand_more_rounded, size: 20),
                        items: [
                          for (final d in devices)
                            DropdownMenuItem<String>(
                              value: d.deviceId,
                              child: Text(
                                d.label.trim().isNotEmpty
                                    ? d.label.trim()
                                    : '$label device',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13.5),
                              ),
                            ),
                        ],
                        onChanged: (id) {
                          if (id != null) onChanged(id);
                        },
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
