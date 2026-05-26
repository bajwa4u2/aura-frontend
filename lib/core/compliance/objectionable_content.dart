/// Client mirror of the backend `objectionable-content.ts` filter.
///
/// Apple Store §1.2 UGC compliance — running the same first-pass
/// rule on the client gives the user an instant message before the
/// network round-trip. The backend remains authoritative (it runs
/// the same rule on every publish/reply); this client copy is
/// purely a UX courtesy. The two lists must stay in sync — when
/// the backend's list bumps, copy the changes here.
///
/// Keep this list intentionally curated. Apple's bar is "the
/// developer is enforcing community standards"; deep moderation
/// belongs to the human review queue, not a regex.
library;

const List<String> _kCanonicalTerms = <String>[
  // Slurs (explicit, non-reclaimed contexts).
  'nigger',
  'nigga',
  'chink',
  'kike',
  'spic',
  'wetback',
  'gook',
  'paki',
  'raghead',
  'towelhead',
  'cunt',
  'faggot',
  'tranny',
  'dyke',
  // CSAM-adjacent.
  'pedo',
  'pedophile',
  'cp porn',
  'child porn',
  'kiddie porn',
  'underage sex',
  'lolicon',
  // Direct threats.
  'i will kill you',
  "i'll kill you",
  'kill yourself',
  'kys',
  'go die',
  'you should die',
  // Doxxing.
  'dox you',
  'doxx you',
];

final List<RegExp> _kRegexes = _kCanonicalTerms.map((term) {
  final escaped = term.replaceAllMapped(
    RegExp(r'[.*+?^${}()|[\]\\]'),
    (m) => '\\${m.group(0)}',
  );
  if (term.contains(' ')) {
    return RegExp(escaped.replaceAll(r'\ ', r'\s+'), caseSensitive: false);
  }
  return RegExp(
    '(^|[^\\p{L}])$escaped([^\\p{L}]|\$)',
    caseSensitive: false,
    unicode: true,
  );
}).toList();

class ObjectionableContentMatch {
  const ObjectionableContentMatch(this.term);
  final String term;
}

/// Returns non-null when [text] contains an objectionable term. The
/// caller surfaces the standard rejection message to the user; the
/// matched term is intentionally not shown back.
ObjectionableContentMatch? scanForObjectionableContent(String text) {
  if (text.isEmpty) return null;
  final lower = text.toLowerCase();
  for (var i = 0; i < _kRegexes.length; i++) {
    if (_kRegexes[i].hasMatch(lower)) {
      return ObjectionableContentMatch(_kCanonicalTerms[i]);
    }
  }
  return null;
}

/// Standard user-facing rejection message. Mirrors the backend
/// constant of the same intent.
const String kObjectionableContentMessage =
    'Your post contains content that may violate our community standards. Please revise and try again.';
