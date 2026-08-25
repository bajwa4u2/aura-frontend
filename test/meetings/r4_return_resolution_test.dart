import 'package:flutter_test/flutter_test.dart';
import 'package:aura/core/navigation/return_path_authority.dart';

/// R-4 — MEETINGS IS ADMITTED TO THE RETURN CONTRACT.
///
/// The audit found four real Meetings destinations offering no way back at
/// all, and ten more answering the question themselves. Admitting the domain
/// is only half of it: the authority has to produce a SENSIBLE answer for
/// every one of these paths, or the affordance would appear and go nowhere.
void main() {
  // The registered Meetings destinations, as the route registry sees them.
  const registered = {
    '/home', '/create', '/discover', '/messages', '/',
    '/meetings/m1', '/meetings/join', '/meetings/keep',
    '/institution/i1', '/institution/i1/meetings', '/institution/i1/overview',
    // the real router registers this; a section root escapes into it
    '/institution/i1/explore',
    '/meet/acme',
  };
  bool exists(String p) => registered.contains(p);

  ReturnAction resolve(String path, {bool canPop = false, bool authed = true}) =>
      ReturnPathAuthority.resolve(
        path: path,
        canPop: canPop,
        isAuthed: authed,
        exists: exists,
      );

  group('the four destinations that offered nothing now offer something', () {
    test('institution availability returns into its institution', () {
      final a = resolve('/institution/i1/availability');
      expect(a.destination, isNotNull,
          reason: 'availability still leads nowhere');
      expect(a.destination, startsWith('/institution/i1'));
    });

    test('public booking, entered cold and signed out, still leads out', () {
      final a = resolve('/meet/acme/book', authed: false);
      expect(a.destination, isNotNull);
      // Booking is a flow: leaving it is cancelling, not ascending.
      expect(a.semantic, ReturnSemantic.flowCancel);
    });

    test('a booking cancellation link leads somewhere legitimate', () {
      final a = resolve('/meet/cancel/tok', authed: false);
      expect(a.destination, isNotNull,
          reason: 'a cancellation link is a cold entry by definition — it '
              'arrives from an email and has no history behind it');
    });

    test('the realtime lobby is framed, and is not a call', () {
      expect(ReturnPathAuthority.isLiveCallSurface('/realtime'), isFalse);
      expect(ReturnPathAuthority.isProtectedDomain('/realtime'), isFalse);
      expect(resolve('/realtime').destination, isNotNull);
    });
  });

  group('the workspace resolves the way the rest of the product does', () {
    test('a meeting record entered cold does NOT fall back to /home', () {
      // The defect this replaces: the screen`s own control went to `/home`
      // whenever it could not pop, so an emailed meeting link led to the top
      // of the product rather than anywhere related to the meeting.
      final a = resolve('/institution/i1/meetings/m1');
      expect(a.destination, '/institution/i1/meetings',
          reason: 'a meeting should return to the meetings it belongs to');
    });

    test('a meeting record with real history pops it', () {
      final a = resolve('/meetings/m1', canPop: true);
      expect(a.semantic, ReturnSemantic.stackReturn);
    });

    test('creating a meeting is a flow, so it CANCELS', () {
      final a = resolve('/institution/i1/meetings/new', canPop: true);
      expect(a.semantic, ReturnSemantic.flowCancel);
    });

    test('the meetings list is a section root inside its institution', () {
      final a = resolve('/institution/i1/meetings');
      expect(a.destination, isNotNull);
      expect(a.destination, startsWith('/institution/i1'));
    });

    test('a live call is still exempt, and says so', () {
      expect(ReturnPathAuthority.isLiveCallSurface('/meetings/m1/live'), isTrue);
      expect(
          ReturnPathAuthority.isLiveCallSurface(
              '/institution/i1/meetings/m1/live'),
          isTrue);
    });
  });
}
