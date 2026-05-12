import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/ui/aura_radius.dart';
import '../core/ui/aura_space.dart';
import '../core/ui/aura_surface.dart';
import '../core/ui/aura_text.dart';
import '../core/ui/document_scaffold.dart';
import '../core/ui/pdf_viewer_screen.dart';

/// Investors & Partners page for Aura Platform LLC.
///
/// Curated entry point — not a PDF repository. The page communicates the
/// company thesis (Trust / Action / Records), introduces the two
/// products (Aura and Orchestrate), and exposes a single investor-deck
/// link. Old document-dump cards (Seed Round, Business Model
/// Framework, Governance Framework) were removed in May 2026 along
/// with their PDFs; the only material exposed in-app is the deck.
class InvestorsHubScreen extends StatelessWidget {
  const InvestorsHubScreen({super.key});

  static const _deckTitle = 'Aura Platform Investor Deck';
  static const _deckAsset =
      'assets/investor/Aura_Platform_Investor_Deck_2026.pdf';

  /// Opens a bundled PDF asset inside `PdfViewerScreen` via the root
  /// Navigator. Never uses `context.go`, `launchUrl`, or any
  /// route-shaped URL — the PDF must be rendered by `PdfViewerScreen`
  /// against the asset path, not by go_router against a synthesized
  /// path that looks like a route.
  void _openPdf(
    BuildContext context, {
    required String title,
    required String assetPath,
  }) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(
          title: title,
          assetPath: assetPath,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DocumentScaffold(
      title: 'Investors',
      showSiteFooter: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Doc.title('Investors & Partners'),
          const SizedBox(height: 10),
          Doc.meta('Aura Platform LLC'),
          Doc.lede(
            'Aura Platform LLC builds infrastructure for accountable '
            'communication and AI-assisted operational execution.',
          ),

          Doc.h('Platform thesis'),
          const _ValueBlock(
            label: 'Trust',
            body:
                'Identity, authority, and responsibility stay attached to '
                'every action — across people, institutions, and AI.',
          ),
          const SizedBox(height: AuraSpace.sm),
          const _ValueBlock(
            label: 'Action',
            body:
                'Communication and operational execution share one trust '
                'fabric, so decisions move forward without losing context.',
          ),
          const SizedBox(height: AuraSpace.sm),
          const _ValueBlock(
            label: 'Records',
            body:
                'Outcomes are durable. What was said, decided, and shipped '
                'remains visible to the right audience over time.',
          ),

          Doc.h('Two connected products'),
          _ProductBlock(
            name: 'Aura',
            tagline: 'Accountable public discourse and institutional '
                'communication infrastructure.',
            description:
                'A communication layer where individuals and institutions '
                'speak under verified identity, with structure that makes '
                'who said what — and the response that followed — durable '
                'and reviewable.',
          ),
          const SizedBox(height: AuraSpace.sm),
          _ProductBlock(
            name: 'Orchestrate',
            tagline: 'AI-assisted revenue automation and operational '
                'execution — from outreach to meetings to workflow to '
                'billing.',
            description:
                'Operating infrastructure for institutional teams. '
                'Orchestrate connects outreach, scheduling, internal '
                'workflow, and billing into one governed pipeline so '
                'follow-through stays attached to the people accountable '
                'for it.',
          ),
          const SizedBox(height: AuraSpace.md),
          Doc.callout(
            'Together: trusted communication and governed operational '
            'execution — one identity, one record, one accountable surface.',
          ),

          Doc.h('Investor materials'),
          const SizedBox(height: 8),
          _DeckCard(
            onTap: () => _openPdf(
              context,
              title: 'Aura Platform Investor Deck',
              assetPath:
                  'assets/investor/Aura_Platform_Investor_Deck_2026.pdf',
            ),
          ),

          Doc.h('Contact'),
          Doc.p(
            'For partnership conversations, write to the Aura team through '
            'the support channel below. Investor-grade inquiries are '
            'routed to the founder.',
          ),
          const SizedBox(height: AuraSpace.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.go('/support/agent'),
              icon: const Icon(Icons.mail_outline_rounded, size: 16),
              label: const Text('Contact the Aura team'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Local UI primitives — compact value blocks and the single deck card.
// Kept private to this screen on purpose: this is a curated investor
// surface, not a reusable design-system module.
// ─────────────────────────────────────────────────────────────────────────────

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

class _ProductBlock extends StatelessWidget {
  const _ProductBlock({
    required this.name,
    required this.tagline,
    required this.description,
  });

  final String name;
  final String tagline;
  final String description;

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
          Text(name, style: AuraText.emphasis.copyWith(fontSize: 18)),
          const SizedBox(height: 4),
          Text(
            tagline,
            style: AuraText.body.copyWith(
              color: AuraSurface.muted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(description, style: AuraText.body.copyWith(height: 1.6)),
        ],
      ),
    );
  }
}

class _DeckCard extends StatelessWidget {
  const _DeckCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: AuraSurface.elevated,
      borderRadius: BorderRadius.circular(AuraRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AuraRadius.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AuraSpace.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AuraRadius.md),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AuraRadius.sm),
                ),
                child: Icon(
                  Icons.picture_as_pdf_rounded,
                  size: 18,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: AuraSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      InvestorsHubScreen._deckTitle,
                      style: AuraText.emphasis.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'May 2026',
                      style: AuraText.small.copyWith(color: AuraSurface.muted),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Infrastructure overview for Aura Platform LLC, '
                      'including Aura and Orchestrate.',
                      style: AuraText.body.copyWith(height: 1.55),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Open the deck',
                          style: AuraText.small.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: cs.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
