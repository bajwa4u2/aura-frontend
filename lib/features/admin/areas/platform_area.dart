/// PLATFORM — health, the released-client fleet, and release governance.
///
/// This is operator platform governance, not developer tooling. The
/// convergence-report screen that used to live in this navigation was
/// engineering evidence for a one-off sign-off and does not belong to an
/// operator; it is retired from here.
///
/// The fleet section exists because the authority behind it already did and
/// nothing consumed it. It answers the question every release consequence
/// turns on: which versions are actually out there, and what is failing to
/// talk to us.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../data/admin_providers.dart';
import '../data/client_fleet.dart';
import '../domain/operator_authority_provider.dart';
import '../domain/operator_capability.dart';
import '../ui/operator_action.dart';
import '../ui/operator_kit.dart';

class PlatformArea extends ConsumerWidget {
  const PlatformArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authority = ref.watch(operatorAuthorityProvider).valueOrNull ??
        const OperatorAuthority.none();

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        return ListView(
          padding: EdgeInsets.all(wide ? AuraSpace.s20 : AuraSpace.s12),
          children: [
            if (authority.can(OperatorCapability.systemHealthRead))
              const _ServiceHealth()
            else
              const OperatorSection(
                title: 'Service health',
                child: OperatorInsufficientCapability(needs: 'system health'),
              ),
            const SizedBox(height: AuraSpace.s24),
            if (authority.can(OperatorCapability.analyticsRead))
              _Fleet(wide: wide)
            else
              const OperatorSection(
                title: 'Released clients',
                child: OperatorInsufficientCapability(needs: 'analytics'),
              ),
            // HEALTH FIRST, THEN GOVERNANCE. An operator opening PLATFORM is
            // usually asking whether something is wrong; the switches that
            // change what Aura does come after the answer, not before it.
            const SizedBox(height: AuraSpace.s24),
            _PolicyBlock(authority: authority),
            const SizedBox(height: AuraSpace.s24),
            _FeatureFlagBlock(authority: authority),
            const SizedBox(height: AuraSpace.s24),
            _MediaRetentionBlock(authority: authority),
            const SizedBox(height: AuraSpace.s24),
            _SettingsBlock(authority: authority),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ServiceHealth extends ConsumerWidget {
  const _ServiceHealth();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(adminHealthProvider);

    return health.when(
      loading: () => const OperatorSection(
        title: 'Service health',
        child: OperatorLoading(lines: 2),
      ),
      error: (e, _) => OperatorSection(
        title: 'Service health',
        child: OperatorFailure(
          title: 'Health could not be read',
          detail: 'Aura may be fine — this is the health check failing.',
          onRetry: () => ref.invalidate(adminHealthProvider),
        ),
      ),
      data: (h) {
        if (h == null) {
          return const OperatorSection(
            title: 'Service health',
            child: OperatorPanel(
              child: Text(
                'No health snapshot was returned. This is unknown, not healthy.',
                style: TextStyle(color: AuraSurface.muted, fontSize: 13),
              ),
            ),
          );
        }
        final services = <String, String>{
          'API': h.apiStatus,
          'Database': h.dbStatus,
          'Realtime': h.realtimeStatus,
          'Email': h.emailStatus,
          'Push': h.pushStatus,
        };
        // Degraded first. An operator opening PLATFORM is usually looking for
        // what is wrong, and making them read past four healthy rows to find
        // it is the wrong hierarchy.
        final ordered = services.entries.toList()
          ..sort((a, b) {
            final aOk = a.value.toLowerCase() == 'ok';
            final bOk = b.value.toLowerCase() == 'ok';
            if (aOk == bOk) return a.key.compareTo(b.key);
            return aOk ? 1 : -1;
          });
        final degraded =
            ordered.where((e) => e.value.toLowerCase() != 'ok').length;

        return OperatorSection(
          title: 'Service health',
          subtitle: degraded == 0
              ? 'All services healthy'
              : '$degraded of ${services.length} degraded',
          child: OperatorPanel(
            tone: degraded == 0 ? null : OperatorTone.danger,
            child: Column(
              children: [
                for (final entry in ordered)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AuraSpace.s10),
                    child: Row(
                      children: [
                        Icon(
                          entry.value.toLowerCase() == 'ok'
                              ? Icons.check_circle_rounded
                              : Icons.error_rounded,
                          size: 15,
                          color: entry.value.toLowerCase() == 'ok'
                              ? AuraSurface.goodInk
                              : AuraSurface.dangerInk,
                        ),
                        const SizedBox(width: AuraSpace.s10),
                        Expanded(
                          child: Text(
                            entry.key,
                            style: const TextStyle(
                                color: AuraSurface.ink, fontSize: 13),
                          ),
                        ),
                        OperatorStatePill(
                          state: entry.value.toUpperCase(),
                          tone: entry.value.toLowerCase() == 'ok'
                              ? OperatorTone.good
                              : OperatorTone.danger,
                          dense: true,
                        ),
                      ],
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

// ─────────────────────────────────────────────────────────────────────────────

class _Fleet extends ConsumerWidget {
  const _Fleet({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fleet = ref.watch(clientFleetProvider);

    return fleet.when(
      loading: () => const OperatorSection(
        title: 'Released clients',
        child: OperatorLoading(lines: 3),
      ),
      error: (e, _) => OperatorSection(
        title: 'Released clients',
        child: OperatorFailure(
          title: 'Fleet observations could not be read',
          onRetry: () => ref.invalidate(clientFleetProvider),
        ),
      ),
      data: (f) {
        if (f.isSilent) {
          // Silence is not health. A fleet reporting nothing may mean nobody
          // is running Aura, or may mean observation is broken.
          return const OperatorSection(
            title: 'Released clients',
            child: OperatorPanel(
              child: Text(
                'No client observations in this window. That is not the same '
                'as a healthy fleet — it may mean nothing is reporting.',
                style: TextStyle(
                    color: AuraSurface.muted, fontSize: 13, height: 1.4),
              ),
            ),
          );
        }

        final totalIncompatible =
            f.incompatible.fold<int>(0, (sum, i) => sum + i.count);

        return OperatorSection(
          title: 'Released clients',
          subtitle: '${f.uniqueClients} client'
              '${f.uniqueClients == 1 ? '' : 's'} seen over '
              '${(f.windowHours / 24).round()} days',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (totalIncompatible > 0) ...[
                OperatorPanel(
                  tone: OperatorTone.danger,
                  child: Row(
                    children: [
                      const Icon(Icons.phonelink_off_rounded,
                          size: 18, color: AuraSurface.dangerInk),
                      const SizedBox(width: AuraSpace.s12),
                      Expanded(
                        child: Text(
                          '$totalIncompatible incompatible connection '
                          'attempt${totalIncompatible == 1 ? '' : 's'} — '
                          'clients that could not talk to this server.',
                          style: const TextStyle(
                              color: AuraSurface.ink,
                              fontSize: 13,
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AuraSpace.s12),
              ],
              OperatorPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final d in f.distributions)
                      _FleetBar(
                        label: '${d.distribution} · ${d.channel}',
                        count: d.count,
                        percentage: d.percentage,
                      ),
                    if (f.stale.any((s) => s.staleCount > 0)) ...[
                      const SizedBox(height: AuraSpace.s12),
                      const Divider(color: AuraSurface.divider, height: 1),
                      const SizedBox(height: AuraSpace.s12),
                      const Text(
                        'RUNNING A STALE VERSION',
                        style: TextStyle(
                          color: AuraSurface.faint,
                          fontSize: 11,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AuraSpace.s8),
                      for (final s
                          in f.stale.where((s) => s.staleCount > 0))
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: AuraSpace.s6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${s.distribution} · ${s.channel}',
                                  style: const TextStyle(
                                      color: AuraSurface.ink, fontSize: 12.5),
                                ),
                              ),
                              Text(
                                '${s.staleCount}/${s.totalCount}',
                                style: const TextStyle(
                                  color: AuraSurface.warnInk,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
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

/// A proportion bar. A chart here earns its place: "which distribution is most
/// of our fleet" is a comparison, and a comparison reads faster as length than
/// as a column of numbers.
class _FleetBar extends StatelessWidget {
  const _FleetBar({
    required this.label,
    required this.count,
    required this.percentage,
  });

  final String label;
  final int count;
  final double percentage;

  @override
  Widget build(BuildContext context) {
    final fraction = (percentage / 100).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                      color: AuraSurface.ink, fontSize: 12.5),
                ),
              ),
              Text(
                '$count',
                style: const TextStyle(
                  color: AuraSurface.muted,
                  fontSize: 12,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: AuraSpace.s8),
              SizedBox(
                width: 44,
                child: Text(
                  '${percentage.toStringAsFixed(0)}%',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AuraSurface.accentText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s6),
          ClipRRect(
            borderRadius: BorderRadius.circular(AuraRadius.sm),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 5,
              backgroundColor: AuraSurface.elevated,
              color: AuraSurface.accent,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// HOW AURA IS SET
// ═════════════════════════════════════════════════════════════════════════════

/// POLICY — the rules Aura runs by.
///
/// Four policy families in one authority. They were a screen of nine hundred
/// lines of form; what an operator needs first is not a form but an answer to
/// "what is Aura doing right now", with the ability to change it second.
///
/// EVERY CHANGE IS A GOVERNED ACT. Maintenance mode and invite-only are
/// platform-wide switches whose consequence reaches every person using Aura,
/// so neither is a bare toggle that fires on touch.
class _PolicyBlock extends ConsumerWidget {
  const _PolicyBlock({required this.authority});

  final OperatorAuthority authority;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!authority.can(OperatorCapability.settingsRead)) {
      return const OperatorSection(
        title: 'Policy',
        child: OperatorInsufficientCapability(needs: 'settings'),
      );
    }

    final policies = ref.watch(adminPoliciesProvider);

    return policies.when(
      loading: () => const OperatorSection(
        title: 'Policy',
        child: OperatorLoading(lines: 3),
      ),
      error: (e, _) => OperatorSection(
        title: 'Policy',
        child: OperatorFailure(
          title: 'Policy could not be read',
          detail: '$e',
          onRetry: () => ref.invalidate(adminPoliciesProvider),
        ),
      ),
      data: (policy) {
        final canWrite = authority.can(OperatorCapability.settingsWrite);

        // THE TWO THAT REACH EVERYBODY. Lifted out of the family they belong
        // to because their consequence is categorically different: one stops
        // Aura, the other stops anyone new joining it.
        final gates = <_PolicySwitch>[
          _PolicySwitch(
            label: 'Maintenance mode',
            detail: 'Aura stops serving everybody.',
            value: policy.feature.maintenanceMode,
            severe: true,
            apply: (next) => policy.copyWith(
              feature: policy.feature.copyWith(maintenanceMode: next),
            ),
          ),
          _PolicySwitch(
            label: 'Public registration',
            detail: 'Whether anybody new can join without an invitation.',
            value: policy.feature.publicRegistrationEnabled,
            severe: true,
            apply: (next) => policy.copyWith(
              feature: policy.feature.copyWith(publicRegistrationEnabled: next),
            ),
          ),
          _PolicySwitch(
            label: 'Invite only',
            detail: 'Joining requires an invitation from somebody already '
                'here.',
            value: policy.feature.inviteOnlyMode,
            apply: (next) => policy.copyWith(
              feature: policy.feature.copyWith(inviteOnlyMode: next),
            ),
          ),
          _PolicySwitch(
            label: 'Beta opt-in',
            detail: 'Whether people may choose unreleased behaviour.',
            value: policy.feature.betaOptInEnabled,
            apply: (next) => policy.copyWith(
              feature: policy.feature.copyWith(betaOptInEnabled: next),
            ),
          ),
        ];

        final institution = <_PolicySwitch>[
          _PolicySwitch(
            label: 'Require email verification',
            detail: 'An institution must prove an address before it stands.',
            value: policy.institution.requireEmailVerification,
            apply: (next) => policy.copyWith(
              institution: policy.institution.copyWith(requireEmailVerification: next),
            ),
          ),
          _PolicySwitch(
            label: 'Require DNS proof',
            detail: 'An institution must prove the domain it claims.',
            value: policy.institution.requireDnsVerification,
            apply: (next) => policy.copyWith(
              institution: policy.institution.copyWith(requireDnsVerification: next),
            ),
          ),
          _PolicySwitch(
            label: 'Approve verified automatically',
            detail: 'A proven institution stands without an operator reading '
                'it. This removes a human from the decision.',
            value: policy.institution.autoApproveVerified,
            severe: true,
            apply: (next) => policy.copyWith(
              institution: policy.institution.copyWith(autoApproveVerified: next),
            ),
          ),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OperatorSection(
              title: 'What Aura is doing',
              subtitle: 'Platform-wide. Every person is affected.',
              child: OperatorPanel(
                tone: policy.feature.maintenanceMode
                    ? OperatorTone.danger
                    : null,
                child: Column(
                  children: [
                    for (final gate in gates)
                      _PolicyRow(
                        entry: gate,
                        canWrite: canWrite,
                        onChange: (next) =>
                            _change(context, ref, gate, next),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AuraSpace.s20),
            OperatorSection(
              title: 'What an institution must prove',
              child: OperatorPanel(
                child: Column(
                  children: [
                    for (final entry in institution)
                      _PolicyRow(
                        entry: entry,
                        canWrite: canWrite,
                        onChange: (next) =>
                            _change(context, ref, entry, next),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AuraSpace.s20),
            OperatorSection(
              title: 'Sessions and delivery',
              subtitle: 'Read here; changed through the policy authority.',
              child: OperatorPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PlatformFact(
                      label: 'Session timeout',
                      value: '${policy.security.sessionTimeoutMinutes} minutes',
                    ),
                    _PlatformFact(
                      label: 'Login attempts',
                      value: '${policy.security.maxLoginAttempts} before a '
                          'lockout',
                    ),
                    _PlatformFact(
                      label: 'Second factor',
                      value: policy.security.requireMfa
                          ? 'Required'
                          : 'Not required',
                    ),
                    _PlatformFact(
                      label: 'Email ceiling',
                      value: '${policy.communications.maxEmailsPerDay} a day',
                    ),
                    _PlatformFact(
                      label: 'Sender',
                      value: policy.communications.senderEmail,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _change(
    BuildContext context,
    WidgetRef ref,
    _PolicySwitch entry,
    bool next,
  ) async {
    final done = await runOperatorAction(
      context,
      OperatorAction(
        title: next ? 'Turn on ${entry.label}' : 'Turn off ${entry.label}',
        subject: 'Aura, platform-wide',
        detail: entry.detail,
        confirmLabel: next ? 'Turn on' : 'Turn off',
        destructive: entry.severe,
        requiresReason: entry.severe,
        reasonLabel: 'Why',
        consequences: [
          OperatorConsequence(
            text: entry.detail,
            tone: entry.severe ? OperatorTone.danger : OperatorTone.warn,
            icon: Icons.tune_rounded,
          ),
          const OperatorConsequence(
            text: 'This takes effect for everybody at once.',
            tone: OperatorTone.warn,
            icon: Icons.public_rounded,
          ),
          OperatorConsequence.recorded('This change'),
        ],
        perform: (_) async {
          await ref
              .read(adminRepositoryProvider)
              .updatePolicies(entry.apply(next));
          return '${entry.label} is now ${next ? 'on' : 'off'}.';
        },
      ),
    );
    if (done) ref.invalidate(adminPoliciesProvider);
  }
}

/// One policy switch, with what it means and how to set it.
class _PolicySwitch {
  const _PolicySwitch({
    required this.label,
    required this.detail,
    required this.value,
    required this.apply,
    this.severe = false,
  });

  final String label;
  final String detail;
  final bool value;

  /// Whether the consequence reaches everybody. Severe switches demand a
  /// recorded reason; ordinary ones do not.
  final bool severe;

  /// The whole policy with this one thing changed. The endpoint takes the
  /// whole document, so a partial update would silently reset its siblings.
  final AdminPolicy Function(bool next) apply;
}

class _PolicyRow extends StatelessWidget {
  const _PolicyRow({
    required this.entry,
    required this.canWrite,
    required this.onChange,
  });

  final _PolicySwitch entry;
  final bool canWrite;
  final ValueChanged<bool> onChange;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.label,
                  style: const TextStyle(
                    color: AuraSurface.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.detail,
                  style: const TextStyle(
                    color: AuraSurface.muted,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AuraSpace.s12),
          // The switch shows STATE. It never performs the change on touch —
          // it opens the ceremony, which is where the consequence is stated
          // and the reason recorded.
          Switch(
            value: entry.value,
            onChanged: canWrite ? onChange : null,
            activeThumbColor: AuraSurface.accent,
          ),
        ],
      ),
    );
  }
}

class _PlatformFact extends StatelessWidget {
  const _PlatformFact({required this.label, required this.value});

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
            width: 132,
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

// ═════════════════════════════════════════════════════════════════════════════

/// FEATURE FLAGS — what is switched on, and what it is for.
///
/// Kept separate from policy on purpose. A policy is a rule Aura is run by; a
/// flag is a piece of behaviour that is or is not present. Collapsing them
/// would make "maintenance mode" look like the same kind of decision as
/// "enable the new composer".
class _FeatureFlagBlock extends ConsumerWidget {
  const _FeatureFlagBlock({required this.authority});

  final OperatorAuthority authority;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!authority.can(OperatorCapability.settingsRead)) {
      return const SizedBox.shrink();
    }

    final flags = ref.watch(adminFeatureFlagsProvider);

    return flags.when(
      loading: () => const OperatorSection(
        title: 'Feature flags',
        child: OperatorLoading(lines: 2),
      ),
      error: (e, _) => OperatorSection(
        title: 'Feature flags',
        child: OperatorFailure(
          title: 'Flags could not be read',
          detail: '$e',
          onRetry: () => ref.invalidate(adminFeatureFlagsProvider),
        ),
      ),
      data: (all) {
        if (all.isEmpty) {
          return const OperatorSection(
            title: 'Feature flags',
            child: OperatorPanel(
              child: OperatorClear(
                title: 'No flag is defined',
                detail: 'Every behaviour Aura has is simply present.',
                icon: Icons.toggle_off_outlined,
              ),
            ),
          );
        }

        final canWrite = authority.can(OperatorCapability.settingsWrite);
        final on = all.where((f) => f.enabled).length;

        return OperatorSection(
          title: 'Feature flags',
          subtitle: '$on of ${all.length} on',
          child: OperatorPanel(
            child: Column(
              children: [
                for (final flag in all)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AuraSpace.s12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                flag.key,
                                style: const TextStyle(
                                  color: AuraSurface.ink,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (flag.description != null &&
                                  flag.description!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  flag.description!,
                                  style: const TextStyle(
                                    color: AuraSurface.muted,
                                    fontSize: 11.5,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: AuraSpace.s12),
                        Switch(
                          value: flag.enabled,
                          onChanged: canWrite
                              ? (next) => _toggle(context, ref, flag, next)
                              : null,
                          activeThumbColor: AuraSurface.accent,
                        ),
                      ],
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
    AdminFeatureFlag flag,
    bool next,
  ) async {
    final done = await runOperatorAction(
      context,
      OperatorAction(
        title: next ? 'Turn on ${flag.key}' : 'Turn off ${flag.key}',
        subject: flag.description ?? flag.key,
        detail: 'A flag changes what Aura does for the people it applies to. '
            'Aura Admin does not know who those are — the flag does.',
        confirmLabel: next ? 'Turn on' : 'Turn off',
        destructive: !next,
        consequences: [
          OperatorConsequence(
            text: next
                ? 'The behaviour becomes available.'
                : 'The behaviour stops being available, including to people '
                    'currently using it.',
            tone: next ? OperatorTone.good : OperatorTone.warn,
            icon: next
                ? Icons.toggle_on_rounded
                : Icons.toggle_off_outlined,
          ),
          OperatorConsequence.recorded('This change'),
        ],
        perform: (_) async {
          await ref
              .read(adminRepositoryProvider)
              .updateFeatureFlag(flag.key, enabled: next);
          return '${flag.key} is now ${next ? 'on' : 'off'}.';
        },
      ),
    );
    if (done) ref.invalidate(adminFeatureFlagsProvider);
  }
}

// ═════════════════════════════════════════════════════════════════════════════

/// SETTINGS — the values Aura was configured with.
///
/// READ-ONLY HERE, and deliberately. A settings row is an untyped key and an
/// arbitrary JSON value; a generic editor over that is a text box that can
/// break anything, offered to whoever is nearest. The ones that matter to an
/// operator have been given real controls above, under names that say what
/// they do. This is the rest, shown so nothing is hidden.
class _SettingsBlock extends ConsumerWidget {
  const _SettingsBlock({required this.authority});

  final OperatorAuthority authority;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!authority.can(OperatorCapability.settingsRead)) {
      return const SizedBox.shrink();
    }

    final settings = ref.watch(adminSettingsProvider);

    return settings.when(
      loading: () => const OperatorSection(
        title: 'Configuration',
        child: OperatorLoading(lines: 2),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (all) {
        if (all.isEmpty) return const SizedBox.shrink();
        return OperatorSection(
          title: 'Configuration',
          subtitle: 'Read-only. Named policy above is how these are changed.',
          child: OperatorPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final setting in all)
                  _PlatformFact(
                    label: setting.key,
                    value: '${setting.value}',
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

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
    this.orphanRetentionDays,
    this.error,
  });

  /// Whether a pass has ever completed. A surface that showed zeroes for a job
  /// that has never run would read as a healthy system with nothing to
  /// collect, which is the opposite of the truth.
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
  final int? orphanRetentionDays;
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
    return MediaRetentionStatus(
      hasRun: body['hasRun'] == true,
      orphaned: i(body['orphaned']),
      pendingDeletion: i(body['pendingDeletion']),
      lastFinishedAt:
          DateTime.tryParse((last['finishedAt'] ?? '').toString()),
      trigger: (last['trigger'] ?? '').toString().isEmpty
          ? null
          : last['trigger'].toString(),
      deletedObjects: i(last['deletedObjects']),
      skippedReferenced: i(last['skippedReferenced']),
      failed: i(last['failed']),
      unresolvedKey: i(last['unresolvedKey']),
      dryRun: last['dryRun'] == true,
      orphanRetentionDays: (last['orphanRetentionDays'] as num?)?.toInt(),
      error: (last['error'] ?? '').toString().isEmpty
          ? null
          : last['error'].toString(),
    );
  }
}

final mediaRetentionProvider =
    FutureProvider.autoDispose<MediaRetentionStatus>((ref) async {
  final res = await ref.watch(dioProvider).get('/v1/admin/media-cleanup/status');
  final data = res.data;
  return MediaRetentionStatus.fromJson(
    data is Map ? Map<String, dynamic>.from(data) : const {},
  );
});

/// MEDIA RETENTION — a system responsibility, reported.
///
/// FOUNDER RULING: "Never expose a naked destructive 'Run cleanup' button
/// merely because an endpoint exists."
///
/// So there is no such button. Retention runs nightly on its own; this says
/// whether it is holding and names the rows it could not resolve. The manual
/// pass exists behind the governed ceremony and is offered ONLY when there is
/// something a run would actually address — an operator running it against a
/// clean corpus is an operator being invited to perform a deletion for no
/// reason.
class _MediaRetentionBlock extends ConsumerWidget {
  const _MediaRetentionBlock({required this.authority});

  final OperatorAuthority authority;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!authority.can(OperatorCapability.settingsRead)) {
      return const SizedBox.shrink();
    }

    final status = ref.watch(mediaRetentionProvider);

    return status.when(
      loading: () => const OperatorSection(
        title: 'Media retention',
        child: OperatorLoading(lines: 2),
      ),
      error: (e, _) => OperatorSection(
        title: 'Media retention',
        child: OperatorFailure(
          title: 'Retention state could not be read',
          detail: '$e',
          onRetry: () => ref.invalidate(mediaRetentionProvider),
        ),
      ),
      data: (r) {
        final canWrite = authority.can(OperatorCapability.settingsWrite);
        // Something a pass would actually address. Without this, the control
        // is an invitation to delete for the sake of pressing something.
        final worthRunning = r.orphaned > 0 || r.needsAttention || !r.hasRun;

        return OperatorSection(
          title: 'Media retention',
          subtitle: r.hasRun
              ? 'Runs nightly. Last pass ${r.trigger == 'operator' ? 'was run by an operator' : 'ran on schedule'}.'
              : 'Runs nightly. No pass has completed yet.',
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
                _PlatformFact(
                  label: 'Awaiting collection',
                  value: '${r.orphaned} orphaned, ${r.pendingDeletion} '
                      'already deleted',
                ),
                if (r.hasRun) ...[
                  _PlatformFact(
                    label: 'Last pass',
                    value: r.dryRun
                        ? 'Dry run — nothing was removed'
                        : '${r.deletedObjects} removed, '
                            '${r.skippedReferenced} still referenced',
                  ),
                  if (r.needsAttention)
                    _PlatformFact(
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
    // before anything leaves storage — the endpoint has supported this from
    // the day it was written and no surface ever used it.
    final preview = await runOperatorAction(
      context,
      OperatorAction(
        title: 'Preview a retention pass',
        subject: '${status.orphaned} orphaned media',
        detail: 'Nothing is deleted. This reports what a real pass would '
            'remove, so the decision to run one is made against a number '
            'rather than a guess.',
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
