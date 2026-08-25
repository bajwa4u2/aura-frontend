import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// RETURN-PATH AUDIT — THE FACTS THAT MADE IT NECESSARY, HELD IN PLACE.
///
/// Founder ruling 2026-08-25 opened the Global Navigation / Return-Path
/// chapter and explicitly forbade mass-adding back arrows before the audit was
/// finished. This is not that implementation. It is the audit's evidence,
/// written as assertions so the findings cannot quietly stop being true — in
/// either direction — while the architecture is being reviewed.
///
/// Two of these describe DEFECTS. They are asserted as the current state on
/// purpose: when the approved implementation lands, these are the tests that
/// must be rewritten, and rewriting them is the proof the defect is gone.
void main() {
  String read(String p) => File(p).readAsStringSync();

  group('the shared page surface renders no header at all', () {
    // The single largest reason screens have no visible way back: 104 of the
    // routed screens compose AuraScaffold, and AuraScaffold accepts `title`,
    // `leading`, `actions`, `centerTitle` and `showHomeAction` and draws NONE
    // of them. 18 screens pass `leading:` into it believing it appears.
    final src = read('lib/core/ui/aura_scaffold.dart');

    test('it still accepts the header arguments', () {
      for (final arg in ['title', 'leading', 'actions', 'showHomeAction']) {
        expect(src, contains('this.$arg'),
            reason: 'AuraScaffold no longer takes $arg — re-run the audit');
      }
    });

    test('CURRENT DEFECT: it renders none of them', () {
      // If this ever fails, AuraScaffold has grown a header. That is the
      // intended fix — update this test rather than reverting the change.
      final build = src.substring(src.indexOf('Widget build('));
      expect(build.contains('leading'), isFalse,
          reason: 'AuraScaffold now uses leading — the audit finding is stale');
      expect(build.contains('AppBar('), isFalse,
          reason: 'AuraScaffold now builds an AppBar — finding is stale');
    });
  });

  group('no shell offers a return affordance', () {
    // A shell is the one place a fix could reach every screen it frames. None
    // of the five draws a back control today; the only pops in them close the
    // drawer.
    const shells = [
      'lib/app/app_shell.dart',
      'lib/app/shell/member_shell.dart',
      'lib/app/shell/admin_shell.dart',
      'lib/app/shell/public_shell.dart',
      'lib/app/shell/global_platform_shell.dart',
    ];

    test('CURRENT DEFECT: none of the shells renders a back control', () {
      for (final f in shells) {
        final src = read(f);
        expect(src.contains('Icons.arrow_back'), isFalse,
            reason: '$f now renders a back control — the audit finding is '
                'stale, re-run the census');
      }
    });
  });

  group('the shared return control exists and is almost entirely unused', () {
    test('InstitutionPage can draw one', () {
      final src = read('lib/features/institutions/presentation/institution_page.dart');
      expect(src, contains('showBack'));
      expect(src, contains('Icons.arrow_back_rounded'));
      // Unguarded: on a deep-link entry there is nothing to pop.
      expect(src, contains('context.pop()'));
    });

    test('exactly ONE screen outside Meetings opts in', () {
      // The split matters more than the total. GuestShell's own
      // `showBackButton` IS adopted — 14 times, every one of them a Meetings
      // guest surface. So the product does have a working return pattern; it
      // lives in the protected domain and nowhere else.
      var institutionPage = 0;
      var guestShell = 0;
      final guestShellFiles = <String>{};
      for (final f in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final src = f.readAsStringSync();
        institutionPage +=
            RegExp(r'showBack:\s*true').allMatches(src).length;
        final g = RegExp(r'showBackButton:\s*true').allMatches(src).length;
        guestShell += g;
        if (g > 0) guestShellFiles.add(f.path.replaceAll(r'\', '/'));
      }
      expect(institutionPage, 1,
          reason: 'InstitutionPage showBack adoption changed — re-run census');
      expect(guestShell, 14,
          reason: 'GuestShell showBackButton adoption changed — re-run census');
      expect(
        guestShellFiles.every((p) => p.contains('/meetings/')),
        isTrue,
        reason: 'GuestShell back adoption has spread outside Meetings — the '
            'audit finding that it is confined there is stale',
      );
    });
  });

  group('the product navigates by REPLACING the stack', () {
    // The mechanical half of the defect, and the reason "just add an arrow"
    // would not fix it: after context.go there is no predecessor for a back
    // control — or for Android system back — to unwind to.
    test('CURRENT DEFECT: go() call sites outnumber push()', () {
      var go = 0;
      var push = 0;
      for (final f in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final src = f.readAsStringSync();
        go += RegExp(r"context\.go\(").allMatches(src).length;
        push += RegExp(r"context\.push\(").allMatches(src).length;
      }
      expect(go, greaterThan(push),
          reason: 'go() no longer dominates — the audit finding is stale');
    });
  });

  test('the census evidence is committed alongside these assertions', () {
    // A count in a report nobody can re-derive is an anecdote.
    for (final f in [
      'docs/navigation/return_path_census.csv',
      'docs/navigation/return_path_surfaces.csv',
      'docs/navigation/return_path_census.json',
    ]) {
      expect(File(f).existsSync(), isTrue, reason: '$f is missing');
    }
    final csv = read('docs/navigation/return_path_census.csv');
    // Header + one row per registered route.
    expect(csv.trim().split('\n').length, 176,
        reason: 'the census no longer covers exactly 175 registered routes');
  });
}
