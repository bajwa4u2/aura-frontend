import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/ui/aura_space.dart';
import '../core/ui/aura_text.dart';
import '../core/ui/document_scaffold.dart';

class WhitePaperScreen extends StatefulWidget {
  const WhitePaperScreen({super.key});

  @override
  State<WhitePaperScreen> createState() => _WhitePaperScreenState();
}

class _WhitePaperScreenState extends State<WhitePaperScreen> {
  String? _md;
  bool _loading = true;
  bool _error = false;

  // Use the same build-time API base used everywhere else.
  // In Railway you build with: --dart-define=API_BASE_URL=https://api.aura.bajwadynesty.us
  // Most of your app endpoints are /v1/*, so we append /v1 here safely if missing.
  static const String _rawBase =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'https://api.aura.bajwadynesty.us');

  late final String _base = _rawBase.endsWith('/v1') ? _rawBase : '$_rawBase/v1';

  late final String mdUrl = '$_base/mission/white-paper.md';
  late final String pdfUrl = '$_base/mission/white-paper.pdf';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final dio = Dio();
      final res = await dio.get<List<int>>(
        mdUrl,
        options: Options(
          responseType: ResponseType.bytes,
          headers: const {'Accept': 'text/markdown'},
        ),
      );

      final bytes = res.data ?? <int>[];
      final text = utf8.decode(bytes);

      if (!mounted) return;
      setState(() {
        _md = text;
        _loading = false;
        _error = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  Future<void> _openPdf() async {
    final uri = Uri.parse(pdfUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the PDF.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DocumentScaffold(
      title: 'White Paper',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Doc.title('White Paper'),
                    const SizedBox(height: AuraSpace.s10),
                    Doc.p('Unable to load the white paper right now.'),
                    const SizedBox(height: AuraSpace.s10),
                    OutlinedButton(
                      onPressed: _load,
                      child: Text('Try again', style: AuraText.body),
                    ),
                    const SizedBox(height: AuraSpace.s10),
                    OutlinedButton(
                      onPressed: _openPdf,
                      child: Text('Download PDF (v1.1)', style: AuraText.body),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Doc.title('Aura White Paper'),
                    const SizedBox(height: AuraSpace.s8),
                    Doc.meta('Version 1.1 — served from Aura backend'),
                    const SizedBox(height: AuraSpace.s12),
                    OutlinedButton(
                      onPressed: _openPdf,
                      child: Text('Download PDF (v1.1)', style: AuraText.body),
                    ),
                    const SizedBox(height: AuraSpace.s16),
                    MarkdownBody(
                      data: _md ?? '',
                      selectable: true,
                      onTapLink: (text, href, title) async {
                        if (href == null) return;
                        final uri = Uri.tryParse(href);
                        if (uri == null) return;
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      },
                      styleSheet: MarkdownStyleSheet(
                        p: AuraText.body.copyWith(height: 1.7),
                        h1: AuraText.title,
                        h2: AuraText.emphasis.copyWith(fontSize: 18),
                        h3: AuraText.emphasis.copyWith(fontSize: 16),
                        blockquote: AuraText.body.copyWith(height: 1.6),
                        listBullet: AuraText.body.copyWith(height: 1.6),
                      ),
                    ),
                  ],
                ),
    );
  }
}