/// THE TRACE SURFACE — the product behind TR.
///
/// TR is the signal. This is the thing it exists for, and it must answer, in
/// ordinary language: what does Aura know, what does that mean, how does Aura
/// know it, what happened to this content, and what remains unknown.
///
/// ## THE HIERARCHY IS THE PRODUCT
///
/// The headline first, because a person who reads nothing else should still
/// learn the most consequential thing Aura can responsibly say. Then the
/// source, then plain meaning, then the evidence behind it, then the history,
/// then who published it, and only then the boundary.
///
/// The previous surface led with "What Aura knows about this, and how it knows
/// it" and then showed one fact. Every word of that was true and none of it was
/// useful — the reader had to construct the meaning themselves out of evidence
/// vocabulary. The ordering here is the correction, and it is decided on the
/// server so it cannot drift per platform.
///
/// ## THE CONTAINER FOLLOWS THE EVIDENCE
///
/// A simple Trace gets a compact inspector. A rich one — a real sequence, a
/// disagreement, or several distinct facts — may expand. Nothing is allocated
/// a near-full-screen panel because the component supports one.
///
/// ## PLATFORM-AWARE, NOT SHRUNKEN DESKTOP
///
/// Touch clients get a sheet sized to its content, because that is the native
/// idiom for progressive disclosure and it is reachable one-handed. Pointer
/// clients get an inspector, because a sheet on a wide screen wastes the space
/// it has and puts the content at the edge furthest from the pointer.
///
/// Both read the same `MediaInteractionProfile` the viewer uses, so this is one
/// decision made once rather than a second platform opinion that could drift.
///
/// ## WHAT IT REFUSES TO SHOW
///
/// Never a metadata dump: raw EXIF, GPS, device identifiers, provider internals
/// and storage URLs are not here, and the server does not send them — evidence
/// existing is not evidence being disclosed. Empty sections never render; a
/// heading with nothing under it reads as something withheld.
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

  final p = profile ?? MediaInteractionProfile.resolve(canDecodeVideo: true);

  if (p.pointer == PointerModel.touch) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TraceSheet(trace: trace),
    );
  }

  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => _TraceInspector(trace: trace),
  );
}

class _TraceSheet extends StatelessWidget {
  const _TraceSheet({required this.trace});

  final AuraTrace trace;

  @override
  Widget build(BuildContext context) {
    // SIZED TO ITS CONTENT. A simple Trace opens small and can still be dragged
    // up; a rich one opens with the sequence already visible so the reader is
    // not made to hunt for the part that took work to establish.
    final simple = trace.density == TraceDensity.simple;

    return DraggableScrollableSheet(
      initialChildSize: simple ? 0.42 : 0.68,
      minChildSize: 0.28,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, controller) => Container(
        decoration: const BoxDecoration(
          color: AuraSurface.card,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AuraRadius.lg)),
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
            Expanded(child: _TraceBody(trace: trace, controller: controller)),
            SafeArea(top: false, child: _TraceBoundary(text: trace.about)),
          ],
        ),
      ),
    );
  }
}

class _TraceInspector extends StatelessWidget {
  const _TraceInspector({required this.trace});

  final AuraTrace trace;

