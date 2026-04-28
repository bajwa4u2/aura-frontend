import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/admin_providers.dart';

class AdminSettingsScreen extends ConsumerWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(adminSettingsProvider);

    return AuraScaffold(
      title: 'Platform settings',
      showHomeAction: true,
      body: settingsAsync.when(
        loading: () => const Center(
          child: AuraLoadingState(message: 'Loading settings…'),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AuraSpace.s16),
            child: AuraErrorState(
              title: 'Failed to load settings',
              body: e.toString(),
              action: AuraSecondaryButton(
                label: 'Retry',
                icon: Icons.refresh_rounded,
                onPressed: () => ref.invalidate(adminSettingsProvider),
              ),
            ),
          ),
        ),
        data: (settings) {
          if (settings.isEmpty) {
            return const Center(
              child: AuraEmptyState(
                title: 'No settings',
                body: 'No platform settings have been configured.',
                icon: Icons.tune_outlined,
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.s16,
              AuraSpace.s16,
              AuraSpace.s16,
              AuraSpace.s32,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AuraSurface.card,
                      borderRadius: BorderRadius.circular(AuraRadius.card),
                      border: Border.all(color: AuraSurface.divider),
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < settings.length; i++) ...[
                          _SettingRow(setting: settings[i]),
                          if (i < settings.length - 1)
                            Container(
                              height: 1,
                              margin: const EdgeInsets.symmetric(
                                horizontal: AuraSpace.s16,
                              ),
                              color: AuraSurface.divider,
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.setting});

  final AdminSetting setting;

  @override
  Widget build(BuildContext context) {
    final valueStr = setting.value?.toString() ?? '—';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s16,
        vertical: AuraSpace.s14,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  setting.key,
                  style: AuraText.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AuraSurface.ink,
                  ),
                ),
                if (setting.description != null &&
                    setting.description!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    setting.description!,
                    style: AuraText.small.copyWith(color: AuraSurface.muted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AuraSpace.s16),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.s10,
              vertical: AuraSpace.s6,
            ),
            decoration: BoxDecoration(
              color: AuraSurface.elevated,
              borderRadius: BorderRadius.circular(AuraRadius.r10),
              border: Border.all(color: AuraSurface.divider),
            ),
            child: Text(
              valueStr,
              style: AuraText.small.copyWith(
                fontFamily: 'monospace',
                color: AuraSurface.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
