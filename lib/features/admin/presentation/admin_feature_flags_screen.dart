import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/admin_providers.dart';

class AdminFeatureFlagsScreen extends ConsumerWidget {
  const AdminFeatureFlagsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flagsAsync = ref.watch(adminFeatureFlagsProvider);

    return AuraScaffold(
      title: 'Feature flags',
      showHomeAction: true,
      body: flagsAsync.when(
        loading: () => const Center(
          child: AuraLoadingState(message: 'Loading feature flags…'),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AuraSpace.s16),
            child: AuraErrorState(
              title: 'Failed to load feature flags',
              body: e.toString(),
              action: AuraSecondaryButton(
                label: 'Retry',
                icon: Icons.refresh_rounded,
                onPressed: () => ref.invalidate(adminFeatureFlagsProvider),
              ),
            ),
          ),
        ),
        data: (flags) {
          if (flags.isEmpty) {
            return const Center(
              child: AuraEmptyState(
                title: 'No feature flags',
                body: 'No feature flags have been configured.',
                icon: Icons.flag_outlined,
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
                        for (var i = 0; i < flags.length; i++) ...[
                          _FlagRow(flag: flags[i]),
                          if (i < flags.length - 1)
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

class _FlagRow extends StatelessWidget {
  const _FlagRow({required this.flag});

  final AdminFeatureFlag flag;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s16,
        vertical: AuraSpace.s14,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  flag.key,
                  style: AuraText.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AuraSurface.ink,
                  ),
                ),
                if (flag.description != null &&
                    flag.description!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    flag.description!,
                    style: AuraText.small.copyWith(color: AuraSurface.muted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AuraSpace.s12),
          _FlagToggle(enabled: flag.enabled),
        ],
      ),
    );
  }
}

class _FlagToggle extends StatelessWidget {
  const _FlagToggle({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s10,
        vertical: AuraSpace.s6,
      ),
      decoration: BoxDecoration(
        color: enabled ? AuraSurface.accentSoft : AuraSurface.elevated,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(
          color: enabled
              ? AuraSurface.accent.withValues(alpha: 0.3)
              : AuraSurface.divider,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: enabled ? AuraSurface.accentText : AuraSurface.faint,
            ),
          ),
          const SizedBox(width: AuraSpace.s6),
          Text(
            enabled ? 'ENABLED' : 'DISABLED',
            style: AuraText.micro.copyWith(
              color: enabled ? AuraSurface.accentText : AuraSurface.faint,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
