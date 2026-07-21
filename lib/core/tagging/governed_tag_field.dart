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
///  * typing `@`/`#` (word-boundary guarded) opens ranked suggestions;
///  * continuous typing refilters; backspace refilters or closes;
///  * ArrowUp / ArrowDown move the highlight, Enter/Tab selects,
///    Escape closes — while open, those keys never reach the field;
///  * mouse/touch tap selects;
///  * selection replaces the token with the canonical insert text.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/aura_radius.dart';
import '../ui/aura_surface.dart';
import '../ui/aura_text.dart';
import '../ui/aura_platform_components.dart' show AuraAvatar;
import 'tag_entities.dart';
import 'tag_suggest_service.dart';
import 'tag_token.dart';

class GovernedTagAutocomplete extends ConsumerStatefulWidget {
  const GovernedTagAutocomplete({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.child,
    this.onTagSelected,
    this.maxOverlayHeight = 280,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Widget child;
  final ValueChanged<TagReference>? onTagSelected;
  final double maxOverlayHeight;

  @override
  ConsumerState<GovernedTagAutocomplete> createState() =>
      _GovernedTagAutocompleteState();
}

class _GovernedTagAutocompleteState
    extends ConsumerState<GovernedTagAutocomplete> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _overlay;
  Timer? _debounce;
  int _requestSeq = 0;
  FocusOnKeyEventCallback? _previousOnKeyEvent;

  ActiveTagToken? _token;
  List<TagSuggestion> _suggestions = const [];
  int _highlight = 0;

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
    final sel = widget.controller.selection;
    if (!sel.isValid || !sel.isCollapsed) {
      _close();
      return;
    }
    final token = activeTagTokenAt(widget.controller.text, sel.baseOffset);
    if (token == null) {
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
      final result = await ref
          .read(tagSuggestServiceProvider)
          .suggest(token.sigil, token.query);
      if (!mounted || seq != _requestSeq) return;
      // The token may have moved/closed while the lookup ran.
      final selNow = widget.controller.selection;
      final tokenNow = selNow.isValid && selNow.isCollapsed
          ? activeTagTokenAt(widget.controller.text, selNow.baseOffset)
          : null;
      if (tokenNow == null || tokenNow.sigil != token.sigil) {
        _close();
        return;
      }
      setState(() {
        _suggestions = result;
        _highlight = 0;
      });
      if (result.isEmpty) {
        _removeOverlay();
      } else {
        _showOverlay();
      }
    });
  }

  void _close() {
    _debounce?.cancel();
    _requestSeq++;
    _token = null;
    if (_suggestions.isNotEmpty) {
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
    widget.onTagSelected?.call(
      s.toReference(
        sourceText: s.insertText,
        startOffset: token.start,
        endOffset: token.start + s.insertText.length,
      ),
    );
    widget.focusNode.requestFocus();
    _close();
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

  void _showOverlay() {
    if (_overlay != null) {
      _overlay!.markNeedsBuild();
      return;
    }
    _overlay = OverlayEntry(
      builder: (context) => Positioned(
        width: 320,
        child: CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 4),
          child: _SuggestionPanel(
            suggestions: _suggestions,
            highlight: _highlight,
            maxHeight: widget.maxOverlayHeight,
            onSelect: _select,
            onHover: (i) {
              setState(() => _highlight = i);
              _overlay?.markNeedsBuild();
            },
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: _onKey,
      // The wrapped field keeps its own FocusNode; this ancestor Focus
      // only intercepts navigation keys while the overlay is open.
      skipTraversal: true,
      child: CompositedTransformTarget(link: _link, child: widget.child),
    );
  }
}

class _SuggestionPanel extends StatelessWidget {
  const _SuggestionPanel({
    required this.suggestions,
    required this.highlight,
    required this.maxHeight,
    required this.onSelect,
    required this.onHover,
  });

  final List<TagSuggestion> suggestions;
  final int highlight;
  final double maxHeight;
  final ValueChanged<TagSuggestion> onSelect;
  final ValueChanged<int> onHover;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      color: AuraSurface.elevated,
      borderRadius: BorderRadius.circular(AuraRadius.card),
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
            return MouseRegion(
              onEnter: (_) => onHover(i),
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) => onSelect(s),
                child: Container(
                  color: selected ? AuraSurface.accentSoft : Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      if (s.kind == TagKind.topic)
                        Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AuraSurface.accentSoft,
                          ),
                          child: Text(
                            '#',
                            style: AuraText.body.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AuraSurface.accentText,
                            ),
                          ),
                        )
                      else
                        AuraAvatar(
                          name: s.display,
                          imageUrl: s.imageUrl,
                          size: 32,
                        ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.display,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AuraText.body.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
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
