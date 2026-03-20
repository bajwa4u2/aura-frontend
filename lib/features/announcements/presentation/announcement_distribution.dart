// NEW: Distribution block for admin/institution use
import 'package:flutter/material.dart';

class AnnouncementDistribution extends StatefulWidget {
  const AnnouncementDistribution({
    super.key,
    required this.linkedinConnected,
    required this.onChanged,
  });

  final bool linkedinConnected;
  final void Function({
    required bool aura,
    required bool linkedin,
    required bool tiktok,
  }) onChanged;

  @override
  State<AnnouncementDistribution> createState() => _AnnouncementDistributionState();
}

class _AnnouncementDistributionState extends State<AnnouncementDistribution> {
  bool aura = true;
  bool linkedin = false;
  bool tiktok = false;

  void _emit() {
    widget.onChanged(
      aura: aura,
      linkedin: linkedin,
      tiktok: tiktok,
    );
  }

  Widget _row({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Distribution', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),

        _row(
          title: 'Aura',
          subtitle: 'Primary publication',
          value: aura,
          onChanged: (v) {
            setState(() => aura = v);
            _emit();
          },
        ),

        _row(
          title: 'LinkedIn',
          subtitle: widget.linkedinConnected ? 'Connected' : 'Not connected',
          value: linkedin,
          onChanged: widget.linkedinConnected
              ? (v) {
                  setState(() => linkedin = v);
                  _emit();
                }
              : (_) {},
        ),

        _row(
          title: 'TikTok',
          subtitle: 'Requires video',
          value: tiktok,
          onChanged: (v) {
            setState(() => tiktok = v);
            _emit();
          },
        ),
      ],
    );
  }
}
