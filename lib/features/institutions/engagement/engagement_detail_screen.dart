import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/utils/relative_time.dart';
import '../data/institutions_repository.dart';
import '../domain/institution_post.dart';
import 'engagement_models.dart';
import 'engagement_providers.dart';

class EngagementDetailScreen extends ConsumerWidget {
  const EngagementDetailScreen({
    super.key,
    required this.institutionId,
    required this.recordId,
  });

  final String institutionId;
  final String recordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(
      engagementDetailProvider((institutionId, recordId)),
    );
    final identity = ref.watch(institutionIdentityProvider);
    final canPublish = identity?.canPublishPosts ?? false;

    return async.when(
      loading: () => AuraScaffold(
        title: 'Public Record',
        showHomeAction: false,
        body: const Center(child: AuraLoadingState(message: 'Loading…')),
      ),
      error: (e, _) => AuraScaffold(
        title: 'Public Record',
        showHomeAction: false,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AuraSpace.s16),
            child: AuraErrorState(
              title: 'Could not load record',
              body: e.toString(),
            ),
          ),
        ),
      ),
      data: (record) => AuraScaffold(
        title: 'Public Record',
        showHomeAction: false,
        body: _DetailBody(
          record: record,
          institutionId: institutionId,
          canPublish: canPublish,
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.record,
    required this.institutionId,
    required this.canPublish,
  });

  final RoutedRecord record;
  final String institutionId;
  final bool canPublish;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (record.status) {
      RoutedRecordStatus.pending => const Color(0xFFE8853A),
      RoutedRecordStatus.responded => AuraSurface.accent,
      RoutedRecordStatus.committed => AuraSurface.accent,
      RoutedRecordStatus.resolved => const Color(0xFF1B8A4C),
    };

    return ListView(
      padding: const EdgeInsets.all(AuraSpace.s16),
      children: [
        // Status header
        Container(
          padding: const EdgeInsets.all(AuraSpace.s14),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AuraRadius.card),
            border: Border.all(color: statusColor.withValues(alpha: 0.30)),
          ),
          child: Row(
            children: [
              Icon(
                switch (record.status) {
                  RoutedRecordStatus.resolved =>
                    Icons.check_circle_outline_rounded,
                  RoutedRecordStatus.pending => Icons.hourglass_empty_rounded,
                  _ => Icons.verified_outlined,
                },
                size: 20,
                color: statusColor,
              ),
              const SizedBox(width: AuraSpace.s10),
              Text(
                record.status.label,
                style: AuraText.body.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AuraSpace.s16),

        // Meta chips
        Wrap(
          spacing: AuraSpace.s8,
          runSpacing: AuraSpace.s8,
          children: [
            if (record.intent != RecordIntent.unknown)
              _MetaChip(
                icon: Icons.chat_bubble_outline_rounded,
                label: record.intent.label,
              ),
            if (record.topic != null)
              _MetaChip(
                icon: Icons.label_outline_rounded,
                label: record.topic!.label,
              ),
            if ((record.participationMode ?? '').isNotEmpty)
              _MetaChip(
                icon: Icons.domain_outlined,
                label: _modeLabel(record.participationMode),
              ),
          ],
        ),
        const SizedBox(height: AuraSpace.s20),

        // Post body
        if ((record.postBody ?? '').trim().isNotEmpty) ...[
          Text(
            'Public post',
            style: AuraText.small.copyWith(
              color: AuraSurface.muted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: AuraSpace.s8),
          Container(
            padding: const EdgeInsets.all(AuraSpace.s14),
            decoration: BoxDecoration(
              color: AuraSurface.card,
              borderRadius: BorderRadius.circular(AuraRadius.card),
              border: Border.all(color: AuraSurface.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.postBody!.trim(),
                  style: AuraText.body.copyWith(
                    color: AuraSurface.ink,
                    height: 1.6,
                  ),
                ),
                if ((record.authorName ?? '').isNotEmpty ||
                    record.createdAt != null) ...[
                  const SizedBox(height: AuraSpace.s12),
                  Row(
                    children: [
                      if ((record.authorName ?? '').isNotEmpty) ...[
                        Text(
                          record.authorName!,
                          style: AuraText.small
                              .copyWith(color: AuraSurface.muted),
                        ),
                        const SizedBox(width: AuraSpace.s8),
                      ],
                      if (record.createdAt != null)
                        Text(
                          formatRelative(record.createdAt!),
                          style: AuraText.micro
                              .copyWith(color: AuraSurface.faint),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AuraSpace.s20),
        ],

        // View original post
        if (record.postId.trim().isNotEmpty)
          OutlinedButton.icon(
            onPressed: () => context.push('/posts/${record.postId}'),
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('View original post'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AuraSurface.muted,
              side: const BorderSide(color: AuraSurface.divider),
            ),
          ),

        // Reply Officially — only for admins/owners
        if (canPublish) ...[
          const SizedBox(height: AuraSpace.s12),
          Consumer(
            builder: (context, ref, _) => FilledButton.icon(
              onPressed: () => _showOfficialReplySheet(context, ref),
              icon: const Icon(Icons.reply_rounded, size: 16),
              label: const Text('Reply Officially'),
              style: FilledButton.styleFrom(
                backgroundColor: AuraSurface.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpace.s16,
                  vertical: AuraSpace.s12,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showOfficialReplySheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AuraSurface.page,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AuraRadius.lg),
        ),
      ),
      builder: (_) => _OfficialReplySheet(
        institutionId: institutionId,
        record: record,
      ),
    );
  }

  String _modeLabel(String? mode) {
    switch ((mode ?? '').toUpperCase()) {
      case 'ACCOUNTABLE':
        return 'Accountable';
      case 'RESPONDING':
        return 'Responding';
      default:
        return mode ?? '';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OFFICIAL REPLY SHEET
// ─────────────────────────────────────────────────────────────────────────────

enum _AccountabilityTag {
  none,
  commitment,
  update,
  resolved;

  String get label {
    switch (this) {
      case _AccountabilityTag.none:
        return 'None';
      case _AccountabilityTag.commitment:
        return 'Commitment';
      case _AccountabilityTag.update:
        return 'Update';
      case _AccountabilityTag.resolved:
        return 'Resolved';
    }
  }

  String? get wire {
    switch (this) {
      case _AccountabilityTag.none:
        return null;
      case _AccountabilityTag.commitment:
        return 'COMMITMENT';
      case _AccountabilityTag.update:
        return 'UPDATE';
      case _AccountabilityTag.resolved:
        return 'RESOLVED';
    }
  }
}

class _OfficialReplySheet extends ConsumerStatefulWidget {
  const _OfficialReplySheet({
    required this.institutionId,
    required this.record,
  });

  final String institutionId;
  final RoutedRecord record;

  @override
  ConsumerState<_OfficialReplySheet> createState() =>
      _OfficialReplySheetState();
}

class _OfficialReplySheetState extends ConsumerState<_OfficialReplySheet> {
  final _bodyCtrl = TextEditingController();
  _AccountabilityTag _tag = _AccountabilityTag.none;
  bool _busy = false;
  String? _error;

  static const int _maxChars = 2000;

  @override
  void dispose() {
    _bodyCtrl.dispose();
    super.dispose();
  }

  String _resolvedTitle() {
    final body = _bodyCtrl.text.trim();
    if (body.isEmpty) return '';
    final firstLine = body
        .split('\n')
        .firstWhere((l) => l.trim().isNotEmpty, orElse: () => '')
        .trim();
    if (firstLine.isEmpty) return body.substring(0, body.length.clamp(0, 80));
    return firstLine.length > 80 ? firstLine.substring(0, 80).trim() : firstLine;
  }

  Future<void> _submit() async {
    final body = _bodyCtrl.text.trim();
    if (body.isEmpty) {
      setState(() => _error = 'Reply body is required.');
      return;
    }
    if (body.length > _maxChars) {
      setState(() => _error = 'Reply must be $_maxChars characters or fewer.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final repo = ref.read(institutionsRepositoryProvider);

      final post = await repo.createInstitutionPost(
        widget.institutionId,
        <String, dynamic>{
          'title': _resolvedTitle(),
          'body': body,
          'visibility': InstitutionPostVisibility.publicAll.wire,
          'distribution': InstitutionPostDistribution.globalEligible.wire,
        },
        status: 'PUBLISHED',
      );

      final tagWire = _tag.wire;
      final publicPostId = widget.record.postId.trim();
      if (tagWire != null && publicPostId.isNotEmpty) {
        await repo.patchAccountabilityTag(
          widget.institutionId,
          post.id,
          tagWire,
          publicPostId,
        );
      }

      ref.invalidate(engagementDetailProvider(
        (widget.institutionId, widget.record.id),
      ));
      ref.invalidate(engagementListProvider(widget.institutionId));
      ref.invalidate(engagementSummaryProvider(widget.institutionId));

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Official reply published'),
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _readError(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  String _readError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final err = data['error'];
      String? msg;
      if (err is Map) {
        msg = err['message']?.toString();
      } else {
        msg = data['message']?.toString();
      }
      if (msg != null && msg.trim().isNotEmpty) return msg.trim();
    }
    return 'Could not publish reply. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(institutionIdentityProvider);
    final instName = identity?.name ?? 'Your institution';
    final charCount = _bodyCtrl.text.length;
    final atLimit = charCount > _maxChars;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AuraSpace.s16,
            AuraSpace.s12,
            AuraSpace.s16,
            AuraSpace.s24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AuraSurface.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AuraSpace.s16),

              // Header
              Row(
                children: [
                  const Icon(
                    Icons.reply_rounded,
                    size: 18,
                    color: AuraSurface.muted,
                  ),
                  const SizedBox(width: AuraSpace.s8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Reply Officially', style: AuraText.headline),
                        Text(
                          'Posting as $instName',
                          style: AuraText.small
                              .copyWith(color: AuraSurface.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AuraSpace.s16),

              // Error
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(AuraSpace.s12),
                  decoration: BoxDecoration(
                    color: AuraSurface.coRose.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AuraRadius.md),
                    border: Border.all(
                      color: AuraSurface.coRose.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          size: 15, color: AuraSurface.coRose),
                      const SizedBox(width: AuraSpace.s8),
                      Expanded(
                        child: Text(
                          _error!,
                          style:
                              AuraText.small.copyWith(color: AuraSurface.coRose),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AuraSpace.s12),
              ],

              // Body field
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'STATEMENT',
                    style: AuraText.micro.copyWith(
                      color: AuraSurface.faint,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                  Text(
                    '$charCount / $_maxChars',
                    style: AuraText.micro.copyWith(
                      color: atLimit ? AuraSurface.coRose : AuraSurface.faint,
                      fontWeight:
                          atLimit ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AuraSpace.s6),
              TextField(
                controller: _bodyCtrl,
                maxLines: 7,
                minLines: 5,
                onChanged: (_) => setState(() {}),
                enabled: !_busy,
                style: AuraText.body,
                decoration: InputDecoration(
                  hintText: 'Write the official institutional response…',
                  hintStyle:
                      AuraText.body.copyWith(color: AuraSurface.faint),
                  filled: true,
                  fillColor: AuraSurface.subtle,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AuraRadius.md),
                    borderSide:
                        const BorderSide(color: AuraSurface.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AuraRadius.md),
                    borderSide:
                        const BorderSide(color: AuraSurface.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AuraRadius.md),
                    borderSide: const BorderSide(
                        color: Color(0xFF0D9488), width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.all(AuraSpace.s14),
                ),
              ),
              const SizedBox(height: AuraSpace.s16),

              // Accountability tag
              Text(
                'ACCOUNTABILITY TAG',
                style: AuraText.micro.copyWith(
                  color: AuraSurface.faint,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: AuraSpace.s8),
              Wrap(
                spacing: AuraSpace.s8,
                runSpacing: AuraSpace.s8,
                children: _AccountabilityTag.values
                    .map((t) => _TagChip(
                          tag: t,
                          selected: _tag == t,
                          onTap: _busy ? null : () => setState(() => _tag = t),
                        ))
                    .toList(),
              ),
              if (_tag != _AccountabilityTag.none) ...[
                const SizedBox(height: AuraSpace.s8),
                Text(
                  _tagHint(_tag),
                  style: AuraText.micro
                      .copyWith(color: AuraSurface.muted, height: 1.45),
                ),
              ],
              const SizedBox(height: AuraSpace.s20),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _busy ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AuraSurface.muted,
                        side: const BorderSide(color: AuraSurface.divider),
                        padding: const EdgeInsets.symmetric(
                          vertical: AuraSpace.s12,
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AuraSpace.s10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _busy || atLimit ? null : _submit,
                      icon: _busy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.publish_rounded, size: 16),
                      label: Text(_busy ? 'Publishing…' : 'Publish reply'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AuraSurface.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: AuraSpace.s12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _tagHint(_AccountabilityTag tag) {
    switch (tag) {
      case _AccountabilityTag.commitment:
        return 'Marks this public record as Committed — your institution has pledged action.';
      case _AccountabilityTag.update:
        return 'Signals progress without advancing to Committed or Resolved.';
      case _AccountabilityTag.resolved:
        return 'Marks this public record as Resolved — the matter has been addressed.';
      default:
        return '';
    }
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.tag,
    required this.selected,
    required this.onTap,
  });

  final _AccountabilityTag tag;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color activeColor = switch (tag) {
      _AccountabilityTag.commitment => AuraSurface.accent,
      _AccountabilityTag.resolved => const Color(0xFF1B8A4C),
      _AccountabilityTag.update => const Color(0xFF7C5CE0),
      _AccountabilityTag.none => AuraSurface.muted,
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AuraRadius.pill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s12,
          vertical: AuraSpace.s8,
        ),
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withValues(alpha: 0.14)
              : AuraSurface.subtle,
          borderRadius: BorderRadius.circular(AuraRadius.pill),
          border: Border.all(
            color: selected
                ? activeColor.withValues(alpha: 0.5)
                : AuraSurface.divider,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          tag.label,
          style: AuraText.small.copyWith(
            color: selected ? activeColor : AuraSurface.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AuraSurface.muted),
          const SizedBox(width: 5),
          Text(
            label,
            style: AuraText.small.copyWith(
              color: AuraSurface.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
