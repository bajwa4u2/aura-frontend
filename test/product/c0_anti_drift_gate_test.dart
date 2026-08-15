// C0 ANTI-DRIFT ARCHITECTURE GATE — FD-13 enforcement.
//
// FD-13 completion formula:
//   AUTHORITY + CONSUMER MIGRATION + ANTI-DRIFT ENFORCEMENT + REGRESSION
//   + CERTIFICATION
//
// This file is the ANTI-DRIFT ENFORCEMENT term. It is a HARD BUILD FAILURE,
// not advice: a violation fails `flutter test`.
//
// ── HOW IT WORKS ─────────────────────────────────────────────────────────────
// Two kinds of rule:
//
//   ZERO-TOLERANCE  the authority owns this completely; any occurrence fails.
//   RATCHET         a measured baseline of pre-existing sites that later
//                   chapters must burn down. The count may never RISE, and
//                   a file not in the baseline may never appear. When a count
//                   FALLS the gate also fails — so the baseline can never
//                   quietly overstate remaining debt.
//
// The ratchet exists because C0 must not mass-rewrite screens. Most remaining
// sites live inside surfaces owned by later chapters — and 15 of the 26
// surface-spinner sites are in Meetings, a PROTECTED CERTIFIED SURFACE that
// C0 is forbidden to touch for convenience. Freezing them honestly is correct;
// silently rewriting them would serve completion.
//
// Baseline data: test/product/c0_drift_baseline.txt

import 'dart:io';

import 'package:aura/core/product/product_language.dart';
import 'package:flutter_test/flutter_test.dart';

/// Files that legitimately hold the behaviour a rule governs.
const _authorityOwners = <String>{
  'lib/core/product/temporal.dart',
  'lib/core/product/product_language.dart',
  'lib/core/product/product_state.dart',
  'lib/core/product/product_state_view.dart',
  // Deprecated shim that forwards to the temporal authority. It keeps the old
  // signatures for its nine callers and holds no formatting logic of its own —
  // asserted by the 'shim holds no formatting logic' test below.
  'lib/core/utils/relative_time.dart',
  // Transport-level zone resolution (IANA id for the backend), not human
  // presentation. Reached through AuraTemporal.zoneId.
  'lib/core/utils/local_timezone.dart',
  // Declares the rendering primitives themselves; its matches are the
  // constructor declarations, not surfaces deciding state meaning locally.
  'lib/core/ui/aura_platform_components.dart',
};

final _agoLiteral = RegExp(r"""(['"])[^'"]*\bago\b[^'"]*\1""");

final _localTimeFormatter = RegExp(
  r'String\??\s+_?[A-Za-z]*'
  r'(?:format|humaniz|relative|TimeAgo|timeAgo|Ago|Elapsed|elapsed)'
  r'[A-Za-z]*\s*\(\s*(?:final\s+)?DateTime',
);

final _sizedBox = RegExp(r'SizedBox\(\s*(?:height|width)\s*:\s*(\d+)');

class _Source {
  _Source(this.path, String raw)
      : text = _stripComments(raw),
        lines = _stripComments(raw).split('\n');

  final String path;

  /// Source with comments blanked out. Every rule here governs **code**, not
  /// prose — the same principle the Product Language Authority itself holds.
  /// Without this, a doc comment explaining a rule would violate it.
  final String text;
  final List<String> lines;
}

