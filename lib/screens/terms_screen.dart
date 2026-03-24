import 'package:flutter/material.dart';

import '../core/ui/document_scaffold.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DocumentScaffold(
      title: 'Terms',
      child: _TermsBody(),
    );
  }
}

class _TermsBody extends StatelessWidget {
  const _TermsBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Doc.title('Terms'),
        const SizedBox(height: 10),
        Doc.meta('Use with identity, continuity, and visible responsibility.'),
        Doc.lede(
          'Aura is structured for accountable participation. Use of the platform assumes respect for identity integrity, lawful conduct, and the continuity of the shared record.',
        ),
        Doc.h('Use of the platform'),
        Doc.p(
          'You may use Aura only in ways that comply with applicable law, platform policy, and the basic integrity of the system. You may not use the service to impersonate, misrepresent institutional standing, evade moderation, or interfere with service operations.',
        ),
        Doc.h('Accounts and identity'),
        Doc.p(
          'You are responsible for the accuracy of your account information and for maintaining the security of your credentials. Aura may restrict, suspend, or remove access where identity integrity is compromised or where the system is used deceptively.',
        ),
        Doc.h('Content and responsibility'),
        Doc.p(
          'You retain responsibility for the material you publish, transmit, or preserve through Aura. The platform may apply moderation, workflow holds, or access restrictions when content or behavior threatens safety, lawful compliance, or the continuity of the record.',
        ),
        Doc.h('Institutional standing'),
        Doc.p(
          'Institutional surfaces carry additional responsibility. Access to institutional tools, domains, and announcements may be limited to verified or authorized participants, and may be revised where standing changes or documentation is insufficient.',
        ),
        Doc.h('Availability and changes'),
        Doc.p(
          'Aura may evolve over time. Features, policies, and workflows may change as the platform matures, provided those changes are made in a clear and structurally honest way.',
        ),
        Doc.h('Termination'),
        Doc.p(
          'Aura may suspend or terminate access where necessary to protect system integrity, legal compliance, or user safety. Users may also choose to leave the service subject to moderation, record-retention, and lawful requirements.',
        ),
        Doc.h('Limitation'),
        Doc.p(
          'The service is provided on an evolving basis. While Aura is built carefully, no platform can guarantee uninterrupted service or absolute immunity from error, abuse, or external disruption.',
        ),
        Doc.callout(
          'Aura is not built for velocity at any cost. Participation here assumes a quieter bargain: identity should mean something, and the record should remain answerable.',
        ),
      ],
    );
  }
}
