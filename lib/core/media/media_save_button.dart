import 'package:flutter/material.dart';

import 'media_save_service.dart';

/// Runs a media save and surfaces the outcome to the user as a snackbar.
///
/// Shared by [MediaSaveButton] (the hover/overlay affordance on media
/// frames) and the long-press save path, and callable directly from
/// action bars such as the fullscreen viewer.
Future<MediaSaveResult> runMediaSave(
  BuildContext context, {
  required String url,
  String? filename,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger
    ?..clearSnackBars()
    ..showSnackBar(
      const SnackBar(
        content: Text('Preparing download…'),
        duration: Duration(seconds: 2),
      ),
    );

  final result = await const MediaSaveService().save(
    url: url,
    suggestedFilename: filename,
  );

  if (!context.mounted) return result;

  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(result.message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  return result;
}

/// Compact, self-contained "save media" affordance.
///
/// Designed to sit as a positioned overlay on top of a media frame —
/// dark, translucent, and legible over arbitrary photographic content.
/// Holds its own busy state so a slow fetch shows a spinner in place of
/// the download glyph. Adding this never changes the host's layout: it
/// is always rendered inside a [Stack] as a [Positioned] child.
class MediaSaveButton extends StatefulWidget {
  const MediaSaveButton({
    super.key,
    required this.url,
    this.filename,
    this.size = 34,
    this.tooltip = 'Save media',
  });

  /// Directly-fetchable media URL. Visibility-gated media must be
  /// resolved to a signed URL before being passed here.
  final String url;

  /// Preferred filename for the saved file. An extension is inferred
  /// when this is null or lacks one.
  final String? filename;

  final double size;
  final String tooltip;

  @override
  State<MediaSaveButton> createState() => _MediaSaveButtonState();
}

class _MediaSaveButtonState extends State<MediaSaveButton> {
  bool _busy = false;

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await runMediaSave(
        context,
        url: widget.url,
        filename: widget.filename,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final glyphSize = widget.size * 0.52;
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const CircleBorder(
        side: BorderSide(color: Colors.white24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Tooltip(
        message: widget.tooltip,
        child: InkWell(
          onTap: _busy ? null : _save,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Center(
              child: _busy
                  ? SizedBox(
                      width: glyphSize,
                      height: glyphSize,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(
                      Icons.download_rounded,
                      size: glyphSize,
                      color: Colors.white,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
