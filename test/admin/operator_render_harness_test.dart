@Tags(['visual'])
library;

import 'dart:io';

import 'package:aura/core/auth/admin_access_provider.dart';
import 'package:aura/core/net/dio_provider.dart';
import 'package:aura/features/admin/areas/discovery_area.dart';
import 'package:aura/features/admin/areas/integrity_area.dart';
import 'package:aura/features/admin/areas/integrity_detail.dart';
import 'package:aura/features/admin/areas/now_area.dart';
import 'package:aura/features/admin/areas/platform_area.dart';
import 'package:aura/features/admin/areas/record_area.dart';
import 'package:aura/features/admin/areas/subject_institution_area.dart';
import 'package:aura/features/admin/areas/subject_person_area.dart';
import 'package:aura/features/admin/areas/subjects_area.dart';
import 'package:aura/features/admin/areas/work_area.dart';
import 'package:aura/features/admin/data/admin_providers.dart';
import 'package:aura/features/admin/data/operator_work.dart';
import 'package:aura/features/admin/shell/operator_shell.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A RENDER HARNESS, NOT AN ASSERTION.
///
/// The reconstruction rule is IMPLEMENT → RENDER → LOOK → JUDGE, and a widget
/// test that passes proves only that nothing threw. This writes real PNGs at
/// desktop, tablet and phone widths so the surfaces can actually be looked at.
///
/// EVERY AREA, EVERY WIDTH. The founder rule is that mobile is not a reduced
/// subset, and the only way to know whether that is true is to look at all
/// three. A surface that renders only at 1440 is a desktop console with a
/// phone build attached.
///
/// It reads through a FAKE TRANSPORT rather than a pile of provider
/// overrides, so each area exercises its real repository, its real parsing
/// and its real capability gating. A field the model drops is then a field
/// missing from the picture, which is the only way that class of defect ever
/// showed up (see the domain-proof section, which compared a domain record's
/// id against an institution's and reported "none on record" for everybody).
///
/// Flutter's test renderer has no system font, so text would otherwise be
/// black boxes — useless for judging hierarchy. A real face is loaded when one
/// is available; the harness degrades rather than failing on a machine that
/// has none.
///
/// Run: flutter test test/admin/operator_render_harness_test.dart --update-goldens
/// Output: goldens/operator/*.png
void main() {
  const outDir = 'goldens/operator';

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // The token store reads SharedPreferences on construction, and the test
    // renderer has no plugin behind it. Mocked empty: the console reads its
    // authority from the overridden admin-access provider, so an empty store
    // is the honest starting state rather than a workaround.
    SharedPreferences.setMockInitialValues(const {});
    await _loadRealFont();
    Directory(outDir).createSync(recursive: true);
  });

  final sizes = <String, Size>{
    'desktop': const Size(1440, 900),
    'tablet': const Size(900, 1000),
    'phone': const Size(390, 844),
  };

  /// The seven areas plus the destinations the worklist addresses. Every one
  /// is rendered at every width — no area is desktop-only and none is a
  /// reduced mobile subset.
  final surfaces = <String, ({String path, Widget widget})>{
    'now': (path: '/admin', widget: const NowArea()),
    'work': (path: '/admin/work', widget: const WorkArea()),
    'subjects': (path: '/admin/subjects', widget: const SubjectsArea()),
    'subject_person': (
      path: '/admin/subjects/person/u-1',
      widget: const SubjectPersonArea(userId: 'u-1'),
    ),
    'subject_institution': (
      path: '/admin/subjects/institution/inst-1',
      widget: const SubjectInstitutionArea(institutionId: 'inst-1'),
    ),
    'integrity': (path: '/admin/integrity', widget: const IntegrityArea()),
    'integrity_report': (
      path: '/admin/integrity/moderation/r-1',
      widget: const ModerationReportDetail(reportId: 'r-1'),
    ),
    'integrity_appeal': (
      path: '/admin/integrity/appeals/ap-1',
      widget: const MediaAppealDetail(appealId: 'ap-1'),
    ),
    'integrity_feedback': (
      path: '/admin/integrity/feedback/fb-1',
      widget: const FeedbackDetail(feedbackId: 'fb-1'),
    ),
    'integrity_support': (
      path: '/admin/integrity/support/sc-1',
      widget: const SupportCaseDetail(caseId: 'sc-1'),
    ),
    'platform': (path: '/admin/platform', widget: const PlatformArea()),
    'record': (path: '/admin/record', widget: const RecordArea()),
    'discovery': (path: '/admin/discovery', widget: const DiscoveryArea()),
  };

  for (final size in sizes.entries) {
    for (final surface in surfaces.entries) {
      testWidgets('${surface.key} · ${size.key}', (tester) async {
        await _render(
          tester,
          size.value,
          surface.value.path,
          surface.value.widget,
          '$outDir/${surface.key}_${size.key}.png',
        );
      });
    }
  }

  // ── The states that are not the busy one ─────────────────────────────────

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

  // A capability-poor operator on the surfaces that are MOST about capability.
  // The console must say what they may not do rather than showing an empty
  // page that reads as a broken one.
  testWidgets('PLATFORM · analyst holds no settings', (tester) async {
    await _render(
      tester,
      const Size(1440, 900),
      '/admin/platform',
      const PlatformArea(),
      '$outDir/platform_analyst_desktop.png',
      adminMe: _analystMe,
    );
  });

  // A TALL viewport for the two longest areas. At 900px the lower half of
  // PLATFORM and DISCOVERY is below the fold, and a section nobody has looked
  // at is a section nobody has judged.
  testWidgets('PLATFORM · whole area', (tester) async {
    await _render(
      tester,
      const Size(1440, 2600),
      '/admin/platform',
      const PlatformArea(),
      '$outDir/platform_full_desktop.png',
    );
  });

  testWidgets('DISCOVERY · whole area', (tester) async {
    await _render(
      tester,
      const Size(1440, 2200),
      '/admin/discovery',
      const DiscoveryArea(),
      '$outDir/discovery_full_desktop.png',
    );
  });

  testWidgets('DISCOVERY · no evidence grant', (tester) async {
    await _render(
      tester,
      const Size(1440, 900),
      '/admin/discovery',
      const DiscoveryArea(),
      '$outDir/discovery_no_evidence_desktop.png',
      adminMe: _discoveryOnlyMe,
    );
  });

  testWidgets('SUBJECT · person, phone, capability-poor', (tester) async {
    await _render(
      tester,
      const Size(390, 844),
      '/admin/subjects/person/u-1',
      const SubjectPersonArea(userId: 'u-1'),
      '$outDir/subject_person_poor_phone.png',
      adminMe: _moderatorMe,
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
        routes: [GoRoute(path: path, builder: (_, __) => area)],
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(_consoleDio(adminMe)),
        appAdminAccessProvider.overrideWith((ref) async => AppAdminAccess(
              state: adminMe == null ? AppAdminState.none : AppAdminState.admin,
              me: adminMe,
            )),
        // `adminMeProvider` awaits session bootstrap and an authed status
        // before it will read anything, and every gated provider behind it —
        // health, metrics, settings, flags, policies, audit — returns null
        // when it does not resolve. Without this the console rendered as an
        // operator who can see nothing, which reads as a product defect and
        // was the harness's own missing session.
        adminMeProvider.overrideWith((ref) async =>
            adminMe == null ? null : AdminAccess.fromJson(adminMe)),
        operatorWorkSummaryProvider.overrideWith(
          (ref) async => workSummary ?? _busySummary,
        ),
        operatorWorkListProvider.overrideWith(
          (ref) async => workItems ?? _busyItems,
        ),
        if (health != null)
          adminHealthProvider.overrideWith((ref) async => health),
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

  // Pumps WITHOUT a duration. Advancing the clock drives RefreshIndicator's
  // animation and the autoDispose futures into a rebuild cycle that made each
  // render take minutes; frame-only pumps settle the providers and stop.
  // Frame-only pumps first, then a few SHORT frames. Dio resolves through
  // async gaps that a bare pump does not always cross, and a detail surface
  // caught mid-flight renders as its loading skeleton — a picture of nothing,
  // which is exactly the failure a render harness is supposed to prevent.
  // Short frames, never pumpAndSettle: the refresh indicator's animation never
  // settles, which is what made an earlier version take minutes per render.
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }

  await expectLater(find.byKey(captureKey), matchesGoldenFile(outPath));

  // Unmount so the ProviderScope disposes. The shell's runtime coordinator
  // holds a periodic timer, and a test that ends with the tree still mounted
  // leaves it pending — which the binding reports as a failure on the NEXT
  // test, pointing at the wrong surface.
  await tester.pumpWidget(const SizedBox.shrink());
  // The clock is only advanced AFTER the tree is gone. Advancing it while the
  // console was mounted drove RefreshIndicator and the autoDispose futures
  // into a rebuild cycle that made each render take minutes; here there is
  // nothing left to rebuild, so this only lets already-scheduled timers
  // retire instead of being reported as leaked.
  await tester.pump(const Duration(seconds: 1));
}

// ── the fake console transport ──────────────────────────────────────────────
//
// One place that answers everything the console asks for, with data shaped
// exactly as the backend shapes it. Anything unrecognised comes back EMPTY and
// 200 rather than 404, so an unmatched path shows up as a blank section in the
// picture rather than as a failure that hides every other section.

/// [adminMe] is answered on `/v1/admin/me` as well as being handed to the
/// access provider.
///
/// Several admin providers gate on `adminMeProvider` before reading anything,
/// so a fake that did not answer that endpoint returned null there and every
/// gated provider then reported EMPTY: PLATFORM rendered "no health snapshot
/// was returned" and policy fell back to its defaults, both of which looked
/// like product defects and were the harness lying.
Dio _consoleDio(Map<String, dynamic>? adminMe) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final p = options.path;
        dynamic body;

        // ENDS-WITH, not contains. `/admin/media-cleanup/status` and
        // `/admin/metrics/overview` both CONTAIN `/admin/me`, so a substring
        // match here answered them with the operator's own record — and the
        // media-retention block then rendered "no pass has completed yet"
        // against a fixture that says one did.
        if (p.endsWith('/admin/me')) {
          body = adminMe;
        } else if (p.contains('/admin/health')) {
          body = _healthyHealth;
        } else if (p.contains('/admin/metrics')) {
          body = _metrics;
        } else if (p.endsWith('/v1/institutions/admin')) {
          body = {'items': _institutions};
        } else if (p.contains('/authority/ownership-recovery-state')) {
          body = {'ok': true, 'recoveryRequired': false, 'candidates': []};
        } else if (p.contains('/members')) {
          body = {'members': _members};
        } else if (p.contains('/verification')) {
          // BEFORE the person-detail branch. `/v1/admin/users/:id/verification`
          // also contains `/admin/users/`, so the broader match answered it
          // with a person record and the identity block reported "no active
          // verification" for a fixture that has one — a picture that lied.
          body = _verification;
        } else if (p.contains('/admin/users/')) {
          body = {'user': _personDetail};
        } else if (p.contains('/admin/users')) {
          body = {'items': _users};
        } else if (p.contains('/admin/grants/permissions')) {
          body = {'permissions': const <String>[]};
        } else if (p.contains('/admin/grants')) {
          body = {'items': _grants};
        } else if (p.contains('/admin/audit-logs')) {
          body = {'items': _audit};
        } else if (p.contains('/admin/settings')) {
          body = {'items': _settings};
        } else if (p.contains('/admin/feature-flags')) {
          body = {'items': _flags};
        } else if (p.contains('/admin/policies')) {
          body = _policies;
        } else if (p.contains('/admin/institution-domains')) {
          body = {'items': _domains};
        } else if (p.contains('/moderation/queue')) {
          body = {'items': _reports};
        } else if (p.contains('/moderation/reports/')) {
          body = _reports.first;
        } else if (p.contains('/admin/media/appeals')) {
          body = {'items': _appeals};
        } else if (p.contains('/admin/feedback/')) {
          body = _feedback;
        } else if (p.contains('/admin/feedback')) {
          body = [_feedback];
        } else if (p.contains('/admin/support/cases/')) {
          body = _supportCase;
        } else if (p.contains('/admin/support/cases')) {
          body = {'cases': [_supportCase], 'total': 1};
        } else if (p.contains('/admin/discovery/coverage')) {
          body = {'coverage': _coverage, 'sources': _sources};
        } else if (p.contains('/admin/discovery/objects')) {
          body = {'items': _discoveryObjects};
        } else if (p.contains('/admin/discovery/queries')) {
          body = {
            'items': _queries,
            'withheld': 41,
            'withheldBelowImpressions': 5,
          };
        } else if (p.contains('/admin/discovery/retention')) {
          body = _retention;
        } else if (p.contains('/admin/media-cleanup/status')) {
          body = _retentionStatus;
        } else if (p.contains('/admin/clients/overview')) {
          body = _fleet;
        } else {
          body = {'items': const <dynamic>[]};
        }

        return handler.resolve(
          Response(requestOptions: options, statusCode: 200, data: body),
        );
      },
    ),
  );
  return dio;
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
    'DISCOVERY_READ', 'DISCOVERY_EVIDENCE_READ',
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

