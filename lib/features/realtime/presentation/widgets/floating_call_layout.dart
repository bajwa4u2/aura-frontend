/// WHAT A MINIMISED CALL IS FOR.
///
/// Founder, 2026-09-24: *"pip is odd and ugly its same for the audio and
/// video"*.
///
/// Both halves of that were true, and the second one caused the first. The old
/// card had ONE shape for every call: a navy panel, a title row saying "Video
/// Call" or "Audio Call", a status row, a control row, and — on video — a 68px
/// strip showing YOUR OWN camera, mirrored. So an audio call, which has nothing
/// to look at, got the same three rows of furniture as a video call; and a video
/// call, which does, spent its picture area on the one participant the viewer
/// already knows what they look like.
///
/// The rule this file holds is the same one the meetings stage was rebuilt on a
/// few hours earlier: CONTENT FIRST, INTERFACE SECOND. A minimised call exists
/// so the call keeps going while you look at something else. What that needs to
/// carry is the *other person* — their picture if there is one, their name and
/// the running time if there is not — plus a way back and a way out.
///
/// Two compositions, because there are two different contents:
///
///   * [FloatingCallComposition.picture] — there is a remote picture decoding,
///     so the card IS that picture, and everything else sits over it.
///   * [FloatingCallComposition.bar] — there is nothing to look at, so the card
///     does not pretend: one short row, no empty video well.
///
/// These are pure so they can be asserted without a renderer, a socket or a
/// camera.
library;

import 'dart:ui' show Size;

/// Which composition a minimised call takes.
enum FloatingCallComposition {
  /// The remote participant's picture, with the call's controls over it.
  picture,

  /// A single compact row. No picture area at all.
  bar,
}

/// The card's width, in logical pixels. One width for both compositions: the
/// PiP should not jump sideways when a camera comes on.
const double kFloatingCallWidth = 276.0;

/// The picture composition's aspect, matching the meetings stage so a face is
/// framed the same way wherever it appears.
const double kFloatingCallPictureAspect = 16 / 9;

/// Height of the control strip laid over the bottom of a picture.
const double kFloatingCallScrimHeight = 52.0;

/// The bar composition's height: one row, sized by [kFloatingControlTapTarget]
/// plus breathing room, and nothing else.
const double kFloatingCallBarHeight = 68.0;

/// The minimum square a finger can be asked to find.
///
/// `kMinInteractiveDimension` from Material, restated because this number is
/// the whole point of the C-4 repair — the Return control used to be a pill
/// about 21 logical pixels tall, which a mouse hits every time and a thumb does
/// not. Public so a test can assert the NUMBER, not the source text.
const double kFloatingControlTapTarget = 48.0;

/// THE PICTURE IS THE ONLY THING THAT EARNS THE PICTURE COMPOSITION.
///
/// Not "is this a video call" — a video call whose participants both have their
/// cameras off has nothing to show, and a black 16:9 well is worse than no well
/// at all. Not the server's `videoState` either: that flag is under repair
/// (M-10) and has been observed reporting OFF for participants who were
/// visibly publishing. The truth is whether a renderer is decoding a frame
/// right now, which is what the caller passes in.
FloatingCallComposition floatingCallComposition({
  required bool isVideo,
  required bool hasRemotePicture,
}) {
  if (isVideo && hasRemotePicture) return FloatingCallComposition.picture;
  return FloatingCallComposition.bar;
}

/// The card's size for a composition.
///
/// Used for layout AND for clamping the drag inside the safe area, so the two
/// can never disagree — the old card clamped against a hardcoded estimate that
/// was already wrong, which let it be parked with its controls under the home
/// indicator.
Size floatingCallSize(FloatingCallComposition composition) {
  switch (composition) {
    case FloatingCallComposition.picture:
      return const Size(
        kFloatingCallWidth,
        kFloatingCallWidth / kFloatingCallPictureAspect,
      );
    case FloatingCallComposition.bar:
      return const Size(kFloatingCallWidth, kFloatingCallBarHeight);
  }
}

/// Whether this composition shows a participant's picture.
bool floatingCallShowsPicture(FloatingCallComposition composition) =>
    composition == FloatingCallComposition.picture;

/// Whether the call's kind needs saying in words.
///
/// On a picture you can SEE that it is a video call, so the label is noise —
/// that title row was one of the three the founder was counting. On a bar there
/// is nothing to see, so the words carry it.
bool floatingCallNamesItsKind(FloatingCallComposition composition) =>
    composition == FloatingCallComposition.bar;
