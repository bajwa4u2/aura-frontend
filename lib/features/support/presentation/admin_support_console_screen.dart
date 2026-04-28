import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_scaffold.dart';
import '../providers.dart';
import 'widgets/support_case_list_tile.dart';

class AdminSupportConsoleScreen extends ConsumerStatefulWidget {
  const AdminSupportConsoleScreen({super.key});

  @override
  ConsumerState<AdminSupportConsoleScreen> createState() => _AdminSupportConsoleScreenState();
}

class _AdminSupportConsoleScreenState extends ConsumerState<AdminSupportConsoleScreen> {
  final _searchCtrl = TextEditingController();
  String? _statusFilter;
  String? _categoryFilter;
  String? _selectedCaseId;

  static const _statuses = ['NEW', 'OPEN', 'WAITING_ON_USER', 'WAITING_ON_AURA', 'RESOLVED', 'CLOSED'];
  static const _categories = [
    'AUTH', 'ACCOUNT', 'MESSAGES', 'CALLS', 'NOTIFICATIONS', 'PROFILE',
    'INSTITUTION', 'SAFETY', 'PRIVACY', 'LEGAL', 'BILLING', 'BUG', 'FEATURE', 'OTHER',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminSupportCasesProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyFilters() {
    ref.read(adminSupportCasesProvider.notifier).load(
          status: _statusFilter,
          category: _categoryFilter,
          search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminSupportCasesProvider);
    final theme = Theme.of(context);

    return AuraScaffold(
      title: 'Support console',
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cases list panel
          SizedBox(
            width: 420,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Filters
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Search ref, email, summary…',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search, size: 18),
                            onPressed: _applyFilters,
                          ),
                        ),
                        onSubmitted: (_) => _applyFilters(),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String?>(
                              key: ValueKey(_statusFilter),
                              initialValue: _statusFilter,
                              decoration: const InputDecoration(
                                labelText: 'Status',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('All')),
                                ..._statuses.map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s.replaceAll('_', ' '), overflow: TextOverflow.ellipsis),
                                  ),
                                ),
                              ],
                              onChanged: (v) {
                                setState(() => _statusFilter = v);
                                _applyFilters();
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String?>(
                              key: ValueKey(_categoryFilter),
                              initialValue: _categoryFilter,
                              decoration: const InputDecoration(
                                labelText: 'Category',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('All')),
                                ..._categories.map(
                                  (c) => DropdownMenuItem(value: c, child: Text(c)),
                                ),
                              ],
                              onChanged: (v) {
                                setState(() => _categoryFilter = v);
                                _applyFilters();
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Stats row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    '${state.total} case${state.total == 1 ? '' : 's'}',
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                  ),
                ),
                // List
                Expanded(
                  child: state.loading
                      ? const Center(child: CircularProgressIndicator())
                      : state.error != null
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Failed to load cases', style: theme.textTheme.bodyMedium),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () => ref.read(adminSupportCasesProvider.notifier).refresh(),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          : state.cases.isEmpty
                              ? Center(
                                  child: Text('No cases', style: theme.textTheme.bodyMedium),
                                )
                              : ListView.separated(
                                  itemCount: state.cases.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (context, i) {
                                    final c = state.cases[i];
                                    return SupportCaseListTile(
                                      supportCase: c,
                                      onTap: () => setState(() => _selectedCaseId = c.id),
                                    );
                                  },
                                ),
                ),
              ],
            ),
          ),

          const VerticalDivider(width: 1),

          // Case detail panel
          Expanded(
            child: _selectedCaseId != null
                ? _CaseDetailPanel(
                    caseId: _selectedCaseId!,
                    key: ValueKey(_selectedCaseId),
                    onClose: () => setState(() => _selectedCaseId = null),
                    onRefresh: () => ref.read(adminSupportCasesProvider.notifier).refresh(),
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.support_agent_outlined, size: 48, color: theme.colorScheme.outlineVariant),
                        const SizedBox(height: 12),
                        Text('Select a case to view details', style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Case detail panel ─────────────────────────────────────────────────────────

class _CaseDetailPanel extends ConsumerStatefulWidget {
  const _CaseDetailPanel({
    super.key,
    required this.caseId,
    required this.onClose,
    required this.onRefresh,
  });

  final String caseId;
  final VoidCallback onClose;
  final VoidCallback onRefresh;

  @override
  ConsumerState<_CaseDetailPanel> createState() => _CaseDetailPanelState();
}

class _CaseDetailPanelState extends ConsumerState<_CaseDetailPanel> {
  Map<String, dynamic>? _caseData;
  bool _loading = true;
  String? _error;
  final _replyCtrl = TextEditingController();
  bool _sending = false;
  String? _aiDraft;
  bool _loadingDraft = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final repo = ref.read(supportRepositoryProvider);
      final data = await repo.adminGetCase(widget.caseId);
      if (mounted) setState(() { _caseData = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _reply() async {
    final content = _replyCtrl.text.trim();
    if (content.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final repo = ref.read(supportRepositoryProvider);
      await repo.adminReply(widget.caseId, content);
      _replyCtrl.clear();
      await _load();
      widget.onRefresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send reply')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _changeStatus(String status) async {
    try {
      final repo = ref.read(supportRepositoryProvider);
      await repo.adminChangeStatus(widget.caseId, status);
      await _load();
      widget.onRefresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update status')),
        );
      }
    }
  }

  Future<void> _loadAiDraft() async {
    setState(() => _loadingDraft = true);
    try {
      final repo = ref.read(supportRepositoryProvider);
      final result = await repo.adminAiDraft(widget.caseId);
      if (mounted && result['draft'] != null) {
        setState(() {
          _aiDraft = result['draft'] as String;
          _replyCtrl.text = _aiDraft!;
        });
      }
    } finally {
      if (mounted) setState(() => _loadingDraft = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Failed to load case', style: theme.textTheme.bodyMedium),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final data = _caseData!;
    final ref_ = data['ref'] as String? ?? '';
    final status = data['status'] as String? ?? 'NEW';
    final category = data['category'] as String? ?? 'OTHER';
    final severity = data['severity'] as String? ?? 'MEDIUM';
    final aiSummary = data['aiSummary'] as String?;
    final requesterEmail = data['requesterEmail'] as String?;
    final messages = (data['conversation']?['messages'] as List<dynamic>?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Case header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ref_, style: theme.textTheme.titleMedium?.copyWith(fontFamily: 'monospace')),
                    if (aiSummary != null)
                      Text(aiSummary, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: [
                        Chip(label: Text(category, style: theme.textTheme.labelSmall)),
                        Chip(label: Text(severity, style: theme.textTheme.labelSmall)),
                        Chip(label: Text(status.replaceAll('_', ' '), style: theme.textTheme.labelSmall)),
                        if (requesterEmail != null)
                          Chip(label: Text(requesterEmail, style: theme.textTheme.labelSmall)),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: widget.onClose),
            ],
          ),
        ),

        // Status actions
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Wrap(
            spacing: 8,
            children: [
              if (status != 'OPEN') _ActionChip(label: 'Mark open', onTap: () => _changeStatus('OPEN')),
              if (status != 'WAITING_ON_USER') _ActionChip(label: 'Waiting on user', onTap: () => _changeStatus('WAITING_ON_USER')),
              if (status != 'RESOLVED') _ActionChip(label: 'Resolve', onTap: () => _changeStatus('RESOLVED')),
              if (status != 'CLOSED') _ActionChip(label: 'Close', onTap: () => _changeStatus('CLOSED')),
            ],
          ),
        ),

        // Conversation transcript
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: messages.length,
            itemBuilder: (context, i) {
              final m = messages[i] as Map<String, dynamic>;
              final role = m['role'] as String? ?? 'assistant';
              final content = m['content'] as String? ?? '';
              final isUser = role == 'user';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(
                        role == 'user' ? 'User' : role == 'admin' ? 'Admin' : 'AI',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isUser ? theme.colorScheme.primary : theme.colorScheme.outline,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(content, style: theme.textTheme.bodySmall),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // Reply area
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('Reply', style: theme.textTheme.labelMedium),
                  const Spacer(),
                  TextButton.icon(
                    icon: _loadingDraft
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.auto_awesome, size: 14),
                    label: const Text('AI draft', style: TextStyle(fontSize: 12)),
                    onPressed: _loadingDraft ? null : _loadAiDraft,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _replyCtrl,
                decoration: const InputDecoration(
                  hintText: 'Write a reply…',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                minLines: 3,
                maxLines: 6,
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                icon: _sending
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send, size: 16),
                label: const Text('Send reply'),
                onPressed: _sending ? null : _reply,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label, style: Theme.of(context).textTheme.labelSmall),
      onPressed: onTap,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
