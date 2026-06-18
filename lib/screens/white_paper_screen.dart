import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/ui/aura_platform_components.dart';
import '../core/ui/aura_radius.dart';
import '../core/ui/aura_space.dart';
import '../core/ui/aura_surface.dart';
import '../core/ui/aura_text.dart';
import '../core/ui/publication/publication.dart';

/// Aura's flagship public publication surface.
///
/// Reads as an institutional white paper, not a markdown viewer:
///   * Hero band with publisher line, "WHITE PAPER" eyebrow, large
///     title, subtitle, version + reading-time meta, and the primary
///     PDF + navigation actions.
///   * Sticky thin progress bar pinned to the top of the viewport,
///     driven by the publication layout's scroll controller.
///   * Markdown body rendered through [AuraPublicationMarkdown] with
///     editorial typography and gold-accent blockquotes.
///   * Loading and error states match the publication aesthetic
///     (skeleton + framed retry, not a bare spinner).
///   * Colophon at the end so the document closes cleanly.
class WhitePaperScreen extends StatefulWidget {
  const WhitePaperScreen({super.key});

  @override
  State<WhitePaperScreen> createState() => _WhitePaperScreenState();
}

class _WhitePaperScreenState extends State<WhitePaperScreen> {
  static const String _rawBase = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.auraplatform.org',
  );

  late final String _base =
      _rawBase.endsWith('/v1') ? _rawBase : '$_rawBase/v1';
  late final String _mdUrl = '$_base/mission/white-paper.md';
  late final String _pdfUrl = '$_base/mission/white-paper.pdf';

  String? _md;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final dio = Dio();
      final res = await dio.get<List<int>>(
        _mdUrl,
        options: Options(
          responseType: ResponseType.bytes,
          headers: const {'Accept': 'text/markdown'},
        ),
      );
      final text = utf8.decode(res.data ?? <int>[]);
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
    final uri = Uri.parse(_pdfUrl);
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

  /// Approximate reading time based on a ~220 wpm pace. Returns null
  /// until the markdown has been fetched.
  int? _readingTimeMinutes() {
    final md = _md;
    if (md == null || md.trim().isEmpty) return null;
    final words = md.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final minutes = (words / 220).ceil();
    return minutes.clamp(1, 999);
  }

  @override
  Widget build(BuildContext context) {
    final readingMinutes = _readingTimeMinutes();
    final metaItems = <AuraPublicationMetaItem>[
      const AuraPublicationMetaItem(
        icon: Icons.description_outlined,
        label: 'Version 1.0',
      ),
      const AuraPublicationMetaItem(
        icon: Icons.event_outlined,
        label: 'Updated May 2026',
      ),
      if (readingMinutes != null)
        AuraPublicationMetaItem(
          icon: Icons.schedule_outlined,
          label: '$readingMinutes min read',
        ),
    ];

    final hero = AuraPublicationHero(
      eyebrow: 'White Paper',
      title: 'Institution operating infrastructure.',
      subtitle:
          'How Aura keeps identity, authority, and outcomes connected '
          'on one accountable record — the system an institution runs '
          'its public and member-facing life on.',
      metaItems: metaItems,
      actions: [
        AuraPrimaryButton(
          label: 'Download PDF',
          icon: Icons.download_outlined,
          onPressed: _openPdf,
        ),
        AuraGhostButton(
          label: 'Back to Mission',
          icon: Icons.arrow_back_rounded,
          onPressed: () => context.go('/mission'),
        ),
      ],
    );

    return AuraPublicationLayout(
      title: 'White Paper',
      hero: hero,
      showProgress: true,
      children: [
        if (_loading) const _PublicationSkeleton(),
        if (!_loading && _error) _ErrorBlock(onRetry: _load, onPdf: _openPdf),
        if (!_loading && !_error && _md != null) ...[
          AuraPublicationMarkdown(data: _md!),
          const AuraPublicationDivider(),
          const AuraPublicationColophon(
            publisher: 'Aura Platform LLC',
            version: 'White Paper · Version 1.0',
            updatedLabel: 'May 2026',
          ),
        ],
      ],
    );
  }
}

/// Calm reading-shape skeleton — three heading + paragraph blocks.
/// Prefer this to a bare CircularProgressIndicator so the page never
/// flashes empty while the markdown is in flight.
class _PublicationSkeleton extends StatelessWidget {
  const _PublicationSkeleton();

  Widget _bar({double width = double.infinity, double height = 16}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.sm),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AuraSpace.md),
        _bar(width: 220, height: 22),
        const SizedBox(height: AuraSpace.md),
        _bar(),
        const SizedBox(height: AuraSpace.s10),
        _bar(),
        const SizedBox(height: AuraSpace.s10),
        _bar(width: 480),
        const SizedBox(height: AuraSpace.xl),
        _bar(width: 280, height: 22),
        const SizedBox(height: AuraSpace.md),
        _bar(),
        const SizedBox(height: AuraSpace.s10),
        _bar(),
        const SizedBox(height: AuraSpace.s10),
        _bar(width: 520),
        const SizedBox(height: AuraSpace.s10),
        _bar(width: 360),
      ],
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.onRetry, required this.onPdf});

  final VoidCallback onRetry;
  final VoidCallback onPdf;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.lg),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        border: Border.all(color: AuraSurface.divider),
        borderRadius: BorderRadius.circular(AuraRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The white paper could not be loaded.',
            style: AuraText.subtitle.copyWith(fontSize: 18),
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(
            'You can retry the network fetch or open the PDF directly. '
            'Both routes lead to the same published version.',
            style: AuraText.body.copyWith(height: 1.6),
          ),
          const SizedBox(height: AuraSpace.md),
          Wrap(
            spacing: AuraSpace.s10,
            runSpacing: AuraSpace.s10,
            children: [
              AuraSecondaryButton(
                label: 'Try again',
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
              ),
              AuraGhostButton(
                label: 'Download PDF',
                icon: Icons.download_outlined,
                onPressed: onPdf,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
