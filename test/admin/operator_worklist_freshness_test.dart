import 'package:aura/features/admin/data/admin_providers.dart';
import 'package:aura/features/admin/data/operator_work.dart';
import 'package:aura/features/admin/domain/operator_signal.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// THE LIST MUST NOT DISAGREE WITH THE SUMMARY ABOVE IT.
///
/// WORK shows per-source counts and, beneath them, the worklist those counts
/// describe. Once the summary survived a failed refresh as a stale reading and
/// the list did not, the area showed counts from a minute ago above an empty
/// list — which reads as "the queues emptied", not as "we could not re-ask".
/// Two halves of one screen were telling an operator different things about the
/// same authority.
///
/// These tests hold the list to the same semantics, and hold the two things
/// that make a filtered list different from a summary: a stale answer may only
/// ever come from the same question, and PARTIAL must not become a sticky label
/// once the missing source comes back.
class _ScriptedWorkRepository implements OperatorWorkRepository {
  _ScriptedWorkRepository(this._answers);

  final List<Object> _answers;
  final List<String?> askedFor = [];
  int calls = 0;

  @override
  Future<OperatorWorklist> list({String? source, int? limit}) async {
    askedFor.add(source);
    final answer =
        _answers[calls < _answers.length ? calls : _answers.length - 1];
    calls++;
    if (answer is OperatorWorklist) return answer;
    throw answer;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

OperatorWorkItem _item(String id) => OperatorWorkItem(
      key: 'MODERATION:$id',
      source: 'MODERATION',
      sourceLabel: 'Moderation',
      id: id,
      title: 'Report $id',
      state: 'OPEN',
      openedAt: DateTime.utc(2026, 8, 30),
      ageDays: 2,
      destination: '/admin/integrity/moderation/$id',
      subjectKind: WorkSubjectKind.person,
    );

OperatorWorklist _complete(List<String> ids) => OperatorWorklist(
      items: [for (final id in ids) _item(id)],
      missingSources: const [],
      complete: true,
    );

OperatorWorklist _partial(List<String> ids, List<String> missing) =>
    OperatorWorklist(
      items: [for (final id in ids) _item(id)],
      missingSources: missing,
      complete: false,
    );

DioException _offline() => DioException(
      requestOptions: RequestOptions(path: '/admin/work'),
      type: DioExceptionType.connectionError,
    );

DioException _refused(int code) => DioException(
      requestOptions: RequestOptions(path: '/admin/work'),
      response: Response(
        requestOptions: RequestOptions(path: '/admin/work'),
        statusCode: code,
      ),
    );

ProviderContainer _containerFor(_ScriptedWorkRepository repo) {
  final c = ProviderContainer(
    overrides: [operatorWorkRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('the list survives a failed refresh, like its summary', () {
    test('a held list is shown as stale rather than lost', () async {
      final repo = _ScriptedWorkRepository([
        _complete(['a', 'b']),
        _offline(),
      ]);
      final c = _containerFor(repo);

      final first = await c.read(operatorWorkListProvider.future);
      expect(first.reach, OperatorReach.complete);
      expect(first.value!.items, hasLength(2));

      c.invalidate(operatorWorkListProvider);
      final second = await c.read(operatorWorkListProvider.future);

      expect(second.reach, OperatorReach.stale);
      expect(second.value!.items, hasLength(2),
          reason: 'the operator keeps the work they could already see');
      expect(second.readAt, first.readAt,
          reason: 'the age belongs to the reading, not to the failure');
    });

    test('cold into a failure is unavailable, not an empty worklist', () async {
      final c = _containerFor(_ScriptedWorkRepository([_offline()]));
      final signal = await c.read(operatorWorkListProvider.future);

      expect(signal.reach, OperatorReach.unavailable);
      expect(signal.value, isNull,
          reason: 'an empty list would say the queues are clear');
    });

    test('an authority refusal discards the held list', () async {
      final repo = _ScriptedWorkRepository([
        _complete(['a']),
        _refused(403),
        _offline(),
      ]);
      final c = _containerFor(repo);

      await c.read(operatorWorkListProvider.future);
      c.invalidate(operatorWorkListProvider);
      final refused = await c.read(operatorWorkListProvider.future);
      expect(refused.reach, OperatorReach.unauthorized);

      c.invalidate(operatorWorkListProvider);
      final after = await c.read(operatorWorkListProvider.future);
      expect(after.reach, OperatorReach.unavailable,
          reason: 'work visible to one operator must never resurface for '
              'another as a stale reading');
    });
  });

  group('a stale answer only ever comes from the same question', () {
    test('a filtered failure never answers with the unfiltered list', () async {
      // Read everything successfully, then filter to a queue and fail.
      final repo = _ScriptedWorkRepository([
        _complete(['a', 'b', 'c']),
        _offline(),
      ]);
      final c = _containerFor(repo);

      await c.read(operatorWorkListProvider.future);
      expect(repo.askedFor, [null]);

      c.read(operatorWorkFilterProvider.notifier).state = 'MODERATION';
      final filtered = await c.read(operatorWorkListProvider.future);

      expect(repo.askedFor, [null, 'MODERATION']);
      expect(filtered.reach, OperatorReach.unavailable,
          reason: 'the unfiltered reading answers a different question — '
              'showing it here would present other queues as this one');
      expect(filtered.value, isNull);
    });

    test('each filter keeps its own held reading', () async {
      final repo = _ScriptedWorkRepository([
        _complete(['a', 'b', 'c']), // unfiltered
        _complete(['m']), //            MODERATION
        _offline(), //                  MODERATION refresh fails
      ]);
      final c = _containerFor(repo);

      await c.read(operatorWorkListProvider.future);

      c.read(operatorWorkFilterProvider.notifier).state = 'MODERATION';
      await c.read(operatorWorkListProvider.future);

      c.invalidate(operatorWorkListProvider);
      final stale = await c.read(operatorWorkListProvider.future);

      expect(stale.reach, OperatorReach.stale);
      expect(stale.value!.items, hasLength(1),
          reason: "the queue's own last reading, not everything");
      expect(stale.value!.items.single.id, 'm');
    });
  });

  group('PARTIAL is a reading, not a label that sticks', () {
    test('PARTIAL becomes READY once the missing source answers', () async {
      final repo = _ScriptedWorkRepository([
        _partial(['a'], ['SUPPORT']),
        _complete(['a', 's']),
      ]);
      final c = _containerFor(repo);

      final partial = await c.read(operatorWorkListProvider.future);
      expect(partial.reach, OperatorReach.partial);
      expect(partial.missing, isNotEmpty,
          reason: 'a partial total shown as a total is the most dangerous '
              'state in an operator console');

      c.invalidate(operatorWorkListProvider);
      final recovered = await c.read(operatorWorkListProvider.future);

      expect(recovered.reach, OperatorReach.complete,
          reason: 'the source came back, so the disclosure must go');
      expect(recovered.missing, isEmpty);
      expect(recovered.value!.items, hasLength(2));
    });

    test('READY is never fabricated — a still-missing source stays PARTIAL',
        () async {
      final repo = _ScriptedWorkRepository([
        _partial(['a'], ['SUPPORT']),
        _partial(['a'], ['SUPPORT']),
      ]);
      final c = _containerFor(repo);

      await c.read(operatorWorkListProvider.future);
      c.invalidate(operatorWorkListProvider);
      final again = await c.read(operatorWorkListProvider.future);

      expect(again.reach, OperatorReach.partial);
      expect(again.missing, isNotEmpty);
    });

    test('a PARTIAL reading is held, and survives a later total failure',
        () async {
      final repo = _ScriptedWorkRepository([
        _partial(['a'], ['SUPPORT']),
        _offline(),
      ]);
      final c = _containerFor(repo);

      await c.read(operatorWorkListProvider.future);
      c.invalidate(operatorWorkListProvider);
      final stale = await c.read(operatorWorkListProvider.future);

      expect(stale.reach, OperatorReach.stale,
          reason: 'half a worklist is a better thing to hold than nothing');
      expect(stale.value!.items, hasLength(1));
      expect(stale.value!.complete, isFalse,
          reason: 'what was held was partial, and it is still partial — the '
              'stale reading must not quietly promote itself to whole');
    });

    test('PARTIAL then STALE then READY ends genuinely current', () async {
      final repo = _ScriptedWorkRepository([
        _partial(['a'], ['SUPPORT']),
        _offline(),
        _complete(['a', 's']),
      ]);
      final c = _containerFor(repo);

      await c.read(operatorWorkListProvider.future);
      c.invalidate(operatorWorkListProvider);
      expect((await c.read(operatorWorkListProvider.future)).reach,
          OperatorReach.stale);

      c.invalidate(operatorWorkListProvider);
      final ready = await c.read(operatorWorkListProvider.future);

      expect(ready.reach, OperatorReach.complete);
      expect(ready.missing, isEmpty);
      expect(ready.value!.items, hasLength(2));
      expect(ready.readAt, isNotNull,
          reason: 'a recovered reading is a new reading, with a new time');
    });
  });
}
