/// BOUNDED MEDIA INITIALIZATION — the state machine every player shares.
///
/// Founder ruling 2026-08-26: a media surface may be
///
///     INITIALIZING -> READY
///
/// or, past a defensible threshold,
///
///     INITIALIZING -> ERROR / UNAVAILABLE
///
/// and never `INITIALIZING` forever.
///
/// ## WHY THIS EXISTS AS A SHARED AUTHORITY
///
/// All three players already implement an honest failure state. What they
/// lacked was a way to REACH it: `VideoPlayerController.initialize()` returns a
/// Future that rejects on error but simply never completes when the underlying
/// load stalls — a decoder waiting on bytes that are not arriving is not an
/// error, it is silence. `catchError` cannot fire on silence, so the spinner
/// outlived the problem. That was observed in production on the immersive
/// viewer, and the same shape was latent in the inline surface and the voice
/// player.
///
/// Putting the bound here rather than in each player is what stops the three
/// from drifting into three different definitions of "too long".
///
/// ## WHY THE PHASES ARE NAMED
///
/// The ruling asks that acquisition, decoding and playback be distinguished
/// where it matters, and it matters for the threshold: fetching a first byte
/// over a slow mobile network is a fundamentally more patient operation than a
/// decoder that has already been handed its bytes. One global number would
/// either cut off a slow network unfairly or let a wedged decoder hang.
///
/// These are deliberately generous. The purpose is to convert an INFINITE wait
/// into a FINITE one, not to police performance — a threshold tight enough to
/// fire on a merely slow connection would turn a working video into a false
/// error, which is a worse product than a slow one.
library;

import 'dart:async';

/// What is being waited on. The value chosen bounds the wait.
enum MediaInitPhase {
  /// Opening a source and acquiring first bytes, possibly over a slow network.
  acquisition,

  /// A decoder that already has its source and must produce a first frame.
  decode,

  /// Fetching a poster image — an enhancement, so it waits the least.
  poster,

  /// Starting playback on an already-initialized controller.
  playback,
}

/// The bound for each phase.
///
/// Changing one of these changes when a user is told something is wrong, so
/// each is stated with its reason rather than tuned by feel.
Duration mediaInitTimeout(MediaInitPhase phase) {
  switch (phase) {
    case MediaInitPhase.acquisition:
      // Long enough for a large object on a poor mobile connection to begin
      // arriving; short enough that a person is not left watching nothing.
      return const Duration(seconds: 30);
    case MediaInitPhase.decode:
      // The bytes are already in hand. A decoder still working after this is
      // wedged, not busy.
      return const Duration(seconds: 20);
    case MediaInitPhase.poster:
      // A poster is recognition, not the media. Failing fast here costs the
      // user nothing: the surface falls back to its honest identity tile.
      return const Duration(seconds: 15);
    case MediaInitPhase.playback:
      // play() resolving is not the same as playback being audible, but a
      // call that has not returned by now will not.
      return const Duration(seconds: 15);
  }
}

/// Raised when a phase exceeded its bound. Distinct from a decode failure, so
/// a caller that wants to report them differently can.
class MediaInitTimeout implements Exception {
  const MediaInitTimeout(this.phase);

  final MediaInitPhase phase;

  @override
  String toString() => 'MediaInitTimeout(${phase.name})';
}

/// Run [operation] under the bound for [phase].
///
/// Throws [MediaInitTimeout] rather than returning null, so an existing
/// `catch` that already routes to an honest error state picks this up with no
/// change — which is the point: the honest UI these players already have
/// becomes reachable instead of being rewritten.
Future<T> boundedMediaInit<T>(
  MediaInitPhase phase,
  Future<T> Function() operation, {
  Duration? timeout,
}) {
  final limit = timeout ?? mediaInitTimeout(phase);
  return operation().timeout(
    limit,
    onTimeout: () => throw MediaInitTimeout(phase),
  );
}
