import 'package:flutter/material.dart';

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
    return Center(
      child: Text('PDF viewer not supported on this platform: $title'),
    );
  }
}