import 'package:aura/core/product/product_language.dart';
import 'package:aura/core/product/product_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Product State Authority — vocabulary completeness', () {
    test('every state has copy', () {
      for (final state in ProductState.values) {
        final copy = ProductStateCopy.of(state);
        expect(copy.headline.trim(), isNotEmpty, reason: '$state headline');
        expect(copy.detail.trim(), isNotEmpty, reason: '$state detail');
      }
    });

    test('empty copy names the subject when one is given', () {
      final generic = ProductStateCopy.of(ProductState.empty);
      final specific =
          ProductStateCopy.of(ProductState.empty, subject: ProductNoun.message);
      expect(generic.headline, 'Nothing here yet');
      expect(specific.headline, 'No messages yet');
    });

    test('no two states share a headline unless they mean the same fault', () {
      // error and retryableError deliberately share a headline; the difference
      // is whether recovery is offered, not what the person is told happened.
      final headlines = <String, List<ProductState>>{};
      for (final state in ProductState.values) {
        headlines
            .putIfAbsent(ProductStateCopy.of(state).headline, () => [])
            .add(state);
      }
      final collisions =
          headlines.entries.where((e) => e.value.length > 1).toList();
      expect(collisions.length, 1);
      expect(
        collisions.single.value.toSet(),
        {ProductState.error, ProductState.retryableError},
      );
    });
  });

  group('Product State Authority — behavioural meaning', () {
    test('retry is offered only where retry is honest', () {
      expect(ProductState.retryableError.isRetryable, isTrue);
      expect(ProductState.failed.isRetryable, isTrue);
      expect(ProductState.unavailable.isRetryable, isTrue);
      expect(ProductState.offline.isRetryable, isTrue);

      // Offering Retry here would misdescribe what is wrong.
      expect(ProductState.unauthorized.isRetryable, isFalse);
      expect(ProductState.revoked.isRetryable, isFalse);
      expect(ProductState.deleted.isRetryable, isFalse);
      expect(ProductState.expired.isRetryable, isFalse);
      expect(ProductState.empty.isRetryable, isFalse);
      expect(ProductState.error.isRetryable, isFalse);
    });

    test('recovery action is always the canonical retry action', () {
      for (final state in ProductState.values) {
        expect(
          state.recoveryAction,
          state.isRetryable ? ProductAction.retry : isNull,
          reason: '$state',
        );
      }
    });

    test('access denial is never an error and never emptiness', () {
      expect(ProductState.unauthorized.isAccessDenial, isTrue);
      expect(ProductState.revoked.isAccessDenial, isTrue);
      expect(ProductState.empty.isAccessDenial, isFalse);
      expect(ProductState.error.isAccessDenial, isFalse);
      // A denial must not be presented as recoverable.
      expect(ProductState.unauthorized.isRetryable, isFalse);
      expect(ProductState.revoked.isRetryable, isFalse);
    });

    test('terminal states are not transient and not retryable', () {
      for (final state in ProductState.values.where((s) => s.isTerminal)) {
        expect(state.isTransient, isFalse, reason: '$state');
        expect(state.isRetryable, isFalse, reason: '$state');
      }
      expect(ProductState.deleted.isTerminal, isTrue);
      expect(ProductState.expired.isTerminal, isTrue);
      // Unavailable is NOT terminal — the thing still exists.
      expect(ProductState.unavailable.isTerminal, isFalse);
    });

    test('states that can lose authored work declare it', () {
      // The composer must survive every one of these.
      expect(ProductState.failed.preservesUserWork, isTrue);
      expect(ProductState.sending.preservesUserWork, isTrue);
      expect(ProductState.uploading.preservesUserWork, isTrue);
      expect(ProductState.offline.preservesUserWork, isTrue);
      expect(ProductState.reconnecting.preservesUserWork, isTrue);
      expect(ProductState.success.preservesUserWork, isFalse);
    });

    test('transient states resolve without the person acting', () {
      const transient = {
        ProductState.loading,
        ProductState.reconnecting,
        ProductState.sending,
        ProductState.uploading,
      };
      for (final state in ProductState.values) {
        expect(state.isTransient, transient.contains(state), reason: '$state');
      }
    });
  });
}
