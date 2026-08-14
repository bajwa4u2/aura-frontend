import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/spaces_repository.dart';

/// Domain 13 — Conversation Lifecycle / Retention Consequence Integrity.
/// Discoverability + governed restore for Spaces this user personally
/// archived. Personal organization state only — never lists a Space
/// archived at the institutional/global level (that's institution-admin
/// territory, see InstitutionSpacesScreen's own archived view).
class ArchivedSpacesScreen extends ConsumerStatefulWidget {
  const ArchivedSpacesScreen({super.key});

  @override
  ConsumerState<ArchivedSpacesScreen> createState() =>
      _ArchivedSpacesScreenState();
}

class _ArchivedSpacesScreenState extends ConsumerState<ArchivedSpacesScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _spaces = const [];
  String? _restoringId;

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
      final spaces = await ref
          .read(spacesRepositoryProvider)
          .listMySpaces(scope: 'archived');
      if (!mounted) return;
      setState(() {
        _spaces = spaces;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _message(e, 'Could not load archived spaces.');
        _loading = false;
      });
    }
  }

  Future<void> _restore(String spaceId) async {
    if (_restoringId != null) return;
    setState(() => _restoringId = spaceId);
    try {
      await ref
          .read(spacesRepositoryProvider)
          .setPersonalArchived(spaceId, archived: false);
      // The active list's own cache would otherwise still be stale —
      // clear it so the restored space reappears immediately there too.
      ref.read(spacesRepositoryProvider).clearCache();
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _restoringId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_message(e, 'Could not restore space.'))),
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
                    child: Text('Archived spaces', style: AuraText.headline),
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
      return const AuraLoadingState(message: 'Loading archived spaces…');
    }
    if (_error != null) {
      return Center(
        child: AuraErrorState(
          title: 'Could not load archived spaces',
          body: _error!,
          action: AuraSecondaryButton(
            label: 'Try again',
            icon: Icons.refresh_rounded,
            onPressed: _load,
          ),
        ),
      );
    }
    if (_spaces.isEmpty) {
      return const Center(
        child: AuraEmptyState(
          icon: Icons.archive_outlined,
          title: 'No archived spaces',
          body: 'Spaces you archive show up here, restorable any time.',
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(AuraSpace.s12),
        itemCount: _spaces.length,
        separatorBuilder: (_, __) => const SizedBox(height: AuraSpace.s8),
        itemBuilder: (context, i) {
          final space = _spaces[i];
          final id = space['id']?.toString() ?? '';
          final title = space['title']?.toString().trim() ?? '';
          final isRestoring = _restoringId == id;
          return Container(
            padding: const EdgeInsets.all(AuraSpace.s14),
            decoration: BoxDecoration(
              color: AuraSurface.subtle,
              borderRadius: BorderRadius.circular(AuraRadius.md),
              border: Border.all(color: AuraSurface.divider),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title.isNotEmpty ? title : 'Unnamed space',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (isRestoring)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  AuraSecondaryButton(
                    label: 'Restore',
                    icon: Icons.unarchive_outlined,
                    onPressed: () => _restore(id),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
