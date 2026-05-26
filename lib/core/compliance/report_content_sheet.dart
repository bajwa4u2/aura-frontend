import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/aura_radius.dart';
import '../ui/aura_space.dart';
import '../ui/aura_surface.dart';
import '../ui/aura_text.dart';
import 'report_repository.dart';

/// Apple Store §1.2 UGC compliance — generic report sheet for
/// user-generated content surfaces.
///
/// Usage:
///   ```dart
///   await ReportContentSheet.show(
///     context,
///     targetType: ReportTargetType.post,
///     targetId: post.id,
///     contextLabel: 'this post',
///   );
///   ```
///
/// The sheet:
///   • shows the standard six reason categories Apple expects;
///   • collects optional details ≤ 500 chars;
///   • submits to `/v1/moderation/reports`;
///   • shows a confirmation snackbar on success;
///   • surfaces errors as inline text without dismissing.
///
/// The sheet is generic — caller picks `ReportTargetType` and passes
/// the target id (post, reply, user, message, etc.). The backend
/// already accepts those wire values.
class ReportContentSheet extends ConsumerStatefulWidget {
  const ReportContentSheet({
    super.key,
    required this.targetType,
    required this.targetId,
    this.contextLabel,
  });

  final ReportTargetType targetType;
  final String targetId;

  /// Short human label of what's being reported (used in the sheet
  /// title — e.g. "this post", "this reply", "this user").
  final String? contextLabel;

  static Future<bool?> show(
    BuildContext context, {
    required ReportTargetType targetType,
    required String targetId,
    String? contextLabel,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AuraSurface.page,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AuraRadius.lg)),
      ),
      builder: (_) => ReportContentSheet(
        targetType: targetType,
        targetId: targetId,
        contextLabel: contextLabel,
      ),
    );
  }

  @override
  ConsumerState<ReportContentSheet> createState() => _ReportContentSheetState();
}

class _ReportContentSheetState extends ConsumerState<ReportContentSheet> {
  ReportReason? _reason;
  final _details = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null) {
      setState(() => _error = 'Please choose a reason.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(reportRepositoryProvider).create(
            targetType: widget.targetType,
            targetId: widget.targetId,
            reason: reason,
            details: _details.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Report submitted. A moderator will review within 24 hours.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not submit. Please check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final ctx = widget.contextLabel ?? 'this content';
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AuraSpace.s20,
            AuraSpace.s16,
            AuraSpace.s20,
            AuraSpace.s20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(
                  bottom: AuraSpace.s12,
                ),
                decoration: BoxDecoration(
                  color: AuraSurface.faint,
                  borderRadius: BorderRadius.circular(AuraRadius.sm),
                ),
              ),
              Text(
                'Report $ctx',
                style: AuraText.title.copyWith(fontSize: 22, height: 1.2),
              ),
              const SizedBox(height: AuraSpace.s4),
              Text(
                'Reports are reviewed by a human moderator within 24 hours. '
                'Offending content may be removed and offending users may be '
                'suspended.',
                style: AuraText.small.copyWith(
                  color: AuraSurface.muted,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: AuraSpace.s16),
              for (final r in ReportReason.values)
                RadioListTile<ReportReason>(
                  contentPadding: EdgeInsets.zero,
                  value: r,
                  groupValue: _reason,
                  title: Text(r.label, style: AuraText.body),
                  onChanged: _busy ? null : (v) => setState(() => _reason = v),
                ),
              const SizedBox(height: AuraSpace.s12),
              TextField(
                controller: _details,
                enabled: !_busy,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Details (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AuraSpace.s8),
                Text(
                  _error!,
                  style: AuraText.small.copyWith(color: AuraSurface.dangerInk),
                ),
              ],
              const SizedBox(height: AuraSpace.s12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AuraSpace.s12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : _submit,
                      child:
                          Text(_busy ? 'Submitting…' : 'Submit report'),
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
}
