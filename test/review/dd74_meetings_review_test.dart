import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/app/aura_app.dart' show auraAppTheme;
import 'package:aura/core/auth/session_providers.dart';
import 'package:aura/core/institutions/institution_access_provider.dart';
import 'package:aura/features/institutions/data/institutions_repository.dart';
import 'package:aura/features/institutions/domain/institution.dart';
import 'package:aura/features/meetings/application/meetings_provider.dart';
import 'package:aura/features/meetings/data/meetings_repository.dart';
import 'package:aura/features/meetings/domain/availability_profile.dart';
import 'package:aura/features/meetings/domain/meeting.dart';
import 'package:aura/features/meetings/presentation/create_meeting_screen.dart';
import 'package:aura/features/meetings/presentation/institution_availability_screen.dart';
import 'package:aura/features/meetings/presentation/invitation_decline_screen.dart';
import 'package:aura/features/meetings/presentation/meeting_detail_screen.dart';
import 'package:aura/features/updates/notifications_repository.dart';
import 'package:aura/features/updates/providers.dart';

/// DD-74 REVIEW PICTURES — meetings gaps, Phase C (6 Nov 2026).
///
/// Not a golden: nothing is compared, so nothing can go brittle in CI. It is
/// skipped unless DD74_SHOTS names a folder, and then writes PNGs there:
///
///   DD74_SHOTS=../docs/meetings/dd74 flutter test test/review/dd74_meetings_review_test.dart
///
/// Real fonts are loaded (AuraSerif, AuraSans from assets/fonts; Roboto and
/// Material Icons from the Flutter SDK cache), not the test font. The app is
/// dark-only (ThemeMode.dark), so every picture uses the app's one theme.
void main() {
  final shots = Platform.environment['DD74_SHOTS'];

  // ── Sample data ───────────────────────────────────────────────────────
  final when = DateTime(2026, 11, 12, 15, 0);

  Map<String, dynamic> person(String id, String name) =>
      {'id': id, 'displayName': name, 'handle': id};

  Map<String, dynamic> participant(String id, String name, String role,
          String rsvp) =>
      {
        'id': 'p-$id',
        'meetingId': 'm1',
        'userId': id,
        'role': role,
        'rsvpStatus': rsvp,
        'user': person(id, name),
      };

  Map<String, dynamic> meeting({
    String amiraRsvp = 'PENDING',
    int duration = 45,
  }) =>
      {
        'id': 'm1',
        'title': 'Kitchen remodel consultation',
        'description':
            'Walk through the layout, cabinet options and a first budget.',
        'meetingCode': 'KRC482',
        'joinUrl': 'https://auraplatform.org/meetings/join/KRC482',
        'state': 'SCHEDULED',
        'type': 'SCHEDULED',
        'scheduledAt': when.toUtc().toIso8601String(),
        'durationMinutes': duration,
        'timezone': 'America/Detroit',
        'organizationId': 'org1',
        'recordingEnabled': true,
        'preparationNotes':
            'Current kitchen photos\nPreferred cabinet finishes\nBudget range',
        'host': person('daniel', 'Daniel Reyes'),
        'institution': {
          'id': 'org1',
          'name': 'Northline Builders',
          'slug': 'northline-builders',
        },
        'participants': [
          participant('daniel', 'Daniel Reyes', 'HOST', 'ACCEPTED'),
          participant('amira', 'Amira Khan', 'PARTICIPANT', amiraRsvp),
          participant('sam', 'Sam Ortiz', 'PARTICIPANT', 'ACCEPTED'),
        ],
      };

  // ── Harness ───────────────────────────────────────────────────────────
  Future<void> pump(
    WidgetTester tester,
    Size size,
    GlobalKey key,
    Widget home, {
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: auraAppTheme(),
          home: home,
        ),
      ),
    ));
    await settle(tester);
  }

  Future<void> save(WidgetTester tester, GlobalKey key, String name) async {
    await settle(tester);
    final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final png = await tester.binding.runAsync(() async {
      final image = await b.toImage(pixelRatio: 2.0);
      return image.toByteData(format: ui.ImageByteFormat.png);
    });
    Directory(shots!).createSync(recursive: true);
    File('$shots/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  }

  List<Override> detailOverrides({
    required Map<String, dynamic> json,
    required String me,
    bool manager = false,
    Object? error,
  }) =>
      [
        meetingsRepositoryProvider
            .overrideWithValue(_Meetings(json, error: error)),
        meetingStateChangedEventProvider
            .overrideWith((ref) => const Stream.empty()),
        meetingAssetsProvider.overrideWith((ref, id) async => const []),
        authMeDataProvider.overrideWith((ref) async => {
              'user': {'id': me},
            }),
        isAuthedProvider.overrideWithValue(true),
        isGuestSessionProvider.overrideWithValue(false),
        notificationsRepoProvider.overrideWithValue(_Notifications()),
        myAffiliationsProvider.overrideWithValue(const []),
        institutionsRepositoryProvider.overrideWithValue(_Institutions()),
        institutionIdentityProvider.overrideWithValue(manager
            ? const InstitutionIdentity(
                id: 'org1',
                name: 'Northline Builders',
                slug: 'northline-builders',
                isAuthorizedSpeaker: false,
                capabilities: {InstitutionCapabilities.manageMeetings},
              )
            : null),
      ];

  Widget detail() => const Scaffold(
        body: MeetingDetailScreen(meetingId: 'm1', institutionId: 'org1'),
      );

  const phone = Size(390, 844);
  const phoneLong = Size(390, 1700);
  const desk = Size(1280, 800);

  testWidgets('DD-74 meetings review pictures', (tester) async {
    await _loadFonts();

    // Meeting page: (a) pending, (b) declined, (c) manager, (d) offline,
    // (e) server error.
    final cases = <String, List<Override>>{
      'a_invited_pending': detailOverrides(json: meeting(), me: 'amira'),
      'b_after_declining':
          detailOverrides(json: meeting(amiraRsvp: 'DECLINED'), me: 'amira'),
      'c_manager_controls':
          detailOverrides(json: meeting(), me: 'ops', manager: true),
      'd_offline': detailOverrides(
        json: meeting(),
        me: 'amira',
        error: DioException(
          requestOptions: RequestOptions(path: '/meetings/m1'),
          type: DioExceptionType.connectionError,
        ),
      ),
      'e_server_error': detailOverrides(
        json: meeting(),
        me: 'amira',
        error: DioException(
          requestOptions: RequestOptions(path: '/meetings/m1'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/meetings/m1'),
            statusCode: 503,
          ),
        ),
      ),
    };
    for (final entry in cases.entries) {
      for (final (size, label) in const [
        (phone, '390x844'),
        (phoneLong, '390x1700_full'),
        (desk, '1280x800'),
      ]) {
        if (entry.key.startsWith('d_') || entry.key.startsWith('e_')) {
          if (size == phoneLong) continue;
        }
        final key = GlobalKey();
        await pump(tester, size, key, detail(), overrides: entry.value);
        await save(tester, key, 'meeting_detail_${entry.key}_$label');
      }
    }

    // Reschedule dialog and edit dialog (75-minute meeting), as the host.
    for (final (size, label) in const [(phone, '390x844'), (desk, '1280x800')]) {
      var key = GlobalKey();
      await pump(tester, size, key, detail(),
          overrides: detailOverrides(json: meeting(duration: 75), me: 'daniel'));
      await tester.tap(find.text('Reschedule'));
      await save(tester, key, 'dialog_reschedule_$label');

      key = GlobalKey();
      await pump(tester, size, key, detail(),
          overrides: detailOverrides(json: meeting(duration: 75), me: 'daniel'));
      await tester.tap(find.text('Edit'));
      await settle(tester);
      await tester.ensureVisible(find.text('Recording allowed'));
      await save(tester, key, 'dialog_edit_recording_75min_$label');
    }

    // Booking page: Days off list, and the edit dialog.
    final pagesOverrides = <Override>[
      institutionsRepositoryProvider.overrideWithValue(_Institutions()),
      institutionProfilesProvider.overrideWith((ref, id) async => [_profile()]),
    ];
    Widget pages() => const Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: InstitutionBookingPages(institutionId: 'org1'),
          ),
        );
    var key = GlobalKey();
    await pump(tester, phone, key, pages(), overrides: pagesOverrides);
    await tester.tap(find.textContaining('Days off'));
    await settle(tester);
    await tester.ensureVisible(find.text('Add a day off'));
    await save(tester, key, 'booking_page_days_off_390x844');

    key = GlobalKey();
    await pump(tester, phone, key, pages(), overrides: pagesOverrides);
    await tester.tap(find.byTooltip('More'));
    await settle(tester);
    await tester.tap(find.text('Edit profile'));
    await settle(tester);
    await tester.ensureVisible(find.text('Meeting lengths guests can book'));
    await save(tester, key, 'booking_page_edit_lengths_timezone_390x844');

    // Invitation decline page: ask, then done.
    key = GlobalKey();
    await pump(tester, phone, key,
        const InvitationDeclineScreen(token: 'inv-tok'),
        overrides: [
          meetingsRepositoryProvider.overrideWithValue(_Meetings(meeting())),
        ]);
    await save(tester, key, 'invitation_decline_ask_390x844');
    await tester.tap(find.text('Decline invitation'));
    await save(tester, key, 'invitation_decline_done_390x844');

    // Create meeting: the Recording allowed switch.
    key = GlobalKey();
    await pump(
      tester,
      phone,
      key,
      const Material(child: CreateMeetingScreen(institutionId: 'org1')),
      overrides: [
        institutionsRepositoryProvider.overrideWithValue(_Institutions()),
        myAvailabilityProfilesProvider.overrideWith((ref) async => const []),
        currentBookingIdentityProvider.overrideWith((ref) async => null),
      ],
    );
    await tester.enterText(
        find.widgetWithText(TextField, 'Meeting title').first,
        'Kitchen remodel consultation');
    await tester.ensureVisible(find.text('Recording allowed'));
    await save(tester, key, 'create_meeting_recording_switch_390x844');

    await tester.pumpWidget(const SizedBox());
  }, skip: shots == null || shots.isEmpty);
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

