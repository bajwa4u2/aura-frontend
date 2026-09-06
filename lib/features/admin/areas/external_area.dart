/// EXTERNAL — the systems that build on Aura Meetings.
///
/// Aura Meetings is a meeting provider other companies integrate with. This is
/// the operator's side of that: admit a system, give it the customers it acts
/// for, hand it a credential, and be able to take the credential back.
///
/// THE SEQUENCE THIS SCREEN EXISTS TO MAKE POSSIBLE, in order, because doing it
/// out of order produces things that look right and are not:
///
///   1. ADMIT THE CONSUMER    — and, in the same act, issue its credential and
///                              webhook signing secret. Both are shown once.
///   2. PROVISION A TENANT    — one of that consumer's customers. A meeting
///                              belongs to a CUSTOMER, never loosely to the
///                              integration that created it.
///   3. PROVISION AN IDENTITY — the address counterparties book at, and the
///                              Aura member who will actually host.
///
/// WHAT THIS SCREEN REFUSES TO DO. It never shows a secret twice, because
/// Aura does not have one to show: the API secret is stored as a hash and the
/// signing secret is sealed. "Show it again" is not a missing feature, it is a
/// value that no longer exists. The dialog says so in those words rather than
/// leaving an operator hunting for a button.
///
/// THIS IS THE OPERATOR CONSOLE, AND IT IS NOT THE DEVELOPER CONSOLE.
///
/// Founder direction, 2026-09-06: Aura's operator console must never be
/// exposed as a customer's developer experience. This screen is AURA deciding
/// who may integrate. A customer managing its own integration — rotating its
/// own credential, changing its own webhook, reading its own usage — is a
/// different surface, for a different reader, under that customer's own
/// authority, and it does not exist yet.
///
/// Every fact shown here is already scoped to one consumer, so building that
/// customer view later needs no new authority model. What it must never do is
/// reuse this screen.
///
/// CERTIFICATION IS NOT REVENUE. A consumer marked as controlled certification
/// is excluded from every commercial total, and this screen says so on the row
/// rather than trusting anyone to remember which one it was.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../data/operator_external.dart';
import '../domain/operator_authority_provider.dart';
import '../domain/operator_capability.dart';
import '../ui/operator_kit.dart';

part 'external_area_actions.dart';

