import 'package:flutter/material.dart';
import 'package:aura/core/ui/document_scaffold.dart';

class FounderMessageScreen extends StatelessWidget {
  const FounderMessageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DocumentScaffold(
      title: 'Founder',
      children: [
        _Intro(),
        SizedBox(height: 24),
        _Origin(),
        SizedBox(height: 24),
        _CoreDecision(),
        SizedBox(height: 24),
        _ForWhom(),
        SizedBox(height: 24),
        _Constraints(),
        SizedBox(height: 24),
        _Moderation(),
        SizedBox(height: 24),
        _Success(),
        SizedBox(height: 24),
        _Standard(),
      ],
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'This is not a biography. It is an operating statement.\n\n'
      'Aura is built with specific intent, constraints, and responsibilities. '
      'The system is not shaped by trends or growth pressure, but by decisions '
      'about how communication should work when identity, institutions, and '
      'continuity matter.',
    );
  }
}

class _Origin extends StatelessWidget {
  const _Origin();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Aura began from a simple concern:\n\n'
      'Modern communication is powerful, but it often distorts identity, '
      'attention, and institutional accountability. Conversations fragment. '
      'Context is lost. Visibility is shaped by systems that do not reflect '
      'responsibility.\n\n'
      'Aura exists to correct that direction — not by adding more noise, '
      'but by restoring structure.',
    );
  }
}

class _CoreDecision extends StatelessWidget {
  const _CoreDecision();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'The core decision in Aura is that attention is private.\n\n'
      'No public engagement counts. No algorithmic amplification. '
      'No visibility systems that distort intent.\n\n'
      'What remains is direct communication, tied to identity and context.',
    );
  }
}

class _ForWhom extends StatelessWidget {
  const _ForWhom();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Aura is built for:\n\n'
      '• Individuals who want their communication to remain coherent and accountable\n'
      '• Institutions that require continuity, identity, and traceable interaction\n'
      '• Environments where communication must outlast the moment\n\n'
      'It is not designed for attention markets or viral interaction loops.',
    );
  }
}

class _Constraints extends StatelessWidget {
  const _Constraints();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Certain constraints are non-negotiable:\n\n'
      '• No public metrics as social currency\n'
      '• No amplification systems that distort visibility\n'
      '• No growth that weakens identity integrity or consent\n'
      '• No system behavior that prioritizes engagement over clarity\n\n'
      'These are not features. They are boundaries the system will not cross.',
    );
  }
}

class _Moderation extends StatelessWidget {
  const _Moderation();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Moderation in Aura is not silent control.\n\n'
      'The preference is always toward clarification, revision, and accountability '
      'over removal without context.\n\n'
      'The goal is not to erase interaction, but to preserve meaning while '
      'maintaining safety.',
    );
  }
}

class _Success extends StatelessWidget {
  const _Success();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Success for Aura is defined differently:\n\n'
      '• Communication remains structured over time\n'
      '• Identity remains intact across interactions\n'
      '• Institutions can operate without fragmentation\n\n'
      'If these hold, the system is working.',
    );
  }
}

class _Standard extends StatelessWidget {
  const _Standard();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'The standard is simple:\n\n'
      'Measured. Repeatable. Built to outlast the moment.',
    );
  }
}