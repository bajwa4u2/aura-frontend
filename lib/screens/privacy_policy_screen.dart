import 'package:flutter/material.dart';

import '../core/ui/aura_design_system.dart';
import '../core/ui/aura_radius.dart';
import '../core/ui/aura_space.dart';
import '../core/ui/aura_surface.dart';
import '../core/ui/aura_text.dart';
import '../core/ui/document_scaffold.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DocumentScaffold(
      title: 'Privacy',
      maxWidth: 920,
      showSiteFooter: true,
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
      children: const [
        _PrivacyHero(),
        SizedBox(height: AuraSpace.lg),
        _SignalGrid(),
        SizedBox(height: AuraSpace.xl),
        _PrivacySection(
          number: '01',
          title: 'Information Aura collects',
          body:
              'Aura collects information needed to operate a secure communication platform, maintain account integrity, support institutions and spaces, deliver messages, and protect participants from abuse.',
          bullets: [
            'Account information such as name, email address, handle, profile details, authentication state, trusted-device status, and session records.',
            'Institution and space information needed to represent official identities, roles, memberships, permissions, invitations, and public profiles.',
            'Communication content you create or send through Aura, including messages, posts, attachments, updates, support requests, and moderation records.',
            'Contact import data you choose to provide, such as names and email addresses, so Aura can preview, deduplicate, resolve existing users, and help you send confirmed invitations.',
            'Technical and security records such as device, browser, IP, timestamps, request metadata, delivery logs, error logs, and abuse-prevention signals.',
          ],
        ),
        _PrivacySection(
          number: '02',
          title: 'Information Aura does not collect for exploitation',
          body:
              'Aura is designed around structural communication, not surveillance economics. Data should serve trust, continuity, safety, and user-directed workflows.',
          bullets: [
            'Aura does not build advertising profiles from your private communications.',
            'Aura does not sell personal information as a product.',
            'Aura does not create shadow profiles from imported contacts. Imported contacts remain tied to the importing user and the selected workflow.',
            'Aura does not use private messages as engagement-bait ranking material.',
            'Aura does not silently auto-invite contacts from imports or uploads.',
          ],
        ),
        _PrivacySection(
          number: '03',
          title: 'How Aura uses information',
          body:
              'Information is used to provide the platform, secure access, route communication, support institutions, enforce rules, and improve reliability without turning user activity into a manipulation engine.',
          bullets: [
            'Authenticate accounts, manage sessions, recognize trusted devices, and enforce revocations.',
            'Create and manage memberships, roles, invitations, spaces, institution profiles, and official communication surfaces.',
            'Send notifications, emails, invite messages, support replies, and product/service updates that are relevant to the user relationship.',
            'Detect abuse, investigate security issues, prevent spam, apply rate limits, and maintain audit logs.',
            'Debug reliability issues, improve accessibility, measure system health, and understand whether critical flows are functioning.',
          ],
        ),
        _PrivacySection(
          number: '04',
          title: 'Invitations and contact imports',
          body:
              'Invitations and contact imports are sensitive because they connect identity, access, and outreach. Aura treats them as explicit user-directed workflows.',
          bullets: [
            'Imported contacts must be previewed and selected before invitations are sent.',
            'Bulk paste and CSV imports should be deduplicated and normalized before use.',
            'Aura may check whether an imported email already belongs to an Aura user so the sender can choose the right invitation path.',
            'Invite tokens should be protected and governed by expiry, revocation, and usage limits.',
            'Email-bound invitations may require the accepting account email to match the invited email where the invite type requires it.',
          ],
        ),
        _PrivacySection(
          number: '05',
          title: 'Sharing and disclosure',
          body:
              'Aura shares information only where needed to operate the service, comply with law, protect the platform, or support a user-directed relationship.',
          bullets: [
            'With service providers that help operate infrastructure, email delivery, storage, security, analytics, support, and reliability tooling.',
            'With institutions, space administrators, or authorized members when role, membership, moderation, or workflow context requires it.',
            'When legally required, including valid legal process, regulatory obligations, safety investigations, or protection of rights and security.',
            'During a business transaction such as financing, merger, acquisition, restructuring, or asset transfer, subject to appropriate safeguards.',
          ],
        ),
        _PrivacySection(
          number: '06',
          title: 'AI-assisted systems',
          body:
              'Aura may use AI-assisted systems for operational support, moderation assistance, workflow clarity, safety review, and reliability improvements. AI should support human and institutional accountability rather than replace it.',
          bullets: [
            'AI may help classify, summarize, route, or review information when appropriate to the product flow.',
            'AI should not be treated as the final authority for serious access, enforcement, or legal decisions without appropriate review paths.',
            'Aura should avoid using AI as an opaque amplification engine for public visibility or social manipulation.',
          ],
        ),
        _PrivacySection(
          number: '07',
          title: 'Retention and deletion',
          body:
              'Aura retains information for as long as needed to provide the platform, preserve security, comply with obligations, resolve disputes, maintain moderation continuity, and support institutional record integrity.',
          bullets: [
            'Some records may be deleted or anonymized when no longer needed.',
            'Some records may be retained where required for security, audit, legal, moderation, billing, or institutional continuity reasons.',
            'Deleted content may persist temporarily in backups, logs, or systems where immediate removal is technically or legally impractical.',
          ],
        ),
        _PrivacySection(
          number: '08',
          title: 'Your choices and controls',
          body:
              'Aura should provide meaningful control without pretending that every operational or legal record can disappear instantly.',
          bullets: [
            'You may update account and profile information where product controls allow it.',
            'You may revoke trusted devices and manage active sessions where those controls are available.',
            'You may request account deletion or data assistance through Support, subject to legal, security, billing, and moderation constraints.',
            'You may choose whether to import contacts, which contacts to select, and when to send invitations.',
          ],
        ),
        _PrivacySection(
          number: '09',
          title: 'Security',
          body:
              'Aura uses reasonable technical and organizational safeguards to protect the platform. No system can guarantee absolute security, but Aura should minimize unnecessary exposure and enforce security controls consistently.',
          bullets: [
            'Session controls, trusted-device records, audit logs, rate limits, token hashing, and permission checks support account and access security.',
            'Users are responsible for maintaining secure credentials, protecting devices, and reporting suspected misuse.',
            'Security issues should be reported through the Support surface so they can be reviewed and addressed.',
          ],
        ),
        _PrivacySection(
          number: '10',
          title: 'Children, regions, and policy updates',
          body:
              'Aura is not intended to ignore legal obligations across user regions. The platform may adapt notices, rights, and workflows as the product matures and legal requirements evolve.',
          bullets: [
            'Aura is not designed for use by children where parental consent or special legal handling is required unless expressly supported by the product and law.',
            'Users in certain regions may have additional rights related to access, correction, deletion, portability, objection, or limitation of processing.',
            'Material privacy changes should be communicated clearly and should not hide major retroactive changes in data use.',
          ],
        ),
        _PrivacySection(
          number: '11',
          title: 'Questions and contact',
          body:
              'For questions about this Privacy Policy, to request data assistance, or to report a privacy concern, use the Support surface inside Aura.',
          bullets: [
            'Account and personal data requests should be submitted through Support.',
            'Security issues and suspected misuse should be reported through Support so they can be reviewed and addressed.',
            'Privacy policy changes will be communicated clearly and in advance of implementation where practical.',
          ],
        ),
        _ClosingCallout(),
      ],
    );
  }
}

