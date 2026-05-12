// Post-build: generate route-aware index.html variants for the Aura
// web bundle.
//
// Why this exists
// ---------------
// Aura is a Flutter Web SPA. Nginx serves it with a blind SPA fallback
// (`try_files $uri $uri/ /index.html`), which means every public route
// — `/investors`, `/mission`, `/founder`, … — receives the same root
// `index.html` and therefore the same OG / Twitter tags. Crawlers do
// NOT execute Flutter, so route-specific social previews are
// impossible without crawler-visible per-route HTML.
//
// What it does
// ------------
// 1. Reads `build/web/index.html` (the canonical metadata foundation,
//    sourced from `web/index.html`).
// 2. For each route in `_routes`, clones the file into
//    `build/web/<route>/index.html` with the tags marked
//    `data-aura-meta="…"` rewritten to the route-specific values.
// 3. The existing nginx try_files directive picks those directory
//    indexes up before falling back to root /index.html.
//
// What it deliberately does NOT do
// --------------------------------
// - Modify any Flutter code, router, runtime server, Dockerfile beyond
//   one extra build step, or nginx config.
// - Touch authenticated routes; only public marketing surfaces.
// - Generate metadata for dynamic public routes such as `/u/:handle`
//   or `/posts/:id`. Those would require backend cooperation (server-
//   side rendering with database lookups); they fall back to the root
//   metadata for now, which is intentional.

import 'dart:io';

const _outputRoot = 'build/web';

/// Substitution map keyed by `data-aura-meta` attribute value. Keys
/// MUST match the `data-aura-meta` markers in `web/index.html`.
class _RouteMeta {
  const _RouteMeta({
    required this.path,
    required this.title,
    required this.description,
    this.image = 'og-default.png',
    String? imageAlt,
  }) : imageAlt = imageAlt ?? 'Aura Platform — accountable communication infrastructure';

  final String path; // e.g. '/investors' — must start with '/' and not end with '/'
  final String title;
  final String description;
  final String image; // file under /social/
  final String imageAlt;

  String get canonicalUrl => 'https://auraplatform.org$path';
  String get imageUrl => 'https://auraplatform.org/social/$image';
}

/// Canonical positioning copy. Sourced from:
/// - aura_final/lib/screens/mission_screen.dart
/// - aura_final/lib/screens/investors_hub_screen.dart
/// - aura_final/lib/screens/founder_message_screen.dart
/// - aura_final/lib/screens/patrons_hub_screen.dart
/// - aura_final/lib/screens/supporters_hub_screen.dart
/// - aura_final/docs/business_deck/README.md
const _routes = <_RouteMeta>[
  _RouteMeta(
    path: '/mission',
    title: 'Mission — Aura Platform LLC',
    description:
        'Build durable systems for communication, coordination, and execution in the AI era. Identity, accountability, continuity, human authority, operational memory.',
    image: 'og-mission.png',
    imageAlt: 'Aura Platform LLC — mission',
  ),
  _RouteMeta(
    path: '/investors',
    title: 'Investors & Partners — Aura Platform LLC',
    description:
        'Aura Platform LLC builds infrastructure for accountable communication and AI-assisted operational execution. Trust, action, records — one identity, one record, one accountable surface.',
    image: 'og-investors.png',
    imageAlt: 'Aura Platform LLC — investors and partners',
  ),
  _RouteMeta(
    path: '/founder',
    title: 'Founder — Aura Platform LLC',
    description:
        'Aura Platform LLC is being built by an operator-builder focused on accountable communication, operational execution, and durable systems.',
    image: 'og-founder.png',
    imageAlt: 'Aura Platform LLC — founder',
  ),
  _RouteMeta(
    path: '/supporters',
    title: 'Supporters — Aura Platform LLC',
    description:
        'Supporters help Aura Platform improve through attention, testing, feedback, and responsible participation.',
  ),
  _RouteMeta(
    path: '/patrons',
    title: 'Patrons — Aura Platform LLC',
    description:
        'Patrons provide ongoing support for the development of durable communication and operational infrastructure.',
  ),
  _RouteMeta(
    path: '/institutions',
    title: 'Institutions — Aura Platform',
    description:
        'Verified institutions on Aura. Public directory of organizations speaking under identity-bound, accountable communication.',
  ),
  _RouteMeta(
    path: '/white-paper',
    title: 'White Paper — Aura Platform',
    description:
        'How Aura keeps identity, authority, and outcomes connected across public discourse and institutional communication.',
  ),
  _RouteMeta(
    path: '/contact',
    title: 'Contact — Aura Platform LLC',
    description:
        'Contact Aura Platform LLC. Operator, investor, partnership, and institution outreach.',
  ),
  _RouteMeta(
    path: '/privacy',
    title: 'Privacy — Aura Platform',
    description:
        'How Aura handles your data, identity, and records.',
  ),
  _RouteMeta(
    path: '/terms',
    title: 'Terms — Aura Platform',
    description:
        'Terms of use for the Aura Platform.',
  ),
  _RouteMeta(
    path: '/child-safety',
    title: 'Child Safety — Aura Platform',
    description:
        'Aura’s child safety standards, reporting channels, and contacts for law enforcement and child-safety investigators.',
  ),
  _RouteMeta(
    path: '/account-deletion',
    title: 'Account Deletion — Aura Platform',
    description:
        'How to delete your Aura account and what happens to your records.',
  ),
];