const _analystMe = <String, dynamic>{
  'userId': 'op-3',
  'roles': ['ANALYST'],
  'isOwner': false,
  'effectivePermissions': ['ANALYTICS_READ', 'AUDIT_READ', 'SYSTEM_HEALTH_READ'],
};

/// Holds Discovery but NOT the evidence grant — the split the area exists to
/// respect, rendered so it can be seen respecting it.
const _discoveryOnlyMe = <String, dynamic>{
  'userId': 'op-4',
  'roles': ['ANALYST'],
  'isOwner': false,
  'effectivePermissions': ['DISCOVERY_READ', 'AUDIT_READ'],
};

final _busySummary = OperatorWorkSummary.fromJson(const {
  'totalOpen': 34,
  'degradedSources': ['SUPPORT'],
  'sources': [
    {
      'source': 'MODERATION',
      'label': 'Conduct reports',
      'open': 12,
      'readable': true,
      'destination': '/admin/integrity',
      'oldestAgeDays': 19,
    },
    {
      'source': 'IDENTITY_VERIFICATION',
      'label': 'Identity verification',
      'open': 8,
      'readable': true,
      'destination': '/admin/subjects',
      'oldestAgeDays': 9,
    },
    {
      'source': 'INSTITUTION_VERIFICATION',
      'label': 'Institution verification',
      'open': 6,
      'readable': true,
      'destination': '/admin/subjects',
      'oldestAgeDays': 4,
    },
    {
      'source': 'MEDIA_APPEAL',
      'label': 'Media appeals',
      'open': 5,
      'readable': true,
      'destination': '/admin/integrity',
      'oldestAgeDays': 2,
    },
    {
      'source': 'PRODUCT_FEEDBACK',
      'label': 'Product feedback',
      'open': 3,
      'readable': true,
      'destination': '/admin/integrity',
      'oldestAgeDays': 1,
    },
    {
      'source': 'SUPPORT',
      'label': 'Support',
      'open': 0,
      'readable': false,
      'destination': '/admin/integrity',
    },
  ],
});