AvailabilityProfile _profile() => AvailabilityProfile.fromJson({
      'id': 'p1',
      'name': 'Remodel consultation',
      'slug': 'remodel-consultation',
      'meetingTitle': 'Kitchen or bath remodel consultation',
      'durationOptions': [30, 45, 60],
      'defaultDuration': 45,
      'timezone': 'America/Detroit',
      'institutionId': 'org1',
      'isActive': true,
      'windows': [
        {'id': 'w1', 'dayOfWeek': 'TUE', 'startTime': '09:00', 'endTime': '17:00'},
        {'id': 'w2', 'dayOfWeek': 'THU', 'startTime': '09:00', 'endTime': '17:00'},
      ],
      'overrides': [
        {'id': 'o1', 'date': '2026-11-26T12:00:00.000Z', 'isBlocked': true},
        {'id': 'o2', 'date': '2026-12-24T12:00:00.000Z', 'isBlocked': true},
      ],
    });

class _Meetings extends MeetingsRepository {
  _Meetings(this.json, {this.error}) : super(Dio());
  final Map<String, dynamic> json;
  final Object? error;

  @override
  Future<Meeting> getMeeting(String id) async {
    final e = error;
    if (e != null) throw e;
    return Meeting.fromJson(json);
  }

  @override
  Future<void> declineInvitationByToken(String token) async {}
}

