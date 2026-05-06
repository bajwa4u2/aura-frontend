import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/ui/aura_platform_components.dart';
import '../../core/ui/aura_radius.dart';
import '../../core/ui/aura_space.dart';
import '../../core/ui/aura_surface.dart';
import '../../core/ui/aura_text.dart';

/// Shape of the visible crop frame.
///
/// `rect` keeps the editor preview rectangular; `circle` clips the preview
/// to a circle (avatar). The exported bytes are **always rectangular** — the
/// downstream UI is responsible for circular masking when it renders. That
/// keeps the upload payload identical between modes and removes the need to
/// composite an alpha-channel cutout server-side.
enum ProfileMediaEditorShape { rect, circle }

/// Per-mode configuration. Aspect ratio drives the on-screen frame; the
/// output (`outputWidth × outputHeight`) is the resolution we encode the
/// cropped image at — small avatars stay crisp; covers stay reasonable
/// bandwidth.
class ProfileMediaEditorConfig {
  const ProfileMediaEditorConfig({
    required this.aspectRatio,
    required this.shape,
    required this.outputWidth,
    required this.outputHeight,
    required this.title,
    required this.subtitle,
  });

  final double aspectRatio;
  final ProfileMediaEditorShape shape;
  final int outputWidth;
  final int outputHeight;
  final String title;
  final String subtitle;

  static const memberAvatar = ProfileMediaEditorConfig(
    aspectRatio: 1.0,
    shape: ProfileMediaEditorShape.circle,
    outputWidth: 800,
    outputHeight: 800,
    title: 'Edit avatar',
    subtitle: 'Pinch to zoom · drag to reposition',
  );

  static const memberCover = ProfileMediaEditorConfig(
    aspectRatio: 3.0,
    shape: ProfileMediaEditorShape.rect,
    outputWidth: 1500,
    outputHeight: 500,
    title: 'Edit cover',
    subtitle: 'Pinch to zoom · drag to reposition',
  );

  static const institutionLogo = ProfileMediaEditorConfig(
    aspectRatio: 1.0,
    shape: ProfileMediaEditorShape.rect,
    outputWidth: 800,
    outputHeight: 800,
    title: 'Edit logo',
    subtitle: 'Pinch to zoom · drag to reposition',
  );

  static const institutionCover = ProfileMediaEditorConfig(
    aspectRatio: 4.0,
    shape: ProfileMediaEditorShape.rect,
    outputWidth: 1600,
    outputHeight: 400,
    title: 'Edit institution banner',
    subtitle: 'Pinch to zoom · drag to reposition',
  );
}

/// Full-screen modal editor for profile media (avatars, logos, covers).
///
/// Architecture:
///   1. Caller picks a file and gets the raw bytes.
///   2. Caller invokes [ProfileMediaEditor.open] with the bytes + a config.
///   3. The editor decodes the image with `dart:ui`, lets the user pan + zoom
///      inside a fixed-aspect frame, and on Save renders the visible crop
///      into a `Canvas`/`Picture` at the configured output resolution.
///   4. The cropped PNG bytes flow back to the caller's `await`, which is
///      then responsible for uploading via `uploadAuraMedia(...)`.
///
/// This editor never talks to the network. It is a pure pixel pipeline.
class ProfileMediaEditor extends StatefulWidget {
  const ProfileMediaEditor({
    super.key,
    required this.imageBytes,
    required this.config,
  });

  final Uint8List imageBytes;
  final ProfileMediaEditorConfig config;

  /// Push the editor as a fullscreen dialog. Resolves to the cropped PNG
  /// bytes, or `null` if the user cancelled.
  static Future<Uint8List?> open(
    BuildContext context, {
    required Uint8List imageBytes,
    required ProfileMediaEditorConfig config,
  }) {
    return Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ProfileMediaEditor(
          imageBytes: imageBytes,
          config: config,
        ),
      ),
    );
  }

  @override
  State<ProfileMediaEditor> createState() => _ProfileMediaEditorState();
}

class _ProfileMediaEditorState extends State<ProfileMediaEditor> {
  ui.Image? _image;
  Object? _decodeError;

  // Transform state — `_scale = 1.0` means the image fully covers the frame
  // (cover-fit). User can scale up to `_maxScale`. Offset is the pan delta
  // from centered.
  double _scale = 1.0;
  Offset _offset = Offset.zero;

