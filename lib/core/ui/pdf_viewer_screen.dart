import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

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
      body: SfPdfViewer.asset(
        assetPath,
        onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
          // Show the real reason instead of failing silently.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'PDF failed to load: ${details.error}\n${details.description}',
                ),
                duration: const Duration(seconds: 6),
              ),
            );
          });

          // Also render a visible error page.
        },
      ),
    );
  }
}