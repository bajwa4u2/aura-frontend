/// AXR-1 — Universal Governed Tagging: the reusable autocomplete layer.
///
/// [GovernedTagAutocomplete] wraps any composer text field and adds
/// governed `@` / `#` autocomplete without owning the field: pass the
/// same [TextEditingController] and [FocusNode] the field uses, keep the
/// field as the child, and selection/keyboard behavior come for free.
/// This is platform infrastructure, not a Post feature — the same widget
/// wires into posts, replies, messages, and announcements composers.
///
/// Interaction contract:
///  * typing `@`/`#` (word-boundary guarded) plus one letter opens ranked
///    suggestions (at most six); continuous typing refilters;
///  * ArrowUp / ArrowDown move the highlight, Enter/Tab selects,
///    Escape (or Back on a phone) closes — while open, those keys never
///    reach the field;
///  * mouse/touch tap selects; a space, a pick or leaving the field closes;
///  * selection replaces the token with the canonical insert text.
///
/// PER PLATFORM (founder, 21 Oct 2026, DD-57). Windows, macOS, Linux and a
/// desktop-width browser show a popover hanging from the line being typed,
/// its left edge at the `#` / `@`, flipping above only when the window has
/// no room below. Phones and a phone-width browser show a strip of chips
/// sitting directly on the keyboard. Before, the list landed at the bottom
/// of a desktop window and at the top edge of a phone.
///
/// ATTACHED TAGS (same day). A person picked from the list showed with a
/// photo in the list and without one once inserted: the field holds plain
/// text. The people and topics attached to the text are now shown under the
/// field as chips with the same photo (or initial) and `#` mark.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderEditable;
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/aura_radius.dart';
import '../ui/aura_surface.dart';
import '../ui/aura_text.dart';
import '../ui/aura_platform_components.dart' show AuraAvatar;
import 'mention_scope.dart';
import 'tag_entities.dart';
import 'tag_suggest_service.dart';
import 'tag_token.dart';

/// How suggestions are presented on this platform and width.
enum TagSuggestionPresentation {
  /// A popover at the caret — Windows, macOS, Linux, desktop-width web.
  popover,

  /// A chip strip on top of the keyboard — Android, iOS, phone-width web.
  strip,
}

/// The presentation for [platform] at [width]. A browser follows the width
/// (a phone browser behaves like a phone); native follows the platform.
TagSuggestionPresentation tagSuggestionPresentationFor({
  required TargetPlatform platform,
  required bool isWeb,
  required double width,
}) {
  if (isWeb) {
    return width >= 600
        ? TagSuggestionPresentation.popover
        : TagSuggestionPresentation.strip;
  }
  switch (platform) {
    case TargetPlatform.windows:
    case TargetPlatform.macOS:
    case TargetPlatform.linux:
      return TagSuggestionPresentation.popover;
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      return TagSuggestionPresentation.strip;
  }
}

/// The most suggestions shown at once.
const int kTagSuggestionLimit = 6;

/// Popover width on desktop and desktop-width web.
const double kTagPopoverWidth = 320;

/// Height of the chip strip on phones.
const double kTagStripHeight = 56;

