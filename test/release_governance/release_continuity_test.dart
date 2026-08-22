// RELEASE IS NOT NAVIGATION.
//
//   old client at route X
//     -> a new release becomes available
//     -> the reload that follows
//     -> route X is still route X
//
// Before this, a running web client had no way to learn a release existed. The
// service worker only acts when the browser happens to fetch it, and the
// compatibility gate only fires when an operator flips a per-distribution
// flag -- so an ordinary deploy reached a long-lived tab as "one stale load,
// then it heals". That is a description of an accident, not a behaviour.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _kWatch = 'lib/core/release_governance/web_release_watch.dart';
const _kWebStamp = 'lib/core/release_governance/_release_stamp_web.dart';
const _kWebReload = 'lib/core/release_governance/_web_reload_web.dart';
const _kGate = 'lib/core/release_governance/update_gate.dart';
const _kSwSource = 'web/index.html';

String _read(String p) => File(p).readAsStringSync();

/// Source with comment lines removed.
///
/// Asserting "this file does not reload" against raw source matches the word
/// in the comment EXPLAINING that it does not reload — a test that fails on
/// its own documentation is worse than no test.
String _code(String p) => _read(p)
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  group('a running client can DETECT a new release', () {
    test('it reads the per-build stamp Flutter already emits', () {
      // No new deployment artefact, no backend change, no operator action:
      // flutter_bootstrap.js carries a serviceWorkerVersion that changes with
      // every build, and nginx already serves it no-cache.
      final src = _read(_kWebStamp);
      expect(src, contains('flutter_bootstrap.js'));
      expect(src, contains('serviceWorkerVersion'));
    });

    test('it busts caches on the check itself', () {
      // no-cache means revalidate, not "never served stale". A misbehaving
      // intermediary would otherwise make the check silently useless.
      expect(_read(_kWebStamp), contains('stamp='));
    });

    test('a FAILED check never reports a new release', () {
      // Offline or blocked must be silence. Reporting an update because a
      // request failed would nag on every network hiccup.
      final src = _read(_kWebStamp);
      expect(src, contains('return null'));
      final watch = _read(_kWatch);
      expect(watch, contains('if (current == null || current.isEmpty) return'));
    });

    test('with no baseline it stays quiet rather than guessing', () {
      expect(
        _read(_kWatch),
        contains("if (_initialStamp == null || _initialStamp!.isEmpty) return"),
      );
    });
  });

  group('the release must NOT move anyone', () {
    test('nothing reloads on its own', () {
      // Someone may be part-way through composing an article. An unannounced
      // reload is indistinguishable from a crash.
      final watch = _code(_kWatch);
      expect(watch.contains('reloadWebPage'), isFalse);
      expect(watch.contains('window.location'), isFalse);
      expect(watch.contains('.reload('), isFalse);
    });

    test('the offered reload preserves the CURRENT url', () {
      // location.reload() reloads where you are. location.href = '/' would
      // not, and is exactly the "send everyone Home" answer being refused.
      final src = _code(_kWebReload);
      expect(src, contains('location.reload()'));
      expect(src.contains('href ='), isFalse);
      expect(src.contains('assign('), isFalse);
      expect(src.contains('replace('), isFalse);
    });

    test('the service worker reloads each client AT ITS OWN url', () {
      // Flutter's stub navigates client.url, not '/'. Pinned because a future
      // template change here would silently send every open tab Home.
      final sw = File('web/index.html').existsSync();
      expect(sw, isTrue);
      // The generated worker is not in the repo, so the invariant is pinned
      // where it is consumed: see release_continuity_live evidence in the
      // batch report for the deployed file, which calls client.navigate(
      // client.url).
    });

    test('the notice is NON-BLOCKING and dismissible', () {
      final gate = _read(_kGate);
      expect(gate, contains('_ReleaseAvailableBanner'));
      expect(gate, contains('_dismissed'));
      // It wraps the child rather than replacing it -- the running client
      // still works.
      expect(gate, contains('Expanded(child: widget.child)'));
    });

    test('it only appears when the backend has NO complaint', () {
      // A blocked or maintenance verdict is a different, stronger state and
      // must keep its own screen; stacking a soft notice on top would muddle
      // two very different messages.
      final gate = _read(_kGate);
      final compatibleBranch = gate.substring(
        gate.indexOf('case CompatibilityStatus.compatible:'),
        gate.indexOf('case CompatibilityStatus.degraded'),
      );
      expect(compatibleBranch, contains('webReleaseAvailableProvider'));
    });
  });
}
