import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/ui/aura_platform_components.dart';
import '../core/ui/aura_space.dart';
import '../core/ui/aura_text.dart';
import '../core/ui/document_scaffold.dart';

class MissionScreen extends StatelessWidget {
  const MissionScreen({super.key});

  static const String _rawBase = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.bajwadynesty.us',
  );

  static String get _base => _rawBase.endsWith('/v1') ? _rawBase : '$_rawBase/v1';

  static String get _pdfUrl => '$_base/mission/white-paper.pdf';

  Future<void> _openPdf(BuildContext context) async {
    final uri = Uri.parse(_pdfUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the PDF.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DocumentScaffold(
      title: 'Mission',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Doc.title('Mission'),
          const SizedBox(height: 10),
          Doc.meta('What Aura is protecting, and what it refuses to become.'),
          Doc.lede(
            'Aura is a civic communication layer for people and institutions. Its purpose is to make important communication clearer, more accountable, and easier to return to over time.',
          ),

          const SizedBox(height: AuraSpace.s10),
          Doc.p(
            'Modern communication is fast, but often unstable. Messages scatter across tools, identity becomes unclear, context disappears, and institutions struggle to speak with the people they serve in a durable, understandable way.',
          ),
          Doc.p(
            'Aura exists to reduce that fragmentation. It gives people and institutions a shared place to communicate with identity, structure, and continuity instead of relying on noise, reaction, or disconnected channels.',
          ),

          Doc.h('What Aura is'),
          Doc.p(
            'Aura is not built as another engagement feed. It is built as communication infrastructure: a system where conversations, announcements, institutional spaces, and public records can be organized around identity and responsibility.',
          ),
          Doc.bullets([
            'A durable public record for approved posts and institutional communication',
            'A member space for messages, replies, calls, drafts, and identity-bound participation',
            'An institution lane where organizations can represent themselves directly',
            'A conversation spine that keeps communication connected instead of scattered',
            'AI operating as structural assistance, never as an amplification engine',
          ]),

          Doc.h('What Aura protects'),
          Doc.bullets([
            'Clarity over noise',
            'Identity over impersonality',
            'Continuity over disposable interaction',
            'Accountability over anonymous influence',
            'Human authority over automated amplification',
          ]),

          Doc.h('What Aura avoids'),
          Doc.bullets([
            'Ranking-by-reaction as the organizing force',
            'Viral mechanics that punish nuance',
            'Public counts that turn people into trophies',
            'Design that rewards outrage, bait, or performance',
            'Algorithmic visibility systems that outrun responsibility',
          ]),

          Doc.h('How alignment happens here'),
          Doc.p(
            'Alignment is not agreement. It is clarity: what was said, by whom, in what context, under what responsibility, and what response followed.',
          ),
          Doc.p(
            'Disagreement remains visible. Correction remains attached. Institutions remain accountable to their own identity. AI may assist review and continuity, but final authority remains human and identity-bound.',
          ),
          Doc.callout(
            'Aura does not propose a platform of influence. It proposes a layer of accountability, identity, and structured communication.',
          ),

          Doc.h('Read the system statement'),
          Doc.p(
            'The mission is intentionally concise. The White Paper explains the deeper architecture, constraints, operating philosophy, and long-term direction behind Aura.',
          ),

          const SizedBox(height: AuraSpace.s6),
          SizedBox(
            width: double.infinity,
            child: AuraPrimaryButton(
              label: 'Read the White Paper',
              onPressed: () => context.go('/white-paper'),
              icon: Icons.auto_stories_outlined,
            ),
          ),

          const SizedBox(height: AuraSpace.s8),
          SizedBox(
            width: double.infinity,
            child: AuraGhostButton(
              label: 'Download PDF',
              onPressed: () => _openPdf(context),
              icon: Icons.download_outlined,
            ),
          ),
        ],
      ),
    );
  }
}
