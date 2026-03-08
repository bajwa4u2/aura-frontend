import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/ui/aura_card.dart';
import '../core/ui/aura_space.dart';
import '../core/ui/aura_text.dart';
import '../core/ui/document_scaffold.dart';

class InstitutionsHubScreen extends StatelessWidget {
  const InstitutionsHubScreen({super.key});

  TextStyle _headlineStyle(BuildContext context) {
    return (Theme.of(context).textTheme.headlineMedium ?? AuraText.body)
        .copyWith(fontWeight: FontWeight.w700);
  }

  Widget _statusChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s10,
        vertical: AuraSpace.s6,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _hero(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Institutions in Aura',
            style: _headlineStyle(context).copyWith(fontSize: 28),
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(
            'Institutional participation exists through a distinct lane with separate credentials, governed verification, and accountable standing.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s12),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: [
              _statusChip('Separate institution entry'),
              _statusChip('Governed verification'),
              _statusChip('Continuity of record'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _entryCard(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Institution entry',
            style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AuraSpace.s10),
          Text(
            'Institutions enter Aura through their own credential lane. '
            'Verification establishes bounded identity and accountable participation.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.go('/institution/sign-in'),
                  child: Text('Institution sign in', style: AuraText.body),
                ),
              ),
              const SizedBox(width: AuraSpace.s10),
              Expanded(
                child: FilledButton(
                  onPressed: () =>
                      context.go('/institution/request-verification'),
                  child: Text(
                    'Request verification',
                    style: AuraText.body.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _principles() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Doc.h('What institutions can do here'),
        Doc.bullets([
          'Maintain verified institutional identity',
          'Enter through a governed credential lane',
          'Issue institutional statements under accountable standing',
          'Preserve institutional speech as public memory',
        ]),
        Doc.h('What institutions cannot do here'),
        Doc.bullets([
          'Use public member entry as a substitute for institution access',
          'Purchase reach or algorithmic visibility',
          'Hide responsibility behind anonymous brand voice',
          'Convert institutional presence into promotional volume',
        ]),
        Doc.callout(
          'Institution participation is governed presence. It is not a branding shortcut.',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DocumentScaffold(
      title: 'Institutions',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Doc.title('Institutions'),
          const SizedBox(height: 10),
          Doc.meta('Separate institutional entry and governed participation.'),
          Doc.lede(
            'Institutions participate in Aura through a distinct lane with verification, bounded identity, and accountable presence.',
          ),
          const SizedBox(height: AuraSpace.s12),
          _hero(context),
          const SizedBox(height: AuraSpace.s12),
          _entryCard(context),
          const SizedBox(height: AuraSpace.s12),
          Doc.p(
            'Institutions need their own bounded place to stand. '
            'This lane exists so institutional presence stays legible, verified, '
            'and distinct from ordinary public member entry.',
          ),
          _principles(),
        ],
      ),
    );
  }
}