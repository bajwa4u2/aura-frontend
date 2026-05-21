import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/utils/relative_time.dart';
import '../../../shared/identity/aura_identity_badge.dart';
import '../../feed/domain/feed_item.dart';
import '../domain/accountability_tag.dart';
import '../domain/monetization_kind.dart';
import 'institution_action_sheet.dart';
import 'mention_text.dart';
import 'monetization_label.dart';

/// One reply in the discourse thread.
///
/// Visual rules:
///   * **Default reply** — calm subtle card.
///   * **Official institution response** — same skeleton, plus a left
///     accent border and a small "Official response" eyebrow. Reads
///     inline with member replies (the discussion stays one stream).
///   * **Non-official replies under an official parent** — slightly
///     dimmed (opacity 0.85) so institutional voice is dominant. We
///     keep readability intact.
class ReplyUnit extends ConsumerWidget {
  const ReplyUnit({
    super.key,
    required this.reply,
    this.parentIsOfficial = false,
    this.children = const [],
    this.depth = 0,
  });

  final FeedReply reply;

  /// True when this reply belongs to an official institution post — the
  /// thread screen passes this so non-official replies dim correctly.
  final bool parentIsOfficial;

  /// Public-UX Phase 3 — nested replies-of-this-reply. Rendered indented
  /// underneath the body up to a hard depth cap of 2 (the depth-2 child
  /// is rendered, but its `children` are flattened to siblings to avoid
  /// runaway indentation).
  final List<FeedReply> children;
  final int depth;

  static const int _kMaxDepth = 2;

  bool get _isOfficial {
    final ctx = reply.author.context;
    if (ctx == null) return false;
    return ctx.type == FeedIdentityContextType.officialInstitution;
  }

  InsAccountabilityTag? get _accountabilityTag =>
      InsAccountabilityTagX.fromWire(reply.accountabilityTagWire);

  MonetizationKind? get _paidLabel =>
      MonetizationKindX.fromPaidActionWire(reply.paidActionWire);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = reply.author.context;
    final hasBadge = ctx != null && ctx.isMeaningful;
    final initial = reply.author.displayName.trim().isNotEmpty
        ? reply.author.displayName.trim()[0].toUpperCase()
        : (reply.author.handle.isNotEmpty
            ? reply.author.handle[0].toUpperCase()
            : '?');

    // Public-UX Phase 4 — render the institution-action kebab only
    // when (a) the reply is institutional, (b) we know its
    // institutionId from the identity context, and (c) the current
    // viewer is an admin/owner of that same institution. This is
    // conservative: a viewer admin'ing a *different* institution
    // won't see the kebab on someone else's reply.
    final replyInstitutionId = ctx?.institutionId?.trim() ?? '';
    final viewerIdentity = ref.watch(institutionIdentityProvider);
    final canManage = _isOfficial &&
        replyInstitutionId.isNotEmpty &&
        viewerIdentity != null &&
        viewerIdentity.id == replyInstitutionId &&
        viewerIdentity.isAdmin;

