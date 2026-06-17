import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/institutions_repository.dart';
import '../ui/institution_ds.dart';
import 'institution_page.dart';

class InstitutionSpacesScreen extends ConsumerStatefulWidget {
  const InstitutionSpacesScreen({
    super.key,
    required this.institutionId,
  });

  final String institutionId;

  @override
  ConsumerState<InstitutionSpacesScreen> createState() =>
      _InstitutionSpacesScreenState();
}

class _InstitutionSpacesScreenState extends ConsumerState<InstitutionSpacesScreen> {
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _spaces = const [];

  bool _creating = false;
  String? _createError;
  bool _showCreate = false;

  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _visibility = 'INVITE_ONLY';

  String? _actingOn;
  String? _actionError;

  InstitutionsRepository get _repo => ref.read(institutionsRepositoryProvider);

  /// Single source of truth for admin gating — never trust route query params.
  bool get _isAdmin =>
      ref.watch(institutionIdentityProvider)?.isAdmin ?? false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final spaces = await _repo.listInstitutionSpaces(widget.institutionId);
      setState(() { _spaces = spaces; _loading = false; });
    } catch (e) {
      setState(() { _error = _message(e, 'Could not load spaces.'); _loading = false; });
    }
  }

  Future<void> _create() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) { setState(() => _createError = 'Space name is required.'); return; }
    setState(() { _creating = true; _createError = null; });
    try {
      await _repo.createInstitutionSpace(
        widget.institutionId,
        title: title,
        description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        visibility: _visibility,
      );
      _titleController.clear();
      _descController.clear();
      setState(() { _creating = false; _showCreate = false; _visibility = 'INVITE_ONLY'; });
      await _load();
    } catch (e) {
      setState(() { _createError = _message(e, 'Could not create space.'); _creating = false; });
    }
  }

  Future<void> _join(String spaceId) async {
    if (_actingOn != null) return;
    setState(() { _actingOn = spaceId; _actionError = null; });
    try {
      await _repo.joinInstitutionSpace(widget.institutionId, spaceId);
      await _load();
    } catch (e) {
      setState(() { _actionError = _message(e, 'Could not join space.'); _actingOn = null; });
    }
  }

  Future<void> _archive(String spaceId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AuraSurface.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AuraRadius.card)),
        title: const Text('Archive space', style: AuraText.subtitle),
        content: Text('This space will be archived and members will lose access.', style: AuraText.body.copyWith(color: AuraSurface.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Cancel', style: AuraText.small.copyWith(color: AuraSurface.muted))),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Archive', style: AuraText.small.copyWith(color: AuraSurface.coRose, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (_actingOn != null) return;
    setState(() { _actingOn = spaceId; _actionError = null; });
    try {
      await _repo.archiveInstitutionSpace(widget.institutionId, spaceId);
      await _load();
    } catch (e) {
      setState(() { _actionError = _message(e, 'Could not archive space.'); _actingOn = null; });
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

  String _visibilityLabel(String v) {
    switch (v.toUpperCase()) {
      case 'DISCOVERABLE': return 'Public';
      case 'INVITE_ONLY': return 'Members';
      case 'PRIVATE': return 'Private';
      default: return v;
    }
  }

  Color _visibilityColor(String v) {
    switch (v.toUpperCase()) {
      case 'DISCOVERABLE': return AuraSurface.coVerdant;
      case 'INVITE_ONLY': return AuraSurface.accentText;
      case 'PRIVATE': return AuraSurface.muted;
      default: return AuraSurface.muted;
    }
  }

  Color _visibilityBg(String v) {
    switch (v.toUpperCase()) {
      case 'DISCOVERABLE': return AuraSurface.coVerdant.withValues(alpha: 0.16);
      case 'INVITE_ONLY': return AuraSurface.accentSoft;
      case 'PRIVATE': return AuraSurface.subtle;
      default: return AuraSurface.subtle;
    }
  }

  Widget _buildCreateForm() {
    return Container(
      margin: const EdgeInsets.only(bottom: AuraSpace.s16),
      padding: const EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.accentText.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('New space', style: AuraText.subtitle)),
              GestureDetector(
                onTap: () => setState(() { _showCreate = false; _createError = null; }),
                child: const Icon(Icons.close, size: 18, color: AuraSurface.muted),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s14),
          TextFormField(
            controller: _titleController,
            style: AuraText.body,
            decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. General, Updates, Staff'),
          ),
          const SizedBox(height: AuraSpace.s12),
          TextFormField(
            controller: _descController,
            style: AuraText.body,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Description (optional)', hintText: 'What is this space for?'),
          ),
          const SizedBox(height: AuraSpace.s12),
          Row(
            children: [
              Text('Visibility', style: AuraText.small.copyWith(color: AuraSurface.muted, fontWeight: FontWeight.w600)),
              const SizedBox(width: AuraSpace.s16),
              Expanded(
                child: DropdownButton<String>(
                  value: _visibility,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'DISCOVERABLE', child: Text('Public')),
                    DropdownMenuItem(value: 'INVITE_ONLY', child: Text('Members only')),
                    DropdownMenuItem(value: 'PRIVATE', child: Text('Admins only')),
                  ],
                  onChanged: (v) { if (v != null) setState(() => _visibility = v); },
                ),
              ),
            ],
          ),
          if (_createError != null) ...[
            const SizedBox(height: AuraSpace.s8),
            Text(_createError!, style: AuraText.small.copyWith(color: AuraSurface.coRose)),
          ],
          const SizedBox(height: AuraSpace.s16),
          AuraPrimaryButton(
            label: _creating ? 'Creating…' : 'Create space',
            onPressed: _creating ? null : _create,
            icon: Icons.add_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildSpaceTile(Map<String, dynamic> space) {
    final id = space['id']?.toString() ?? '';
    final title = space['title']?.toString().trim() ?? '';
    final description = space['description']?.toString().trim() ?? '';
    final visibility = space['visibility']?.toString() ?? 'INVITE_ONLY';
    final memberCount = space['memberCount'] as int? ?? 0;
    final threadCount = space['threadCount'] as int? ?? 0;
    final isActing = _actingOn == id;

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
          Row(
            children: [
              Expanded(
                child: Text(title.isNotEmpty ? title : 'Unnamed space', style: AuraText.body.copyWith(fontWeight: FontWeight.w700)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s8, vertical: AuraSpace.s4),
                decoration: BoxDecoration(
                  color: _visibilityBg(visibility),
                  borderRadius: BorderRadius.circular(AuraRadius.pill),
                ),
                child: Text(
                  _visibilityLabel(visibility),
                  style: AuraText.micro.copyWith(color: _visibilityColor(visibility), fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text(description, style: AuraText.small.copyWith(color: AuraSurface.muted, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: AuraSpace.s10),
          Row(
            children: [
              const Icon(Icons.people_outline, size: 12, color: AuraSurface.faint),
              const SizedBox(width: AuraSpace.s4),
              Text('$memberCount', style: AuraText.micro.copyWith(color: AuraSurface.faint)),
              const SizedBox(width: AuraSpace.s12),
              const Icon(Icons.chat_bubble_outline, size: 12, color: AuraSurface.faint),
              const SizedBox(width: AuraSpace.s4),
              Text('$threadCount threads', style: AuraText.micro.copyWith(color: AuraSurface.faint)),
              const Spacer(),
              if (isActing)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              else ...[
                GestureDetector(
                  onTap: () => context.push(
                    '/institution/${widget.institutionId}/spaces/$id',
                  ),
                  child: Text('Open', style: AuraText.small.copyWith(color: AuraSurface.accentText, fontWeight: FontWeight.w700)),
                ),
                if (!_isAdmin) ...[
                  const SizedBox(width: AuraSpace.s12),
                  GestureDetector(
                    onTap: () => _join(id),
                    child: Text('Join', style: AuraText.small.copyWith(color: AuraSurface.coVerdant, fontWeight: FontWeight.w700)),
                  ),
                ],
                if (_isAdmin) ...[
                  const SizedBox(width: AuraSpace.s12),
                  GestureDetector(
                    onTap: () => _archive(id),
                    child: const Icon(Icons.archive_outlined, size: 16, color: AuraSurface.coRose),
                  ),
                ],
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AuraLoadingState(message: 'Loading spaces…');
    if (_error != null) {
      return AuraErrorState(
        title: 'Could not load spaces',
        body: _error!,
        action: AuraSecondaryButton(label: 'Try again', onPressed: _load, icon: Icons.refresh_rounded),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_actionError != null) ...[
          Container(
            margin: const EdgeInsets.only(bottom: AuraSpace.s12),
            padding: const EdgeInsets.all(AuraSpace.s12),
            decoration: BoxDecoration(
              color: AuraSurface.coRose.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AuraRadius.md),
              border: Border.all(color: AuraSurface.coRose.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 16, color: AuraSurface.coRose),
                const SizedBox(width: AuraSpace.s8),
                Expanded(child: Text(_actionError!, style: AuraText.small.copyWith(color: AuraSurface.coRose))),
                GestureDetector(onTap: () => setState(() => _actionError = null), child: const Icon(Icons.close, size: 16, color: AuraSurface.coRose)),
              ],
            ),
          ),
        ],
        if (_showCreate && _isAdmin) _buildCreateForm(),
        if (_spaces.isEmpty && !_showCreate)
          const InsEmptyState(
            icon: Icons.forum_outlined,
            title: 'No spaces yet',
            description: 'Create one with New Space.',
          )
        else
          ..._spaces.map(_buildSpaceTile),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return InstitutionPage(
      title: 'Spaces',
      subtitle:
          'Coordinate internal groups, teams, and working rooms.',
      trailing: _isAdmin
          ? AuraPrimaryButton(
              label: _showCreate ? 'Hide form' : 'New Space',
              onPressed: () => setState(() {
                _showCreate = !_showCreate;
              }),
              icon: _showCreate ? Icons.close_rounded : Icons.add_rounded,
            )
          : null,
      body: _buildBody(),
    );
  }
}
