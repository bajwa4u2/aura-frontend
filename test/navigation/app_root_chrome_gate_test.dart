import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// WHAT IS ALLOWED TO LIVE ABOVE THE NAVIGATOR.
//
// `MaterialApp.router`'s `builder:` mounts chrome ABOVE the route tree. That
// placement is deliberate — the blocking release screens need Material and
// MediaQuery ancestors — but it means these widgets have NO Navigator, and
// therefore NO Overlay and NO GoRouterState.
//
// This has now failed three separate times in the same file:
//
//   1. the maintenance branch called `GoRouterState.of(context)` and threw
//      "There is no GoRouterState above the current context" — invisible until
//      maintenance was switched on for the first time;
//   2. the release-available banner's dismiss control used `tooltip:`, and
//      Tooltip requires an Overlay, so it threw "No Overlay widget found." on
//      every build. The global ErrorWidget replaced it with a 460x320 black box
//      sitting where the dismiss button belongs — founder-observed on the live
//      site, 2026-08-22;
//   3. the soft-warn banner carried the same tooltip, latent only because a
//      `degraded` verdict is rarer than an available release.
//
// Each was found by a person looking at a running app, which is the wrong
// instrument for a rule this mechanical. The rule is: chrome mounted above the
// Navigator may not use anything that requires one.

const _appRootChrome = <String>[
  'lib/core/release_governance/update_gate.dart',
  'lib/core/navigation/boot_gate.dart',
  'lib/features/realtime/presentation/widgets/orphaned_session_banner.dart',
  'lib/features/realtime/presentation/thread_call_lifecycle_host.dart',
];

/// Widgets that silently require an Overlay (which only a Navigator provides).
const _needsOverlay = <String>[
  'tooltip:',
  'Tooltip(',
  'SelectableText(',
  'DropdownButton',
  'showMenu(',
];

/// APIs that resolve only beneath a `RouteBase.builder`.
const _needsRoute = <String>[
  'GoRouterState.of(',
  'ModalRoute.of(',
];

/// Strip `//` line comments so the rule reads code, not the notes explaining
/// why the rule exists — those legitimately name the banned tokens.
String _codeOnly(String source) => source
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  group('chrome above the Navigator needs nothing from it', () {
    for (final path in _appRootChrome) {
      test('$path uses no Overlay-dependent widget', () {
        final file = File(path);
        if (!file.existsSync()) {
          fail('app-root chrome moved or was renamed: $path');
        }
        final code = _codeOnly(file.readAsStringSync());

        final offenders =
            _needsOverlay.where((token) => code.contains(token)).toList();

        expect(offenders, isEmpty,
            reason: 'these build above the Navigator, so there is no Overlay '
                'for them to attach to — the widget throws and the global '
                'ErrorWidget paints a box where the control should be');
      });

      test('$path resolves no route from context', () {
        final code = _codeOnly(File(path).readAsStringSync());
        final offenders =
            _needsRoute.where((token) => code.contains(token)).toList();

        expect(offenders, isEmpty,
            reason: 'there is no GoRouterState above the route tree; read the '
                'router directly instead');
      });
    }
  });
}
