import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../ui/aura_text.dart';
import 'aura_video_surface.dart' show storedVideoCanDecodeInline;
import 'immersive_presenter.dart';
import 'media_initialization.dart';
import 'media_interaction_profile.dart';
import 'media_origin_label.dart';
import 'media_save_button.dart';
import 'media_url_resolver.dart';

/// Canonical evidence-grade media viewer.
///
/// One fullscreen viewer for every media surface — post / Works / public
/// feed / institution post / announcement / reply media. It is reached
/// through [showAuraMediaViewer] and exposes:
///
///   * zoom in / out / reset (fit) / actual size (100%)
///   * smooth pinch + drag pan, mouse/trackpad scale, double-tap zoom
///   * "Open original" — the source file in the browser / OS
///   * "Download original" — the untouched source bytes, never a thumb
///
/// Visibility-gated media is resolved to a fresh signed URL on demand
/// through [MediaUrlResolver]; an expired or unavailable URL surfaces an
/// honest error rather than a silent failure.

/// One media item handed to [AuraMediaViewer].
class AuraViewerItem {
  const AuraViewerItem({
    required this.originalUrl,
    this.mediaId,
    this.isPublic = true,
    this.isVideo = false,
    this.caption,
    this.intrinsicWidth,
    this.intrinsicHeight,
    this.downloadContext = 'media',
    this.originState,
    this.contentCredentials = false,
  });

  /// The source/original file URL. For public media this is rendered and
  /// downloaded directly. For gated media this may be a stale legacy URL
  /// — [mediaId] drives signed-URL resolution instead.
  final String originalUrl;

  /// Canonical Media id. Required for gated (non-public) media so the
  /// viewer can resolve a fresh signed URL for display, open and save.
  final String? mediaId;

  /// PUBLIC media renders/downloads [originalUrl] directly. Non-public
  /// media is resolved through [MediaUrlResolver].
  final bool isPublic;

  final bool isVideo;
  final String? caption;

  /// Intrinsic pixel size when the backend supplied it. Used to seed the
  /// "actual size" computation before the image finishes decoding.
  final int? intrinsicWidth;
  final int? intrinsicHeight;

  /// Filename context token, e.g. `post-media`, `announcement-media`,
  /// `institution-announcement-media`. Drives the normalized download
  /// filename: `aura-<context>-<yyyy-MM-dd>.<ext>`.
  final String downloadContext;

  /// Resolved origin disclosure for THIS item. Null means nothing established,
  /// and the viewer then says nothing rather than offering an empty verdict.
  final String? originState;

  /// Whether this item carries Content Credentials, verified or not.
  final bool contentCredentials;
}

/// Open the fullscreen [AuraMediaViewer] over [items], starting on
/// [initialIndex]. Safe to call with an empty list (no-op).
Future<void> showAuraMediaViewer(
  BuildContext context, {
  required List<AuraViewerItem> items,
  int initialIndex = 0,
}) {
  if (items.isEmpty) return Future<void>.value();
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.92),
    barrierDismissible: true,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      clipBehavior: Clip.none,
      child: AuraMediaViewer(items: items, initialIndex: initialIndex),
    ),
  );
}

/// Open a media URL in the platform browser / OS, with honest feedback.
///
/// On web this opens a new tab; on desktop/mobile it hands off to the
/// system browser. A failure copies the link to the clipboard and tells
/// the user — it never fails silently.
Future<void> openMediaExternally(
  BuildContext context,
  String rawUrl,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final trimmed = rawUrl.trim();
  if (trimmed.isEmpty) {
    messenger?.showSnackBar(
      const SnackBar(content: Text('The original media is not available.')),
    );
    return;
  }

  var uri = Uri.tryParse(trimmed);
  if (uri != null && !uri.hasScheme) uri = Uri.tryParse('https://$trimmed');
  if (uri == null || !uri.hasScheme) {
    await _copyLink(context, trimmed, 'That media link is not valid.');
    return;
  }

  try {
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!launched && context.mounted) {
      await _copyLink(context, trimmed, 'Could not open the original.');
    }
  } catch (_) {
    if (context.mounted) {
      await _copyLink(context, trimmed, 'Could not open the original.');
    }
  }
}

