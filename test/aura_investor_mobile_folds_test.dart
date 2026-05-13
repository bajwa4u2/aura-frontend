// Real mobile-viewport captures for the Investor surface.
//
// Single 380×6800 strip is misleading — that's not what a phone user
// sees. These tests render the gallery at the actual mobile viewport
// size (380×900) and scroll to known section anchors, producing four
// fold-sized PNGs that match what a real phone screen looks like at
// each scroll position:
//
//   * fold 1 — first paint (hero)
//   * fold 2 — mid scroll (platform architecture / strategic pillars)
//   * fold 3 — deck centerpiece
//   * fold 4 — CTA / contact close + footer
//
// Run from aura_final/:
//   flutter test --update-goldens test/aura_investor_mobile_folds_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/ui/aura_platform_components.dart';
import 'package:aura/core/ui/aura_space.dart';
import 'package:aura/core/ui/aura_surface.dart';
import 'package:aura/core/ui/aura_text.dart';
import 'package:aura/core/ui/investor/investor.dart';
import 'package:aura/core/ui/publication/publication.dart';

// Section anchor keys — used by tester.ensureVisible to scroll the
// ListView so each fold capture lands on a known band.
const _heroKey = Key('investor_band_hero');
const _architectureKey = Key('investor_band_architecture');
const _pillarsKey = Key('investor_band_pillars');
const _whyNowKey = Key('investor_band_whynow');
const _executionKey = Key('investor_band_execution');
const _deckKey = Key('investor_band_deck');
const _ctaKey = Key('investor_band_cta');

Widget _gallery() {
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
          InvestorBand(
            key: _heroKey,
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
          const InvestorBand(
            key: _architectureKey,
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
          const InvestorBand(
            key: _pillarsKey,
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
                      'design — the operating contract every product '
                      'on the fabric inherits.',
                ),
                SizedBox(height: AuraSpace.xl),
                InvestorThesisStrip(
                  pillars: [
                    InvestorThesisPillar(
                      label: 'Trust',
                      body:
                          'Identity, authority, and responsibility '
                          'stay attached to every action — across '
                          'people, institutions, and AI.',
                    ),
                    InvestorThesisPillar(
                      label: 'Action',
                      body:
                          'Communication and operational execution '
                          'share one trust fabric.',
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
          const InvestorBand(
            key: _whyNowKey,
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
          const InvestorBand(
            key: _executionKey,
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
                      'operator-builder.',
                ),
                SizedBox(height: AuraSpace.xl),
                InvestorExecutionContent(
                  summary:
                      'Muhammad Sakhawat is founder and builder. The '
                      'background is operator-builder, not media: '
                      'infrastructure, projects, records.',
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
                          'Infrastructure discipline.',
                    ),
                  ],
                ),
              ],
            ),
          ),
          InvestorBand(
            key: _deckKey,
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
          InvestorBand(
            key: _ctaKey,
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
                      'Capital relationships and partnership '
                      'discussions are routed through the Aura team.',
                ),
                const SizedBox(height: AuraSpace.lg),
                Wrap(
                  spacing: AuraSpace.s10,
                  runSpacing: AuraSpace.s10,
                  children: [
                    AuraPrimaryButton(
                      label: 'Contact Aura',
                      icon: Icons.mail_outline_rounded,
                      onPressed: () {},
                    ),
                    AuraGhostButton(
                      label: 'Patrons',
                      icon: Icons.volunteer_activism_outlined,
                      onPressed: () {},
                    ),
                    AuraGhostButton(
                      label: 'Mission',
                      icon: Icons.flag_outlined,
                      onPressed: () {},
                    ),
                    AuraGhostButton(
                      label: 'White Paper',
                      icon: Icons.menu_book_outlined,
                      onPressed: () {},
                    ),
                  ],
                ),
                const SizedBox(height: AuraSpace.xl),
                Text(
                  'AURA PLATFORM LLC · INVESTORS & PARTNERS · MAY 2026',
                  style: AuraText.label.copyWith(
                    color: AuraSurface.muted,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Real-phone viewport — 380×900 matches a typical mid-range device
/// in CSS-pixel terms (e.g. iPhone SE area), so the captures match
/// what a person actually sees on screen rather than the unrealistic
/// full-page strip.
const _viewport = Size(380, 900);

Future<void> _pumpAndScrollToKey(
  WidgetTester tester,
  Key anchor,
) async {
  tester.view.physicalSize = _viewport;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(_gallery());
  await tester.pump(const Duration(milliseconds: 200));

  // ListView lazy-builds children, so an anchor that's below the
  // fold isn't in the tree yet. scrollUntilVisible repeatedly scrolls
  // by `delta` until the target is found and on-screen.
  await tester.scrollUntilVisible(
    find.byKey(anchor),
    400.0,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 50,
  );
  await tester.pump(const Duration(milliseconds: 200));

  // Once the band is on-screen, jump the scrollable so the band's top
  // edge sits at viewport-top — produces a clean fold-aligned capture.
  final scrollable = Scrollable.of(tester.element(find.byKey(anchor)));
  final box = tester.renderObject<RenderBox>(find.byKey(anchor));
  final pos = scrollable.position;
  final bandTopInViewport = box.localToGlobal(Offset.zero).dy;
  final targetPos = pos.pixels + bandTopInViewport;
  pos.jumpTo(targetPos.clamp(pos.minScrollExtent, pos.maxScrollExtent));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('Mobile fold 1 · first paint (hero)', (tester) async {
    tester.view.physicalSize = _viewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_gallery());
    await tester.pump(const Duration(milliseconds: 300));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/aura_investor_mobile_fold_1_hero.png'),
    );
  });

  testWidgets('Mobile fold 2 · mid scroll (platform structure)',
      (tester) async {
    await _pumpAndScrollToKey(tester, _architectureKey);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        'goldens/aura_investor_mobile_fold_2_architecture.png',
      ),
    );
  });

  testWidgets('Mobile fold 3 · strategic pillars', (tester) async {
    await _pumpAndScrollToKey(tester, _pillarsKey);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        'goldens/aura_investor_mobile_fold_3_pillars.png',
      ),
    );
  });

  testWidgets('Mobile fold 4 · why now', (tester) async {
    await _pumpAndScrollToKey(tester, _whyNowKey);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        'goldens/aura_investor_mobile_fold_4_whynow.png',
      ),
    );
  });

  testWidgets('Mobile fold 5 · execution', (tester) async {
    await _pumpAndScrollToKey(tester, _executionKey);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        'goldens/aura_investor_mobile_fold_5_execution.png',
      ),
    );
  });

  testWidgets('Mobile fold 6 · deck centerpiece', (tester) async {
    await _pumpAndScrollToKey(tester, _deckKey);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        'goldens/aura_investor_mobile_fold_6_deck.png',
      ),
    );
  });

  testWidgets('Mobile fold 7 · CTA / contact close', (tester) async {
    await _pumpAndScrollToKey(tester, _ctaKey);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        'goldens/aura_investor_mobile_fold_7_cta.png',
      ),
    );
  });
}
