import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';

class PublicHomeScreen extends StatelessWidget {
  const PublicHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuraScaffold(
      title: 'Aura',
      // Keep header clean. AuraScaffold already makes actions scrollable if needed.
      actions: [
        TextButton(
          onPressed: () => context.go('/login'),
          style: TextButton.styleFrom(textStyle: AuraText.small),
          child: const Text('Login'),
        ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AuraSpace.s16, AuraSpace.s16, AuraSpace.s16, AuraSpace.s24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuraCard(
              padding: const EdgeInsets.all(AuraSpace.s20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('A quiet place to publish with responsibility.', style: AuraText.title),
                  const SizedBox(height: AuraSpace.s10),
                  Text(
                    'Read, follow writers, and keep your own correspondence. No noise. No rush.',
                    style: AuraText.body,
                  ),
                  const SizedBox(height: AuraSpace.s16),
                  Wrap(
                    spacing: AuraSpace.s10,
                    runSpacing: AuraSpace.s10,
                    children: [
                      FilledButton(
                        onPressed: () => context.go('/register'),
                        child: const Text('Create account'),
                      ),
                      OutlinedButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('Login'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AuraSpace.s16),
            AuraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Start here', style: AuraText.title),
                  const SizedBox(height: AuraSpace.s10),
                  _LinkRow(label: 'Mission', onTap: () => context.go('/mission')),
                  _LinkRow(label: 'Founder message', onTap: () => context.go('/founder')),
                  _LinkRow(label: 'Privacy policy', onTap: () => context.go('/privacy')),
                  _LinkRow(label: 'Investors hub', onTap: () => context.go('/investors')),
                ],
              ),
            ),
            const SizedBox(height: AuraSpace.s16),
            AuraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('What you can do inside', style: AuraText.title),
                  const SizedBox(height: AuraSpace.s10),
                  const _Bullet('Follow authors without chasing feeds.'),
                  const _Bullet('Write notes as correspondence, not performance.'),
                  const _Bullet('Publish when it is ready, not when it is loud.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AuraSpace.s12),
        child: Row(
          children: [
            Expanded(child: Text(label, style: AuraText.body)),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
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
      padding: const EdgeInsets.only(bottom: AuraSpace.s10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AuraSpace.s4),
            child: const Icon(Icons.circle, size: 6),
          ),
          const SizedBox(width: AuraSpace.s10),
          Expanded(child: Text(text, style: AuraText.body)),
        ],
      ),
    );
  }
}
