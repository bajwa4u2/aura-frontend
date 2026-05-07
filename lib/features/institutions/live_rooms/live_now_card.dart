/// Shared "LIVE NOW" card used in three places:
///   1. Institution explore feed (Public/Member/Internal tabs).
///   2. Global Public feed at the top of `PublicHomeScreen`.
///   3. Member home feed at the top of `MemberHomeScreen`.
///
/// The widget is presentation-only: callers supply a normalized
/// [LiveNowCardData] payload built either from the institution
/// `activeSession` map (per-institution surface) or from a
/// `LiveNowDiscoveryEntry` (global surface). The widget itself never
/// fetches data.
///
/// Tap navigates to `/realtime/:id` with the same query-param contract
/// the rest of the workspace uses, so the in-session header lights up
/// immediately on join.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import 'global_live_discovery.dart';
import 'institution_session_meta.dart';

/// Inputs the card needs. Two factory paths cover the institution
/// active-session map (legacy, untyped) and the global discovery
/// entry (typed) so a single widget handles both surfaces.
class LiveNowCardData {
  const LiveNowCardData({
    required this.sessionId,
    required this.eyebrow,
    required this.title,
    required this.hostName,
    required this.isVerifiedHost,
    required this.returnTo,
    this.meta,
  });

  final String sessionId;
  final String eyebrow;
  final String title;

  /// Empty when the host institution name is unknown — the card hides
  /// the trust line in that case.
  final String hostName;

  final bool isVerifiedHost;

  /// Route to return to after the call ends — preserves "where the user
  /// was browsing" so they don't get teleported.
  final String returnTo;

  /// Cached session meta used to build the realtime URL query params.
  final InsSessionMeta? meta;

  factory LiveNowCardData.fromInstitution({
    required Map<String, dynamic> session,
    required String institutionId,
    required String hostName,
    required bool isVerifiedHost,
    InsSessionMeta? meta,
  }) {
    final id = (session['id'] ?? '').toString();
    final eyebrow = meta != null
        ? '${meta.type.label.toUpperCase()} • ${meta.audience.label}'
        : 'LIVE SESSION';
    final title = (meta?.title?.trim().isNotEmpty ?? false)
        ? meta!.title!.trim()
        : (meta != null
            ? meta.type.label
            : ((session['title'] ?? '').toString().trim().isNotEmpty
                ? (session['title'] ?? '').toString().trim()
                : 'Live session'));
    return LiveNowCardData(
      sessionId: id,
      eyebrow: eyebrow,
      title: title,
      hostName: hostName,
      isVerifiedHost: isVerifiedHost,
      returnTo: '/institution/$institutionId/explore',
      meta: meta,
    );
  }

  factory LiveNowCardData.fromDiscovery({
    required LiveNowDiscoveryEntry entry,
    required String returnTo,
    String hostName = '',
    bool isVerifiedHost = false,
  }) {
    return LiveNowCardData(
      sessionId: entry.sessionId,
      eyebrow: entry.eyebrow,
      title: entry.displayTitle,
      hostName: hostName,
      isVerifiedHost: isVerifiedHost,
      returnTo: returnTo,
      meta: entry.meta,
    );
  }
}

class LiveNowCard extends StatelessWidget {
  const LiveNowCard({super.key, required this.data});

  final LiveNowCardData data;

  void _join(BuildContext context) {
    if (data.sessionId.isEmpty) return;
    final m = data.meta;
    final qp = <String, String>{
      'action': 'join',
      'returnTo': data.returnTo,
      if (m != null) 'sessionType': m.type.wire,
      if (m != null) 'sessionAudience': m.audience.wire,
      if (m != null && (m.title?.trim().isNotEmpty ?? false))
        'sessionTitle': m.title!.trim(),
    };
    final qs = qp.entries
        .map((e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    context.push('/realtime/${data.sessionId}?$qs');
  }

  @override
  Widget build(BuildContext context) {
    final hostName = data.hostName.trim();
    return InkWell(
      onTap: () => _join(context),
      borderRadius: BorderRadius.circular(AuraRadius.lg),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AuraSpace.s14,
          AuraSpace.s12,
          AuraSpace.s12,
          AuraSpace.s12,
        ),
        decoration: BoxDecoration(
          color: AuraSurface.goodBg.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(AuraRadius.lg),
          border: Border.all(
            color: AuraSurface.goodInk.withValues(alpha: 0.45),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AuraSurface.goodInk,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AuraSpace.s10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'LIVE NOW',
                        style: AuraText.micro.copyWith(
                          color: AuraSurface.goodInk,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.9,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '· ${data.eyebrow}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AuraText.micro.copyWith(
                            color: AuraSurface.muted,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AuraText.body.copyWith(
                      color: AuraSurface.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (hostName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.apartment_rounded,
                          size: 11,
                          color: AuraSurface.faint,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Hosted by $hostName',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AuraText.micro.copyWith(
                              color: AuraSurface.faint,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (data.isVerifiedHost) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified_rounded,
                            size: 11,
                            color: AuraSurface.accentText,
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AuraSpace.s10),
            AuraPrimaryButton(
              label: 'Join',
              icon: Icons.call_rounded,
              onPressed: () => _join(context),
            ),
          ],
        ),
      ),
    );
  }
}
