import 'package:flutter/material.dart';

import '../../../../core/ui/aura_card.dart';
import '../../../../core/ui/aura_radius.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_surface.dart';
import '../meeting_semantics.dart';

/// THE PIECES MEETINGS IS COMPOSED FROM.
///
/// Founder ruling 2026-08-25 (visual reconstruction). The structural pass left
/// the product looking exactly as it did: five sections stacked vertically,
/// each with its own grey box saying "No X", and a centred spinner per section
/// while any of it loaded.
///
/// §19 is explicit that these are part of the design, not the absence of it:
/// *no giant generic spinners where meaningful context can remain visible; no
/// technical-looking error blocks; no dead white space with a sentence.*
///
/// So the states live here, once, and every Meetings surface uses them.
///
/// The section grammar is NOT here: `widgets/meeting_section.dart` already
/// owned it. A second one lived in this file briefly and was the exact
/// design-language fork section 21 forbids.

// ─────────────────────────────────────────────────────────────────────────
// LOADING
// ─────────────────────────────────────────────────────────────────────────

/// A calm placeholder with the SHAPE of what is coming.
///
/// A spinner says "wait"; a skeleton says "a meeting card is about to appear
/// here, and it will be about this big". The second is less anxious to look at
/// and stops the layout jumping when content lands.
///
/// Deliberately not animated. A shimmer across five cards is motion for its
/// own sake, which §18 rules out.
class MeetingSkeleton extends StatelessWidget {
  const MeetingSkeleton({super.key, this.lines = 2, this.height});

  final int lines;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading meetings',
      liveRegion: true,
      excludeSemantics: true,
      child: AuraCard(
        padding: const EdgeInsets.all(AuraSpace.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Bar(width: 92, height: 18),
            const SizedBox(height: AuraSpace.s12),
            for (var i = 0; i < lines; i++) ...[
              _Bar(width: i.isEven ? 260 : 180, height: 12),
              if (i != lines - 1) const SizedBox(height: AuraSpace.s8),
            ],
            if (height != null) SizedBox(height: height),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AuraSurface.elevated,
        borderRadius: BorderRadius.circular(AuraRadius.r10),
      ),
    );
  }
}

/// Loading that keeps the surrounding context. Used where a whole surface is
/// resolving and a skeleton of the real layout is worth showing.
class MeetingSkeletonList extends StatelessWidget {
  const MeetingSkeletonList({super.key, this.count = 2});

  final int count;

  @override
  Widget build(BuildContext context) => Column(
        // Without this the placeholder cards size to their content and sit
        // centred, so the loading state does not match the shape of the list
        // it is standing in for - which is the whole point of a skeleton.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < count; i++) ...[
            const MeetingSkeleton(),
            if (i != count - 1) const SizedBox(height: AuraSpace.s10),
          ],
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────
// EMPTY
// ─────────────────────────────────────────────────────────────────────────

/// Nothing here — said properly.
///
/// The version this replaces was a grey card containing one muted sentence,
/// repeated five times down the page. An empty state should tell a person
/// what would appear here and, where there is one, offer the action that
/// makes it appear.
class MeetingEmpty extends StatelessWidget {
  const MeetingEmpty({
    super.key,
    required this.icon,
    required this.headline,
    this.detail,
    this.action,
    this.compact = false,
  });

  final IconData icon;
  final String headline;
  final String? detail;
  final Widget? action;

  /// A quieter inline form for a section inside a page that has other content.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AuraCard(
      padding: EdgeInsets.all(compact ? AuraSpace.s16 : AuraSpace.s24),
      child: Column(
        crossAxisAlignment:
            compact ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Container(
            width: compact ? 34 : 46,
            height: compact ? 34 : 46,
            decoration: BoxDecoration(
              color: AuraSurface.elevated,
              borderRadius: BorderRadius.circular(AuraRadius.r12),
            ),
            child: Icon(icon,
                size: compact ? 18 : 24, color: AuraSurface.muted),
          ),
          SizedBox(height: compact ? AuraSpace.s10 : AuraSpace.s14),
          Text(
            headline,
            textAlign: compact ? TextAlign.start : TextAlign.center,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          if ((detail ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text(
              detail!,
              textAlign: compact ? TextAlign.start : TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AuraSurface.muted),
            ),
          ],
          if (action != null) ...[
            SizedBox(height: compact ? AuraSpace.s12 : AuraSpace.s16),
            action!,
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// ERROR
// ─────────────────────────────────────────────────────────────────────────

/// Something failed — said in the product's voice, not the exception's.
///
/// The version this replaces rendered `'Unable to load. $e'`, putting a raw
/// Dart exception on screen. §19: no technical-looking error blocks.
class MeetingError extends StatelessWidget {
  const MeetingError({
    super.key,
    required this.what,
    this.onRetry,
    this.technical,
  });

  /// What could not be loaded, in the person's words: "your upcoming
  /// meetings", not "MeetingsRepository.fetchUpcoming".
  final String what;
  final VoidCallback? onRetry;

  /// Kept for the log, never rendered.
  final String? technical;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AuraCard(
      padding: const EdgeInsets.all(AuraSpace.s16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 20, color: AuraSurface.muted),
          const SizedBox(width: AuraSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Could not load $what',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'Check your connection — this usually resolves on its own.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AuraSurface.muted),
                ),
              ],
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: AuraSpace.s10),
            MeetingAction(
              label: 'Try loading $what again',
              child: TextButton(onPressed: onRetry, child: const Text('Retry')),
            ),
          ],
        ],
      ),
    );
  }
}

/// A small, quiet label.
///
/// NOT `MeetingStatusChip` — that name belongs to the lifecycle-aware chip in
/// `presentation/meeting_status_chip.dart`, which reads a
/// `MeetingLifecycleViewModel` and phrases itself differently for a host than
/// for a guest. This is the generic primitive: a word and a tone. Colour alone never carries the meaning — the
/// label is the meaning, and the colour agrees with it.
class MeetingTag extends StatelessWidget {
  const MeetingTag({
    super.key,
    required this.label,
    this.tone = MeetingChipTone.neutral,
    this.icon,
  });

  final String label;
  final MeetingChipTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      MeetingChipTone.live => (const Color(0x2622C55E), const Color(0xFF4ADE80)),
      MeetingChipTone.soon => (AuraSurface.accentSoft, AuraSurface.accentText),
      MeetingChipTone.neutral => (AuraSurface.elevated, AuraSurface.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AuraRadius.r10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: fg, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

enum MeetingChipTone { neutral, soon, live }
