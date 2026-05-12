import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/ui/aura_radius.dart';
import '../core/ui/aura_space.dart';
import '../core/ui/aura_surface.dart';
import '../core/ui/aura_text.dart';
import '../core/ui/document_scaffold.dart';

/// Supporters page for Aura Platform LLC.
///
/// Supporters contribute attention, testing, and feedback — not capital.
/// The page is intentionally narrow: it names what supporters do, what
/// supporters are not (so the role does not blur with Patron or
/// Investor), and the principle that public infrastructure improves
/// through careful use rather than hype. Single CTA: contact the team.
class SupportersHubScreen extends StatelessWidget {
  const SupportersHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DocumentScaffold(
      title: 'Supporters',
      showSiteFooter: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Doc.title('Supporters'),
          const SizedBox(height: 10),
          Doc.meta('Aura Platform LLC'),
          Doc.lede(
            'Supporters help Aura Platform improve through attention, '
            'testing, feedback, and responsible participation.',
          ),

          Doc.h('What supporters do'),
          const _ValueBlock(
            label: 'Test',
            body:
                'Walk product flows end-to-end and report what feels '
                'wrong, broken, or unclear.',
          ),
          const SizedBox(height: AuraSpace.sm),
          const _ValueBlock(
            label: 'Report',
            body:
                'File precise bug reports — what you did, what you '
                'expected, what happened.',
          ),
          const SizedBox(height: AuraSpace.sm),
          const _ValueBlock(
            label: 'Improve clarity',
            body:
                'Flag copy, structure, and identity signals that confuse '
                'real users or institutions.',
          ),
          const SizedBox(height: AuraSpace.sm),
          const _ValueBlock(
            label: 'Share',
            body:
                'Invite thoughtful users and institutions who would '
                'benefit from accountable communication infrastructure.',
          ),

          Doc.h('What supporters are not'),
          Doc.bullets([
            'Not investors — supporters do not provide capital and do '
                'not hold equity',
            'Not patrons — supporters do not provide ongoing financial '
                'support',
            'Not paid endorsers — supporters speak under their own '
                'identity, not on behalf of the company',
          ]),

          Doc.h('Why it matters'),
          Doc.p(
            'Public infrastructure improves through careful use, not '
            'through hype. Every accurate bug report, every honest '
            'critique of a confusing flow, every thoughtful invitation '
            'sharpens the system. Supporters are the early signal that '
            'the platform is being shaped by real participation rather '
            'than marketing motion.',
          ),

          Doc.callout(
            'Trust, action, and records improve when people who care '
            'about durable systems actually use them.',
          ),

          const SizedBox(height: AuraSpace.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.go('/support/agent'),
              icon: const Icon(Icons.mail_outline_rounded, size: 16),
              label: const Text('Share feedback with the Aura team'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueBlock extends StatelessWidget {
  const _ValueBlock({required this.label, required this.body});

  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.md),
      decoration: BoxDecoration(
        color: AuraSurface.elevated,
        borderRadius: BorderRadius.circular(AuraRadius.md),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AuraText.micro.copyWith(
              color: AuraSurface.muted,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(body, style: AuraText.body.copyWith(height: 1.55)),
        ],
      ),
    );
  }
}
