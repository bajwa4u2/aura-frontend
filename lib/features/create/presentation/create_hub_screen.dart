import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/admin_access_provider.dart';
import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/navigation/navigation_authority.dart';
import '../../../core/ui/aura_design_system.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';

/// CREATE — the fourth PRIMARY (founder-observed correction, 2026-08-16).
///
/// FROZEN CREATE INTENT VOCABULARY (founder §5 resolution, 2026-08-16):
/// MESSAGE · POST · ARTICLE (when real) · contextual ANNOUNCEMENT.
/// "Message" is the human intention; "Conversation" is the durable object
/// opened underneath it. No "Write" umbrella (Post ≠ future Article), no
/// Invitation, no Institution onboarding, no Article until real.
///
/// CREATE IS A PERSISTENT PRIMARY HUMAN INTENTION: a member may arrive in
/// Aura with "I want to create something", before any contextual home.
/// This hub is that intention's destination. Frozen rules:
///  * GLOBAL CREATE and CONTEXTUAL CREATE are complementary — every card
///    here leads into the SAME canonical lifecycle its contextual entry
///    uses (one lifecycle, multiple legitimate entry points).
///  * Create exposes HUMAN CREATION INTENTIONS — never backend module
///    names, never a forest of disabled actions. Options are current,
///    truthful, capability-aware, and acting-identity-aware (C1: the
///    lifecycle asks AS WHOM only where a genuine choice exists — e.g.
///    the announcement scope choice below).
///  * Article creation is NOT exposed — Long-Form Publishing does not
///    exist yet (founder-owned roadmap gap); no dead actions.
///  * Institution meeting creation stays CONTEXTUAL-ONLY in the
///    institution workspace — the institution owns the meeting
///    lifecycle; global Create does not manufacture an institution
///    picker for it.
///
/// Capability matrix:
///   canAnnounceAsPlatform:    appAdmin.isAdmin
///   canAnnounceAsInstitution: institutionAccess.state == authorizedSpeaker
///   canAnnounce:              either of the above
class CreateHubScreen extends ConsumerWidget {
  const CreateHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Display-only admin signal — never triggers a probe from /create.
    // First-time admins won't see the announcement-as-platform / claim-audit
    // cards until they have visited /admin once and the cache has been
    // populated. That's the explicit trade-off documented in the admin
    // route gating contract: avoid probing every signed-in user.
    final isAdmin = ref.watch(appAdminCachedDisplayProvider);
    final institutionAsync = ref.watch(institutionAccessProvider);

    final institution = institutionAsync.maybeWhen(
      data: (v) => v,
      orElse: () => const InstitutionAccess(state: InstitutionAccessState.none),
    );

    final canAnnounceAsPlatform = isAdmin;
    final canAnnounceAsInstitution =
        institution.state == InstitutionAccessState.authorizedSpeaker;
    final canAnnounce = canAnnounceAsPlatform || canAnnounceAsInstitution;
    // Claim audit is an analysis tool, not an act of creation — it now lives
    // outside the Create hub (reachable at /ai/claim-audit). Create stays
    // scoped to things you make: writing, messages, announcements.
    final hasAuthoritySection = canAnnounce;

