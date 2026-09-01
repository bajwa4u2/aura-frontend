/// PLATFORM — is Aura well, and what is running out there?
///
/// WHAT WAS REMOVED, AND WHY
/// -------------------------
/// This area was the clearest case of re-facing the old world. It exposed a
/// policy document with seven switches — maintenance mode, public
/// registration, invite only, beta opt-in, and three institution-proof rules —
/// and a "Configuration" panel that printed whatever `PlatformSetting` held.
///
/// Live, that produced:
///
///   * a switch reading "Maintenance mode — Aura stops serving everybody",
///     shown ON, while Aura served every request;
///   * a Configuration panel dumping member ids, post ids and avatar URLs out
///     of a migration backup;
///   * `admin.policies` printed twice — once as switches, once as raw JSON.
///
/// A grep across the backend settles it: NOT ONE of those policy values is
/// read by any runtime path. They are stored, served and never consulted. A
/// control that changes nothing is not an operator control, and a governed
/// ceremony that promises "this takes effect for everybody at once" over an
/// inert field is worse than no control at all.
///
/// They are therefore GONE from the operator product and classified as legacy
/// configuration. Nothing was wired up to preserve them: wiring fake
/// consequence to keep a switch would be the same lie with more code behind it.
///
/// WHAT STAYS, BECAUSE RUNTIME ACTUALLY CONSUMES IT
/// ------------------------------------------------
///   HEALTH      the canonical projection — is Aura well?
///   FLEET       which released clients exist, on what channels, how stale
///   FLAGS       the three flags `posts.service` and the public-record router
///               genuinely read
///   RETENTION   media retention, which really runs and really deletes
library;

import 'package:flutter/material.dart';
import '../../../core/product/temporal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../data/admin_providers.dart';
import '../data/client_fleet.dart';
import '../domain/operator_authority_provider.dart';
import '../domain/operator_capability.dart';
import '../domain/operator_signal.dart';
import '../ui/operator_action.dart';
import '../ui/operator_kit.dart';
import '../ui/operator_states.dart';
import 'now_area.dart' show HealthCheckRow;

class PlatformArea extends ConsumerWidget {
  const PlatformArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authority = ref.watch(operatorAuthorityProvider).valueOrNull ??
        const OperatorAuthority.none();

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final pad = wide ? AuraSpace.s20 : AuraSpace.s12;

