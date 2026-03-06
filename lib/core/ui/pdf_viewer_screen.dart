import 'package:flutter/material.dart';

import 'pdf_viewer/pdf_viewer.dart';

class PdfViewerScreen extends StatelessWidget {
  final String title;
  final String assetPath;

  const PdfViewerScreen({
    super.key,
    required this.title,
    required this.assetPath,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: PdfViewer(
        assetPath: assetPath,
        title: title,
      ),
    );
  }
}