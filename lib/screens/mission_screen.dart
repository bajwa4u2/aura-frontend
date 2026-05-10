import 'package:flutter/material.dart';

import '../core/ui/aura_space.dart';
import '../core/ui/document_scaffold.dart';

class MissionScreen extends StatelessWidget {
  const MissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DocumentScaffold(
      title: 'Mission',
      showSiteFooter: true,
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

          Doc.h('Operating standard'),
          Doc.p(
            'The design decisions in Aura are structural, not decorative. Every constraint is intentional. Every choice to withhold a feature or reject a growth mechanic reflects a commitment to communication that endures.',
          ),
          Doc.p(
            'Aura is not defined by what it adds. It is defined by what it refuses to become: an attention market, a manipulation engine, or an unaccountable system.',
          ),
        ],
      ),
    );
  }
}
