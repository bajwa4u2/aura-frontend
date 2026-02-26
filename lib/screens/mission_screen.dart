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
    // baseUrl is something like https://api.example.com
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
            'Aura is a civic communication layer: a place where people and institutions can speak in a way that can be checked, carried, and returned to.',
          ),

          // White paper (primary depth layer)
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
            'Aura is not trying to win attention. It is trying to reduce distortion.',
          ),
          Doc.h('What Aura is'),
          Doc.bullets([
            'A durable public record for approved posts',
            'A member space for drafting, replies, and responsible participation',
            'A verification lane for institutions to participate as themselves',
            'A moderation foundation that prefers repair over removal',
          ]),
          Doc.h('What Aura avoids'),
          Doc.bullets([
            'Ranking-by-reaction as the main organizing force',
            'Viral mechanics that punish nuance',
            'Public counts that turn people into trophies',
            'Design that rewards outrage, bait, or performance',
          ]),
          Doc.h('How alignment happens here'),
          Doc.p(
            'Alignment is not agreement. It is clarity: what was said, by whom, under what responsibility, and what response followed.',
          ),
          Doc.p(
            'Aura is built so that disagreement can exist without becoming a weapon, and institutional speech can exist without becoming propaganda.',
          ),
          Doc.callout(
            'This document does not propose a platform of influence. It proposes a layer of accountability and alignment.',
          ),
        ],
      ),
    );
  }
}
