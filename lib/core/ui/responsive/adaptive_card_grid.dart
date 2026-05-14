import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../aura_responsive.dart';
import '../aura_space.dart';

/// Adaptive card layout primitive.
///
/// On narrow viewports (mobile / split-screen desktop), renders the cards
/// in a horizontal-scroll rail with **pointer-aware affordances**:
///   - vertical mouse-wheel is translated into horizontal scroll
///   - left/right arrow keys move the scroll position
///   - on pointer devices (Windows desktop, web on laptop) chevron buttons
///     appear at the rail edges
///
/// On wide viewports (tablet / desktop), the cards wrap into a multi-row
/// grid using [Wrap], with the column count computed from
/// `availableWidth / (cardWidth + gap)`.
///
/// The single decision point is the `breakpoint` parameter (default:
/// [kTabletBreak] from `aura_responsive.dart`, currently 900 logical px).
/// Above breakpoint = grid. Below breakpoint = horizontal-scroll rail with
/// affordances.
///
/// Why a horizontal-scroll-with-affordances fallback (instead of a single
/// column on mobile): the cards are intentionally compact (220 px wide,
/// 152 px tall). One card per row on a 320 px phone wastes vertical space
/// and pushes the next feed item down two screens. A swipeable rail keeps
/// the surface compact and matches the same primitive on tablet+, just
/// without the multi-row visual.
class AdaptiveCardGrid extends StatelessWidget {
  const AdaptiveCardGrid({
    super.key,
    required this.cards,
    this.cardWidth = 220,
    this.cardHeight,
    this.gap = AuraSpace.s10,
    this.breakpoint = kTabletBreak,
    this.minCardsPerRow = 2,
    this.maxCardsPerRow = 5,
  });

  final List<Widget> cards;
  final double cardWidth;

  /// Optional fixed cell height. When set:
  ///   - grid mode: every cell is sized to (cellWidth × cardHeight) so the
  ///     row is visually aligned even if some cards have shorter content
  ///   - rail mode: the horizontal-scroll rail is wrapped in
  ///     SizedBox(height: cardHeight). This is **required** for the rail
  ///     to render at all — a horizontal ListView inside an unbounded
  ///     vertical parent (which is what feed/home ListView children give
  ///     it) throws "Vertical viewport given unbounded height" and breaks
  ///     the rest of the page below.
  /// When null, grid mode gives each cell intrinsic height (rows may be
  /// ragged) and rail mode falls back to IntrinsicHeight (slow; only
  /// safe for small card counts).
  final double? cardHeight;
  final double gap;
  final double breakpoint;
  final int minCardsPerRow;
  final int maxCardsPerRow;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width >= breakpoint) {
          // Compute column count from available width. Clamp so the cards
          // never get so wide they look stretched (max) or so narrow they
          // wrap on a single row that overflows (min).
          final columnsByWidth =
              ((width + gap) / (cardWidth + gap)).floor().clamp(
                    minCardsPerRow,
                    maxCardsPerRow,
                  );
          return _GridLayout(
            cards: cards,
            columns: columnsByWidth,
            gap: gap,
            cardHeight: cardHeight,
          );
        }
        return _RailLayout(
          cards: cards,
          cardWidth: cardWidth,
          cardHeight: cardHeight,
          gap: gap,
        );
      },
    );
  }
}

class _GridLayout extends StatelessWidget {
  const _GridLayout({
    required this.cards,
    required this.columns,
    required this.gap,
    required this.cardHeight,
  });

  final List<Widget> cards;
  final int columns;
  final double gap;
  final double? cardHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Wrap is simpler and more forgiving than GridView when child
        // widths are intrinsic; we re-size each child to a uniform width
        // so the wrap forms a clean grid. When `cardHeight` is provided
        // every cell is also height-bounded so a row of mixed-intrinsic-
        // height cards reads as a clean grid instead of a ragged one.
        final totalGap = gap * (columns - 1);
        final cellWidth = (constraints.maxWidth - totalGap) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final card in cards)
              SizedBox(
                width: cellWidth,
                height: cardHeight,
                child: card,
              ),
          ],
        );
      },
    );
  }
}

class _RailLayout extends StatefulWidget {
  const _RailLayout({
    required this.cards,
    required this.cardWidth,
    required this.cardHeight,
    required this.gap,
  });

  final List<Widget> cards;
  final double cardWidth;
  final double? cardHeight;
  final double gap;

  @override
  State<_RailLayout> createState() => _RailLayoutState();
}

class _RailLayoutState extends State<_RailLayout> {
  final ScrollController _controller = ScrollController();
  final FocusNode _focusNode = FocusNode(skipTraversal: false);

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Approximate "page" — three cards worth — for arrow-key paging.
  double get _pageOffset => (widget.cardWidth + widget.gap) * 3;