final _clearSummary = OperatorWorkSummary.fromJson(const {
  'totalOpen': 0,
  'degradedSources': <String>[],
  'sources': [
    {
      'source': 'MODERATION',
      'label': 'Conduct reports',
      'open': 0,
      'readable': true,
      'destination': '/admin/integrity',
    },
    {
      'source': 'IDENTITY_VERIFICATION',
      'label': 'Identity verification',
      'open': 0,
      'readable': true,
      'destination': '/admin/subjects',
    },
  ],
});

final _moderatorSummary = OperatorWorkSummary.fromJson(const {
  'totalOpen': 12,
  'degradedSources': <String>[],
  'sources': [
    {
      'source': 'MODERATION',
      'label': 'Conduct reports',
      'open': 12,
      'readable': true,
      'destination': '/admin/integrity',
      'oldestAgeDays': 19,
    },
  ],
});

final _busyItems = [
  OperatorWorkItem.fromJson(const {
    'key': 'MODERATION:r-1',
    'source': 'MODERATION',
    'sourceLabel': 'Conduct reports',
    'id': 'r-1',
    'title': 'Reported post — harassment',
    'state': 'OPEN',
    'openedAt': '2026-08-12T09:00:00.000Z',
    'ageDays': 19,
    'destination': '/admin/integrity/moderation/r-1',
    'subjectKind': 'CONTENT',
    'subjectLabel': 'A post by @rowan',
    'subjectId': 'p-77',
    'requiredCapability': 'MODERATION_READ',
  }),
  OperatorWorkItem.fromJson(const {
    'key': 'IDENTITY_VERIFICATION:u-1',
    'source': 'IDENTITY_VERIFICATION',
    'sourceLabel': 'Identity verification',
    'id': 'u-1',
    'title': 'Identity claim awaiting review',
    'state': 'PENDING',
    'openedAt': '2026-08-22T09:00:00.000Z',
    'ageDays': 9,
    'destination': '/admin/subjects/person/u-1/identity',
    'subjectKind': 'PERSON',
    'subjectLabel': 'Rowan Ellis',
    'subjectId': 'u-1',
    'requiredCapability': 'IDENTITY_VERIFICATION_READ',
  }),
  OperatorWorkItem.fromJson(const {
    'key': 'INSTITUTION_VERIFICATION:inst-1',
    'source': 'INSTITUTION_VERIFICATION',
    'sourceLabel': 'Institution verification',
    'id': 'inst-1',
    'title': 'Civic Institute — verification requested',
    'state': 'UNDER_REVIEW',
    'openedAt': '2026-08-27T09:00:00.000Z',
    'ageDays': 4,
    'destination': '/admin/subjects/institution/inst-1/verification',
    'subjectKind': 'INSTITUTION',
    'subjectLabel': 'Civic Institute',
    'subjectId': 'inst-1',
    'requiredCapability': 'VERIFICATION_READ',
  }),
  OperatorWorkItem.fromJson(const {
    'key': 'MEDIA_APPEAL:ap-1',
    'source': 'MEDIA_APPEAL',
    'sourceLabel': 'Media appeals',
    'id': 'ap-1',
    'title': 'Appeal against a quarantined file',
    'state': 'SUBMITTED',
    'openedAt': '2026-08-29T09:00:00.000Z',
    'ageDays': 2,
    'destination': '/admin/integrity/appeals/ap-1',
    'subjectKind': 'MEDIA',
    'subjectLabel': 'brochure.pdf',
    'subjectId': 'md-3',
    'requiredCapability': 'MODERATION_READ',
  }),
  OperatorWorkItem.fromJson(const {
    'key': 'PRODUCT_FEEDBACK:fb-1',
    'source': 'PRODUCT_FEEDBACK',
    'sourceLabel': 'Product feedback',
    'id': 'fb-1',
    'title': 'AF-7QK2 — calls do not ring on Android',
    'state': 'RECEIVED',
    'openedAt': '2026-08-30T09:00:00.000Z',
    'ageDays': 1,
    'destination': '/admin/integrity/feedback/fb-1',
    'subjectKind': 'PERSON',
    'subjectLabel': 'Rowan Ellis',
    'subjectId': 'u-1',
    'requiredCapability': 'PRODUCT_FEEDBACK_READ',
  }),
];