    void onAnnouncementTap(BuildContext ctx) {
      if (canAnnounceAsPlatform && canAnnounceAsInstitution) {
        showDialog<void>(
          context: ctx,
          builder: (dialogCtx) => AlertDialog(
            title: const Text('Announcement scope'),
            content: const Text(
              'Choose where this announcement will be published.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogCtx).pop();
                  ctx.go('/announcements/create');
                },
                child: const Text('Platform'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(dialogCtx).pop();
                  ctx.go('/announcements/create?scope=institution');
                },
                child: const Text('Institution'),
              ),
            ],
          ),
        );
      } else if (canAnnounceAsPlatform) {
        ctx.go('/announcements/create');
      } else {
        ctx.go('/announcements/create?scope=institution');
      }
    }

    return AuraScaffold(
      showHeader: false,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.s16,
              AuraSpace.s20,
              AuraSpace.s16,
              AuraSpace.s32,
            ),
            children: [
              _CreateHero(),
              const SizedBox(height: AuraSpace.s28),
              _CreateSection(
                title: 'Say something',
                items: [
                  _CreateActionData(
                    title: 'Post',
                    subtitle:
                        'Say something on the public record — media, topics, '
                        'and audience as you go.',
                    icon: Icons.edit_note_rounded,
                    route: '/compose',
                  ),
                ],
              ),
              const SizedBox(height: AuraSpace.s20),
              _CreateSection(
                title: 'Talk to someone',
                items: [
                  _CreateActionData(
                    title: 'Message',
                    subtitle:
                        'Pick a person and start talking — add people later.',
                    icon: Icons.forum_outlined,
                    route: NavigationAuthority.newConversationRoute,
                  ),
                ],
              ),

              if (hasAuthoritySection) ...[
                const SizedBox(height: AuraSpace.s20),
                _CreateSection(
                  title: 'Authority',
                  items: [
                    if (canAnnounce)
                      _CreateActionData(
                        title: 'Announcement',
                        subtitle:
                            'Publish an official institution or platform notice.',
                        icon: Icons.campaign_outlined,
                        onTap: onAnnouncementTap,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.s20,
        AuraSpace.s24,
        AuraSpace.s20,
        AuraSpace.s24,
      ),
      decoration: BoxDecoration(
        gradient: AuraGradients.card,
        borderRadius: BorderRadius.circular(AuraRadius.xl),
        border: Border.all(color: AuraSurface.divider),
        boxShadow: AuraShadows.card,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Create', style: AuraText.headline),
                const SizedBox(height: AuraSpace.s8),
                Text(
                  'Start something — a message, a post, or an official notice.',
                  style: AuraText.body.copyWith(
                    color: AuraSurface.muted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AuraGradients.accent,
              borderRadius: BorderRadius.circular(AuraRadius.r14),
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
          ),
        ],
      ),
    );
  }
}

class _CreateSection extends StatelessWidget {
  const _CreateSection({required this.title, required this.items});

  final String title;
  final List<_CreateActionData> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AuraSpace.s4,
            bottom: AuraSpace.s12,
          ),
          child: Text(
            title,
            style: AuraText.label.copyWith(
              color: AuraSurface.faint,
              letterSpacing: 0.8,
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 680;
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    Expanded(child: _CreateActionCard(data: items[i])),
                    if (i != items.length - 1)
                      const SizedBox(width: AuraSpace.s12),
                  ],
                ],
              );
            }

            return Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  _CreateActionCard(data: items[i]),
                  if (i != items.length - 1)
                    const SizedBox(height: AuraSpace.s10),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CreateActionCard extends StatelessWidget {
  const _CreateActionCard({required this.data});

  final _CreateActionData data;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (data.onTap != null) {
            data.onTap!(context);
          } else if (data.route != null) {
            context.go(data.route!);
          }
        },
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
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AuraSurface.accentSoft,
                  borderRadius: BorderRadius.circular(AuraRadius.r10),
                  border: Border.all(
                    color: AuraSurface.accent.withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(
                  data.icon,
                  size: AuraIconSize.sm,
                  color: AuraSurface.accentText,
                ),
              ),
              const SizedBox(height: AuraSpace.s14),
              Text(
                data.title,
                style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AuraSpace.s6),
              Text(
                data.subtitle,
                style: AuraText.small.copyWith(
                  color: AuraSurface.muted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AuraSpace.s14),
              Row(
                children: [
                  Text(
                    'Open',
                    style: AuraText.small.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AuraSurface.accentText,
                    ),
                  ),
                  const SizedBox(width: AuraSpace.s4),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: AuraSurface.accentText,
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

class _CreateActionData {
  _CreateActionData({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.route,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? route;
  final void Function(BuildContext context)? onTap;
}
