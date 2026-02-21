import 'package:flutter/material.dart';

import '../core/ui/document_scaffold.dart';

class MissionScreen extends StatelessWidget {
  const MissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DocumentScaffold(
      title: 'Mission',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Doc.title('Mission'),
          const SizedBox(height: 10),
          Doc.meta('A short statement of what Aura protects.'),
          Doc.lede(
            'Aura is a writing platform built for continuity.',
          ),

          Doc.p(
            'A place where work can remain intact. Where archives are treated as first-class. '
            'Where writing is not forced to perform for attention.',
          ),

          Doc.h('What it avoids'),
          Doc.p(
            'Aura avoids ranking by reaction, algorithmic amplification, and engagement pressure. '
            'Its tools are meant to stay quiet.',
          ),

          Doc.h('What it favors'),
          Doc.p(
            'Its structure favors duration over velocity: return over refresh, accumulation over interruption.',
          ),

          Doc.h('What it is'),
          Doc.p(
            'This is not a platform for broadcasting. It is a platform for correspondence, return, and steady work.',
          ),

          Doc.callout(
            'If a feature threatens continuity, it does not ship.',
          ),
        ],
      ),
    );
  }
}