const _healthyHealth = {
  'status': 'ok',
  'healthy': true,
  'services': {
    'api': 'ok',
    'db': 'ok',
    'email': 'ok',
    'push': 'ok',
    'realtime': 'ok',
  },
};

const _degradedHealth = {
  'status': 'degraded',
  'healthy': false,
  'services': {
    'api': 'ok',
    'db': 'ok',
    'email': 'degraded',
    'push': 'ok',
    'realtime': 'down',
  },
};

const _metrics = {
  'users': 4120,
  'institutions': 38,
  'posts': 9044,
  'realtimeSessions': 3,
};

const _fleet = {
  'windowHours': 168,
  'totalObservations': 1902,
  'uniqueClientFingerprints': 214,
  'byDistribution': [
    {
      'distribution': 'play',
      'channel': 'production',
      'count': 180,
      'percentage': 84.1,
    },
    {
      'distribution': 'app_store',
      'channel': 'production',
      'count': 34,
      'percentage': 15.9,
    },
  ],
  'byVersion': [
    {
      'distribution': 'play',
      'channel': 'production',
      'appVersion': '1.4.0',
      'count': 180,
      'percentage': 84.1,
      'staleVsRecommended': false,
    },
    {
      'distribution': 'app_store',
      'channel': 'production',
      'appVersion': '1.3.0',
      'count': 34,
      'percentage': 15.9,
      'staleVsRecommended': true,
    },
  ],
  'incompatibleAttempts': <dynamic>[],
  'stalePercentageByDistribution': [
    {'distribution': 'app_store', 'percentage': 15.9},
  ],
};

