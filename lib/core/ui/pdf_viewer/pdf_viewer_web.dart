import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class PdfViewer extends StatefulWidget {
  final String assetPath;
  final String title;

  const PdfViewer({super.key, required this.assetPath, required this.title});

  @override
  State<PdfViewer> createState() => _PdfViewerWebState();
}

class _PdfViewerWebState extends State<PdfViewer> {
  late final String _viewType;
  bool _registered = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'pdf-iframe-${DateTime.now().microsecondsSinceEpoch}';
    _register();
  }

  void _register() {
    if (_registered) return;

    // Flutter web ships pubspec-declared assets under `<base>/assets/<path>`.
    // Earlier we used just the filename + a leading slash (e.g.
    // `/Aura_Platform_Investor_Deck_2026.pdf`) which the server's SPA
    // fallback resolved to `index.html` — the iframe then booted a
    // second Flutter instance whose router promptly threw
    // `GoException: no routes for location: /<filename>`.
    //
    // The correct URL for an asset declared as `assets/investor/foo.pdf`
    // is `/assets/assets/investor/foo.pdf` (the build pipeline preserves
    // the `assets/` prefix from pubspec). We normalize any incidental
    // leading slash before joining.
    final normalized = widget.assetPath.startsWith('/')
        ? widget.assetPath.substring(1)
        : widget.assetPath;
    final src = '/assets/$normalized';

    ui.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = web.HTMLIFrameElement()
        ..src = src
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allowFullscreen = true;

      return iframe;
    });

    _registered = true;
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
