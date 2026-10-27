import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/public_spaces_registry.dart';

/// Compact tile for a public discourse space.
///
/// Phase 1 — the Aura backend does not yet expose a public spaces
/// discovery endpoint, so the home strip renders a curated list of
/// topical seeds (see [PublicSpacesStrip] below). When the public
/// spaces backend ships, the same widget binds 1:1 to whatever DTO
/// we end up with — only the data source changes.
class SpaceCard extends StatelessWidget {
  const SpaceCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
    this.activitySummary,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  /// One-line summary like "12 active threads · 3 live now". Optional
  /// — when null, the line is omitted so the card stays calm.
  final String? activitySummary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        child: Container(
          // Width comes from the parent (AdaptiveCardGrid's SizedBox);
          // the previous hard-coded 220 fought the grid layout on wide
          // viewports.
          padding: const EdgeInsets.all(AuraSpace.s14),
          decoration: BoxDecoration(
            color: AuraSurface.card,
            borderRadius: BorderRadius.circular(AuraRadius.card),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(height: AuraSpace.s10),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AuraText.body.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AuraSurface.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AuraText.small.copyWith(
                  color: AuraSurface.muted,
                  height: 1.4,
                ),
              ),
              if (activitySummary != null) ...[
                const SizedBox(height: AuraSpace.s8),
                Text(
                  activitySummary!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AuraText.micro.copyWith(
                    color: AuraSurface.faint,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Public spaces on the member home: ONE row that drifts slowly
/// (founder, 2026-10-26).
///
/// It used to be an [AdaptiveCardGrid]: ten 188 px cards plus a "See all"
/// tile wrapped to three rows on a desktop, and the first post started below
/// the fold. Now the spaces sit in a single compact row that moves on its own,
/// so the feed is in view the moment a member lands, and "See all spaces"
/// lives in the header.
///
/// Motion is a courtesy, never a fight:
/// - it drifts in reading direction (RTL included) at [_driftPerSecond];
/// - hover, keyboard focus, a press, a drag or a wheel/trackpad scroll stops
///   it, and it resumes [_resumeAfter] after the last of them;
/// - the pause button stops it until pressed again;
/// - with reduced motion on it never moves.
/// When it is still, chevrons page it by hand. The loop is seamless: the list
/// is long and modular, and the offset is folded back by whole cycles.
/// A [Ticker] drives the scroll controller directly, so nothing rebuilds per
/// frame, and [TickerMode] stops it when the route is not visible.
class PublicSpacesStrip extends ConsumerStatefulWidget {
  const PublicSpacesStrip({super.key});

  /// Phones keep the row compact; wider windows give the description room.
  static const double cardWidth = 200;
  static const double cardWidthWide = 232;
  static const double cardHeight = 76;
  static const double gap = AuraSpace.s10;

  @override
  ConsumerState<PublicSpacesStrip> createState() => _PublicSpacesStripState();
}

const double _driftPerSecond = 24;
const Duration _resumeAfter = Duration(seconds: 4);

/// How many copies of the list the row holds; the offset starts in the
/// middle and is folded back by whole cycles, so it never meets an end.
const int _copies = 200;

class _PublicSpacesStripState extends ConsumerState<PublicSpacesStrip>
    with SingleTickerProviderStateMixin {
  double _extent = PublicSpacesStrip.cardWidth + PublicSpacesStrip.gap;

  late final Ticker _ticker = createTicker(_tick);
  ScrollController? _controller;
  int _count = 0;
  Duration? _last;

  bool _pausedByUser = false;
  bool _hovering = false;
  bool _focused = false;
  bool _pressing = false;
  // The grace after an interaction is timed on the ticker's own clock, so it
  // matches the frames actually shown (and test time).
  bool _holdRequested = false;
  Duration _heldUntil = Duration.zero;

  double get _cycle => _count * _extent;

  bool _reduceMotion(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  bool get _still =>
      _pausedByUser || _reduceMotion(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTicker();
  }

  void _ensureController(int count, double extent) {
    if (_controller != null && count == _count && extent == _extent) return;
    _count = count;
    _extent = extent;
    _controller?.dispose();
    _controller = ScrollController(
      initialScrollOffset: _cycle * (_copies ~/ 2),
    );
  }

  void _syncTicker() {
    if (!mounted) return;
    final shouldRun = !_still && _count > 0;
    if (shouldRun && !_ticker.isActive) {
      _last = null;
      _heldUntil = Duration.zero;
      _ticker.start();
    } else if (!shouldRun && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _hold() => _holdRequested = true;

  void _tick(Duration elapsed) {
    final last = _last;
    _last = elapsed;
    if (_holdRequested) {
      _holdRequested = false;
      _heldUntil = elapsed + _resumeAfter;
    }
    final interacting = _hovering || _focused || _pressing || elapsed < _heldUntil;
    final c = _controller;
    if (last == null || c == null || !c.hasClients || interacting) return;
    final dt = (elapsed - last).inMicroseconds / 1e6;
    if (dt <= 0 || dt > 0.25) return; // a stalled frame never lurches the row
    var next = c.offset + _driftPerSecond * dt;
    final max = c.position.maxScrollExtent;
    if (next > max - _cycle * 2) next -= _cycle * (_copies ~/ 2 - 2);
    c.jumpTo(next);
  }

  void _page(int direction) {
    final c = _controller;
    if (c == null || !c.hasClients) return;
    final step = (c.position.viewportDimension * 0.8 / _extent).floor().clamp(1, 99) * _extent;
    var target = c.offset + direction * step;
    // Fold back by whole cycles if a long run of paging nears either end.
    final mid = _cycle * (_copies ~/ 2);
    if ((target - mid).abs() > _cycle * (_copies ~/ 4)) {
      final folded = target - ((target - mid) / _cycle).truncate() * _cycle;
      c.jumpTo(c.offset + (folded - target));
      target = folded;
    }
    if (_reduceMotion(context)) {
      c.jumpTo(target);
    } else {
      c.animateTo(target, duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
    }
  }

  void _togglePause() {
    setState(() => _pausedByUser = !_pausedByUser);
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spaces = ref.watch(publicSpacesProvider);
    final wide = MediaQuery.sizeOf(context).width >= 700;
    _ensureController(
      spaces.length,
      (wide ? PublicSpacesStrip.cardWidthWide : PublicSpacesStrip.cardWidth) + PublicSpacesStrip.gap,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncTicker());
    final still = _still;
    final reduce = _reduceMotion(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Expanded(child: Text('Spaces', style: AuraText.subtitle)),
            if (still) ...[
              _RowIconButton(
                icon: Icons.chevron_left_rounded,
                label: 'Previous spaces',
                onPressed: () => _page(Directionality.of(context) == TextDirection.rtl ? 1 : -1),
              ),
              _RowIconButton(
                icon: Icons.chevron_right_rounded,
                label: 'Next spaces',
                onPressed: () => _page(Directionality.of(context) == TextDirection.rtl ? -1 : 1),
              ),
            ],
            if (!reduce)
              _RowIconButton(
                icon: _pausedByUser ? Icons.play_arrow_rounded : Icons.pause_rounded,
                label: _pausedByUser ? 'Play spaces' : 'Pause spaces',
                onPressed: _togglePause,
              ),
            const SizedBox(width: AuraSpace.s4),
            TextButton(
              onPressed: () => context.push('/spaces'),
              style: TextButton.styleFrom(
                foregroundColor: AuraSurface.accentText,
                padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s8),
                minimumSize: const Size(0, 36),
              ),
              child: Text(
                'See all spaces',
                style: AuraText.small.copyWith(
                  color: AuraSurface.accentText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AuraSpace.s8),
        SizedBox(
          height: PublicSpacesStrip.cardHeight,
          child: LayoutBuilder(
            builder: (context, box) {
              final fade = (24 / box.maxWidth).clamp(0.0, 0.2);
              return ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (rect) => LinearGradient(
                  colors: const [
                    Color(0x00000000),
                    Color(0xFF000000),
                    Color(0xFF000000),
                    Color(0x00000000),
                  ],
                  stops: [0, fade, 1 - fade, 1],
                ).createShader(rect),
                child: MouseRegion(
                  onEnter: (_) => _hovering = true,
                  onExit: (_) {
                    _hovering = false;
                    _hold();
                  },
                  child: Listener(
                    onPointerDown: (_) => _pressing = true,
                    onPointerUp: (_) {
                      _pressing = false;
                      _hold();
                    },
                    onPointerCancel: (_) {
                      _pressing = false;
                      _hold();
                    },
                    onPointerSignal: (_) => _hold(),
                    child: Focus(
                      skipTraversal: true,
                      canRequestFocus: false,
                      onFocusChange: (has) {
                        _focused = has;
                        if (!has) _hold();
                      },
                      child: NotificationListener<ScrollStartNotification>(
                        onNotification: (n) {
                          if (n.dragDetails != null) _hold();
                          return false;
                        },
                        child: ListView.builder(
                          key: const ValueKey('spaces-row'),
                          controller: _controller,
                          scrollDirection: Axis.horizontal,
                          itemExtent: _extent,
                          itemCount: spaces.isEmpty ? 0 : spaces.length * _copies,
                          semanticChildCount: spaces.length,
                          itemBuilder: (context, i) {
                            final s = spaces[i % spaces.length];
                            return Padding(
                              padding: const EdgeInsetsDirectional.only(
                                end: PublicSpacesStrip.gap,
                              ),
                              child: _CompactSpaceCard(
                                key: ValueKey('space-${s.slug}-$i'),
                                title: s.name,
                                description: s.description,
                                icon: s.icon,
                                onTap: () => context.push('/spaces/${s.slug}'),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RowIconButton extends StatelessWidget {
  const _RowIconButton({required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: IconButton(
        onPressed: onPressed,
        tooltip: label,
        icon: Icon(icon, size: 18),
        color: AuraSurface.muted,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 36, height: 36),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

/// A space as one compact line-height card: icon, name, one-line description.
class _CompactSpaceCard extends StatelessWidget {
  const _CompactSpaceCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AuraRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s12, vertical: AuraSpace.s10),
          decoration: BoxDecoration(
            color: AuraSurface.card,
            borderRadius: BorderRadius.circular(AuraRadius.md),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AuraSurface.accentSoft,
                  borderRadius: BorderRadius.circular(AuraRadius.sm - 4),
                  border: Border.all(color: AuraSurface.accent.withValues(alpha: 0.3)),
                ),
                child: Icon(icon, size: 15, color: AuraSurface.accentText),
              ),
              const SizedBox(width: AuraSpace.s10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AuraText.body.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AuraSurface.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AuraText.small.copyWith(color: AuraSurface.muted),
                    ),
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
