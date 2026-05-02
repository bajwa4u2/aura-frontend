import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/ui/aura_design_system.dart';
import '../core/ui/aura_radius.dart';
import '../core/ui/aura_space.dart';
import '../core/ui/aura_surface.dart';
import '../core/ui/aura_text.dart';
import '../core/ui/document_scaffold.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DocumentScaffold(
      title: 'Terms',
      maxWidth: 920,
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
        const _LegalHero(),
        const SizedBox(height: AuraSpace.lg),
        const _TermsMap(),
        const SizedBox(height: AuraSpace.lg),
        _Section(
          eyebrow: '01',
          title: 'Acceptance of these terms',
          body:
              'By accessing Aura, creating an account, joining an institution or space, publishing content, sending messages, participating in calls, or using any public or member-facing service, you agree to these Terms. If you use Aura on behalf of an institution, organization, company, or public body, you represent that you have authority to act for that entity.',
        ),
        _Section(
          eyebrow: '02',
          title: 'What Aura is built for',
          body:
              'Aura is a structured social and civic communication platform for identity-bound participation, institutional representation, messaging, announcements, support, and accountable public communication. The platform is designed for durable communication, not manipulation, spam, impersonation, or engagement abuse.',
        ),
        _Section(
          eyebrow: '03',
          title: 'Accounts, identity, and access',
          body:
              'You are responsible for maintaining accurate account information, protecting your credentials, and using only accounts and identities you are authorized to use. Institution identities must represent the institution truthfully. You may not impersonate people, institutions, officials, organizations, or communities, or use Aura to create misleading authority.',
          bullets: const [
            'Keep login credentials, trusted devices, and recovery access secure.',
            'Do not share accounts or bypass session, device, or access controls.',
            'Do not use institution tools unless you are authorized to represent that institution.',
          ],
        ),
        _Section(
          eyebrow: '04',
          title: 'Invites, memberships, and roles',
          body:
              'Invites, memberships, and role assignments are access-control mechanisms. You may not transfer, sell, automate, or misuse invite links or access rights. Aura may restrict or revoke invitations, memberships, trusted devices, sessions, or roles where misuse, risk, or unauthorized access is detected.',
        ),
        _Section(
          eyebrow: '05',
          title: 'Content and communication standards',
          body:
              'You are responsible for the content you publish, submit, send, upload, or transmit through Aura. This includes public posts, replies, messages, attachments, calls, institutional announcements, support requests, profile content, and imported contact data. You must not use Aura to post or transmit unlawful, deceptive, abusive, exploitative, invasive, defamatory, spammy, malicious, or structurally harmful material.',
          bullets: const [
            'Do not harass, threaten, exploit, or target people or institutions.',
            'Do not upload malware, deceptive files, illegal material, or content you lack rights to use.',
            'Do not use automation to scrape, spam, manipulate visibility, or overload services.',
          ],
        ),
        _Section(
          eyebrow: '06',
          title: 'Institution and public-interest use',
          body:
              'Institutional participation must be accurate, accountable, and authorized. Institutions are responsible for the announcements, memberships, spaces, messages, support workflows, and public representations they operate through Aura. Aura may require verification or additional review before enabling or continuing institution-level features.',
        ),
        _Section(
          eyebrow: '07',
          title: 'Contact imports and outreach',
          body:
              'If you import contacts, paste emails, upload CSV files, or send invitations, you are responsible for having a lawful and appropriate basis to do so. You must not use Aura for unsolicited bulk outreach, deceptive invitations, purchased contact lists, or communication that violates applicable anti-spam, privacy, or consent rules.',
        ),
        _Section(
          eyebrow: '08',
          title: 'Platform enforcement',
          body:
              'Aura may review, limit, remove, label, preserve, suspend, restrict, or revoke access to content, accounts, invites, institutions, spaces, devices, sessions, or workflows where required to protect users, institutions, platform integrity, legal obligations, or the public record. Enforcement may include human review and technical safeguards.',
        ),
        _Section(
          eyebrow: '09',
          title: 'Service availability and changes',
          body:
              'Aura is evolving. Features, routes, interfaces, membership workflows, storage behavior, moderation tools, AI assistance, notification delivery, calls, support channels, and institution services may change over time. We work to preserve continuity, but Aura is provided without a guarantee of uninterrupted, error-free, or permanently available operation.',
        ),
        _Section(
          eyebrow: '10',
          title: 'Payments, patrons, supporters, and investors',
          body:
              'Any paid, supporter, patron, investor, or partnership-related program is governed by the terms shown for that program at the time of participation. Public recognition, early access, contribution status, or support participation does not create ownership, governance authority, employment, endorsement, or guaranteed access unless expressly agreed in a separate written agreement.',
        ),
        _Section(
          eyebrow: '11',
          title: 'Privacy and data',
          body:
              'Aura handles data according to the Privacy Policy. By using Aura, you acknowledge that account data, content, messages, attachments, access logs, security records, moderation records, institution records, support records, and operational metadata may be processed to run, secure, improve, and enforce the platform.',
        ),
        _Section(
          eyebrow: '12',
          title: 'Intellectual property',
          body:
              'You retain ownership of content you own, but you grant Aura the rights needed to host, transmit, display, store, secure, moderate, and operate that content within the platform. Aura, its product design, software, brand, infrastructure, and platform materials remain Aura property or the property of their respective owners.',
        ),
        _Section(
          eyebrow: '13',
          title: 'Disclaimers and liability limits',
          body:
              'Aura is provided on an “as available” basis to the fullest extent permitted by law. We do not guarantee that every communication will be delivered instantly, that every feature will remain unchanged, or that every issue will be resolved in a specific timeframe. To the fullest extent permitted by law, Aura is not liable for indirect, incidental, special, consequential, punitive, or lost-profit damages arising from use of the platform.',
        ),
        _Section(
          eyebrow: '14',
          title: 'Termination',
          body:
              'You may stop using Aura at any time. Aura may suspend, restrict, or terminate access where required for security, misuse, legal compliance, institutional integrity, nonpayment, policy enforcement, or platform protection. Some records may be retained where necessary for legal, security, moderation, audit, or continuity reasons.',
        ),
        _Section(
          eyebrow: '15',
          title: 'Updates to these terms',
          body:
              'These Terms may be updated as Aura matures. Material changes should be presented clearly. Continued use of Aura after updated Terms become effective means you accept the updated Terms.',
        ),
        const SizedBox(height: AuraSpace.md),
        _ActionPanel(
          onPrivacy: () => context.go('/privacy'),
          onSupport: () => context.go('/support/agent'),
        ),
      ],
    );
  }
}

