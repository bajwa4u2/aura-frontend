import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../providers.dart';

class AnnouncementDetailScreen extends ConsumerWidget {
  const AnnouncementDetailScreen({super.key, required this.slug});
  final String slug;

  String _fmtDate(DateTime dt) {
    final d = dt.toLocal();
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  bool _isSvg(Map<String, dynamic> m) {
    final t = (m['type'] ?? '').toString().toUpperCase();
    if (t == 'SVG') return true;

    final url = (m['url'] ?? '').toString().toLowerCase();
    return url.endsWith('.svg');
  }

  bool _isImage(Map<String, dynamic> m) {
    final t = (m['type'] ?? '').toString().toUpperCase();
    return t == 'IMAGE' || t == 'SVG';
  }

  bool _isVideo(Map<String, dynamic> m) {
    final t = (m['type'] ?? '').toString().toUpperCase();
    return t == 'VIDEO';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(announcementBySlugProvider(slug));

    return AuraScaffold(
      
      showHomeAction: true,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: AuraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Failed to load', style: AuraText.title),
                  const SizedBox(height: AuraSpace.s10),
                  Text(e.toString(), style: AuraText.body),
                ],
              ),
            ),
          ),
        ),
        data: (a) {
          if (a == null) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: AuraCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Not found', style: AuraText.title),
                      const SizedBox(height: AuraSpace.s10),
                      Text('This announcement does not exist.', style: AuraText.body),
                    ],
                  ),
                ),
              ),
            );
          }

          final title = a.title.isEmpty ? a.slug : a.title;
          final body = a.bodyMarkdown.trim();
          final summary = a.summary.trim();

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.s16,
              AuraSpace.s12,
              AuraSpace.s16,
              AuraSpace.s24,
            ),
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: AuraCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AuraText.h1),
                      const SizedBox(height: AuraSpace.s10),
                      if (a.publishedAt != null)
                        Text('Published: ${_fmtDate(a.publishedAt!)}', style: AuraText.small),

                      if (summary.isNotEmpty) ...[
                        const SizedBox(height: AuraSpace.s14),
                        Text(
                          summary,
                          style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],

                      if (a.media.isNotEmpty) ...[
                        const SizedBox(height: AuraSpace.s16),
                        Text('Attachments', style: AuraText.body.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: AuraSpace.s10),
                        for (final m in a.media) ...[
                          _AnnouncementMediaBlock(
                            m: m,
                            isImage: _isImage,
                            isVideo: _isVideo,
                            isSvg: _isSvg,
                          ),
                          const SizedBox(height: AuraSpace.s10),
                        ],
                      ],

                      if (body.isNotEmpty) ...[
                        const SizedBox(height: AuraSpace.s14),
                        Text(body, style: AuraText.body),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AnnouncementMediaBlock extends StatelessWidget {
  const _AnnouncementMediaBlock({
    required this.m,
    required this.isImage,
    required this.isVideo,
    required this.isSvg,
  });

  final Map<String, dynamic> m;
  final bool Function(Map<String, dynamic>) isImage;
  final bool Function(Map<String, dynamic>) isVideo;
  final bool Function(Map<String, dynamic>) isSvg;

  @override
  Widget build(BuildContext context) {
    final url = (m['url'] ?? '').toString();
    final thumb = (m['thumbUrl'] ?? '').toString();
    final caption = (m['caption'] ?? '').toString().trim();

    if (url.isEmpty) return const SizedBox.shrink();

    Widget media;

    if (isImage(m)) {
      if (isSvg(m)) {
        media = SvgPicture.network(
          url,
          fit: BoxFit.contain,
          placeholderBuilder: (_) => const SizedBox(
            height: 140,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        );
      } else {
        media = Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox(
            height: 140,
            child: Center(child: Icon(Icons.broken_image)),
          ),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const SizedBox(
              height: 140,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          },
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: media,
            ),
          ),
          if (caption.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(caption, style: AuraText.small),
          ],
        ],
      );
    }

    if (isVideo(m)) {
      // Phase 1: show thumb (or fallback), don’t introduce a full video player yet.
      final show = thumb.isNotEmpty ? thumb : url;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.network(
                    show,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(
                      height: 140,
                      child: Center(child: Icon(Icons.video_file_outlined)),
                    ),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const SizedBox(
                        height: 140,
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      );
                    },
                  ),
                  const Icon(Icons.play_circle_outline, size: 44),
                ],
              ),
            ),
          ),
          if (caption.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(caption, style: AuraText.small),
          ],
        ],
      );
    }

    // Unknown media type
    return Row(
      children: [
        const Icon(Icons.attach_file, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(url, style: AuraText.small)),
      ],
    );
  }
}