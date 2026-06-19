import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../feed/data/unified_feed_providers.dart';

/// Public-UX Phase 5 — first-session activation overlay.
///
/// Mounts as a Stack child above the Public Home. The first time a user
/// reaches the home it slides up with a 3-step framing:
///   1. Orient ("real discussions are happening").
///   2. Prompt action (Respond / Ask / Explore).
///   3. Direct routing on tap.
///
/// Persistence: a single SharedPreferences key `aura.activation.dismissed`
/// flips to true the moment the user picks an action OR taps Skip. The
/// overlay never shows again on that device. There is no analytics
/// dependency — the activation outcome is pure UX state.
class ActivationOverlay extends ConsumerStatefulWidget {
  const ActivationOverlay({super.key, this.onDismiss});

  /// Called when the overlay should be torn down (Skip / × / action picked).
  /// When provided, the overlay drives dismissal through this callback
  /// instead of popping a Navigator route — which is what binds it to the
  /// Home route's widget tree (rendered as an in-tree Stack child) rather
  /// than living as a root-navigator dialog that could float over other
  /// routes. When null, falls back to `Navigator.maybePop()`.
  final VoidCallback? onDismiss;

  static const String _kDismissedKey = 'aura.activation.dismissed';

  /// Returns true the first time, false on subsequent loads. Caller
  /// (typically MemberHomeScreen) gates the overlay's mount on this.
  static Future<bool> shouldShow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_kDismissedKey) != true;
    } catch (_) {
      // SharedPreferences should never fail; if it does we err on the
      // side of NOT showing — better to hide than to harass the user.
      return false;
    }
  }

  static Future<void> markDismissed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kDismissedKey, true);
    } catch (_) {
      // Same defensive treatment — best-effort persistence.
    }
  }

  @override
  ConsumerState<ActivationOverlay> createState() =>
      _ActivationOverlayState();
}

class _ActivationOverlayState extends ConsumerState<ActivationOverlay> {
  void _close() {
    if (widget.onDismiss != null) {
      widget.onDismiss!();
    } else if (mounted) {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _dismiss() async {
    await ActivationOverlay.markDismissed();
    if (!mounted) return;
    _close();
  }

  Future<void> _route(String path) async {
    await ActivationOverlay.markDismissed();
    if (!mounted) return;
    // Route first (while this context is still mounted), then tear down.
    context.push(path);
    _close();
  }

  /// "Respond to a discussion" — picks the first active discussion
  /// from the global feed and routes to its thread. Falls back to
  /// /spaces when the feed is empty.
  Future<void> _respond() async {
    final feed = ref.read(globalPublicFeedProvider);
    final firstId = feed.maybeWhen(
      data: (page) {
        for (final item in page.items) {
          // Pick the first item with replies — that's where the user
          // can plausibly land in an active conversation.
          final ic = item.interaction;
          if (ic.canViewReplyCount && ic.replyCount > 0) {
            return item.id;
          }
        }
        // Fallback: the first item, even if it has no replies — better
        // than dumping the user back at the home.
        return page.items.isNotEmpty ? page.items.first.id : null;
      },
      orElse: () => null,
    );
    if (firstId != null && firstId.isNotEmpty) {
      await _route('/thread/$firstId');
    } else {
      await _route('/spaces');
    }
  }

  Future<void> _ask() async {
    await _route('/compose?intent=ask');
  }

  Future<void> _explore() async {
    await _route('/spaces');
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.s16),
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Container(
                padding: const EdgeInsets.fromLTRB(
                  AuraSpace.s20,
                  AuraSpace.s20,
                  AuraSpace.s20,
                  AuraSpace.s16,
                ),
                decoration: BoxDecoration(
                  color: AuraSurface.card,
                  borderRadius: BorderRadius.circular(AuraRadius.lg),
                  border: Border.all(
                    color: AuraSurface.accent.withValues(alpha: 0.4),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const _StepDot(active: true),
                        const SizedBox(width: 6),
                        const _StepDot(active: false),
                        const SizedBox(width: 6),
                        const _StepDot(active: false),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Skip',
                          icon: const Icon(Icons.close_rounded, size: 18),
                          color: AuraSurface.muted,
                          onPressed: _dismiss,
                        ),
                      ],
                    ),
                    const SizedBox(height: AuraSpace.s10),
                    const Text(
                      'You’re seeing real discussions happening now.',
                      style: AuraText.subtitle,
                    ),
                    const SizedBox(height: AuraSpace.s6),
                    Text(
                      'This isn’t a feed to scroll — it’s a place to act. '
                      'Pick one to get started.',
                      style: AuraText.body.copyWith(
                        color: AuraSurface.muted,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: AuraSpace.s18),
                    _ActionTile(
                      icon: Icons.reply_rounded,
                      title: 'Respond to a discussion',
                      subtitle:
                          'Jump into something already happening and add your perspective.',
                      onTap: _respond,
                    ),
                    const SizedBox(height: AuraSpace.s8),
                    _ActionTile(
                      icon: Icons.help_outline_rounded,
                      title: 'Ask a question',
                      subtitle:
                          'Raise something you want public answers to.',
                      onTap: _ask,
                    ),
                    const SizedBox(height: AuraSpace.s8),
                    _ActionTile(
                      icon: Icons.travel_explore_rounded,
                      title: 'Explore a space',
                      subtitle:
                          'Find topical environments — civic, climate, tech, more.',
                      onTap: _explore,
                    ),
                    const SizedBox(height: AuraSpace.s8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AuraGhostButton(
                        label: 'Skip for now',
                        onPressed: _dismiss,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: active ? AuraSurface.accentText : AuraSurface.divider,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AuraRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AuraSpace.s12),
        decoration: BoxDecoration(
          color: AuraSurface.subtle,
          borderRadius: BorderRadius.circular(AuraRadius.md),
          border: Border.all(color: AuraSurface.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AuraSurface.accentSoft,
                borderRadius: BorderRadius.circular(AuraRadius.r10),
                border: Border.all(
                  color: AuraSurface.accent.withValues(alpha: 0.3),
                ),
              ),
              child: Icon(icon, size: 18, color: AuraSurface.accentText),
            ),
            const SizedBox(width: AuraSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AuraText.body.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AuraText.small.copyWith(
                      color: AuraSurface.muted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AuraSpace.s8),
            const Icon(
              Icons.arrow_forward_rounded,
              size: 16,
              color: AuraSurface.muted,
            ),
          ],
        ),
      ),
    );
  }
}
