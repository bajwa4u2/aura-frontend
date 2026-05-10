import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/media/canonical_media_thumb.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../features/institutions/presentation/institution_page.dart';
import '../../feed/domain/feed_media.dart';
import '../data/institutions_repository.dart';
import '../ui/institution_ds.dart';

class InstitutionAnnouncementsScreen extends ConsumerStatefulWidget {
  const InstitutionAnnouncementsScreen({
    super.key,
    required this.institutionId,
  });

  final String institutionId;

  @override
  ConsumerState<InstitutionAnnouncementsScreen> createState() =>
      _InstitutionAnnouncementsScreenState();
}

class _InstitutionAnnouncementsScreenState
    extends ConsumerState<InstitutionAnnouncementsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _published = const [];
  List<Map<String, dynamic>> _drafts = const [];

  String? _actingOn;
  String? _actionError;

  InstitutionsRepository get _repo => ref.read(institutionsRepositoryProvider);

  /// Single source of truth for admin gating — never trust route query params.
  /// Uses [ref.read] so the getter is safe from non-build call sites
  /// (initState, async handlers). The `build()` method explicitly subscribes
  /// to [institutionIdentityProvider] so rebuilds still happen on role change.
  bool get _isAdmin =>
      ref.read(institutionIdentityProvider)?.isAdmin ?? false;

  @override
  void initState() {
    super.initState();
    // Always 2 tabs (Published + Drafts). The Drafts tab is rendered only for
    // admins, so the controller length stays stable across role changes.
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final published = await _repo.listInstitutionAnnouncements(widget.institutionId);
      final drafts = _isAdmin
          ? await _repo.listInstitutionDrafts(widget.institutionId)
          : <Map<String, dynamic>>[];
      setState(() {
        _published = published;
        _drafts = drafts;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = _message(e, 'Could not load announcements.');
        _loading = false;
      });
    }
  }

  Future<void> _publish(String id) async {
    if (_actingOn != null) return;
    setState(() { _actingOn = id; _actionError = null; });
    try {
      await _repo.publishInstitutionAnnouncement(widget.institutionId, id);
      await _load();
    } catch (e) {
      setState(() { _actionError = _message(e, 'Could not publish.'); _actingOn = null; });
    }
  }

  Future<void> _unpublish(String id) async {
    if (_actingOn != null) return;
    setState(() { _actingOn = id; _actionError = null; });
    try {
      await _repo.unpublishInstitutionAnnouncement(widget.institutionId, id);
      await _load();
    } catch (e) {
      setState(() { _actionError = _message(e, 'Could not unpublish.'); _actingOn = null; });
    }
  }

  Future<void> _delete(String id) async {
    if (_actingOn != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AuraSurface.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AuraRadius.card)),
        title: const Text('Delete announcement', style: AuraText.subtitle),
        content: Text(
          'This announcement will be deleted and cannot be recovered.',
          style: AuraText.body.copyWith(color: AuraSurface.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: AuraText.small.copyWith(color: AuraSurface.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete', style: AuraText.small.copyWith(color: AuraSurface.dangerInk, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() { _actingOn = id; _actionError = null; });
    try {
      await _repo.deleteInstitutionAnnouncement(widget.institutionId, id);
      await _load();
    } catch (e) {
      setState(() { _actionError = _message(e, 'Could not delete.'); _actingOn = null; });
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

  String _audienceLabel(String audience) {
    switch (audience.toUpperCase()) {
      case 'PUBLIC': return 'Public';
      case 'MEMBERS': return 'Members only';
      case 'INTERNAL': return 'Internal';
      default: return audience;
    }
  }

  Color _audienceColor(String audience) {
    switch (audience.toUpperCase()) {
      case 'PUBLIC': return AuraSurface.goodInk;
      case 'MEMBERS': return AuraSurface.accentText;
      default: return AuraSurface.muted;
    }
  }

  Color _audienceBg(String audience) {
    switch (audience.toUpperCase()) {
      case 'PUBLIC': return AuraSurface.goodBg;
      case 'MEMBERS': return AuraSurface.accentSoft;
      default: return AuraSurface.subtle;
    }
  }

  String _formatDate(String? raw) {
    final dt = DateTime.tryParse(raw ?? '');
    if (dt == null) return '';
    final local = dt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  Widget _buildAnnouncementTile(Map<String, dynamic> ann, {bool isDraft = false}) {
    final id = ann['id']?.toString() ?? '';
    final title = ann['title']?.toString().trim() ?? '';
    final summary = ann['summary']?.toString().trim() ?? '';
    final audience = ann['audience']?.toString() ?? 'PUBLIC';
    final kind = ann['kind']?.toString() ?? 'GENERAL';
    final publishedAt = _formatDate(ann['publishedAt']?.toString());
    final createdAt = _formatDate(ann['createdAt']?.toString());
    final isActing = _actingOn == id;
    final mediaList = FeedMedia.listFromJson(ann['media']);
    final firstMedia = mediaList.isEmpty ? null : mediaList.first;

    return Container(
      margin: const EdgeInsets.only(bottom: AuraSpace.s10),
      padding: const EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (firstMedia != null) ...[
            CanonicalMediaThumb(media: firstMedia),
            const SizedBox(height: AuraSpace.s12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title.isNotEmpty ? title : 'Untitled',
                  style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: AuraSpace.s8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s8, vertical: AuraSpace.s4),
                decoration: BoxDecoration(
                  color: _audienceBg(audience),
                  borderRadius: BorderRadius.circular(AuraRadius.pill),
                ),
                child: Text(
                  _audienceLabel(audience),
                  style: AuraText.micro.copyWith(color: _audienceColor(audience), fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text(
              summary,
              style: AuraText.small.copyWith(color: AuraSurface.muted, height: 1.45),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: AuraSpace.s10),
          Row(
            children: [
              Text(
                kind[0] + kind.substring(1).toLowerCase(),
                style: AuraText.micro.copyWith(color: AuraSurface.faint),
              ),
              if (!isDraft && publishedAt.isNotEmpty) ...[
                Text(' · ', style: AuraText.micro.copyWith(color: AuraSurface.faint)),
                Text(publishedAt, style: AuraText.micro.copyWith(color: AuraSurface.faint)),
              ] else if (isDraft && createdAt.isNotEmpty) ...[
                Text(' · ', style: AuraText.micro.copyWith(color: AuraSurface.faint)),
                Text('Draft · $createdAt', style: AuraText.micro.copyWith(color: AuraSurface.warnInk)),
              ],
            ],
          ),
          if (_isAdmin) ...[
            const SizedBox(height: AuraSpace.s12),
            if (isActing)
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            else
              Row(
                children: [
                  if (isDraft)
                    _ActionBtn(
                      label: 'Publish',
                      icon: Icons.send_rounded,
                      color: AuraSurface.goodInk,
                      onTap: () => _publish(id),
                    )
                  else
                    _ActionBtn(
                      label: 'Unpublish',
                      icon: Icons.unpublished_outlined,
                      color: AuraSurface.warnInk,
                      onTap: () => _unpublish(id),
                    ),
                  const SizedBox(width: AuraSpace.s10),
                  _ActionBtn(
                    label: 'Edit',
                    icon: Icons.edit_outlined,
                    color: AuraSurface.accentText,
                    onTap: () => context.push(
                      '/institution/${widget.institutionId}/announcements/$id/edit',
                    ),
                  ),
                  const SizedBox(width: AuraSpace.s10),
                  _ActionBtn(
                    label: 'Delete',
                    icon: Icons.delete_outline_rounded,
                    color: AuraSurface.dangerInk,
                    onTap: () => _delete(id),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildPublishedList() {
    if (_published.isEmpty) {
      return const InsEmptyState(
        icon: Icons.campaign_outlined,
        title: 'No announcements yet',
        description: 'Published announcements will appear here.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _published.map((a) => _buildAnnouncementTile(a)).toList(),
    );
  }

  Widget _buildDraftsList() {
    final unpublished = _drafts.where((a) => a['status']?.toString() == 'DRAFT').toList();
    if (unpublished.isEmpty) {
      return const InsEmptyState(
        icon: Icons.drafts_outlined,
        title: 'No drafts',
        description: 'Use the action above to start a new announcement draft.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: unpublished.map((a) => _buildAnnouncementTile(a, isDraft: true)).toList(),
    );
  }

  Widget _buildErrorBanner() {
    if (_actionError == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: AuraSpace.s12),
      padding: const EdgeInsets.all(AuraSpace.s12),
      decoration: BoxDecoration(
        color: AuraSurface.dangerBg,
        borderRadius: BorderRadius.circular(AuraRadius.md),
        border: Border.all(color: AuraSurface.dangerInk.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: AuraSurface.dangerInk),
          const SizedBox(width: AuraSpace.s8),
          Expanded(child: Text(_actionError!, style: AuraText.small.copyWith(color: AuraSurface.dangerInk))),
          GestureDetector(
            onTap: () => setState(() => _actionError = null),
            child: const Icon(Icons.close, size: 16, color: AuraSurface.dangerInk),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AuraLoadingState(message: 'Loading announcements…');
    if (_error != null) {
      return AuraErrorState(
        title: 'Could not load announcements',
        body: _error!,
        action: AuraSecondaryButton(label: 'Try again', onPressed: _load, icon: Icons.refresh_rounded),
      );
    }

    if (!_isAdmin) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildErrorBanner(),
          _buildPublishedList(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildErrorBanner(),
        TabBar(
          controller: _tabs,
          labelStyle: AuraText.small.copyWith(fontWeight: FontWeight.w700),
          unselectedLabelStyle: AuraText.small,
          labelColor: AuraSurface.accentText,
          unselectedLabelColor: AuraSurface.muted,
          indicatorColor: AuraSurface.accentText,
          tabs: const [Tab(text: 'Published'), Tab(text: 'Drafts')],
        ),
        const SizedBox(height: AuraSpace.s16),
        SizedBox(
          height: 800,
          child: TabBarView(
            controller: _tabs,
            children: [
              _buildPublishedList(),
              _buildDraftsList(),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Subscribe explicitly so role changes drive a rebuild — the `_isAdmin`
    // getter intentionally uses `ref.read` so it can be called from
    // initState / async handlers.
    ref.watch(institutionIdentityProvider);

    return InstitutionPage(
      title: 'Announcements',
      subtitle:
          'Publish official institutional notices and public statements.',
      trailing: _isAdmin
          ? AuraPrimaryButton(
              label: 'New announcement',
              onPressed: () => context
                  .push(
                    '/institution/${widget.institutionId}/announcements/new',
                  )
                  .then((_) => _load()),
              icon: Icons.add_rounded,
            )
          : null,
      body: _buildBody(),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AuraSpace.s4),
          Text(label, style: AuraText.micro.copyWith(color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
