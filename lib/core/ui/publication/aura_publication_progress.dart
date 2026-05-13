import 'package:flutter/material.dart';

import '../aura_surface.dart';

/// Thin reading-progress indicator pinned to the top of a publication
/// surface. Listens to a [ScrollController] and renders a gold
/// progress bar that fills as the reader moves through the document.
///
/// Deliberately understated:
///   * 3 px tall — visible but never demanding attention.
///   * Idle (no progress yet) renders nothing — no empty bar at the
///     top of a fresh visit.
///   * Animated transitions disabled in favor of immediate response
///     so the reader's scroll feels mechanically connected to the bar.
class AuraPublicationProgress extends StatefulWidget {
  const AuraPublicationProgress({super.key, required this.controller});

  final ScrollController controller;

  @override
  State<AuraPublicationProgress> createState() =>
      _AuraPublicationProgressState();
}

class _AuraPublicationProgressState extends State<AuraPublicationProgress> {
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant AuraPublicationProgress old) {
    super.didUpdateWidget(old);
    if (!identical(old.controller, widget.controller)) {
      old.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!widget.controller.hasClients) return;
    final position = widget.controller.position;
    final max = position.maxScrollExtent;
    if (max <= 0) {
      if (_progress != 0) setState(() => _progress = 0);
      return;
    }
    final ratio = (position.pixels / max).clamp(0.0, 1.0);
    if ((ratio - _progress).abs() > 0.005) {
      setState(() => _progress = ratio);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_progress <= 0.001) {
      return const SizedBox(height: 3);
    }
    return SizedBox(
      height: 3,
      child: Stack(
        children: [
          Container(color: AuraSurface.divider),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _progress,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFC9A55C), // Aura gold — same accent the OG images use
              ),
            ),
          ),
        ],
      ),
    );
  }
}
