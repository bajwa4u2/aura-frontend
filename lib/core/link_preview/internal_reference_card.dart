import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../media/aura_attachment_image.dart';
import '../ui/aura_radius.dart';
import '../ui/aura_space.dart';
import '../ui/aura_surface.dart';
import '../ui/aura_text.dart';
import 'link_preview.dart';

const Map<String, String> _kKindLabel = {
  'POST': 'Post',
  'INSTITUTION_POST': 'Institution post',
  'ANNOUNCEMENT': 'Announcement',
  'USER_PROFILE': 'Profile',
  'INSTITUTION_PROFILE': 'Institution',
  'THREAD': 'Thread',
  'SPACE': 'Correspondence',
  'INSTITUTION_SPACE': 'Institution space',
  'DIRECT_THREAD': 'Direct message',
  'MEETING': 'Meeting',
};

const Map<String, IconData> _kKindIcon = {
  'POST': Icons.article_outlined,
  'INSTITUTION_POST': Icons.article_outlined,
  'ANNOUNCEMENT': Icons.campaign_outlined,
  'USER_PROFILE': Icons.person_outline,
  'INSTITUTION_PROFILE': Icons.apartment_outlined,
  'THREAD': Icons.forum_outlined,
  'SPACE': Icons.forum_outlined,
  'INSTITUTION_SPACE': Icons.forum_outlined,
  'DIRECT_THREAD': Icons.mail_outline,
  'MEETING': Icons.video_call_outlined,
};

/// Item 14 — Internal Aura Link / Canonical Reference Hydration.
///
/// The bounded internal-reference preview: canonical-authority-sourced,
/// never OG-scraped, and always re-evaluated against the CURRENT viewer's
/// authorization (never rendered from stale/cached/historical access).
/// Deliberately a sibling of `LinkPreviewCard`, not a shared card type --
/// an internal reference's fields (kind, canonical title, governed route)
/// have no OG-scraping analogue, and collapsing the two would blur exactly
/// the distinction Item 14 exists to enforce: reference != authority.
///
/// Tap always attempts navigation to the reference's route (falling back to
/// the raw source URL's path when the reference layer had no route to
/// offer, e.g. UNSUPPORTED) -- the destination screen's own existing
/// authorization guard is authoritative for what actually renders there.
/// This preview never fabricates information for RESTRICTED/SIGN_IN_REQUIRED
/// outcomes; it names only the object kind (already implicit in the URL
/// itself, not new disclosure) and a generic, non-revealing status label.
class InternalReferenceCard extends StatelessWidget {
  const InternalReferenceCard({
    super.key,
    required this.sourceUrl,
    this.reference,
    this.dense = false,
    this.onRemove,
  });

  final String sourceUrl;
  final InternalReferenceResult? reference;
  final bool dense;
  final VoidCallback? onRemove;

  String? get _navigationRoute {
    final route = (reference?.route ?? '').trim();
    if (route.isNotEmpty) return route;
    final uri = Uri.tryParse(sourceUrl);
    if (uri == null) return null;
    final path = uri.path;
    return path.isEmpty ? null : path;
  }

  @override
  Widget build(BuildContext context) {
    final ref = reference;
    final kind = ref?.kind;
    final label = _kKindLabel[kind] ?? 'Aura link';
    final icon = _kKindIcon[kind] ?? Icons.link;

    final title = (ref?.title ?? '').trim();
    final subtitle = (ref?.subtitle ?? '').trim();
    final imageUrl = (ref?.imageUrl ?? '').trim();
    final isReady = ref?.isReady ?? false;

    String statusText;
    if (ref == null) {
      statusText = 'Loading…';
    } else if (isReady) {
      statusText = title.isNotEmpty ? title : label;
    } else if (ref.outcome == 'SIGN_IN_REQUIRED') {
      statusText = 'Sign in to view this $label';
    } else if (ref.outcome == 'RESTRICTED') {
      statusText = 'This $label isn\'t available to you';
    } else {
      statusText = label;
    }

    final route = _navigationRoute;

    return InkWell(
      onTap: route == null ? null : () => GoRouter.of(context).push(route),
      borderRadius: BorderRadius.circular(AuraRadius.md),
      child: Container(
        decoration: BoxDecoration(
          color: AuraSurface.card,
          border: Border.all(color: AuraSurface.divider),
          borderRadius: BorderRadius.circular(AuraRadius.md),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isReady && imageUrl.isNotEmpty)
              SizedBox(
                width: dense ? 72 : 96,
                height: dense ? 72 : 96,
                child: AuraAttachmentImage(
                  url: imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_) => const SizedBox.shrink(),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(AuraSpace.s10),
                child: Icon(icon, size: 20, color: AuraSurface.faint),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AuraSpace.s10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: AuraText.micro.copyWith(
                        color: AuraSurface.faint,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: AuraSpace.s4),
                    Text(
                      statusText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: isReady
                          ? AuraText.small.copyWith(fontWeight: FontWeight.w700)
                          : AuraText.small.copyWith(color: AuraSurface.muted),
                    ),
                    if (isReady && subtitle.isNotEmpty) ...[
                      const SizedBox(height: AuraSpace.s4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AuraText.micro.copyWith(color: AuraSurface.muted),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (onRemove != null)
              Padding(
                padding: const EdgeInsets.all(AuraSpace.s6),
                child: InkWell(
                  onTap: onRemove,
                  child: const Padding(
                    padding: EdgeInsets.all(AuraSpace.s4),
                    child: Icon(Icons.close, size: 16, color: AuraSurface.muted),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
