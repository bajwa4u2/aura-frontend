/// Settings → Data and account → Download my data.
///
/// A copy of what the person put into Aura, from `POST /v1/me/export`, once a
/// day. Says what is in it and what is not before anyone presses anything.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/data_export_repository.dart';
import 'widgets/data_export_panel.dart';
import 'widgets/me_section.dart';

class DataExportScreen extends ConsumerWidget {
  const DataExportScreen({super.key, this.panel});

  /// For tests and review screenshots only.
  final Widget? panel;

  static const intro =
      'Get a copy of what you have put into Aura: your profile, your posts, '
      'replies and reactions, the people you follow and who follows you, '
      'your saved items, the messages you sent, links to your photos and '
      'videos, your notifications, your sign-in history, and the calls and '
      'meetings you took part in.';

  static const excluded =
      'It does not include other people\'s messages or anything that is '
      'private to someone else.';

  static const onceADay = 'You can download your data once a day.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AuraScaffold(
      title: 'Download my data',
      maxWidth: 720,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AuraSpace.s16,
          AuraSpace.s16,
          AuraSpace.s16,
          AuraSpace.s32,
        ),
        children: [
          Text(
            intro,
            style: AuraText.body.copyWith(color: AuraSurface.ink, height: 1.5),
          ),
          const SizedBox(height: AuraSpace.s12),
          Text(
            excluded,
            style: AuraText.small.copyWith(color: AuraSurface.muted, height: 1.45),
          ),
          const SizedBox(height: AuraSpace.s20),
          MeSection(
            title: 'Your copy',
            children: [
              Padding(
                padding: const EdgeInsets.all(AuraSpace.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      onceADay,
                      style: AuraText.small
                          .copyWith(color: AuraSurface.faint, height: 1.4),
                    ),
                    const SizedBox(height: AuraSpace.s14),
                    panel ??
                        DataExportPanel(
                          buttonLabel: 'Download my data',
                          fetch: () =>
                              ref.read(dataExportRepositoryProvider).exportMine(),
                        ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
