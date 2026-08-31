@Tags(['visual'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:aura/core/auth/admin_access_provider.dart';
import 'package:aura/features/admin/areas/now_area.dart';
import 'package:aura/features/admin/areas/work_area.dart';
import 'package:aura/features/admin/data/admin_providers.dart';
import 'package:aura/features/admin/data/operator_work.dart';
import 'package:aura/features/admin/shell/operator_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// A RENDER HARNESS, NOT AN ASSERTION.
///
/// The reconstruction rule is IMPLEMENT → RENDER → LOOK → JUDGE, and a widget
/// test that passes proves only that nothing threw. This writes real PNGs at
/// desktop, tablet and phone widths so the surfaces can actually be looked at.
///
/// Flutter's test renderer has no system font, so text would otherwise be
/// black boxes — useless for judging hierarchy. A real face is loaded when one
/// is available; the harness degrades rather than failing on a machine that
/// has none.
///
/// Run: flutter test test/admin/operator_render_harness_test.dart
/// Output: build/operator-render/*.png
void main() {
  const outDir = 'build/operator-render';

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadRealFont();
    Directory(outDir).createSync(recursive: true);
  });

  final sizes = <String, Size>{
    'desktop': const Size(1440, 900),
    'tablet': const Size(900, 1000),
    'phone': const Size(390, 844),
  };

  for (final entry in sizes.entries) {
    testWidgets('NOW · ${entry.key}', (tester) async {
      await _render(tester, entry.value, '/admin', const NowArea(),
          '$outDir/now_${entry.key}.png');
    });

    testWidgets('WORK · ${entry.key}', (tester) async {
      await _render(tester, entry.value, '/admin/work', const WorkArea(),
          '$outDir/work_${entry.key}.png');
    });
  }

  testWidgets('NOW · everything clear', (tester) async {
    await _render(
      tester,
      const Size(1440, 900),
      '/admin',
      const NowArea(),
      '$outDir/now_clear_desktop.png',
      workSummary: _clearSummary,
    );
  });

  testWidgets('NOW · degraded platform', (tester) async {
    await _render(
      tester,
      const Size(1440, 900),
      '/admin',
      const NowArea(),
      '$outDir/now_degraded_desktop.png',
      health: _degradedHealth,
    );
  });

  testWidgets('WORK · empty result', (tester) async {
    await _render(
      tester,
      const Size(1440, 900),
      '/admin/work',
      const WorkArea(),
      '$outDir/work_empty_desktop.png',
      workItems: const <OperatorWorkItem>[],
      workSummary: _clearSummary,
    );
  });

  testWidgets('shell · operator with no authority', (tester) async {
    await _render(
      tester,
      const Size(1440, 900),
      '/admin',
      const NowArea(),
      '$outDir/no_authority_desktop.png',
      adminMe: null,
    );
  });

  testWidgets('shell · moderator sees only what they hold', (tester) async {
    await _render(
      tester,
      const Size(1440, 900),
      '/admin',
      const NowArea(),
      '$outDir/moderator_desktop.png',
      adminMe: _moderatorMe,
      workSummary: _moderatorSummary,
    );
  });
}

// ─────────────────────────────────────────────────────────────────────────────

Future<void> _loadRealFont() async {
  const candidates = [
    r'C:\Windows\Fonts\segoeui.ttf',
    r'C:\Windows\Fonts\arial.ttf',
    '/System/Library/Fonts/Helvetica.ttc',
    '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
  ];
  for (final path in candidates) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final bytes = file.readAsBytesSync();
    // Registered under the family the test theme asks for, so every widget
    // picks it up without touching production code.
    final loader = FontLoader('OperatorHarness')
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
    break;
  }

  // The test renderer ships NO icon font, so every Icon renders as a box —
  // which makes a console impossible to judge, since status is carried by
  // icons as much as by text.
  for (final path in const [
    'C:/flutter/bin/cache/dart-sdk/bin/resources/devtools/assets/fonts/MaterialIcons-Regular.otf',
    '/usr/lib/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ]) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final bytes = file.readAsBytesSync();
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
    return;
  }
}