const _institutions = [
  {
    'id': 'inst-1',
    'name': 'Civic Institute',
    'slug': 'civic-institute',
    'status': 'VERIFIED',
    'memberCount': 24,
    'domain': 'civic.example',
    'verifiedAt': '2026-02-01T00:00:00.000Z',
  },
  {
    'id': 'inst-2',
    'name': 'Northgate Trust',
    'slug': 'northgate-trust',
    'status': 'PENDING',
    'memberCount': 3,
  },
];

const _members = {
  'members': [
    {
      'id': 'm-ada',
      'userId': 'u-ada',
      'role': 'OWNER',
      'joinedAt': '2026-01-01T00:00:00.000Z',
      'title': 'Director',
      'canSpeakOfficially': true,
      'user': {'displayName': 'Ada Owner', 'handle': 'ada'},
    },
    {
      'id': 'm-bea',
      'userId': 'u-bea',
      'role': 'EDITOR',
      'joinedAt': '2026-01-02T00:00:00.000Z',
      'user': {'displayName': 'Bea Member', 'handle': 'bea'},
    },
  ],
};

const _users = [
  {
    'id': 'u-1',
    'handle': 'rowan',
    'displayName': 'Rowan Ellis',
    'email': 'rowan@example.test',
    'role': 'MEMBER',
    'status': 'active',
    'createdAt': '2026-03-01T00:00:00.000Z',
  },
  {
    'id': 'u-2',
    'handle': 'sam',
    'displayName': 'Sam Iyer',
    'email': 'sam@example.test',
    'role': 'MEMBER',
    'status': 'disabled',
    'createdAt': '2026-04-01T00:00:00.000Z',
  },
];

