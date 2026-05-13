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
    this.crawlerVisibleHeading,
    this.crawlerVisibleBodyParagraphs = const <String>[],
    this.crawlerVisibleContactEmail,
  }) : imageAlt = imageAlt ?? 'Aura Platform — accountable communication infrastructure';

  final String path; // e.g. '/investors' — must start with '/' and not end with '/'
  final String title;
  final String description;
  final String image; // file under /social/
  final String imageAlt;

  /// Optional crawler-visible heading rendered inside a `<noscript>`
  /// block (and as a visible fallback for clients that disable JS).
  /// Used for compliance routes — Microsoft Store 10.5.1 in particular
  /// requires the privacy URL to resolve to a functional webpage, and
  /// some certification crawlers do not execute JavaScript.
  final String? crawlerVisibleHeading;

  /// Paragraphs rendered alongside [crawlerVisibleHeading]. Plain text;
  /// each becomes a `<p>` tag. Kept short — full legal text still
  /// lives in the Flutter SPA's rendered route.
  final List<String> crawlerVisibleBodyParagraphs;

  /// Optional contact email surfaced in the crawler-visible block.
  /// Microsoft cert tooling specifically looks for the existence of a
  /// privacy contact and a method to reach it.
  final String? crawlerVisibleContactEmail;

  String get canonicalUrl => 'https://auraplatform.org$path';
  String get imageUrl => 'https://auraplatform.org/social/$image';

  bool get hasCrawlerVisibleContent =>
      (crawlerVisibleHeading ?? '').trim().isNotEmpty;
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
    title: 'Privacy Policy — Aura Platform',
    description:
        'How Aura Platform LLC handles your data, identity, and records. '
        'Verified identity, structured authority, durable records, and '
        'user-controlled deletion.',
    crawlerVisibleHeading: 'Privacy Policy',
    crawlerVisibleBodyParagraphs: [
      'Aura Platform LLC operates the Aura communication platform and the '
          'Orchestrate operational-execution platform. This page summarizes '
          'how the platform collects, uses, retains, and deletes personal '
          'information.',
      'Aura collects only the information needed to operate verified-identity '
          'accounts, attribute public statements to a real author, deliver '
          'private communications, and produce durable institutional records. '
          'We do not sell personal information.',
      'Information categories: account identity (name, handle, email, phone '
          'where supplied for verification), authored content (public posts, '
          'institutional announcements, private messages), interaction '
          'records (likes, replies, follows, reactions), media uploads, and '
          'operational metadata (timestamps, device identity for session '
          'continuity, audit logs of moderation actions).',
      'Data sharing: Aura does not share personal information with '
          'advertisers or data brokers. We share data with sub-processors '
          'we use to run the platform (cloud hosting, email delivery, '
          'payment processing where applicable, and law-enforcement '
          'compliance where legally required).',
      'Account deletion: signed-in users can request account deletion from '
          'the Account Deletion page. Deletion removes account identity '
          'from public surfaces. Public records that have been replied to '
          'or referenced by other authors may be retained in anonymized '
          'form so the public record remains coherent.',
      'Children: Aura is not directed to children under 13. See the Child '
          'Safety page for reporting channels and law-enforcement contact.',
      'Contact: write to privacy@auraplatform.org with questions, deletion '
          'requests, or regulatory inquiries.',
    ],
    crawlerVisibleContactEmail: 'privacy@auraplatform.org',
  ),
  _RouteMeta(
    path: '/terms',
    title: 'Terms of Use — Aura Platform',
    description:
        'Terms of use for the Aura Platform, including Aura and Orchestrate. '
        'Acceptable use, accountability requirements, and dispute resolution.',
    crawlerVisibleHeading: 'Terms of Use',
    crawlerVisibleBodyParagraphs: [
      'These Terms of Use govern access to the Aura communication platform '
          'and the Orchestrate operational-execution platform, both operated '
          'by Aura Platform LLC.',
      'Identity: accounts on Aura are tied to verified real-person or '
          'verified-institution identity. Accountability is a core platform '
          'property; impersonation, identity laundering, and synthetic '
          'authorship are prohibited.',
      'Acceptable use: users agree not to use the platform to harass, '
          'defraud, distribute illegal content, abuse children, or '
          'circumvent platform moderation. Aura retains the right to '
          'suspend accounts and remove content that violates these terms.',
      'Authored content: users retain ownership of content they author, '
          'grant Aura a license to host and distribute that content as '
          'directed by the user, and accept that public statements may be '
          'preserved as durable records.',
      'Institutional accounts: institutions speaking on Aura accept that '
          'institutional statements are attributable to the institution and '
          'subject to public accountability.',
      'No warranty: the platform is provided as-is. Aura disclaims liability '
          'for indirect or consequential damages to the extent permitted by '
          'law.',
      'Governing law: these terms are governed by the laws of the state '
          'in which Aura Platform LLC is organized, with venue in courts of '
          'competent jurisdiction.',
      'Contact: write to legal@auraplatform.org for terms questions or '
          'service of process.',
    ],
    crawlerVisibleContactEmail: 'legal@auraplatform.org',
  ),
  _RouteMeta(
    path: '/child-safety',
    title: 'Child Safety — Aura Platform',
    description:
        'Aura\'s child safety standards, reporting channels, and contacts '
        'for law enforcement and child-safety investigators.',
    crawlerVisibleHeading: 'Child Safety',
    crawlerVisibleBodyParagraphs: [
      'Aura Platform LLC has zero tolerance for child sexual abuse material '
          '(CSAM) and child exploitation of any form. Suspected violations '
          'are removed and, where required by law, reported to the National '
          'Center for Missing and Exploited Children (NCMEC) and to the '
          'appropriate authorities.',
      'Reporting suspected abuse: write to safety@auraplatform.org with a '
          'description, the affected URL or username when known, and any '
          'context that helps reviewers act quickly. Reports are reviewed '
          'on a priority track.',
      'Law enforcement: investigators may contact Aura at '
          'safety@auraplatform.org for child-safety matters. Legal process '
          'should be served through the channels published under our legal '
          'contact.',
      'Policies: Aura requires verified identity, prohibits accounts '
          'directed to minors under 13, and applies enhanced review to '
          'content involving minors. Detection combines automated review, '
          'community reporting, and human moderators.',
      'Contact: safety@auraplatform.org.',
    ],
    crawlerVisibleContactEmail: 'safety@auraplatform.org',
  ),
  _RouteMeta(
    path: '/account-deletion',
    title: 'Account Deletion — Aura Platform',
    description:
        'How to delete your Aura account and what happens to your records.',
    crawlerVisibleHeading: 'Account Deletion',
    crawlerVisibleBodyParagraphs: [
      'Aura Platform LLC users can request account deletion. This page '
          'describes the deletion path, the timeline, and the treatment of '
          'public records authored by the account.',
      'How to request deletion: signed-in users can open the Account '
          'Deletion screen inside the app and submit the deletion request. '
          'Users unable to sign in can write to privacy@auraplatform.org '
          'from the email address on file.',
      'What happens at deletion: account identity (name, handle, avatar, '
          'private messages, draft content) is removed. Public records that '
          'have been replied to or referenced by other accounts may be '
          'retained in anonymized form so the public record remains '
          'coherent.',
      'Timeline: deletion is processed within 30 days of a verified '
          'request. Some institutional records subject to legal retention '
          'requirements may be retained longer, in anonymized form, where '
          'required by law.',
      'Contact: privacy@auraplatform.org.',
    ],
    crawlerVisibleContactEmail: 'privacy@auraplatform.org',
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
///
/// When [route] supplies crawler-visible content, also injects a
/// `<noscript>` + visible-fallback block immediately before `</body>`
/// so non-JS crawlers (notably Microsoft Store certification tooling
/// on policy 10.5.1) read functional content instead of an empty SPA
/// shell.
String _applySubstitutions(
  String html,
  Map<String, String> subs, {
  _RouteMeta? route,
}) {
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

  // Crawler-visible content injection. The block lives inside
  // <noscript> so JS-capable browsers (which boot the Flutter SPA and
  // render the canonical route view) never see double content. Bots
  // that disable JS — including Microsoft Store certification tooling
  // and several public crawlers — get a real, readable page.
  if (route != null && route.hasCrawlerVisibleContent) {
    final block = _buildCrawlerVisibleBlock(route);
    // Insert immediately before </body>. Replace the first match only.
    out = out.replaceFirst('</body>', '$block\n</body>');
  }

  return out;
}

/// Build the static crawler-visible block for a compliance route.
/// Renders inside `<noscript>` so it never competes with the SPA's
/// rendered view. Plain HTML — no JS, no app dependencies. The block
/// styles itself inline with the Aura dark palette so it reads as a
/// real publication rather than an unstyled fallback.
String _buildCrawlerVisibleBlock(_RouteMeta route) {
  final heading = _htmlEscape(route.crawlerVisibleHeading!);
  final canonical = _attrEscape(route.canonicalUrl);
  final paragraphs = route.crawlerVisibleBodyParagraphs
      .map((p) => '      <p style="margin:0 0 1.1em 0;line-height:1.7;color:#d4dbe5;font-size:15px;">${_htmlEscape(p)}</p>')
      .join('\n');
  final contactBlock = (route.crawlerVisibleContactEmail ?? '').isEmpty
      ? ''
      : '      <p style="margin:1.6em 0 0 0;color:#8fa3bf;font-size:13px;letter-spacing:0.06em;">'
          'Contact: <a href="mailto:${_attrEscape(route.crawlerVisibleContactEmail!)}" '
          'style="color:#c9a55c;text-decoration:underline;">'
          '${_htmlEscape(route.crawlerVisibleContactEmail!)}</a></p>';

  return '''
  <noscript>
    <main style="background:#0d1520;color:#e2ecf5;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;min-height:100vh;padding:48px 24px;">
      <article style="max-width:720px;margin:0 auto;">
        <p style="margin:0 0 8px 0;color:#c9a55c;font-size:12px;letter-spacing:0.16em;text-transform:uppercase;font-weight:700;">Aura Platform LLC</p>
        <h1 style="margin:0 0 24px 0;font-size:32px;line-height:1.2;font-weight:700;letter-spacing:-0.2px;">$heading</h1>
$paragraphs
$contactBlock
        <p style="margin:2em 0 0 0;color:#7a96b5;font-size:12px;letter-spacing:0.12em;text-transform:uppercase;">Canonical: <a href="$canonical" style="color:#7a96b5;text-decoration:underline;">$canonical</a></p>
      </article>
    </main>
  </noscript>''';
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
    final variant = _applySubstitutions(
      canonical,
      _substitutions(route),
      route: route,
    );
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
