/// PRODUCT STATE PRESENTATION AUTHORITY — C0 (semantics).
///
/// > **A STATE IS A MEANING, NOT A WIDGET.**
///
/// ── WHY THIS EXISTS ──────────────────────────────────────────────────────
/// Measured drift: **122** raw `CircularProgressIndicator` uses and **131**
/// `SizedBox.shrink()` uses. Classification of those 122 found **26 genuine
/// full-surface loading states** — the rest are legitimate inline progress and
/// are deliberately NOT migrated. The real defect was never "too many
/// spinners"; it was that *nothing-here-yet*, *you-cannot-see-this*,
/// *it-is-gone*, *it-broke*, and *we-are-offline* were all rendered as the
/// same silence or the same grey circle.
///
/// ── WHAT THIS OWNS ───────────────────────────────────────────────────────
/// The governed state vocabulary and each state's **behavioural meaning**:
/// is it transient? is retry meaningful? is the object gone? does unsaved
/// human work need protecting?
///
/// ── WHAT IT DOES NOT OWN ─────────────────────────────────────────────────
/// Layout, visual design, or where a state appears. It also does **not**
/// claim inline progress: a send button's own spinner, a small avatar
/// placeholder or a per-row shimmer are legitimately local and stay local.
/// See [StateScope].
library;

import 'product_language.dart';

/// The governed product states.
///
/// Distinctions that must **never** be collapsed:
///   EMPTY != ERROR              nothing yet vs something broke
///   UNAUTHORIZED != EMPTY       not permitted vs nothing to show
///   DELETED != UNAVAILABLE      gone for good vs not reachable now
///   EXPIRED != REVOKED          time ran out vs access was withdrawn
///   OFFLINE != ERROR            transport condition, not a failure
///   FAILED != ERROR             *this* operation failed and the person's
///                               work must be preserved
enum ProductState {
  /// Work in progress; outcome unknown. Transient.
  loading,

  /// The request succeeded and there is legitimately nothing to show.
  empty,

  /// Something went wrong and retrying would not help.
  error,

  /// Something went wrong and retrying is a meaningful action.
  retryableError,

  /// No network transport. A condition of the environment, not a defect.
  offline,

  /// Transport was lost and is being re-established. Resolves itself.
  reconnecting,

  /// The thing exists but cannot be served right now.
  unavailable,

  /// The thing was time-bound and its window has passed.
  expired,

  /// Access was deliberately withdrawn by an authority.
  revoked,

  /// The thing no longer exists. Terminal.
  deleted,

  /// The person is not permitted to see or act on this.
  unauthorized,

  /// An outbound operation is in flight (message, reply, publication).
  sending,

  /// Content bytes are transferring.
  uploading,

  /// An operation the person initiated failed. Their input still exists.
  failed,

  /// An operation the person initiated completed.
  success,
}

/// Where a state legitimately belongs.
///
/// This is the distinction that keeps the migration honest. Only [surface]
/// states are owned by the canonical presentation; [inline] states remain the
/// property of the component that raised them.
enum StateScope {
  /// The whole surface/section is in this state and has no content to show.
  surface,

  /// A single control, row, tile or field is in this state while the
  /// surrounding surface remains usable and populated.
  inline,
}

extension ProductStateBehaviour on ProductState {
  /// Will resolve on its own without the person doing anything.
  bool get isTransient => switch (this) {
        ProductState.loading ||
        ProductState.reconnecting ||
        ProductState.sending ||
        ProductState.uploading =>
          true,
        _ => false,
      };

  /// No action available to anyone changes this outcome.
  bool get isTerminal =>
      this == ProductState.deleted || this == ProductState.expired;

  /// Retry is a meaningful, honest offer.
  ///
  /// Deliberately **false** for [ProductState.unauthorized],
  /// [ProductState.revoked], [ProductState.deleted] and
  /// [ProductState.expired] — offering Retry there tells the person a lie
  /// about what is wrong.
  bool get isRetryable => switch (this) {
        ProductState.retryableError ||
        ProductState.failed ||
        ProductState.unavailable ||
        ProductState.offline =>
          true,
        _ => false,
      };

  /// The person authored something that must survive this state.
  ///
  /// Consumers must not clear composers, drafts or selected attachments while
  /// in one of these states.
  bool get preservesUserWork => switch (this) {
        ProductState.failed ||
        ProductState.sending ||
        ProductState.uploading ||
        ProductState.offline ||
        ProductState.reconnecting =>
          true,
        _ => false,
      };

  /// The state is a denial of access rather than a fault.
  ///
  /// Denials must never be presented as errors or as emptiness.
  bool get isAccessDenial => switch (this) {
        ProductState.unauthorized || ProductState.revoked => true,
        _ => false,
      };

  /// The canonical recovery action, or null when nothing honest can be
  /// offered. [ProductAction.retry] is the single canonical word (FD-10).
  ProductAction? get recoveryAction =>
      isRetryable ? ProductAction.retry : null;
}

/// Default copy for a governed state.
///
/// This is **not** a string database. Prose stays with the surface that writes
/// it; these are only the fallbacks that stop fifteen different spellings of
/// "Something went wrong" existing for one meaning. A surface with genuine
/// context should pass its own headline and detail.
class ProductStateCopy {
  const ProductStateCopy(this.headline, this.detail);

  final String headline;
  final String detail;

  static ProductStateCopy of(ProductState state, {ProductNoun? subject}) {
    final it = subject?.plural.toLowerCase() ?? 'this';
    final one = subject?.singular.toLowerCase() ?? 'this';

    switch (state) {
      case ProductState.loading:
        return const ProductStateCopy('Loading', 'One moment.');
      case ProductState.empty:
        return ProductStateCopy(
          subject == null ? 'Nothing here yet' : 'No $it yet',
          'When there is something to show, it will appear here.',
        );
      case ProductState.error:
        return const ProductStateCopy(
          'Something went wrong',
          'This could not be completed.',
        );
      case ProductState.retryableError:
        return const ProductStateCopy(
          'Something went wrong',
          'This did not load. You can try once more.',
        );
      case ProductState.offline:
        return const ProductStateCopy(
          'You are offline',
          'Your work is saved. This will continue when the connection returns.',
        );
      case ProductState.reconnecting:
        return const ProductStateCopy(
          'Reconnecting',
          'Restoring the connection.',
        );
      case ProductState.unavailable:
        return ProductStateCopy(
          'Not available right now',
          'This $one exists but cannot be reached at the moment.',
        );
      case ProductState.expired:
        return ProductStateCopy(
          'This has expired',
          'The time window for this $one has passed.',
        );
      case ProductState.revoked:
        return const ProductStateCopy(
          'Access was withdrawn',
          'You no longer have access to this.',
        );
      case ProductState.deleted:
        return ProductStateCopy(
          'No longer available',
          'This $one has been removed.',
        );
      case ProductState.unauthorized:
        return const ProductStateCopy(
          'You do not have access',
          'This is not available to your account.',
        );
      case ProductState.sending:
        return const ProductStateCopy('Sending', 'This is on its way.');
      case ProductState.uploading:
        return const ProductStateCopy('Uploading', 'Transferring your file.');
      case ProductState.failed:
        return const ProductStateCopy(
          'Not sent',
          'Your message was kept. You can send it again.',
        );
      case ProductState.success:
        return const ProductStateCopy('Done', 'This completed.');
    }
  }
}