/// Per-route value to substitute, keyed by `data-aura-meta`.
Map<String, String> _substitutions(_RouteMeta r) {
  return {
    'title': r.title,
    'description': r.description,
    'canonical': r.canonicalUrl,
    'og:title': r.title,
    'og:description': r.description,
    'og:url': r.canonicalUrl,
    'og:image': r.imageUrl,
    'og:image:secure_url': r.imageUrl,
    'og:image:alt': r.imageAlt,
    'twitter:title': r.title,
    'twitter:description': r.description,
    'twitter:image': r.imageUrl,
    'twitter:image:alt': r.imageAlt,
  };
}

/// Rewrites the document for a given route. Three tag shapes are
/// supported:
///   <title data-aura-meta="title">…</title>
///   <meta … data-aura-meta="<key>" content="…">
///   <link rel="canonical" data-aura-meta="canonical" href="…">
String _applySubstitutions(String html, Map<String, String> subs) {
  var out = html;

  // <title data-aura-meta="title">…</title>
  out = out.replaceAllMapped(
    RegExp(r'<title\s+data-aura-meta="title">[^<]*</title>'),
    (_) => '<title data-aura-meta="title">${_htmlEscape(subs['title'] ?? '')}</title>',
  );

  // <meta … data-aura-meta="<key>" content="…">
  out = out.replaceAllMapped(
    RegExp(
      r'(<meta\b[^>]*?\bdata-aura-meta=")([^"]+)("\s+content=")[^"]*(")',
      multiLine: false,
    ),
    (m) {
      final key = m.group(2)!;
      final value = subs[key];
      if (value == null) return m.group(0)!;
      return '${m.group(1)}$key${m.group(3)}${_attrEscape(value)}${m.group(4)}';
    },
  );

  // <link rel="canonical" data-aura-meta="canonical" href="…">
  out = out.replaceAllMapped(
    RegExp(
      r'(<link\b[^>]*?\bdata-aura-meta=")([^"]+)("\s+href=")[^"]*(")',
      multiLine: false,
    ),
    (m) {
      final key = m.group(2)!;
      final value = subs[key];
      if (value == null) return m.group(0)!;
      return '${m.group(1)}$key${m.group(3)}${_attrEscape(value)}${m.group(4)}';
    },
  );

  return out;
}

String _htmlEscape(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

String _attrEscape(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('"', '&quot;');

Future<int> main(List<String> args) async {
  final rootIndex = File('$_outputRoot/index.html');
  if (!await rootIndex.exists()) {
    stderr.writeln(
      'generate_route_metadata: $_outputRoot/index.html not found. '
      'Run after `flutter build web`.',
    );
    return 1;
  }
  final canonical = await rootIndex.readAsString();

  if (!canonical.contains('data-aura-meta=')) {
    stderr.writeln(
      'generate_route_metadata: $_outputRoot/index.html has no '
      '`data-aura-meta` markers. The metadata foundation was likely '
      'removed from web/index.html. Refusing to generate variants.',
    );
    return 2;
  }

  var written = 0;
  for (final route in _routes) {
    final variant = _applySubstitutions(canonical, _substitutions(route));
    final dirPath = '$_outputRoot${route.path}';
    final dir = Directory(dirPath);
    await dir.create(recursive: true);
    await File('$dirPath/index.html').writeAsString(variant);
    written++;
    stdout.writeln('generate_route_metadata: wrote $dirPath/index.html');
  }

  stdout.writeln(
    'generate_route_metadata: $written route variants written under $_outputRoot/.',
  );
  return 0;
}