class GovernedTagAutocomplete extends ConsumerStatefulWidget {
  const GovernedTagAutocomplete({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.child,
    this.onTagSelected,
    this.maxOverlayHeight = 280,
    this.mentionScope = const MentionScope.global(),
    this.attached = const <TagReference>[],
    this.showAttached = true,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Widget child;
  final ValueChanged<TagReference>? onTagSelected;
  final double maxOverlayHeight;
  /// Governs `@` candidates. Default [MentionScope.global] preserves the
  /// existing live `/search`-backed behavior unchanged — Posts, Institution
  /// Posts, Announcements, and replies never pass this. Bounded surfaces
  /// (Thread/Space, DM) pass [MentionScope.bounded] with their own
  /// already-resolved, contextually-eligible candidate set. `#` topic
  /// suggestions are unaffected either way — they're a global taxonomy
  /// with no eligibility concept.
  final MentionScope mentionScope;

  /// Tags the composer already holds (a draft or an edited post). Shown as
  /// attached chips while their text is still in the field, alongside the
  /// ones picked here.
  final List<TagReference> attached;

  /// Show the attached people and topics under the field.
  final bool showAttached;

  @override
  ConsumerState<GovernedTagAutocomplete> createState() =>
      _GovernedTagAutocompleteState();
}

class _GovernedTagAutocompleteState
    extends ConsumerState<GovernedTagAutocomplete> {
  OverlayEntry? _overlay;
  Timer? _debounce;
  int _requestSeq = 0;
  FocusOnKeyEventCallback? _previousOnKeyEvent;

  ActiveTagToken? _token;
  List<TagSuggestion> _suggestions = const [];
  int _highlight = 0;
  int _announcedCount = -1;

  /// Tags picked in this field, in the order picked.
  final List<TagReference> _picked = <TagReference>[];

  bool get _open => _overlay != null && _suggestions.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _previousOnKeyEvent = widget.focusNode.onKeyEvent;
    widget.focusNode.onKeyEvent = _onFieldKey;
    widget.controller.addListener(_onTextChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    if (widget.focusNode.onKeyEvent == _onFieldKey) {
      widget.focusNode.onKeyEvent = _previousOnKeyEvent;
    }
    _debounce?.cancel();
    _removeOverlay();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!widget.focusNode.hasFocus) _close();
  }

  void _onTextChanged() {
    // The attached chips follow the text: removing a mention's text removes
    // its chip.
    if (widget.showAttached && mounted) setState(() {});
    final sel = widget.controller.selection;
    if (!sel.isValid || !sel.isCollapsed) {
      _close();
      return;
    }
    final token = activeTagTokenAt(widget.controller.text, sel.baseOffset);
    // A bare sigil opens nothing: one letter after it first.
    if (token == null || token.query.isEmpty) {
      _close();
      return;
    }
    _token = token;
    _debounce?.cancel();
    // '#' resolves locally (instant); '@' debounces the network lookup
    // just enough to coalesce fast typing without feeling laggy.
    final wait = token.sigil == '#'
        ? Duration.zero
        : const Duration(milliseconds: 120);
    final seq = ++_requestSeq;
    _debounce = Timer(wait, () async {
      final result = await _resolveSuggestions(token);
      if (!mounted || seq != _requestSeq) return;
      // The token may have moved/closed while the lookup ran.
      final selNow = widget.controller.selection;
      final tokenNow = selNow.isValid && selNow.isCollapsed
          ? activeTagTokenAt(widget.controller.text, selNow.baseOffset)
          : null;
      if (tokenNow == null ||
          tokenNow.sigil != token.sigil ||
          tokenNow.query.isEmpty) {
        _close();
        return;
      }
      final shown = result.take(kTagSuggestionLimit).toList();
      setState(() {
        _token = tokenNow;
        _suggestions = shown;
        _highlight = 0;
      });
      if (shown.isEmpty) {
        _removeOverlay();
      } else {
        _showOverlay();
        _announce(shown.length);
      }
    });
  }

  void _announce(int count) {
    if (count == _announcedCount) return;
    _announcedCount = count;
    final view = View.maybeOf(context);
    if (view == null) return;
    SemanticsService.sendAnnouncement(
      view,
      count == 1 ? '1 suggestion' : '$count suggestions',
      Directionality.maybeOf(context) ?? TextDirection.ltr,
    );
  }

  /// `#` always resolves against the local taxonomy (no eligibility
  /// concept). `@` under [MentionScope.bounded] filters the caller's
  /// already-eligible candidate set locally — never the raw global
  /// `/search` result, and never a second network-ranked authority.
  /// [MentionScope.global] keeps the exact prior behavior.
  Future<List<TagSuggestion>> _resolveSuggestions(ActiveTagToken token) {
    if (token.sigil == '#') {
      return ref.read(tagSuggestServiceProvider).suggest(token.sigil, token.query);
    }
    final scope = widget.mentionScope;
    if (scope is MentionScopeBounded) {
      return Future.value(_filterBounded(scope.eligible, token.query));
    }
    return ref.read(tagSuggestServiceProvider).suggest(token.sigil, token.query);
  }

  List<TagSuggestion> _filterBounded(List<TagSuggestion> candidates, String query) {
    final q = query.trim().toLowerCase();
    final matches = q.isEmpty
        ? candidates
        : candidates
              .where(
                (c) =>
                    c.display.toLowerCase().contains(q) ||
                    (c.subtitle ?? '').toLowerCase().contains(q),
              )
              .toList();
    return matches.take(TagSuggestService.maxSuggestions).toList();
  }

  void _close() {
    _debounce?.cancel();
    _requestSeq++;
    _token = null;
    _announcedCount = -1;
    if (_suggestions.isNotEmpty && mounted) {
      setState(() {
        _suggestions = const [];
        _highlight = 0;
      });
    }
    _removeOverlay();
  }

  void _select(TagSuggestion s) {
    final token = _token;
    if (token == null) return;
    final applied = applyTagSelection(
      widget.controller.text,
      token,
      s.insertText,
    );
    widget.controller.value = TextEditingValue(
      text: applied.text,
      selection: TextSelection.collapsed(offset: applied.cursor),
    );
    final reference = s.toReference(
      sourceText: s.insertText,
      startOffset: token.start,
      endOffset: token.start + s.insertText.length,
    );
    _picked.removeWhere(
      (r) => r.kind == reference.kind && r.canonicalId == reference.canonicalId,
    );
    _picked.add(reference);
    widget.onTagSelected?.call(reference);
    widget.focusNode.requestFocus();
    _close();
  }

  /// People and topics whose text is still in the field, de-duplicated:
  /// those the composer brought plus those picked here.
  List<TagReference> get _attachedNow {
    final text = widget.controller.text;
    final seen = <String>{};
    final out = <TagReference>[];
    for (final r in [...widget.attached, ..._picked]) {
      final insert = r.insertText.trim();
      if (insert.isEmpty || !text.contains(insert)) continue;
      if (!seen.add('${r.kind.name}:${r.canonicalId}')) continue;
      out.add(r);
    }
    return out;
  }

  /// Removing an attached chip removes its text from the field.
  void _detach(TagReference r) {
    final text = widget.controller.text;
    final insert = r.insertText.trim();
    final at = text.indexOf(insert);
    if (at < 0) return;
    var end = at + insert.length;
    if (end < text.length && text[end] == ' ') end++;
    final next = text.replaceRange(at, end, '');
    widget.controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: at.clamp(0, next.length)),
    );
    _picked.removeWhere(
      (p) => p.kind == r.kind && p.canonicalId == r.canonicalId,
    );
  }

  KeyEventResult _onFieldKey(FocusNode node, KeyEvent event) {
    final handled = _onKey(node, event);
    if (handled == KeyEventResult.handled) return handled;
    return _previousOnKeyEvent?.call(node, event) ?? KeyEventResult.ignored;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!_open) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() => _highlight = (_highlight + 1) % _suggestions.length);
      _overlay?.markNeedsBuild();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      setState(
        () => _highlight =
            (_highlight - 1 + _suggestions.length) % _suggestions.length,
      );
      _overlay?.markNeedsBuild();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.tab) {
      _select(_suggestions[_highlight]);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      _close();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  TagSuggestionPresentation _presentation() {
    return tagSuggestionPresentationFor(
      platform: defaultTargetPlatform,
      isWeb: kIsWeb,
      width: _windowMedia().size.width,
    );
  }

  void _showOverlay() {
    // The root overlay builds before the field in the same frame, so it
    // would measure the caret one keystroke late; measure again once the
    // field has laid out the new text.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _overlay?.markNeedsBuild();
    });
    if (_overlay != null) {
      _overlay!.markNeedsBuild();
      return;
    }
    // The ROOT overlay: a composer inside a shell page must not have its
    // suggestions clipped at the page's edge (above the bottom navigation).
    _overlay = OverlayEntry(
      builder: (overlayContext) {
        if (!mounted) return const SizedBox.shrink();
        final query = _token?.query ?? '';
        if (_presentation() == TagSuggestionPresentation.strip) {
          final strip = _stripPlacement(overlayContext);
          return Positioned(
            left: 0,
            right: 0,
            top: strip.top,
            height: kTagStripHeight,
            child: _SuggestionStrip(
              suggestions: _suggestions,
              query: query,
              onSelect: _select,
            ),
          );
        }
        final placement = _popoverPlacement(overlayContext);
        return Positioned(
          left: placement.left,
          width: placement.width,
          top: placement.above ? null : placement.anchorY,
          bottom: placement.above
              ? placement.overlayHeight - placement.anchorY
              : null,
          child: _SuggestionPopover(
            suggestions: _suggestions,
            query: query,
            highlight: _highlight,
            maxHeight: placement.maxHeight,
            onSelect: _select,
            onHover: (i) {
              setState(() => _highlight = i);
              _overlay?.markNeedsBuild();
            },
          ),
        );
      },
    );
    Overlay.of(context, rootOverlay: true).insert(_overlay!);
  }

  /// The caret rect and the trigger's left edge, in [overlayBox]
  /// coordinates; null when the field is not laid out.
  ({Rect caret, double triggerX})? _caretGeometry(RenderBox overlayBox) {
    final targetBox = context.findRenderObject() as RenderBox?;
    if (targetBox == null || !targetBox.attached) return null;
    final editable = _findEditable(targetBox);
    final offset = widget.controller.selection.baseOffset;
    if (editable != null && offset >= 0) {
      final local = editable.getLocalRectForCaret(TextPosition(offset: offset));
      final topLeft = editable.localToGlobal(local.topLeft, ancestor: overlayBox);
      final caret = topLeft & local.size;
      var triggerX = caret.left;
      final start = _token?.start;
      if (start != null && start >= 0) {
        final t = editable.getLocalRectForCaret(TextPosition(offset: start));
        final tl = editable.localToGlobal(t.topLeft, ancestor: overlayBox);
        // Same line only: a token that wrapped hangs from the caret.
        if ((tl.dy - caret.top).abs() < 2) triggerX = tl.dx;
      }
      return (caret: caret, triggerX: triggerX);
    }
    final topLeft = targetBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final caret = Rect.fromLTWH(topLeft.dx, topLeft.dy, 0, targetBox.size.height);
    return (caret: caret, triggerX: caret.left);
  }

  /// Desktop: hang from the line being typed, left edge at the `#` / `@`;
  /// above it only when the window has no room below.
  _TagOverlayPlacement _popoverPlacement(BuildContext overlayContext) {
    final media = _windowMedia();
    final overlayBox = _overlayBox(overlayContext);
    final overlaySize = overlayBox?.size ?? media.size;
    const gap = 4.0;
    const edge = 8.0;
    final width = (overlaySize.width - 2 * edge).clamp(0.0, kTagPopoverWidth);
    final geometry = overlayBox == null ? null : _caretGeometry(overlayBox);
    if (geometry == null) {
      return _TagOverlayPlacement(
        left: edge,
        width: width,
        anchorY: edge,
        above: false,
        maxHeight: widget.maxOverlayHeight,
        overlayHeight: overlaySize.height,
      );
    }
    final caret = geometry.caret;
    final visibleTop = media.padding.top + edge;
    final visibleBottom =
        overlaySize.height - media.viewInsets.bottom - media.padding.bottom - edge;
    final spaceBelow = visibleBottom - caret.bottom - gap;
    final spaceAbove = caret.top - gap - visibleTop;
    final wanted = _popoverHeight();
    final above = spaceBelow < wanted && spaceAbove > spaceBelow;
    final room = above ? spaceAbove : spaceBelow;
    final maxLeft = (overlaySize.width - width - edge).clamp(edge, double.infinity);

    return _TagOverlayPlacement(
      left: geometry.triggerX.clamp(edge, maxLeft),
      width: width,
      anchorY: above ? caret.top - gap : caret.bottom + gap,
      above: above,
      maxHeight: room.clamp(48.0, widget.maxOverlayHeight),
      overlayHeight: overlaySize.height,
    );
  }

  double _popoverHeight() =>
      (_suggestions.length * _SuggestionPopover.rowHeight + 8)
          .clamp(0.0, widget.maxOverlayHeight);

  /// Phones: directly on top of the keyboard (or the bottom safe area), and
  /// directly above the line being typed if the keyboard edge would cover it.
  ({double top}) _stripPlacement(BuildContext overlayContext) {
    final media = _windowMedia();
    final overlayBox = _overlayBox(overlayContext);
    final height = overlayBox?.size.height ?? media.size.height;
    final bottomInset = media.viewInsets.bottom > 0
        ? media.viewInsets.bottom
        : media.padding.bottom;
    var top = height - bottomInset - kTagStripHeight;
    final geometry = overlayBox == null ? null : _caretGeometry(overlayBox);
    if (geometry != null && geometry.caret.bottom + 2 > top) {
      top = geometry.caret.top - 4 - kTagStripHeight;
    }
    return (top: top.clamp(media.padding.top, height - kTagStripHeight));
  }

  /// The root overlay's box. The entry's own context has no render object
  /// while it is first being built, which left the geometry empty and put
  /// the popover in the window's corner.
  RenderBox? _overlayBox(BuildContext overlayContext) {
    final box = Overlay.maybeOf(context, rootOverlay: true)
        ?.context
        .findRenderObject();
    if (box is RenderBox && box.hasSize) return box;
    final own = overlayContext.findRenderObject();
    return own is RenderBox && own.hasSize ? own : null;
  }

  /// The window's own keyboard and safe-area insets. A Scaffold that
  /// resizes for the keyboard consumes viewInsets for everything below it,
  /// so the field's MediaQuery reads 0 and the strip landed at the screen
  /// bottom, under the keyboard (S24+, 21 Oct 2026). The overlay is placed
  /// in window coordinates, so it reads the window.
  MediaQueryData _windowMedia() {
    final view = View.maybeOf(context);
    return view == null ? MediaQuery.of(context) : MediaQueryData.fromView(view);
  }

  RenderEditable? _findEditable(RenderObject root) {
    if (root is RenderEditable) return root;
    RenderEditable? found;
    root.visitChildren((child) {
      found ??= _findEditable(child);
    });
    return found;
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  @override
  Widget build(BuildContext context) {
    final attached = widget.showAttached ? _attachedNow : const <TagReference>[];
    return PopScope(
      // Back on a phone closes an open list before it leaves the page.
      canPop: !_open,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _open) _close();
      },
      child: Focus(
        onKeyEvent: _onKey,
        // The wrapped field keeps its own FocusNode; this ancestor Focus
        // only intercepts navigation keys while the overlay is open.
        skipTraversal: true,
        child: attached.isEmpty
            ? widget.child
            : Column(
                mainAxisSize: MainAxisSize.min,
                // start, not stretch: a composer may sit in a Row without a
                // bounded width.
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  widget.child,
                  AttachedTagRow(references: attached, onRemove: _detach),
                ],
              ),
      ),
    );
  }
}

