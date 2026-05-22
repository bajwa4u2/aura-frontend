// Golden screenshots for the Investor surface.
//
// Generates PNGs at test/goldens/ so the flagship band composition,
// section pacing, and deck centerpiece can be visually inspected.
// Each band is rendered against the Aura dark surface system so the
// captured PNG matches production registration.
//
// Run from aura_final/:
//   flutter test --update-goldens test/aura_investor_golden_test.dart
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/ui/aura_platform_components.dart';
import 'package:aura/core/ui/aura_space.dart';
import 'package:aura/core/ui/aura_surface.dart';
import 'package:aura/core/ui/aura_text.dart';
import 'package:aura/core/ui/investor/investor.dart';
import 'package:aura/core/ui/publication/publication.dart';

/// The same content the production screen renders, lifted into a
/// dependency-free composition so we can capture goldens without the
/// app-shell/router/scaffold pieces.
Widget _investorGallery() {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AuraSurface.page,
    ),
    home: Material(
      color: AuraSurface.page,
      child: ListView(
        children: [
          // I. Hero band.
          InvestorBand(
            surface: AuraSurface.subtle,
            bottomBorder: true,
            child: AuraPublicationHero(
              eyebrow: 'Investors & Partners',
              title: 'Infrastructure for accountable communication '
                  'and AI-assisted execution.',
              subtitle:
                  'Aura Platform LLC builds the trust fabric beneath '
                  'two connected products — Aura for accountable public '
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
                  onPressed: () {},
                ),
                AuraGhostButton(
                  label: 'Contact the Aura team',
                  icon: Icons.mail_outline_rounded,
                  onPressed: () {},
                ),
              ],
            ),
          ),
          // II. Platform structure.
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
                      'Aura and Orchestrate are not adjacent SaaS '
                      'products. They sit on the same identity, '
                      'governance, realtime, and records layer.',
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
                      'contract.',
                ),
                SizedBox(height: AuraSpace.xl),
                InvestorThesisStrip(
                  pillars: [
                    InvestorThesisPillar(
                      label: 'Trust',
                      body:
                          'Identity, authority, and responsibility '
                          'stay attached to every action.',
                    ),
                    InvestorThesisPillar(
                      label: 'Action',
                      body:
                          'Communication and execution share one '
                          'trust fabric.',
                    ),
                    InvestorThesisPillar(
                      label: 'Records',
                      body:
                          'Outcomes are durable. Statements remain '
                          'visible over time.',
                    ),
                  ],
                ),
              ],
            ),
          ),
          // IV. Why now.
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
                  title: 'The institutional moment.',
                  subtitle:
                      'Public communication, institutional '
                      'coordination, and AI-assisted execution are '
                      'converging on the same operational reality.',
                ),
                SizedBox(height: AuraSpace.xl),
                InvestorWhyNowContent(
                  forces: [
                    InvestorMarketPoint(
                      headline: 'Eroded public trust',
                      body:
                          'Communication infrastructure built for '
                          'engagement is incompatible with '
                          'accountable public discourse.',
                    ),
                    InvestorMarketPoint(
                      headline: 'AI as actor',
                      body:
                          'AI takes operational actions; identity '
                          'and authority must be named at the system '
                          'layer.',
                    ),
                  ],
                  shifts: [
                    InvestorMarketPoint(
                      headline: 'Identity as primitive',
                      body:
                          'Verified institutions speaking under '
                          'verified identity.',
                    ),
                    InvestorMarketPoint(
                      headline: 'Governed AI',
                      body:
                          'AI assists; humans decide. Every action '
                          'carries a reviewable record.',
                    ),
                  ],
                ),
              ],
            ),
          ),
          // V. Execution.
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
                      'The company is being built by a sole '
                      'operator-builder.',
                ),
                SizedBox(height: AuraSpace.xl),
                InvestorExecutionContent(
                  summary:
                      'Muhammad Sakhawat is founder and builder. '
                      'The background is operator-builder, not '
                      'media: infrastructure, projects, records.',
                  tiles: [
                    InvestorExecutionTile(
                      icon: Icons.engineering_outlined,
                      label: 'Infrastructure operator',
                      body:
                          'Real-world systems where identity, '
                          'schedule, and outcome had to stay '
                          'attached.',
                    ),
                    InvestorExecutionTile(
                      icon: Icons.menu_book_outlined,
                      label: 'Editorial posture',
                      body:
                          'Long-form work on institutional '
                          'responsibility informs platform voice.',
                    ),
                    InvestorExecutionTile(
                      icon: Icons.developer_board_outlined,
                      label: 'Shipping product',
                      body:
                          'Aura ships today as a working '
                          'communication platform.',
                    ),
                    InvestorExecutionTile(
                      icon: Icons.timeline_outlined,
                      label: 'Long-horizon thinking',
                      body:
                          'Infrastructure discipline. Not '
                          'engagement-extraction logic.',
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
                      'A single, controlled investor document covers '
                      'the infrastructure thesis and the operating '
                      'contract.',
                ),
                const SizedBox(height: AuraSpace.xl),
                InvestorDeckCenterpiece(
                  title: 'Aura Platform Investor Deck',
                  subtitle:
                      'Infrastructure overview for Aura Platform LLC, '
                      'including Aura and Orchestrate.',
                  version: 'Version 1.0 · Seed',
                  updatedLabel: 'May 2026',
                  onOpen: () {},
                ),
              ],
            ),
          ),
          // VII. Contact close.
          const InvestorBand(
            surface: AuraSurface.page,
            verticalPadding: AuraSpace.xxl,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InvestorSectionHeader(
                  numeral: 'VI',
                  eyebrow: 'Contact',
                  title: 'Investor-grade conversations.',
                  subtitle:
                      'Capital relationships and partnership '
                      'discussions are routed through the Aura team.',
                ),
                SizedBox(height: AuraSpace.lg),
                _ColophonGolden(),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ColophonGolden extends StatelessWidget {
  const _ColophonGolden();
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

Future<void> _pumpAt(
  WidgetTester tester, {
  required Size viewport,
}) async {
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(_investorGallery());
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('Investor surface · desktop', (tester) async {
    await _pumpAt(tester, viewport: const Size(1280, 4400));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/aura_investor_desktop.png'),
    );
  });

  testWidgets('Investor surface · mobile narrow', (tester) async {
    await _pumpAt(tester, viewport: const Size(380, 6800));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/aura_investor_mobile.png'),
    );
  });
}
