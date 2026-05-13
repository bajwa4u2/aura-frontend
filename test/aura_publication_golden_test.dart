// Golden screenshots for the Aura publication system.
//
// Produces real PNG files at test/goldens/ that demonstrate the
// publication-grade visual identity established by [AuraPublicationLayout],
// [AuraPublicationHero], and [AuraPublicationMarkdown].
//
// Run from aura_final/:
//   flutter test --update-goldens test/aura_publication_golden_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/ui/aura_platform_components.dart';
import 'package:aura/core/ui/aura_space.dart';
import 'package:aura/core/ui/aura_surface.dart';
import 'package:aura/core/ui/publication/publication.dart';

const String _sampleWhitePaperMarkdown = '''
# Accountable communication, by design

Modern public communication systems reward reaction over responsibility.
Identity blurs. Corrections evaporate. The record of who said what and
what followed scatters across surfaces that were never built to keep it
connected.

Aura inverts that default. Every voice, every action, every outcome is
attached to an identity-bound author — a person or an institution speaking
on the record.

## Why this matters

The cost of unaccountable communication has been absorbed mostly by the
public so far. Misattribution is normalized. Reputation laundering is a
business. Institutions take a position, walk it back overnight, and the
trace is gone by the morning news cycle.

Communication infrastructure that cannot keep identity, authority, and
outcomes connected is communication infrastructure that disclaims its
own responsibility for those properties.

> Identity, authority, and outcomes must stay connected — by the system,
> not by the goodwill of the operator.

## The contract

Aura ships three guarantees as primitives, not features:

- **Verified identity.** Every author is a real, named person or a
  verified institution. Anonymous performance is incompatible with the
  product.
- **Structured authority.** Authority is named, scoped, and reviewable —
  for individuals, institutions, and the AI agents they operate.
- **Durable records.** Statements, replies, corrections, and outcomes
  remain attached over time. Context does not evaporate between sessions.

### Identity

A speaker carries one identity across every public surface — discourse,
announcements, replies, corrections. The identity is verified before it
can speak; what it says stays attributable.

### Authority

Authority to act — to publish on behalf of an institution, to moderate,
to certify — is named in advance and reviewable after the fact. No
authority is implicit.

### Records

Public statements and institutional actions are durable artifacts. They
do not move. They do not silently disappear. Corrections attach to the
original record rather than replacing it.

## What this is not

Aura is not a social network with an audit trail bolted on. The
accountability is the product. Anything resembling engagement-extraction
mechanics is incompatible with the contract above and will not ship.

---

This paper is a living document. Versioned, dated, and updated as the
infrastructure matures.
''';

Widget _whitePaperGallery({
  required Size viewport,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AuraSurface.page,
    ),
    home: AuraPublicationLayout(
      title: 'White Paper',
      hero: AuraPublicationHero(
        eyebrow: 'White Paper',
        title: 'Accountable communication infrastructure.',
        subtitle:
            'How Aura keeps identity, authority, and outcomes connected '
            'across public discourse and institutional communication.',
        metaItems: const [
          AuraPublicationMetaItem(
            icon: Icons.description_outlined,
            label: 'Version 1.0',
          ),
          AuraPublicationMetaItem(
            icon: Icons.event_outlined,
            label: 'Updated May 2026',
          ),
          AuraPublicationMetaItem(
            icon: Icons.schedule_outlined,
            label: '5 min read',
          ),
        ],
        actions: [
          AuraPrimaryButton(
            label: 'Download PDF',
            icon: Icons.download_outlined,
            onPressed: () {},
          ),
          AuraGhostButton(
            label: 'Back to Mission',
            icon: Icons.arrow_back_rounded,
            onPressed: () {},
          ),
        ],
      ),
      showProgress: true,
      showSiteFooter: false, // footer adds complexity unrelated to this golden
      children: const [
        AuraPublicationMarkdown(data: _sampleWhitePaperMarkdown),
        SizedBox(height: AuraSpace.lg),
        AuraPublicationCallout(
          text: 'Trust, action, and records are not features. They are '
              'the operating contract for accountable communication.',
          attribution: 'Aura Platform thesis',
        ),
        AuraPublicationDivider(),
        AuraPublicationColophon(
          publisher: 'Aura Platform LLC',
          version: 'White Paper · Version 1.0',
          updatedLabel: 'May 2026',
        ),
      ],
    ),
  );
}

Widget _missionGallery({required Size viewport}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AuraSurface.page,
    ),
    home: AuraPublicationLayout(
      title: 'Mission',
      showSiteFooter: false,
      hero: AuraPublicationHero(
        eyebrow: 'Mission',
        title: 'Durable systems for communication, '
            'coordination, and execution.',
        subtitle:
            'Aura Platform LLC builds infrastructure where identity, '
            'authority, and outcomes stay connected — across people, '
            'institutions, and AI.',
        actions: [
          AuraGhostButton(
            label: 'White Paper',
            icon: Icons.menu_book_outlined,
            onPressed: () {},
          ),
          AuraGhostButton(
            label: 'Founder',
            icon: Icons.person_outline_rounded,
            onPressed: () {},
          ),
        ],
      ),
      children: [
        PubText.p(
          'Modern work is fast, but unstable. Conversations scatter '
          'across tools. Identity blurs. Decisions move forward, but '
          'the record of who said what — and what was supposed to '
          'happen next — gets lost between the tab and the calendar.',
        ),
        PubText.h('What we protect'),
        PubText.p(
          'Every voice and every action is attributed to a real, '
          'verifiable person or institution. Authority is named, '
          'scoped, and reviewable.',
        ),
        const AuraPublicationCallout(
          text: 'Infrastructure for accountable communication and '
              'AI-assisted operational execution.',
          attribution: 'Aura Platform thesis',
        ),
        const AuraPublicationDivider(),
        const AuraPublicationColophon(
          publisher: 'Aura Platform LLC',
          version: 'Mission',
          updatedLabel: 'May 2026',
        ),
      ],
    ),
  );
}

Future<void> _pumpAt(
  WidgetTester tester, {
  required Widget child,
  required Size viewport,
}) async {
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(child);
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('Publication system · White Paper · desktop',
      (tester) async {
    const viewport = Size(1280, 2400);
    await _pumpAt(
      tester,
      child: _whitePaperGallery(viewport: viewport),
      viewport: viewport,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/aura_publication_white_paper_desktop.png'),
    );
  });

  testWidgets('Publication system · White Paper · mobile narrow',
      (tester) async {
    const viewport = Size(380, 2400);
    await _pumpAt(
      tester,
      child: _whitePaperGallery(viewport: viewport),
      viewport: viewport,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/aura_publication_white_paper_mobile.png'),
    );
  });

  testWidgets('Publication system · Mission · desktop', (tester) async {
    const viewport = Size(1280, 2000);
    await _pumpAt(
      tester,
      child: _missionGallery(viewport: viewport),
      viewport: viewport,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/aura_publication_mission_desktop.png'),
    );
  });
}