/// Replace comment bodies with spaces, preserving offsets and line breaks.
/// String literals are respected, so `'https://…'` is not mistaken for a
/// line comment.
String _stripComments(String src) {
  final out = StringBuffer();
  var i = 0;
  String? quote;
  while (i < src.length) {
    final c = src[i];
    if (quote != null) {
      out.write(c);
      if (c == r'\' && i + 1 < src.length) {
        out.write(src[i + 1]);
        i += 2;
        continue;
      }
      if (c == quote) quote = null;
      i++;
      continue;
    }
    if (c == "'" || c == '"') {
      quote = c;
      out.write(c);
      i++;
      continue;
    }
    if (c == '/' && i + 1 < src.length && src[i + 1] == '/') {
      while (i < src.length && src[i] != '\n') {
        out.write(' ');
        i++;
      }
      continue;
    }
    if (c == '/' && i + 1 < src.length && src[i + 1] == '*') {
      while (i < src.length && !(src[i] == '*' && src[i + 1] == '/')) {
        out.write(src[i] == '\n' ? '\n' : ' ');
        i++;
      }
      out.write('  ');
      i += 2;
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

List<_Source> _libSources() {
  final dir = Directory('lib');
  if (!dir.existsSync()) {
    throw StateError(
      'The C0 gate must run from the package root; lib/ was not found. '
      'Current directory: ${Directory.current.path}',
    );
  }
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .map((f) => _Source(
            f.path.replaceAll(r'\', '/'),
            f.readAsStringSync(),
          ))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

/// Whole string literals in a file, unescaped content only.
Iterable<String> _stringLiterals(String text) sync* {
  final re = RegExp("'([^'\\\\\\n]*)'|\"([^\"\\\\\\n]*)\"");
  for (final m in re.allMatches(text)) {
    yield m.group(1) ?? m.group(2)!;
  }
}

int _countSurfaceSpinners(_Source s) {
  var count = 0;
  for (var i = 0; i < s.lines.length; i++) {
    final line = s.lines[i];
    if (!line.contains('CircularProgressIndicator')) continue;
    if (line.trimLeft().startsWith('//')) continue;
    final window =
        s.lines.sublist((i - 4).clamp(0, i), (i + 2).clamp(0, s.lines.length))
            .join('\n');
    // Inline progress is legitimately local: a thin stroke, or a small box.
    if (window.contains('strokeWidth')) continue;
    final sized = _sizedBox.firstMatch(window);
    if (sized != null && int.parse(sized.group(1)!) <= 32) continue;
    if (window.contains('Center(')) count++;
  }
  return count;
}

Map<String, Map<String, int>> _readBaseline() {
  final file = File('test/product/c0_drift_baseline.txt');
  if (!file.existsSync()) {
    throw StateError('The frozen C0 drift baseline is missing: ${file.path}');
  }
  final out = <String, Map<String, int>>{};
  for (final raw in file.readAsLinesSync()) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final parts = line.split(RegExp(r'\s+'));
    out.putIfAbsent(parts[0], () => {})[parts[2]] = int.parse(parts[1]);
  }
  return out;
}

void _ratchet(String rule, Map<String, int> actual, Map<String, int> baseline,
    String remedy) {
  final appeared = actual.keys.where((p) => !baseline.containsKey(p)).toList()
    ..sort();
  expect(
    appeared,
    isEmpty,
    reason: '\n[$rule] NEW DRIFT introduced in:\n'
        '${appeared.map((p) => '  $p').join('\n')}\n\n$remedy\n',
  );

  final rose = actual.entries
      .where((e) => baseline.containsKey(e.key) && e.value > baseline[e.key]!)
      .map((e) => '  ${e.key}: ${baseline[e.key]} -> ${e.value}')
      .toList()
    ..sort();
  expect(rose, isEmpty,
      reason: '\n[$rule] drift INCREASED in existing files:\n'
          '${rose.join('\n')}\n\n$remedy\n');

  final fell = baseline.entries
      .where((e) => (actual[e.key] ?? 0) < e.value)
      .map((e) => '  ${e.key}: ${e.value} -> ${actual[e.key] ?? 0}')
      .toList()
    ..sort();
  expect(
    fell,
    isEmpty,
    reason: '\n[$rule] drift was REDUCED (good) but the frozen baseline now '
        'overstates remaining debt:\n${fell.join('\n')}\n\n'
        'Update test/product/c0_drift_baseline.txt so the register stays '
        'truthful.\n',
  );
}

void main() {
  final sources = _libSources();
  final governed =
      sources.where((s) => !_authorityOwners.contains(s.path)).toList();
  final baseline = _readBaseline();

  group('C0 gate — Product Language (ZERO TOLERANCE)', () {
    test('no prohibited action synonym is used as a label', () {
      final prohibited = ProductLabels.prohibitedActionSynonyms;
      final violations = <String>[];
      for (final s in governed) {
        for (final literal in _stringLiterals(s.text)) {
          final canonical = prohibited[literal.trim().toLowerCase()];
          if (canonical != null) {
            violations.add(
              '  ${s.path}: "$literal" -> '
              'ProductLabels.of(ProductAction.${canonical.name})',
            );
          }
        }
      }
      expect(
        violations..sort(),
        isEmpty,
        reason: '\n[PRODUCT LANGUAGE] These words carry no meaning that '
            'a canonical action does not already own:\n'
            '${violations.join('\n')}\n\n'
            'Prose is not governed — only whole action labels are. If the '
            'phrase is part of a sentence, it will not match this rule.\n',
      );
    });

    test('Representation-backed nouns keep their canonical terms', () {
      // MINIMUM PRACTICAL CROSS-REPOSITORY ENFORCEMENT.
      //
      // Deliberately NOT a cross-repo governance platform. These are only the
      // nouns that a frozen, founder-approved Representation module actually
      // names. A later chapter renaming one of them is renaming canon, and
      // that must fail here rather than be discovered in a review.
      //
      // Sources: representation/inventory/AURA_REPRESENTATION_MODULE_INVENTORY.md
      // (frozen modules Institutional Identity, Discovery, Public Discourse,
      // Institutional Communication, Meetings & Live) and
      // representation/inventory/PRODUCT_IDENTITY_CANON.md.
      expect(ProductNoun.institution.singular, 'Institution');
      expect(ProductNoun.space.singular, 'Space'); // "Public Space Discovery"
      expect(ProductNoun.meeting.singular, 'Meeting');
      expect(ProductNoun.post.singular, 'Post'); // "Public Posts / Institution Posts"
      expect(ProductNoun.announcement.singular, 'Announcement');
      expect(ProductNoun.participant.singular, 'Participant');
      expect(ProductLabels.of(ProductAction.reply), 'Reply'); // "Replies"
    });

    test('membership operations stay distinguishable', () {
      // INSTITUTION_SPACE_MEMBERSHIP_DOCTRINE.md, founder-approved and frozen:
      // "never renaming one into the other as a shortcut fix."
      const ops = [
        ProductAction.addMember,
        ProductAction.invitePerson,
        ProductAction.manageInvites,
      ];
      final labels = ops.map(ProductLabels.of).toList();
      expect(labels.toSet().length, ops.length,
          reason: 'two membership operations render the same label');
      expect(ProductLabels.of(ProductAction.addMember), 'Add member');
      expect(ProductLabels.of(ProductAction.invitePerson), 'Invite person');
      expect(ProductLabels.of(ProductAction.manageInvites), 'Manage invites');

      // The generic action must not become a synonym for either specific one.
      expect(ProductLabels.of(ProductAction.invite),
          isNot(ProductLabels.of(ProductAction.invitePerson)));
      expect(ProductLabels.of(ProductAction.invite),
          isNot(ProductLabels.of(ProductAction.addMember)));
    });

    test('Person and Member are not flattened into one another', () {
      // Founder decision 2026-08-15: PERSON is the canonical human identity;
      // MEMBER is a contextual relationship status.
      expect(ProductNoun.person.key, isNot(ProductNoun.member.key));
      expect(ProductNoun.person.singular, 'Person');
      expect(ProductNoun.member.singular, 'Member');
      // A human is never canonically typed as "Member".
      expect(ProductNoun.person.singular, isNot('Member'));
      expect(ProductNoun.person.plural, isNot('Members'));

      // FD-11's five concepts remain five.
      expect(IdentityConcept.values.length, 5);
      expect(IdentityConcept.values.toSet().length, 5);
      expect(IdentityConcept.values, contains(IdentityConcept.presence));
      expect(IdentityConcept.values, contains(IdentityConcept.actingContext));
    });

    test('Correspondence carries exactly one canonical product meaning', () {
      // Founder decision 2026-08-15: the governed formal communication form.
      // The legacy umbrella sense (Spaces + Threads + Messages + DMs) is
      // architectural naming drift and is owned by C7.
      expect(ProductNoun.correspondence.singular, 'Correspondence');
      // If Correspondence still meant the umbrella, these would be the same
      // concept. They are not, and must never be merged.
      for (final other in [
        ProductNoun.space,
        ProductNoun.thread,
        ProductNoun.message,
      ]) {
        expect(ProductNoun.correspondence.key, isNot(other.key));
        expect(ProductNoun.correspondence.singular, isNot(other.singular));
      }
    });

    test('superseded framing language is not reintroduced', () {
      // The Discovery module's 2026-07-11 directive ("always trusted
      // discovery") is SUPERSEDED: PUBLIC_REPRESENTATION_CANON B.5 bans that
      // exact phrase, and PRODUCT_IDENTITY_CANON uses "public institution
      // directory". Narrow and reliable — one banned phrase, not a natural
      // language lint.
      final offenders = <String>[];
      for (final s in governed) {
        for (final literal in _stringLiterals(s.text)) {
          if (literal.toLowerCase().contains('trusted discovery')) {
            offenders.add('  ${s.path}: "$literal"');
          }
        }
      }
      expect(offenders..sort(), isEmpty,
          reason: '\n[REPRESENTATION] "trusted discovery" is superseded and '
              'banned as current canonical language:\n${offenders.join('\n')}\n');
    });

    test('no generic Verified label flattens layered verification', () {
      // Verification is IDENTITY / INSTITUTION_AFFILIATION / ROLE_OR_CREDENTIAL
      // and is never collapsed to a boolean. The label mapping is an OPEN C2
      // checkpoint; until it is decided, no verification vocabulary may be
      // introduced here to close the map.
      final nouns = ProductNoun.all.map((n) => n.key).toSet();
      final actions = ProductAction.values.map((a) => a.name).toSet();
      for (final banned in ['verified', 'verification', 'verify']) {
        expect(nouns.contains(banned), isFalse, reason: '$banned is a C2 decision');
        expect(actions.contains(banned), isFalse, reason: '$banned is a C2 decision');
      }
      for (final label in ProductAction.values.map(ProductLabels.of)) {
        expect(label.toLowerCase(), isNot('verified'));
      }
    });

    test('concepts with no canonical existence never enter the vocabulary', () {
      // "Connect": the lifecycle audit found ZERO matches for a Relationship or
      // Connection model anywhere in the codebase. "Works": zero matches in the
      // canonical Representation body. Neither may be introduced by a later
      // chapter reaching for a familiar social-product word.
      final nouns = ProductNoun.all.map((n) => n.key).toSet();
      expect(nouns.contains('connect'), isFalse);
      expect(nouns.contains('connection'), isFalse);
      expect(nouns.contains('works'), isFalse);
      final actions = ProductAction.values.map((a) => a.name).toSet();
      expect(actions.contains('connect'), isFalse);
    });

    test('every canonical action still resolves to exactly one label', () {
      final labels = <String, ProductAction>{};
      for (final action in ProductAction.values) {
        final label = ProductLabels.of(action);
        expect(labels.containsKey(label), isFalse,
            reason: '$action and ${labels[label]} both render "$label"');
        labels[label] = action;
      }
    });
  });

  group('C0 gate — Human Temporal (ZERO TOLERANCE)', () {
    test('the deprecated shim holds no formatting logic of its own', () {
      final shim = _stripComments(
          File('lib/core/utils/relative_time.dart').readAsStringSync());
      for (final banned in [
        'inMinutes',
        'inSeconds',
        'inHours',
        'inDays',
        'DateTime.now()',
      ]) {
        expect(
          shim.contains(banned),
          isFalse,
          reason: '\n[HUMAN TEMPORAL] relative_time.dart reintroduced "$banned". '
              'It must forward to AuraTemporal so there is exactly one '
              'implementation of humanized time.\n',
        );
      }
      expect(shim.contains('AuraTemporal'), isTrue);
    });

    test('sorting through the authority declares its event semantics', () {
      // Guards the API shape the ratchet depends on: a caller cannot obtain an
      // ordering without naming what the ordering means.
      final temporal =
          File('lib/core/product/temporal.dart').readAsStringSync();
      expect(temporal.contains('required String orderedBy'), isTrue);
    });
  });

  group('C0 gate — RATCHETS (frozen debt, owned by later chapters)', () {
    test('no new local humanized-time formatting', () {
      final actual = <String, int>{};
      for (final s in governed) {
        if (!s.text.contains('.difference(')) continue;
        final n = _agoLiteral.allMatches(s.text).length;
        if (n > 0) actual[s.path] = n;
      }
      _ratchet(
        'HUMAN TEMPORAL / local elapsed-time',
        actual,
        baseline['G2'] ?? const {},
        'Use AuraTemporal.humanize(ProductTime(instant, TimeEvent.x)) — the '
            'event semantics must travel with the instant.',
      );
    });

    test('no new local timezone conversion', () {
      final actual = <String, int>{};
      for (final s in governed) {
        final n = '.toLocal()'.allMatches(s.text).length;
        if (n > 0) actual[s.path] = n;
      }
      _ratchet(
        'HUMAN TEMPORAL / toLocal',
        actual,
        baseline['G3'] ?? const {},
        'Use ProductTime.local for presentation, or AuraTemporal.zoneId when '
            'a zone identifier must be sent or stored.',
      );
    });

    test('no new full-surface spinner outside the state authority', () {
      final actual = <String, int>{};
      for (final s in governed) {
        final n = _countSurfaceSpinners(s);
        if (n > 0) actual[s.path] = n;
      }
      _ratchet(
        'PRODUCT STATE / full-surface loading',
        actual,
        baseline['G4'] ?? const {},
        'Use AuraProductState(state: ProductState.loading). Inline progress '
            '(strokeWidth, or a box <= 32px) is legitimately local and is not '
            'matched by this rule.',
      );
    });

    test('no new direct construction of the state primitives', () {
      // AuraLoadingState / AuraEmptyState / AuraErrorState are the rendering
      // primitives the authority composes. A surface constructing them itself
      // is deciding state meaning locally — which is how the same condition
      // ended up looking like five different things.
      //
      // This ratchet exists so the authority cannot sit declared-and-unconsumed:
      // the number of surfaces bypassing it is measured and can only fall.
      final actual = <String, int>{};
      final re = RegExp(r'\bAura(?:Loading|Empty|Error)State\s*\(');
      for (final s in governed) {
        final n = re.allMatches(s.text).length;
        if (n > 0) actual[s.path] = n;
      }
      _ratchet(
        'PRODUCT STATE / direct primitive construction',
        actual,
        baseline['G5'] ?? const {},
        'Use AuraProductState(state: ProductState.x). Say what is TRUE; the '
            'authority decides what that looks like and whether recovery is '
            'an honest offer.',
      );
    });

    test('no new locally declared time formatter', () {
      final actual = <String, int>{};
      for (final s in governed) {
        final n = _localTimeFormatter.allMatches(s.text).length;
        if (n > 0) actual[s.path] = n;
      }
      _ratchet(
        'HUMAN TEMPORAL / local formatter declarations',
        actual,
        baseline['G7'] ?? const {},
        'A function that turns a DateTime into a human string belongs to the '
            'Human Temporal Presentation Authority, not to a screen.',
      );
    });
  });

  group('C0 gate — the baseline itself stays honest', () {
    test('every baselined file still exists', () {
      final missing = <String>[];
      for (final rule in baseline.values) {
        for (final path in rule.keys) {
          if (!File(path).existsSync()) missing.add(path);
        }
      }
      expect(missing.toSet().toList()..sort(), isEmpty,
          reason: '\nBaselined files were moved or deleted. Regenerate '
              'test/product/c0_drift_baseline.txt.\n');
    });

    test('the authority owner list points at real files', () {
      for (final path in _authorityOwners) {
        expect(File(path).existsSync(), isTrue, reason: '$path is missing');
      }
    });
  });
}