    final card = Container(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.s12,
        AuraSpace.s12,
        AuraSpace.s12,
        AuraSpace.s12,
      ),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.md),
        border: Border(
          top: const BorderSide(color: AuraSurface.divider),
          right: const BorderSide(color: AuraSurface.divider),
          bottom: const BorderSide(color: AuraSurface.divider),
          left: BorderSide(
            color: _isOfficial
                ? AuraSurface.accent.withValues(alpha: 0.6)
                : AuraSurface.divider,
            width: _isOfficial ? 2.5 : 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isOfficial || _accountabilityTag != null || _paidLabel != null) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (_isOfficial)
                  const MonetizationLabel(
                    kind: MonetizationKind.officialResponse,
                    compact: true,
                  ),
                if (_paidLabel != null)
                  MonetizationLabel(kind: _paidLabel!, compact: true),
                if (_accountabilityTag != null)
                  _AccountabilityChip(tag: _accountabilityTag!),
              ],
            ),
            const SizedBox(height: AuraSpace.s8),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AuraSurface.accentSoft,
                  shape: BoxShape.circle,
                  border: Border.all(color: AuraSurface.divider),
                ),
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: AuraText.small.copyWith(
                    color: AuraSurface.accentText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: AuraSpace.s10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            reply.author.displayName.isNotEmpty
                                ? reply.author.displayName
                                : (reply.author.handle.isNotEmpty
                                    ? '@${reply.author.handle}'
                                    : 'Unknown'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AuraText.small.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (hasBadge) ...[
                          const SizedBox(width: AuraSpace.s6),
                          Flexible(
                            child: AuraIdentityBadge(
                              context: ctx,
                              mode: AuraIdentityBadgeMode.replyPreview,
                            ),
                          ),
                        ],
                        if (reply.createdAt != null) ...[
                          const SizedBox(width: AuraSpace.s6),
                          Text(
                            '· ${formatRelative(reply.createdAt!)}',
                            style: AuraText.micro.copyWith(
                              color: AuraSurface.faint,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (canManage) ...[
                const SizedBox(width: AuraSpace.s6),
                InkWell(
                  borderRadius: BorderRadius.circular(AuraRadius.pill),
                  onTap: () => showInstitutionActionSheet(
                    context: context,
                    institutionId: replyInstitutionId,
                    postId: reply.id,
                    currentTag: _accountabilityTag,
                    currentPaidLabel: _paidLabel,
                    onApplied: () {},
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.more_vert_rounded,
                      size: 16,
                      color: AuraSurface.muted,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (reply.body.trim().isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s8),
            // Phase 6.1 — render @handles as accent-tinted, tappable
            // spans linking to /u/:handle. SelectionArea adds drag/
            // long-press text selection without disturbing those
            // mention tap recognizers.
            SelectionArea(
              child: MentionText(
                reply.body,
                style: AuraText.body.copyWith(
                  color: AuraSurface.ink,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    // Public-UX Phase 3 — render nested children up to the depth cap.
    // At depth 0 (top-level reply), children render indented beneath
    // the body. At depth 1, children render flush so we don't run
    // into runaway indentation on small screens.
    final hasChildren = children.isNotEmpty && depth < _kMaxDepth;
    final wrapped = parentIsOfficial && !_isOfficial
        ? Opacity(opacity: 0.85, child: card)
        : card;

    if (!hasChildren) return wrapped;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        wrapped,
        const SizedBox(height: AuraSpace.s8),
        Padding(
          padding: EdgeInsets.only(
            left: depth == 0 ? AuraSpace.s24 : 0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                ReplyUnit(
                  reply: children[i],
                  parentIsOfficial: _isOfficial || parentIsOfficial,
                  depth: depth + 1,
                ),
                if (i < children.length - 1)
                  const SizedBox(height: AuraSpace.s8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Accountability tag chip rendered next to the OFFICIAL label on
/// institution replies. The three tags signal lifecycle stages of an
/// institutional commitment (commit → update → resolve) so readers
/// can see whether the discussion produced an outcome.
class _AccountabilityChip extends StatelessWidget {
  const _AccountabilityChip({required this.tag});

  final InsAccountabilityTag tag;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color ink, Color border, IconData icon) = switch (tag) {
      InsAccountabilityTag.commitment => (
        AuraSurface.accentSoft,
        AuraSurface.accentText,
        AuraSurface.accent.withValues(alpha: 0.4),
        Icons.handshake_outlined,
      ),
      InsAccountabilityTag.update => (
        AuraSurface.warnBg,
        AuraSurface.warnInk,
        AuraSurface.warnInk.withValues(alpha: 0.35),
        Icons.update_rounded,
      ),
      InsAccountabilityTag.resolved => (
        AuraSurface.goodBg,
        AuraSurface.goodInk,
        AuraSurface.goodInk.withValues(alpha: 0.4),
        Icons.check_circle_outline_rounded,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: ink),
          const SizedBox(width: 4),
          Text(
            tag.label.toUpperCase(),
            style: AuraText.micro.copyWith(
              color: ink,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