const _personDetail = {
  'id': 'u-1',
  'handle': 'rowan',
  'displayName': 'Rowan Ellis',
  'email': 'rowan@example.test',
  'accountType': 'PERSON',
  'status': 'ACTIVE',
  'emailVerifiedAt': '2026-03-02T00:00:00.000Z',
  'city': 'Detroit',
  'country': 'US',
  'createdAt': '2026-03-01T00:00:00.000Z',
  'admin': {
    'roles': ['MODERATOR'],
    'permissions': ['MODERATION_READ', 'MODERATION_WRITE'],
    'grants': [
      {
        'id': 'g-1',
        'role': 'MODERATOR',
        'status': 'ACTIVE',
        'permissions': ['MODERATION_READ', 'MODERATION_WRITE'],
        'grantedAt': '2026-05-01T00:00:00.000Z',
        'reason': 'Community moderation for the Detroit chapter.',
        'userId': 'u-1',
        'grantedBy': {'id': 'op-1', 'displayName': 'The Owner'},
      },
    ],
  },
  'devices': [
    {
      'id': 'd-1',
      'platform': 'android',
      'deviceName': 'Pixel 8',
      'appVersion': '1.4.0',
      'isActive': true,
      'lastSeenAt': '2026-08-30T00:00:00.000Z',
    },
    {
      'id': 'd-2',
      'platform': 'web',
      'deviceName': 'Chrome on Windows',
      'isActive': false,
      'revokedAt': '2026-07-01T00:00:00.000Z',
      'lastSeenAt': '2026-06-28T00:00:00.000Z',
    },
  ],
  'counts': {'devices': 2, 'adminGrants': 1, 'moderationReports': 0},
};

const _verification = {
  'ok': true,
  'user': {'id': 'u-1', 'handle': 'rowan', 'displayName': 'Rowan Ellis'},
  'activeClasses': ['IDENTITY'],
  'history': [
    {
      'verificationClass': 'IDENTITY',
      'state': 'VERIFIED',
      'reason': 'Government photo identification checked against the profile.',
      'grantedAt': '2026-05-04T00:00:00.000Z',
    },
    {
      'verificationClass': 'ROLE_OR_CREDENTIAL',
      'state': 'REVOKED',
      'reason': 'The claimed office could not be substantiated on review.',
      'revokedAt': '2026-06-11T00:00:00.000Z',
    },
  ],
};

const _grants = [
  {
    'id': 'g-1',
    'role': 'MODERATOR',
    'status': 'ACTIVE',
    'permissions': ['MODERATION_READ', 'MODERATION_WRITE'],
    'grantedAt': '2026-05-01T00:00:00.000Z',
    'userId': 'u-1',
    'user': {'id': 'u-1', 'handle': 'rowan', 'displayName': 'Rowan Ellis'},
    'grantedBy': {'id': 'op-1', 'displayName': 'The Owner'},
  },
];