  void _scrollBy(double delta) {
    if (!_controller.hasClients) return;
    final target = (_controller.offset + delta)
        .clamp(0.0, _controller.position.maxScrollExtent);
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    // The horizontal ListView below needs a BOUNDED vertical extent or it
    // throws "Vertical viewport given unbounded height" — and because the
    // exception happens during the host page's layout, it can prevent the
    // entire feed/page below from rendering. When the caller provides a
    // cardHeight, use it; otherwise fall back to IntrinsicHeight (safe
    // but expensive — fine for small card counts).
    final railHeight = widget.cardHeight;
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          _scrollBy(_pageOffset);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _scrollBy(-_pageOffset);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.home) {
          _scrollBy(-double.infinity);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.end) {
          _scrollBy(double.infinity);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Listener(
        // Translate vertical mouse-wheel into horizontal scroll for pointer
        // devices. Without this, a Windows desktop user has no way to
        // reach off-screen cards because Flutter's default ScrollBehavior
        // does NOT propagate vertical wheel events to a horizontal scroll.
        onPointerSignal: (signal) {
          if (signal is! PointerScrollEvent) return;
          if (!_controller.hasClients) return;
          // dx (horizontal trackpad gesture) → use as-is
          // dy (vertical wheel) → re-route to horizontal
          final delta =
              signal.scrollDelta.dx != 0 ? signal.scrollDelta.dx : signal.scrollDelta.dy;
          if (delta == 0) return;
          final target = (_controller.offset + delta)
              .clamp(0.0, _controller.position.maxScrollExtent);
          _controller.jumpTo(target);
        },
        child: ScrollConfiguration(
          // Allow mouse drag in addition to touch drag — important for
          // Windows desktop and web. Default ScrollBehavior disables
          // mouse-drag on scroll views.
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
              PointerDeviceKind.stylus,
            },
            scrollbars: false,
          ),
          child: _railHeightWrap(
            railHeight,
            Stack(
              children: [
                ListView.separated(
                  controller: _controller,
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: AuraSpace.s2),
                  itemCount: widget.cards.length,
                  separatorBuilder: (_, __) => SizedBox(width: widget.gap),
                  itemBuilder: (_, i) => SizedBox(
                    width: widget.cardWidth,
                    child: widget.cards[i],
                  ),
                ),
                // Chevron affordances — only render on pointer devices,
                // and only when there is actually somewhere to scroll.
                if (_isPointerDevice(context))
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: false,
                      child: _ChevronAffordances(
                        controller: _controller,
                        onScrollBy: _scrollBy,
                        pageOffset: _pageOffset,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Bound the rail's vertical extent. SizedBox is the fast path; the
  /// IntrinsicHeight fallback only fires when the caller did not supply
  /// a cardHeight (rare; previously every caller hardcoded one).
  Widget _railHeightWrap(double? height, Widget child) {
    if (height != null) {
      return SizedBox(height: height, child: child);
    }
    return IntrinsicHeight(child: child);
  }

  bool _isPointerDevice(BuildContext context) {
    final platform = Theme.of(context).platform;
    return platform == TargetPlatform.windows ||
        platform == TargetPlatform.linux ||
        platform == TargetPlatform.macOS;
  }
}

class _ChevronAffordances extends StatefulWidget {
  const _ChevronAffordances({
    required this.controller,
    required this.onScrollBy,
    required this.pageOffset,
  });

  final ScrollController controller;
  final void Function(double delta) onScrollBy;
  final double pageOffset;

  @override
  State<_ChevronAffordances> createState() => _ChevronAffordancesState();
}

class _ChevronAffordancesState extends State<_ChevronAffordances> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // CRITICAL: ScrollPosition.maxScrollExtent throws "Null check operator
    // on null value" before the controlled scroll view has finished its
    // first layout — `hasClients` becomes true at attach time, but the
    // position's content extents are only populated AFTER the first
    // layout pass. We must check `hasContentDimensions` before reading
    // maxScrollExtent. The earlier hasClients-only guard let this
    // exception escape on every first frame, which propagated up through
    // the parent LayoutBuilder and broke rendering of the feed beneath
    // the rail. Repro: launch app, look at Works/Public home, observe
    // posts/footer "disappear".
    final controller = widget.controller;
    final ready = controller.hasClients &&
        controller.position.hasContentDimensions;
    final canLeft = ready && controller.offset > 4;
    final canRight = ready &&
        controller.offset < controller.position.maxScrollExtent - 4;
    return Row(
      children: [
        if (canLeft)
          _ChevronButton(
            icon: Icons.chevron_left_rounded,
            onTap: () => widget.onScrollBy(-widget.pageOffset),
          ),
        const Spacer(),
        if (canRight)
          _ChevronButton(
            icon: Icons.chevron_right_rounded,
            onTap: () => widget.onScrollBy(widget.pageOffset),
          ),
      ],
    );
  }
}

class _ChevronButton extends StatelessWidget {
  const _ChevronButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: Colors.black.withValues(alpha: 0.6),
          shape: const CircleBorder(),
          elevation: 2,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(icon, size: 22, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
