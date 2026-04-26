import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key, required this.handle});
  final String handle;

  @override
  Widget build(BuildContext context) {
    return AuraScaffold(
      title: 'Support',
      body: ListView(
        padding: EdgeInsets.fromLTRB(AuraSpace.s16, AuraSpace.s12, AuraSpace.s16, AuraSpace.s24),
        children: [
          AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Support @$handle', style: AuraText.title),
                SizedBox(height: AuraSpace.s8),
                Text(
                  'Phase 3 keeps support present, but not noisy. Payments are a later integration. '
                  'This screen is the stable place where support will live.',
                  style: AuraText.body.copyWith(height: 1.4),
                ),
              ],
            ),
          ),
          SizedBox(height: AuraSpace.s14),
          AuraCard(
            child: const _Tier(
              title: 'Patron',
              subtitle: 'Quiet monthly support',
              amount: '\$5 / month',
            ),
          ),
          SizedBox(height: AuraSpace.s12),
          AuraCard(
            child: const _Tier(
              title: 'Sustainer',
              subtitle: 'Carry the infrastructure',
              amount: '\$20 / month',
            ),
          ),
          SizedBox(height: AuraSpace.s12),
          AuraCard(
            child: const _Tier(
              title: 'Institution',
              subtitle: 'Ethics + systems partnership',
              amount: 'Request access',
            ),
          ),
          SizedBox(height: AuraSpace.s18),
          AuraPrimaryButton(
            label: 'Back',
            onPressed: () => context.pop(),
          ),
        ],
      ),
    );
  }
}

class _Tier extends StatelessWidget {
  const _Tier({required this.title, required this.subtitle, required this.amount});

  final String title;
  final String subtitle;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AuraText.body.copyWith(fontWeight: FontWeight.w700)),
        SizedBox(height: AuraSpace.s6),
        Text(subtitle, style: AuraText.body),
        SizedBox(height: AuraSpace.s10),
        Text(amount, style: AuraText.muted),
      ],
    );
  }
}