class _LegalHero extends StatelessWidget {
  const _LegalHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AuraSpace.lg),
      decoration: BoxDecoration(
        gradient: AuraGradients.card,
        borderRadius: BorderRadius.circular(AuraRadius.lg),
        border: Border.all(color: AuraSurface.divider),
        boxShadow: AuraShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _IconBadge(icon: Icons.gavel_outlined),
              const SizedBox(width: AuraSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Terms of Service', style: AuraText.title),
                    const SizedBox(height: AuraSpace.xs),
                    Text(
                      'The operating rules for Aura’s public, member, institution, messaging, invitation, and support surfaces.',
                      style: AuraText.body.copyWith(height: 1.6),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.md),
          Wrap(
            spacing: AuraSpace.sm,
            runSpacing: AuraSpace.sm,
            children: const [
              _SignalPill(label: 'Accountable identity'),
              _SignalPill(label: 'Institution integrity'),
              _SignalPill(label: 'Safe communication'),
              _SignalPill(label: 'No misuse'),
            ],
          ),
          const SizedBox(height: AuraSpace.md),
          Text(
            'Last updated: May 2026',
            style: AuraText.small.copyWith(color: AuraSurface.muted),
          ),
        ],
      ),
    );
  }
}

class _TermsMap extends StatelessWidget {
  const _TermsMap();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final cards = [
          const _MapCard(
            icon: Icons.verified_user_outlined,
            title: 'Identity rules',
            body: 'Accounts, institution authority, sessions, roles, and access must stay truthful and authorized.',
          ),
          const _MapCard(
            icon: Icons.forum_outlined,
            title: 'Communication rules',
            body: 'Posts, replies, messages, calls, files, and invites must not be abusive, deceptive, or harmful.',
          ),
          const _MapCard(
            icon: Icons.balance_outlined,
            title: 'Platform rights',
            body: 'Aura may enforce limits, preserve records, and change features to protect integrity and safety.',
          ),
        ];

