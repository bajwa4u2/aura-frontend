import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_responsive.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/substrate_chip.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/admin_providers.dart';
import 'admin_error.dart';

class AdminInstitutionsScreen extends ConsumerStatefulWidget {
  const AdminInstitutionsScreen({super.key});

  @override
  ConsumerState<AdminInstitutionsScreen> createState() => _AdminInstitutionsScreenState();
}

class _AdminInstitutionsScreenState extends ConsumerState<AdminInstitutionsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  List<AdminInstitutionSummary> _verified = const [];
  bool _loadingVerified = false;
  Object? _errorVerified;

  List<AdminVerificationRequest> _requests = const [];
  bool _loadingRequests = false;
  bool _actionLoading = false;
  Object? _errorRequests;

  List<AdminInstitutionSummary> _suspended = const [];
  bool _loadingSuspended = false;
  Object? _errorSuspended;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() {
      if (!_tab.indexIsChanging) _onTabChange(_tab.index);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadVerified());
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _onTabChange(int index) {
    switch (index) {
      case 0:
        if (_verified.isEmpty && !_loadingVerified) _loadVerified();
      case 1:
        if (_requests.isEmpty && !_loadingRequests) _loadRequests();
      case 2:
        if (_suspended.isEmpty && !_loadingSuspended) _loadSuspended();
    }
  }

  Future<void> _loadVerified() async {
    if (_loadingVerified) return;
    setState(() { _loadingVerified = true; _errorVerified = null; });
    try {
      final results = await ref.read(adminRepositoryProvider).fetchInstitutions(status: 'VERIFIED');
      if (!mounted) return;
      setState(() { _verified = results; _loadingVerified = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loadingVerified = false; _errorVerified = e; });
    }
  }

  Future<void> _loadRequests() async {
    if (_loadingRequests) return;
    setState(() { _loadingRequests = true; _errorRequests = null; });
    try {
      final results = await ref.read(adminRepositoryProvider).fetchVerificationRequests();
      if (!mounted) return;
      setState(() { _requests = results; _loadingRequests = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loadingRequests = false; _errorRequests = e; });
    }
  }

  Future<void> _loadSuspended() async {
    if (_loadingSuspended) return;
    setState(() { _loadingSuspended = true; _errorSuspended = null; });
    try {
      final results = await ref.read(adminRepositoryProvider).fetchInstitutions(status: 'SUSPENDED');
      if (!mounted) return;
      setState(() { _suspended = results; _loadingSuspended = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loadingSuspended = false; _errorSuspended = e; });
    }
  }

  Future<void> _approve(String id) async {
    setState(() => _actionLoading = true);
    try {
      await ref.read(adminRepositoryProvider).approveVerificationRequest(id);
      _requests = const [];
      await _loadRequests();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Approval failed: ${adminErrorMessage(e)}')),
        );
        setState(() => _actionLoading = false);
      }
    }
  }

  Future<void> _reject(String id) async {
    final reason = await _promptText(
      context,
      title: 'Reject request',
      hint: 'Reason for rejection (optional)',
    );
    if (reason == null) return;
    setState(() => _actionLoading = true);
    try {
      await ref.read(adminRepositoryProvider).rejectVerificationRequest(id, reason: reason);
      _requests = const [];
      await _loadRequests();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rejection failed: ${adminErrorMessage(e)}')),
        );
        setState(() => _actionLoading = false);
      }
    }
  }

  Future<void> _needsInfo(String id) async {
    final question = await _promptText(
      context,
      title: 'Request more information',
      hint: 'What information is needed?',
    );
    if (question == null) return;
    setState(() => _actionLoading = true);
    try {
      await ref.read(adminRepositoryProvider).needsInfoVerificationRequest(id, reason: question);
      _requests = const [];
      await _loadRequests();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${adminErrorMessage(e)}')),
        );
        setState(() => _actionLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuraScaffold(
      title: 'Institutions',
      showHomeAction: true,
      body: Column(
        children: [
          Container(
            color: AuraSurface.card,
            child: TabBar(
              controller: _tab,
              tabs: const [
                Tab(text: 'Verified'),
                Tab(text: 'Pending review'),
                Tab(text: 'Suspended'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _InstitutionList(
                  items: _verified,
                  loading: _loadingVerified,
                  error: _errorVerified,
                  onRetry: _loadVerified,
                  onTap: (slug) => context.go('/institutions/$slug'),
                  emptyMessage: 'No verified institutions.',
                  onViewMembers: (inst) {
                    final name = Uri.encodeQueryComponent(inst.name);
                    context.go('/admin/institutions/${inst.id}/members?name=$name');
                  },
                  onViewAnnouncements: (inst) => context.go(
                    '/institution/${inst.id}/announcements',
                  ),
                  onViewSpaces: (inst) => context.go(
                    '/institution/${inst.id}/spaces',
                  ),
                ),
                _RequestList(
                  items: _requests,
                  loading: _loadingRequests,
                  actionLoading: _actionLoading,
                  error: _errorRequests,
                  onRetry: _loadRequests,
                  onApprove: _approve,
                  onReject: _reject,
                  onNeedsInfo: _needsInfo,
                  onViewProfile: (slug) => context.go('/institutions/$slug'),
                ),
                _InstitutionList(
                  items: _suspended,
                  loading: _loadingSuspended,
                  error: _errorSuspended,
                  onRetry: _loadSuspended,
                  onTap: (slug) => context.go('/institutions/$slug'),
                  emptyMessage: 'No suspended institutions.',
                  onViewMembers: (inst) {
                    final name = Uri.encodeQueryComponent(inst.name);
                    context.go('/admin/institutions/${inst.id}/members?name=$name');
                  },
                  onViewAnnouncements: (inst) => context.go(
                    '/institution/${inst.id}/announcements',
                  ),
                  onViewSpaces: (inst) => context.go(
                    '/institution/${inst.id}/spaces',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INSTITUTION LIST (VERIFIED / SUSPENDED)
// ─────────────────────────────────────────────────────────────────────────────

class _InstitutionList extends StatelessWidget {
  const _InstitutionList({
    required this.items,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onTap,
    required this.emptyMessage,
    this.onViewMembers,
    this.onViewAnnouncements,
    this.onViewSpaces,
  });

  final List<AdminInstitutionSummary> items;
  final bool loading;
  final Object? error;
  final VoidCallback onRetry;
  final ValueChanged<String> onTap;
  final String emptyMessage;
  final ValueChanged<AdminInstitutionSummary>? onViewMembers;
  final ValueChanged<AdminInstitutionSummary>? onViewAnnouncements;
  final ValueChanged<AdminInstitutionSummary>? onViewSpaces;

  @override
  Widget build(BuildContext context) {
    if (loading && items.isEmpty) {
      return const Center(child: AuraLoadingState(message: 'Loading…'));
    }
    if (error != null && items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AuraSpace.s16),
          child: AuraErrorState(
            title: 'Failed to load institutions',
            body: adminErrorMessage(error!),
            action: AuraSecondaryButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
          ),
        ),
      );
    }
    if (!loading && items.isEmpty) {
      return Center(
        child: AuraEmptyState(
          title: 'No institutions',
          body: emptyMessage,
          icon: Icons.apartment_outlined,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.s16,
        AuraSpace.s16,
        AuraSpace.s16,
        AuraSpace.s32,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kWorkspaceWidth),
            child: Container(
              decoration: BoxDecoration(
                color: AuraSurface.card,
                borderRadius: BorderRadius.circular(AuraRadius.card),
                border: Border.all(color: AuraSurface.divider),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    _InstitutionRow(
                      institution: items[i],
                      onTap: () => onTap(items[i].slug),
                      onViewMembers: onViewMembers != null ? () => onViewMembers!(items[i]) : null,
                      onViewAnnouncements: onViewAnnouncements != null ? () => onViewAnnouncements!(items[i]) : null,
                      onViewSpaces: onViewSpaces != null ? () => onViewSpaces!(items[i]) : null,
                    ),
                    if (i < items.length - 1)
                      Container(
                        height: 1,
                        margin: const EdgeInsets.symmetric(horizontal: AuraSpace.s16),
                        color: AuraSurface.divider,
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InstitutionRow extends StatelessWidget {
  const _InstitutionRow({
    required this.institution,
    required this.onTap,
    this.onViewMembers,
    this.onViewAnnouncements,
    this.onViewSpaces,
  });

  final AdminInstitutionSummary institution;
  final VoidCallback onTap;
  final VoidCallback? onViewMembers;
  final VoidCallback? onViewAnnouncements;
  final VoidCallback? onViewSpaces;

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AuraRadius.card),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s16,
          vertical: AuraSpace.s14,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    institution.name,
                    style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AuraSpace.s2),
                  Text(
                    institution.domain ?? institution.slug,
                    style: AuraText.small.copyWith(color: AuraSurface.muted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Created ${_formatDate(institution.createdAt)}',
                    style: AuraText.micro.copyWith(color: AuraSurface.faint),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AuraSpace.s12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _CountBadge(
                  label: '${institution.memberCount} member${institution.memberCount == 1 ? '' : 's'}',
                ),
                const SizedBox(height: AuraSpace.s4),
                Text(
                  institution.status.toUpperCase(),
                  style: AuraText.micro.copyWith(
                    color: institution.status == 'VERIFIED'
                        ? AuraSurface.accentText
                        : AuraSurface.coRose,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18, color: AuraSurface.muted),
              tooltip: 'Admin actions',
              onSelected: (value) {
                switch (value) {
                  case 'members': onViewMembers?.call();
                  case 'announcements': onViewAnnouncements?.call();
                  case 'spaces': onViewSpaces?.call();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'members',
                  child: Row(children: [
                    Icon(Icons.group_outlined, size: 16),
                    SizedBox(width: 8),
                    Text('Members'),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'announcements',
                  child: Row(children: [
                    Icon(Icons.campaign_outlined, size: 16),
                    SizedBox(width: 8),
                    Text('Announcements'),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'spaces',
                  child: Row(children: [
                    Icon(Icons.workspaces_outlined, size: 16),
                    SizedBox(width: 8),
                    Text('Spaces'),
                  ]),
                ),
              ],
            ),
            const Icon(Icons.chevron_right, size: 16, color: AuraSurface.faint),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VERIFICATION REQUESTS LIST (PENDING REVIEW)
// ─────────────────────────────────────────────────────────────────────────────

class _RequestList extends StatelessWidget {
  const _RequestList({
    required this.items,
    required this.loading,
    required this.actionLoading,
    required this.error,
    required this.onRetry,
    required this.onApprove,
    required this.onReject,
    required this.onNeedsInfo,
    required this.onViewProfile,
  });

  final List<AdminVerificationRequest> items;
  final bool loading;
  final bool actionLoading;
  final Object? error;
  final VoidCallback onRetry;
  final ValueChanged<String> onApprove;
  final ValueChanged<String> onReject;
  final ValueChanged<String> onNeedsInfo;
  final ValueChanged<String> onViewProfile;

  @override
  Widget build(BuildContext context) {
    if (loading && items.isEmpty) {
      return const Center(child: AuraLoadingState(message: 'Loading…'));
    }
    if (error != null && items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AuraSpace.s16),
          child: AuraErrorState(
            title: 'Failed to load requests',
            body: adminErrorMessage(error!),
            action: AuraSecondaryButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
          ),
        ),
      );
    }
    if (!loading && items.isEmpty) {
      return const Center(
        child: AuraEmptyState(
          title: 'No pending requests',
          body: 'All verification requests have been reviewed.',
          icon: Icons.check_circle_outline_rounded,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.s16,
        AuraSpace.s16,
        AuraSpace.s16,
        AuraSpace.s32,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kWorkspaceWidth),
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  _RequestCard(
                    request: items[i],
                    actionLoading: actionLoading,
                    onApprove: () => onApprove(items[i].id),
                    onReject: () => onReject(items[i].id),
                    onNeedsInfo: () => onNeedsInfo(items[i].id),
                    onViewProfile: items[i].institutionSlug != null
                        ? () => onViewProfile(items[i].institutionSlug!)
                        : null,
                  ),
                  if (i < items.length - 1) const SizedBox(height: AuraSpace.s12),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.actionLoading,
    required this.onApprove,
    required this.onReject,
    required this.onNeedsInfo,
    this.onViewProfile,
  });

  final AdminVerificationRequest request;
  final bool actionLoading;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onNeedsInfo;
  final VoidCallback? onViewProfile;

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.organizationName,
                      style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: AuraSpace.s4),
                    if (request.domain != null)
                      Text(
                        request.domain!,
                        style: AuraText.small.copyWith(color: AuraSurface.muted),
                      ),
                    if (request.workEmail != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        request.workEmail!,
                        style: AuraText.micro.copyWith(color: AuraSurface.faint),
                      ),
                    ],
                    if (request.requesterHandle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'By @${request.requesterHandle}',
                        style: AuraText.micro.copyWith(color: AuraSurface.faint),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AuraSpace.s12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusBadge(status: request.status),
                  const SizedBox(height: AuraSpace.s4),
                  Text(
                    _formatDate(request.createdAt),
                    style: AuraText.micro.copyWith(color: AuraSurface.faint),
                  ),
                ],
              ),
            ],
          ),
          if (request.reviewNotes != null) ...[
            const SizedBox(height: AuraSpace.s10),
            Container(
              padding: const EdgeInsets.all(AuraSpace.s10),
              decoration: BoxDecoration(
                color: AuraSurface.elevated,
                borderRadius: BorderRadius.circular(AuraRadius.md),
                border: Border.all(color: AuraSurface.divider),
              ),
              child: Text(
                request.reviewNotes!,
                style: AuraText.small.copyWith(color: AuraSurface.muted, height: 1.4),
              ),
            ),
          ],
          const SizedBox(height: AuraSpace.s12),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: [
              _ActionButton(
                label: 'Approve',
                color: AuraSurface.accentText,
                bgColor: AuraSurface.accentSoft,
                icon: Icons.check_rounded,
                disabled: actionLoading,
                onTap: onApprove,
              ),
              _ActionButton(
                label: 'Reject',
                color: AuraSurface.coRose,
                bgColor: AuraSurface.coRose.withValues(alpha: 0.16),
                icon: Icons.close_rounded,
                disabled: actionLoading,
                onTap: onReject,
              ),
              _ActionButton(
                label: 'Needs info',
                color: AuraSurface.muted,
                bgColor: AuraSurface.elevated,
                icon: Icons.info_outline_rounded,
                disabled: actionLoading,
                onTap: onNeedsInfo,
              ),
              if (onViewProfile != null)
                _ActionButton(
                  label: 'View profile',
                  color: AuraSurface.faint,
                  bgColor: AuraSurface.elevated,
                  icon: Icons.open_in_new_rounded,
                  disabled: actionLoading,
                  onTap: onViewProfile!,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.bgColor,
    required this.icon,
    required this.disabled,
    required this.onTap,
  });

  final String label;
  final Color color;
  final Color bgColor;
  final IconData icon;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Opacity(
        opacity: disabled ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s12,
            vertical: AuraSpace.s6,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AuraRadius.pill),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: AuraSpace.s4),
              Text(
                label,
                style: AuraText.small.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s8, vertical: 2),
      decoration: BoxDecoration(
        color: AuraSurface.elevated,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Text(
        label,
        style: AuraText.micro.copyWith(
          color: AuraSurface.muted,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Institution-lifecycle status rendered as a canonical SubstrateChip.
/// APPROVED → teal (institutional authority); REJECTED/SUSPENDED →
/// rose (refused); other → mist (pending / unknown).
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final upper = status.toUpperCase();
    final state = upper == 'APPROVED'
        ? SubstrateChipState.teal
        : (upper == 'REJECTED' || upper == 'SUSPENDED')
            ? SubstrateChipState.rose
            : SubstrateChipState.mist;
    return SubstrateChip(label: status.replaceAll('_', ' '), state: state);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

Future<String?> _promptText(
  BuildContext context, {
  required String title,
  required String hint,
}) async {
  final controller = TextEditingController();
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(hintText: hint),
        autofocus: true,
        minLines: 2,
        maxLines: 5,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Confirm'),
        ),
      ],
    ),
  );
  final text = controller.text.trim();
  controller.dispose();
  if (result != true) return null;
  return text;
}
