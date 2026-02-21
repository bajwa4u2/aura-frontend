import 'package:flutter/material.dart';

import 'aura_radius.dart';
import 'aura_scaffold.dart';
import 'aura_space.dart';
import 'aura_surface.dart';
import 'aura_text.dart';

/// Standard frame for document-like pages (Mission, Privacy, Founder, Hubs).
///
/// Rules:
/// - Always centered and constrained
/// - Always uses AuraScaffold (so Back + Home are consistent)
/// - Always scrolls (ListView)
class DocumentScaffold extends StatelessWidget {
  const DocumentScaffold({
    super.key,
    required this.title,
    required this.child,
    this.maxWidth = 760,
    this.actions,
    this.footer,
    this.homePath = '/public',
  });

  final String title;
  final Widget child;

  /// Document width. 760 is intentional: reading-first.
  final double maxWidth;

  /// Optional app bar actions. Home action is already handled by AuraScaffold.
  final List<Widget>? actions;

  /// Optional section placed after the document body.
  /// Useful for calm “related links” or a small callout.
  final Widget? footer;

  /// Where "Home" should go. '/public' is safe for both authed + unauthed.
  final String homePath;

  @override
  Widget build(BuildContext context) {
    return AuraScaffold(
      title: title,
      actions: actions,
      homePath: homePath,
      maxWidth: maxWidth,
      // Document pages control their own scroll + rhythm.
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AuraSpace.s16,
          AuraSpace.s16,
          AuraSpace.s16,
          AuraSpace.s24,
        ),
        children: [
          _DocumentSurface(child: child),
          if (footer != null) ...[
            SizedBox(height: AuraSpace.s12),
            _DocumentSurface(child: footer!),
          ],
        ],
      ),
    );
  }
}

class _DocumentSurface extends StatelessWidget {
  const _DocumentSurface({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.r18),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: child,
    );
  }
}

/// Small helpers for document pages (consistent rhythm).
class Doc {
  Doc._();

  static Widget title(String text) => Text(text, style: AuraText.title);

  static Widget lede(String text) => Padding(
        padding: EdgeInsets.only(top: AuraSpace.s10),
        child: Text(text, style: AuraText.body),
      );

  static Widget meta(String text) => Text(text, style: AuraText.muted);

  static Widget h(String text) => Padding(
        padding: EdgeInsets.only(top: AuraSpace.s18, bottom: AuraSpace.s10),
        child: Text(text, style: AuraText.emphasis),
      );

  static Widget p(String text) => Padding(
        padding: EdgeInsets.only(bottom: AuraSpace.s10),
        child: Text(text, style: AuraText.body),
      );

  static Widget callout(String text) => Container(
        margin: EdgeInsets.only(top: AuraSpace.s10, bottom: AuraSpace.s10),
        padding: EdgeInsets.all(AuraSpace.s12),
        decoration: BoxDecoration(
          color: AuraSurface.page,
          borderRadius: BorderRadius.circular(AuraRadius.r14),
          border: Border.all(color: AuraSurface.divider),
        ),
        child: Text(text, style: AuraText.body),
      );

  static Widget bullets(List<String> items) => Padding(
        padding: EdgeInsets.only(bottom: AuraSpace.s10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items
              .map(
                (x) => Padding(
                  padding: EdgeInsets.only(bottom: AuraSpace.s8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: AuraSpace.s6),
                        child: Icon(
                          Icons.circle,
                          size: 6,
                          color: AuraSurface.divider,
                        ),
                      ),
                      SizedBox(width: AuraSpace.s10),
                      Expanded(child: Text(x, style: AuraText.body)),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      );
}