import 'package:aura/core/product/temporal.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/authority/authority_providers.dart';
import '../../../core/authority/capability_projection.dart';

import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/product/product_language.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../feed/domain/feed_media.dart';
import '../../posts/presentation/widgets/post_card/post_card_utils.dart';
import '../../share/aura_share_sheet.dart';
import '../data/institutions_repository.dart';
import '../institution_words.dart';
import '../workspace/workspace_page.dart';
import '../workspace/workspace_row_menu.dart';

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
    extends ConsumerState<InstitutionAnnouncementsScreen> {
  String _tab = 'published';

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
  // GOVERNANCE V1: managing announcements (publish/unpublish/delete + draft
  // list) requires MANAGE_ANNOUNCEMENTS; composing in the institution's voice
  // requires official representation. Representatives can draft; admins manage.
  /// Named for the authority it actually asks. It was called `_canManageAnnouncements`, which
  /// read as a role check and invited the next reader to copy the pattern —
  /// but MANAGE_ANNOUNCEMENTS is delegable, so an OWNER may grant it to someone
  /// who is not an admin, and an admin may hold it without being an owner.
  ///
  /// Asked of THIS institution (phase 2, 2026-10-09): it read the ambient
  /// identity, which is the person's oldest membership.
  bool get _canManageAnnouncements =>
      ref
          .read(capabilityProjectionForProvider(widget.institutionId))
          .presentationFor(ConsequentialAct.publishAnnouncement) ==
      ControlPresentation.available;

  bool get _canCompose =>
      _canManageAnnouncements ||
      ref
              .read(capabilityProjectionForProvider(widget.institutionId))
              .presentationFor(ConsequentialAct.authorOfficialContent) ==
          ControlPresentation.available;

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
      final published = await _repo.listInstitutionAnnouncements(
        widget.institutionId,
      );
      final drafts = _canManageAnnouncements
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
    setState(() {
      _actingOn = id;
      _actionError = null;
    });
    try {
      await _repo.publishInstitutionAnnouncement(widget.institutionId, id);
      await _load();
    } catch (e) {
      setState(() {
        _actionError = _message(e, 'Could not publish.');
        _actingOn = null;
      });
    }
  }

  Future<void> _unpublish(String id) async {
    if (_actingOn != null) return;
    setState(() {
      _actingOn = id;
      _actionError = null;
    });
    try {
      await _repo.unpublishInstitutionAnnouncement(widget.institutionId, id);
      await _load();
    } catch (e) {
      setState(() {
        _actionError = _message(e, 'Could not unpublish.');
        _actingOn = null;
      });
    }
  }

  Future<void> _delete(String id) async {
    if (_actingOn != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AuraSurface.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AuraRadius.card),
        ),
        title: const Text('Delete announcement', style: AuraText.subtitle),
        content: Text(
          'This announcement will be deleted and cannot be recovered.',
          style: AuraText.body.copyWith(color: AuraSurface.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: AuraText.small.copyWith(color: AuraSurface.muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Delete',
              style: AuraText.small.copyWith(
                color: AuraSurface.coRose,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _actingOn = id;
      _actionError = null;
    });
    try {
      await _repo.deleteInstitutionAnnouncement(widget.institutionId, id);
      await _load();
    } catch (e) {
      setState(() {
        _actionError = _message(e, 'Could not delete.');
        _actingOn = null;
      });
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
      case 'PUBLIC':
        return 'Public';
      case 'MEMBERS':
        return 'Members only';
      case 'INTERNAL':
        return 'Internal';
      default:
        return audience;
    }
  }

  String _formatDate(String? raw) {
    final dt = DateTime.tryParse(raw ?? '');
    if (dt == null) return '';
    return AuraTemporal.fullShort(dt);
  }

  List<Map<String, dynamic>> get _unpublished =>
      _drafts.where((a) => a['status']?.toString() == 'DRAFT').toList();

  /// One row per announcement (DD-43): title; audience, kind and date; one
  /// status pill; every act on it under the row's menu.
  Widget _row(Map<String, dynamic> ann, {bool isDraft = false}) {
    final id = ann['id']?.toString() ?? '';
    final title = ann['title']?.toString().trim() ?? '';
    final audience = ann['audience']?.toString() ?? 'PUBLIC';
    final slug = ann['slug']?.toString() ?? '';
    final kind = ann['kind']?.toString() ?? 'GENERAL';
    final pinned = ann['pinned'] == true;
    final date = isDraft
        ? _formatDate((ann['updatedAt'] ?? ann['createdAt'])?.toString())
        : _formatDate(ann['publishedAt']?.toString());
    final mediaCount = FeedMedia.listFromJson(ann['media']).length;
    final canOpenDetail = !isDraft && slug.trim().isNotEmpty;
    final editPath = '/institution/${widget.institutionId}/announcements/$id/edit';

    final menu = <WorkspaceAction>[
      if (canOpenDetail)
        WorkspaceAction(label: 'Read', icon: Icons.article_outlined, onPressed: () => context.push('/announcements/$slug')),
      if (!isDraft && audience == 'PUBLIC' && slug.isNotEmpty)
        WorkspaceAction(
          label: 'Share',
          icon: Icons.ios_share_rounded,
          onPressed: () => showAuraShareSheet(
            context,
            shareUrl: canonicalAnnouncementUrl(slug),
            headline: 'Share this announcement',
            subtitle: 'A public link that shows a preview on LinkedIn, X, Slack and Facebook.',
            emailSubject: 'Aura announcement',
          ),
        ),
      if (_canManageAnnouncements) ...[
        if (isDraft)
          WorkspaceAction(label: 'Publish', icon: Icons.send_rounded, onPressed: () => _publish(id))
        else
          WorkspaceAction(label: 'Unpublish', icon: Icons.unpublished_outlined, onPressed: () => _unpublish(id)),
        WorkspaceAction(
          label: 'Edit',
          icon: Icons.edit_outlined,
          onPressed: () => context.push(editPath).then((_) => _load()),
        ),
        WorkspaceAction(label: 'Delete', icon: Icons.delete_outline_rounded, destructive: true, onPressed: () => _delete(id)),
      ],
    ];

    return WorkspaceRow(
      leading: const WorkspaceIcon(Icons.campaign_outlined),
      title: title.isNotEmpty ? title : 'Untitled',
      context: [
        _audienceLabel(audience),
        announcementKindWords(kind),
        if (date.isNotEmpty) isDraft ? 'last edited $date' : date,
        if (mediaCount > 0) '$mediaCount attachment${mediaCount == 1 ? '' : 's'}',
      ].join(' · '),
      pill: isDraft
          ? const WorkspacePill(label: 'Draft', tone: WorkspaceTone.waiting)
          : pinned
              ? const WorkspacePill(label: 'Pinned', tone: WorkspaceTone.waiting)
              : const WorkspacePill(label: 'Published', tone: WorkspaceTone.done),
      trailing: _actingOn == id
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : (menu.isEmpty ? null : WorkspaceRowMenu(actions: menu)),
      onTap: canOpenDetail
          ? () => context.push('/announcements/$slug')
          : (isDraft && _canManageAnnouncements ? () => context.push(editPath).then((_) => _load()) : null),
    );
  }

  List<Widget> _content() {
    if (_error != null) {
      return [
        WorkspaceEmpty(
          icon: Icons.error_outline_rounded,
          title: 'Could not load announcements',
          body: _error!,
          action: WorkspaceAction(label: ProductLabels.of(ProductAction.retry), icon: Icons.refresh_rounded, onPressed: _load),
        ),
      ];
    }
    final drafts = _tab == 'drafts';
    final list = drafts ? _unpublished : _published;
    return [
      if (_actionError != null)
        WorkspaceRow(
          leading: const WorkspaceIcon(Icons.error_outline_rounded, tone: WorkspaceTone.problem),
          title: _actionError!,
          emphasis: WorkspaceTone.problem,
          trailing: IconButton(
            tooltip: 'Dismiss',
            icon: const Icon(Icons.close_rounded, size: 18, color: AuraSurface.muted),
            onPressed: () => setState(() => _actionError = null),
          ),
        ),
      if (list.isEmpty)
        drafts
            ? const WorkspaceEmpty(
                icon: Icons.drafts_outlined,
                title: 'No drafts',
                body: 'Announcements you start and do not publish wait here.',
              )
            : WorkspaceEmpty(
                icon: Icons.campaign_outlined,
                title: 'No announcements yet',
                body: 'Published announcements will appear here.',
                action: _canCompose
                    ? WorkspaceAction(label: 'New announcement', icon: Icons.add_rounded, onPressed: _compose)
                    : null,
              )
      else
        for (final a in list) _row(a, isDraft: drafts),
    ];
  }

  void _compose() => context
      .push('/institution/${widget.institutionId}/announcements/new')
      .then((_) => _load());

  @override
  Widget build(BuildContext context) {
    // Subscribe explicitly so role changes drive a rebuild — the `_canManageAnnouncements`
    // getter intentionally uses `ref.read` so it can be called from
    // initState / async handlers.
    ref.watch(institutionIdentityProvider);

    return WorkspacePage(
      type: WorkspacePageType.collection,
      title: 'Announcements',
      purpose: 'Official notices and public statements, in the institution’s name.',
      primary: _canCompose
          ? WorkspaceAction(label: 'New announcement', icon: Icons.add_rounded, onPressed: _compose)
          : null,
      // Drafts are a manager's list; everyone else sees what was published.
      tabs: _canManageAnnouncements
          ? [
              WorkspaceTab(id: 'published', label: 'Published', count: _loading ? null : _published.length),
              WorkspaceTab(id: 'drafts', label: 'Drafts', count: _loading ? null : _unpublished.length),
            ]
          : const [],
      selectedTab: _tab,
      onTab: (id) => setState(() => _tab = id),
      loading: _loading,
      children: _content(),
    );
  }
}
