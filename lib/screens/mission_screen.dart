import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/ui/aura_platform_components.dart';
import '../core/ui/aura_space.dart';
import '../core/ui/aura_text.dart';
import '../core/ui/document_scaffold.dart';

class MissionScreen extends StatelessWidget {
  const MissionScreen({super.key});

  static const String _rawBase =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'https://api.bajwadynesty.us');

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
            'Aura is a civic communication layer. It is a place where people and institutions speak within a shared, accountable record.',
          ),

          const SizedBox(height: AuraSpace.s12),

          // Primary: in-app reading surface (MD rendered nicely)
          SizedBox(
            width: double.infinity,
            child: AuraPrimaryButton(
              label: 'Read the White Paper',
              onPressed: () => context.go('/white-paper'),
              icon: Icons.auto_stories_outlined,
            ),
          ),

          const SizedBox(height: AuraSpace.s8),

          // Secondary: PDF download (external)
          SizedBox(
            width: double.infinity,
            child: AuraGhostButton(
              label: 'Download PDF',
              onPressed: () => _openPdf(context),
              icon: Icons.download_outlined,
            ),
          ),

          const SizedBox(height: AuraSpace.s10),
          Doc.p(
            'If you want the full architecture and constraints, read the white paper. The mission statement stays short on purpose.',
          ),

          Doc.p(
            'Aura does not optimize for engagement. It does not rank by reaction. It introduces structural constraints so that speech can be checked, carried, and returned to.',
          ),

          Doc.h('What Aura is'),
          Doc.bullets([
            'A durable public record for approved posts',
            'A member space for drafting, replies, and identity-bound participation',
            'A verification lane for institutions to participate as themselves',
            'A moderation foundation that prefers repair over removal',
            'AI operating as structural assistance, never amplification',
          ]),

          Doc.h('What Aura avoids'),
          Doc.bullets([
            'Ranking-by-reaction as the organizing force',
            'Viral mechanics that punish nuance',
            'Public counts that turn people into trophies',
            'Design that rewards outrage, bait, or performance',
            'Algorithmic amplification as a visibility engine',
          ]),

          Doc.h('How alignment happens here'),
          Doc.p(
            'Alignment is not agreement. It is clarity: what was said, by whom, under what responsibility, and what response followed.',
          ),
          Doc.p(
            'Disagreement remains visible. Correction remains attached. AI may assist review and continuity, but final authority remains human and identity-bound.',
          ),
          Doc.callout(
            'This document does not propose a platform of influence. It proposes a layer of accountability and alignment.',
          ),
        ],
      ),
    );
  }
}