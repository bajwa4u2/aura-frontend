import 'package:flutter/material.dart';

import '../../../core/ui/aura_text_block.dart';

class AnnouncementDistribution extends StatefulWidget {
  const AnnouncementDistribution({
    super.key,
    required this.linkedinConnected,
    required this.tiktokConnected,
    required this.tiktokEnabled,
    required this.initialAura,
    required this.initialLinkedin,
    required this.initialTiktok,
    required this.onChanged,
  });

  final bool linkedinConnected;
  final bool tiktokConnected;
  final bool tiktokEnabled;
  final bool initialAura;
  final bool initialLinkedin;
  final bool initialTiktok;
  final void Function({
    required bool aura,
    required bool linkedin,
    required bool tiktok,
  }) onChanged;

  @override
  State<AnnouncementDistribution> createState() => _AnnouncementDistributionState();
}

class _AnnouncementDistributionState extends State<AnnouncementDistribution> {
  late bool aura;
  late bool linkedin;
  late bool tiktok;

  @override
  void initState() {
    super.initState();
    aura = widget.initialAura;
    linkedin = widget.initialLinkedin;
    tiktok = widget.initialTiktok;
  }

  @override
  void didUpdateWidget(covariant AnnouncementDistribution oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!widget.linkedinConnected && linkedin) {
      linkedin = false;
      _emit();
    }

    if ((!widget.tiktokConnected || !widget.tiktokEnabled) && tiktok) {
      tiktok = false;
      _emit();
    }
  }

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
    required ValueChanged<bool>? onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: AuraTextBlock(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: AuraTextBlock(
        subtitle,
        style: const TextStyle(fontSize: 13),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      value: value,
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AuraTextBlock(
          'Distribution',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
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
              : null,
        ),
        _row(
          title: 'TikTok',
          subtitle: !widget.tiktokConnected
              ? 'Not connected'
              : (widget.tiktokEnabled ? 'Connected' : 'Requires one uploaded video'),
          value: tiktok,
          onChanged: (widget.tiktokConnected && widget.tiktokEnabled)
              ? (v) {
                  setState(() => tiktok = v);
                  _emit();
                }
              : null,
        ),
      ],
    );
  }
}
