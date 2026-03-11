import 'package:flutter/material.dart';

import 'pdf_viewer_stub.dart'
    if (dart.library.io) 'pdf_viewer_io.dart'
    if (dart.library.html) 'pdf_viewer_web.dart' as impl;

class PdfViewer extends StatelessWidget {
  final String assetPath;
  final String title;

  const PdfViewer({
    super.key,
    required this.assetPath,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return impl.PdfViewer(
      assetPath: assetPath,
      title: title,
    );
  }
}