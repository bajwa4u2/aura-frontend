/// MEDIA ORIGIN LABELS — what Aura may say about where media came from.
///
/// The canonical resolver lives server-side and has already decided. This file
/// does ONE thing: turn a resolved state into words. It performs no inference,
/// combines no evidence and cannot upgrade a state — if it could, the whole
/// point of resolving centrally would be lost the moment two clients disagreed.
///
/// ## THE RULES THAT MATTER MOST ARE THE SILENCES
///
/// `NO_EVIDENCE` renders NOTHING. Not "unverified", not "origin unknown", not a
/// grey chip. Files lose their metadata constantly — a screenshot, a re-encode,
/// a platform that strips credentials — so absence of evidence is overwhelmingly
/// common and says nothing at all. A badge there would convert silence into an
/// accusation.
///
/// There is deliberately NO "Human created" label, and no state that could
/// produce one. Aura cannot know that, and a badge claiming it would be wrong
/// exactly when it mattered most.
///
/// `CONFLICTING` says sources disagree. It does NOT resolve to an AI or non-AI
/// answer, because picking one would be inventing the certainty the resolver
/// specifically declined to invent.
///
/// ## ITEM-SCOPED, ALWAYS
///
/// Origin belongs to a media object, never to a composition. A group holding
/// one verified AI image and three photographs is not an AI group, and this
/// file only ever describes a single item.
library;

import 'package:flutter/material.dart';

import '../ui/aura_surface.dart';
import '../ui/aura_text.dart';

/// The resolved states, mirroring the server's `DisclosureState`.
enum MediaOriginState {
  auraGenerated,
  aiGenerated,
  aiAltered,
  likelyAi,
  conflicting,
  noEvidence,
}

MediaOriginState mediaOriginStateFrom(String? wire) {
  switch ((wire ?? '').trim().toUpperCase()) {
    case 'AURA_GENERATED':
      return MediaOriginState.auraGenerated;
    case 'AI_GENERATED':
      return MediaOriginState.aiGenerated;
    case 'AI_ALTERED':
      return MediaOriginState.aiAltered;
    case 'LIKELY_AI':
      return MediaOriginState.likelyAi;
    case 'CONFLICTING':
      return MediaOriginState.conflicting;
    default:
      // Anything unrecognised is treated as nothing established. A state this
      // client does not know about must not become a guess.
      return MediaOriginState.noEvidence;
  }
}

/// The label, or null when Aura should say nothing.
String? mediaOriginLabel(MediaOriginState state) {
  switch (state) {
    case MediaOriginState.auraGenerated:
      return 'Made with Aura';
    case MediaOriginState.aiGenerated:
      return 'Generated with AI';
    case MediaOriginState.aiAltered:
      return 'AI-edited';
    case MediaOriginState.likelyAi:
      // HEDGED ON PURPOSE. Only a classifier thinks so, and a classifier is an
      // opinion about pixels. Stating it as fact would make a false positive
      // indistinguishable from a verified credential.
      return 'May be AI-generated';
    case MediaOriginState.conflicting:
      return 'Origin disputed';
    case MediaOriginState.noEvidence:
      // Silence. See the header.
      return null;
  }
}

/// Longer wording for the viewer's provenance surface.
String? mediaOriginDetail(MediaOriginState state, {required bool credentials}) {
  final base = switch (state) {
    MediaOriginState.auraGenerated =>
      'Aura produced this media, so its origin is known rather than inferred.',
    MediaOriginState.aiGenerated =>
      'A source Aura can check reports that this was generated with AI.',
    MediaOriginState.aiAltered =>
      'A source Aura can check reports that this was edited with AI.',
    MediaOriginState.likelyAi =>
      'An automated check suggests AI involvement. That is an opinion, not a '
          'verified record, and it can be wrong.',
    MediaOriginState.conflicting =>
      'Sources disagree about how this was made, so Aura is not stating an '
          'answer.',
    MediaOriginState.noEvidence =>
      'Aura has nothing recorded about how this was made. That is not a '
          'statement that a person made it — media loses this information '
          'easily.',
  };
  if (!credentials) return base;
  return '$base Content Credentials are attached to this file.';
}

/// A restrained inline indicator. Returns nothing when Aura should be silent.
class MediaOriginBadge extends StatelessWidget {
  const MediaOriginBadge({
    super.key,
    required this.state,
    this.compact = false,
  });

  final MediaOriginState state;

  /// Inside a collage cell, where a full label would crowd the media.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = mediaOriginLabel(state);
    if (label == null) return const SizedBox.shrink();

    return Semantics(
      label: label,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 5 : 7,
          vertical: compact ? 1 : 2,
        ),
        decoration: BoxDecoration(
          // Deliberately neutral. The purpose is transparency, not stigma, and
          // a warning colour would make disclosure feel like an accusation.
          color: AuraSurface.ink.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          compact ? _compactLabel(state) ?? label : label,
          style: (compact ? AuraText.small : AuraText.small).copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  static String? _compactLabel(MediaOriginState state) {
    switch (state) {
      case MediaOriginState.auraGenerated:
      case MediaOriginState.aiGenerated:
      case MediaOriginState.aiAltered:
      case MediaOriginState.likelyAi:
        return 'AI';
      case MediaOriginState.conflicting:
        return '?';
      case MediaOriginState.noEvidence:
        return null;
    }
  }
}
