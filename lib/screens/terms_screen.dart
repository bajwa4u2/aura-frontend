import 'package:flutter/material.dart';

import '../core/ui/aura_card.dart';
import '../core/ui/aura_scaffold.dart';
import '../core/ui/aura_space.dart';
import '../core/ui/aura_surface.dart';
import '../core/ui/aura_text.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuraScaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.s16,
              AuraSpace.s16,
              AuraSpace.s16,
              AuraSpace.s24,
            ),
            children: [
              const AuraCard(
                child: _TermsBody(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TermsBody extends StatelessWidget {
  const _TermsBody();

  @override
  Widget build(BuildContext context) {
    final heading = AuraText.title;
    final body = AuraText.body;
    final muted = AuraText.small.copyWith(color: AuraSurface.muted);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Terms', style: heading),
        const SizedBox(height: AuraSpace.s8),
        Text(
          'These terms govern access to Aura and its public and member-facing surfaces.',
          style: muted,
        ),
        const SizedBox(height: AuraSpace.s20),
        Text('Use of the platform', style: heading),
        const SizedBox(height: AuraSpace.s8),
        Text(
          'Aura is provided for publishing, correspondence, discovery, and structured participation. You agree not to misuse the platform, interfere with its operation, or attempt unauthorized access to data, accounts, or protected areas.',
          style: body,
        ),
        const SizedBox(height: AuraSpace.s16),
        Text('Accounts and responsibility', style: heading),
        const SizedBox(height: AuraSpace.s8),
        Text(
          'You are responsible for the security of your account and for activity carried out through it. You must provide accurate information where required and keep credentials private.',
          style: body,
        ),
        const SizedBox(height: AuraSpace.s16),
        Text('Content and conduct', style: heading),
        const SizedBox(height: AuraSpace.s8),
        Text(
          'You retain responsibility for the material you publish or send through Aura. Content that is unlawful, deceptive, abusive, invasive, or structurally harmful to the service or its participants may be restricted or removed.',
          style: body,
        ),
        const SizedBox(height: AuraSpace.s16),
        Text('Availability and changes', style: heading),
        const SizedBox(height: AuraSpace.s8),
        Text(
          'Aura may evolve over time. Features, access conditions, and workflows may change as the platform develops. Reasonable efforts may be made to preserve continuity, but uninterrupted availability is not guaranteed.',
          style: body,
        ),
        const SizedBox(height: AuraSpace.s16),
        Text('Contact', style: heading),
        const SizedBox(height: AuraSpace.s8),
        Text(
          'Questions about these terms may be directed through the public contact route provided in the footer.',
          style: body,
        ),
      ],
    );
  }
}