class _Notifications extends NotificationsRepository {
  _Notifications() : super(Dio());

  @override
  Future<NotificationsPage> page({
    int limit = 30,
    String? cursor,
    bool forceRefresh = false,
  }) async =>
      const NotificationsPage(items: [], nextCursor: null);

  @override
  Future<void> markReadForTarget({
    String? postId,
    String? institutionPostId,
    String? directThreadId,
    String? meetingId,
    String? announcementId,
    String? institutionId,
    String? threadId,
    List<String>? types,
  }) async {}
}

class _Institutions extends InstitutionsRepository {
  _Institutions() : super(Dio());

  @override
  Future<Institution> getById(String id) async => Institution(
        id: id,
        name: 'Northline Builders',
        slug: 'northline-builders',
        domain: 'northlinebuilders.com',
        jurisdiction: 'US',
        description: '',
        website: '',
        isVerified: true,
      );

  @override
  Future<Map<String, dynamic>> listMembers(String institutionId) async => {
        'callerRole': 'ADMIN',
        'members': [
          for (final (id, name) in const [
            ('daniel', 'Daniel Reyes'),
            ('sam', 'Sam Ortiz'),
            ('lena', 'Lena Park'),
          ])
            {
              'userId': id,
              'role': 'MEMBER',
              'user': {'id': id, 'displayName': name, 'handle': id},
            },
        ],
      };
}

Future<void> _loadFonts() async {
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      final bytes = File(f).readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  await family('AuraSerif', [
    'assets/fonts/SourceSerif4-500.ttf',
    'assets/fonts/SourceSerif4-600.ttf',
  ]);
  await family('AuraSans', [
    for (final f in Directory('assets/fonts').listSync().whereType<File>())
      if (f.path.contains('PublicSans')) f.path,
  ]);

  // Roboto (Material's default family for widgets the theme leaves unstyled)
  // and Material Icons, from the Flutter SDK's own cache.
  final fonts = _materialFontsDir();
  if (fonts != null) {
    await family('Roboto', [
      for (final w in ['regular', 'medium', 'bold'])
        '${fonts.path}/roboto-$w.ttf',
    ]);
    final icons = File('${fonts.path}/materialicons-regular.otf');
    if (icons.existsSync()) await family('MaterialIcons', [icons.path]);
  }
}

Directory? _materialFontsDir() {
  final root = Platform.environment['FLUTTER_ROOT'];
  final candidates = <Directory>[
    if (root != null) Directory('$root/bin/cache/artifacts/material_fonts'),
  ];
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 8; i++) {
    candidates.add(Directory('${dir.path}/material_fonts'));
    candidates.add(Directory('${dir.path}/artifacts/material_fonts'));
    dir = dir.parent;
  }
  for (final c in candidates) {
    if (c.existsSync()) return c;
  }
  return null;
}