class ExternalArea extends ConsumerWidget {
  const ExternalArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consumers = ref.watch(operatorExternalConsumersProvider);
    final canWrite = ref.watch(
      hasOperatorCapabilityProvider(OperatorCapability.externalConsumersWrite),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final pad = constraints.maxWidth >= 900 ? AuraSpace.s20 : AuraSpace.s12;

        return consumers.when(
          loading: () => Padding(
            padding: EdgeInsets.all(pad),
            child: const OperatorLoading(lines: 4),
          ),
          error: (_, __) => Padding(
            padding: EdgeInsets.all(pad),
            child: OperatorFailure(
              title: 'The consumer list could not be loaded',
              detail: 'Nothing was changed. This is a read failure.',
              onRetry: () => ref.invalidate(operatorExternalConsumersProvider),
            ),
          ),
          data: (rows) => ListView(
            padding: EdgeInsets.all(pad),
            children: [
              _Header(canWrite: canWrite),
              const SizedBox(height: AuraSpace.s16),
              if (rows.isEmpty)
                const OperatorClear(
                  title: 'No external system has been admitted',
                  detail:
                      'Admitting one issues a credential that lets it create meetings '
                      'and read participation as Aura. Nothing else grants that.',
                )
              else
                for (final row in rows) ...[
                  _ConsumerCard(consumer: row, canWrite: canWrite),
                  const SizedBox(height: AuraSpace.s12),
                ],
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _Header extends ConsumerWidget {
  const _Header({required this.canWrite});

  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'External systems',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AuraSpace.s4),
              Text(
                'Systems holding a credential to act as Aura Meetings. '
                'A credential is shown once and cannot be recovered.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AuraSurface.muted),
              ),
            ],
          ),
        ),
        // The button is absent, not disabled, for an operator who cannot use
        // it. A disabled control still teaches that the action exists here and
        // invites a request for access to a thing they may have no business
        // doing.
        if (canWrite)
          FilledButton.icon(
            onPressed: () => _openCreate(context, ref),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Admit a system'),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ConsumerCard extends ConsumerWidget {
  const _ConsumerCard({required this.consumer, required this.canWrite});

  final ExternalConsumerRow consumer;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final credential = consumer.activeCredential;

    return OperatorPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(consumer.displayName, style: theme.textTheme.titleMedium),
              ),
              OperatorStatePill(
                state: consumer.status,
                tone: consumer.isActive ? OperatorTone.good : OperatorTone.warn,
              ),
            ],
          ),
          if (!consumer.countsTowardMarketMetrics) ...[
            const SizedBox(height: AuraSpace.s8),
            const _Note(
              icon: Icons.science_rounded,
              // Said on the row, not in a footnote. Somebody reading usage
              // numbers must see the exclusion at the same moment they see the
              // numbers.
              text: 'Controlled certification — excluded from every commercial total. '
                  'Its meetings are not customer revenue, adoption or ARR.',
            ),
          ],
          const SizedBox(height: AuraSpace.s12),
          Wrap(
            spacing: AuraSpace.s16,
            runSpacing: AuraSpace.s8,
            children: [
              _Stat(label: 'Meetings', value: '${consumer.meetingCount}'),
              _Stat(label: 'Events', value: '${consumer.eventCount}'),
              _Stat(
                label: 'Webhook',
                value: consumer.webhookUrl == null ? 'Not set' : 'Configured',
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s12),
          if (credential == null)
            const _Note(
              icon: Icons.key_off_rounded,
              text: 'No active credential. This system cannot authenticate.',
            )
          else
            _CredentialLine(credential: credential),
          const SizedBox(height: AuraSpace.s12),
          _TenantList(consumerId: consumer.id, canWrite: canWrite),
          if (canWrite) ...[
            const SizedBox(height: AuraSpace.s12),
            Wrap(
              spacing: AuraSpace.s8,
              runSpacing: AuraSpace.s8,
              children: [
                OutlinedButton(
                  onPressed: () => _openTenant(context, ref, consumer.id),
                  child: const Text('Provision customer'),
                ),
                OutlinedButton(
                  onPressed: () => _openWebhook(context, ref, consumer.id),
                  child: Text(
                    consumer.webhookUrl == null ? 'Set webhook' : 'Change webhook',
                  ),
                ),
                OutlinedButton(
                  onPressed: () => _openRotate(context, ref, consumer),
                  child: const Text('Rotate credential'),
                ),
                if (credential != null)
                  OutlinedButton(
                    onPressed: () => _confirmRevoke(context, ref, consumer, credential),
                    child: const Text('Revoke'),
                  ),
                OutlinedButton(
                  onPressed: () => _setStatus(
                    context,
                    ref,
                    consumer,
                    consumer.isActive ? 'SUSPENDED' : 'ACTIVE',
                  ),
                  child: Text(consumer.isActive ? 'Suspend' : 'Reinstate'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CredentialLine extends StatelessWidget {
  const _CredentialLine({required this.credential});

  final ExternalCredentialRow credential;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.key_rounded, size: 16),
            const SizedBox(width: AuraSpace.s8),
            // The key id, in full. It is the public half by design: it
            // identifies a credential in a support conversation without
            // revealing anything.
            Expanded(
              child: SelectableText(
                credential.keyId,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: AuraSurface.ink,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AuraSpace.s4),
        Text(
          credential.scopes.join(' · '),
          style: theme.textTheme.labelSmall?.copyWith(color: AuraSurface.muted),
        ),
        const SizedBox(height: AuraSpace.s4),
        Text(
          // THE MOST USEFUL LINE ON THE CARD. It is how an operator tells a
          // credential that was installed from one that was only issued —
          // which is the difference between an integration that exists and one
          // that is believed to.
          credential.lastUsedAt == null
              ? 'Never used — issued but not yet installed'
              : 'Last used ${_ago(credential.lastUsedAt!)}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: credential.lastUsedAt == null
                ? AuraSurface.muted
                : AuraSurface.ink,
          ),
        ),
      ],
    );
  }
}

class _TenantList extends ConsumerWidget {
  const _TenantList({required this.consumerId, required this.canWrite});

  final String consumerId;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenants = ref.watch(operatorExternalTenantsProvider(consumerId));
    final theme = Theme.of(context);

    return tenants.when(
      loading: () => const OperatorLoading(lines: 1),
      // A tenant read failing must not blank the consumer card: everything
      // above it is still true and still worth showing.
      error: (_, __) => Text(
        'Customers could not be loaded.',
        style: theme.textTheme.labelSmall?.copyWith(color: AuraSurface.muted),
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return Text(
            'No customers provisioned. This system can authenticate but has '
            'nobody to create meetings for.',
            style: theme.textTheme.labelSmall?.copyWith(color: AuraSurface.muted),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final t in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: AuraSpace.s8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.apartment_rounded, size: 16),
                    const SizedBox(width: AuraSpace.s8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${t.displayName}  ·  ${t.externalRef}',
                            style: theme.textTheme.bodySmall,
                          ),
                          Text(
                            t.identities.isEmpty
                                ? 'No address yet — cannot take bookings'
                                : t.identities
                                    .map((i) => i.isActive
                                        ? '/${i.slug}'
                                        : '/${i.slug} (retired)')
                                    .join('  '),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AuraSurface.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (canWrite)
                      TextButton(
                        onPressed: () =>
                            _openIdentity(context, ref, consumerId, t.externalRef),
                        child: const Text('Add address'),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── Small pieces ─────────────────────────────────────────────────────────

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: theme.textTheme.titleSmall),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(color: AuraSurface.muted),
        ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AuraSurface.muted),
        const SizedBox(width: AuraSpace.s8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: AuraSurface.muted),
          ),
        ),
      ],
    );
  }
}

String _ago(DateTime when) {
  final d = DateTime.now().difference(when);
  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes}m ago';
  if (d.inDays < 1) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}
