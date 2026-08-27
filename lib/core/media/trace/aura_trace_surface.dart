/// THE TRACE SURFACE — what opens behind TR.
///
/// The sophistication belongs HERE, behind the interaction, not across the
/// content. The media surface stays quiet; this is where a person can actually
/// inspect the basis for a disclosure.
///
/// ## PLATFORM-AWARE, NOT SHRUNKEN DESKTOP
///
/// Touch clients get a draggable bottom sheet — the native idiom for
/// progressive disclosure, reachable one-handed, dismissed by dragging down.
/// Pointer clients get a centred dialog panel, because a sheet on a wide screen
/// wastes the space it has and puts the content at the bottom edge, furthest
/// from where the pointer already is.
///
/// It reads the same `MediaInteractionProfile` the viewer uses, so this is one
/// decision made once rather than a second platform opinion that could drift
/// from the first.
///
/// ## WHAT IT SHOWS, AND WHAT IT REFUSES TO
///
/// Human-readable facts, grouped, each carrying HOW IT IS HELD. Never a metadata
/// dump: raw EXIF, GPS, device identifiers, provider internals and storage URLs
/// are not here, and the server does not send them — evidence existing is not
/// evidence being disclosed.
///
/// Empty sections never render. A heading with nothing under it reads as
/// something withheld, which is the opposite of the point.
library;

import 'package:flutter/material.dart';

import '../../ui/aura_radius.dart';
import '../../ui/aura_space.dart';
import '../../ui/aura_surface.dart';
import '../../ui/aura_text.dart';
import '../media_interaction_profile.dart';
import 'aura_trace.dart';

/// Open Trace using the idiom this platform actually uses.
Future<void> showAuraTrace(
  BuildContext context, {
  required AuraTrace trace,
  MediaInteractionProfile? profile,
}) {
  if (trace.isEmpty) return Future<void>.value();

  final p = profile ??
      MediaInteractionProfile.resolve(canDecodeVideo: true);

  if (p.pointer == PointerModel.touch) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // Dragging down to dismiss is the gesture people already expect from a
      // sheet, and here it cannot conflict with anything: Trace has no pan or
      // zoom of its own to compete with.
      builder: (_) => _TraceSheet(trace: trace),
    );
  }

  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (_) => _TracePanel(trace: trace),
  );
}

class _TraceSheet extends StatelessWidget {
  const _TraceSheet({required this.trace});

  final AuraTrace trace;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, controller) => Container(
        decoration: const BoxDecoration(
          color: AuraSurface.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AuraRadius.lg)),
        ),
        child: Column(
          children: [
            const SizedBox(height: AuraSpace.s8),
            // The grab handle. It says "this moves" without a label.
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AuraSurface.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: _TraceBody(trace: trace, controller: controller),
            ),
          ],
        ),
      ),
    );
  }
}

class _TracePanel extends StatelessWidget {
  const _TracePanel({required this.trace});

  final AuraTrace trace;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: Material(
          color: AuraSurface.card,
          borderRadius: BorderRadius.circular(AuraRadius.lg),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(child: _TraceBody(trace: trace)),
              Padding(
                padding: const EdgeInsets.all(AuraSpace.s12),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('Close'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TraceBody extends StatelessWidget {
  const _TraceBody({required this.trace, this.controller});

  final AuraTrace trace;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final groups = trace.grouped;

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.s16,
        AuraSpace.s16,
        AuraSpace.s16,
        AuraSpace.s24,
      ),
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AuraSurface.ink,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'TR',
                style: AuraText.small.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: AuraSpace.s8),
            const Text('Trace', style: AuraText.title),
          ],
        ),
        const SizedBox(height: AuraSpace.s6),
        Text(
          // The promise, stated where a person can hold Aura to it.
          'What Aura knows about this, and how it knows it.',
          style: AuraText.small.copyWith(color: AuraSurface.faint),
        ),
        const SizedBox(height: AuraSpace.s16),

        for (final group in groups) ...[
          Text(
            traceSectionLabel(group.key),
            style: AuraText.small.copyWith(
              color: AuraSurface.faint,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: AuraSpace.s6),
          for (final fact in group.value) _FactRow(fact: fact),
          const SizedBox(height: AuraSpace.s16),
        ],

        const Divider(height: 1),
        const SizedBox(height: AuraSpace.s12),
        Text(
          // The boundary, said plainly rather than left to be inferred. This is
          // the sentence that stops TR being read as a mark of approval.
          'Trace shows what Aura can establish about how this was made and what '
          'happened to it. It is not a judgement about whether what it shows or '
          'says is true.',
          style: AuraText.small.copyWith(color: AuraSurface.faint),
        ),
      ],
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.fact});

  final TraceFact fact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  fact.summary,
                  style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: AuraSpace.s8),
              // HOW IT IS HELD, beside every single fact.
              //
              // This is the label that stops a creator's declaration reading
              // like a verification. It is never omitted, never abbreviated
              // away, and never merged with the summary.
              _EvidenceChip(evidence: fact.evidence),
            ],
          ),
          if (fact.detail != null) ...[
            const SizedBox(height: 2),
            Text(
              fact.detail!,
              style: AuraText.small.copyWith(color: AuraSurface.faint),
            ),
          ],
          if (fact.source != null) ...[
            const SizedBox(height: 2),
            Text(
              'Source: ${fact.source}',
              style: AuraText.small.copyWith(color: AuraSurface.faint),
            ),
          ],
        ],
      ),
    );
  }
}

class _EvidenceChip extends StatelessWidget {
  const _EvidenceChip({required this.evidence});

  final TraceEvidenceClass evidence;

  @override
  Widget build(BuildContext context) {
    // Only two visual weights, deliberately. Grading six classes by colour
    // would turn the evidence ladder into a traffic-light system people read as
    // good-versus-bad, when the distinction is actually firm-versus-tentative.
    final firm = evidence == TraceEvidenceClass.known ||
        evidence == TraceEvidenceClass.verified;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: firm ? AuraSurface.subtle : Colors.transparent,
        border: Border.all(color: AuraSurface.divider),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        traceEvidenceLabel(evidence),
        style: AuraText.small.copyWith(
          color: AuraSurface.faint,
          fontWeight: firm ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}
