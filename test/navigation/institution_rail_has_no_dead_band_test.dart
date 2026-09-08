import 'package:flutter_test/flutter_test.dart';
import 'package:aura/core/ui/aura_responsive.dart';
import 'package:aura/core/ui/aura_window.dart';
import 'package:aura/core/ui/surface/surface_composition.dart';

/// A SURFACE MAY NEVER BE LEFT WITH NO NAVIGATION.
///
/// The institution workspace carries its navigation in a left rail and nothing
/// else — no top tabs, no bottom bar. Its rail is declared `tabletUp`, whose
/// documentation says "tablet and above (>= kTabletBreak)" — 900.
///
/// It was implemented as `canHoldSelection`, which is desktop-or-wider: 1040.
/// The shell meanwhile decided whether to draw the REPLACEMENT mobile bar from
/// `isDesktopClass`, which is merely "not a handset": 600. So from 600 to 1039
/// the shell suppressed the mobile bar because it believed the rail was
/// showing, and the surface drew no rail because it was below its own
/// threshold. Two components, each correct on its own number, together
/// produced a window width band with no navigation at all.
///
/// This was not a contrived size. A 150% display scale on an ordinary laptop
/// lands around 950 CSS px, squarely inside the band, and that is how it was
/// found — a person opened an institution and the navigation was gone.
void main() {
  AuraWindowInfo windowOf(double width) => AuraWindowInfo(
        width: width,
        height: 900,
        navPosture: AuraNavPosture.forWidth(width),
      );

  bool railShows(double width) => AuraSurfaceScaffold.railAllowed(
        AuraRailVisibility.tabletUp,
        windowOf(width),
      );

  group('the institution rail appears where it says it does', () {
    test('at the tablet break itself', () {
      expect(railShows(kTabletBreak), isTrue);
    });

    test('across the band that used to have nothing', () {
      // Every one of these was previously false while the mobile bar was also
      // suppressed. 952 is the observed real-world case.
      for (final width in <double>[900, 920, 952, 1000, 1039]) {
        expect(railShows(width), isTrue,
            reason: 'a $width px window must carry institution navigation');
      }
    });

    test('and still at desktop and wide widths', () {
      expect(railShows(1040), isTrue);
      expect(railShows(1480), isTrue);
      expect(railShows(1920), isTrue);
    });

    test('but not on a handset, which has the drawer instead', () {
      expect(railShows(599), isFalse);
      expect(railShows(400), isFalse);
    });
  });

  group('the threshold is one number, not two', () {
    test('the rail and its replacement hand over at exactly the same width', () {
      // The shell shows the mobile bar when it is NOT showing the rail. If the
      // two disagree by even one pixel, that pixel is a window width with no
      // navigation — which is the entire defect this file exists to prevent.
      const shellShowsRailFrom = kTabletBreak;
      for (final width in <double>[898, 899, 900, 901]) {
        final surfaceDraws = railShows(width);
        final shellDraws = width >= shellShowsRailFrom;
        expect(surfaceDraws, shellDraws,
            reason: 'at $width the shell and the surface disagree about who '
                'is providing navigation');
      }
    });
  });
}
