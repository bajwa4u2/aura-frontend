/// PRODUCT STATE PRESENTATION AUTHORITY — C0 (rendering).
///
/// The single widget that renders a governed [ProductState]. It is a **thin
/// adapter over the existing Aura components** — `AuraLoadingState`,
/// `AuraEmptyState`, `AuraErrorState` — not a new design system. C0 does not
/// redesign screens; it makes the *meaning* of a state consistent.
///
/// Consumers say what is true, not what to draw:
///
/// ```dart
/// AuraProductState(
///   state: ProductState.retryableError,
///   subject: ProductNoun.message,
///   onRecover: controller.reload,
/// )
/// ```
library;

import 'package:flutter/material.dart';

import '../ui/aura_platform_components.dart';
import '../ui/aura_space.dart';
import '../ui/aura_surface.dart';
import '../ui/aura_text.dart';
import 'product_language.dart';
import 'product_state.dart';

class AuraProductState extends StatelessWidget {
  const AuraProductState({
    super.key,
    required this.state,
    this.scope = StateScope.surface,
    this.subject,
    this.headline,
    this.detail,
    this.onRecover,
    this.action,
    this.icon,
  });

  /// What is true right now.
  final ProductState state;

  /// Whether the whole surface is in this state, or a single control is.
  final StateScope scope;

  /// The product noun this state is about, used for honest default copy.
  final ProductNoun? subject;

  /// Contextual override. Surfaces with real context should supply this.
  final String? headline;
  final String? detail;

  /// Recovery handler. Only rendered when the state can *honestly* recover —
  /// see [ProductStateBehaviour.isRetryable]. Passing this for a denial or a
  /// terminal state is silently ignored rather than shown as a false offer.
  final VoidCallback? onRecover;

  /// A domain-specific action (e.g. "Request access"). Rendered instead of
  /// nothing when there is no honest retry.
  final Widget? action;

  /// Icon override for empty/informational presentations.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final copy = ProductStateCopy.of(state, subject: subject);
    final title = headline ?? copy.headline;
    final body = detail ?? copy.detail;

    if (scope == StateScope.inline) {
      return _inline(title);
    }

    switch (state) {
      case ProductState.loading:
      case ProductState.sending:
      case ProductState.uploading:
      case ProductState.reconnecting:
        return Center(child: AuraLoadingState(message: title));

      case ProductState.error:
      case ProductState.retryableError:
      case ProductState.failed:
      case ProductState.offline:
      case ProductState.unavailable:
        return AuraErrorState(title: title, body: body, action: _recovery());

      case ProductState.unauthorized:
      case ProductState.revoked:
      case ProductState.expired:
      case ProductState.deleted:
        // Denials and terminal states are NOT errors. Presenting them in the
        // danger treatment would tell the person something is broken when
        // nothing is.
        return AuraEmptyState(
          title: title,
          body: body,
          icon: icon ?? _neutralIcon,
          action: action,
        );

      case ProductState.empty:
        return AuraEmptyState(
          title: title,
          body: body,
          icon: icon ?? Icons.inbox_outlined,
          action: action,
        );

      case ProductState.success:
        return AuraEmptyState(
          title: title,
          body: body,
          icon: icon ?? Icons.check_circle_outline_rounded,
          action: action,
        );
    }
  }

  IconData get _neutralIcon => switch (state) {
        ProductState.unauthorized || ProductState.revoked => Icons.lock_outline,
        ProductState.expired => Icons.schedule_outlined,
        ProductState.deleted => Icons.do_not_disturb_alt_outlined,
        _ => Icons.info_outline,
      };

  /// The recovery control, or the caller's own action, or nothing.
  ///
  /// Retry is offered **only** where retry is meaningful, and always with the
  /// canonical label from [ProductLabels].
  Widget? _recovery() {
    if (state.isRetryable && onRecover != null) {
      return AuraSecondaryButton(
        label: ProductLabels.of(ProductAction.retry),
        onPressed: onRecover,
        icon: Icons.refresh_rounded,
      );
    }
    return action;
  }

  /// Inline presentation: a single control or row is in this state while the
  /// surrounding surface stays usable. Never occupies the surface.
  Widget _inline(String title) {
    if (state.isTransient) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AuraSurface.muted,
            ),
          ),
          const SizedBox(width: AuraSpace.s8),
          Text(title, style: AuraText.small),
        ],
      );
    }

    final isFault = state.isRetryable || state == ProductState.error;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isFault ? Icons.error_outline_rounded : _neutralIcon,
          size: 14,
          color: isFault ? AuraSurface.dangerInk : AuraSurface.faint,
        ),
        const SizedBox(width: AuraSpace.s8),
        Flexible(
          child: Text(
            headline ?? title,
            style: AuraText.small.copyWith(
              color: isFault ? AuraSurface.dangerInk : null,
            ),
          ),
        ),
        if (state.isRetryable && onRecover != null) ...[
          const SizedBox(width: AuraSpace.s8),
          AuraGhostButton(
            label: ProductLabels.of(ProductAction.retry),
            onPressed: onRecover,
          ),
        ],
      ],
    );
  }
}