class _TagOverlayPlacement {
  const _TagOverlayPlacement({
    required this.left,
    required this.width,
    required this.anchorY,
    required this.above,
    required this.maxHeight,
    required this.overlayHeight,
  });

  final double left;
  final double width;

  /// The caret edge the panel hangs from: its top when below, its bottom
  /// when above.
  final double anchorY;
  final bool above;
  final double maxHeight;
  final double overlayHeight;
}

/// The typed part of [label] in bold; the rest regular.
TextSpan tagMatchSpan(String label, String query, TextStyle style) {
  final q = query.trim().toLowerCase();
  final at = q.isEmpty ? -1 : label.toLowerCase().indexOf(q);
  if (at < 0) return TextSpan(text: label, style: style);
  return TextSpan(
    style: style,
    children: [
      if (at > 0) TextSpan(text: label.substring(0, at)),
      TextSpan(
        text: label.substring(at, at + q.length),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      if (at + q.length < label.length)
        TextSpan(text: label.substring(at + q.length)),
    ],
  );
}

/// The mark for a tag: the person's or institution's photo (initial when
/// there is none), or `#` for a topic. The list, the strip and the attached
/// chips all use it, so a pick looks the same before and after.
class TagMark extends StatelessWidget {
  const TagMark({
    super.key,
    required this.kind,
    required this.name,
    this.imageUrl,
    this.size = 32,
  });

  final TagKind kind;
  final String name;
  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (kind == TagKind.topic) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AuraSurface.accentSoft,
        ),
        child: Text(
          '#',
          style: AuraText.body.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: size * 0.5,
            color: AuraSurface.accentText,
          ),
        ),
      );
    }
    return AuraAvatar(name: name, imageUrl: imageUrl, size: size);
  }
}

