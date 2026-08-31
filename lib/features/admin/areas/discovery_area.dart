/// DISCOVERY — can the outside world find what we published?
///
/// FOUNDER FRAME: OBSERVATION ≠ CONTROL. This area observes five estates and
/// changes none of them. There is no button here that publishes, retires,
/// submits a URL anywhere, or asks a search engine to do anything.
///
/// It leads with the gap rather than a score. A "discoverability score" is a
/// vanity number; "we published 4,102 objects and our sitemap mentions 0 of
/// them" is a finding somebody can act on, and it is the finding this area was
/// built after seeing.
///
/// EVIDENCE IS NAMED, NOT ASSUMED. Every number carries which sources produced
/// it and which could not run. Google Search Console is one adapter among six
/// — if it disappeared, Discovery would lose an adapter and keep working.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../data/operator_discovery.dart';
import '../domain/operator_authority_provider.dart';
import '../domain/operator_capability.dart';
import '../ui/operator_action.dart';
import '../ui/operator_kit.dart';

class DiscoveryArea extends ConsumerWidget {
  const DiscoveryArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authority = ref.watch(operatorAuthorityProvider).valueOrNull ??
        const OperatorAuthority.none();

    if (!authority.can(OperatorCapability.discoveryRead)) {
      return const Padding(
        padding: EdgeInsets.all(AuraSpace.s20),
        child: OperatorInsufficientCapability(needs: 'discovery'),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        return ListView(
          padding: EdgeInsets.all(wide ? AuraSpace.s20 : AuraSpace.s12),
          children: [
            const _EstatePicker(),
            const SizedBox(height: AuraSpace.s20),
            _Coverage(authority: authority),
            const SizedBox(height: AuraSpace.s24),
            const _Objects(),
            const SizedBox(height: AuraSpace.s24),
            // BEHIND ITS OWN CAPABILITY. Search text is written by the outside
            // world, is person-identifying at low volume, and Aura did not
            // author it. DISCOVERY_READ runs Discovery; reading what people
            // typed is a separate grant.
            if (authority.can(OperatorCapability.discoveryEvidenceRead))
              const _Queries()
            else
              const OperatorSection(
                title: 'What people searched for',
                subtitle: 'Behind a separate grant, deliberately',
                child: OperatorInsufficientCapability(
                  needs: 'discovery evidence',
                ),
              ),
            const SizedBox(height: AuraSpace.s24),
            const _Retention(),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// The five estates, and only those five. Frozen scope.
class _EstatePicker extends ConsumerWidget {
  const _EstatePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(discoveryEstateProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final estate in DiscoveryEstate.values)
            Padding(
              padding: const EdgeInsets.only(right: AuraSpace.s8),
              child: ChoiceChip(
                label: Text(estate.label),
                selected: estate == selected,
                onSelected: (_) =>
                    ref.read(discoveryEstateProvider.notifier).state = estate,
                labelStyle: TextStyle(
                  fontSize: 12.5,
                  color: estate == selected
                      ? AuraSurface.ink
                      : AuraSurface.muted,
                  fontWeight: estate == selected
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
                backgroundColor: AuraSurface.card,
                selectedColor: AuraSurface.elevated,
                side: const BorderSide(color: AuraSurface.divider),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _Coverage extends ConsumerWidget {
  const _Coverage({required this.authority});

  final OperatorAuthority authority;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(discoveryReportProvider);

    return report.when(
      loading: () => const OperatorSection(
        title: 'Reach',
        child: OperatorLoading(lines: 3),
      ),
      error: (e, _) => OperatorSection(
        title: 'Reach',
        child: OperatorFailure(
          title: 'Discovery could not be read',
          detail: '$e',
          onRetry: () => ref.invalidate(discoveryReportProvider),
        ),
      ),
      data: (report) {
        final coverage = report.coverage;

        if (coverage.published == 0) {
          return OperatorSection(
            title: 'Reach',
            subtitle: coverage.estate.label,
            trailing: _CollectButton(authority: authority),
            child: OperatorPanel(
              child: OperatorClear(
                title: 'Nothing is on record for this estate',
                detail: coverage.estate == DiscoveryEstate.aura ||
                        coverage.estate == DiscoveryEstate.auraPlatform
                    ? 'Collect evidence to build the inventory.'
                    : 'This estate lives outside this database. Aura observes '
                        'it only through providers that can reach it.',
                icon: Icons.travel_explore_rounded,
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // THE GAP LEADS. Not a score — the number of published objects our
            // own sitemap never mentions, which is the thing that can be
            // fixed and the thing nothing could previously show.
            if (coverage.hasSitemapGap)
              OperatorSection(
                title: 'Reach',
                subtitle: coverage.estate.label,
                trailing: _CollectButton(authority: authority),
                child: OperatorPanel(
                  tone: OperatorTone.danger,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${coverage.unadvertised} of ${coverage.published} '
                        'published objects are not in the sitemap',
                        style: const TextStyle(
                          color: AuraSurface.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: AuraSpace.s8),
                      const Text(
                        'A search engine is only given the sitemap. Anything '
                        'missing from it is found by accident or not at all.',
                        style: TextStyle(
                          color: AuraSurface.muted,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              OperatorSection(
                title: 'Reach',
                subtitle: coverage.estate.label,
                trailing: _CollectButton(authority: authority),
                child: const OperatorPanel(
                  child: OperatorClear(
                    title: 'Everything published is advertised',
                    detail: 'The sitemap and the published corpus agree.',
                  ),
                ),
              ),
            const SizedBox(height: AuraSpace.s16),
            OperatorPanel(
              child: Row(
                children: [
                  _Count(label: 'Published', value: coverage.published),
                  _Count(
                    label: 'In sitemap',
                    value: coverage.advertisedFromInventory,
                    tone: coverage.hasSitemapGap ? OperatorTone.danger : null,
                  ),
                  _Count(label: 'Observed', value: coverage.observed),
                  _Count(label: 'Reachable', value: coverage.indexed),
                ],
              ),
            ),
            if (coverage.families.isNotEmpty) ...[
              const SizedBox(height: AuraSpace.s16),
              OperatorSection(
                title: 'By kind',
                child: OperatorPanel(
                  child: Column(
                    children: [
                      for (final family in coverage.families)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AuraSpace.s8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  family.family,
                                  style: const TextStyle(
                                    color: AuraSurface.ink,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                              Text(
                                '${family.advertised} advertised of '
                                '${family.published}',
                                style: TextStyle(
                                  color: family.advertised < family.published
                                      ? AuraSurface.dangerInk
                                      : AuraSurface.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: AuraSpace.s16),
            _Sources(report: report),
          ],
        );
      },
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.label, required this.value, this.tone});

  final String label;
  final int value;
  final OperatorTone? tone;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: tone?.ink ?? AuraSurface.ink,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: AuraSurface.faint, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

/// WHICH EVIDENCE EXISTS, AND WHICH DOES NOT.
///
/// Shown beside every number rather than hidden behind an info icon. A
/// coverage figure read without knowing that four of six sources could not run
/// is a figure that misleads.
class _Sources extends StatelessWidget {
  const _Sources({required this.report});

  final DiscoveryReport report;

  @override
  Widget build(BuildContext context) {
    return OperatorSection(
      title: 'Where this comes from',
      subtitle: '${report.sources.length - report.unavailable.length} of '
          '${report.sources.length} sources can run',
      child: OperatorPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final source in report.sources)
              Padding(
                padding: const EdgeInsets.only(bottom: AuraSpace.s8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      source.available
                          ? Icons.check_circle_rounded
                          : Icons.remove_circle_outline_rounded,
                      size: 15,
                      color: source.available
                          ? AuraSurface.goodInk
                          : AuraSurface.faint,
                    ),
                    const SizedBox(width: AuraSpace.s8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            source.label,
                            style: TextStyle(
                              color: source.available
                                  ? AuraSurface.ink
                                  : AuraSurface.muted,
                              fontSize: 12.5,
                            ),
                          ),
                          if (source.reason != null)
                            Text(
                              source.reason!,
                              style: const TextStyle(
                                color: AuraSurface.faint,
                                fontSize: 11.5,
                                height: 1.35,
                              ),
                            ),
                        ],
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
}

class _CollectButton extends ConsumerWidget {
  const _CollectButton({required this.authority});

  final OperatorAuthority authority;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton.icon(
      icon: const Icon(Icons.refresh_rounded, size: 16),
      label: const Text('Collect'),
      onPressed: () => _collect(context, ref),
    );
  }

  Future<void> _collect(BuildContext context, WidgetRef ref) async {
    final estate = ref.read(discoveryEstateProvider);
    final done = await runOperatorAction(
      context,
      OperatorAction(
        title: 'Collect evidence',
        subject: estate.label,
        detail: 'Aura reads its own published corpus, fetches its own sitemap, '
            'and probes its own canonical URLs the way a crawler would. '
            'Nothing is submitted anywhere and nothing outside Aura changes.',
        confirmLabel: 'Collect',
        consequences: [
          const OperatorConsequence(
            text: 'Evidence is written into Aura’s own tables.',
            icon: Icons.storage_rounded,
          ),
          const OperatorConsequence(
            text: 'Raw evidence older than 90 days is deleted in the same '
                'pass.',
            icon: Icons.auto_delete_rounded,
          ),
          const OperatorConsequence(
            text: 'Nothing is published, submitted or asked of anybody else.',
            tone: OperatorTone.good,
            icon: Icons.visibility_rounded,
          ),
        ],
        perform: (_) async {
          await ref
              .read(operatorDiscoveryRepositoryProvider)
              .collect(estate);
          return 'Collected. Coverage is rebuilt from what came back.';
        },
      ),
    );
    if (done) {
      ref.invalidate(discoveryReportProvider);
      ref.invalidate(discoveryObjectsProvider);
      ref.invalidate(discoveryRetentionProvider);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// WHAT NOBODY CAN FIND — worst first, by the server's own ordering.
class _Objects extends ConsumerWidget {
  const _Objects();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final objects = ref.watch(discoveryObjectsProvider);

    return objects.when(
      loading: () => const OperatorSection(
        title: 'Objects',
        child: OperatorLoading(lines: 3),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (all) {
        if (all.isEmpty) {
          return const OperatorSection(
            title: 'Objects',
            child: OperatorPanel(
              child: OperatorClear(
                title: 'No object is on record',
                detail: 'Collect evidence to build the inventory.',
                icon: Icons.inventory_2_outlined,
              ),
            ),
          );
        }

        final unseen = all
            .where((o) => o.visibility == DiscoveryVisibility.unobserved)
            .length;

        return OperatorSection(
          title: 'Objects',
          subtitle: unseen == 0
              ? 'Every object has been seen by something'
              : '$unseen of ${all.length} have never been seen',
          child: OperatorPanel(
            padding: const EdgeInsets.symmetric(vertical: AuraSpace.s4),
            child: Column(
              children: [
                for (final object in all.take(60))
                  _ObjectRow(object: object),
                if (all.length > 60)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AuraSpace.s16,
                      AuraSpace.s8,
                      AuraSpace.s16,
                      AuraSpace.s8,
                    ),
                    child: Text(
                      // A silent truncation reads as complete coverage. It is
                      // said out loud instead.
                      '${all.length - 60} more not shown. Worst first, so what '
                      'is hidden is what is already fine.',
                      style: const TextStyle(
                        color: AuraSurface.faint,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ObjectRow extends StatelessWidget {
  const _ObjectRow({required this.object});

  final DiscoveryObject object;

  OperatorTone get _tone => switch (object.visibility) {
        DiscoveryVisibility.unobserved => OperatorTone.danger,
        DiscoveryVisibility.unreachable => OperatorTone.danger,
        DiscoveryVisibility.unknown => OperatorTone.warn,
        DiscoveryVisibility.reachable => OperatorTone.good,
      };

  @override
  Widget build(BuildContext context) {
    // The tail of a canonical URL is what identifies the object; the origin is
    // the same on every row and reading it sixty times helps nobody.
    final path = Uri.tryParse(object.canonicalUrl)?.path ?? object.canonicalUrl;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.s16,
        AuraSpace.s8,
        AuraSpace.s16,
        AuraSpace.s8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 30,
            margin: const EdgeInsets.only(right: AuraSpace.s12, top: 2),
            decoration: BoxDecoration(
              color: _tone.ink,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  path,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AuraSurface.ink,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  object.visibility.label,
                  style: TextStyle(color: _tone.ink, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: AuraSpace.s8),
          OperatorStatePill(state: object.objectFamily, dense: true),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _Queries extends ConsumerWidget {
  const _Queries();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queries = ref.watch(discoveryQueriesProvider);

    return queries.when(
      loading: () => const OperatorSection(
        title: 'What people searched for',
        child: OperatorLoading(lines: 2),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (page) {
        if (page.items.isEmpty) {
          return OperatorSection(
            title: 'What people searched for',
            child: OperatorPanel(
              child: OperatorClear(
                title: page.withheld > 0
                    ? 'Every query is below the display floor'
                    : 'No query evidence',
                detail: page.withheld > 0
                    ? '${page.withheld} withheld. A query seen fewer than '
                        '${page.floor} times can identify the person who '
                        'typed it.'
                    : 'No provider that reports search text is configured.',
                icon: Icons.search_off_rounded,
              ),
            ),
          );
        }

        return OperatorSection(
          title: 'What people searched for',
          subtitle: 'Aggregated and redacted. Never joined to an Aura member.',
          child: OperatorPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final query in page.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AuraSpace.s8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            query.query,
                            style: const TextStyle(
                              color: AuraSurface.ink,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        Text(
                          '${query.impressions}',
                          style: const TextStyle(
                            color: AuraSurface.muted,
                            fontSize: 12,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (page.withheld > 0) ...[
                  const SizedBox(height: AuraSpace.s8),
                  Text(
                    '${page.withheld} withheld for being seen fewer than '
                    '${page.floor} times.',
                    style: const TextStyle(
                      color: AuraSurface.faint,
                      fontSize: 11.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// RETENTION, SHOWN AS A FACT.
///
/// The policy is enforced in the ingestion pass, not documented in a comment.
/// This is where an operator can see it holding.
class _Retention extends ConsumerWidget {
  const _Retention();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final retention = ref.watch(discoveryRetentionProvider);

    return retention.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (r) => OperatorSection(
        title: 'What Discovery keeps',
        child: OperatorPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${r.rawRows} raw rows, kept ${r.rawRetentionDays} days.',
                style: const TextStyle(
                  color: AuraSurface.ink,
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
              Text(
                '${r.observations} normalized observations, kept up to '
                '${r.observationRetentionMonths} months.',
                style: const TextStyle(
                  color: AuraSurface.ink,
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: AuraSpace.s8),
              const Text(
                'Raw evidence can carry search text somebody typed, so it '
                'expires first. The normalized projection carries none, which '
                'is what makes the longer window defensible.',
                style: TextStyle(
                  color: AuraSurface.muted,
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