class _PrivacyHero extends StatelessWidget {
  const _PrivacyHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.xl),
      decoration: BoxDecoration(
        gradient: AuraGradients.hero,
        borderRadius: BorderRadius.circular(AuraRadius.xl),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Privacy',
            style: AuraText.headline.copyWith(fontSize: 30),
          ),
          const SizedBox(height: AuraSpace.sm),
          Text(
            'Data minimization. Identity integrity. No surveillance incentives.',
            style: AuraText.emphasis.copyWith(color: AuraSurface.accentText),
          ),
          const SizedBox(height: AuraSpace.md),
          Text(
            'Aura handles data to protect access, preserve communication context, support institutions, and keep the platform reliable. The goal is not to extract attention from people — it is to make trusted communication possible.',
            style: AuraText.body.copyWith(height: 1.75),
          ),
          const SizedBox(height: AuraSpace.lg),
          Wrap(
            spacing: AuraSpace.sm,
            runSpacing: AuraSpace.sm,
            children: const [
              _PrivacyPill('Account security'),
              _PrivacyPill('Institution identity'),
              _PrivacyPill('Invite controls'),
              _PrivacyPill('Contact consent'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SignalGrid extends StatelessWidget {
  const _SignalGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final cards = const [
          _SignalCard(
            icon: Icons.verified_user_outlined,
            title: 'Privacy by role',
            body: 'Data access should follow identity, membership, role, and institution context.',
          ),
          _SignalCard(
            icon: Icons.person_add_alt_1_outlined,
            title: 'No silent outreach',
            body: 'Contact imports should require preview, deduplication, selection, and confirmation.',
          ),
          _SignalCard(
            icon: Icons.lock_outline,
            title: 'Security-first records',
            body: 'Sessions, invites, devices, and audit logs exist to protect trust and accountability.',
          ),
        ];

        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: cards
                .map((card) => Padding(
                      padding: const EdgeInsets.only(bottom: AuraSpace.sm),
                      child: card,
                    ))
                .toList(),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: cards
              .map((card) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: AuraSpace.sm),
                      child: card,
                    ),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _SignalCard extends StatelessWidget {
  const _SignalCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.md),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.lg),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AuraSurface.accentText, size: 22),
          const SizedBox(height: AuraSpace.sm),
          Text(title, style: AuraText.emphasis),
          const SizedBox(height: AuraSpace.xs),
          Text(body, style: AuraText.small.copyWith(height: 1.55)),
        ],
      ),
    );
  }
}

