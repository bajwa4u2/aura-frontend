import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../admin/domain/operator_entry.dart';
import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/navigation/navigation_authority.dart';
import '../../../core/ui/aura_design_system.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/responsive/adaptive_card_grid.dart';

/// CREATE — the fourth PRIMARY (founder-observed correction, 2026-08-16).
///
/// FROZEN CREATE INTENT VOCABULARY (founder §5 resolution, 2026-08-16):
/// MESSAGE · POST · ARTICLE · contextual ANNOUNCEMENT.
/// "Message" is the human intention; "Conversation" is the durable object
/// opened underneath it. No "Write" umbrella (Post ≠ Article), no Invitation,
/// no Institution onboarding.
///
/// CREATE IS A PERSISTENT PRIMARY HUMAN INTENTION: a person may arrive in Aura
/// with "I want to create something", before any contextual home. This is that
/// intention's destination. Frozen rules:
///  * GLOBAL CREATE and CONTEXTUAL CREATE are complementary — every card here
///    leads into the SAME canonical lifecycle its contextual entry uses.
///  * Create exposes HUMAN CREATION INTENTIONS — never backend module names,
///    never a forest of disabled actions.
///  * Institution meeting creation stays CONTEXTUAL-ONLY in the institution
///    workspace; global Create does not manufacture an institution picker.
///
/// ─────────────────────────────────────────────────────────────────────────
/// RECONSTRUCTED 2026-08-25
/// ─────────────────────────────────────────────────────────────────────────
///
/// The intentions did not change. Four things about the surface did, each for
/// a defect found by using it:
///
///  1. **A creation entered from here now returns here.** The cards navigated
///     with `go`, which REPLACES the stack — so cancelling the post composer
///     landed on `/home` and the person's journey was erased. Verified live
///     before the change. They `push` now, so the governed Cancel unwinds to
///     Create, exactly as the return-path chapter intends for a child entry.
///
///  2. **Every outcome is reachable.** Four sections of one card each made a
///     four-choice surface taller than the viewport, putting Message — a
///     primary human intention — below the fold on a laptop. One grid; the
///     canonical `AdaptiveCardGrid`, pinned to grid mode because its narrow
///     fallback is a horizontal rail and a rail hides choices off-screen,
///     which is the same defect wearing different clothes.
///
///  3. **Authority resolves honestly.** Institution access was read with
///     `orElse: none`, so "still finding out" rendered as "you cannot" and the
///     Announcement card appeared late, unannounced. While it resolves the
///     surface says so.
///
///  4. **The copy says what Aura is for.** The hero listed the same four
///     things the cards below it already list. Public-first doctrine: people
///     come to Aura to say something that stands up, not to manage an
///     institution and not to feed a timeline.
class CreateHubScreen extends ConsumerWidget {
  const CreateHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final institutionAsync = ref.watch(institutionAccessProvider);

    // UNKNOWN IS NOT "NO". The previous reading collapsed loading into
    // `none`, which is the shape of every authority defect this product has
    // had: a surface that answers before it knows.
    final resolving = institutionAsync.isLoading && !institutionAsync.hasValue;
    final institution = institutionAsync.valueOrNull ??
        const InstitutionAccess(state: InstitutionAccessState.none);

    // The institution's own name, from the canonical projection rather than
    // a label invented here.
    final institutionName =
        (institution.institution?['name'] ?? '').toString().trim();

    // WHO MAY ANNOUNCE FOR AURA, ASKED RATHER THAN REMEMBERED.
    //
    // This read `isAdmin` — the DISPLAY cache above, which is only populated
    // by a probe that fires on entering /admin. A platform admin who had not
    // opened the admin workspace this session therefore looked like a
    // non-admin here, and `openAnnouncement` silently routed them to
    // `?scope=institution`: a drafting-only surface whose Publish button is
    // disabled. No request ever reached the backend, so nothing appeared in
    // the audit log either — the button simply did nothing.
    //
    // `shell_header_tools.dart` already learned this and moved off the same
    // cache for the operator entrance, in its own words because "an operator
    // could not see the door until they had already found it by typing the
    // address". Create asks the same small, audit-safe question.
    final canAnnounceAsPlatform = ref.watch(canEnterOperatorConsoleProvider);
    final canAnnounceAsInstitution =
        institution.state == InstitutionAccessState.authorizedSpeaker;
    final canAnnounce = canAnnounceAsPlatform || canAnnounceAsInstitution;

