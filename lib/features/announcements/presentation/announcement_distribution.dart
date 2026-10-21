import 'package:flutter/material.dart';

import '../../../core/ui/aura_text_block.dart';

class AnnouncementDistribution extends StatefulWidget {
  const AnnouncementDistribution({
    super.key,
    required this.linkedinConnected,
    required this.tiktokConnected,
    required this.tiktokEnabled,
    this.linkedinAccountName,
    this.tiktokAccountName,
    required this.initialAura,
    required this.initialLinkedin,
    required this.initialTiktok,
    required this.onChanged,
    this.metaOffered = true,
    this.facebookConnected = false,
    this.facebookPageName,
    this.instagramConnected = false,
    this.instagramUsername,
    this.initialFacebook = false,
    this.initialInstagram = false,
  });

  /// Whether Facebook Page and Instagram are open to this member at all
  /// (2026-10-21: not before Meta completes its review of Aura). When not,
  /// neither row is drawn.
  final bool metaOffered;

  /// A Facebook Page chosen under Connected accounts (2026-10-20).
  final bool facebookConnected;
  final String? facebookPageName;

  /// The professional Instagram linked to that Page, if any.
  final bool instagramConnected;
  final String? instagramUsername;
  final bool initialFacebook;
  final bool initialInstagram;

  final bool linkedinConnected;
  final bool tiktokConnected;
  final bool tiktokEnabled;

  /// The connected account's HUMAN name, when the provider gave us one.
  ///
  /// Null when it did not. Deliberately never an opaque platform identifier:
  /// the editor previously fell back to a raw TikTok open-id and printed it on
  /// screen, so a person composing an announcement was shown
  /// `-000Dmtv3qyF_cHtMRR_jpGQv1lk-Q-gMYXt` and had to work out that it meant
  /// their own account. An id a person cannot recognise tells them nothing;
  /// "Connected" at least tells them the truth.
  final String? linkedinAccountName;
  final String? tiktokAccountName;

  final bool initialAura;
  final bool initialLinkedin;
  final bool initialTiktok;
  final void Function({
    required bool aura,
    required bool linkedin,
    required bool tiktok,
    required bool facebook,
    required bool instagram,
  }) onChanged;

  @override
  State<AnnouncementDistribution> createState() => _AnnouncementDistributionState();
}

class _AnnouncementDistributionState extends State<AnnouncementDistribution> {
  late bool aura;
  late bool linkedin;
  late bool tiktok;
  late bool facebook;
  late bool instagram;

  @override
  void initState() {
    super.initState();
    aura = widget.initialAura;
    linkedin = widget.initialLinkedin;
    tiktok = widget.initialTiktok;
    facebook = widget.initialFacebook;
    instagram = widget.initialInstagram;
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

    if (!widget.facebookConnected && facebook) {
      facebook = false;
      _emit();
    }

    if (!widget.instagramConnected && instagram) {
      instagram = false;
      _emit();
    }
  }

  void _emit() {
    widget.onChanged(
      aura: aura,
      linkedin: linkedin,
      tiktok: tiktok,
      facebook: facebook,
      instagram: instagram,
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
        // NO HEADING HERE. The editor already renders "Distribution" as a
        // section title in the same style as "Writing", "Writing support" and
        // "Media"; this widget printed a second one immediately beneath it, so
        // the surface read "Distribution / Distribution".
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
          // A DEAD SWITCH MUST AT LEAST SAY WHERE IT COMES ALIVE.
          //
          // The control is correctly disabled with no connected account —
          // there is nothing to publish to. But it read only "Not connected",
          // which describes the state and withholds the remedy, so the switch
          // looked broken rather than unavailable. The connection is made on
          // the profile screen; saying so is the difference between a dead
          // control and a next step.
          // WHICH account, when we know its name. Someone publishing to a
          // place their name is attached to should be able to see whose name
          // it will be, and the subtitle is where they are already looking —
          // the editor used to print it as a separate "LinkedIn: …" line
          // underneath, which read like debug output.
          subtitle: widget.linkedinConnected
              ? (widget.linkedinAccountName?.trim().isNotEmpty == true
                  ? widget.linkedinAccountName!.trim()
                  : 'Connected')
              : 'Not connected — connect LinkedIn on your profile',
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
              : (widget.tiktokEnabled
                  ? (widget.tiktokAccountName?.trim().isNotEmpty == true
                      ? widget.tiktokAccountName!.trim()
                      : 'Connected')
                  : 'Requires one uploaded video'),
          value: tiktok,
          onChanged: (widget.tiktokConnected && widget.tiktokEnabled)
              ? (v) {
                  setState(() => tiktok = v);
                  _emit();
                }
              : null,
        ),
        if (widget.metaOffered) ...[
        _row(
          title: 'Facebook Page',
          subtitle: widget.facebookConnected
              ? (widget.facebookPageName?.trim().isNotEmpty == true
                  ? widget.facebookPageName!.trim()
                  : 'Connected')
              : 'Not connected \u2014 connect a Facebook Page on your profile',
          value: facebook,
          onChanged: widget.facebookConnected
              ? (v) {
                  setState(() => facebook = v);
                  _emit();
                }
              : null,
        ),
        _row(
          title: 'Instagram',
          subtitle: widget.instagramConnected
              ? '${widget.instagramUsername?.trim().isNotEmpty == true ? '@${widget.instagramUsername!.trim()}' : 'Connected'} \u00b7 needs a photo or video'
              : 'Comes with a Facebook Page that has Instagram linked',
          value: instagram,
          onChanged: widget.instagramConnected
              ? (v) {
                  setState(() => instagram = v);
                  _emit();
                }
              : null,
        ),
        ],
      ],
    );
  }
}
