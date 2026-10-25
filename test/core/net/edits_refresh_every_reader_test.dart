import 'package:aura/core/net/data_changes.dart';
import 'package:aura/core/net/reload_after_edits.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// AN EDIT IS SEEN EVERYWHERE AT ONCE (2026-10-25): founder, "this is not
/// just for post edit, its for anything you edit" -- posts, announcements,
/// articles, profiles including avatar and cover.
void main() {
  group('isEditWrite', () {
    test('changes to existing data count', () {
      expect(isEditWrite('PUT', '/posts/p1'), isTrue);
      expect(isEditWrite('PATCH', '/users/me'), isTrue);
      expect(isEditWrite('patch', '/v1/admin/announcements/a1'), isTrue);
      expect(isEditWrite('PATCH', '/articles/a1'), isTrue);
      expect(isEditWrite('PATCH', '/institutions/i1'), isTrue);
      expect(isEditWrite('DELETE', '/posts/p1'), isTrue);
      expect(isEditWrite('POST', '/meetings/m1/cancel'), isTrue);
      expect(isEditWrite('POST', '/articles/a1/restore'), isTrue);
      expect(
        isEditWrite('PATCH', 'https://api.auraplatform.org/v1/users/me'),
        isTrue,
      );
    });

    test('reads, new things and background writes do not', () {
      expect(isEditWrite('GET', '/users/me'), isFalse);
      expect(isEditWrite('POST', '/posts'), isFalse);
      expect(isEditWrite('POST', '/posts/p1/reactions'), isFalse);
      expect(isEditWrite('PUT', '/posts/draft'), isFalse);
      expect(isEditWrite('DELETE', '/posts/draft'), isFalse);
      expect(isEditWrite('PATCH', '/media/m1'), isFalse);
      expect(isEditWrite('POST', '/auth/refresh'), isFalse);
      expect(isEditWrite('PATCH', '/notifications/read'), isFalse);
    });
  });

  testWidgets('a screen holding its own data reloads once per edit burst',
      (tester) async {
    var reloads = 0;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: _HoldsItsOwnData(() => reloads++),
    ));
    container.read(dataEditEpochProvider.notifier).state++;
    container.read(dataEditEpochProvider.notifier).state++;
    await tester.pump(const Duration(milliseconds: 300));
    expect(reloads, 1);
  });

  group('EditRefreshObserver', () {
    var profileReads = 0;
    var actionRuns = 0;
    final profileProvider = FutureProvider<String>((ref) async {
      profileReads++;
      return 'name $profileReads';
    });
    final postProvider = FutureProvider.family<String, String>((ref, id) async {
      profileReads++;
      return '$id $profileReads';
    });
    final actionProvider = FutureProvider<void>((ref) async => actionRuns++);

    setUp(() {
      profileReads = 0;
      actionRuns = 0;
    });

    test('an edit makes every live reader fetch again', () async {
      final observer = EditRefreshObserver(exclude: {actionProvider});
      final container = ProviderContainer(observers: [observer]);
      addTearDown(container.dispose);

      container.listen(profileProvider, (_, __) {});
      container.listen(postProvider('p1'), (_, __) {});
      container.listen(actionProvider, (_, __) {});
      await container.read(profileProvider.future);
      await container.read(postProvider('p1').future);
      await container.read(actionProvider.future);
      expect(profileReads, 2);
      expect(actionRuns, 1);

      container.read(dataEditEpochProvider.notifier).state++;
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await container.read(profileProvider.future);
      await container.read(postProvider('p1').future);

      expect(profileReads, 4, reason: 'both readers fetched again');
      expect(actionRuns, 1, reason: 'an excluded action never repeats');
      expect(container.read(profileProvider).value, isNot('name 1'));
    });

    test('a burst of writes is one refresh', () async {
      final container =
          ProviderContainer(observers: [EditRefreshObserver()]);
      addTearDown(container.dispose);
      container.listen(profileProvider, (_, __) {});
      await container.read(profileProvider.future);

      for (var i = 0; i < 3; i++) {
        container.read(dataEditEpochProvider.notifier).state++;
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await container.read(profileProvider.future);
      expect(profileReads, 2);
    });
  });
}

/// The other half: a screen that holds its own data reloads after an edit.
class _HoldsItsOwnData extends ConsumerStatefulWidget {
  const _HoldsItsOwnData(this.onReload);
  final VoidCallback onReload;
  @override
  ConsumerState<_HoldsItsOwnData> createState() => _HoldsItsOwnDataState();
}

class _HoldsItsOwnDataState extends ConsumerState<_HoldsItsOwnData>
    with ReloadAfterEdits<_HoldsItsOwnData> {
  @override
  void reloadAfterEdits() => widget.onReload();

  @override
  void initState() {
    super.initState();
    listenForEdits();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

