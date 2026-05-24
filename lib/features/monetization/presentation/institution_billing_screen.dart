import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/substrate_chip.dart';
import '../../institutions/ui/institution_ds.dart';
import '../data/monetization_repository.dart';
import '../domain/monetization_models.dart';
import '../providers/monetization_providers.dart';

/// Institution billing screen.
///
/// Pure display + trigger. Every value (plan list, prices, credit packs,
/// feature costs, member limits) comes from the backend's monetization config.
/// No prices, credit amounts, or limits are hardcoded.
class InstitutionBillingScreen extends ConsumerWidget {
  const InstitutionBillingScreen({super.key, required this.institutionId});

  final String institutionId;

  bool get _purchaseAllowed {
    if (kIsWeb) return true;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.android:
        return false;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(monetizationConfigProvider);
    final entitlementsAsync =
        ref.watch(institutionEntitlementProvider(institutionId));

    return AuraScaffold(
      showHeader: false,
      body: configAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => InsScreen(
          children: [
            const InsModeHeader(
              title: 'Plan & Billing',
              description:
                  'Manage your institution’s plan, credits, and feature usage.',
            ),
            const InsModeHeaderGap(),
            _ErrorState(message: e.toString()),
          ],
        ),
        data: (config) {
          if (config.mode == MonetizationMode.disabled) {
            return const InsScreen(
              children: [
                InsModeHeader(
                  title: 'Plan & Billing',
                  description:
                      'Manage your institution’s plan, credits, and feature usage.',
                ),
                InsModeHeaderGap(),
                _DisabledState(),
              ],
            );
          }

          return entitlementsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => InsScreen(
              children: [
                const InsModeHeader(
                  title: 'Plan & Billing',
                  description:
                      'Manage your institution’s plan, credits, and feature usage.',
                ),
                const InsModeHeaderGap(),
                _ErrorState(message: e.toString()),
              ],
            ),
            data: (ent) => InsScreen(
              children: [
                const InsModeHeader(
                  title: 'Plan & Billing',
                  description:
                      'Manage your institution’s plan, credits, and feature usage.',
                ),
                const InsModeHeaderGap(),
                _CurrentPlanCard(entitlements: ent),
                const SizedBox(height: AuraSpace.s14),
                _CreditBalanceCard(entitlements: ent),
                const SizedBox(height: AuraSpace.s14),
                _PlansSection(
                  config: config,
                  entitlements: ent,
                  purchaseAllowed: _purchaseAllowed,
                  onCheckout: (productCode) => _runPlanCheckout(
                    context: context,
                    ref: ref,
                    productCode: productCode,
                  ),
                ),
                const SizedBox(height: AuraSpace.s14),
                _CreditPacksSection(
                  config: config,
                  purchaseAllowed: _purchaseAllowed,
                  onCheckout: (productCode) => _runCreditsCheckout(
                    context: context,
                    ref: ref,
                    productCode: productCode,
                  ),
                ),
                const SizedBox(height: AuraSpace.s14),
                _FeatureCostsSection(costs: config.featureCosts),
                if (!_purchaseAllowed) ...[
                  const SizedBox(height: AuraSpace.s12),
                  const _MobilePurchaseNotice(),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _runPlanCheckout({
    required BuildContext context,
    required WidgetRef ref,
    required String productCode,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = ref.read(monetizationRepositoryProvider);
      final session = await repo.startInstitutionPlanCheckout(
        institutionId: institutionId,
        productCode: productCode,
      );
      await _openCheckout(messenger, session);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Checkout failed: $e')));
    }
  }

  Future<void> _runCreditsCheckout({
    required BuildContext context,
    required WidgetRef ref,
    required String productCode,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = ref.read(monetizationRepositoryProvider);
      final session = await repo.startInstitutionCreditsCheckout(
        institutionId: institutionId,
        productCode: productCode,
      );
      await _openCheckout(messenger, session);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Checkout failed: $e')));
    }
  }

  Future<void> _openCheckout(
    ScaffoldMessengerState messenger,
    CheckoutSession session,
  ) async {
    final url = session.url;
    if (url == null || url.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Provider did not return a checkout URL.')),
      );
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({required this.entitlements});
  final InstitutionEntitlements entitlements;

  @override
  Widget build(BuildContext context) {
    final memberLimit = entitlements.memberLimit;
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Current plan', style: AuraText.muted),
          const SizedBox(height: AuraSpace.s6),
          Text(entitlements.plan, style: AuraText.title),
          const SizedBox(height: AuraSpace.s10),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: [
              _Chip(
                label: entitlements.isVerified ? 'Verified' : 'Not verified',
              ),
              _Chip(
                label: entitlements.canSpeakOfficially
                    ? 'Official voice on'
                    : 'Official voice off',
              ),
              if (memberLimit != null)
                _Chip(label: 'Member limit: $memberLimit')
              else
                const _Chip(label: 'Members: unlimited'),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreditBalanceCard extends StatelessWidget {
  const _CreditBalanceCard({required this.entitlements});
  final InstitutionEntitlements entitlements;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Credit balance', style: AuraText.muted),
                const SizedBox(height: AuraSpace.s4),
                Text(
                  '${entitlements.creditBalance}',
                  style: AuraText.title,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlansSection extends StatelessWidget {
  const _PlansSection({
    required this.config,
    required this.entitlements,
    required this.purchaseAllowed,
    required this.onCheckout,
  });

  final MonetizationConfig config;
  final InstitutionEntitlements entitlements;
  final bool purchaseAllowed;
  final ValueChanged<String> onCheckout;

  @override
  Widget build(BuildContext context) {
    final paidPlans =
        config.plans.where((p) => p.productCode != null).toList(growable: false);

    if (paidPlans.isEmpty) return const SizedBox.shrink();

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Plans', style: AuraText.title),
          const SizedBox(height: AuraSpace.s8),
          for (final plan in paidPlans) ...[
            _PlanRow(
              plan: plan,
              isCurrent: plan.code == entitlements.plan,
              purchaseAllowed: purchaseAllowed,
              onCheckout: () => onCheckout(plan.productCode!),
            ),
            const SizedBox(height: AuraSpace.s10),
          ],
        ],
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.plan,
    required this.isCurrent,
    required this.purchaseAllowed,
    required this.onCheckout,
  });

  final PlanConfig plan;
  final bool isCurrent;
  final bool purchaseAllowed;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                plan.label,
                style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (isCurrent)
              const _Chip(label: 'Current')
            else if (purchaseAllowed)
              AuraPrimaryButton(label: 'Upgrade', onPressed: onCheckout)
            else
              const AuraPrimaryButton(label: 'Web only', onPressed: null),
          ],
        ),
        const SizedBox(height: AuraSpace.s4),
        Text(plan.description, style: AuraText.body),
        if (plan.memberLimit != null) ...[
          const SizedBox(height: AuraSpace.s4),
          Text('Up to ${plan.memberLimit} members', style: AuraText.muted),
        ],
      ],
    );
  }
}

class _CreditPacksSection extends StatelessWidget {
  const _CreditPacksSection({
    required this.config,
    required this.purchaseAllowed,
    required this.onCheckout,
  });

  final MonetizationConfig config;
  final bool purchaseAllowed;
  final ValueChanged<String> onCheckout;

  @override
  Widget build(BuildContext context) {
    final packs = config.creditPacks
        .where((p) => p.credits > 0)
        .toList(growable: false);
    if (packs.isEmpty) return const SizedBox.shrink();

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Credit packs', style: AuraText.title),
          const SizedBox(height: AuraSpace.s8),
          for (final pack in packs) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${pack.credits} credits',
                        style: AuraText.body.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (pack.displayPrice != null) ...[
                        const SizedBox(height: AuraSpace.s4),
                        Text(pack.displayPrice!, style: AuraText.muted),
                      ],
                    ],
                  ),
                ),
                if (purchaseAllowed)
                  AuraPrimaryButton(
                    label: 'Buy',
                    onPressed: () => onCheckout(pack.code),
                  )
                else
                  const AuraPrimaryButton(label: 'Web only', onPressed: null),
              ],
            ),
            const SizedBox(height: AuraSpace.s10),
          ],
        ],
      ),
    );
  }
}