class _PrivacySection extends StatelessWidget {
  const _PrivacySection({
    required this.number,
    required this.title,
    required this.body,
    required this.bullets,
  });

  final String number;
  final String title;
  final String body;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionNumber(number),
          const SizedBox(width: AuraSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AuraText.title),
                const SizedBox(height: AuraSpace.sm),
                Text(body, style: AuraText.body.copyWith(height: 1.7)),
                const SizedBox(height: AuraSpace.md),
                ...bullets.map((item) => _Bullet(item)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionNumber extends StatelessWidget {
  const _SectionNumber(this.value);
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AuraSurface.elevated,
        borderRadius: BorderRadius.circular(AuraRadius.md),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Text(
        value,
        style: AuraText.label.copyWith(color: AuraSurface.accentText),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 9),
            decoration: const BoxDecoration(
              color: AuraSurface.accentText,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AuraSpace.sm),
          Expanded(
            child: Text(text, style: AuraText.body.copyWith(height: 1.6)),
          ),
        ],
      ),
    );
  }
}

class _PrivacyPill extends StatelessWidget {
  const _PrivacyPill(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.md,
        vertical: AuraSpace.xs,
      ),
      decoration: BoxDecoration(
        color: AuraSurface.accentSoft,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Text(
        label,
        style: AuraText.label.copyWith(color: AuraSurface.ink),
      ),
    );
  }
}

class _ClosingCallout extends StatelessWidget {
  const _ClosingCallout();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AuraSpace.sm),
      padding: const EdgeInsets.all(AuraSpace.lg),
      decoration: BoxDecoration(
        color: AuraSurface.elevated,
        borderRadius: BorderRadius.circular(AuraRadius.lg),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.privacy_tip_outlined, color: AuraSurface.accentText),
          const SizedBox(width: AuraSpace.md),
          Expanded(
            child: Text(
              'Privacy in Aura is structural, not performative. Data exists to protect the record, maintain accountable access, and support trusted communication — not to extract leverage from people.',
              style: AuraText.body.copyWith(height: 1.65),
            ),
          ),
        ],
      ),
    );
  }
}