BoxDecoration _overlayDecoration() => BoxDecoration(
  color: AuraSurface.overlay,
  borderRadius: BorderRadius.circular(AuraRadius.r12),
  border: Border.all(color: AuraSurface.divider),
  boxShadow: const [
    BoxShadow(color: Color(0x66000000), blurRadius: 18, offset: Offset(0, 6)),
  ],
);

/// Desktop: up to six rows in a card at the caret.
class _SuggestionPopover extends StatelessWidget {
  const _SuggestionPopover({
    required this.suggestions,
    required this.query,
    required this.highlight,
    required this.maxHeight,
    required this.onSelect,
    required this.onHover,
  });

  static const double rowHeight = 52;

  final List<TagSuggestion> suggestions;
  final String query;
  final int highlight;
  final double maxHeight;
  final ValueChanged<TagSuggestion> onSelect;
  final ValueChanged<int> onHover;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        key: const ValueKey('tag-suggestion-popover'),
        decoration: _overlayDecoration(),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: suggestions.length,
            itemBuilder: (context, i) {
              final s = suggestions[i];
              final selected = i == highlight;
              return Semantics(
                button: true,
                selected: selected,
                label: s.display,
                excludeSemantics: true,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => onHover(i),
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (_) => onSelect(s),
                    child: Container(
                      height: rowHeight,
                      color: selected ? AuraSurface.accentSoft : Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          TagMark(kind: s.kind, name: s.display, imageUrl: s.imageUrl),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text.rich(
                                  tagMatchSpan(s.display, query, AuraText.body),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if ((s.subtitle ?? '').isNotEmpty)
                                  Text(
                                    s.subtitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AuraText.micro.copyWith(
                                      color: AuraSurface.muted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Phones: a sideways-scrolling row of chips on top of the keyboard.
class _SuggestionStrip extends StatelessWidget {
  const _SuggestionStrip({
    required this.suggestions,
    required this.query,
    required this.onSelect,
  });

  final List<TagSuggestion> suggestions;
  final String query;
  final ValueChanged<TagSuggestion> onSelect;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        key: const ValueKey('tag-suggestion-strip'),
        decoration: const BoxDecoration(
          color: AuraSurface.overlay,
          border: Border(top: BorderSide(color: AuraSurface.divider)),
        ),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: suggestions.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final s = suggestions[i];
            return Semantics(
              button: true,
              label: s.display,
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(s),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(4, 0, 12, 0),
                  decoration: BoxDecoration(
                    color: AuraSurface.elevated,
                    borderRadius: BorderRadius.circular(AuraRadius.pill),
                    border: Border.all(color: AuraSurface.divider),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TagMark(
                        kind: s.kind,
                        name: s.display,
                        imageUrl: s.imageUrl,
                        size: 30,
                      ),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 200),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text.rich(
                              tagMatchSpan(s.display, query, AuraText.body),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if ((s.subtitle ?? '').isNotEmpty)
                              Text(
                                s.subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AuraText.micro.copyWith(
                                  color: AuraSurface.muted,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The people and topics attached to a composer's text, with the same photo
/// (or initial) and `#` mark the suggestions showed. × takes one out of the
/// text.
class AttachedTagRow extends StatelessWidget {
  const AttachedTagRow({
    super.key,
    required this.references,
    required this.onRemove,
  });

  final List<TagReference> references;
  final ValueChanged<TagReference> onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('attached-tag-row'),
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final r in references)
            Container(
              padding: const EdgeInsets.fromLTRB(3, 3, 4, 3),
              decoration: BoxDecoration(
                color: AuraSurface.elevated,
                borderRadius: BorderRadius.circular(AuraRadius.pill),
                border: Border.all(color: AuraSurface.divider),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TagMark(
                    kind: r.kind,
                    name: r.displayLabel,
                    imageUrl: r.identity?.imageUrl,
                    size: 24,
                  ),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: Text(
                      r.displayLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Remove ${r.displayLabel}',
                    excludeSemantics: true,
                    child: InkResponse(
                      radius: 16,
                      onTap: () => onRemove(r),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: AuraSurface.muted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
