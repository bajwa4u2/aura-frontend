import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/ui/aura_design_system.dart';
import '../core/ui/aura_radius.dart';
import '../core/ui/aura_space.dart';
import '../core/ui/aura_surface.dart';
import '../core/ui/aura_text.dart';
import '../core/ui/document_scaffold.dart';

/// Aura's published Child Safety Standards.
///
/// This page is intentionally public, unauthenticated, indexable, and
/// non-editable. It exists to satisfy the Google Play "social platform"
/// child-safety policy requirement and to make Aura's CSAM/exploitation
/// stance, reporting paths, and enforcement commitments legible to
/// users, institutions, regulators, and reviewers.
class ChildSafetyScreen extends StatelessWidget {
  const ChildSafetyScreen({super.key});

  static const String safetyEmail = 'safety@auraplatform.org';

  @override
  Widget build(BuildContext context) {
    return const DocumentScaffold(
      title: 'Child Safety',
      maxWidth: 920,
      showSiteFooter: true,
      child: _ChildSafetyBody(),
    );
  }
}

class _ChildSafetyBody extends StatelessWidget {
  const _ChildSafetyBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SafetyHero(),
        const SizedBox(height: AuraSpace.lg),
        const _SafetySignalGrid(),
        const SizedBox(height: AuraSpace.xl),
        const _SafetySection(
          number: '01',
          title: 'Our commitment to child safety',
          body:
              'Aura is a public-discourse and institutional-communication platform. We hold a zero-tolerance position toward content and behavior that endangers minors. Sexual exploitation of children is one of the most serious harms an online platform can host, and Aura treats it accordingly — as a hard line, enforced consistently, with no exceptions for context, satire, or claims of artistic merit.',
          bullets: [
            'Aura prohibits child sexual abuse material (CSAM) in every form, including imagery, video, audio, text descriptions, AI-generated material, links, references, and solicitation.',
            'Aura prohibits the exploitation, sexualization, sextortion, or trafficking of minors.',
            'Aura prohibits grooming behavior, including any pattern of contact, coercion, or isolation directed at a minor.',
            'Aura prohibits sharing personal information of minors in ways that could endanger them.',
            'Aura prohibits accounts, communities, institutions, or coordinated efforts dedicated to harming minors.',
          ],
        ),
        const _SafetySection(
          number: '02',
          title: 'Prohibited content and behavior',
          body:
              'The following are explicitly prohibited on Aura. This list is illustrative, not exhaustive — moderation teams may act on any conduct that endangers a minor whether or not it appears verbatim below.',
          bullets: [
            'Producing, possessing, requesting, distributing, linking to, or soliciting CSAM.',
            'Sexualized depictions of minors, including photorealistic, illustrated, computer-generated, or AI-synthesized imagery.',
            'Grooming, including building inappropriate trust with a minor, attempting to move conversations to private channels for sexual purposes, or normalizing harmful conduct.',
            'Sextortion, blackmail, threats, or coercion involving a minor.',
            'Trafficking, recruitment, or facilitation of exploitation of a minor.',
            'Doxxing or publishing non-public information about a minor in a manner that could enable harm.',
            'Promoting, glorifying, or instructing others on how to commit any of the above.',
          ],
        ),
        const _SafetySection(
          number: '03',
          title: 'How to report a child-safety concern',
          body:
              'Reporting is available to anyone — Aura users, institutions, parents, guardians, educators, researchers, and the public. You do not need an account to report CSAM or grooming. Reports are routed to Aura’s Trust & Safety review queue and are treated with priority.',
          bullets: [
            'In-app: use the report control on any post, reply, message, profile, institution, or space. Select a child-safety reason where applicable so the report enters the priority queue.',
            'Email: write to safety@auraplatform.org with a description, the affected URL or username if known, and any context that helps reviewers act quickly.',
            'Emergency: if you believe a child is in immediate danger, contact local emergency services first, then report to Aura. We will cooperate with the investigating authority.',
            'Anonymous reports are accepted. Reporters are not required to identify themselves to Aura.',
          ],
        ),
        const _SafetySection(
          number: '04',
          title: 'How we review reports',
          body:
              'Reports flagged as child-safety concerns are surfaced ahead of routine moderation work. Aura combines automated detection signals with human review by Trust & Safety reviewers trained on child-protection policy. Reviewers operate under documented playbooks so that decisions are consistent, auditable, and not driven by individual reviewer discretion.',
          bullets: [
            'Automated systems pre-flag suspected CSAM, grooming patterns, and known abusive media so they can be removed quickly and routed for human review.',
            'Trust & Safety reviewers verify, classify, and act on reports, including borderline and ambiguous cases.',
            'Confirmed CSAM is preserved in a controlled, access-restricted form only as necessary to meet legal preservation duties; the underlying material is removed from public surfaces immediately.',
            'Decisions are logged so enforcement can be reviewed, audited, and corrected if a mistake is identified.',
          ],
        ),
        const _SafetySection(
          number: '05',
          title: 'Enforcement actions',
          body:
              'Where a child-safety violation is confirmed, Aura applies the strongest available remedies. Enforcement is not negotiable and is not subject to the standard appeals path used for ordinary policy disputes.',
          bullets: [
            'Immediate removal of the offending content from public, member, institution, and direct surfaces.',
            'Account suspension or permanent termination of every Aura identity associated with the conduct.',
            'Revocation of trusted devices, sessions, invitations, and institution roles tied to the actor.',
            'Termination of institutional accounts that produce, host, or fail to act on child-safety violations under their authority.',
            'Preservation of records — including content, metadata, and access logs — required for legal reporting and investigation.',
            'Referral to the National Center for Missing & Exploited Children (NCMEC) and applicable law-enforcement authorities where required by law.',
          ],
        ),
        const _SafetySection(
          number: '06',
          title: 'Cooperation with law enforcement',
          body:
              'Aura cooperates with valid legal requests from law-enforcement agencies investigating child exploitation. We respond to lawful process, preserve records when properly requested, and proactively report suspected CSAM through the channels available to platforms.',
          bullets: [
            'Reports of apparent CSAM are submitted to NCMEC where Aura is required or permitted to do so.',
            'Aura responds to subpoenas, court orders, search warrants, and emergency-disclosure requests from competent authorities.',
            'Investigators may contact Aura at safety@auraplatform.org for child-safety matters; legal process should be served through the channels published in our legal contact.',
            'Aura preserves account, content, and access records as required by law when a valid preservation request is received.',
          ],
        ),
        const _SafetySection(
          number: '07',
          title: 'Moderation and Trust & Safety operations',
          body:
              'Aura operates a moderation and Trust & Safety function whose mandate explicitly includes child protection. Moderation is not advisory — it has the authority to remove content, restrict surfaces, and end accounts. Institutions on Aura are also responsible for moderating the surfaces they administer and may be held accountable for repeated child-safety failures within their authority.',
          bullets: [
            'Continuous review of public posts, replies, direct messages, institution announcements, profiles, spaces, calls, and uploaded media for child-safety violations.',
            'Proactive detection signals — including hash-matching against known abusive media where lawful and appropriate — augment, but do not replace, human review.',
            'Repeat-offender controls block re-registration patterns associated with confirmed child-safety actors.',
            'Trust & Safety reviewers are supported with documented policy, escalation paths, and well-being safeguards appropriate to the work.',
          ],
        ),
        const _SafetySection(
          number: '08',
          title: 'Age, account integrity, and minors on Aura',
          body:
              'Aura is built for accountable adult communication, including institutional and civic participation. The platform applies controls intended to keep accounts truthful and to limit exposure of minors to inappropriate behavior.',
          bullets: [
            'Accounts must represent a real person or a legitimately authorized institution; impersonation and identity laundering are prohibited.',
            'Aura does not knowingly permit registration by users below the age required by applicable law in their region.',
            'Where an account is reported to belong to a minor in violation of applicable law, Aura reviews and acts on that report.',
            'Parents, guardians, and educators may submit child-safety concerns through any channel listed above; they are not required to be Aura users.',
          ],
        ),
        const _SafetySection(
          number: '09',
          title: 'No tolerance for evasion',
          body:
              'Attempts to evade Aura’s child-safety enforcement are themselves violations. This includes coded language, link-laundering, off-platform handoffs, ban-evasion accounts, and attempts to coordinate exploitation across surfaces. Reviewers are authorized to act on the substance of conduct, not only on its surface form.',
        ),
        const _SafetySection(
          number: '10',
          title: 'Updates to this policy',
          body:
              'These standards may be updated as legal obligations evolve, as new abuse patterns emerge, and as Aura’s detection and review capabilities improve. Material changes will be reflected on this page. The substance of the commitment — zero tolerance for CSAM and exploitation of minors — does not change.',
        ),
        const SizedBox(height: AuraSpace.md),
        const _SafetyContactCallout(),
        const SizedBox(height: AuraSpace.lg),
        _SafetyActionPanel(
          onPrivacy: () => context.go('/privacy'),
          onTerms: () => context.go('/terms'),
        ),
      ],
    );
  }
}