const _audit = [
  {
    'id': 'a-1',
    'action': 'admin.grant.revoked',
    'actorUserId': 'op-1',
    'targetType': 'ADMIN_GRANT',
    'targetId': 'g-9',
    'result': 'SUCCESS',
    'createdAt': '2026-08-30T11:00:00.000Z',
    'actor': {'displayName': 'The Owner', 'handle': 'owner'},
    'reason': 'Left the moderation rota.',
  },
  {
    'id': 'a-2',
    'action': 'admin.institution_domain.approved',
    'actorUserId': 'op-1',
    'targetType': 'INSTITUTION_DOMAIN',
    'targetId': 'd-2',
    'result': 'SUCCESS',
    'createdAt': '2026-08-29T15:20:00.000Z',
    'actor': {'displayName': 'The Owner', 'handle': 'owner'},
  },
];

const _settings = [
  {'key': 'platform.name', 'value': 'Aura'},
  {'key': 'media.retention.days', 'value': 365},
];

const _flags = [
  {
    'key': 'compose.link_intelligence',
    'enabled': true,
    'description': 'Link previews in the composer.',
  },
  {
    'key': 'realtime.sfu_grid',
    'enabled': false,
    'description': 'Grid stage for multi-party calls.',
  },
];

const _policies = {
  'institutionPolicy': {
    'requireEmailVerification': true,
    'requireDnsVerification': true,
    'allowProvisionalActive': false,
    'autoApproveVerified': false,
  },
  'securityPolicy': {
    'maxLoginAttempts': 5,
    'sessionTimeoutMinutes': 43200,
    'requireMfa': false,
  },
  'communicationsPolicy': {
    'maxEmailsPerDay': 2000,
    'digestEnabled': true,
    'digestFrequency': 'WEEKLY',
    'unsubscribeEnabled': true,
    'senderEmail': 'no-reply@auraplatform.org',
  },
  'featurePolicy': {
    'betaOptInEnabled': true,
    'maintenanceMode': false,
    'publicRegistrationEnabled': true,
    'inviteOnlyMode': false,
  },
};

const _domains = [
  {
    'id': 'dm-1',
    'institutionId': 'inst-1',
    'domain': 'civic.example',
    'organizationName': 'Civic Institute',
    'status': 'PENDING',
    'requestedBy': 'u-ada',
    'createdAt': '2026-08-20T00:00:00.000Z',
  },
];

const _reports = [
  {
    'id': 'r-1',
    'targetType': 'POST',
    'targetId': 'p-77',
    'reason': 'Harassment',
    'status': 'OPEN',
    'createdAt': '2026-08-12T09:00:00.000Z',
    'updatedAt': '2026-08-12T09:00:00.000Z',
    'details': 'They keep replying to every post I write with the same insult.',
    'reporter': {'displayName': 'Sam Iyer', 'handle': 'sam'},
    'actions': [
      {
        'id': 'ma-1',
        'actionType': 'NOTE',
        'targetType': 'POST',
        'targetId': 'p-77',
        'createdAt': '2026-08-13T09:00:00.000Z',
        'note': 'Read the thread; asked a second moderator to look.',
        'moderator': {'displayName': 'The Owner', 'handle': 'owner'},
      },
    ],
  },
];

const _appeals = [
  {
    'id': 'ap-1',
    'mediaId': 'md-3',
    'status': 'SUBMITTED',
    'standingBasis': 'UPLOADER',
    'appellantUserId': 'u-1',
    'statement': 'This is our own printed brochure. Nothing in it is unsafe.',
    'submittedAt': '2026-08-29T09:00:00.000Z',
    'media': {
      'fileName': 'brochure.pdf',
      'mimeType': 'application/pdf',
      'quarantineReason': 'Scanner reported an embedded script object.',
      'quarantineSource': 'clamav',
    },
  },
];

const _feedback = {
  'id': 'fb-1',
  'ref': 'AF-7QK2',
  'intent': 'DEFECT',
  'state': 'RECEIVED',
  'message': 'Calls never ring on my Pixel unless the app is already open.',
  'product': 'Aura',
  'platform': 'android',
  'appVersion': '1.4.0',
  'surface': '/messages/c/:id',
  'releaseChannel': 'production',
  'submittedAt': '2026-08-30T09:00:00.000Z',
  'user': {'displayName': 'Rowan Ellis', 'handle': 'rowan'},
};

