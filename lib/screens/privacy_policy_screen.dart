import 'package:flutter/material.dart';

import '../core/ui/document_scaffold.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DocumentScaffold(
      title: 'Privacy',
      child: _PrivacyBody(),
    );
  }
}

class _PrivacyBody extends StatelessWidget {
  const _PrivacyBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Doc.title('Privacy'),
        const SizedBox(height: 10),
        Doc.meta('Data minimization. Identity integrity. No surveillance incentives.'),
        Doc.lede(
          'Aura collects only what is necessary to preserve identity integrity, moderation continuity, and structural record.',
        ),

        Doc.h('What we collect'),
        Doc.bullets([
          'Account identity information (email, handle, profile data)',
          'Authentication and session data required for secure access',
          'Posts, replies, and related moderation records',
          'Limited technical logs for security and abuse prevention',
        ]),

        Doc.h('What we do not collect'),
        Doc.bullets([
          'Behavioral tracking for advertising purposes',
          'Public engagement analytics as social scoreboards',
          'Shadow profiles or off-platform surveillance data',
        ]),

        Doc.h('How data is used'),
        Doc.p(
          'Data is used to maintain account integrity, enforce moderation policies, preserve chronological record, and prevent abuse. It is not used to optimize engagement velocity or manipulate visibility.',
        ),

        Doc.h('AI usage'),
        Doc.p(
          'AI systems may assist with structural tasks such as moderation support, pattern detection, and workflow efficiency. AI is not used as an amplification engine and does not determine public visibility through opaque ranking mechanisms.',
        ),

        Doc.h('Data retention'),
        Doc.p(
          'Records are retained to preserve continuity, moderation accountability, and lawful compliance. Where deletion is permitted, it follows structured review rather than silent erasure.',
        ),

        Doc.h('User control'),
        Doc.p(
          'Users may update profile information and request account deletion subject to legal and moderation constraints. Certain records may remain where required for structural continuity or lawful obligation.',
        ),

        Doc.h('Security'),
        Doc.p(
          'Aura implements reasonable technical and organizational safeguards to protect account data and system integrity. No system can guarantee absolute security, but the architecture is designed to minimize unnecessary exposure.',
        ),

        Doc.h('Policy updates'),
        Doc.p(
          'Privacy commitments may evolve as the platform matures. Material changes will be reflected clearly and without hidden retroactive shifts in data use.',
        ),

        Doc.callout(
          'Privacy in Aura is structural, not performative. Data exists to protect the record, not to extract leverage from it.',
        ),
      ],
    );
  }
}