class _SafetyHero extends StatelessWidget {
  const _SafetyHero();

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: AuraGradients.accent,
                  borderRadius: BorderRadius.circular(AuraRadius.md),
                  boxShadow: AuraShadows.glow,
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: Colors.white,
                  size: AuraIconSize.lg,
                ),
              ),
              const SizedBox(width: AuraSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Child Safety Standards',
                      style: AuraText.headline.copyWith(fontSize: 30),
                    ),
                    const SizedBox(height: AuraSpace.xs),
                    Text(
                      'Zero tolerance for CSAM, exploitation, grooming, trafficking, and abuse of minors.',
                      style: AuraText.emphasis.copyWith(
                        color: AuraSurface.accentText,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.md),
          Text(
            'These standards explain what Aura prohibits, how reports are handled, what enforcement looks like, how we cooperate with law enforcement, and how to contact our Trust & Safety team. They apply across every Aura surface — public posts, replies, messages, institutions, spaces, calls, profiles, and uploads.',
            style: AuraText.body.copyWith(height: 1.75),
          ),
          const SizedBox(height: AuraSpace.lg),
          const Wrap(
            spacing: AuraSpace.sm,
            runSpacing: AuraSpace.sm,
            children: [
              _SafetyPill('Zero tolerance for CSAM'),
              _SafetyPill('Always-on reporting'),
              _SafetyPill('Human review'),
              _SafetyPill('Law-enforcement cooperation'),
              _SafetyPill('NCMEC reporting'),
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

class _SafetySignalGrid extends StatelessWidget {
  const _SafetySignalGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        const cards = [
          _SafetySignalCard(
            icon: Icons.block,
            title: 'Hard prohibitions',
            body:
                'CSAM, sexualization of minors, grooming, sextortion, and trafficking are removed on sight.',
          ),
          _SafetySignalCard(
            icon: Icons.flag_outlined,
            title: 'Reporting that works',
            body:
                'In-app report, email, and anonymous channels — every child-safety report is routed to a priority queue.',
          ),
          _SafetySignalCard(
            icon: Icons.gavel_outlined,
            title: 'Real enforcement',
            body:
                'Removal, suspension, termination, preservation, and cooperation with NCMEC and law enforcement.',
          ),
        ];

        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: cards
                .map(
                  (card) => Padding(
                    padding: const EdgeInsets.only(bottom: AuraSpace.sm),
                    child: card,
                  ),
                )
                .toList(),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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

class _SafetySignalCard extends StatelessWidget {
  const _SafetySignalCard({
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

class _SafetySection extends StatelessWidget {
  const _SafetySection({
    required this.number,
    required this.title,
    required this.body,
    this.bullets = const [],
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
                if (bullets.isNotEmpty) ...[
                  const SizedBox(height: AuraSpace.md),
                  ...bullets.map((item) => _Bullet(item)),
                ],
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

class _SafetyPill extends StatelessWidget {
  const _SafetyPill(this.label);
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

class _SafetyContactCallout extends StatelessWidget {
  const _SafetyContactCallout();

  Future<void> _openMail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: ChildSafetyScreen.safetyEmail,
      queryParameters: {
        'subject': 'Aura — Child Safety report',
      },
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
              const Icon(
                Icons.support_agent_outlined,
                color: AuraSurface.accentText,
                size: AuraIconSize.lg,
              ),
              const SizedBox(width: AuraSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contact Aura Trust & Safety',
                      style: AuraText.emphasis.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: AuraSpace.xs),
                    Text(
                      'Use this address for child-safety reports, law-enforcement requests, and Trust & Safety inquiries. For an immediate threat to a child, contact local emergency services first.',
                      style: AuraText.body.copyWith(height: 1.65),
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
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _openMail,
                icon: const Icon(
                  Icons.mail_outline,
                  size: AuraIconSize.sm,
                ),
                label: const Text(ChildSafetyScreen.safetyEmail),
              ),
              SelectableText(
                ChildSafetyScreen.safetyEmail,
                style: AuraText.small.copyWith(color: AuraSurface.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SafetyActionPanel extends StatelessWidget {
  const _SafetyActionPanel({
    required this.onPrivacy,
    required this.onTerms,
  });

  final VoidCallback onPrivacy;
  final VoidCallback onTerms;

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
          const Text('Related policies', style: AuraText.emphasis),
          const SizedBox(height: AuraSpace.xs),
          Text(
            'Privacy explains how Aura handles data — including records preserved for safety review. Terms cover platform-wide rules of use and enforcement.',
            style: AuraText.small.copyWith(
              color: AuraSurface.muted,
              height: 1.55,
            ),
          ),
          const SizedBox(height: AuraSpace.md),
          Wrap(
            spacing: AuraSpace.sm,
            runSpacing: AuraSpace.sm,
            children: [
              OutlinedButton.icon(
                onPressed: onPrivacy,
                icon: const Icon(
                  Icons.privacy_tip_outlined,
                  size: AuraIconSize.sm,
                ),
                label: const Text('Read Privacy'),
              ),
              OutlinedButton.icon(
                onPressed: onTerms,
                icon: const Icon(
                  Icons.gavel_outlined,
                  size: AuraIconSize.sm,
                ),
                label: const Text('Read Terms'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
