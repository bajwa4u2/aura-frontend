import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../providers.dart';

class AnnouncementDetailScreen extends ConsumerWidget {
  const AnnouncementDetailScreen({super.key, required this.slug});
  final String slug;

  // Keep stable and simple. If you later want a dynamic base, we can wire it to AppConfig.
  String _publicAnnouncementUrl(String slug) {
    final s = slug.trim();
    return 'https://auraplatform.org/announcements/$s';
  }

  String _linkedInShareUrl(String targetUrl) {
    final u = Uri.encodeComponent(targetUrl);
    return 'https://www.linkedin.com/sharing/share-offsite/?url=$u';
  }

  Future<void> _copy(BuildContext context, String label, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied')),
    );
  }

  void _openShareSheet(BuildContext context, {required String publicUrl}) {
    final linkedInShare = _linkedInShareUrl(publicUrl);

    // Your backend OAuth start (user said integration already exists)
    // This is the "connect" start endpoint (not callback).
    const linkedInConnectUrl = 'https://api.auraplatform.org/v1/auth/linkedin';

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AuraSpace.s16, AuraSpace.s10, AuraSpace.s16, AuraSpace.s16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Share', style: AuraText.title),
                const SizedBox(height: AuraSpace.s10),

                AuraCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Announcement link', style: AuraText.small.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: AuraSpace.s8),
                      SelectableText(publicUrl, style: AuraText.body),
                      const SizedBox(height: AuraSpace.s10),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => _copy(context, 'Link', publicUrl),
                            child: const Text('Copy link'),
                          ),
                          const Spacer(),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AuraSpace.s10),

                AuraCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('LinkedIn share URL', style: AuraText.small.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: AuraSpace.s8),
                      SelectableText(linkedInShare, style: AuraText.body),
                      const SizedBox(height: AuraSpace.s10),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => _copy(context, 'LinkedIn share URL', linkedInShare),
                            child: const Text('Copy LinkedIn share URL'),
                          ),
                          const Spacer(),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AuraSpace.s10),

                AuraCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('LinkedIn connect URL', style: AuraText.small.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: AuraSpace.s8),
                      SelectableText(linkedInConnectUrl, style: AuraText.body),
                      const SizedBox(height: AuraSpace.s10),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => _copy(context, 'LinkedIn connect URL', linkedInConnectUrl),
                            child: const Text('Copy LinkedIn connect URL'),
                          ),
                          const Spacer(),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AuraSpace.s6),
                Text(
                  'Next: we’ll replace this with “Post to Aura LinkedIn Page” (direct posting) using your backend flow.',
                  style: AuraText.small,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _prettyPublished(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  String _tryDecodeBody(String body) {
    final s = body.trim();
    if (s.isEmpty) return s;

    // If backend ever returns JSON string accidentally, try to unwrap gracefully.
    if (s.startsWith('{') && s.endsWith('}')) {
      try {
        final decoded = jsonDecode(s);
        if (decoded is Map) {
          final maybe = decoded['body'] ?? decoded['content'] ?? decoded['text'];
          if (maybe is String) return maybe;
        }
      } catch (_) {}
    }
    return body;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(announcementBySlugProvider(slug));

    return AuraScaffold(
      title: 'Announcement',
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
          final publicUrl = _publicAnnouncementUrl(a.slug);
          final body = _tryDecodeBody(a.body);

          return ListView(
            padding: const EdgeInsets.fromLTRB(AuraSpace.s16, AuraSpace.s12, AuraSpace.s16, AuraSpace.s24),
            children: [
              AuraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: Text(title, style: AuraText.h1)),
                        IconButton(
                          tooltip: 'Share',
                          onPressed: () => _openShareSheet(context, publicUrl: publicUrl),
                          icon: const Icon(Icons.ios_share),
                        ),
                      ],
                    ),
                    const SizedBox(height: AuraSpace.s8),
                    if (a.publishedAt != null)
                      Text('Published: ${_prettyPublished(a.publishedAt!)}', style: AuraText.small),
                    const SizedBox(height: AuraSpace.s14),
                    Text(body, style: AuraText.body),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}