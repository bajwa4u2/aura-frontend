import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../domain/public_visibility.dart';
import 'visibility_selector.dart';

/// Public composer entry — the persistent top-of-public-home bar that
/// invites the user to start a discourse statement.
///
/// Layout:
///   * Avatar · "What's happening on Aura?" hint · `Post` button.
///   * Tapping the body (or the avatar / hint) navigates to the
///     existing `/compose` route, which already handles draft persistence,
///     visibility selection, media, and publish.
///
/// The widget itself does NOT post — the public-layer policy is to
/// always go through the canonical compose flow so we don't fork
/// drafts, validation, or the FCM bridge. The visibility chip on this
/// bar is a *hint* showing the default reach when the user lands in
/// the composer (Public). The compose screen owns the final selection.
class PublicComposer extends ConsumerWidget {
  const PublicComposer({
    super.key,
    this.defaultVisibility = PubVisibility.public,
    this.spaceContext,
  });

  /// Default visibility shown on the bar's hint chip. Inside a space,
  /// callers should pass `PubVisibility.social`.
  final PubVisibility defaultVisibility;

  /// Optional space context — when set, the composer entry navigates
  /// with `surface=space&institutionId=...` style query params so the
  /// downstream compose screen can read it. Phase 1 leaves this
  /// pass-through wired but unused (no public spaces backend yet).
  final String? spaceContext;

  void _open(BuildContext context) {
    // Reuse existing compose flow. No prefill — the compose screen has
    // its own draft hydration via the held-post path.
    context.push('/compose');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authMeDataProvider).valueOrNull;
    final user = (me?['user'] is Map ? me!['user'] : <String, dynamic>{})
        as Map<dynamic, dynamic>;
    final displayName = (user['displayName'] ?? user['name'] ?? '').toString();
    final handle = (user['handle'] ?? '').toString();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(AuraRadius.lg),
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            AuraSpace.s12,
            AuraSpace.s12,
            AuraSpace.s10,
            AuraSpace.s12,
          ),
          decoration: BoxDecoration(
            color: AuraSurface.card,
            borderRadius: BorderRadius.circular(AuraRadius.lg),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: Row(
            children: [
              AuraAvatar(
                name: displayName.isNotEmpty
                    ? displayName
                    : (handle.isNotEmpty ? '@$handle' : 'You'),
                size: 36,
              ),
              const SizedBox(width: AuraSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What’s happening on Aura?',
                      style: AuraText.body.copyWith(
                        color: AuraSurface.muted,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        PubVisibilityChip(value: defaultVisibility),
                        const SizedBox(width: AuraSpace.s6),
                        Text(
                          'Tap to start a statement',
                          style: AuraText.micro.copyWith(
                            color: AuraSurface.faint,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AuraSpace.s10),
              AuraPrimaryButton(
                label: 'Post',
                icon: Icons.edit_rounded,
                onPressed: () => _open(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
