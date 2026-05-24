import 'package:flutter/material.dart';

import '../../../../core/ui/aura_platform_components.dart';
import '../../../../core/ui/aura_radius.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_surface.dart';
import '../../../../core/ui/aura_text.dart';
import '../../../../core/ui/aura_text_block.dart';

class MeConnectedAccountsPanel extends StatefulWidget {
  const MeConnectedAccountsPanel({
    super.key,
    required this.linkedinAccount,
    required this.linkedinLoading,
    required this.linkedinActionBusy,
    required this.isLinkedInConnected,
    required this.tiktokAccount,
    required this.tiktokLoading,
    required this.tiktokActionBusy,
    required this.isTikTokConnected,
    required this.onConnectLinkedIn,
    required this.onDisconnectLinkedIn,
    required this.onCheckLinkedIn,
    required this.onConnectTikTok,
    required this.onRefreshTikTok,
    required this.onDisconnectTikTok,
    required this.onCheckTikTok,
  });

  final Map<String, dynamic>? linkedinAccount;
  final bool linkedinLoading;
  final bool linkedinActionBusy;
  final bool isLinkedInConnected;
  final Map<String, dynamic>? tiktokAccount;
  final bool tiktokLoading;
  final bool tiktokActionBusy;
  final bool isTikTokConnected;
  final VoidCallback onConnectLinkedIn;
  final VoidCallback onDisconnectLinkedIn;
  final VoidCallback onCheckLinkedIn;
  final VoidCallback onConnectTikTok;
  final VoidCallback onRefreshTikTok;
  final VoidCallback onDisconnectTikTok;
  final VoidCallback onCheckTikTok;

  @override
  State<MeConnectedAccountsPanel> createState() =>
      _MeConnectedAccountsPanelState();
}

class _MeConnectedAccountsPanelState
    extends State<MeConnectedAccountsPanel> {
  bool _linkedinExpanded = false;
  bool _tiktokExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.xl),
        border: Border.all(color: AuraSurface.divider),
      ),
      padding: const EdgeInsets.all(AuraSpace.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Connected accounts', style: AuraText.title),
          const SizedBox(height: AuraSpace.s14),
          _linkedinTile(),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: AuraSpace.s4),
            color: AuraSurface.divider,
          ),
          _tiktokTile(),
        ],
      ),
    );
  }

  Widget _linkedinTile() {
    final connected = widget.isLinkedInConnected;
    final acct = widget.linkedinAccount ?? const <String, dynamic>{};
    final accountLabel = _firstNonEmpty([
      _v(acct['name']),
      _v(acct['email']),
      _v(acct['linkedinMemberId']),
      connected ? 'Connected' : '',
    ]);
    final isBusy = widget.linkedinActionBusy || widget.linkedinLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _accountRow(
          icon: Icons.business_center_outlined,
          name: 'LinkedIn',
          statusText: widget.linkedinLoading
              ? 'Checking connection…'
              : connected
                  ? accountLabel
                  : 'Not connected',
          connected: connected,
          busy: isBusy,
          expanded: _linkedinExpanded,
          onToggle: () =>
              setState(() => _linkedinExpanded = !_linkedinExpanded),
        ),
        if (_linkedinExpanded)
          _actionsRow(
            connected: connected,
            busy: isBusy,
            actionBusy: widget.linkedinActionBusy,
            onConnect: widget.onConnectLinkedIn,
            onCheck: widget.onCheckLinkedIn,
            onDisconnect: widget.onDisconnectLinkedIn,
          ),
      ],
    );
  }

  Widget _tiktokTile() {
    final connected = widget.isTikTokConnected;
    final acct = widget.tiktokAccount ?? const <String, dynamic>{};
    final accountLabel = _firstNonEmpty([
      _v(acct['username']),
      _v(acct['platformUserId']),
      connected ? 'Connected' : '',
    ]);
    final isBusy = widget.tiktokActionBusy || widget.tiktokLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _accountRow(
          icon: Icons.music_note_outlined,
          name: 'TikTok',
          statusText: widget.tiktokLoading
              ? 'Checking connection…'
              : connected
                  ? accountLabel
                  : 'Not connected',
          connected: connected,
          busy: isBusy,
          expanded: _tiktokExpanded,
          onToggle: () =>
              setState(() => _tiktokExpanded = !_tiktokExpanded),
        ),
        if (_tiktokExpanded)
          _actionsRow(
            connected: connected,
            busy: isBusy,
            actionBusy: widget.tiktokActionBusy,
            onConnect: widget.onConnectTikTok,
            onCheck: widget.onCheckTikTok,
            onDisconnect: widget.onDisconnectTikTok,
            onRefresh: connected ? widget.onRefreshTikTok : null,
          ),
      ],
    );
  }

  Widget _accountRow({
    required IconData icon,
    required String name,
    required String statusText,
    required bool connected,
    required bool busy,
    required bool expanded,
    required VoidCallback onToggle,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AuraSpace.s12,
            horizontal: AuraSpace.s4,
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AuraSurface.ink),
              const SizedBox(width: AuraSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AuraTextBlock(
                      name,
                      style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    AuraTextBlock(
                      statusText,
                      style: AuraText.small.copyWith(color: AuraSurface.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AuraSpace.s8),
              if (busy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                _MeConnectionStatusChip(connected: connected),
              const SizedBox(width: AuraSpace.s8),
              Icon(
                expanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 18,
                color: AuraSurface.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionsRow({
    required bool connected,
    required bool busy,
    required bool actionBusy,
    required VoidCallback onConnect,
    required VoidCallback onCheck,
    required VoidCallback onDisconnect,
    VoidCallback? onRefresh,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.s4,
        AuraSpace.s4,
        AuraSpace.s4,
        AuraSpace.s12,
      ),
      child: Wrap(
        spacing: AuraSpace.s8,
        runSpacing: AuraSpace.s8,
        children: [
          if (!connected)
            AuraSecondaryButton(
              label: 'Connect',
              onPressed: actionBusy ? null : onConnect,
              icon: Icons.link_rounded,
            ),
          if (connected && onRefresh != null)
            AuraSecondaryButton(
              label: 'Refresh',
              onPressed: actionBusy ? null : onRefresh,
              icon: Icons.refresh_rounded,
            ),
          AuraSecondaryButton(
            label: 'Check',
            onPressed: busy ? null : onCheck,
            icon: Icons.sync_rounded,
          ),
          if (connected)
            AuraGhostButton(
              label: 'Disconnect',
              onPressed: actionBusy ? null : onDisconnect,
              icon: Icons.link_off_rounded,
            ),
        ],
      ),
    );
  }

  String _v(dynamic v) => (v ?? '').toString().trim();

  String _firstNonEmpty(List<String> values) {
    for (final v in values) {
      if (v.trim().isNotEmpty) return v.trim();
    }
    return '';
  }
}

class _MeConnectionStatusChip extends StatelessWidget {
  const _MeConnectionStatusChip({required this.connected});
  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: connected ? AuraSurface.coVerdant.withValues(alpha: 0.16) : AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(
          color: connected
              ? AuraSurface.coVerdant.withValues(alpha: 0.3)
              : AuraSurface.divider,
        ),
      ),
      child: Text(
        connected ? 'Connected' : 'Not connected',
        style: AuraText.micro.copyWith(
          color: connected ? AuraSurface.coVerdant : AuraSurface.muted,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}
