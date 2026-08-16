import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/navigation/navigation_authority.dart';

/// C3 — ROUTE INTEGRITY GATE + LITERAL RATCHET (hard build failure).
///
/// The Navigation Authority owns destination grammar. Feature code still
/// contains historical route literals; this gate makes them SAFE and
/// FROZEN until their owning surfaces migrate:
///
///  1. INTEGRITY — every feature-level navigation literal must resolve
///     against the router's declared route table (parameters wildcarded)
///     or be an explicitly classified exception. Navigating to a retired
///     or misspelled address fails the build — the declared table is the
///     registry, enforced (FD-12 §8).
///  2. RATCHET — per-file literal counts may not RISE (no new scattered
///     grammar; new code uses the authority) and falls must be recorded
///     (the register stays truthful).
void main() {
  final routerSrc = File('lib/router.dart').readAsStringSync();

  // Declared route patterns from the router (single source of truth) —
  // both literal `path: '...'` and constant-declared `path: kName` forms.
  final constants = <String, String>{
    for (final m in RegExp(r"const String (k\w+) =[\s\r\n]*'([^']+)'")
        .allMatches(routerSrc))
      m.group(1)!: m.group(2)!,
  };
  String substituteConstants(String raw) {
    var out = raw;
    constants.forEach((name, value) {
      out = out.replaceAll('\$$name', value);
    });
    return out;
  }

  final declared = <String>{
    ...RegExp(r"path:\s*'([^']+)'")
        .allMatches(routerSrc)
        .map((m) => substituteConstants(m.group(1)!)),
    ...RegExp(r"path:\s*(k\w+)")
        .allMatches(routerSrc)
        .map((m) => constants[m.group(1)!])
        .whereType<String>(),
  };

  // GoRouter nests paths; a feature literal is valid when its segments
  // match a declared ABSOLUTE pattern. Nested relative patterns are rare
  // in this router (absolute paths are used); treat non-absolute declared
  // entries as suffixes appended to their parents — conservatively, also
  // accept a literal when any declared pattern matches segment-wise.
  bool segmentsMatch(List<String> pat, List<String> lit) {
    if (pat.length != lit.length) return false;
    for (var i = 0; i < pat.length; i++) {
      final p = pat[i];
      if (p.startsWith(':')) continue; // route parameter
      if (lit[i] == '*') continue; // interpolated segment
      if (p != lit[i]) return false;
    }
    return true;
  }

  bool resolves(String literal) {
    var lit = literal;
    final q = lit.indexOf('?');
    if (q >= 0) lit = lit.substring(0, q);
    if (lit.isEmpty || lit == '/') return true;
    final litSegs = lit.split('/').where((s) => s.isNotEmpty).toList();
    for (final d in declared) {
      if (!d.startsWith('/')) continue;
      final patSegs = d.split('/').where((s) => s.isNotEmpty).toList();
      if (segmentsMatch(patSegs, litSegs)) return true;
    }
    return false;
  }

  // Feature literals: context.go/push('...') outside the router.
  final literalRe = RegExp(r"context\.(?:go|push)\(\s*'([^']*)'");
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) =>
          f.path.endsWith('.dart') &&
          !f.path.replaceAll('\\', '/').endsWith('lib/router.dart'))
      .toList();

  final perFile = <String, List<String>>{};
  for (final f in files) {
    final src = f.readAsStringSync();
    final path = f.path.replaceAll('\\', '/');
    for (final m in literalRe.allMatches(src)) {
      var lit = m.group(1)!;
      if (!lit.startsWith('/')) continue; // external / relative / dynamic
      // Wildcard Dart interpolations: ${...} and $identifier become '*'
      // for one path segment.
      lit = lit
          .replaceAll(RegExp(r'\$\{[^}]*\}'), '*')
          .replaceAll(RegExp(r'\$[A-Za-z_][A-Za-z0-9_.]*'), '*');
      (perFile[path] ??= []).add(lit);
    }
  }

  test('every feature navigation literal resolves against the declared route table',
      () {
    final violations = <String>[];
    perFile.forEach((file, lits) {
      for (final lit in lits) {
        if (!resolves(lit)) violations.add('$file → $lit');
      }
    });
    expect(
      violations,
      isEmpty,
      reason: '[C3 ROUTE INTEGRITY] Feature code navigates to addresses the '
          'router does not declare (retired, moved, or misspelled). Use the '
          'Navigation Authority builders, or fix the address:\n  ' +
          violations.join('\n  '),
    );
  });

  test(
      'AUTHORITY-DECLARED DESTINATIONS ARE EXECUTABLE — every primary and '
      'every route the Navigation Authority can emit exists in the router',
      () {
    // Founder-observed correction pin (2026-08-16). The original gate only
    // validated inline `context.go/push('...')` literals, so a destination
    // declared BY THE AUTHORITY ITSELF (the since-removed Meetings primary
    // → '/meetings') shipped with no executable route behind it: nav items
    // navigate via `context.go(item.path)` — a variable, invisible to the
    // literal scan. The certification tested registry SELF-consistency,
    // never registry → router EXECUTABILITY. This test closes that class
    // for the current four primaries and every future one: any address
    // the authority declares or builds must resolve against the declared
    // route table, or the build fails.
    final authorityAddresses = <String>[
      // Every primary, authenticated and public.
      for (final d in NavigationAuthority.authenticatedPrimaries) d.route,
      for (final d in NavigationAuthority.publicPrimaries) d.route,
      // The canonical global actions.
      NavigationAuthority.institutionOnboardingRoute,
      NavigationAuthority.newConversationRoute,
      NavigationAuthority.inviteHubRoute,
      NavigationAuthority.conversationRoute('*'),
      // Every object route builder, with representative arguments
      // (wildcarded like feature literals so parameters match).
      NavigationAuthority.personRoute('*'),
      NavigationAuthority.institutionRoute('*'),
      NavigationAuthority.threadRoute('*'),
      NavigationAuthority.directThreadRoute('*'),
      NavigationAuthority.postRoute('*'),
      NavigationAuthority.messagesRoute,
      NavigationAuthority.createRoute,
      NavigationAuthority.realtimeSessionRoute('*'),
      NavigationAuthority.articleRoute('*'),
      NavigationAuthority.articleEditorRoute('*'),
    ];
    final unbacked = <String>[
      for (final a in authorityAddresses)
        if (!resolves(a)) a,
    ];
    expect(
      unbacked,
      isEmpty,
      reason: '[C3 PRIMARY EXECUTABILITY] The Navigation Authority declares '
          'destinations the router does not implement — this is exactly the '
          'defect that shipped "/meetings → Route not found" to production. '
          'Every declared destination must have an executable route:\n  ' +
          unbacked.join('\n  '),
    );
    // Meetings is an institutional domain (founder ruling 2026-08-16):
    // there must be NO bare personal `/meetings` destination — the old
    // primary is gone and no landing page may be manufactured for it.
    expect(declared, isNot(contains('/meetings')),
        reason: 'A bare /meetings destination re-appeared — meetings are '
            'institution-owned; personal relationships are contextual.');
  });

  test('route-literal ratchet — no new scattered navigation grammar', () {
    final baselineFile = File('test/navigation/c3_route_literal_baseline.txt');
    expect(baselineFile.existsSync(), isTrue,
        reason: 'baseline missing — create it from current counts');
    final baseline = <String, int>{};
    for (final line in baselineFile.readAsLinesSync()) {
      final t = line.trim();
      if (t.isEmpty || t.startsWith('#')) continue;
      final idx = t.indexOf(' ');
      baseline[t.substring(idx + 1).trim()] = int.parse(t.substring(0, idx));
    }

    final rises = <String>[];
    final falls = <String>[];
    final current = <String, int>{
      for (final e in perFile.entries) e.key: e.value.length,
    };
    current.forEach((file, n) {
      final base = baseline[file] ?? 0;
      if (n > base) rises.add('$file: $base -> $n');
      if (n < base) falls.add('$file: $base -> $n');
    });
    baseline.forEach((file, base) {
      if (!current.containsKey(file) && base > 0) {
        falls.add('$file: $base -> 0');
      }
    });

    expect(rises, isEmpty,
        reason: '[C3 LITERAL RATCHET] NEW route literals — new code must use '
            'the Navigation Authority:\n  ' +
            rises.join('\n  '));
    expect(falls, isEmpty,
        reason: '[C3 LITERAL RATCHET] literals were REDUCED (good) — record '
            'the burn-down in c3_route_literal_baseline.txt:\n  ' +
            falls.join('\n  '));
  });

  test('DR4 — retired mirror addresses stay alias-resolvable, never buildable',
      () {
    // The two retired mirrors must remain DECLARED (alias redirects) so
    // old links resolve…
    expect(declared, contains('/institution/:institutionId/u/:handle'));
    expect(declared,
        contains('/institution/:institutionId/institutions/:slug'));
    // …but no feature code may navigate TO them anymore.
    perFile.forEach((file, lits) {
      for (final lit in lits) {
        expect(
          RegExp(r'^/institution/[^/]+/(u|institutions)/').hasMatch(lit),
          isFalse,
          reason: '$file navigates to a retired mirror: $lit',
        );
      }
    });
  });
}
