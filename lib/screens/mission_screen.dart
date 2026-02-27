import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/auth/auth_providers.dart';
import 'package:aura/core/auth/session_providers.dart';
import '../core/config/aura_links.dart';
import '../core/ui/aura_space.dart';
import '../core/ui/aura_text.dart';
import '../core/ui/document_scaffold.dart';

class MissionScreen extends ConsumerWidget {
  const MissionScreen({super.key});

  Future<void> _openWhitePaper(BuildContext context, String baseUrl) async {
    final uri = Uri.parse(baseUrl).replace(path: AuraLinks.whitePaperPath);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the white paper.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionStateProvider);

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
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _openWhitePaper(context, session.baseUrl),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AuraSpace.s14,
                      vertical: AuraSpace.s12,
                    ),
                  ),
                  child: Text('Read the White Paper (PDF)', style: AuraText.body),
                ),
              ),
            ],
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