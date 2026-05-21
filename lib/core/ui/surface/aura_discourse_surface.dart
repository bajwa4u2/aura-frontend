import 'package:flutter/material.dart';

import '../aura_responsive.dart';
import '../aura_space.dart';
import 'surface_composition.dart';

/// Desktop two-panel composition for discourse DETAIL surfaces — post
/// detail, public thread, announcement detail, institution post detail.
///
/// Places the calm reading-width record column beside a contextual
/// [AuraContextRail] when the viewport has room, and collapses to the
/// reading column alone at laptop / mobile widths.
///
/// Contract:
///   * The reading column stays at [kReadWidth] in BOTH modes — the
///     rail consumes the desktop space that would otherwise be empty
///     page gutter, never the document measure. The reading-width
///     document model is preserved exactly.
///   * The rail is desktop-first: it appears only when the available
///     width fits the reading column AND a full rail AND a gutter.
///     Below that it is dropped — no mobile clutter.
///   * When [railModules] is empty the rail is never rendered, so a
///     surface with no contextual data shows no empty sidebar. Each
///     module is itself provider-backed and self-collapses, so a rail
///     whose modules all have no data simply renders short — the
///     caller decides whether to pass modules at all.
class AuraDiscourseSurface extends StatelessWidget {
  const AuraDiscourseSurface({
    super.key,
    required this.reading,
    this.railModules = const [],
  });

  /// The reading-column content — typically the surface's own scroll
  /// view. Sized to [kReadWidth] by this widget; callers must NOT
  /// pre-center or pre-constrain it to a content width.
  final Widget reading;

  /// Contextual rail modules, in display-priority order. Pass an empty
  /// list to opt out of the rail entirely.
  final List<Widget> railModules;

  @override
  Widget build(BuildContext context) {
    final hasRail = railModules.isNotEmpty;
    final railWidth = AuraContextRail.widthFor(
      MediaQuery.of(context).size.width,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final fitsRail =
            constraints.maxWidth >= kReadWidth + railWidth + AuraSpace.s32;

        if (!hasRail || !fitsRail) {
          // Laptop / mobile, or no contextual data: the calm reading
          // column alone, centered with intentional page margins.
          return Center(
            child: SizedBox(width: kReadWidth, child: reading),
          );
        }

        // Desktop: reading column + contextual rail, centered as a
        // group so the composition has balanced page margins.
        return Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: kReadWidth, child: reading),
              AuraContextRail(modules: railModules, width: railWidth),
            ],
          ),
        );
      },
    );
  }
}