Future<void> _render(
  WidgetTester tester,
  Size size,
  String path,
  Widget area,
  String outPath, {
  Map<String, dynamic>? adminMe = _ownerMe,
  OperatorWorkSummary? workSummary,
  List<OperatorWorkItem>? workItems,
  dynamic health,
}) async {
  final captureKey = GlobalKey();
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: path,
    routes: [
      ShellRoute(
        builder: (_, __, child) => OperatorShell(child: child),
        routes: [
          GoRoute(path: '/admin', builder: (_, __) => area),
          GoRoute(path: '/admin/work', builder: (_, __) => area),
        ],
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appAdminAccessProvider.overrideWith((ref) async => AppAdminAccess(
              state: adminMe == null ? AppAdminState.none : AppAdminState.admin,
              me: adminMe,
            )),
        operatorWorkSummaryProvider.overrideWith(
          (ref) async => workSummary ?? _busySummary,
        ),
        operatorWorkListProvider.overrideWith(
          (ref) async => workItems ?? _busyItems,
        ),
        adminHealthProvider.overrideWith((ref) async => health ?? _healthyHealth),
        adminAuditLogsProvider.overrideWith((ref) async => const []),
      ],
      child: RepaintBoundary(
        key: captureKey,
        child: MaterialApp.router(
          routerConfig: router,
          debugShowCheckedModeBanner: false,
          theme: ThemeData(brightness: Brightness.dark).copyWith(
            textTheme: ThemeData(brightness: Brightness.dark)
                .textTheme
                .apply(fontFamily: 'OperatorHarness'),
          ),
        ),
      ),
    ),
  );

  // Two pumps: one to mount, one to settle the async providers.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));

  await _capture(tester, captureKey, outPath);
}

Future<void> _capture(
  WidgetTester tester,
  GlobalKey key,
  String outPath,
) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1.0);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) return;
  File(outPath).writeAsBytesSync(bytes.buffer.asUint8List());
}

// ── fixtures ────────────────────────────────────────────────────────────────

const _ownerMe = <String, dynamic>{
  'userId': 'op-1',
  'roles': ['OWNER'],
  'isOwner': true,
  'effectivePermissions': [
    'USERS_READ', 'USERS_WRITE', 'MODERATION_READ', 'MODERATION_WRITE',
    'VERIFICATION_READ', 'VERIFICATION_WRITE',
    'IDENTITY_VERIFICATION_READ', 'IDENTITY_VERIFICATION_WRITE',
    'INSTITUTIONS_READ', 'INSTITUTIONS_WRITE',
    'ANNOUNCEMENTS_READ', 'ANNOUNCEMENTS_WRITE',
    'COMMUNICATIONS_READ', 'COMMUNICATIONS_WRITE',
    'COMMUNICATIONS_APPROVE', 'COMMUNICATIONS_SEND',
    'AUDIT_READ', 'ANALYTICS_READ', 'SETTINGS_READ', 'SETTINGS_WRITE',
    'SYSTEM_HEALTH_READ', 'SUPPORT_READ', 'SUPPORT_WRITE',
    'PRODUCT_FEEDBACK_READ', 'PRODUCT_FEEDBACK_WRITE',
  ],
};

const _moderatorMe = <String, dynamic>{
  'userId': 'op-2',
  'roles': ['MODERATOR'],
  'isOwner': false,
  'effectivePermissions': [
    'MODERATION_READ',
    'MODERATION_WRITE',
    'ANNOUNCEMENTS_READ',
    'AUDIT_READ',
  ],
};

