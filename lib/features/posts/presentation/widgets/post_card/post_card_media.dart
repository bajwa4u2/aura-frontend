import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../../core/ui/aura_platform_components.dart';
import '../../../../../core/ui/aura_text.dart';
import 'post_card_models.dart';
import 'post_card_utils.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MEDIA VIEWER DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class PostCardMediaViewerDialog extends StatefulWidget {
  const PostCardMediaViewerDialog({
    super.key,
    required this.items,
    required this.initialIndex,
  });

  final List<PostCardResolvedMediaItem> items;
  final int initialIndex;

  @override
  State<PostCardMediaViewerDialog> createState() =>
      _PostCardMediaViewerDialogState();
}

class _PostCardMediaViewerDialogState
    extends State<PostCardMediaViewerDialog> {
  late final PageController _pageController;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.items.length - 1);
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _jump(int next) {
    if (next < 0 || next >= widget.items.length) return;
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.items[_index];

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 820),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white12),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: widget.items.length,
                    onPageChanged: (value) {
                      setState(() {
                        _index = value;
                      });
                    },
                    itemBuilder: (context, index) {
                      final media = widget.items[index];
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: media.isVideo
                              ? PostCardVideoViewer(url: media.playableUrl)
                              : PostCardImageViewer(url: media.previewUrl),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.white12)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ((item.caption ?? '').trim().isNotEmpty)
                        Text(
                          item.caption!.trim(),
                          style: AuraText.body.copyWith(color: Colors.white),
                        ),
                      if ((item.caption ?? '').trim().isNotEmpty)
                        const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            '${_index + 1} / ${widget.items.length}',
                            style: AuraText.small.copyWith(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          if (item.playableUrl.isNotEmpty)
                            AuraGhostButton(
                              label: item.isVideo ? 'Open video' : 'Open image',
                              icon: Icons.open_in_new,
                              onPressed: () => openExternalUrl(
                                context,
                                item.playableUrl,
                                fallbackCopyMessage: 'Media link copied',
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
            if (_index > 0)
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: PostCardViewerArrowButton(
                    icon: Icons.chevron_left,
                    onTap: () => _jump(_index - 1),
                  ),
                ),
              ),
            if (_index < widget.items.length - 1)
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: PostCardViewerArrowButton(
                    icon: Icons.chevron_right,
                    onTap: () => _jump(_index + 1),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VIEWER ARROW BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class PostCardViewerArrowButton extends StatelessWidget {
  const PostCardViewerArrowButton({
    super.key,
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// IMAGE VIEWER
// ─────────────────────────────────────────────────────────────────────────────

class PostCardImageViewer extends StatelessWidget {
  const PostCardImageViewer({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) {
      return Text(
        'Image unavailable',
        style: AuraText.body.copyWith(color: Colors.white),
      );
    }

    return InteractiveViewer(
      minScale: 0.8,
      maxScale: 4.0,
      child: Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Text(
          'Image unavailable',
          style: AuraText.body.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VIDEO VIEWER
// ─────────────────────────────────────────────────────────────────────────────

class PostCardVideoViewer extends StatefulWidget {
  const PostCardVideoViewer({super.key, required this.url});

  final String url;

  @override
  State<PostCardVideoViewer> createState() => _PostCardVideoViewerState();
}

class _PostCardVideoViewerState extends State<PostCardVideoViewer> {
  VideoPlayerController? _controller;
  Future<void>? _initializeFuture;
  String? _error;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  void _setup() {
    final url = widget.url.trim();
    if (url.isEmpty) {
      _error = 'Video URL is missing';
      return;
    }

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      _controller = controller;
      _initializeFuture = controller
          .initialize()
          .then((_) async {
            await controller.setLooping(true);
            if (mounted) {
              setState(() {});
            }
          })
          .catchError((_) {
            _error = 'Could not load video';
            if (mounted) {
              setState(() {});
            }
          });
    } catch (_) {
      _error = 'Could not open video';
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    _controller = null;
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if ((_error ?? '').trim().isNotEmpty) {
      return PostCardVideoFallback(message: _error!, url: widget.url);
    }

    final controller = _controller;
    final initializeFuture = _initializeFuture;

    if (controller == null || initializeFuture == null) {
      return PostCardVideoFallback(message: 'Video unavailable', url: widget.url);
    }

    return FutureBuilder<void>(
      future: initializeFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return PostCardVideoFallback(
            message: 'Could not load video',
            url: widget.url,
          );
        }

        if (snapshot.connectionState != ConnectionState.done ||
            !controller.value.isInitialized) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio > 0
                    ? controller.value.aspectRatio
                    : (16 / 9),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: VideoPlayer(controller),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                AuraPrimaryButton(
                  label: controller.value.isPlaying ? 'Pause' : 'Play',
                  icon: controller.value.isPlaying
                      ? Icons.pause
                      : Icons.play_arrow,
                  onPressed: () async {
                    if (controller.value.isPlaying) {
                      await controller.pause();
                    } else {
                      await controller.play();
                    }
                    if (mounted) {
                      setState(() {});
                    }
                  },
                ),
                AuraSecondaryButton(
                  label: 'Restart',
                  icon: Icons.replay,
                  onPressed: () async {
                    await controller.seekTo(Duration.zero);
                    if (!controller.value.isPlaying) {
                      await controller.play();
                    }
                    if (mounted) {
                      setState(() {});
                    }
                  },
                ),
                AuraSecondaryButton(
                  label: 'Open externally',
                  icon: Icons.open_in_new,
                  onPressed: () => openExternalUrl(
                    context,
                    widget.url,
                    fallbackCopyMessage: 'Video link copied',
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VIDEO FALLBACK
// ─────────────────────────────────────────────────────────────────────────────

class PostCardVideoFallback extends StatelessWidget {
  const PostCardVideoFallback({
    super.key,
    required this.message,
    required this.url,
  });

  final String message;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 220, minWidth: 320),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam_outlined, size: 40, color: Colors.white70),
          const SizedBox(height: 12),
          Text(
            message,
            style: AuraText.body.copyWith(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          AuraSecondaryButton(
            label: 'Open video',
            icon: Icons.open_in_new,
            onPressed: () => openExternalUrl(
              context,
              url,
              fallbackCopyMessage: 'Video link copied',
            ),
          ),
        ],
      ),
    );
  }
}
