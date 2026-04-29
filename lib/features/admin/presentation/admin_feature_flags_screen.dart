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
              body: adminErrorMessage(e),
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

class _FlagRow extends ConsumerStatefulWidget {
  const _FlagRow({required this.flag});

  final AdminFeatureFlag flag;

  @override
  ConsumerState<_FlagRow> createState() => _FlagRowState();
}

class _FlagRowState extends ConsumerState<_FlagRow> {
  bool _busy = false;
  String? _error;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    _enabled = widget.flag.enabled;
  }

  Future<void> _toggle() async {
    if (_busy) return;
    final next = !_enabled;
    setState(() {
      _busy = true;
      _error = null;
      _enabled = next;
    });
    try {
      await ref
          .read(adminRepositoryProvider)
          .updateFeatureFlag(widget.flag.key, enabled: next);
      if (mounted) {
        setState(() => _busy = false);
        ref.invalidate(adminFeatureFlagsProvider);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _enabled = !next;
          _busy = false;
          _error = adminErrorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s16,
        vertical: AuraSpace.s14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.flag.key,
                      style: AuraText.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AuraSurface.ink,
                      ),
                    ),
                    if (widget.flag.description != null &&
                        widget.flag.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.flag.description!,
                        style: AuraText.small.copyWith(color: AuraSurface.muted),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AuraSpace.s12),
              _FlagToggle(
                enabled: _enabled,
                busy: _busy,
                onTap: _toggle,
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: AuraSpace.s6),
            Text(
              _error!,
              style: AuraText.small.copyWith(color: AuraSurface.dangerInk),
            ),
          ],
        ],
      ),
    );
  }
}

class _FlagToggle extends StatelessWidget {
  const _FlagToggle({
    required this.enabled,
    required this.busy,
    required this.onTap,
  });

  final bool enabled;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: busy ? SystemMouseCursors.wait : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: busy ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
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
              if (busy)
                SizedBox(
                  width: 6,
                  height: 6,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: enabled ? AuraSurface.accentText : AuraSurface.faint,
                  ),
                )
              else
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
        ),
      ),
    );
  }
}