        if (compact) {
          return Column(
            children: cards
                .map((card) => Padding(
                      padding: const EdgeInsets.only(bottom: AuraSpace.sm),
                      child: card,
                    ))
                .toList(),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: cards
              .map(
                (card) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: AuraSpace.sm),
                    child: card,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _MapCard extends StatelessWidget {
  const _MapCard({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: double.infinity,
      padding: const EdgeInsets.all(AuraSpace.md),
      decoration: BoxDecoration(
        color: AuraSurface.elevated,
        borderRadius: BorderRadius.circular(AuraRadius.md),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AuraSurface.accent, size: AuraIconSize.lg),
          const SizedBox(height: AuraSpace.sm),
          Text(title, style: AuraText.emphasis),
          const SizedBox(height: AuraSpace.xs),
          Text(body, style: AuraText.small.copyWith(height: 1.55)),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.eyebrow,
    required this.title,
    required this.body,
    this.bullets = const [],
  });

  final String eyebrow;
  final String title;
  final String body;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AuraSpace.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AuraSurface.elevated,
              borderRadius: BorderRadius.circular(AuraRadius.sm),
              border: Border.all(color: AuraSurface.divider),
            ),
            child: Text(
              eyebrow,
              style: AuraText.small.copyWith(
                color: AuraSurface.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AuraSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AuraText.emphasis.copyWith(fontSize: 16)),
                const SizedBox(height: AuraSpace.sm),
                Text(body, style: AuraText.body.copyWith(height: 1.7)),
                if (bullets.isNotEmpty) ...[
                  const SizedBox(height: AuraSpace.sm),
                  Doc.bullets(bullets),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({required this.onPrivacy, required this.onSupport});

  final VoidCallback onPrivacy;
  final VoidCallback onSupport;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AuraSpace.md),
      decoration: BoxDecoration(
        color: AuraSurface.elevated,
        borderRadius: BorderRadius.circular(AuraRadius.md),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Need the related policy?', style: AuraText.emphasis),
          const SizedBox(height: AuraSpace.xs),
          Text(
            'Privacy explains how data is handled. Support is the correct route for questions, reports, and account requests.',
            style: AuraText.small.copyWith(color: AuraSurface.muted, height: 1.55),
          ),
          const SizedBox(height: AuraSpace.md),
          Wrap(
            spacing: AuraSpace.sm,
            runSpacing: AuraSpace.sm,
            children: [
              _InlineAction(label: 'Read Privacy', icon: Icons.privacy_tip_outlined, onTap: onPrivacy),
              _InlineAction(label: 'Contact Support', icon: Icons.support_agent_outlined, onTap: onSupport),
            ],
          ),
        ],
      ),
    );
  }
}

class _InlineAction extends StatelessWidget {
  const _InlineAction({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: AuraIconSize.sm),
      label: Text(label),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: AuraGradients.accent,
        borderRadius: BorderRadius.circular(AuraRadius.md),
        boxShadow: AuraShadows.glow,
      ),
      child: Icon(icon, color: Colors.white, size: AuraIconSize.lg),
    );
  }
}

class _SignalPill extends StatelessWidget {
  const _SignalPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AuraSpace.sm, vertical: 6),
      decoration: BoxDecoration(
        color: AuraSurface.elevated,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Text(label, style: AuraText.small.copyWith(color: AuraSurface.muted)),
    );
  }
}
