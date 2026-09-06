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
import '../../../core/identity/person_identity_model.dart';

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
    // F053/F116 — one reader. The three-way avatar alias chain here was a
    // private copy of what the canonical model already resolves.
    final person = AuraPersonIdentity.fromJson(me);
    final displayName = person.displayName;
    final handle = person.handle;
    final avatarUrl = person.avatarUrl ?? '';

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
                imageUrl: avatarUrl.isEmpty ? null : avatarUrl,
                size: 36,
              ),
              const SizedBox(width: AuraSpace.s12),
              // THE PROMPT IS A FIELD, BECAUSE THAT IS WHAT IT IS.
              //
              // This was two lines of muted label floating in an `Expanded`,
              // with the Post button pinned to the far end of the same row.
              // At a phone's width that reads as a composer. At the desktop
              // feed measure it is a 1290 px bar holding one short sentence
              // at the leading edge and a button roughly 800 px away at the
              // trailing one, with nothing in between: the emptiest object
              // on member Home, and it got emptier when the work column was
              // widened. Founder-observed.
              //
              // Nothing here needed to be smaller. What was missing was a
              // reason for the width to exist. A field fills it honestly,
              // says what tapping does before you tap, and puts the action
              // against the thing it acts on.
              //
              // The whole card remains one tap target, so the button is a
              // second door into the same room rather than the only one.
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AuraSpace.s12,
                    vertical: AuraSpace.s10,
                  ),
                  decoration: BoxDecoration(
                    color: AuraSurface.page,
                    borderRadius: BorderRadius.circular(AuraRadius.md),
                    border: Border.all(color: AuraSurface.divider),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'What’s happening on Aura?',
                          style: AuraText.body.copyWith(
                            color: AuraSurface.muted,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Visibility rides INSIDE the field, at its trailing
                      // edge, because it is a property of what is about to be
                      // written rather than a caption about the composer. It
                      // also replaces "Tap to start a statement", which
                      // explained the affordance the field now shows.
                      const SizedBox(width: AuraSpace.s8),
                      PubVisibilityChip(value: defaultVisibility),
                    ],
                  ),
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
