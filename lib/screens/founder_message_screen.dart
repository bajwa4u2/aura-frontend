import 'package:flutter/material.dart';

import '../core/ui/document_scaffold.dart';

class FounderMessageScreen extends StatelessWidget {
  const FounderMessageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DocumentScaffold(
      title: 'Founder',
      showSiteFooter: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Doc.title('Founder'),
          const SizedBox(height: 10),
          Doc.meta('Operating statement.'),
          Doc.lede(
            'This is not a biography. It is an operating statement. Aura is built with specific intent, constraints, and responsibilities that the system must be accountable to.',
          ),

          Doc.h('Origin'),
          Doc.p(
            'Aura began from a simple concern: modern communication is powerful, but it often distorts identity, attention, and institutional accountability. Conversations fragment. Context is lost. Visibility is shaped by systems that do not reflect responsibility.',
          ),
          Doc.p(
            'Aura exists to correct that direction — not by adding more noise, but by restoring structure.',
          ),

          Doc.h('The core decision'),
          Doc.p(
            'Attention is private. There are no public engagement counts. No algorithmic amplification. No visibility systems that distort intent. What remains is direct communication, tied to identity and context.',
          ),
          Doc.p(
            'This was not a product decision. It was a structural one. Removing the amplification layer changes what the system rewards and what it cannot be used to build.',
          ),

          Doc.h('For whom'),
          Doc.bullets([
            'Individuals who want their communication to remain coherent and accountable',
            'Institutions that require continuity, identity, and traceable interaction',
            'Environments where communication must outlast the moment',
          ]),
          Doc.p(
            'Aura is not designed for attention markets or viral interaction loops.',
          ),

          Doc.h('Non-negotiable constraints'),
          Doc.bullets([
            'No public metrics as social currency',
            'No amplification systems that distort visibility',
            'No growth that weakens identity integrity or consent',
            'No system behavior that prioritizes engagement over clarity',
          ]),
          Doc.p(
            'These are not features. They are the boundaries the system will not cross.',
          ),

          Doc.h('Moderation'),
          Doc.p(
            'Moderation in Aura is not silent control. The preference is always toward clarification, revision, and accountability over removal without context. The goal is not to erase interaction, but to preserve meaning while maintaining safety.',
          ),

          Doc.h('What success looks like'),
          Doc.bullets([
            'Communication remains structured over time',
            'Identity remains intact across interactions',
            'Institutions can operate without fragmentation',
          ]),
          Doc.p(
            'If these hold, the system is working.',
          ),

          Doc.callout(
            'Measured. Repeatable. Built to outlast the moment.',
          ),
        ],
      ),
    );
  }
}