  // Gesture pivots — captured at scaleStart and reused on each update so
  // pan + pinch combine cleanly without drift.
  double _gestureStartScale = 1.0;
  Offset _gestureStartOffset = Offset.zero;
  Offset? _gestureFocalStart;

  // Computed each layout pass.
  Size? _frameSize;

  static const double _minScale = 1.0;
  static const double _maxScale = 4.0;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _decodeImage();
  }

  Future<void> _decodeImage() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.imageBytes);
      final frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() {
        _image = frame.image;
        _decodeError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _decodeError = e;
      });
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  // ── Geometry ──────────────────────────────────────────────────────────────

  /// Cover-fit base scale: at `_scale = 1` the image just covers the frame
  /// on its tighter axis, so the entire frame is opaque image with no
  /// empty edges.
  double _baseFitScale(Size frame) {
    final image = _image!;
    return _coverFitScale(
      imageW: image.width.toDouble(),
      imageH: image.height.toDouble(),
      frameW: frame.width,
      frameH: frame.height,
    );
  }

  double _coverFitScale({
    required double imageW,
    required double imageH,
    required double frameW,
    required double frameH,
  }) {
    final scaleW = frameW / imageW;
    final scaleH = frameH / imageH;
    return scaleW > scaleH ? scaleW : scaleH;
  }

  /// Max allowed offset in screen pixels: the image must always cover the
  /// frame, so at scale `_scale` we can pan by at most half the overhang on
  /// each side.
  Offset _maxOffsetFor(Size frame) {
    final image = _image!;
    final s = _baseFitScale(frame) * _scale;
    final imageScreenW = image.width * s;
    final imageScreenH = image.height * s;
    final maxX = ((imageScreenW - frame.width) / 2).clamp(0.0, double.infinity);
    final maxY =
        ((imageScreenH - frame.height) / 2).clamp(0.0, double.infinity);
    return Offset(maxX, maxY);
  }

  Offset _clamp(Offset offset, Size frame) {
    final max = _maxOffsetFor(frame);
    return Offset(
      offset.dx.clamp(-max.dx, max.dx),
      offset.dy.clamp(-max.dy, max.dy),
    );
  }

  // ── Gesture ───────────────────────────────────────────────────────────────

  void _onScaleStart(ScaleStartDetails details) {
    _gestureStartScale = _scale;
    _gestureStartOffset = _offset;
    _gestureFocalStart = details.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final frame = _frameSize;
    if (frame == null || _image == null) return;
    final start = _gestureFocalStart ?? details.localFocalPoint;
    final delta = details.localFocalPoint - start;
    final newScale =
        (_gestureStartScale * details.scale).clamp(_minScale, _maxScale);
    final newOffset = _clamp(_gestureStartOffset + delta, frame);
    if (newScale == _scale && newOffset == _offset) return;
    setState(() {
      _scale = newScale;
      _offset = newOffset;
    });
  }

  void _onScrollWheel(double scrollDelta) {
    final frame = _frameSize;
    if (frame == null || _image == null) return;
    // 1.0 unit of dy ≈ 0.5% scale change — slow and predictable.
    final factor = 1.0 - (scrollDelta * 0.005);
    final newScale = (_scale * factor).clamp(_minScale, _maxScale);
    if (newScale == _scale) return;
    setState(() {
      _scale = newScale;
      _offset = _clamp(_offset, frame);
    });
  }

  void _reset() {
    setState(() {
      _scale = 1.0;
      _offset = Offset.zero;
    });
  }

  // ── Save (crop) ───────────────────────────────────────────────────────────

  Future<void> _save() async {
    final image = _image;
    final frame = _frameSize;
    if (image == null || frame == null) return;

    setState(() => _saving = true);

    try {
      final bytes = await _renderCrop(image, frame);
      if (!mounted) return;
      Navigator.of(context).pop(bytes);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save crop: $e')),
      );
    }
  }

  /// Renders the currently-visible crop window into PNG bytes at the
  /// configured output resolution.
  ///
  /// Math: the on-screen frame `[0, 0, frameW, frameH]` corresponds to a
  /// rectangle in the source image's pixel space, given the current
  /// scale + offset. We compute that source rect, then `drawImageRect` it
  /// onto a `Canvas` of the output size.
  Future<Uint8List> _renderCrop(ui.Image image, Size frame) async {
    final base = _coverFitScale(
      imageW: image.width.toDouble(),
      imageH: image.height.toDouble(),
      frameW: frame.width,
      frameH: frame.height,
    );
    final s = base * _scale;
    final imageScreenW = image.width * s;
    final imageScreenH = image.height * s;
    final imageScreenLeft = (frame.width - imageScreenW) / 2 + _offset.dx;
    final imageScreenTop = (frame.height - imageScreenH) / 2 + _offset.dy;

    final srcLeft = (-imageScreenLeft) / s;
    final srcTop = (-imageScreenTop) / s;
    final srcRight = (frame.width - imageScreenLeft) / s;
    final srcBottom = (frame.height - imageScreenTop) / s;

    // Clamp source rect into image bounds — defensive, the offset clamper
    // already guarantees this but rounding can push us a fraction of a
    // pixel out.
    final src = Rect.fromLTRB(
      srcLeft.clamp(0.0, image.width.toDouble()),
      srcTop.clamp(0.0, image.height.toDouble()),
      srcRight.clamp(0.0, image.width.toDouble()),
      srcBottom.clamp(0.0, image.height.toDouble()),
    );
    final outW = widget.config.outputWidth.toDouble();
    final outH = widget.config.outputHeight.toDouble();
    final dst = Rect.fromLTWH(0, 0, outW, outH);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..filterQuality = FilterQuality.high
      ..isAntiAlias = true;
    canvas.drawImageRect(image, src, dst, paint);
    final picture = recorder.endRecording();
    try {
      final out = await picture.toImage(
        widget.config.outputWidth,
        widget.config.outputHeight,
      );
      try {
        final byteData = await out.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) {
          throw StateError('Encoded image returned no bytes');
        }
        return byteData.buffer.asUint8List();
      } finally {
        out.dispose();
      }
    } finally {
      picture.dispose();
    }
  }

  // ── Render ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(widget.config.title, style: AuraText.headline),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _saving ? null : () => Navigator.of(context).pop(null),
          tooltip: 'Cancel',
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: AuraSpace.s8),
            Expanded(child: _buildPreview()),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (_decodeError != null) {
      return Center(
        child: AuraErrorState(
          title: 'Could not load image',
          body: 'The selected file may be corrupted or unsupported.',
          action: AuraSecondaryButton(
            label: 'Try again',
            icon: Icons.refresh_rounded,
            onPressed: () {
              setState(() => _decodeError = null);
              _decodeImage();
            },
          ),
        ),
      );
    }
    if (_image == null) {
      return const Center(child: AuraLoadingState(message: 'Preparing…'));
    }

    final aspect = widget.config.aspectRatio;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Fit the frame into the available area, preserving aspect ratio.
        final maxW = constraints.maxWidth - AuraSpace.s32;
        final maxH = constraints.maxHeight - AuraSpace.s32;
        double frameW = maxW;
        double frameH = frameW / aspect;
        if (frameH > maxH) {
          frameH = maxH;
          frameW = frameH * aspect;
        }
        final frame = Size(frameW, frameH);
        _frameSize = frame;
        return Center(
          child: Listener(
            onPointerSignal: (signal) {
              if (signal is PointerScrollEvent) {
                _onScrollWheel(signal.scrollDelta.dy);
              }
            },
            child: GestureDetector(
              onScaleStart: _onScaleStart,
              onScaleUpdate: _onScaleUpdate,
              child: _ClippedFrame(
                size: frame,
                shape: widget.config.shape,
                child: SizedBox(
                  width: frame.width,
                  height: frame.height,
                  child: _ImageLayer(
                    image: _image!,
                    frameSize: frame,
                    scale: _scale,
                    offset: _offset,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildControls() {
    final disabled = _image == null || _saving;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.s16,
        AuraSpace.s12,
        AuraSpace.s16,
        AuraSpace.s16,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF101018),
        border: Border(
          top: BorderSide(color: Color(0xFF1F1F2A), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.config.subtitle,
            style: AuraText.micro.copyWith(
              color: Colors.white.withValues(alpha: 0.65),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AuraSpace.s8),
          Row(
            children: [
              const Icon(Icons.zoom_out_rounded,
                  color: Colors.white70, size: 18),
              Expanded(
                child: Slider(
                  value: _scale.clamp(_minScale, _maxScale),
                  min: _minScale,
                  max: _maxScale,
                  onChanged: disabled
                      ? null
                      : (v) {
                          final frame = _frameSize;
                          if (frame == null) return;
                          setState(() {
                            _scale = v;
                            _offset = _clamp(_offset, frame);
                          });
                        },
                ),
              ),
              const Icon(Icons.zoom_in_rounded,
                  color: Colors.white70, size: 18),
            ],
          ),
          const SizedBox(height: AuraSpace.s8),
          Row(
            children: [
              Expanded(
                child: _DarkActionButton(
                  label: 'Reset',
                  icon: Icons.restore_rounded,
                  onPressed: disabled ? null : _reset,
                ),
              ),
              const SizedBox(width: AuraSpace.s10),
              Expanded(
                child: _DarkActionButton(
                  label: 'Cancel',
                  onPressed:
                      _saving ? null : () => Navigator.of(context).pop(null),
                ),
              ),
              const SizedBox(width: AuraSpace.s10),
              Expanded(
                child: _PrimaryActionButton(
                  label: _saving ? 'Saving…' : 'Save',
                  onPressed: disabled ? null : _save,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClippedFrame extends StatelessWidget {
  const _ClippedFrame({
    required this.size,
    required this.shape,
    required this.child,
  });

  final Size size;
  final ProfileMediaEditorShape shape;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final clipped = shape == ProfileMediaEditorShape.circle
        ? ClipOval(child: child)
        : ClipRRect(
            borderRadius: BorderRadius.circular(AuraRadius.lg),
            child: child,
          );
    return SizedBox(
      width: size.width,
      height: size.height,
      child: Stack(
        children: [
          Positioned.fill(child: clipped),
          // Frame outline so the user always sees the crop boundary
          // distinctly from the image. Soft, low-saturation.
          IgnorePointer(
            child: shape == ProfileMediaEditorShape.circle
                ? Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 2,
                      ),
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AuraRadius.lg),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 2,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ImageLayer extends StatelessWidget {
  const _ImageLayer({
    required this.image,
    required this.frameSize,
    required this.scale,
    required this.offset,
  });

  final ui.Image image;
  final Size frameSize;
  final double scale;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: frameSize,
      painter: _ImagePainter(
        image: image,
        frameSize: frameSize,
        scale: scale,
        offset: offset,
      ),
    );
  }
}

class _ImagePainter extends CustomPainter {
  const _ImagePainter({
    required this.image,
    required this.frameSize,
    required this.scale,
    required this.offset,
  });

  final ui.Image image;
  final Size frameSize;
  final double scale;
  final Offset offset;

  @override
  void paint(Canvas canvas, Size size) {
    // Cover-fit base × user scale.
    final baseScaleW = size.width / image.width;
    final baseScaleH = size.height / image.height;
    final base = baseScaleW > baseScaleH ? baseScaleW : baseScaleH;
    final s = base * scale;
    final imageW = image.width * s;
    final imageH = image.height * s;
    final left = (size.width - imageW) / 2 + offset.dx;
    final top = (size.height - imageH) / 2 + offset.dy;
    final dst = Rect.fromLTWH(left, top, imageW, imageH);
    final src =
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..isAntiAlias = true;
    canvas.drawImageRect(image, src, dst, paint);
  }

  @override
  bool shouldRepaint(covariant _ImagePainter old) =>
      old.image != image ||
      old.frameSize != frameSize ||
      old.scale != scale ||
      old.offset != offset;
}

class _DarkActionButton extends StatelessWidget {
  const _DarkActionButton({
    required this.label,
    this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1B1B26),
      borderRadius: BorderRadius.circular(AuraRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s14,
            vertical: 11,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: Colors.white),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: AuraText.body.copyWith(
                  fontSize: 13,
                  color: onPressed == null
                      ? Colors.white.withValues(alpha: 0.4)
                      : Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AuraSurface.accent,
      borderRadius: BorderRadius.circular(AuraRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s14,
            vertical: 11,
          ),
          child: Center(
            child: Text(
              label,
              style: AuraText.body.copyWith(
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
