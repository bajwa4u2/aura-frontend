import 'package:flutter/material.dart';

import '../../../../core/product/product_state.dart';
import '../../../../core/product/product_state_view.dart';
import '../../../../core/ui/aura_card.dart';
import '../../../../core/ui/aura_platform_components.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_surface.dart';
import '../../../../core/ui/aura_text.dart';

/// Communication-centre loading surface.
///
/// Delegates to the Product State Presentation Authority. Rendering is
/// unchanged — `AuraProductState` composes the same `AuraLoadingState` — but
/// the *meaning* now comes from one place.
class CommLoadingState extends StatelessWidget {
  const CommLoadingState({super.key, this.message = 'Loading…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AuraProductState(
      state: ProductState.loading,
      headline: message,
    );
  }
}

/// Communication-centre error surface.
///
/// Declared as [ProductState.retryableError] rather than a generic error: the
/// caller supplies a recovery handler, so retry is an honest offer here. The
/// authority renders the canonical Retry label; this widget no longer decides
/// what that word is.
class CommErrorState extends StatelessWidget {
  const CommErrorState({
    super.key,
    required this.title,
    required this.body,
    required this.onRetry,
  });

  final String title;
  final String body;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AuraProductState(
      state: ProductState.retryableError,
      headline: title,
      detail: body,
      onRecover: onRetry,
    );
  }
}

class CommResultCard extends StatelessWidget {
  const CommResultCard({
    super.key,
    required this.title,
    required this.body,
    required this.chipLabel,
  });

  final String title;
  final String body;
  final String chipLabel;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      borderColor: AuraSurface.divider,
      color: AuraSurface.subtle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              AuraStatusChip(
                label: chipLabel,
                backgroundColor: AuraSurface.card,
                textColor: AuraSurface.ink,
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(body, style: AuraText.muted),
        ],
      ),
    );
  }
}

class CommPreviewPanel extends StatelessWidget {
  const CommPreviewPanel({
    super.key,
    required this.title,
    required this.previewText,
    required this.text,
    required this.html,
  });

  final String title;
  final String previewText;
  final String text;
  final String html;

  @override
  Widget build(BuildContext context) {
    final htmlSummary = html.trim().isEmpty
        ? 'No HTML returned.'
        : html.trim().length <= 320
            ? html.trim()
            : '${html.trim().substring(0, 320)}…';

    return AuraCard(
      borderColor: AuraSurface.divider,
      color: AuraSurface.subtle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AuraSpace.s6),
          Text(previewText, style: AuraText.muted),
          const SizedBox(height: AuraSpace.s12),
          const Text('Text preview', style: AuraText.label),
          const SizedBox(height: AuraSpace.s4),
          Text(
            text.isEmpty ? 'No text returned.' : text,
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s12),
          const Text('HTML summary', style: AuraText.label),
          const SizedBox(height: AuraSpace.s4),
          Text(htmlSummary, style: AuraText.small),
        ],
      ),
    );
  }
}

class CommTwoColumnFields extends StatelessWidget {
  const CommTwoColumnFields({super.key, required this.fields});

  final List<Widget> fields;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 820;
        final children = <Widget>[];
        if (wide) {
          for (var i = 0; i < fields.length; i += 2) {
            children.add(
              Row(
                children: [
                  Expanded(child: fields[i]),
                  const SizedBox(width: AuraSpace.s12),
                  Expanded(
                    child: i + 1 < fields.length
                        ? fields[i + 1]
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            );
            if (i + 2 < fields.length) {
              children.add(const SizedBox(height: AuraSpace.s12));
            }
          }
        } else {
          for (var i = 0; i < fields.length; i++) {
            children.add(fields[i]);
            if (i != fields.length - 1) {
              children.add(const SizedBox(height: AuraSpace.s12));
            }
          }
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
      },
    );
  }
}
