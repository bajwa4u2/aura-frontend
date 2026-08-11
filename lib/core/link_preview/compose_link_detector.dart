import 'dart:async';

import 'package:flutter/widgets.dart';

import 'link_preview.dart';
import 'link_url_detection.dart';

/// Compose Link Intelligence / OG Preview -- Phase 1.
///
/// Wraps a composer's `TextEditingController` (the same "wrap the
/// controller/focus node" convention `GovernedTagAutocomplete`
/// established for `@`/`#` detection, `lib/core/tagging/governed_tag_field.dart`)
/// and detects the first pasted/typed URL, debounces, resolves it through
/// the canonical `LinkPreviewService`, and reports the result. Both member
/// and institution compose screens instantiate this identically -- neither
/// re-implements URL detection or debounce logic.
///
/// Not a widget: unlike the tag autocomplete (which needs an `OverlayEntry`
/// positioned at the caret), a link preview renders as an ordinary inline
/// card below the text field, which the composer already knows how to lay
/// out -- there's no overlay-positioning concern here to justify a widget.
class ComposeLinkDetector {
  ComposeLinkDetector({
    required this.controller,
    required this.resolve,
    required this.onPreviewChanged,
    this.debounce = const Duration(milliseconds: 500),
  }) {
    controller.addListener(_onTextChanged);
  }

  final TextEditingController controller;
  final Future<LinkPreview?> Function(String url) resolve;
  final ValueChanged<LinkPreview?> onPreviewChanged;
  final Duration debounce;

  Timer? _debounceTimer;
  String? _lastDetectedUrl;
  bool _disposed = false;

  void _onTextChanged() {
    final url = firstUrlIn(controller.text);
    if (url == _lastDetectedUrl) return;
    _lastDetectedUrl = url;
    _debounceTimer?.cancel();

    if (url == null) {
      // Draft editing stays stable: removing the URL from the text clears
      // the attached preview rather than leaving a stale, orphaned card.
      onPreviewChanged(null);
      return;
    }

    _debounceTimer = Timer(debounce, () async {
      final preview = await resolve(url);
      if (_disposed) return;
      // The author may have kept typing during the network round trip --
      // if the detected URL has since changed (edited or replaced), this
      // result is stale and must not overwrite whatever is current.
      if (firstUrlIn(controller.text) != url) return;
      onPreviewChanged(preview);
    });
  }

  /// Forces immediate (re-)resolution of whatever URL is currently in the
  /// text, bypassing the debounce -- used when hydrating an existing draft
  /// so its preview appears without waiting for the author to type.
  void resolveNow() {
    final url = firstUrlIn(controller.text);
    _lastDetectedUrl = url;
    if (url == null) return;
    unawaited(
      resolve(url).then((preview) {
        if (_disposed) return;
        if (firstUrlIn(controller.text) != url) return;
        onPreviewChanged(preview);
      }),
    );
  }

  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    controller.removeListener(_onTextChanged);
  }
}