Future<void> _copyLink(
  BuildContext context,
  String url,
  String reason,
) async {
  await Clipboard.setData(ClipboardData(text: url));
  if (!context.mounted) return;
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(content: Text('$reason Link copied to the clipboard.')),
  );
}

/// Affine transform that scales by [scale] while pinning [focal] (a
/// point in viewport coordinates). Used both as an absolute transform
/// and, multiplied onto the current matrix, as an incremental zoom.
Matrix4 _scaleMatrix(double scale, Offset focal) {
  return Matrix4.identity()
    ..setEntry(0, 0, scale)
    ..setEntry(1, 1, scale)
    ..setEntry(0, 3, focal.dx * (1 - scale))
    ..setEntry(1, 3, focal.dy * (1 - scale));
}

/// Normalized, evidence-friendly download filename stem (no extension —
/// [MediaSaveService] appends one from the original's content-type).
String _viewerFilenameStem(AuraViewerItem item) {
  final now = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  final date = '${now.year}-${two(now.month)}-${two(now.day)}';
  var context = item.downloadContext.trim().toLowerCase();
  context = context.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  context = context.replaceAll(RegExp(r'^-+|-+$'), '');
  if (context.isEmpty) context = 'media';
  return 'aura-$context-$date';
}

class AuraMediaViewer extends ConsumerStatefulWidget {
  const AuraMediaViewer({
    super.key,
    required this.items,
    this.initialIndex = 0,
  });

  final List<AuraViewerItem> items;
  final int initialIndex;

  @override
  ConsumerState<AuraMediaViewer> createState() => _AuraMediaViewerState();
}

class _AuraMediaViewerState extends ConsumerState<AuraMediaViewer> {
  static const double _kMinScale = 1.0;
  static const double _kMaxScale = 8.0;

  late final PageController _pageController;
  late final List<TransformationController> _controllers;
  late int _index;

  /// Viewport size of a single page — needed for the actual-size math.
  Size? _pageSize;

