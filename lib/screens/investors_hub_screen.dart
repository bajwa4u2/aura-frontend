import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/ui/aura_platform_components.dart';
import '../core/ui/aura_space.dart';
import '../core/ui/aura_surface.dart';
import '../core/ui/aura_text.dart';
import '../core/ui/investor/investor.dart';
import '../core/ui/pdf_viewer_screen.dart';
import '../core/ui/publication/publication.dart';

/// Investors & Partners — flagship strategic surface for Aura Platform LLC.
///
/// Architecture:
///   I.   Hero band — strategic thesis, primary deck CTA.
///   II.  Platform structure — Aura + Orchestrate over shared fabric.
///   III. Strategic pillars — Trust / Action / Records (numbered).
///   IV.  Why now — market forces + operational shift (contrasting band).
///   V.   Execution credibility — operator background.
///   VI.  Investor deck — flagship centerpiece.
///   VII. Contact — strategic close.
///
/// Implementation lives entirely on the new investor primitives in
/// `core/ui/investor/`. Shares Aura typography, spacing, and color
/// systems with the publication system but uses a band-based
/// composition (executive register) rather than a single reading
/// column (editorial register).
class InvestorsHubScreen extends StatelessWidget {
  const InvestorsHubScreen({super.key});

  static const _deckTitle = 'Aura Platform Investor Deck';
  static const _deckAsset =
      'assets/investor/Aura_Platform_Investor_Deck_2026.pdf';

  void _openDeck(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => const PdfViewerScreen(
          title: _deckTitle,
          assetPath: _deckAsset,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InvestorLayout(
      title: 'Investors',
      bands: [
        // I. Hero band.
        InvestorBand(
          surface: AuraSurface.subtle,
          bottomBorder: true,
          child: AuraPublicationHero(
            eyebrow: 'Investors & Partners',
            title: 'Infrastructure for accountable communication '
                'and AI-assisted execution.',
            subtitle:
                'Aura Platform LLC builds the trust fabric beneath two '
                'connected products — Aura for accountable public '
                'discourse and institutional communication, and '
                'Orchestrate for AI-assisted revenue and operational '
                'execution.',
            metaItems: const [
              AuraPublicationMetaItem(
                icon: Icons.account_balance_outlined,
                label: 'Aura Platform LLC',
              ),
              AuraPublicationMetaItem(
                icon: Icons.workspaces_outline,
                label: 'Two-product platform',
              ),
              AuraPublicationMetaItem(
                icon: Icons.event_outlined,
                label: 'Seed · May 2026',
              ),
            ],
            actions: [
              AuraPrimaryButton(
                label: 'Open Investor Deck',
                icon: Icons.menu_book_outlined,
                onPressed: () => _openDeck(context),
              ),
              AuraGhostButton(
                label: 'Contact the Aura team',
                icon: Icons.mail_outline_rounded,
                onPressed: () => context.go('/support/agent'),
              ),
            ],
          ),
        ),

        // II. Platform structure — visual architecture.
        const InvestorBand(
          surface: AuraSurface.page,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InvestorSectionHeader(
                numeral: 'I',
                eyebrow: 'Platform structure',
                title: 'Two products. One trust fabric.',
                subtitle:
                    'Aura and Orchestrate are not adjacent SaaS products. '
                    'They sit on the same identity, governance, realtime, '
                    'and records layer — the fabric beneath them is the '
                    'company.',
              ),
              SizedBox(height: AuraSpace.xl),
              InvestorPlatformArchitecture(
                fabricLabel: 'Shared infrastructure',
                fabricCells: [
                  'Identity',
                  'Governance',
                  'Realtime',
                  'Records',
                  'AI execution',
                ],
                products: [
                  InvestorArchitectureProduct(
                    name: 'Aura',
                    tagline:
                        'Accountable public discourse and '
                        'institutional communication.',
                  ),
                  InvestorArchitectureProduct(
                    name: 'Orchestrate',
                    tagline:
                        'AI-assisted revenue and operational '
                        'execution — outreach to billing.',
                  ),
                ],
              ),
            ],
          ),
        ),

        // III. Strategic pillars.
        const InvestorBand(
          surface: AuraSurface.page,
          verticalPadding: AuraSpace.xxl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InvestorSectionHeader(
                numeral: 'II',
                eyebrow: 'Strategic pillars',
                title: 'Trust. Action. Records.',
                subtitle:
                    'Three properties the platform enforces by '
                    'design — not as features, but as the operating '
                    'contract every product on the fabric inherits.',
              ),
              SizedBox(height: AuraSpace.xl),
              InvestorThesisStrip(
                pillars: [
                  InvestorThesisPillar(
                    label: 'Trust',
                    body:
                        'Identity, authority, and responsibility stay '
                        'attached to every action — across people, '
                        'institutions, and AI.',
                  ),
                  InvestorThesisPillar(
                    label: 'Action',
                    body:
                        'Communication and operational execution share '
                        'one trust fabric, so decisions move forward '
                        'without losing context.',
                  ),
                  InvestorThesisPillar(
                    label: 'Records',
                    body:
                        'Outcomes are durable. What was said, decided, '
                        'and shipped remains visible to the right '
                        'audience over time.',
                  ),
                ],
              ),
            ],
          ),
        ),

