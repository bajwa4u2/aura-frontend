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

  Widget _benefitCard({
    required String title,
    required String text,
  }) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(text, style: AuraText.body),
        ],
      ),
    );
  }

  Widget _hero(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'For institutions',
            style: _headlineStyle(context).copyWith(fontSize: 30),
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(
            'Aura offers institutions a quieter kind of public presence: one built for continuity, accountability, and readable record rather than noise.',
            style: AuraText.body,
          ),
        ],
      ),
    );
  }

  Widget _whyAura() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Why institutions enter here',
          style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AuraSpace.s10),
        _benefitCard(
          title: 'A lasting public record',
          text:
              'Institutional statements, clarifications, and responses remain readable over time instead of dissolving into feed churn.',
        ),
        const SizedBox(height: AuraSpace.s10),
        _benefitCard(
          title: 'Clear institutional voice',
          text:
              'Aura distinguishes between a person speaking personally and a person speaking while carrying institutional authority.',
        ),
        const SizedBox(height: AuraSpace.s10),
        _benefitCard(
          title: 'A calmer environment',
          text:
              'This space is designed for continuity, responsibility, and serious communication rather than volume, reach, and reaction loops.',
        ),
      ],
    );
  }

  Widget _entryCard(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Institution access',
            style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(
            'Institutions may sign in with approved institutional credentials or begin by creating an institutional account.',
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
                  onPressed: () => context.go('/institution/create'),
                  child: Text(
                    'Create institutional account',
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

  Widget _differenceCard() {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What makes Aura different',
            style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(
            'Aura is not built around velocity, promotion, or algorithmic attention. It gives institutions a place to speak with continuity, maintain public memory, and act under visible responsibility.',
            style: AuraText.body,
          ),
        ],
      ),
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
          Doc.meta('Institutional presence with continuity and accountable voice.'),
          Doc.lede(
            'Aura gives institutions a distinct place to stand, speak, and remain legible over time.',
          ),
          const SizedBox(height: AuraSpace.s12),
          _hero(context),
          const SizedBox(height: AuraSpace.s12),
          _whyAura(),
          const SizedBox(height: AuraSpace.s12),
          _differenceCard(),
          const SizedBox(height: AuraSpace.s12),
          _entryCard(context),
        ],
      ),
    );
  }
}