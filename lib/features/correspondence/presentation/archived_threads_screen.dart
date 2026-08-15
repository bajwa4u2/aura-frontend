import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/product/product_language.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/threads_repository.dart';

/// Domain 13 — Conversation Lifecycle / Retention Consequence Integrity.
///
/// A Thread can be archived at two independent levels — this screen must
/// surface both, distinctly, per row:
///   * personally (`personalArchivedAt` set) — this user's own
///     organization state; "Unarchive for me" is available to them alone
///     and never affects anyone else.
///   * globally (`archivedAt` set) — the owner/admin/editor lifecycle
///     action; "Restore conversation (everyone)" uses the same authority
///     as the archive action itself. Not client-role-gated here, matching
///     this codebase's existing convention for that action (thread_screen
///     .dart's own "Archive conversation" menu item) — the server enforces
///     and a plain member sees a clear, honest rejection rather than a
///     hidden button implying they never had the option.
/// A single Thread can show both actions at once if archived both ways.
class ArchivedThreadsScreen extends ConsumerStatefulWidget {
  const ArchivedThreadsScreen({super.key, required this.spaceId});

  final String spaceId;

  @override
  ConsumerState<ArchivedThreadsScreen> createState() =>
      _ArchivedThreadsScreenState();
}

class _ArchivedThreadsScreenState extends ConsumerState<ArchivedThreadsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _threads = const [];
  String? _actingOn;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final threads = await ref
          .read(threadsRepositoryProvider)
          .listThreads(spaceId: widget.spaceId, scope: 'archived');
      if (!mounted) return;
      setState(() {
        _threads = threads;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _message(e, 'Could not load archived conversations.');
        _loading = false;
      });
    }
  }

  Future<void> _unarchiveForMe(String threadId) async {
    if (_actingOn != null) return;
    setState(() => _actingOn = threadId);
    try {
      await ref
          .read(threadsRepositoryProvider)
          .setPersonalArchived(threadId, archived: false);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _actingOn = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_message(e, 'Could not unarchive.'))),
      );
    }
  }

  Future<void> _restoreGlobal(String threadId) async {
    if (_actingOn != null) return;
    setState(() => _actingOn = threadId);
    try {
      await ref
          .read(threadsRepositoryProvider)
          .updateThread(threadId, archived: false);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _actingOn = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_message(e, 'Could not restore this conversation.'))),
      );
    }
  }

  String _message(Object error, String fallback) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final msg = data['message']?.toString().trim() ?? '';
        if (msg.isNotEmpty) return msg;
      }
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    return AuraScaffold(
      showHeader: false,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AuraSpace.s16,
                AuraSpace.s16,
                AuraSpace.s16,
                AuraSpace.s8,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => context.pop(),
                  ),
                  const Expanded(
                    child: Text('Archived conversations', style: AuraText.headline),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const AuraLoadingState(message: 'Loading archived conversations…');
    }
    if (_error != null) {
      return Center(
        child: AuraErrorState(
          title: 'Could not load archived conversations',
          body: _error!,
          action: AuraSecondaryButton(
            label: ProductLabels.of(ProductAction.retry),
            icon: Icons.refresh_rounded,
            onPressed: _load,
          ),
        ),
      );
    }
    if (_threads.isEmpty) {
      return const Center(
        child: AuraEmptyState(
          icon: Icons.archive_outlined,
          title: 'No archived conversations',
          body: 'Conversations archived for you, or for everyone, show up here.',
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(AuraSpace.s12),
        itemCount: _threads.length,
        separatorBuilder: (_, __) => const SizedBox(height: AuraSpace.s8),
        itemBuilder: (context, i) => _buildTile(_threads[i]),
      ),
    );
  }

  Widget _buildTile(Map<String, dynamic> thread) {
    final id = thread['id']?.toString() ?? '';
    final title = thread['title']?.toString().trim() ?? '';
    final isGlobalArchived = thread['archivedAt'] != null;
    final isPersonalArchived = thread['personalArchivedAt'] != null;
    final isActing = _actingOn == id;

    return Container(
      padding: const EdgeInsets.all(AuraSpace.s14),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.md),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.isNotEmpty ? title : 'Untitled conversation',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AuraSpace.s6),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s6,
            children: [
              if (isPersonalArchived)
                Text(
                  'Archived for you',
                  style: AuraText.micro.copyWith(color: AuraSurface.muted),
                ),
              if (isGlobalArchived)
                Text(
                  'Archived for everyone',
                  style: AuraText.micro.copyWith(color: AuraSurface.coRose),
                ),
            ],
          ),
          const SizedBox(height: AuraSpace.s10),
          if (isActing)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Wrap(
              spacing: AuraSpace.s8,
              runSpacing: AuraSpace.s8,
              children: [
                if (isPersonalArchived)
                  AuraSecondaryButton(
                    label: 'Unarchive for me',
                    icon: Icons.unarchive_outlined,
                    onPressed: () => _unarchiveForMe(id),
                  ),
                if (isGlobalArchived)
                  AuraSecondaryButton(
                    label: 'Restore for everyone',
                    icon: Icons.unarchive_outlined,
                    onPressed: () => _restoreGlobal(id),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