        // IV. Why now — contrasting subtle band.
        const InvestorBand(
          surface: AuraSurface.subtle,
          topBorder: true,
          bottomBorder: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InvestorSectionHeader(
                numeral: 'III',
                eyebrow: 'Why now',
                title: 'The institutional moment for accountability '
                    'infrastructure.',
                subtitle:
                    'Public communication, institutional coordination, '
                    'and AI-assisted execution are converging on the '
                    'same operational reality — and most stacks were '
                    'never designed to keep identity, action, and '
                    'records connected through it.',
              ),
              SizedBox(height: AuraSpace.xl),
              InvestorWhyNowContent(
                forces: [
                  InvestorMarketPoint(
                    headline: 'Eroded public trust',
                    body:
                        'Communication infrastructure built for '
                        'engagement extraction is incompatible with '
                        'accountable public discourse — and the cost '
                        'of that mismatch is no longer absorbable.',
                  ),
                  InvestorMarketPoint(
                    headline: 'AI as an actor, not a tool',
                    body:
                        'When AI takes operational actions on behalf '
                        'of people and institutions, identity and '
                        'authority need to be named at the system '
                        'layer — not at the prompt.',
                  ),
                  InvestorMarketPoint(
                    headline: 'Coordination fragmentation',
                    body:
                        'Decisions move forward across five tools and '
                        'three threads. The operational memory needed '
                        'to keep follow-through attached is missing '
                        'by default.',
                  ),
                ],
                shifts: [
                  InvestorMarketPoint(
                    headline: 'Identity as platform primitive',
                    body:
                        'Verified institutions speaking under verified '
                        'identity, with authority that is named, '
                        'scoped, and reviewable.',
                  ),
                  InvestorMarketPoint(
                    headline: 'Governed AI execution',
                    body:
                        'AI assists; humans decide. Final authority '
                        'stays with an identity-bound person or '
                        'institution, and every action carries a '
                        'reviewable record.',
                  ),
                  InvestorMarketPoint(
                    headline: 'Operational continuity',
                    body:
                        'Communication, scheduling, workflow, and '
                        'billing share one trust fabric. Context does '
                        'not evaporate between tools.',
                  ),
                ],
              ),
            ],
          ),
        ),

        // V. Execution credibility.
        const InvestorBand(
          surface: AuraSurface.page,
          verticalPadding: AuraSpace.xxl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InvestorSectionHeader(
                numeral: 'IV',
                eyebrow: 'Execution',
                title: 'Operator-builder discipline.',
                subtitle:
                    'Aura Platform LLC is being built by a sole '
                    'operator-builder. The background is not media or '
                    'marketing — it is infrastructure, projects, and '
                    'records.',
              ),
              SizedBox(height: AuraSpace.xl),
              InvestorExecutionContent(
                summary:
                    'Muhammad Sakhawat (MS Bajwa) is founder and '
                    'builder. The background is operator-builder, not '
                    'media: construction, excavation, oil and gas '
                    'infrastructure, and project management — '
                    'primarily in Oman. The work demanded the kind of '
                    'discipline that does not survive shortcuts: '
                    'identity attached to scope, schedules attached '
                    'to delivery, records attached to outcomes.',
                tiles: [
                  InvestorExecutionTile(
                    icon: Icons.engineering_outlined,
                    label: 'Infrastructure operator',
                    body:
                        'Real-world systems where identity, schedule, '
                        'and outcome had to stay attached or projects '
                        'broke.',
                  ),
                  InvestorExecutionTile(
                    icon: Icons.menu_book_outlined,
                    label: 'Editorial posture',
                    body:
                        'Bajwa Writes™ — long-form work on conscience, '
                        'institutional responsibility, and moral '
                        'structure — informs the platform\'s voice.',
                  ),
                  InvestorExecutionTile(
                    icon: Icons.developer_board_outlined,
                    label: 'Shipping product',
                    body:
                        'Aura ships today as a working communication '
                        'platform — verified identity, institutions, '
                        'announcements, realtime, records.',
                  ),
                  InvestorExecutionTile(
                    icon: Icons.timeline_outlined,
                    label: 'Long-horizon thinking',
                    body:
                        'Built with infrastructure discipline. Not '
                        'short-term engagement logic. Continuity is a '
                        'first-class system property.',
                  ),
                ],
              ),
            ],
          ),
        ),

        // VI. Deck centerpiece.
        InvestorBand(
          surface: AuraSurface.subtle,
          topBorder: true,
          verticalPadding: AuraSpace.xxl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const InvestorSectionHeader(
                numeral: 'V',
                eyebrow: 'Investor deck',
                title: 'Read the platform thesis.',
                subtitle:
                    'A single, controlled investor document covers the '
                    'infrastructure thesis, the two-product platform, '
                    'and the operating contract. Open the deck below.',
              ),
              const SizedBox(height: AuraSpace.xl),
              InvestorDeckCenterpiece(
                title: 'Aura Platform Investor Deck',
                subtitle:
                    'Infrastructure overview for Aura Platform LLC, '
                    'including Aura and Orchestrate, the shared trust '
                    'fabric, and the operating contract.',
                version: 'Version 1.0 · Seed',
                updatedLabel: 'May 2026',
                onOpen: () => _openDeck(context),
              ),
            ],
          ),
        ),

        // VII. Contact close.
        InvestorBand(
          surface: AuraSurface.page,
          verticalPadding: AuraSpace.xxl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const InvestorSectionHeader(
                numeral: 'VI',
                eyebrow: 'Contact',
                title: 'Investor-grade conversations.',
                subtitle:
                    'Capital relationships, partnership discussions, '
                    'and operational diligence are routed through the '
                    'Aura team. Patronage, supporter, and platform '
                    'inquiries each have a dedicated surface.',
              ),
              const SizedBox(height: AuraSpace.lg),
              Wrap(
                spacing: AuraSpace.s10,
                runSpacing: AuraSpace.s10,
                children: [
                  AuraPrimaryButton(
                    label: 'Contact Aura',
                    icon: Icons.mail_outline_rounded,
                    onPressed: () => context.go('/support/agent'),
                  ),
                  AuraGhostButton(
                    label: 'Patrons',
                    icon: Icons.volunteer_activism_outlined,
                    onPressed: () => context.go('/patrons'),
                  ),
                  AuraGhostButton(
                    label: 'Mission',
                    icon: Icons.flag_outlined,
                    onPressed: () => context.go('/mission'),
                  ),
                  AuraGhostButton(
                    label: 'White Paper',
                    icon: Icons.menu_book_outlined,
                    onPressed: () => context.go('/white-paper'),
                  ),
                ],
              ),
              const SizedBox(height: AuraSpace.xl),
              const _Colophon(),
            ],
          ),
        ),
      ],
    );
  }
}

class _Colophon extends StatelessWidget {
  const _Colophon();

  @override
  Widget build(BuildContext context) {
    return Text(
      'AURA PLATFORM LLC · INVESTORS & PARTNERS · MAY 2026',
      style: AuraText.label.copyWith(
        color: AuraSurface.muted,
        letterSpacing: 1.4,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