final _busySummary = OperatorWorkSummary(
  totalOpen: 23,
  degradedSources: const [],
  sources: [
    const OperatorWorkSourceSummary(
      source: 'MODERATION',
      label: 'Moderation',
      open: 9,
      readable: true,
      destination: '/admin/work?source=MODERATION',
      oldestAgeDays: 16,
    ),
    const OperatorWorkSourceSummary(
      source: 'IDENTITY_VERIFICATION',
      label: 'Identity verification',
      open: 6,
      readable: true,
      destination: '/admin/work?source=IDENTITY_VERIFICATION',
      oldestAgeDays: 8,
    ),
    const OperatorWorkSourceSummary(
      source: 'PRODUCT_FEEDBACK',
      label: 'Product feedback',
      open: 5,
      readable: true,
      destination: '/admin/work?source=PRODUCT_FEEDBACK',
      oldestAgeDays: 3,
    ),
    const OperatorWorkSourceSummary(
      source: 'SUPPORT',
      label: 'Support',
      open: 3,
      readable: true,
      destination: '/admin/work?source=SUPPORT',
      oldestAgeDays: 1,
    ),
  ],
);

final _moderatorSummary = OperatorWorkSummary(
  totalOpen: 9,
  degradedSources: const [],
  sources: [
    const OperatorWorkSourceSummary(
      source: 'MODERATION',
      label: 'Moderation',
      open: 9,
      readable: true,
      destination: '/admin/work?source=MODERATION',
      oldestAgeDays: 16,
    ),
  ],
);

final _clearSummary = OperatorWorkSummary(
  totalOpen: 0,
  degradedSources: const [],
  sources: [
    const OperatorWorkSourceSummary(
      source: 'MODERATION',
      label: 'Moderation',
      open: 0,
      readable: true,
      destination: '/admin/work?source=MODERATION',
    ),
  ],
);

final _busyItems = <OperatorWorkItem>[
  OperatorWorkItem(
    key: 'MODERATION:1',
    source: 'MODERATION',
    sourceLabel: 'Moderation',
    id: '1',
    title: 'Report: harassment',
    state: 'OPEN',
    openedAt: DateTime.now().subtract(const Duration(days: 16)),
    ageDays: 16,
    destination: '/admin/integrity/moderation/1',
    subjectKind: WorkSubjectKind.content,
    subjectLabel: 'Institution post',
  ),
  OperatorWorkItem(
    key: 'IDENTITY_VERIFICATION:2',
    source: 'IDENTITY_VERIFICATION',
    sourceLabel: 'Identity verification',
    id: '2',
    title: 'Identity verification review',
    state: 'PENDING_REVIEW',
    openedAt: DateTime.now().subtract(const Duration(days: 8)),
    ageDays: 8,
    destination: '/admin/subjects/person/u2/identity',
    subjectKind: WorkSubjectKind.person,
  ),
  OperatorWorkItem(
    key: 'PRODUCT_FEEDBACK:3',
    source: 'PRODUCT_FEEDBACK',
    sourceLabel: 'Product feedback',
    id: '3',
    title: 'Feedback: REPORT_A_PROBLEM',
    state: 'RECEIVED',
    openedAt: DateTime.now().subtract(const Duration(days: 3)),
    ageDays: 3,
    destination: '/admin/integrity/feedback/3',
    subjectKind: WorkSubjectKind.unknown,
    subjectLabel: 'aura',
  ),
  OperatorWorkItem(
    key: 'SUPPORT:4',
    source: 'SUPPORT',
    sourceLabel: 'Support',
    id: '4',
    title: 'Cannot join a meeting from the invite link',
    state: 'NEW',
    openedAt: DateTime.now().subtract(const Duration(days: 1)),
    ageDays: 1,
    destination: '/admin/integrity/support/4',
    subjectKind: WorkSubjectKind.person,
  ),
];

final _healthyHealth = AdminHealthSnapshot.fromJson(const {
  'api': 'ok',
  'db': 'ok',
  'email': 'ok',
  'push': 'ok',
  'realtime': 'ok',
});

final _degradedHealth = AdminHealthSnapshot.fromJson(const {
  'api': 'ok',
  'db': 'ok',
  'email': 'down',
  'push': 'degraded',
  'realtime': 'ok',
});
