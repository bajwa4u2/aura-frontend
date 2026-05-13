import 'package:flutter/material.dart';

import '../../core/ui/aura_platform_components.dart';
import '../../core/ui/aura_radius.dart';
import '../../core/ui/aura_space.dart';
import '../../core/ui/aura_surface.dart';
import '../../core/ui/aura_text.dart';
import '../posts/presentation/widgets/post_card/post_card_utils.dart';

/// Reusable share action sheet for any public Aura entity.
///
/// Pass the crawler-friendly canonical URL (e.g. the value returned by
/// [canonicalPostUrl] / [canonicalInstitutionPostUrl] /
/// [canonicalAnnouncementUrl]). The sheet exposes three identity-safe
/// share actions:
///
///   * **Copy link** — clipboard, with a snackbar confirmation.
///   * **Share to LinkedIn** — opens LinkedIn's offsite share composer.
///   * **Share to Email** — opens the system mail composer.
///
/// The sheet is intentionally simple: no native iOS/Android share API
/// dependency, no preview rendering. Visibility-gating MUST happen at
/// the call site — this function does not know whether the entity is
/// public. Callers should never invoke it for private / member-only /
/// internal content.
Future<void> showAuraShareSheet(
  BuildContext context, {
  required String shareUrl,
  required String headline,
  String? subtitle,
  String emailSubject = 'Aura',
  String copyMessage = 'Link copied',
  String linkedInFallbackMessage = 'LinkedIn share link copied',
  String emailFallbackMessage = 'Email share link copied',
}) async {
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AuraSurface.card,
    isScrollControlled: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AuraRadius.r14),
      ),
    ),
    builder: (sheetCtx) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AuraSpace.s16,
            AuraSpace.s12,
            AuraSpace.s16,
            AuraSpace.s16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              const SizedBox(height: AuraSpace.s12),
              Text(headline, style: AuraText.subtitle),
              if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                const SizedBox(height: AuraSpace.s4),
                Text(subtitle, style: AuraText.small),
              ],
              const SizedBox(height: AuraSpace.s12),
              SelectableText(
                shareUrl,
                style: AuraText.small.copyWith(
                  fontFamily: 'monospace',
                  color: AuraSurface.muted,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: AuraSpace.s14),
              AuraSecondaryButton(
                label: 'Copy link',
                icon: Icons.link_outlined,
                onPressed: () async {
                  await copyToClipboard(
                    sheetCtx,
                    shareUrl,
                    message: copyMessage,
                  );
                  if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                },
              ),
              const SizedBox(height: AuraSpace.s8),
              AuraSecondaryButton(
                label: 'Share to LinkedIn',
                icon: Icons.work_outline,
                onPressed: () async {
                  await openExternalUrl(
                    sheetCtx,
                    linkedInShareUrl(shareUrl),
                    fallbackCopyMessage: linkedInFallbackMessage,
                  );
                  if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                },
              ),
              const SizedBox(height: AuraSpace.s8),
              AuraSecondaryButton(
                label: 'Share to Email',
                icon: Icons.email_outlined,
                onPressed: () async {
                  await openExternalUrl(
                    sheetCtx,
                    emailShareUrl(shareUrl, subject: emailSubject),
                    fallbackCopyMessage: emailFallbackMessage,
                  );
                  if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