        return ListView(
          padding: EdgeInsets.fromLTRB(pad, pad, pad, AuraSpace.s32),
          children: [
            _Health(authority: authority),
            const SizedBox(height: AuraSpace.s24),
            _Fleet(authority: authority, wide: wide),
            const SizedBox(height: AuraSpace.s24),
            _Behaviour(authority: authority),
            const SizedBox(height: AuraSpace.s24),
            _Retention(authority: authority),
          ],
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// IS AURA WELL?
// ═════════════════════════════════════════════════════════════════════════════

class _Health extends ConsumerWidget {
  const _Health({required this.authority});

  final OperatorAuthority authority;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!authority.can(OperatorCapability.systemHealthRead)) {
      return const OperatorSection(
        title: 'Is Aura well?',
        child: OperatorInsufficientCapability(needs: 'system health'),
      );
    }

    final health = ref.watch(platformHealthProvider);

    return health.when(
      loading: () => const OperatorSection(
        title: 'Is Aura well?',
        child: OperatorLoading(lines: 2),
      ),
      error: (_, __) => OperatorSection(
        title: 'Is Aura well?',
        child: OperatorFailure(
          title: 'Health could not be read',
          detail: 'This is a read failure. It is not a statement about Aura.',
          onRetry: () => ref.invalidate(platformHealthProvider),
        ),
      ),
      data: (signal) => OperatorSignalView<PlatformHealth>(
        signal: signal,
        subject: 'platform health',
        unauthorizedNeeds: 'system health',
        onRetry: () => ref.invalidate(platformHealthProvider),
        builder: (context, value) => OperatorSection(
          title: 'Is Aura well?',
          subtitle: value.summary,
          child: OperatorPanel(
            tone: value.condition.isAdverse
                ? OperatorTone.danger
                : value.condition == OperatorCondition.attention
                    ? OperatorTone.warn
                    : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // EVERY dependency, worst first — this is the one screen
                // where the full picture belongs, unlike NOW where healthy
                // collapses to a line.
                for (final check in value.ordered)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AuraSpace.s8),
                    child: HealthCheckRow(check: check),
                  ),
                if (value.snapshotAt != null) ...[
                  const SizedBox(height: 2),
                  const Text(
                    'Checked when this page was opened.',
                    style: TextStyle(
                      color: AuraSurface.faint,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// WHAT IS RUNNING OUT THERE?
// ═════════════════════════════════════════════════════════════════════════════

/// The released-client fleet — server capability that had never been surfaced.
///
/// This is the question every release consequence turns on: which versions are
/// actually in people's hands, on which channels, how far behind, and what is
/// being refused.
class _Fleet extends ConsumerWidget {
  const _Fleet({required this.authority, required this.wide});

  final OperatorAuthority authority;
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!authority.can(OperatorCapability.analyticsRead)) {
      return const OperatorSection(
        title: 'What is running out there',
        child: OperatorInsufficientCapability(needs: 'analytics'),
      );
    }

    final fleet = ref.watch(clientFleetProvider);

    return fleet.when(
      loading: () => const OperatorSection(
        title: 'What is running out there',
        child: OperatorLoading(lines: 3),
      ),
      error: (e, _) => OperatorSection(
        title: 'What is running out there',
        child: OperatorFailure(
          title: 'Fleet observations could not be read',
          onRetry: () => ref.invalidate(clientFleetProvider),
        ),
      ),
      data: (f) {
        if (f.uniqueClients == 0) {
          return const OperatorSection(
            title: 'What is running out there',
            child: OperatorPanel(
              child: OperatorClear(
                title: 'No client has reported in this window',
                detail: 'That is not the same as a healthy fleet — it may '
                    'mean nothing is reporting.',
                icon: Icons.devices_other_rounded,
              ),
            ),
          );
        }

        final staleVersions =
            f.versions.where((v) => v.staleVsRecommended).toList();
        final refused =
            f.incompatible.fold<int>(0, (sum, i) => sum + i.count);

        return OperatorSection(
          title: 'What is running out there',
          subtitle: '${f.uniqueClients} '
              '${f.uniqueClients == 1 ? 'client' : 'clients'} over the last '
              '${(f.windowHours / 24).round()} days',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // WHAT NEEDS ATTENTION comes first, and only when there is any.
              if (refused > 0 || staleVersions.isNotEmpty) ...[
                OperatorPanel(
                  tone: refused > 0 ? OperatorTone.danger : OperatorTone.warn,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (refused > 0)
                        Text(
                          '$refused connection '
                          '${refused == 1 ? 'attempt was' : 'attempts were'} '
                          'refused as incompatible.',
                          style: const TextStyle(
                            color: AuraSurface.ink,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      if (staleVersions.isNotEmpty) ...[
                        if (refused > 0) const SizedBox(height: AuraSpace.s6),
                        Text(
                          '${staleVersions.length} '
                          '${staleVersions.length == 1 ? 'version is' : 'versions are'} '
                          'behind what Aura recommends.',
                          style: const TextStyle(
                            color: AuraSurface.ink,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AuraSpace.s12),
              ],
              OperatorPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final version in f.versions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AuraSpace.s10),
                        child: _VersionRow(version: version, total: f.uniqueClients),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow({required this.version, required this.total});

  final FleetVersion version;
  final int total;

  @override
  Widget build(BuildContext context) {
    final fraction = (version.percentage / 100).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Text(
                    version.appVersion ?? 'unknown version',
                    style: const TextStyle(
                      color: AuraSurface.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: AuraSpace.s8),
                  Text(
                    // How it was distributed, in the words the store uses.
                    '${version.distribution} · ${version.channel}',
                    style: const TextStyle(
                      color: AuraSurface.faint,
                      fontSize: 11.5,
                    ),
                  ),
                  if (version.staleVsRecommended) ...[
                    const SizedBox(width: AuraSpace.s8),
                    const OperatorStatePill(
                      state: 'BEHIND',
                      tone: OperatorTone.warn,
                      dense: true,
                    ),
                  ],
                ],
              ),
            ),
            Text(
              '${version.count}',
              style: const TextStyle(
                color: AuraSurface.muted,
                fontSize: 12.5,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: AuraSpace.s10),
            SizedBox(
              width: 38,
              child: Text(
                '${version.percentage.round()}%',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: AuraSurface.ink,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 3,
            backgroundColor: AuraSurface.divider,
            color: version.staleVsRecommended
                ? AuraSurface.warnInk
                : AuraSurface.accent,
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// WHAT BEHAVIOUR IS SWITCHED ON?
// ═════════════════════════════════════════════════════════════════════════════

/// Feature flags — the ONLY switches on this screen that runtime reads.
///
/// Verified by grep before being kept: `posts.service.ts` and
/// `public-record-routing.service.ts` genuinely consult these keys. The policy
/// document that used to sit beside them does not, and is gone.
///
/// The key is not the label. `PUBLIC_RECORD_ROUTING_ENABLED` is the server's
/// identifier; an operator needs to know what turning it off would stop.
class _Behaviour extends ConsumerWidget {
  const _Behaviour({required this.authority});

  final OperatorAuthority authority;

  /// What each flag GOVERNS, written for the person deciding.
  ///
  /// A flag with no entry still appears — with its key and an honest "what
  /// this governs is not documented here", which is better than hiding a live
  /// switch or captioning it with a guess.
  static const _governs = <String, (String, String)>{
    'PUBLIC_RECORD_ROUTING_ENABLED': (
      'Public record routing',
      'Whether posts are routed into the public record at all.',
    ),
    'PUBLIC_RECORD_INTENT_REQUIRED': (
      'Require intent for the public record',
      'Whether a person must state an intent before something enters the '
          'public record.',
    ),
    'CAN_RAISE_ISSUE_GATE_ENABLED': (
      'Raise-an-issue gate',
      'Whether the eligibility gate runs before somebody may raise an issue.',
    ),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!authority.can(OperatorCapability.settingsRead)) {
      return const OperatorSection(
        title: 'What behaviour is switched on',
        child: OperatorInsufficientCapability(needs: 'settings'),
      );
    }

    final flags = ref.watch(adminFeatureFlagsProvider);

    return flags.when(
      loading: () => const OperatorSection(
        title: 'What behaviour is switched on',
        child: OperatorLoading(lines: 2),
      ),
      error: (_, __) => OperatorSection(
        title: 'What behaviour is switched on',
        child: OperatorFailure(
          title: 'Flags could not be read',
          onRetry: () => ref.invalidate(adminFeatureFlagsProvider),
        ),
      ),
      data: (all) {
        if (all.isEmpty) {
          return const OperatorSection(
            title: 'What behaviour is switched on',
            child: OperatorPanel(
              child: OperatorClear(
                title: 'No behaviour is switched',
                detail: 'Everything Aura does is simply present.',
                icon: Icons.toggle_off_outlined,
              ),
            ),
          );
        }

        final canWrite = authority.can(OperatorCapability.settingsWrite);
        final on = all.where((f) => f.enabled).length;

        return OperatorSection(
          title: 'What behaviour is switched on',
          subtitle: '$on of ${all.length} on. Each of these changes what Aura '
              'does for the people it applies to.',
          child: OperatorPanel(
            child: Column(
              children: [
                for (final flag in all)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AuraSpace.s14),
                    child: _FlagRow(
                      flagKey: flag.key,
                      enabled: flag.enabled,
                      governs: _governs[flag.key],
                      description: flag.description,
                      onChange: canWrite
                          ? (next) => _toggle(context, ref, flag.key,
                              _governs[flag.key]?.$1 ?? flag.key, next)
                          : null,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    String key,
    String label,
    bool next,
  ) async {
    final done = await runOperatorAction(
      context,
      OperatorAction(
        title: next ? 'Turn on $label' : 'Turn off $label',
        subject: key,
        detail: 'This changes what Aura does for everyone the flag applies '
            'to, from the moment it is saved.',
        confirmLabel: next ? 'Turn on' : 'Turn off',
        destructive: !next,
        consequences: [
          OperatorConsequence(
            text: next
                ? 'The behaviour becomes available.'
                : 'The behaviour stops, including for people currently using '
                    'it.',
            tone: next ? OperatorTone.good : OperatorTone.warn,
            icon: next ? Icons.toggle_on_rounded : Icons.toggle_off_outlined,
          ),
          OperatorConsequence.recorded('This change'),
        ],
        perform: (_) async {
          await ref
              .read(adminRepositoryProvider)
              .updateFeatureFlag(key, enabled: next);
          return '$label is now ${next ? 'on' : 'off'}.';
        },
      ),
    );
    if (done) ref.invalidate(adminFeatureFlagsProvider);
  }
}

class _FlagRow extends StatelessWidget {
  const _FlagRow({
    required this.flagKey,
    required this.enabled,
    required this.governs,
    required this.description,
    required this.onChange,
  });

  final String flagKey;
  final bool enabled;
  final (String, String)? governs;
  final String? description;
  final ValueChanged<bool>? onChange;

  @override
  Widget build(BuildContext context) {
    final label = governs?.$1 ?? flagKey;
    final explanation = governs?.$2 ??
        description ??
        'What this governs is not documented here. It is live, and it is '
            'read by Aura at runtime.';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AuraSurface.ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                explanation,
                style: const TextStyle(
                  color: AuraSurface.muted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              if (governs != null) ...[
                const SizedBox(height: 4),
                // The key stays visible but subordinate: an operator reading a
                // log or talking to an engineer still needs it.
                Text(
                  flagKey,
                  style: const TextStyle(
                    color: AuraSurface.faint,
                    fontSize: 10.5,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: AuraSpace.s12),
        Switch(
          value: enabled,
          onChanged: onChange,
          activeThumbColor: AuraSurface.accent,
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// MEDIA RETENTION
// ═════════════════════════════════════════════════════════════════════════════

/// What retention is holding, as the server reports it.
class MediaRetentionStatus {
  const MediaRetentionStatus({
    required this.hasRun,
    required this.orphaned,
    required this.pendingDeletion,
    this.lastFinishedAt,
    this.trigger,
    this.deletedObjects = 0,
    this.skippedReferenced = 0,
    this.failed = 0,
    this.unresolvedKey = 0,
    this.dryRun = false,
    this.error,
  });

  /// Whether a pass has ever completed. Zeroes for a job that has never run
  /// would read as a healthy system with nothing to collect.
  final bool hasRun;

  final int orphaned;
  final int pendingDeletion;
  final DateTime? lastFinishedAt;
  final String? trigger;
  final int deletedObjects;
  final int skippedReferenced;

  /// The two numbers this surface exists for: rows the job could not resolve
  /// on its own. Everything else is the system doing its job quietly.
  final int failed;
  final int unresolvedKey;

  final bool dryRun;
  final String? error;

  bool get needsAttention => failed > 0 || unresolvedKey > 0 || error != null;

  factory MediaRetentionStatus.fromJson(Map<String, dynamic> json) {
    final body = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;
    final last = body['lastRun'] is Map
        ? Map<String, dynamic>.from(body['lastRun'] as Map)
        : const <String, dynamic>{};
    int i(dynamic v) => (v as num?)?.toInt() ?? 0;
    String? text(dynamic v) {
      final s = (v ?? '').toString().trim();
      return s.isEmpty ? null : s;
    }

    return MediaRetentionStatus(
      hasRun: body['hasRun'] == true,
      orphaned: i(body['orphaned']),
      pendingDeletion: i(body['pendingDeletion']),
      lastFinishedAt: DateTime.tryParse((last['finishedAt'] ?? '').toString()),
      trigger: text(last['trigger']),
      deletedObjects: i(last['deletedObjects']),
      skippedReferenced: i(last['skippedReferenced']),
      failed: i(last['failed']),
      unresolvedKey: i(last['unresolvedKey']),
      dryRun: last['dryRun'] == true,
      error: text(last['error']),
    );
  }
}

final mediaRetentionProvider =
    FutureProvider.autoDispose<MediaRetentionStatus>((ref) async {
  final res =
      await ref.watch(dioProvider).get('/v1/admin/media-cleanup/status');
  final data = res.data;
  return MediaRetentionStatus.fromJson(
    data is Map ? Map<String, dynamic>.from(data) : const {},
  );
});

/// FOUNDER RULING: "Never expose a naked destructive 'Run cleanup' button
/// merely because an endpoint exists."
///
/// So there is none. Retention runs nightly on its own; this reports whether
/// it is holding and names the rows it could not resolve. A manual pass exists
/// behind the governed ceremony, is offered only when a run would address
/// something, and runs a dry run first.
class _Retention extends ConsumerWidget {
  const _Retention({required this.authority});

  final OperatorAuthority authority;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!authority.can(OperatorCapability.settingsRead)) {
      return const SizedBox.shrink();
    }

    final status = ref.watch(mediaRetentionProvider);

    return status.when(
      loading: () => const OperatorSection(
        title: 'What Aura is collecting',
        child: OperatorLoading(lines: 2),
      ),
      error: (e, _) => OperatorSection(
        title: 'What Aura is collecting',
        child: OperatorFailure(
          title: 'Retention state could not be read',
          onRetry: () => ref.invalidate(mediaRetentionProvider),
        ),
      ),
      data: (r) {
        final canWrite = authority.can(OperatorCapability.settingsWrite);
        final worthRunning = r.orphaned > 0 || r.needsAttention || !r.hasRun;

        return OperatorSection(
          title: 'What Aura is collecting',
          // WHEN THE LAST PASS RAN, NOT ONLY THAT ONE DID.
          //
          // `lastFinishedAt` was parsed and never shown, so "Last pass ran on
          // schedule" read identically whether that pass finished last night or
          // three weeks ago — and those are opposite answers to "is the
          // orphaned count I am looking at worth acting on".
          //
          // Never-run keeps its own sentence. A pass that has never happened is
          // not an old pass, and giving it an age would be inventing one.
          subtitle: r.hasRun
              ? 'Media retention runs nightly. Last pass '
                  "${r.trigger == 'operator' ? 'was run by an operator' : 'ran on schedule'}"
                  '${r.lastFinishedAt == null ? '.' : ', ${AuraTemporal.humanize(ProductTime(r.lastFinishedAt!, TimeEvent.ended))}.'}'
              : 'Media retention runs nightly. No pass has completed yet.',
          child: OperatorPanel(
            tone: r.needsAttention ? OperatorTone.danger : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (r.error != null) ...[
                  Text(
                    'The last pass did not finish: ${r.error}',
                    style: const TextStyle(
                      color: AuraSurface.dangerInk,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: AuraSpace.s12),
                ],
                _Fact(
                  label: 'Awaiting collection',
                  value: '${r.orphaned} orphaned, ${r.pendingDeletion} '
                      'already deleted',
                ),
                if (r.hasRun) ...[
                  _Fact(
                    label: 'Last pass',
                    value: r.dryRun
                        ? 'Dry run — nothing was removed'
                        : '${r.deletedObjects} removed, '
                            '${r.skippedReferenced} still referenced',
                  ),
                  if (r.needsAttention)
                    _Fact(
                      label: 'Could not resolve',
                      value: '${r.failed} storage failures, '
                          '${r.unresolvedKey} unresolvable keys',
                    ),
                ],
                if (r.needsAttention) ...[
                  const SizedBox(height: AuraSpace.s8),
                  const Text(
                    'These rows stay where they are and the next pass retries '
                    'them. Nothing was lost.',
                    style: TextStyle(
                      color: AuraSurface.muted,
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                  ),
                ],
                if (canWrite && worthRunning) ...[
                  const SizedBox(height: AuraSpace.s16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: const Icon(Icons.play_arrow_rounded, size: 16),
                      label: const Text('Run a pass now'),
                      onPressed: () => _run(context, ref, r),
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

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    MediaRetentionStatus status,
  ) async {
    // A DRY RUN FIRST, always. The operator sees what a real pass would remove
    // before anything leaves storage.
    final preview = await runOperatorAction(
      context,
      OperatorAction(
        title: 'Preview a retention pass',
        subject: '${status.orphaned} orphaned media',
        detail: 'Nothing is deleted. This reports what a real pass would '
            'remove, so the decision is made against a number rather than a '
            'guess.',
        confirmLabel: 'Preview',
        consequences: [
          const OperatorConsequence(
            text: 'Nothing is removed.',
            tone: OperatorTone.good,
            icon: Icons.visibility_rounded,
          ),
        ],
        perform: (_) async {
          final res = await ref
              .read(dioProvider)
              .post('/v1/admin/media-cleanup/run', data: {'dryRun': true});
          final body = res.data is Map
              ? Map<String, dynamic>.from(res.data as Map)
              : const <String, dynamic>{};
          final would = (body['deletedObjects'] as num?)?.toInt() ?? 0;
          final kept = (body['skippedReferenced'] as num?)?.toInt() ?? 0;
          return 'A real pass would remove $would object'
              '${would == 1 ? '' : 's'} and keep $kept that are still '
              'referenced.';
        },
      ),
    );

    if (!preview || !context.mounted) return;
    ref.invalidate(mediaRetentionProvider);

    final done = await runOperatorAction(
      context,
      OperatorAction(
        title: 'Run a retention pass',
        subject: '${status.orphaned} orphaned media',
        detail: 'The job removes only rows with no live parent reference and '
            'only those past the retention threshold. It checks each one '
            'again as it goes.',
        confirmLabel: 'Run it',
        destructive: true,
        requiresReason: true,
        reasonLabel: 'Why this is being run now rather than tonight',
        consequences: [
          const OperatorConsequence(
            text: 'Storage objects with no live reference are deleted.',
            tone: OperatorTone.danger,
            icon: Icons.delete_forever_rounded,
          ),
          const OperatorConsequence(
            text: 'Anything still referenced is left exactly where it is.',
            tone: OperatorTone.good,
            icon: Icons.shield_rounded,
          ),
          OperatorConsequence.recorded('This pass and who ran it'),
        ],
        perform: (_) async {
          final res = await ref
              .read(dioProvider)
              .post('/v1/admin/media-cleanup/run', data: {'dryRun': false});
          final body = res.data is Map
              ? Map<String, dynamic>.from(res.data as Map)
              : const <String, dynamic>{};
          final removed = (body['deletedObjects'] as num?)?.toInt() ?? 0;
          return 'Removed $removed object${removed == 1 ? '' : 's'}. The pass '
              'is recorded.';
        },
      ),
    );
    if (done) ref.invalidate(mediaRetentionProvider);
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 148,
            child: Text(
              label,
              style: const TextStyle(color: AuraSurface.faint, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(color: AuraSurface.ink, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}
