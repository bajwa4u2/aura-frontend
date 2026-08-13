import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aura/features/realtime/data/orphaned_session_dismissal_cache.dart';

// Runtime Lifecycle / Attention Coherence fix — the founder-observed defect
// was dismissal living only in the banner's ephemeral State, so it was
// forgotten on every reload/relaunch. These tests prove the persistence
// layer that fixes it: per-session, survives a fresh read, and self-prunes
// once a session is no longer reported active.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('OrphanedSessionDismissalCache', () {
    test('read returns empty set when nothing has ever been dismissed', () async {
      expect(await OrphanedSessionDismissalCache.read(), isEmpty);
    });

    test('a dismissed session id survives a fresh read (simulating reload)', () async {
      await OrphanedSessionDismissalCache.markDismissed(
        's1',
        stillActiveIds: {'s1'},
      );

      expect(await OrphanedSessionDismissalCache.read(), {'s1'});
    });

    test('dismissing a second session preserves the first', () async {
      await OrphanedSessionDismissalCache.markDismissed(
        's1',
        stillActiveIds: {'s1', 's2'},
      );
      await OrphanedSessionDismissalCache.markDismissed(
        's2',
        stillActiveIds: {'s1', 's2'},
      );

      expect(await OrphanedSessionDismissalCache.read(), {'s1', 's2'});
    });

    test('a previously dismissed session that is no longer active is pruned on the next write', () async {
      await OrphanedSessionDismissalCache.markDismissed(
        's1',
        stillActiveIds: {'s1'},
      );
      // s1 has since ended and no longer appears in mySessions; dismissing
      // a new, unrelated session should prune the stale s1 marker rather
      // than let the stored set grow forever.
      await OrphanedSessionDismissalCache.markDismissed(
        's2',
        stillActiveIds: {'s2'},
      );

      expect(await OrphanedSessionDismissalCache.read(), {'s2'});
    });

    test('an empty/blank session id is a no-op', () async {
      await OrphanedSessionDismissalCache.markDismissed('  ', stillActiveIds: {});
      expect(await OrphanedSessionDismissalCache.read(), isEmpty);
    });
  });
}
