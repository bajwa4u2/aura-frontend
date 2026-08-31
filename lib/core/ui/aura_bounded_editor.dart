import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';


/// A HEIGHT-BOUNDED EDITOR THAT DOES NOT TRAP THE PAGE.
///
/// ── The problem this exists for ───────────────────────────────────────────
///
/// A `TextField` with a bounded multi-line `maxLines` claims the wheel and
/// never passes it to the enclosing scroll view — proven 2026-08-30 by a
/// controlled A/B on one browser harness with the build pinned. For a field in
/// an ordinary form the fix is to stop bounding it: content grows, the page
/// grows, the page keeps scroll ownership.
///
/// Persistent composers cannot take that fix. A chat box, a discussion box or
/// a support reply console stays on screen while the conversation scrolls
/// beside it; unbounded growth would let it eat the surface. Their bounded
/// height is a product decision, not an oversight — so they need the wheel to
/// behave properly instead.
///
/// ── The semantics ─────────────────────────────────────────────────────────
///
///   no internal range                    → the page scrolls
///   internal range, room in that way     → the editor scrolls
///   at the internal top, wheeling up     → the page scrolls
///   at the internal bottom, wheeling down→ the page scrolls
///
/// Nested scrolling as a person expects it: the small thing moves until it
/// cannot, then the big thing does.
///
/// ── How, and why this way ─────────────────────────────────────────────────
///
/// Flutter resolves a competing pointer signal through
/// [PointerSignalResolver]: every listener in the hit-test path is offered the
/// event, and the FIRST to register acts. Hit testing runs innermost-first, so
/// a `TextField`'s own scrollable registers before any wrapper can — which is
/// why wrapping one is not, on its own, enough to take the event back.
///
/// So the editor is told to stop competing: [NeverScrollableScrollPhysics]
/// means it never registers. This widget then registers ONLY when it intends
/// to move the text, and stays silent otherwise — and silence is what lets the
/// enclosing scrollable's own registration win. The delta is never handled
/// twice and never dropped, because exactly one party ever claims it.
///
/// The editor still scrolls itself for the caret: `EditableText` moves its own
/// controller when the cursor would leave view, and that path does not consult
/// physics. Typing, selection, IME composition and keyboard navigation are
/// untouched.
///
/// Nothing here is web-specific in a way that changes native behaviour: on
/// touch platforms a drag is a gesture, not a pointer signal, and never
/// reaches this handler.
class AuraBoundedEditor extends StatefulWidget {
  const AuraBoundedEditor({
    super.key,
    required this.builder,
  });

  /// Builds the editor, given the controller and physics it must adopt.
  ///
  /// A builder rather than a `child`, because the contract is not "wrap this"
  /// — it is "this editor must hand its scrolling over". Passing the pieces
  /// makes that impossible to forget: a caller who ignores them gets the old
  /// trapping behaviour back and no compiler complaint, so the parameters are
  /// named to make the omission obvious in review.
  final Widget Function(
    BuildContext context,
    ScrollController scrollController,
    ScrollPhysics physics,
  ) builder;

  @override
  State<AuraBoundedEditor> createState() => _AuraBoundedEditorState();
}

class _AuraBoundedEditorState extends State<AuraBoundedEditor> {
  final ScrollController _inner = ScrollController();

  @override
  void dispose() {
    _inner.dispose();
    super.dispose();
  }

  /// Can the editor absorb this movement itself?
  ///
  /// False when it has no scrollable range at all, and false at each end in
  /// the direction that would go past it. Both are the cases where the page
  /// should move instead.
  bool _canAbsorb(double delta) {
    if (!_inner.hasClients) return false;
    final ScrollPosition p = _inner.position;
    if (p.maxScrollExtent <= p.minScrollExtent) return false;
    if (delta > 0) return p.pixels < p.maxScrollExtent;
    if (delta < 0) return p.pixels > p.minScrollExtent;
    return false;
  }

  void _apply(PointerEvent event) {
    if (event is! PointerScrollEvent || !_inner.hasClients) return;
    final ScrollPosition p = _inner.position;
    final double target = (p.pixels + event.scrollDelta.dy).clamp(
      p.minScrollExtent,
      p.maxScrollExtent,
    );
    if (target != p.pixels) p.jumpTo(target);
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;

    // Registering is the act of claiming. Claim only what the editor can
    // actually use; anything else is left for the enclosing scrollable, whose
    // own registration then wins uncontested.
    if (_canAbsorb(event.scrollDelta.dy)) {
      GestureBinding.instance.pointerSignalResolver.register(event, _apply);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _onPointerSignal,
      child: widget.builder(
        context,
        _inner,
        const NeverScrollableScrollPhysics(),
      ),
    );
  }
}
