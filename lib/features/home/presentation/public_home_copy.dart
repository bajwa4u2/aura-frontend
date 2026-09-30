/// The landing page's own words, in one place.
///
/// Read by the page itself AND by tool/web/generate_route_metadata.dart,
/// which writes the text search engines and link previews read. They used to
/// be written twice, and by 2026-09-29 Google was reading a different
/// headline and links to a business case the page never showed (founder
/// approval F3). Plain Dart, no Flutter import, so the build tool can load it.
library;

const String publicHomeHeadline = 'Public conversation that keeps its context.';

const String publicHomeLede =
    'Raise what matters in the open, with people who answer under their '
    'real name. Conversations keep their history, so what was said and '
    'what was promised are still there later.';

const String publicHomeJoinLabel = 'Join Aura';
const String publicHomeExploreLabel = 'Explore discussions';
const String publicHomeExploreRoute = '/discover';
const String publicHomeInstitutionsLabel = 'Browse the institutions on Aura';
const String publicHomeInstitutionsRoute = '/institutions';
const String publicHomeJoinRoute = '/register';