  /// Per-item intrinsic (decoded) pixel size, filled in as images load.
  late final List<Size?> _intrinsicSizes;

  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.items.length - 1);
    _pageController = PageController(initialPage: _index);
    _controllers = List.generate(
      widget.items.length,
      (_) => TransformationController(),
    );
    _intrinsicSizes = List<Size?>.generate(widget.items.length, (i) {
      final it = widget.items[i];
      final w = it.intrinsicWidth;
      final h = it.intrinsicHeight;
      return (w != null && h != null && w > 0 && h > 0)
          ? Size(w.toDouble(), h.toDouble())
          : null;
    });
    _controllers[_index].addListener(_onTransformChanged);
  }

  @override
  void dispose() {
    _controllers[_index].removeListener(_onTransformChanged);
    for (final c in _controllers) {
      c.dispose();
    }
    _pageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    if (mounted) setState(() {});
  }

  AuraViewerItem get _current => widget.items[_index];
  TransformationController get _controller => _controllers[_index];

  double get _scale => _controller.value.getMaxScaleOnAxis();
  bool get _isZoomed => _scale > _kMinScale + 0.01;

  void _onPageChanged(int next) {
    if (next == _index) return;
    _controllers[_index].removeListener(_onTransformChanged);
    setState(() => _index = next);
    _controllers[_index].addListener(_onTransformChanged);
  }

  void _jumpPage(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= widget.items.length) return;
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  // ── Zoom controls ─────────────────────────────────────────────────

  /// Incrementally scale by [factor] around the viewport centre,
  /// clamped to range. Preserves the current pan offset.
  void _zoomBy(double factor) {
    final size = _pageSize;
    if (size == null) return;
    final current = _scale;
    final target = (current * factor).clamp(_kMinScale, _kMaxScale);
    final realFactor = current <= 0 ? 1.0 : target / current;
    if ((realFactor - 1).abs() < 0.001) return;
    final c = Offset(size.width / 2, size.height / 2);
    _controller.value = _scaleMatrix(realFactor, c) * _controller.value;
  }

  void _resetZoom() {
    _controller.value = Matrix4.identity();
  }

  /// Set the image to 1 image-pixel per logical-pixel, centred.
  void _actualSize() {
    final size = _pageSize;
    final intrinsic = _intrinsicSizes[_index];
    if (size == null || intrinsic == null) {
      // No intrinsic size known — fall back to a sensible close-up.
      _zoomBy(2.0);
      return;
    }
    // The image sits inside an 8px padding on every side.
    final viewport = Size(size.width - 16, size.height - 16);
    final fitScale = _fitScale(viewport, intrinsic);
    if (fitScale <= 0) return;
    // At identity the image is shown at `intrinsic * fitScale`; the
    // viewer scale that makes it 1:1 is therefore 1 / fitScale.
    final target = 1.0 / fitScale;
    final c = Offset(size.width / 2, size.height / 2);
    _controller.value = _scaleMatrix(target, c);
  }

  /// `BoxFit.contain` scale of [intrinsic] inside [viewport].
  double _fitScale(Size viewport, Size intrinsic) {
    if (intrinsic.width <= 0 || intrinsic.height <= 0) return 0;
    final sw = viewport.width / intrinsic.width;
    final sh = viewport.height / intrinsic.height;
    return sw < sh ? sw : sh;
  }

  /// Zoom readout as a true actual-pixel percentage when the intrinsic
  /// size is known (so "Actual size" reads 100%); otherwise the raw
  /// viewer scale relative to the fitted view.
  int _zoomPercent() {
    final intrinsic = _intrinsicSizes[_index];
    final size = _pageSize;
    if (intrinsic != null && size != null) {
      final fit = _fitScale(
        Size(size.width - 16, size.height - 16),
        intrinsic,
      );
      if (fit > 0) return (_scale * fit * 100).round();
    }
    return (_scale * 100).round();
  }

  // ── Open / download original ──────────────────────────────────────

  /// Resolve the directly-usable original URL for [item] — the public
  /// URL as-is, or a freshly signed URL for gated media. Returns null
  /// (and shows an honest message) when the media cannot be resolved.
  Future<String?> _resolveOriginalUrl(AuraViewerItem item) async {
    if (item.isPublic) {
      final url = item.originalUrl.trim();
      if (url.isNotEmpty) return url;
    }
    final id = (item.mediaId ?? '').trim();
    if (id.isEmpty) {
      _toast('The original media is not available.');
      return null;
    }
    try {
      final result = await ref.read(mediaUrlProvider(id).future);
      final url = result.url.trim();
      if (url.isEmpty) {
        _toast('This media is no longer available.');
        return null;
      }
      return url;
    } catch (_) {
      _toast('This media link has expired or is no longer available.');
      return null;
    }
  }

  Future<void> _openOriginal(AuraViewerItem item) async {
    final url = await _resolveOriginalUrl(item);
    if (url == null || !mounted) return;
    await openMediaExternally(context, url);
  }

  Future<void> _downloadOriginal(AuraViewerItem item) async {
    final url = await _resolveOriginalUrl(item);
    if (url == null || !mounted) return;
    await runMediaSave(context, url: url, filename: _viewerFilenameStem(item));
  }

  /// WHAT THE SAVE ACTION WILL ACTUALLY PRODUCE.
  ///
  /// Read from the distribution authority's own answer rather than assumed.
  /// "Download original" shown to somebody the server will hand a governed
  /// copy is a promise the backend then breaks, and they find out in their
  /// downloads folder.
  ///
  /// Unknown resolves to the NEUTRAL wording, never the permissive one: a
  /// server that predates the authority, or a URL not yet resolved, must not
  /// cause Aura to claim an entitlement it has not been told about.
  String _saveLabelFor(AuraViewerItem item) {
    final id = (item.mediaId ?? '').trim();
    if (id.isEmpty) return 'Save';
    final resolved = ref.read(mediaUrlProvider(id));
    final value = resolved.asData?.value;
    if (value == null) return 'Save';
    if (value.deliversOriginal) return 'Download original';
    if (value.deliversGovernedExport) return 'Save a copy';
    return 'Save';
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(message)));
  }

  // ── Keyboard ──────────────────────────────────────────────────────

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft && !_isZoomed) {
      _jumpPage(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight && !_isZoomed) {
      _jumpPage(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.equal || key == LogicalKeyboardKey.add) {
      _zoomBy(1.6);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.minus || key == LogicalKeyboardKey.numpadSubtract) {
      _zoomBy(1 / 1.6);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit0) {
      _resetZoom();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final item = _current;

    // LAYER 4 — resolved once, here, and passed down. Nothing below asks what
    // device it is on; it asks what it is allowed to offer.
    final profile = MediaInteractionProfile.resolve(
      canDecodeVideo: storedVideoCanDecodeInline(),
    );
    final caps = ImmersivePresenterRegistry.capabilitiesFor(
      ImmersiveRequest(
        isVideo: item.isVideo,
        mimeType: null,
        profile: profile,
        mediaId: item.mediaId,
        isPublic: item.isPublic,
        originalUrl: item.originalUrl,
      ),
    );

    // Zoom chrome needs BOTH a zoomable presenter and a platform where
    // discrete controls are the right idiom. On touch the image is under the
    // user's thumb and the buttons are noise; for video there is nothing to
    // zoom at all.
    final showZoomCluster = caps.zoomable && profile.zoomButtons;
    final showZoomReadout = caps.zoomable && profile.zoomReadout;

    // Open original earns primary chrome exactly when Aura cannot present the
    // media — the Windows video case — and is otherwise a secondary action.
    final sourceIsPrimary =
        caps.sourceActionIsPrimary || profile.persistentSourceActions;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1600, maxHeight: 1100),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Page area drives the actual-size math. Capture
                        // it post-frame to avoid a build-phase setState.
                        final size = Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        );
                        if (_pageSize != size) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) setState(() => _pageSize = size);
                          });
                        }
                        return PageView.builder(
                          controller: _pageController,
                          // When the current image is zoomed, the drag
                          // gesture must pan it — not swipe the page.
                          physics: _isZoomed
                              ? const NeverScrollableScrollPhysics()
                              : const PageScrollPhysics(),
                          itemCount: widget.items.length,
                          onPageChanged: _onPageChanged,
                          itemBuilder: (context, index) {
                            return _ViewerPage(
                              item: widget.items[index],
                              controller: _controllers[index],
                              minScale: _kMinScale,
                              maxScale: _kMaxScale,
                              onIntrinsicSize: (s) {
                                if (_intrinsicSizes[index] == null) {
                                  _intrinsicSizes[index] = s;
                                  if (mounted) setState(() {});
                                }
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                  _ViewerBottomBar(
                    item: item,
                    index: _index,
                    total: widget.items.length,
                    zoomPercent: _zoomPercent(),
                    showZoomCluster: showZoomCluster,
                    showZoomReadout: showZoomReadout,
                    sourceIsPrimary: sourceIsPrimary,
                    edgeToEdge: profile.edgeToEdge,
                    saveLabel: _saveLabelFor(item),
                    onZoomIn: () => _zoomBy(1.6),
                    onZoomOut: () => _zoomBy(1 / 1.6),
                    onReset: _resetZoom,
                    onActualSize: _actualSize,
                    onOpenOriginal: () => _openOriginal(item),
                    onDownloadOriginal: () => _downloadOriginal(item),
                  ),
                ],
              ),
              Positioned(
                top: 6,
                right: 6,
                child: _ViewerCircleButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Close',
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ),
              if (_index > 0 && !_isZoomed)
                Positioned(
                  left: 8,
                  top: 0,
                  bottom: 76,
                  child: Center(
                    child: _ViewerCircleButton(
                      icon: Icons.chevron_left_rounded,
                      tooltip: 'Previous',
                      onTap: () => _jumpPage(-1),
                    ),
                  ),
                ),
              if (_index < widget.items.length - 1 && !_isZoomed)
                Positioned(
                  right: 8,
                  top: 0,
                  bottom: 76,
                  child: Center(
                    child: _ViewerCircleButton(
                      icon: Icons.chevron_right_rounded,
                      tooltip: 'Next',
                      onTap: () => _jumpPage(1),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One page of the viewer — a zoomable image or a video player. Gated
/// media is resolved to a signed URL before the zoomable image renders.
class _ViewerPage extends ConsumerWidget {
  const _ViewerPage({
    required this.item,
    required this.controller,
    required this.minScale,
    required this.maxScale,
    required this.onIntrinsicSize,
  });

  final AuraViewerItem item;
  final TransformationController controller;
  final double minScale;
  final double maxScale;
  final ValueChanged<Size> onIntrinsicSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (item.isVideo) {
      return _ViewerVideo(item: item);
    }

    if (item.isPublic) {
      final url = item.originalUrl.trim();
      if (url.isEmpty) return const _ViewerMessage('This image is unavailable.');
      return _ZoomableImage(
        url: url,
        cacheKey: item.mediaId,
        controller: controller,
        minScale: minScale,
        maxScale: maxScale,
        onIntrinsicSize: onIntrinsicSize,
      );
    }

    // Gated media — resolve a fresh signed URL before rendering.
    final id = (item.mediaId ?? '').trim();
    if (id.isEmpty) {
      return const _ViewerMessage('This image is unavailable.');
    }
    final resolved = ref.watch(mediaUrlProvider(id));
    return resolved.when(
      data: (result) {
        final url = result.url.trim();
        if (url.isEmpty) {
          return const _ViewerMessage('This image is no longer available.');
        }
        return _ZoomableImage(
          url: url,
          cacheKey: id,
          controller: controller,
          minScale: minScale,
          maxScale: maxScale,
          onIntrinsicSize: onIntrinsicSize,
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, __) => const _ViewerMessage(
        'This media link has expired or is no longer available.',
      ),
    );
  }
}

/// Pinch / drag / double-tap zoomable image. The image decodes at full
/// resolution (no [ResizeImage] downscale) so panning a zoomed-in
/// screenshot stays sharp.
class _ZoomableImage extends StatefulWidget {
  const _ZoomableImage({
    required this.url,
    required this.cacheKey,
    required this.controller,
    required this.minScale,
    required this.maxScale,
    required this.onIntrinsicSize,
  });

  final String url;
  final String? cacheKey;
  final TransformationController controller;
  final double minScale;
  final double maxScale;
  final ValueChanged<Size> onIntrinsicSize;

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  late final ImageProvider _provider;
  ImageStream? _stream;
  ImageStreamListener? _listener;
  Offset _doubleTapPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    // Share the cache entry with AuraAttachmentImage (same key scheme)
    // so a thumbnail already on screen is reused at full resolution.
    _provider = CachedNetworkImageProvider(
      widget.url,
      cacheKey: (widget.cacheKey ?? '').trim().isNotEmpty
          ? 'aura_attachment:${widget.cacheKey!.trim()}'
          : null,
    );
    _resolveIntrinsicSize();
  }

  void _resolveIntrinsicSize() {
    final stream = _provider.resolve(ImageConfiguration.empty);
    _stream = stream;
    final listener = ImageStreamListener((info, _) {
      widget.onIntrinsicSize(
        Size(info.image.width.toDouble(), info.image.height.toDouble()),
      );
    }, onError: (_, __) {});
    _listener = listener;
    stream.addListener(listener);
  }

  @override
  void dispose() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    super.dispose();
  }

  void _handleDoubleTap() {
    final current = widget.controller.value.getMaxScaleOnAxis();
    if (current > widget.minScale + 0.01) {
      widget.controller.value = Matrix4.identity();
    } else {
      widget.controller.value = _scaleMatrix(2.5, _doubleTapPosition);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (d) => _doubleTapPosition = d.localPosition,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: widget.controller,
        minScale: widget.minScale,
        maxScale: widget.maxScale,
        // Keep the image inside the viewport while panning so it never
        // drifts off into empty space.
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Image(
            image: _provider,
            fit: BoxFit.contain,
            // Crisp sampling when zoomed past 100%.
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
            frameBuilder: (context, child, frame, wasSync) {
              if (wasSync || frame != null) return child;
              return const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              );
            },
            errorBuilder: (_, __, ___) =>
                const _ViewerMessage('This image could not be loaded.'),
          ),
        ),
      ),
    );
  }
}

