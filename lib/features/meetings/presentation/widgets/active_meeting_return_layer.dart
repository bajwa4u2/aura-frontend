import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The active meeting a user has open somewhere in the app: the live-room
/// route to return to and a display title. Set by the live room on mount,
/// cleared on leave/end.
///
/// The return pill this file used to draw was mounted by the member shell
/// alone, so an institution host stepping out of their own meeting had no way
/// back. The way back is now the live ribbon `FloatingCallWidget` draws in
/// every shell (founder-approved design, 23 Oct 2026); this entry tells it
/// the exact room to return to.
final activeMeetingReturnProvider =
    StateProvider<({String path, String title})?>((ref) => null);
