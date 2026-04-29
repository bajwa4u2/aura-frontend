import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/admin_providers.dart';
import 'admin_error.dart';

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
              body: adminErrorMessage(e),
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
            return const _SettingsEmptyState();
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

// ─────────────────────────────────────────────────────────────────────────────
// SETTINGS EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsEmptyState extends StatelessWidget {
  const _SettingsEmptyState();

  static const _categories = [
    (Icons.security_outlined, 'Security policy', 'Login attempts, session timeouts, MFA enforcement.'),
    (Icons.mark_email_read_outlined, 'Communications policy', 'Email sender config, digest caps, unsubscribe behavior.'),
    (Icons.apartment_outlined, 'Institution policy', 'Verification requirements, domain allowlist rules.'),
    (Icons.flag_outlined, 'Feature policy', 'Rollout gates, beta opt-in, kill-switch overrides.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(AuraSpace.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.tune_outlined, size: 32, color: AuraSurface.faint),
              const SizedBox(height: AuraSpace.s12),
              Text(
                'No settings configured',
                style: AuraText.title.copyWith(color: AuraSurface.ink),
              ),
              const SizedBox(height: AuraSpace.s6),
              Text(
                'Platform settings appear here once pushed from the backend. '
                'These categories are managed by the admin configuration service:',
                style: AuraText.body.copyWith(color: AuraSurface.muted),
              ),
              const SizedBox(height: AuraSpace.s20),
              Container(
                decoration: BoxDecoration(
                  color: AuraSurface.card,
                  borderRadius: BorderRadius.circular(AuraRadius.card),
                  border: Border.all(color: AuraSurface.divider),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < _categories.length; i++) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AuraSpace.s16,
                          vertical: AuraSpace.s12,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              _categories[i].$1,
                              size: 18,
                              color: AuraSurface.faint,
                            ),
                            const SizedBox(width: AuraSpace.s12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _categories[i].$2,
                                    style: AuraText.body.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AuraSurface.muted,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _categories[i].$3,
                                    style: AuraText.small.copyWith(
                                      color: AuraSurface.faint,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AuraSpace.s8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AuraSurface.elevated,
                                borderRadius: BorderRadius.circular(AuraRadius.pill),
                                border: Border.all(color: AuraSurface.divider),
                              ),
                              child: Text(
                                'Not configured',
                                style: AuraText.micro.copyWith(
                                  color: AuraSurface.faint,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (i < _categories.length - 1)
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
            ],
          ),
        ),
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
