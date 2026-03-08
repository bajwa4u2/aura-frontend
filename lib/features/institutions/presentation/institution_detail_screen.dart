import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';

class InstitutionDetailScreen extends ConsumerWidget {
  const InstitutionDetailScreen({
    super.key,
    required this.slug,
  });

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cleanSlug = slug.trim();

    return AuraScaffold(
      title: 'Institution',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AuraSpace.s16,
          AuraSpace.s12,
          AuraSpace.s16,
          AuraSpace.s24,
        ),
        children: [
          AuraCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 24,
                  backgroundColor: Color(0x332E2A26),
                  child: Icon(Icons.apartment_outlined),
                ),
                const SizedBox(width: AuraSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cleanSlug.isEmpty ? 'Institution' : cleanSlug,
                        style: AuraText.title,
                      ),
                      const SizedBox(height: AuraSpace.s6),
                      Text(
                        cleanSlug.isEmpty ? 'No institution selected.' : cleanSlug,
                        style: AuraText.muted,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AuraSpace.s14),
          AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Institution profiles are being prepared.',
                  style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AuraSpace.s10),
                Text(
                  'This route is now in place so institution search results can open into a dedicated detail page. The full institution profile, activity, and verification context can be connected next.',
                  style: AuraText.body,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}