import 'package:flutter/material.dart';

import '../core/ui/aura_card.dart';
import '../core/ui/aura_scaffold.dart';
import '../core/ui/aura_space.dart';
import '../core/ui/aura_text.dart';

class SupportFallbackScreen extends StatelessWidget {
  const SupportFallbackScreen({super.key, required this.handle});

  final String handle;

  @override
  Widget build(BuildContext context) {
    return AuraScaffold(
      
      body: Padding(
        padding: const EdgeInsets.all(AuraSpace.s16),
        child: AuraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Support @$handle', style: AuraText.title),
              const SizedBox(height: AuraSpace.s10),
              Text(
                'Support screen is temporarily routed to a fallback while the real file path is being reconciled.',
                style: AuraText.body,
              ),
            ],
          ),
        ),
      ),
    );
  }
}