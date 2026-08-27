// TRACE CROSS-SURFACE CONVERGENCE.
//
// ─────────────────────────────────────────────────────────────────────────────
// WHAT THIS IS, AND WHAT IT IS NOT
//
// This is a SOURCE-INSPECTION test. It protects architecture; it is NOT product
// proof, and it must never be cited as one. The product proof is the lifecycle
// test, which starts from real provenance-bearing bytes and ends at a rendered
// disclosure on a real device.
//
// It exists because "it inherits" was assumed three times and was wrong three
// times. Trace does not reach a surface because the architecture says it
// should; it reaches a surface because that surface routes through something
// that mounts it. This enumerates every widget in the app that renders stored
// media and asserts each one is accounted for — either it goes through an
// adapter that mounts TR, or it mounts TR itself, or it is recorded here as a
// known exclusion with a reason.
//
// A new media consumer added later fails this test until someone decides which
// of those three it is. That decision is the point.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Widgets that render stored media and MOUNT TR themselves.
///
/// Each is a genuine choke point: every path to media on that surface passes
/// through it, which is what makes the mark structural rather than a list of
/// integrations someone has to keep complete.
const mountsTraceItself = <String>{
  // The shared adapter the feed, announcements and institution surfaces all
  // route through. A post with ONE image never enters the collage, which is
  // why mounting on collage cells left the commonest case invisible.
  'lib/core/media/canonical_media_thumb.dart',
  // PostCard builds its own frame instead of using the adapter, so post
  // detail, the author profile and saves inherited nothing.
  'lib/features/posts/presentation/widgets/post_card/post_card_parts.dart',
  // Conversation renders by attachment kind; the mark wraps the renderer
  // rather than one branch, because it was on VIDEO only and images are the
  // kind that actually carry AI provenance here.
  'lib/features/conversation/presentation/conversation_screen.dart',
  // The text mark, at the one control every text surface already renders.
  'lib/core/translation/communication_translate_action.dart',
  // The immersive viewer.
  'lib/core/media/aura_media_viewer.dart',
  // Meeting assets are stored media like any other. This surface was the one
  // the inventory found rendering media with no account at all, which is
  // exactly the kind of gap "it inherits" hides.
  'lib/features/meetings/presentation/widgets/meeting_assets_section.dart',
};

/// Widgets that render media and legitimately do NOT mount TR.
///
/// Every entry needs a reason that is about EVIDENCE, not convenience.
const knownExclusions = <String, String>{
  'lib/core/media/aura_media_group.dart':
      'Delegates every cell and the single-media case to CanonicalMediaThumb. '
          'Mounting here too would double the mark on the collage path.',
  'lib/core/media/aura_media_frame.dart':
      'A layout primitive. It is handed a URL and a shape and knows nothing '
          'about a media identity, so it has no evidence to disclose.',
  'lib/core/media/aura_stored_media.dart':
      'The presentation authority for one stored object — poster, play '
          'affordance, failure states. Its callers own the media identity and '
          'mount the mark; mounting here would put TR inside every embed '
          'including ones with no Trace-bearing model.',
  'lib/core/media/aura_video_surface.dart':
      'The decoder surface. Same reasoning as the frame.',
  'lib/core/media/aura_resolvable_attachment_image.dart':
      'Resolves a signed URL for a restricted object. It is a delivery '
          'concern; the surface that asked for the image owns the disclosure.',
  'lib/core/media/aura_composition_strip.dart':
      'COMPOSER-side. It shows what is about to be sent, which has no '
          'server-resolved account yet — Trace is resolved at rest, from '
          'evidence recorded during ingestion.',
  'lib/features/posts/presentation/compose/compose_widgets.dart':
      'Composer-side, same reasoning as the strip.',
  'lib/core/media/stored_media.dart':
      'A model, not a widget. It describes bytes and delivery, and holds no '
          'resolved account to disclose.',
  'lib/features/posts/presentation/widgets/post_card/post_card_models.dart':
      'A model, not a widget. It CARRIES the account that '
          'PostCardSingleMediaCard mounts.',
  'lib/features/institutions/posts/institution_post_detail_screen.dart':
      'Renders the focused post through UnifiedFeedCard and its replies '
          'through the translate control. Both mount the mark.',
  'lib/features/feed/domain/feed_media.dart':
      'A model, not a widget. It CARRIES the account.',
  'lib/features/feed/presentation/unified_feed_card.dart':
      'Routes media through AuraMediaGroup and text through the translate '
          'control. Both mount the mark.',
  'lib/features/announcements/presentation/announcement_detail_screen.dart':
      'Routes media through AuraMediaGroup, which delegates to the shared '
          'adapter that mounts the mark.',
  'lib/features/announcements/presentation/announcements_screen.dart':
      'Routes media through AuraMediaGroup, which delegates to the shared '
          'adapter that mounts the mark.',
  'lib/features/institutions/announcements/institution_announcements_screen.dart':
      'Routes media through AuraMediaGroup, which delegates to the shared '
          'adapter that mounts the mark.',
  'lib/core/media/media_url_resolver.dart':
      'Not a widget. It resolves a delivery URL and never sees a media '
          'identity or an account.',
};

