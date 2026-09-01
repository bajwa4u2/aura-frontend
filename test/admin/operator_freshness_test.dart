import 'package:aura/features/admin/data/admin_providers.dart';
import 'package:aura/features/admin/domain/operator_freshness.dart';
import 'package:aura/features/admin/domain/operator_signal.dart';
import 'package:dio/dio.dart';
import 'package:aura/features/admin/ui/operator_states.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// STALE IS AN EVENT, NOT AN AGE.
///
/// `OperatorReach.stale` was in the vocabulary from the start — *the value is
/// real but was read some time ago and could not be refreshed* — and nothing
/// ever produced it. Every authority that failed to refresh discarded the
/// reading it already held and reported `unavailable`, so an operator watching
/// a live console lost the last known state at the exact moment the network got
/// worse, and was shown a read failure instead of the answer from a minute ago.
///
/// These tests hold the whole transition, in both directions, and they hold the
/// three refusals that keep staleness honest: a cold failure is not stale, an
/// authority change discards what was held, and a recovery returns to current
/// rather than staying old.
class _ScriptedRepository implements AdminRepository {
  _ScriptedRepository(this._answers);

  final List<Object> _answers;
  int calls = 0;

  @override
  Future<PlatformHealth> fetchHealth() async {
    final answer = _answers[calls < _answers.length ? calls : _answers.length - 1];
    calls++;
    if (answer is PlatformHealth) return answer;
    throw answer;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PlatformHealth _healthy(String label) => PlatformHealth(
      checks: [
        HealthCheck(
          key: 'database',
          label: label,
          condition: OperatorCondition.healthy,
        ),
      ],
    );

DioException _offline() => DioException(
      requestOptions: RequestOptions(path: '/admin/health'),
      type: DioExceptionType.connectionError,
    );

DioException _refused(int code) => DioException(
      requestOptions: RequestOptions(path: '/admin/health'),
      response: Response(
        requestOptions: RequestOptions(path: '/admin/health'),
        statusCode: code,
      ),
    );

ProviderContainer _containerFor(_ScriptedRepository repo) {
  final c = ProviderContainer(
    overrides: [adminRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('READY becomes STALE when a refresh fails', () {
    test('the last good reading is kept, with the value intact', () async {
      final repo = _ScriptedRepository([_healthy('first'), _offline()]);
      final c = _containerFor(repo);

      final first = await c.read(platformHealthProvider.future);
      expect(first.reach, OperatorReach.complete);
      expect(first.value!.checks.single.label, 'first');

      c.invalidate(platformHealthProvider);
      final second = await c.read(platformHealthProvider.future);

      expect(second.reach, OperatorReach.stale,
          reason: 'a failed refresh over a held reading is stale, not a read '
              'failure');
      expect(second.value!.checks.single.label, 'first',
          reason: 'the operator keeps the answer they already had');
    });

    test('the stale reading carries the moment it was actually taken', () async {
      final repo = _ScriptedRepository([_healthy('first'), _offline()]);
      final c = _containerFor(repo);

      final before = DateTime.now();
      final first = await c.read(platformHealthProvider.future);
      final after = DateTime.now();

      c.invalidate(platformHealthProvider);
      final stale = await c.read(platformHealthProvider.future);

      expect(stale.readAt, isNotNull,
          reason: 'without a reading time the surface cannot state an age, '
              'and an unstated age reads as fresh');
      expect(stale.readAt!.isBefore(after.add(const Duration(seconds: 1))), isTrue);
      expect(stale.readAt!.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(stale.readAt, first.readAt,
          reason: 'the age is of the READING, not of the failure that exposed '
              'it');
    });

    test('stale is retryable and discloses itself', () async {
      final repo = _ScriptedRepository([_healthy('first'), _offline()]);
      final c = _containerFor(repo);
      await c.read(platformHealthProvider.future);
      c.invalidate(platformHealthProvider);
      final stale = await c.read(platformHealthProvider.future);

      expect(stale.reach.hasValue, isTrue);
      expect(stale.reach.needsDisclosure, isTrue);
      expect(stale.reach.isRetryable, isTrue);
    });
  });

  group('STALE returns to READY when the refresh succeeds', () {
    test('recovery replaces the old value rather than keeping it', () async {
      final repo = _ScriptedRepository([
        _healthy('first'),
        _offline(),
        _healthy('second'),
      ]);
      final c = _containerFor(repo);

      await c.read(platformHealthProvider.future);
      c.invalidate(platformHealthProvider);
      final stale = await c.read(platformHealthProvider.future);
      expect(stale.reach, OperatorReach.stale);

      c.invalidate(platformHealthProvider);
      final recovered = await c.read(platformHealthProvider.future);

      expect(recovered.reach, OperatorReach.complete,
          reason: 'a console that recovers must stop saying the data is old');
      expect(recovered.value!.checks.single.label, 'second',
          reason: 'recovery shows the NEW answer, not the one it was holding');
    });

    test('a second failure after recovery is stale against the NEWER reading',
        () async {
      final repo = _ScriptedRepository([
        _healthy('first'),
        _healthy('second'),
        _offline(),
      ]);
      final c = _containerFor(repo);

      await c.read(platformHealthProvider.future);
      c.invalidate(platformHealthProvider);
      await c.read(platformHealthProvider.future);
      c.invalidate(platformHealthProvider);
      final stale = await c.read(platformHealthProvider.future);

      expect(stale.reach, OperatorReach.stale);
      expect(stale.value!.checks.single.label, 'second',
          reason: 'the memory holds the LATEST good reading, not the first');
    });
  });

  group('what staleness refuses to be', () {
    test('a cold failure is unavailable, never stale', () async {
      final repo = _ScriptedRepository([_offline()]);
      final c = _containerFor(repo);

      final signal = await c.read(platformHealthProvider.future);

      expect(signal.reach, OperatorReach.unavailable,
          reason: 'there is nothing old to show, so claiming a last reading '
              'would invent a history the console never had');
      expect(signal.value, isNull);
    });

    test('an authority refusal discards what was held', () async {
      final repo = _ScriptedRepository([_healthy('first'), _refused(403)]);
      final c = _containerFor(repo);

      await c.read(platformHealthProvider.future);
      c.invalidate(platformHealthProvider);
      final refused = await c.read(platformHealthProvider.future);

      expect(refused.reach, OperatorReach.unauthorized,
          reason: 'not stale — nothing is broken and retrying changes nothing');
      expect(refused.value, isNull);
    });

    test('after a refusal, a later failure cannot resurrect the old reading',
        () async {
      final repo = _ScriptedRepository([
        _healthy('first'),
        _refused(401),
        _offline(),
      ]);
      final c = _containerFor(repo);

      await c.read(platformHealthProvider.future);
      c.invalidate(platformHealthProvider);
      await c.read(platformHealthProvider.future);
      c.invalidate(platformHealthProvider);
      final afterRefusal = await c.read(platformHealthProvider.future);

      expect(afterRefusal.reach, OperatorReach.unavailable,
          reason: 'a reading taken as one operator must never be shown to '
              'another, stale or otherwise');
    });

    test('memory does not leak between containers', () async {
      final first = _containerFor(_ScriptedRepository([_healthy('first')]));
      await first.read(platformHealthProvider.future);

      final second = _containerFor(_ScriptedRepository([_offline()]));
      final signal = await second.read(platformHealthProvider.future);

      expect(signal.reach, OperatorReach.unavailable,
          reason: 'a leaked reading would let a deliberately-failing case '
              'render a value it was never given, and pass for the wrong '
              'reason');
    });
  });

  group('the memory itself', () {
    test('recall of a never-read authority is null, not an empty reading', () {
      final memory = OperatorReadingMemory();
      expect(memory.recall<PlatformHealth>(OperatorReadingKey.health), isNull);
    });

    test('recall refuses a value of the wrong type rather than crashing', () {
      final memory = OperatorReadingMemory()
        ..remember(OperatorReadingKey.health, 'not a health payload',
            DateTime.now());
      expect(memory.recall<PlatformHealth>(OperatorReadingKey.health), isNull);
    });

    test('forget clears every authority, not just one', () {
      final memory = OperatorReadingMemory()
        ..remember(OperatorReadingKey.health, _healthy('h'), DateTime.now())
        ..remember(OperatorReadingKey.work, 'w', DateTime.now())
        ..forget();

      expect(memory.recall<PlatformHealth>(OperatorReadingKey.health), isNull);
      expect(memory.recall<String>(OperatorReadingKey.work), isNull);
    });
  });

  group('the operator is told how old it is', () {
    Future<void> pumpDisclosure(
      WidgetTester tester,
      OperatorSignal<Object?> signal,
    ) async {
      final widget = OperatorDisclosure.forSignal(signal, subject: 'health');
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: widget ?? const SizedBox())),
      );
    }

    testWidgets('a stale reading states its age, not just its staleness',
        (tester) async {
      await pumpDisclosure(
        tester,
        OperatorSignal.stale(
          const <String>[],
          readAt: DateTime.now().subtract(const Duration(minutes: 7)),
        ),
      );

      // "This is the last reading" tells an operator the value is old. It does
      // not tell them whether old means seven minutes or seven days, and those
      // lead to opposite decisions.
      expect(find.textContaining('7 minutes ago'), findsOneWidget);
      expect(find.textContaining('last reading'), findsOneWidget);
    });

    testWidgets('hours and days are said in those words', (tester) async {
      await pumpDisclosure(
        tester,
        OperatorSignal.stale(
          const <String>[],
          readAt: DateTime.now().subtract(const Duration(hours: 3)),
        ),
      );
      expect(find.textContaining('3 hours ago'), findsOneWidget);

      await pumpDisclosure(
        tester,
        OperatorSignal.stale(
          const <String>[],
          readAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
      );
      expect(find.textContaining('2 days ago'), findsOneWidget);
    });

    testWidgets('one minute is singular, because the console is read by people',
        (tester) async {
      await pumpDisclosure(
        tester,
        OperatorSignal.stale(
          const <String>[],
          readAt: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      );
      expect(find.textContaining('1 minute ago'), findsOneWidget);
    });

    testWidgets('an unknown reading time says nothing rather than implying now',
        (tester) async {
      await pumpDisclosure(tester, const OperatorSignal.stale(<String>[]));

      expect(find.textContaining('last reading'), findsOneWidget);
      expect(find.textContaining('ago'), findsNothing,
          reason: 'inventing an age would be worse than omitting one');
    });

    testWidgets('a complete reading discloses nothing at all', (tester) async {
      final widget = OperatorDisclosure.forSignal(
        OperatorSignal.complete(const <String>[], readAt: DateTime.now()),
        subject: 'health',
      );
      expect(widget, isNull,
          reason: 'the common case must cost nothing on screen');
    });
  });
}