const _supportCase = {
  'id': 'sc-1',
  'ref': 'SC-4821',
  'status': 'OPEN',
  'category': 'ACCOUNT',
  'severity': 'HIGH',
  'subject': 'Cannot sign in after changing my email',
  'requesterName': 'Sam Iyer',
  'requesterEmail': 'sam@example.test',
  'aiSummary': 'Sign-in fails after an email change; likely an unverified '
      'address on the new record.',
  'createdAt': '2026-08-28T09:00:00.000Z',
  'messages': [
    {
      'id': 'sm-1',
      'role': 'user',
      'content': 'I changed my email yesterday and now nothing lets me in.',
      'createdAt': '2026-08-28T09:00:00.000Z',
    },
    {
      'id': 'sm-2',
      'role': 'assistant',
      'content': 'Thanks — checking whether the new address was verified.',
      'createdAt': '2026-08-28T09:01:00.000Z',
    },
    {
      'id': 'sm-3',
      'role': 'admin',
      'content': 'I have resent the verification email to the new address.',
      'createdAt': '2026-08-28T11:30:00.000Z',
    },
  ],
};

const _coverage = {
  'estate': 'AURA',
  'published': 4102,
  'advertisedTotal': 19,
  'advertisedFromInventory': 0,
  'observed': 38,
  'indexed': 12,
  'families': [
    {'family': 'ARTICLE', 'published': 61, 'advertised': 0, 'observed': 9},
    {'family': 'INSTITUTION', 'published': 38, 'advertised': 0, 'observed': 6},
    {'family': 'PERSON', 'published': 3990, 'advertised': 0, 'observed': 21},
    {'family': 'ANNOUNCEMENT', 'published': 13, 'advertised': 0, 'observed': 2},
  ],
};

const _sources = [
  {
    'source': 'SITEMAP',
    'available': true,
    'lastFetchedAt': '2026-08-31T06:00:00.000Z',
  },
  {
    'source': 'CRAWLER_FETCH',
    'available': true,
    'lastFetchedAt': '2026-08-31T06:00:00.000Z',
  },
  {
    'source': 'GOOGLE_SEARCH_CONSOLE',
    'available': false,
    'reason': 'No adapter is configured for this estate.',
  },
  {
    'source': 'BING_WEBMASTER',
    'available': false,
    'reason': 'No adapter is configured for this estate.',
  },
  {
    'source': 'INDEXNOW',
    'available': false,
    'reason': 'No adapter is configured for this estate.',
  },
  {
    'source': 'AURA_REFERRAL',
    'available': false,
    'reason': 'No adapter is configured for this estate.',
  },
];

const _discoveryObjects = [
  {
    'canonicalUrl': 'https://auraplatform.org/p/art/institutional-trust',
    'objectFamily': 'ARTICLE',
    'visibility': 'UNOBSERVED',
    'impressions': 0,
    'clicks': 0,
    'sources': <String>[],
    'publishedAt': '2026-07-01T00:00:00.000Z',
  },
  {
    'canonicalUrl': 'https://auraplatform.org/p/org/civic-institute',
    'objectFamily': 'INSTITUTION',
    'visibility': 'UNREACHABLE',
    'impressions': 0,
    'clicks': 0,
    'sources': ['CRAWLER_FETCH'],
    'publishedAt': '2026-02-01T00:00:00.000Z',
  },
  {
    'canonicalUrl': 'https://auraplatform.org/p/u/rowan',
    'objectFamily': 'PERSON',
    'visibility': 'REACHABLE',
    'impressions': 41,
    'clicks': 3,
    'sources': ['CRAWLER_FETCH', 'SITEMAP'],
    'publishedAt': '2026-03-01T00:00:00.000Z',
  },
];

const _queries = [
  {'query': 'aura platform', 'impressions': 412, 'clicks': 38},
  {'query': 'civic institute detroit', 'impressions': 96, 'clicks': 11},
  {'query': '[email] aura login', 'impressions': 22, 'clicks': 1},
];

/// Retention with something to report. `failed` and `unresolvedKey` are the
/// whole reason the surface exists, so the fixture carries them.
const _retentionStatus = {
  'hasRun': true,
  'orphaned': 46,
  'pendingDeletion': 12,
  'lastRun': {
    'trigger': 'scheduled',
    'finishedAt': '2026-08-31T03:04:11.000Z',
    'dryRun': false,
    'deletedObjects': 31,
    'skippedReferenced': 9,
    'failed': 2,
    'unresolvedKey': 1,
    'orphanRetentionDays': 7,
  },
};

const _retention = {
  'rawRows': 8814,
  'observations': 1220,
  'oldestRawFetchedAt': '2026-06-04T00:00:00.000Z',
  'rawRetentionDays': 90,
  'observationRetentionMonths': 24,
};
