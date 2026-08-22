import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/realtime/presentation/widgets/floating_call_widget.dart';

// THE PiP APPEAR / EXPAND / REPLACE SEQUENCE ON ACCEPT.
//
// Founder-observed 2026-08-22, worse on mobile: accepting a call showed the
// floating call widget, which grew, and was then replaced by the full room.
//
// Visibility was driven by `isCallRoomVisible`, which the room sets in
// initState. `dispose` IS synchronous with leaving (so minimising was already
// correct), but `initState` runs only after the route builds — so ENTERING
// left a window where the call was joined and the room was not yet on screen,
// and the PiP filled it.
//
// A second "entering" flag would have been another race to arbitrate. The
// ADDRESS changes synchronously with navigation in both directions, so it
// answers the question without a window.
void main() {
  test('a conversation call room owns the screen', () {
    expect(callSurfaceOwnsTheScreen(Uri.parse('/realtime/sess_1')), isTrue);
    expect(
      callSurfaceOwnsTheScreen(Uri.parse('/realtime/sess_1?action=join')),
      isTrue,
      reason: 'the accept path arrives with intent in the address',
    );
  });

  test('a Meeting live room owns the screen too, without being the same system', () {
    expect(callSurfaceOwnsTheScreen(Uri.parse('/meetings/m1/live')), isTrue);
    expect(callSurfaceOwnsTheScreen(Uri.parse('/meetings/m1/prep')), isFalse);
    expect(callSurfaceOwnsTheScreen(Uri.parse('/meetings/m1')), isFalse);
  });

  test('anywhere else, an ongoing call still deserves its PiP', () {
    for (final path in [
      '/home',
      '/messages/c/c1',
      '/articles/some-slug',
      '/realtime',
    ]) {
      expect(callSurfaceOwnsTheScreen(Uri.parse(path)), isFalse,
          reason: '$path is not a call surface');
    }
  });
}