  @override
  Widget build(BuildContext context) {
    // THE CONTENT SETS THE HEIGHT; the ceiling only stops it running away.
    //
    // A fixed per-density height was the wrong mechanism and it hid the
    // evidence: with real desktop fonts a simple Trace is taller than it is
    // under the test font, so a 470px cap clipped the Evidence section — and
    // with it "Aura has not independently verified the credential signer",
    // the one line a reader must never be the one to miss.
    //
    // The body already shrink-wraps, so a small Trace stays small on its own.
    // What the rejected panel got wrong was allocating a near-full-screen
    // surface REGARDLESS of content, which a ceiling proportional to the
    // viewport prevents without ever truncating what is there.
    final maxH = MediaQuery.sizeOf(context).height * 0.8;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 460,
          maxHeight: maxH.clamp(320.0, 720.0),
        ),
        child: Material(
          color: AuraSurface.card,
          borderRadius: BorderRadius.circular(AuraRadius.lg),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: _TraceBody(trace: trace)),
              _TraceBoundary(text: trace.about),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpace.s8,
                  vertical: AuraSpace.s4,
                ),
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
    return ListView(
      controller: controller,
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.s16,
        AuraSpace.s12,
        AuraSpace.s16,
        AuraSpace.s20,
      ),
      children: [
        // ── THE MARK AND THE NAME ────────────────────────────────────────
        Row(
          children: [
            const _TraceGlyph(),
            const SizedBox(width: AuraSpace.s8),
            Text('Trace', style: AuraText.small.copyWith(
              color: AuraSurface.faint,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            )),
          ],
        ),
        const SizedBox(height: AuraSpace.s12),

        // ── THE HEADLINE ─────────────────────────────────────────────────
        //
        // First, and largest. A person who reads nothing else still learns the
        // most consequential thing Aura can responsibly say.
        Text(
          trace.headline ?? '',
          style: AuraText.title.copyWith(height: 1.2),
        ),

        if ((trace.source ?? '').isNotEmpty) ...[
          const SizedBox(height: AuraSpace.s4),
          Text(
            trace.source!,
            style: AuraText.body.copyWith(
              color: AuraSurface.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],

        if ((trace.summary ?? '').isNotEmpty) ...[
          const SizedBox(height: AuraSpace.s10),
          Text(
            trace.summary!,
            style: AuraText.body.copyWith(height: 1.45),
          ),
        ],

        _Section(
          title: 'Evidence',
          show: trace.evidence.isNotEmpty || trace.uncertainty.isNotEmpty,
          children: [
            for (final line in trace.evidence)
              _Line(title: line.label, detail: line.detail),
            // The limits, with the evidence rather than buried at the bottom —
            // an unverified signer is part of what the evidence IS, not a
            // footnote to it.
            for (final u in trace.uncertainty)
              Padding(
                padding: const EdgeInsets.only(bottom: AuraSpace.s6),
                child: Text(
                  u,
                  style: AuraText.small.copyWith(
                    color: AuraSurface.faint,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),

        _Section(
          title: 'History',
          show: trace.history.isNotEmpty,
          children: [
            for (var i = 0; i < trace.history.length; i++)
              _HistoryRow(
                step: trace.history[i],
                isLast: i == trace.history.length - 1,
              ),
          ],
        ),

        _Section(
          title: 'Publication',
          show: trace.publication != null && !trace.publication!.isEmpty,
          children: [
            if (trace.publication != null)
              _Line(
                title: trace.publication!.by ?? 'Published',
                detail: trace.publication!.forInstitution == null
                    ? null
                    : 'for ${trace.publication!.forInstitution}',
              ),
          ],
        ),

      ],
    );
  }
}

/// The provenance/truth boundary.
///
/// PINNED, not scrolled past. It is what stops TR being read as a mark of
/// approval, so it must be present whatever the reader does — but it is also
/// the thing that must not crowd out what Aura actually found, which is why it
/// sits quietly at the edge rather than in the flow above the evidence.
class _TraceBoundary extends StatelessWidget {
  const _TraceBoundary({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AuraSpace.s16,
            AuraSpace.s10,
            AuraSpace.s16,
            AuraSpace.s12,
          ),
          child: Text(
            text,
            style: AuraText.small.copyWith(color: AuraSurface.faint),
          ),
        ),
      ],
    );
  }
}

class _TraceGlyph extends StatelessWidget {
  const _TraceGlyph();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: AuraSurface.divider),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        'TR',
        style: AuraText.small.copyWith(
          color: AuraSurface.faint,
          fontWeight: FontWeight.w700,
          fontSize: 10,
          letterSpacing: 0.5,
          height: 1.2,
        ),
      ),
    );
  }
}

/// A titled group that renders nothing at all when it has nothing to show.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.show,
    required this.children,
  });

  final String title;
  final bool show;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (!show || children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AuraSpace.s16),
        Text(
          title,
          style: AuraText.small.copyWith(
            color: AuraSurface.faint,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: AuraSpace.s8),
        ...children,
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.title, this.detail});

  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AuraText.body.copyWith(fontWeight: FontWeight.w600)),
          if ((detail ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              detail!,
              style: AuraText.small.copyWith(
                color: AuraSurface.faint,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One step of the object's history, with the rail that makes it a sequence.
class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.step, required this.isLast});

  final TraceHistoryStep step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The rail. It is what makes these read as one sequence rather than
          // four unrelated statements.
          Column(
            children: [
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(top: 5),
                decoration: BoxDecoration(
                  color: AuraSurface.muted,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 1, color: AuraSurface.divider),
                ),
            ],
          ),
          const SizedBox(width: AuraSpace.s10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AuraSpace.s10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if ((step.detail ?? '').isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      step.detail!,
                      style: AuraText.small.copyWith(
                        color: AuraSurface.faint,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (step.basis.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    // HOW AURA HOLDS THIS STEP, on the step itself. It is what
                    // stops a creator's declaration reading like a verification
                    // when the two sit next to each other in one sequence.
                    Text(
                      step.basis,
                      style: AuraText.small.copyWith(
                        color: AuraSurface.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
