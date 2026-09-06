import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'aura_window.dart';

/// WHETHER THIS PERSON WANTS NAVIGATION EXPANDED.
///
/// Compact is the desktop default: navigation orients somebody, it does not
/// own their window. The previous shell spent 288 px on it at every width
/// above 900 — a fifth of a laptop window, permanently, for four labels.
///
/// But "compact by default" is not "compact always". Somebody who wants the
/// labels should get them, and should not have to ask twice. So the choice is
/// remembered, per device, in the same local store the app already uses for
/// the remembered sign-in identifier.
///
/// Deliberately NOT server state: this is a property of a window on a
/// machine, not of an account. The same person on a phone and a desktop wants
/// different answers, and a synced preference would fight the window.
class NavPostureController extends StateNotifier<bool> {
  NavPostureController() : super(false) {
    _restore();
  }

  static const _key = 'aura.nav.expanded';

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool(_key) ?? false;
    } catch (_) {
      // A device that cannot read its preferences is not a device with an
      // opinion. Compact is the default and a safe one.
    }
  }

  Future<void> toggle() async {
    state = !state;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, state);
    } catch (_) {
      // The window still reflects the choice for this session.
    }
  }
}

final navExpandedProvider =
    StateNotifierProvider<NavPostureController, bool>((ref) {
  return NavPostureController();
});

/// The posture to actually use, given the window and the person's choice.
///
/// A narrow window overrules the preference — there is no room for expanded
/// navigation on a handset and honouring the preference there would just take
/// the content away.
AuraNavPosture resolveNavPosture({
  required double windowWidth,
  required bool expandedPreferred,
  required bool hasPersistentNav,
}) {
  if (!hasPersistentNav) return AuraNavPosture.hidden;
  if (windowWidth < kNavExpandedFloor) return AuraNavPosture.compact;
  return expandedPreferred ? AuraNavPosture.expanded : AuraNavPosture.compact;
}

/// Below this width, expanded navigation costs the work more than it gives
/// the person — 264 px out of a 1000 px window is a quarter of it.
const double kNavExpandedFloor = 1180;

/// Reads the resolved posture for the current window.
AuraNavPosture watchNavPosture(
  BuildContext context,
  WidgetRef ref, {
  required bool hasPersistentNav,
}) {
  return resolveNavPosture(
    windowWidth: MediaQuery.sizeOf(context).width,
    expandedPreferred: ref.watch(navExpandedProvider),
    hasPersistentNav: hasPersistentNav,
  );
}
