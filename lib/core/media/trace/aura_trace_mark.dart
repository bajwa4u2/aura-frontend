/// THE TR MARK — a small doorway, never a verdict.
///
/// TR appears when Aura has something worth disclosing. It is deliberately two
/// characters and no colour of its own, because the alternative is a badge that
/// competes with the content it annotates.
///
/// ## WHY IT IS NOT A COLOURED WARNING CHIP
///
/// A red or amber mark would read as an accusation about the person who posted
/// the media, and Trace is not an accusation — most of what it discloses is
/// neutral or even reassuring (recorded in Aura, credentials attached). Colour
/// is reserved for the one case where something is genuinely unresolved, and
/// even then it is a hairline, not a fill.
///
/// ## WHY IT SURVIVES ANY BACKGROUND
///
/// It sits over photographs, video posters, dark audio surfaces and white
/// documents. A single fill colour cannot be legible on all of them, so the
/// mark carries its own scrim: a translucent dark plate with a light glyph,
/// which is the one combination that holds on both a snow scene and a night
/// shot. The plate is the minimum size that stays readable rather than the
/// minimum that fits.
///
/// ## TOUCH TARGET
///
/// The visible mark is small; the TAP TARGET is not. On touch clients it is
/// padded out to a comfortable minimum, because a 16-pixel affordance over an
/// image is something people miss and then poke at repeatedly — and each miss
/// lands on the media instead, opening the viewer they did not ask for.
library;

import 'package:flutter/material.dart';

import '../../ui/aura_text.dart';
import 'aura_trace.dart';

/// The minimum comfortable touch target, per platform accessibility guidance.
const double kTraceTouchTarget = 44;

class AuraTraceMark extends StatelessWidget {
  const AuraTraceMark({
    super.key,
    required this.trace,
    required this.onOpen,
    this.compact = false,
    this.touch = false,
  });

  final AuraTrace trace;
  final VoidCallback onOpen;

  /// Inside a collage cell, where a full-size mark would crowd the media.
  final bool compact;

  /// Expand the tap target for fingers without growing the visible mark.
  final bool touch;

  @override
  Widget build(BuildContext context) {
    // THE VISIBILITY RULE, enforced at the widget boundary too. Nothing renders
    // when there is nothing to disclose — an object existing in Aura's database
    // is not something worth marking.
    if (trace.isEmpty) return const SizedBox.shrink();

    final size = compact ? 18.0 : 22.0;
    final mark = Container(
      height: size,
      padding: EdgeInsets.symmetric(horizontal: compact ? 5 : 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // Its own scrim, so the mark is legible over a snow scene and a night
        // shot alike without knowing anything about the media beneath it.
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(6),
        border: trace.hasConflict
            // The ONE case that earns colour, and only as a hairline: something
            // is genuinely unresolved and a reader should know before deciding
            // what to make of the object.
            ? Border.all(color: const Color(0xFFE0A44A), width: 1)
            : Border.all(color: Colors.white24, width: 1),
      ),
      child: Text(
        'TR',
        style: AuraText.small.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: compact ? 10 : 11,
          letterSpacing: 0.5,
          height: 1.1,
        ),
      ),
    );

    return Semantics(
      button: true,
      // The label says what opening it DOES, not what it concludes — the mark
      // itself concludes nothing.
      label: trace.headline == null
          ? 'Trace. What Aura knows about this.'
          : 'Trace. ${trace.headline}. Open for details.',
      child: Tooltip(
        message: trace.headline ?? 'What Aura knows about this',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(6),
            child: touch
                // The visible mark stays small; the target does not. A missed
                // tap here lands on the media and opens a viewer nobody asked
                // for, which is why the padding is generous.
                ? ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: kTraceTouchTarget,
                      minHeight: kTraceTouchTarget,
                    ),
                    child: Center(child: mark),
                  )
                : mark,
          ),
        ),
      ),
    );
  }
}
