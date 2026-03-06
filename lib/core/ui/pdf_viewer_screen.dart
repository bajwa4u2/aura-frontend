// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';

class PdfViewer extends StatefulWidget {
  final String assetPath;
  final String title;

  const PdfViewer({
    super.key,
    required this.assetPath,
    required this.title,
  });

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

    // IMPORTANT:
    // Flutter web serves bundled assets at /assets/<assetPath>
    // Our assetPath is "assets/investor/FILE.pdf"
    // So the correct URL is "/assets/assets/investor/FILE.pdf"
    final src = '/assets/${widget.assetPath}';

    ui.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = html.IFrameElement()
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