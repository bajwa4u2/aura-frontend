import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/admin_providers.dart';
import 'admin_error.dart';

class AdminAuditLogsScreen extends ConsumerStatefulWidget {
  const AdminAuditLogsScreen({super.key});

  @override
  ConsumerState<AdminAuditLogsScreen> createState() => _AdminAuditLogsScreenState();
}

class _AdminAuditLogsScreenState extends ConsumerState<AdminAuditLogsScreen> {
  final _actorController = TextEditingController();
  final _actionController = TextEditingController();
  String _resultFilter = '';
  int _page = 1;
  List<AdminAuditLogEntry> _entries = const [];
  bool _loading = false;
  Object? _error;
  bool _hasMore = true;

  static const _pageSize = 50;
  static const _results = ['', 'SUCCESS', 'DENIED', 'FAILED'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  @override
  void dispose() {
    _actorController.dispose();
    _actionController.dispose();
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
      final actorId = _actorController.text.trim();
      final action = _actionController.text.trim();
      final results = await repo.fetchAuditLogs(
        page: currentPage,
        limit: _pageSize,
        actorId: actorId.isNotEmpty ? actorId : null,
        action: action.isNotEmpty ? action : null,
        result: _resultFilter.isNotEmpty ? _resultFilter : null,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _entries = results;
        } else {
          _entries = [..._entries, ...results];
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

  @override
  Widget build(BuildContext context) {
    return AuraScaffold(
      title: 'Audit log',
      showHomeAction: true,
      body: Column(
        children: [
          _AuditFilterBar(
            actorController: _actorController,
            actionController: _actionController,
            resultFilter: _resultFilter,
            results: _results,
            onSearch: () => _load(reset: true),
            onResultChanged: (r) {
              setState(() => _resultFilter = r);
              _load(reset: true);
            },
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _entries.isEmpty) {
      return const Center(child: AuraLoadingState(message: 'Loading audit log…'));
    }
    if (_error != null && _entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AuraSpace.s16),
          child: AuraErrorState(
            title: 'Failed to load audit log',
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
    if (!_loading && _entries.isEmpty) {
      return const Center(
        child: AuraEmptyState(
          title: 'No audit entries',
          body: 'No admin actions match the current filters.',
          icon: Icons.history_rounded,
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
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AuraSurface.card,
                    borderRadius: BorderRadius.circular(AuraRadius.card),
                    border: Border.all(color: AuraSurface.divider),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < _entries.length; i++) ...[
                        _AuditRow(entry: _entries[i]),
                        if (i < _entries.length - 1)
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
                if (_loading && _entries.isNotEmpty)
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

class _AuditFilterBar extends StatelessWidget {
  const _AuditFilterBar({
    required this.actorController,
    required this.actionController,
    required this.resultFilter,
    required this.results,
    required this.onSearch,
    required this.onResultChanged,
  });

  final TextEditingController actorController;
  final TextEditingController actionController;
  final String resultFilter;
  final List<String> results;
  final VoidCallback onSearch;
  final ValueChanged<String> onResultChanged;

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
          constraints: const BoxConstraints(maxWidth: 960),
          child: Wrap(
            spacing: AuraSpace.s10,
            runSpacing: AuraSpace.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 220,
                height: 40,
                child: _FilterField(
                  controller: actorController,
                  hint: 'Actor ID or email…',
                  onSubmitted: onSearch,
                ),
              ),
              SizedBox(
                width: 220,
                height: 40,
                child: _FilterField(
                  controller: actionController,
                  hint: 'Action name…',
                  onSubmitted: onSearch,
                ),
              ),
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
                    value: resultFilter,
                    hint: Text(
                      'All results',
                      style: AuraText.small.copyWith(color: AuraSurface.muted),
                    ),
                    style: AuraText.small.copyWith(color: AuraSurface.ink),
                    icon: const Icon(
                      Icons.arrow_drop_down_rounded,
                      size: 18,
                      color: AuraSurface.faint,
                    ),
                    onChanged: (v) {
                      if (v != null) onResultChanged(v);
                    },
                    items: results
                        .map(
                          (r) => DropdownMenuItem(
                            value: r,
                            child: Text(r.isEmpty ? 'All results' : r),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              _SearchButton(onPressed: onSearch),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterField extends StatelessWidget {
  const _FilterField({
    required this.controller,
    required this.hint,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: AuraText.small,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AuraText.small.copyWith(color: AuraSurface.muted),
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
      onSubmitted: (_) => onSubmitted(),
      textInputAction: TextInputAction.search,
    );
  }
}

class _SearchButton extends StatelessWidget {
  const _SearchButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s14),
        decoration: BoxDecoration(
          color: AuraSurface.accentSoft,
          borderRadius: BorderRadius.circular(AuraRadius.md),
          border: Border.all(
            color: AuraSurface.accent.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_rounded, size: 16, color: AuraSurface.accentText),
            const SizedBox(width: AuraSpace.s6),
            Text(
              'Search',
              style: AuraText.small.copyWith(
                color: AuraSurface.accentText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AUDIT ROW
// ─────────────────────────────────────────────────────────────────────────────

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.entry});

  final AdminAuditLogEntry entry;

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '${months[local.month - 1]} ${local.day}, ${local.year} $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s16,
        vertical: AuraSpace.s12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AuraSurface.elevated,
              borderRadius: BorderRadius.circular(AuraRadius.md),
              border: Border.all(color: AuraSurface.divider),
            ),
            child: const Icon(
              Icons.history_rounded,
              size: 16,
              color: AuraSurface.faint,
            ),
          ),
          const SizedBox(width: AuraSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.action,
                  style: AuraText.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AuraSurface.ink,
                  ),
                ),
                const SizedBox(height: AuraSpace.s4),
                Text(
                  entry.actorEmail.isNotEmpty ? entry.actorEmail : entry.actorId,
                  style: AuraText.small.copyWith(color: AuraSurface.muted),
                ),
                if (entry.targetType.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Target: ${entry.targetType}${entry.targetId != null ? ' · ${entry.targetId}' : ''}',
                    style: AuraText.micro.copyWith(color: AuraSurface.faint),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AuraSpace.s10),
          Text(
            _formatDate(entry.createdAt),
            style: AuraText.micro.copyWith(color: AuraSurface.faint),
          ),
        ],
      ),
    );
  }
}
