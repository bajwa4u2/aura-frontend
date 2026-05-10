import 'package:flutter/material.dart';

import '../../app/shell/shell_shared.dart';
import 'aura_radius.dart';
import 'aura_scaffold.dart';
import 'aura_space.dart';
import 'aura_surface.dart';
import 'aura_text.dart';

/// Standard frame for document-like pages (Mission, Privacy, Founder, Hubs).
///
/// Rules:
/// - Always centered and constrained
/// - Always uses AuraScaffold
/// - Always scrolls
/// - Reading-first atmosphere
/// - The public site footer is opt-in via [showSiteFooter]. Public-shell
///   screens (mission / privacy / terms / founder / hubs) pass `true` so the
///   footer flows at the end of the page scroll. Workspace screens that
///   reuse this scaffold (institution units / domains / verification) leave
///   it `false` so public chrome never leaks into a workspace.
class DocumentScaffold extends StatelessWidget {
  const DocumentScaffold({
    super.key,
    required this.title,
    required this.child,
    this.maxWidth = 780,
    this.actions,
    this.footer,
    this.homePath = '/',
    this.showSiteFooter = false,
  });

  final String title;
  final Widget child;
  final double maxWidth;
  final List<Widget>? actions;
  final Widget? footer;
  final String homePath;
  final bool showSiteFooter;

  @override
  Widget build(BuildContext context) {
    return AuraScaffold(
      title: title,
      actions: actions,
      homePath: homePath,
      maxWidth: 1080,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.md,
              AuraSpace.lg,
              AuraSpace.md,
              AuraSpace.xl,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  children: [
                    _DocumentSurface(child: child),
                    if (footer != null) ...[
                      const SizedBox(height: AuraSpace.lg),
                      _DocumentSurface(child: footer!),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (showSiteFooter) const ShellFooter(),
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
      padding: const EdgeInsets.all(AuraSpace.lg),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.lg),
        border: Border.all(color: AuraSurface.divider, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 32,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Small helpers for document pages (consistent editorial rhythm).
class Doc {
  Doc._();

  static Widget title(String text) => Text(text, style: AuraText.title);

  static Widget meta(String text) => Text(text, style: AuraText.muted);

  static Widget lede(String text) => Padding(
    padding: const EdgeInsets.only(top: AuraSpace.sm),
    child: Text(text, style: AuraText.body.copyWith(fontSize: 16, height: 1.8)),
  );

  static Widget h(String text) => Padding(
    padding: const EdgeInsets.only(top: AuraSpace.xl, bottom: AuraSpace.sm),
    child: Text(text, style: AuraText.emphasis.copyWith(fontSize: 16)),
  );

  static Widget p(String text) => Padding(
    padding: const EdgeInsets.only(bottom: AuraSpace.sm),
    child: Text(text, style: AuraText.body.copyWith(height: 1.7)),
  );

  static Widget callout(String text) => Container(
    margin: const EdgeInsets.symmetric(vertical: AuraSpace.md),
    padding: const EdgeInsets.all(AuraSpace.md),
    decoration: BoxDecoration(
      color: AuraSurface.elevated,
      borderRadius: BorderRadius.circular(AuraRadius.md),
      border: Border.all(color: AuraSurface.divider),
    ),
    child: Text(text, style: AuraText.body.copyWith(height: 1.6)),
  );

  static Widget bullets(List<String> items) => Padding(
    padding: const EdgeInsets.only(bottom: AuraSpace.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (x) => Padding(
              padding: const EdgeInsets.only(bottom: AuraSpace.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 9),
                    child: Icon(
                      Icons.circle,
                      size: 6,
                      color: AuraSurface.muted,
                    ),
                  ),
                  const SizedBox(width: AuraSpace.sm),
                  Expanded(
                    child: Text(x, style: AuraText.body.copyWith(height: 1.6)),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    ),
  );
}
