# Return-path audit tooling

Re-derives every count in
`docs/navigation/2026-08-25-return-path-authority-audit.md`. Run from the
repository root, in order:

    flutter test test/navigation/return_path_census_dump_test.dart   # 1
    python tools/navigation_audit/attribute.py                       # 2
    python tools/navigation_audit/classify.py                        # 3
    python tools/navigation_audit/entrymode.py                       # 4
    python tools/navigation_audit/surfaces.py                        # 5
    python tools/navigation_audit/emit.py                            # 6

1. Walks the LIVE router (`router.configuration.routes`) and writes
   `test/navigation/_route_census.json`. This is the authoritative population —
   a text scan of `router.dart` is not, and the one written first silently
   dropped three routes.
2. Attributes each route to the widget its builder constructs, unwrapping route
   boundaries (`InstitutionRouteScope` and friends). Attributing a route to its
   boundary reports the boundary's file, which never draws a return control —
   that mistake made every institution route look defective.
3. Classifies against the founder's return-path taxonomy.
4. Measures how each destination is navigated TO — `push` grows the stack,
   `go` replaces it. A destination reached by `go` has no predecessor for any
   return affordance to unwind to.
5. Censuses navigable surfaces with no registered route (sheets, dialogs,
   overlays, pushes outside go_router).
6. Emits the committed CSV/JSON evidence into `docs/navigation/`.

Intermediates land in the repo root and are gitignored; only step 6's output is
committed.