/// Centered white message used for unavailable / failed media states.
class _ViewerMessage extends StatelessWidget {
  const _ViewerMessage(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 36,
            ),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: AuraText.body.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom action bar — caption, page counter, zoom controls and the
/// open / download original actions.
class _ViewerBottomBar extends StatelessWidget {
  const _ViewerBottomBar({
    required this.item,
    required this.index,
    required this.total,
    required this.zoomPercent,
    required this.showZoomCluster,
    required this.showZoomReadout,
    required this.sourceIsPrimary,
    required this.edgeToEdge,
    required this.saveLabel,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
    required this.onActualSize,
    required this.onOpenOriginal,
    required this.onDownloadOriginal,
  });

  final AuraViewerItem item;
  final int index;
  final int total;
  final int zoomPercent;
  final bool showZoomCluster;
  final bool showZoomReadout;
  final bool sourceIsPrimary;
  final bool edgeToEdge;
  final String saveLabel;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;
  final VoidCallback onActualSize;
  final VoidCallback onOpenOriginal;
  final VoidCallback onDownloadOriginal;

  @override
  Widget build(BuildContext context) {
    final caption = (item.caption ?? '').trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // MEDIA INFORMATION — a line, not a forensic console.
          //
          // Shown only when something was actually established. NO_EVIDENCE
          // renders nothing at all: media loses this information constantly,
          // so an "unverified" line would convert ordinary silence into an
          // accusation about the person who posted it.
          if (mediaOriginLabel(mediaOriginStateFrom(item.originState)) != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MediaOriginBadge(
                    state: mediaOriginStateFrom(item.originState),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      mediaOriginDetail(
                            mediaOriginStateFrom(item.originState),
                            credentials: item.contentCredentials,
                          ) ??
                          '',
                      style: AuraText.small.copyWith(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (caption.isNotEmpty) ...[
            SelectionArea(
              child: Text(
                caption,
                style: AuraText.body.copyWith(color: Colors.white),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              if (total > 1)
                Text(
                  '${index + 1} / $total',
                  style: AuraText.small.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if (showZoomReadout) ...[
                if (total > 1) const SizedBox(width: 10),
                Tooltip(
                  message: 'Zoom level',
                  child: Text(
                    '$zoomPercent%',
                    style: AuraText.small.copyWith(
                      color: Colors.white54,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (showZoomCluster) ...[
                _ViewerBarButton(
                  icon: Icons.remove_rounded,
                  tooltip: 'Zoom out',
                  onTap: onZoomOut,
                ),
                _ViewerBarButton(
                  icon: Icons.add_rounded,
                  tooltip: 'Zoom in',
                  onTap: onZoomIn,
                ),
                _ViewerBarButton(
                  icon: Icons.fit_screen_outlined,
                  tooltip: 'Fit to screen',
                  onTap: onReset,
                ),
                _ViewerBarButton(
                  icon: Icons.crop_original_outlined,
                  tooltip: 'Actual size (100%)',
                  onTap: onActualSize,
                ),
                const SizedBox(width: 4),
              ],
              // ── SOURCE ACTIONS ──────────────────────────────────────
              //
              // `Open original` is a SOURCE action, not a viewing feature. It
              // carries a label only when it has earned primary chrome — which
              // it does exactly when Aura cannot present the media itself, the
              // Windows video case, where it stops being clutter and becomes
              // the only route to watching. Everywhere else it stays an
              // unlabelled, quieter affordance beside the media rather than a
              // step the person must take to reach their own photograph.
              _ViewerBarButton(
                icon: Icons.open_in_new_rounded,
                tooltip: sourceIsPrimary
                    ? 'Open in another app'
                    : 'Open the original file',
                label: sourceIsPrimary ? 'Open in another app' : null,
                onTap: onOpenOriginal,
              ),
              // Save survives everywhere — wanting a copy is unrelated to
              // whether the viewer can display it — but its WORDING comes from
              // the distribution authority's real answer, so the button never
              // promises an original the server will replace with a governed
              // copy.
              _ViewerBarButton(
                icon: Icons.download_rounded,
                tooltip: saveLabel,
                label: saveLabel,
                onTap: onDownloadOriginal,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A pill button used in the viewer's bottom bar. Icon-only when [label]
/// is null, icon + text otherwise.
class _ViewerBarButton extends StatelessWidget {
  const _ViewerBarButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.label,
  });

  final IconData icon;
  final String tooltip;
  final String? label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: label == null ? 10 : 12,
              vertical: 9,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: Colors.white),
                if (label != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    label!,
                    style: AuraText.small.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular dark control used for close + page navigation.
class _ViewerCircleButton extends StatelessWidget {
  const _ViewerCircleButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.5),
        shape: const CircleBorder(side: BorderSide(color: Colors.white24)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// In-viewer video player. Visibility-gated video resolves a signed URL
/// first. Video has no zoom controls — the bottom bar still offers
/// open / download original.
class _ViewerVideo extends ConsumerWidget {
  const _ViewerVideo({required this.item});

  final AuraViewerItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (item.isPublic) {
      final url = item.originalUrl.trim();
      if (url.isEmpty) return const _ViewerMessage('This video is unavailable.');
      return _ViewerVideoPlayer(url: url);
    }
    final id = (item.mediaId ?? '').trim();
    if (id.isEmpty) return const _ViewerMessage('This video is unavailable.');
    final resolved = ref.watch(mediaUrlProvider(id));
    return resolved.when(
      data: (result) {
        final url = result.url.trim();
        if (url.isEmpty) {
          return const _ViewerMessage('This video is no longer available.');
        }
        return _ViewerVideoPlayer(url: url);
      },
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (_, __) => const _ViewerMessage(
        'This media link has expired or is no longer available.',
      ),
    );
  }
}

/// `m:ss`, or `h:mm:ss` past an hour. Tabular figures keep the readout from
/// shifting width as the seconds tick.
String _clock(Duration d) {
  final total = d.inSeconds;
  if (total <= 0) return '0:00';
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final sec = total % 60;
  final ss = sec.toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$ss';
  return '$m:$ss';
}

class _ViewerVideoPlayer extends StatefulWidget {
  const _ViewerVideoPlayer({required this.url});

  final String url;

  @override
  State<_ViewerVideoPlayer> createState() => _ViewerVideoPlayerState();
}

class _ViewerVideoPlayerState extends State<_ViewerVideoPlayer> {
  VideoPlayerController? _controller;
  Future<void>? _initialize;
  String? _error;

  @override
  void initState() {
    super.initState();
    final url = widget.url.trim();
    if (url.isEmpty) {
      _error = 'This video is unavailable.';
      return;
    }
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      _controller = controller;
      // BOUNDED — this is where the indefinite spinner came from.
      //
      // `initialize()` rejects on a decode error, so `catchError` handled that
      // case correctly. It does not reject when the load simply STALLS, and a
      // stall is silence rather than an error, so the FutureBuilder below sat
      // on `ConnectionState.waiting` forever and the honest message a line
      // down was unreachable. Bounding the wait is what connects them.
      _initialize = boundedMediaInit(
        MediaInitPhase.acquisition,
        () => controller.initialize(),
      ).then((_) async {
        await controller.setLooping(true);
        if (mounted) setState(() {});
      }).catchError((_) {
        if (mounted) setState(() => _error = 'This video could not be played.');
      });
    } catch (_) {
      _error = 'This video could not be played.';
    }
  }

  @override
  void dispose() {
    final c = _controller;
    _controller = null;
    c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if ((_error ?? '').isNotEmpty) {
      return _ViewerMessage(_error!);
    }
    final controller = _controller;
    final initialize = _initialize;
    if (controller == null || initialize == null) {
      return const _ViewerMessage('This video is unavailable.');
    }
    return FutureBuilder<void>(
      future: initialize,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _ViewerMessage('This video could not be played.');
        }
        if (snapshot.connectionState != ConnectionState.done ||
            !controller.value.isInitialized) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        final value = controller.value;
        final duration = value.duration;
        final position = value.position;

        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: AspectRatio(
                  // PORTRAIT VIDEO USES THE PORTRAIT SHAPE. The measured aspect
                  // is preferred over any assumed one, so a phone recording is
                  // pillarboxed inside the stage rather than cropped to fill a
                  // landscape box — destroying the top and bottom of somebody's
                  // video to make the frame tidy is not a presentation choice
                  // Aura gets to make on their behalf.
                  aspectRatio: value.aspectRatio > 0 ? value.aspectRatio : 16 / 9,
                  child: VideoPlayer(controller),
                ),
              ),
              const SizedBox(height: 10),
              // THE TRANSPORT. Play/pause and restart were the whole control
              // set before this; a video you cannot scrub is a video you cannot
              // actually use.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ViewerBarButton(
                      icon: value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      tooltip: value.isPlaying ? 'Pause' : 'Play',
                      onTap: () async {
                        if (value.isPlaying) {
                          await controller.pause();
                        } else {
                          await controller.play();
                        }
                        if (mounted) setState(() {});
                      },
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _clock(position),
                      style: AuraText.small.copyWith(
                        color: Colors.white70,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 260,
                      child: Semantics(
                        label: 'Seek',
                        value: '${_clock(position)} of ${_clock(duration)}',
                        child: Slider(
                          min: 0,
                          max: duration.inMilliseconds
                              .clamp(1, 1 << 30)
                              .toDouble(),
                          value: position.inMilliseconds
                              .clamp(0, duration.inMilliseconds)
                              .toDouble(),
                          onChanged: (ms) async {
                            await controller
                                .seekTo(Duration(milliseconds: ms.round()));
                            if (mounted) setState(() {});
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _clock(duration),
                      style: AuraText.small.copyWith(
                        color: Colors.white54,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ViewerBarButton(
                      icon: value.volume > 0
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_rounded,
                      tooltip: value.volume > 0 ? 'Mute' : 'Unmute',
                      onTap: () async {
                        await controller.setVolume(value.volume > 0 ? 0 : 1);
                        if (mounted) setState(() {});
                      },
                    ),
                    const SizedBox(width: 4),
                    _ViewerBarButton(
                      icon: Icons.replay_rounded,
                      tooltip: 'Restart',
                      onTap: () async {
                        await controller.seekTo(Duration.zero);
                        await controller.play();
                        if (mounted) setState(() {});
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