class _FeatureCostsSection extends StatelessWidget {
  const _FeatureCostsSection({required this.costs});
  final FeatureCosts costs;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, int)>[
      ('AI editor (short)', costs.aiEditorShort),
      ('AI editor (long)', costs.aiEditorLong),
      ('Translation (short)', costs.translationShort),
      ('Translation (long)', costs.translationLong),
      ('Realtime audio / minute', costs.realtimeAudioPerMinute),
      ('Realtime video / minute', costs.realtimeVideoPerMinute),
    ];

    final visible = rows.where((r) => r.$2 > 0).toList(growable: false);
    if (visible.isEmpty) return const SizedBox.shrink();

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Feature costs', style: AuraText.title),
          const SizedBox(height: AuraSpace.s8),
          for (final r in visible)
            Padding(
              padding: const EdgeInsets.only(bottom: AuraSpace.s6),
              child: Row(
                children: [
                  Expanded(child: Text(r.$1, style: AuraText.body)),
                  Text('${r.$2} credits', style: AuraText.muted),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MobilePurchaseNotice extends StatelessWidget {
  const _MobilePurchaseNotice();

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Manage your plan on the web', style: AuraText.title),
          const SizedBox(height: AuraSpace.s6),
          Text(
            'Plan upgrades and credit packs are processed on '
            'app.auraplatform.org. Sign in there with the same '
            'account to update billing for this institution.',
            style: AuraText.body.copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _DisabledState extends StatelessWidget {
  const _DisabledState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AuraSpace.s24),
      child: AuraCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Billing unavailable', style: AuraText.title),
            SizedBox(height: AuraSpace.s6),
            Text(
              'Monetization is disabled in this environment.',
              style: AuraText.body,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AuraSpace.s24),
      child: AuraCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Could not load billing', style: AuraText.title),
            const SizedBox(height: AuraSpace.s6),
            Text(message, style: AuraText.body),
          ],
        ),
      ),
    );
  }
}

/// Billing-screen neutral chip — wraps canonical SubstrateChip.
class _Chip extends StatelessWidget {
  const _Chip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return SubstrateChip(label: label, state: SubstrateChipState.mist);
  }
}
