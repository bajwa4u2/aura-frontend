import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_responsive.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/admin_providers.dart';
import 'admin_error.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final _searchController = TextEditingController();
  String _statusFilter = 'ALL';
  int _page = 1;
  List<AdminUserSummary> _users = const [];
  bool _loading = false;
  bool _actionLoading = false;
  Object? _error;
  bool _hasMore = true;

  static const _pageSize = 50;
  static const _statuses = ['ALL', 'ACTIVE', 'DISABLED', 'SUSPENDED', 'BANNED'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    if (reset) _page = 1;
    final currentPage = _page;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) _hasMore = true;
    });
    try {
      final repo = ref.read(adminRepositoryProvider);
      final q = _searchController.text.trim();
      final results = await repo.fetchUsers(
        page: currentPage,
        limit: _pageSize,
        query: q.isNotEmpty ? q : null,
        status: _statusFilter != 'ALL' ? _statusFilter : null,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _users = results;
        } else {
          _users = [..._users, ...results];
        }
        _hasMore = results.length >= _pageSize;
        if (results.isNotEmpty) _page = currentPage + 1;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  Future<void> _changeStatus(String userId, String newStatus) async {
    setState(() => _actionLoading = true);
    try {
      await ref.read(adminRepositoryProvider).updateUserStatus(userId, newStatus);
      if (!mounted) return;
      await _load(reset: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: ${adminErrorMessage(e)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuraScaffold(
      title: 'Users',
      showHomeAction: true,
      body: Column(
        children: [
          _UsersFilterBar(
            searchController: _searchController,
            statusFilter: _statusFilter,
            statuses: _statuses,
            onSearch: () => _load(reset: true),
            onStatusChanged: (s) {
              setState(() => _statusFilter = s);
              _load(reset: true);
            },
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _users.isEmpty) {
      return const Center(child: AuraLoadingState(message: 'Loading users…'));
    }
    if (_error != null && _users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AuraSpace.s16),
          child: AuraErrorState(
            title: 'Failed to load users',
            body: adminErrorMessage(_error!),
            action: AuraSecondaryButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              onPressed: () => _load(reset: true),
            ),
          ),
        ),
      );
    }
    if (!_loading && _users.isEmpty) {
      return const Center(
        child: AuraEmptyState(
          title: 'No users found',
          body: 'Try a different search or status filter.',
          icon: Icons.group_outlined,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(label: 'Members', count: _users.length),
                const SizedBox(height: AuraSpace.s12),
                Container(
                  decoration: BoxDecoration(
                    color: AuraSurface.card,
                    borderRadius: BorderRadius.circular(AuraRadius.card),
                    border: Border.all(color: AuraSurface.divider),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < _users.length; i++) ...[
                        _UserRow(
                          user: _users[i],
                          actionLoading: _actionLoading,
                          onStatusChange: _changeStatus,
                        ),
                        if (i < _users.length - 1)
                          Container(
                            height: 1,
                            margin: const EdgeInsets.symmetric(
                              horizontal: AuraSpace.s16,
                            ),
                            color: AuraSurface.divider,
                          ),
                      ],
                    ],
                  ),
                ),
                if (_hasMore && !_loading) ...[
                  const SizedBox(height: AuraSpace.s16),
                  Center(
                    child: AuraSecondaryButton(
                      label: 'Load more',
                      icon: Icons.expand_more_rounded,
                      onPressed: () => _load(),
                    ),
                  ),
                ],
                if (_loading && _users.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AuraSpace.s16),
                    child: Center(child: AuraLoadingState(message: 'Loading…')),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTER BAR
// ─────────────────────────────────────────────────────────────────────────────

class _UsersFilterBar extends StatelessWidget {
  const _UsersFilterBar({
    required this.searchController,
    required this.statusFilter,
    required this.statuses,
    required this.onSearch,
    required this.onStatusChanged,
  });

  final TextEditingController searchController;
  final String statusFilter;
  final List<String> statuses;
  final VoidCallback onSearch;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.s16,
        AuraSpace.s12,
        AuraSpace.s16,
        AuraSpace.s12,
      ),
      decoration: const BoxDecoration(
        color: AuraSurface.card,
        border: Border(bottom: BorderSide(color: AuraSurface.divider)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kWorkspaceWidth),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: searchController,
                    style: AuraText.body,
                    decoration: InputDecoration(
                      hintText: 'Search by name, email or handle…',
                      hintStyle: AuraText.small.copyWith(color: AuraSurface.muted),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: AuraSurface.faint,
                      ),
                      filled: true,
                      fillColor: AuraSurface.elevated,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AuraSpace.s12,
                        vertical: AuraSpace.s8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AuraRadius.md),
                        borderSide: const BorderSide(color: AuraSurface.divider),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AuraRadius.md),
                        borderSide: const BorderSide(color: AuraSurface.divider),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AuraRadius.md),
                        borderSide: const BorderSide(color: AuraSurface.accent),
                      ),
                    ),
                    onSubmitted: (_) => onSearch(),
                    textInputAction: TextInputAction.search,
                  ),
                ),
              ),
              const SizedBox(width: AuraSpace.s10),
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s10),
                decoration: BoxDecoration(
                  color: AuraSurface.elevated,
                  borderRadius: BorderRadius.circular(AuraRadius.md),
                  border: Border.all(color: AuraSurface.divider),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: statusFilter,
                    style: AuraText.small.copyWith(color: AuraSurface.ink),
                    icon: const Icon(
                      Icons.arrow_drop_down_rounded,
                      size: 18,
                      color: AuraSurface.faint,
                    ),
                    onChanged: (v) {
                      if (v != null) onStatusChanged(v);
                    },
                    items: statuses
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(s),
                          ),
                        )
                        .toList(),
                  ),
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
// SECTION HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label.toUpperCase(),
          style: AuraText.label.copyWith(
            color: AuraSurface.faint,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: AuraSpace.s8),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s8,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: AuraSurface.elevated,
            borderRadius: BorderRadius.circular(AuraRadius.pill),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: Text(
            count.toString(),
            style: AuraText.micro.copyWith(
              color: AuraSurface.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// USER ROW
// ─────────────────────────────────────────────────────────────────────────────

class _UserRow extends StatelessWidget {
  const _UserRow({
    required this.user,
    required this.actionLoading,
    required this.onStatusChange,
  });

  final AdminUserSummary user;
  final bool actionLoading;
  final Future<void> Function(String userId, String status) onStatusChange;

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return AuraSurface.accentText;
      case 'suspended':
      case 'banned':
        return AuraSurface.coRose;
      default:
        return AuraSurface.faint;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.s16,
        AuraSpace.s12,
        AuraSpace.s8,
        AuraSpace.s12,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName.isNotEmpty ? user.displayName : user.handle,
                  style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AuraSpace.s2),
                Text(
                  user.email,
                  style: AuraText.small.copyWith(color: AuraSurface.muted),
                ),
                if (user.handle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '@${user.handle}',
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
              _RoleBadge(role: user.role),
              const SizedBox(height: AuraSpace.s4),
              Text(
                user.status.toUpperCase(),
                style: AuraText.micro.copyWith(
                  color: _statusColor(user.status),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(width: AuraSpace.s4),
          PopupMenuButton<String>(
            enabled: !actionLoading,
            icon: const Icon(
              Icons.more_vert_rounded,
              size: 18,
              color: AuraSurface.faint,
            ),
            tooltip: 'Change status',
            onSelected: (status) => onStatusChange(user.id, status),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'ACTIVE', child: Text('Set Active')),
              PopupMenuItem(value: 'DISABLED', child: Text('Disable')),
              PopupMenuItem(value: 'SUSPENDED', child: Text('Suspend')),
              PopupMenuItem(value: 'BANNED', child: Text('Ban')),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AuraSurface.elevated,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Text(
        role.toUpperCase(),
        style: AuraText.micro.copyWith(
          color: AuraSurface.faint,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
