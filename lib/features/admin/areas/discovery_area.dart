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
import '../../../core/product/temporal.dart';
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
    final authority =
        ref.watch(operatorAuthorityProvider).valueOrNull ??
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
            // THE ANSWER FIRST (7 Nov 2026): did search bring anybody this
            // week? Everything below it is how the answer was reached.
            const _Week(),
            const SizedBox(height: AuraSpace.s24),
            _Coverage(authority: authority),
            const SizedBox(height: AuraSpace.s24),
            const _Objects(),
            const SizedBox(height: AuraSpace.s24),
            // BEHIND ITS OWN CAPABILITY. Search text is written by the outside
            // world, is person-identifying at low volume, and Aura did not
            // author it. DISCOVERY_READ runs Discovery; reading what people
            // typed is a separate grant.
            if (authority.can(OperatorCapability.discoveryEvidenceRead))
              const _Searches()
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
      skipLoadingOnReload: true,
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
          // AN EMPTY RESULT IS WHEN PROVENANCE MATTERS MOST.
          //
          // The empty state used to be a single sentence with no way to tell
          // "we looked everywhere and there is nothing" from "nothing that
          // could look was able to run". Those are opposite conclusions, and
          // an operator was left to guess which one they were reading.
          //
          // So the source panel stays. Zero with every source reporting is a
          // finding; zero with sources unavailable is not a finding at all.
          final reporting = report.sources.length - report.unavailable.length;
          final nothingCanLook = report.sources.isNotEmpty && reporting == 0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OperatorSection(
                title: 'Reach',
                subtitle: coverage.estate.label,
                trailing: _CollectButton(authority: authority),
                child: OperatorPanel(
                  tone: nothingCanLook ? OperatorTone.warn : null,
                  child: OperatorClear(
                    title: nothingCanLook
                        ? 'Nothing that could look at this estate can run'
                        : 'Nothing is on record for this estate',
                    detail: nothingCanLook
                        ? 'This is not a finding about the estate. Every '
                              'source below is unavailable, so Discovery has '
                              'not been able to observe anything either way.'
                        : coverage.estate == DiscoveryEstate.aura ||
                              coverage.estate == DiscoveryEstate.auraPlatform
                        ? 'Every source below reported, and found nothing. '
                              'Collect evidence to build the inventory.'
                        : 'This estate lives outside this database. Aura '
                              'observes it only through the providers below.',
                    icon: nothingCanLook
                        ? Icons.cloud_off_rounded
                        : Icons.travel_explore_rounded,
                  ),
                ),
              ),
              if (report.sources.isNotEmpty) ...[
                const SizedBox(height: AuraSpace.s16),
                _Sources(report: report),
              ],
            ],
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
                child: OperatorPanel(
                  child: OperatorClear(
                    title: coverage.privateByChoice > 0
                        ? 'Everything that should be listed is listed'
                        : 'Everything published is advertised',
                    detail: coverage.privateByChoice > 0
                        ? '${coverage.privateByChoice} '
                              '${coverage.privateByChoice == 1 ? 'person' : 'people'} '
                              'chose not to be listed by search engines. Their '
                              'profiles stay out of the sitemap until they opt in.'
                        : 'The sitemap and the published corpus agree.',
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
                                  family.label,
                                  style: const TextStyle(
                                    color: AuraSurface.ink,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                              Text(
                                '${family.advertised} listed of '
                                '${family.published}'
                                '${family.privateByChoice > 0 ? ' · ${family.privateByChoice} private by choice' : ''}',
                                style: TextStyle(
                                  color: family.gap > 0
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
/// How much of Discovery could actually look.
///
/// Stated as a sentence rather than a fraction, because "0 of 4" and "4 of 4"
/// are opposite conclusions and a bare ratio makes an operator do the reading.
String _reach(DiscoveryReport report) {
  final total = report.sources.length;
  if (total == 0) return 'No source is configured for this estate';
  final reporting = total - report.unavailable.length;
  if (reporting == 0) return 'No source can run — nothing was observed';
  if (reporting == total) {
    return total == 1 ? 'One source, and it ran' : 'All $total sources ran';
  }
  return '$reporting of $total sources ran · '
      '${report.unavailable.length} could not';
}

class _Sources extends StatelessWidget {
  const _Sources({required this.report});

  final DiscoveryReport report;

  @override
  Widget build(BuildContext context) {
    return OperatorSection(
      title: 'Where this comes from',
      subtitle: _reach(report),
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
                          // WHEN THIS SOURCE LAST SPOKE — A FACT, NOT A VERDICT.
                          //
                          // The payload has carried `lastFetchedAt` all along
                          // and nothing showed it, so an operator reading a
                          // coverage number could not tell whether the evidence
                          // behind it was from an hour ago or from last week.
                          //
                          // Said as the source's own reported fetch time and
                          // NOTHING MORE. This is deliberately not staleness:
                          // a provider that answered and reported nothing has
                          // reported a result, and calling that reading old
                          // would turn Bing's verified legitimate zero into a
                          // suspicion. A source with no credential has no fetch
                          // time at all and keeps only its reason.
                          if (source.lastFetchedAt != null)
                            Text(
                              'Last fetched '
                              '${AuraTemporal.humanize(ProductTime(source.lastFetchedAt!, TimeEvent.occurred))}',
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
        detail:
            'Aura reads its own published corpus, fetches its own sitemap, '
            'and probes its own canonical URLs the way a crawler would. '
            'Nothing is submitted anywhere and nothing outside Aura changes.',
        confirmLabel: 'Collect',
        consequences: [
          const OperatorConsequence(
            text: 'Evidence is written into Aura’s own tables.',
            icon: Icons.storage_rounded,
          ),
          const OperatorConsequence(
            text:
                'Raw evidence older than 90 days is deleted in the same '
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
          await ref.read(operatorDiscoveryRepositoryProvider).collect(estate);
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
      skipLoadingOnReload: true,
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
                for (final object in all.take(60)) _ObjectRow(object: object),
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

// ─────────────────────────────────────────────────────────────────────────────

/// THE WEEK IN ONE LINE (7 Nov 2026).
///
/// Discovery could say whether pages were reachable and not whether search
/// brought anybody. This is that answer: how often search showed the estate,
/// how often somebody chose it, how many visits came from a search engine, and
/// how many people joined — against the week before.
///
/// THE STEPS ARE COUNTED APART. "Joined" is every new member that week from
/// anywhere: Discovery never links a search or a visit to a person, and the
/// panel says so rather than letting the line read as a funnel.
class _Week extends ConsumerWidget {
  const _Week();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final week = ref.watch(discoveryWeekProvider);
    final estate = ref.watch(discoveryEstateProvider);

    return week.when(
      skipLoadingOnReload: true,
      loading: () => const OperatorSection(
        title: 'This week',
        child: OperatorLoading(lines: 2),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (w) {
        final now = w.week;
        if (!w.available || now == null) {
          return OperatorSection(
            title: 'This week',
            child: OperatorPanel(
              child: OperatorClear(
                title: 'No search numbers yet',
                detail:
                    w.reason ??
                    'No search engine has reported on this estate yet.',
                icon: Icons.query_stats_rounded,
              ),
            ),
          );
        }
        final before = w.previous;
        final name = estate.label;
        final steps = <String>[
          'Search showed $name ${_times(now.shown)}',
          'chosen ${_times(now.chosen)}',
          '${now.arrivalsFromSearch} '
              '${now.arrivalsFromSearch == 1 ? 'visit' : 'visits'} came from search',
          if (now.joined != null)
            '${now.joined} ${now.joined == 1 ? 'person' : 'people'} joined',
        ];

        return OperatorSection(
          title: 'This week',
          subtitle:
              '${_day(now.from)} – ${_day(now.to)} · search engines '
              'report about three days late, so the week ends there',
          child: OperatorPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  steps.join(' · '),
                  style: const TextStyle(
                    color: AuraSurface.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AuraSpace.s16),
                Wrap(
                  spacing: AuraSpace.s24,
                  runSpacing: AuraSpace.s12,
                  children: [
                    _WeekFigure(
                      label: 'Shown in search',
                      value: now.shown,
                      before: before?.shown,
                    ),
                    _WeekFigure(
                      label: 'Chosen',
                      value: now.chosen,
                      before: before?.chosen,
                      note: now.shown > 0
                          ? '${_percent(now.chosen, now.shown)} of showings'
                          : null,
                    ),
                    _WeekFigure(
                      label: 'Visits from search',
                      value: now.arrivalsFromSearch,
                      before: before?.arrivalsFromSearch,
                      note: '${now.arrivalsAll} visits in all',
                    ),
                    if (now.joined != null)
                      _WeekFigure(
                        label: 'Joined',
                        value: now.joined!,
                        before: before?.joined,
                      ),
                  ],
                ),
                const SizedBox(height: AuraSpace.s12),
                Text(
                  [
                    if (now.position != null)
                      'Average place in results: ${now.position!.toStringAsFixed(1)}'
                          '${before?.position != null ? ' (week before: ${before!.position!.toStringAsFixed(1)})' : ''}.',
                    if (now.joined != null)
                      'Joined counts everyone who joined that week, from '
                          'anywhere. Discovery never links a search to a person.',
                  ].join(' '),
                  style: const TextStyle(
                    color: AuraSurface.faint,
                    fontSize: 11.5,
                    height: 1.4,
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

class _WeekFigure extends StatelessWidget {
  const _WeekFigure({
    required this.label,
    required this.value,
    this.before,
    this.note,
  });

  final String label;
  final int value;
  final int? before;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final change = _change(value, before);
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: const TextStyle(
              color: AuraSurface.ink,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: AuraSurface.muted, fontSize: 11.5),
          ),
          if (change != null)
            Text(
              change,
              style: const TextStyle(color: AuraSurface.faint, fontSize: 11),
            ),
          if (note != null)
            Text(
              note!,
              style: const TextStyle(color: AuraSurface.faint, fontSize: 11),
            ),
        ],
      ),
    );
  }
}

String _times(int n) => n == 1 ? 'once' : '$n times';

String _percent(int part, int whole) {
  if (whole <= 0) return '0%';
  final p = part * 100 / whole;
  return p >= 10 || p == 0 ? '${p.round()}%' : '${p.toStringAsFixed(1)}%';
}

/// "up 60% on the week before", in words, or null when there is nothing to
/// compare with.
String? _change(int now, int? before) {
  if (before == null) return null;
  if (before == 0) {
    return now == 0 ? 'none the week before either' : 'none the week before';
  }
  if (now == before) return 'same as the week before';
  final pct = ((now - before).abs() * 100 / before).round();
  return '${now > before ? 'up' : 'down'} $pct% on the week before';
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _day(DateTime d) => '${d.day} ${_months[d.month - 1]}';

// ─────────────────────────────────────────────────────────────────────────────

/// WHAT PEOPLE SEARCHED FOR, SPLIT (7 Nov 2026).
///
/// One list mixed searches for Aura by name with searches for other products
/// that share the word ("aura dispatch platform", "auraportal"), so the
/// biggest numbers on the page were partly somebody else's. Now:
///   * searches for us by name, with where we ranked — if people search for
///     us and do not choose us, the title and description shown need work;
///   * what our pages are found FOR — searches that led to an article or a
///     post, which is what to write more of;
///   * everything else, set apart.
class _Searches extends ConsumerWidget {
  const _Searches();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searches = ref.watch(discoverySearchesProvider);
    final estate = ref.watch(discoveryEstateProvider);

    return searches.when(
      skipLoadingOnReload: true,
      loading: () => const OperatorSection(
        title: 'What people searched for',
        child: OperatorLoading(lines: 2),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (s) {
        if (s.items.isEmpty) {
          return OperatorSection(
            title: 'What people searched for',
            child: OperatorPanel(
              child: OperatorClear(
                title: s.withheld > 0
                    ? 'Every search is below the display floor'
                    : 'No search evidence',
                detail: s.withheld > 0
                    ? '${s.withheld} withheld. A search seen fewer than '
                          '${s.floor} times can identify the person who typed it.'
                    : 'No provider that reports search text is configured.',
                icon: Icons.search_off_rounded,
              ),
            ),
          );
        }
        final own = s.items.where((q) => q.ownName).toList();
        final other = s.items.where((q) => !q.ownName).toList();

        return OperatorSection(
          title: 'What people searched for',
          subtitle:
              'Last ${s.days} days. Aggregated and redacted. Never '
              'joined to an Aura member.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OperatorPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SplitLine(
                      label: 'For ${estate.label} by name',
                      totals: s.ownName,
                    ),
                    const SizedBox(height: AuraSpace.s8),
                    _SplitLine(
                      label: 'Everything else',
                      totals: s.other,
                      muted: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AuraSpace.s12),
              _SearchList(
                title: 'Searches for ${estate.label}',
                hint: 'Where you ranked, and how often people chose you.',
                items: own,
                empty:
                    'Nobody searched for ${estate.label} by name often '
                    'enough to show.',
              ),
              const SizedBox(height: AuraSpace.s12),
              _SearchList(
                title: 'What your pages are found for',
                hint:
                    'Searches that led to an article or a post — the '
                    'subjects people come to ${estate.label} for.',
                items: s.topics,
                showPage: true,
                empty:
                    'No article or post has been found by a search often '
                    'enough to show yet.',
              ),
              const SizedBox(height: AuraSpace.s12),
              _SearchList(
                title: 'Other searches',
                hint: 'Mostly other products and words that share the name.',
                items: other.take(10).toList(),
                muted: true,
                empty: 'None.',
              ),
              if (s.withheld > 0) ...[
                const SizedBox(height: AuraSpace.s8),
                Text(
                  '${s.withheld} withheld for being seen fewer than '
                  '${s.floor} times.',
                  style: const TextStyle(
                    color: AuraSurface.faint,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SplitLine extends StatelessWidget {
  const _SplitLine({
    required this.label,
    required this.totals,
    this.muted = false,
  });

  final String label;
  final DiscoverySearchTotals totals;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: muted ? AuraSurface.muted : AuraSurface.ink,
              fontSize: 13,
              fontWeight: muted ? FontWeight.w400 : FontWeight.w600,
            ),
          ),
        ),
        Text(
          '${totals.impressions} shown · ${totals.clicks} chosen'
          '${totals.impressions > 0 ? ' (${_percent(totals.clicks, totals.impressions)})' : ''}',
          style: TextStyle(
            color: muted ? AuraSurface.faint : AuraSurface.muted,
            fontSize: 12,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _SearchList extends StatelessWidget {
  const _SearchList({
    required this.title,
    required this.hint,
    required this.items,
    required this.empty,
    this.showPage = false,
    this.muted = false,
  });

  final String title;
  final String hint;
  final List<DiscoverySearch> items;
  final String empty;
  final bool showPage;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return OperatorPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AuraSurface.ink,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            hint,
            style: const TextStyle(color: AuraSurface.faint, fontSize: 11.5),
          ),
          const SizedBox(height: AuraSpace.s12),
          if (items.isEmpty)
            Text(
              empty,
              style: const TextStyle(color: AuraSurface.muted, fontSize: 12.5),
            ),
          for (final q in items)
            Padding(
              padding: const EdgeInsets.only(bottom: AuraSpace.s8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          q.query,
                          style: TextStyle(
                            color: muted ? AuraSurface.muted : AuraSurface.ink,
                            fontSize: 12.5,
                          ),
                        ),
                        if (showPage && q.pagePath != null)
                          Text(
                            q.pagePath!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AuraSurface.faint,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AuraSpace.s12),
                  Text(
                    [
                      '${q.impressions} shown',
                      '${q.clicks} chosen',
                      if (q.position != null)
                        'place ${q.position!.toStringAsFixed(1)}',
                    ].join(' · '),
                    style: TextStyle(
                      color: muted ? AuraSurface.faint : AuraSurface.muted,
                      fontSize: 12,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
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
