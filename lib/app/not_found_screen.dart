import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/session_providers.dart';
import '../core/ui/aura_chamber.dart';
import '../core/ui/aura_space.dart';
import '../features/home/presentation/public_home_copy.dart';
import 'shell/shell_shared.dart';

/// THE PAGE FOR AN ADDRESS AURA DOES NOT HAVE (founder, 2026-10-26).
///
/// Replaces the router's raw developer page ("Route not found: /zzz" under a
/// red icon). Since the same day nginx answers such an address with status 404
/// and this app shell, so this is what a person who mistyped or followed an
/// old link actually reads. Night Chamber, like the front door: ink ground,
/// serif heading, one gold action home and one quiet way to keep exploring.
/// The address is shown small and muted, so a person can see what they typed
/// without being handed an error report.
class NotFoundScreen extends ConsumerWidget {
  const NotFoundScreen({super.key, required this.address});

  /// The address that was asked for, shown small so a person sees what they typed.
  final String address;

  static const String heading = "This page isn't here";
  static const String explanation =
      'The address may be mistyped, or the page may have moved or been removed.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthed = ref.watch(isAuthedProvider);
    final home = isAuthed ? '/home' : '/';

    return Scaffold(
      backgroundColor: AuraChamber.ink,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AuraSpace.s16,
                AuraSpace.s12,
                AuraSpace.s16,
                0,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: AuraShellWordmark(onTap: () => context.go(home)),
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AuraSpace.s24,
                    vertical: AuraSpace.s32,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('NOT FOUND', style: AuraChamber.eyebrow),
                        const SizedBox(height: AuraSpace.s12),
                        Semantics(
                          header: true,
                          child: const Text(heading, style: AuraChamber.heading),
                        ),
                        const SizedBox(height: AuraSpace.s16),
                        const Text(explanation, style: AuraChamber.lede),
                        if (address.trim().isNotEmpty) ...[
                          const SizedBox(height: AuraSpace.s12),
                          Text(
                            address,
                            style: AuraChamber.small.copyWith(
                              color: AuraChamber.faint,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: AuraSpace.s28),
                        Wrap(
                          spacing: AuraSpace.s10,
                          runSpacing: AuraSpace.s10,
                          children: [
                            _ChamberPill(
                              label: isAuthed ? 'Go to your feed' : 'Go to Aura',
                              filled: true,
                              onTap: () => context.go(home),
                            ),
                            _ChamberPill(
                              label: publicHomeExploreLabel,
                              filled: false,
                              onTap: () => context.go(publicHomeExploreRoute),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Look B's pill, as on the public front door: gold with ink text, or hairline.
class _ChamberPill extends StatelessWidget {
  const _ChamberPill({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? AuraChamber.gold : Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(
          color: filled ? AuraChamber.gold : AuraChamber.ruleStrong,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: AuraChamber.body.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: filled ? AuraChamber.ink : AuraChamber.text,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