void main() {
  group('EVERY stored-media consumer is accounted for', () {
    late final List<String> consumers;

    setUpAll(() {
      // The same inventory a person would run by hand, run every time instead.
      final markers = [
        'AuraMediaGroup',
        'CanonicalMediaThumb',
        'AuraStoredMedia',
        'AuraResolvableAttachmentImage',
        'AuraMediaFrame',
      ];
      consumers = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) {
            final src = f.readAsStringSync();
            return markers.any(src.contains);
          })
          .map((f) => f.path.replaceAll(r'\', '/'))
          .toList()
        ..sort();
    });

    test('the inventory is not empty (guard against a broken scan)', () {
      // If the scan silently found nothing, every assertion below would pass.
      expect(consumers.length, greaterThan(5));
    });

    test('each one mounts TR, or is a recorded exclusion with a reason', () {
      final unaccounted = consumers
          .where((p) => !mountsTraceItself.contains(p))
          .where((p) => !knownExclusions.containsKey(p))
          .toList();

      expect(
        unaccounted,
        isEmpty,
        reason:
            'These render stored media and are neither mounting TR nor recorded '
            'as an exclusion. Decide which, and say why:\n  ${unaccounted.join("\n  ")}',
      );
    });

    test('every claimed mount actually mounts it', () {
      // A file can be listed above and then quietly stop mounting the mark.
      // The claim has to keep being true.
      for (final path in mountsTraceItself) {
        final src = File(path).readAsStringSync();
        expect(
          src.contains('AuraTraceMark'),
          isTrue,
          reason: '$path is listed as mounting TR and does not.',
        );
        expect(
          src.contains('showAuraTrace'),
          isTrue,
          reason: '$path mounts the mark but nothing opens the surface.',
        );
      }
    });

    test('every exclusion states a reason', () {
      for (final entry in knownExclusions.entries) {
        expect(
          entry.value.trim().length,
          greaterThan(30),
          reason: '${entry.key} is excluded without a real reason.',
        );
      }
    });
  });

  group('NO PARALLEL PROVENANCE PRESENTATION competes with TR', () {
    test('the legacy edit-disclosure line is retired', () {
      // It rendered "Edited for clarity or privacy" on every profile crop —
      // an editorial judgement about content that nobody ever made. Two
      // provenance presentations on one object is one too many.
      final src = File(
        'lib/features/posts/presentation/widgets/post_card/post_card_parts.dart',
      ).readAsStringSync();
      final live = src
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(live, isNot(contains("'Edited for clarity or privacy'")));
    });

    test('no surface renders an origin badge outside Trace', () {
      // The origin badge TR superseded. If one reappears, a reader gets two
      // different accounts of the same object.
      for (final file in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final live = file
            .readAsStringSync()
            .split('\n')
            .where((l) => !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
            .join('\n');
        expect(
          live.contains("'AI-generated'") || live.contains("'AI generated'"),
          isFalse,
          reason: '${file.path} states an AI verdict outside Trace.',
        );
      }
    });
  });
}