    void openAnnouncement(BuildContext ctx) {
      if (canAnnounceAsPlatform && canAnnounceAsInstitution) {
        // The one place Create asks AS WHOM, because it is the one place a
        // genuine choice exists (C1: acting identity is per-act).
        showDialog<void>(
          context: ctx,
          builder: (dialogCtx) => AlertDialog(
            backgroundColor: AuraSurface.card,
            title: const Text('Publish this notice as'),
            content: Text(
              'An announcement carries the authority of whoever publishes it.',
              style: AuraText.small.copyWith(color: AuraSurface.muted),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogCtx).pop();
                  ctx.push('/announcements/create?scope=institution');
                },
                child: Text(institutionName.isEmpty
                    ? 'Your institution'
                    : institutionName),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(dialogCtx).pop();
                  ctx.push('/announcements/create');
                },
                child: const Text('Aura'),
              ),
            ],
          ),
        );
        return;
      }
      ctx.push(canAnnounceAsPlatform
          ? '/announcements/create'
          : '/announcements/create?scope=institution');
    }

    return AuraScaffold(
      title: 'Create',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AuraSpace.s16,
          AuraSpace.s4,
          AuraSpace.s16,
          AuraSpace.s32,
        ),
        children: [
          Text(
            'Say something that stands up — to a person, to the public, or on '
            'the record.',
            style: AuraText.body.copyWith(
              color: AuraSurface.muted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AuraSpace.s20),
          AdaptiveCardGrid(
            // Pinned to grid mode. The default narrow fallback is a
            // horizontal rail, and a landing surface whose whole job is
            // "here is what you can create" may not put a choice off-screen.
            breakpoint: 0,
            minCardsPerRow: 1,
            maxCardsPerRow: 3,
            cardWidth: 260,
            gap: AuraSpace.s12,
            cards: [
              // SHARE IS FIRST BECAUSE IT IS THE MOST COMMON INTENTION AND
              // THE MOST TIME-SENSITIVE. Somebody holding a photograph they
              // want to send is not browsing a menu of ways to write.
              //
              // It is a card here rather than a navigation destination on
              // purpose: this hub already asks "what do you want to make?",
              // and Share is a new answer to that question, not a new place.
              _CreateCard(
                title: 'Share',
                subtitle: 'A photo or video, straight to a feed or a person.',
                icon: Icons.camera_alt_outlined,
                onTap: (ctx) => ctx.push('/share'),
              ),
              _CreateCard(
                title: 'Message',
                subtitle: 'Talk to someone. Add more people whenever you like.',
                icon: Icons.forum_outlined,
                onTap: (ctx) =>
                    ctx.push(NavigationAuthority.newConversationRoute),
              ),
              _CreateCard(
                title: 'Post',
                subtitle: 'Say something publicly, with media and topics.',
                icon: Icons.edit_note_rounded,
                onTap: (ctx) => ctx.push('/compose'),
              ),
              _CreateCard(
                title: 'Article',
                subtitle: 'Longer, authored writing that lasts.',
                icon: Icons.article_outlined,
                onTap: (ctx) => ctx.push('/articles/write'),
              ),
              if (canAnnounce)
                _CreateCard(
                  title: 'Announcement',
                  subtitle: canAnnounceAsInstitution &&
                          !canAnnounceAsPlatform &&
                          institutionName.isNotEmpty
                      ? 'An official notice from $institutionName.'
                      : 'An official notice, published with authority.',
                  icon: Icons.campaign_outlined,
                  onTap: openAnnouncement,
                )
              else if (resolving)
                // Honest, and brief. Saying nothing here would state that
                // these three are all there is, before that is known.
                const _PendingCard(),
            ],
          ),
        ],
      ),
    );
  }
}

/// One creation outcome. The whole card is the affordance — the old "Open →"
/// row restated what tapping a card already means.
class _CreateCard extends StatelessWidget {
  const _CreateCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final void Function(BuildContext context) onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(context),
          borderRadius: BorderRadius.circular(AuraRadius.card),
          child: Container(
            padding: const EdgeInsets.all(AuraSpace.s16),
            decoration: BoxDecoration(
              color: AuraSurface.card,
              borderRadius: BorderRadius.circular(AuraRadius.card),
              border: Border.all(color: AuraSurface.divider),
              boxShadow: AuraShadows.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AuraSurface.accentSoft,
                    borderRadius: BorderRadius.circular(AuraRadius.r10),
                    border: Border.all(
                      color: AuraSurface.accent.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(icon,
                      size: AuraIconSize.sm, color: AuraSurface.accentText),
                ),
                const SizedBox(height: AuraSpace.s12),
                Text(
                  title,
                  style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AuraSpace.s4),
                Text(
                  subtitle,
                  style: AuraText.small
                      .copyWith(color: AuraSurface.muted, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AuraSpace.s12),
          Expanded(
            child: Text(
              'Checking what else you can publish',
              style: AuraText.small.copyWith(color: AuraSurface.muted),
            ),
          ),
        ],
      ),
    );
  }
}
