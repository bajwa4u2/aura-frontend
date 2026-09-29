{{flutter_js}}
{{flutter_build_config}}

// Every script a person writes in, from Aura's own origin (2026-09-29).
// Flutter draws text in a canvas and fetches a Noto font the moment a script
// appears. By default it fetches from fonts.gstatic.com, and where that is
// blocked (strict tracking prevention, a filtering network) Urdu, Arabic and
// every other non-Latin script became empty boxes in the composer. The same
// 724 files are served from /fallback-fonts/ (web/fallback-fonts, mirrored
// from the engine's own list; see tool/sync_fallback_fonts.py).
_flutter.loader.load({
  config: {
    fontFallbackBaseUrl: "/fallback-fonts/",
  },
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
});
