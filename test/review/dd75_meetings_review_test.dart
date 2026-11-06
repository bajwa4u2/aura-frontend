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
import 'package:aura/features/meetings/data/availability_repository.dart';
import 'package:aura/features/meetings/data/meetings_repository.dart';
import 'package:aura/features/meetings/domain/availability_profile.dart';
import 'package:aura/features/meetings/domain/meeting.dart';
import 'package:aura/features/meetings/domain/meeting_agenda_item.dart';
import 'package:aura/features/meetings/presentation/create_meeting_screen.dart';
import 'package:aura/features/meetings/presentation/institution_availability_screen.dart';
import 'package:aura/features/meetings/presentation/meeting_detail_screen.dart';
import 'package:aura/features/updates/notifications_repository.dart';
import 'package:aura/features/updates/providers.dart';

/// DD-75 REVIEW PICTURES — meetings Phase E (6 Nov 2026): answers in the
/// list, recurring series, follow-ups, agenda points, co-hosts, booking-page
/// numbers. Same harness as DD-74: nothing compared, skipped unless
/// DD75_SHOTS names a folder.
///
///   DD75_SHOTS=../docs/meetings/dd75 flutter test test/review/dd75_meetings_review_test.dart
void main() {
  final shots = Platform.environment['DD75_SHOTS'];

  final when = DateTime(2026, 11, 12, 15, 0);

  Map<String, dynamic> person(String id, String name) =>
      {'id': id, 'displayName': name, 'handle': id};

  Map<String, dynamic> participant(
          String id, String name, String role, String rsvp,
          {bool attended = false}) =>
      {
        'id': 'p-$id',
        'meetingId': 'm1',
        'userId': id,
        'role': role,
        'rsvpStatus': rsvp,
        'attended': attended,
        'user': person(id, name),
      };

  Map<String, dynamic> meeting({String state = 'SCHEDULED', bool series = true}) => {
        'id': 'm1',
        'title': 'Kitchen remodel consultation',
        'description':
            'Walk through the layout, cabinet options and a first budget.',
        'meetingCode': 'KRC482',
        'joinUrl': 'https://auraplatform.org/meetings/join/KRC482',
        'state': state,
        'type': series ? 'RECURRING' : 'SCHEDULED',
        'scheduledAt': when.toUtc().toIso8601String(),
        'durationMinutes': 45,
        'timezone': 'America/Detroit',
        'organizationId': 'org1',
        'recordingEnabled': true,
        if (series) 'seriesId': 'm0',
        if (series) 'recurringRule': 'FREQ=WEEKLY;COUNT=6',
        'preparationNotes': 'Bring the current kitchen photos.',
        'host': person('daniel', 'Daniel Reyes'),
        'institution': {
          'id': 'org1',
          'name': 'Northline Builders',
          'slug': 'northline-builders',
        },
        'participants': [
          participant('daniel', 'Daniel Reyes', 'HOST', 'ACCEPTED',
              attended: state == 'ENDED'),
          participant('lena', 'Lena Park', 'CO_HOST', 'ACCEPTED',
              attended: state == 'ENDED'),
          participant('amira', 'Amira Khan', 'PARTICIPANT', 'ACCEPTED',
              attended: state == 'ENDED'),
          participant('sam', 'Sam Ortiz', 'PARTICIPANT', 'DECLINED'),
          participant('omar', 'Omar Haddad', 'PARTICIPANT', 'PENDING'),
        ],
      };

  const agenda = [
    MeetingAgendaItem(
        id: 'i1', text: 'Current layout and what must stay', position: 0, covered: true),
    MeetingAgendaItem(
        id: 'i2', text: 'Cabinet finishes: oak or painted', position: 1, covered: false),
    MeetingAgendaItem(
        id: 'i3', text: 'First budget range', position: 2, covered: false),
  ];

  Future<void> pump(WidgetTester tester, Size size, GlobalKey key, Widget home,
      {List<Override> overrides = const []}) async {
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
    await _settle(tester);
  }

  Future<void> save(WidgetTester tester, GlobalKey key, String name) async {
    await _settle(tester);
    final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final png = await tester.binding.runAsync(() async {
      final image = await b.toImage(pixelRatio: 2.0);
      return image.toByteData(format: ui.ImageByteFormat.png);
    });
    Directory(shots!).createSync(recursive: true);
    File('$shots/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  }

  List<Override> detail(Map<String, dynamic> json, String me,
          {bool manager = false}) =>
      [
        meetingsRepositoryProvider.overrideWithValue(_Meetings(json, agenda)),
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

  Widget page() => const Scaffold(
        body: MeetingDetailScreen(meetingId: 'm1', institutionId: 'org1'),
      );

  const phone = Size(390, 844);
  const phoneLong = Size(390, 2000);
  const desk = Size(1280, 800);
  const sizes = [(phone, '390x844'), (phoneLong, '390x2000_full'), (desk, '1280x800')];

  testWidgets('DD-75 meetings review pictures', (tester) async {
    await _loadFonts();

    final views = <String, List<Override>>{
      'host_upcoming_series': detail(meeting(), 'daniel'),
      'cohost_upcoming': detail(meeting(), 'lena'),
      'participant_upcoming': detail(meeting(), 'amira'),
      'host_after_meeting': detail(meeting(state: 'ENDED', series: false), 'daniel'),
    };
    for (final v in views.entries) {
      for (final (size, label) in sizes) {
        final key = GlobalKey();
        await pump(tester, size, key, page(), overrides: v.value);
        await save(tester, key, 'meeting_${v.key}_$label');
      }
    }

    // "Make it an outcome" menu, after the meeting.
    var key = GlobalKey();
    await pump(tester, desk, key, page(),
        overrides: detail(meeting(state: 'ENDED', series: false), 'daniel'));
    await tester.ensureVisible(find.text('Make it an outcome').first);
    await tester.tap(find.text('Make it an outcome').first);
    await save(tester, key, 'agenda_make_outcome_menu_1280x800');

    // Co-host menu, as the host.
    key = GlobalKey();
    await pump(tester, desk, key, page(), overrides: detail(meeting(), 'daniel'));
    await tester.tap(find.byTooltip('Options for Amira Khan'));
    await save(tester, key, 'cohost_menu_1280x800');

    // Follow-up dialog and series cancel confirmation.
    for (final (size, label) in const [(phone, '390x844'), (desk, '1280x800')]) {
      key = GlobalKey();
      await pump(tester, size, key, page(), overrides: detail(meeting(), 'daniel'));
      await tester.ensureVisible(find.text('Schedule a follow-up'));
      await tester.tap(find.text('Schedule a follow-up'));
      await save(tester, key, 'dialog_follow_up_$label');
    }
    key = GlobalKey();
    // Tall enough that the button (bottom of the page) is on screen to tap.
    await pump(tester, const Size(390, 2600), key, page(),
        overrides: detail(meeting(), 'daniel'));
    await tester.tap(find.text('Cancel this and later meetings'));
    await save(tester, key, 'dialog_cancel_series_390x2600');

    // Create meeting: Repeat weekly, How many times.
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
    await tester.ensureVisible(find.text('Does not repeat'));
    await tester.tap(find.text('Does not repeat'));
    await _settle(tester);
    await tester.tap(find.text('Weekly').last);
    await _settle(tester);
    await tester.ensureVisible(find.text('How many times'));
    await save(tester, key, 'create_meeting_repeat_390x844');

    // Booking pages with their numbers.
    for (final (size, label) in const [(phone, '390x844'), (desk, '1280x800')]) {
      key = GlobalKey();
      await pump(
        tester,
        size,
        key,
        const Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: InstitutionBookingPages(institutionId: 'org1'),
          ),
        ),
        overrides: [
          availabilityRepositoryProvider.overrideWithValue(_Availability()),
          institutionsRepositoryProvider.overrideWithValue(_Institutions()),
          institutionProfilesProvider.overrideWith((ref, id) async => [
                AvailabilityProfile.fromJson({
                  'id': 'p1',
                  'name': 'Remodel consultation',
                  'slug': 'remodel-consultation',
                  'meetingTitle': 'Kitchen or bath remodel consultation',
                  'durationOptions': [30, 45, 60],
                  'defaultDuration': 45,
                  'timezone': 'America/Detroit',
                  'institutionId': 'org1',
                  'windows': [
                    {'id': 'w1', 'dayOfWeek': 'TUE', 'startTime': '09:00', 'endTime': '17:00'},
                  ],
                }),
              ]),
        ],
      );
      await save(tester, key, 'booking_page_numbers_$label');
    }

    await tester.pumpWidget(const SizedBox());
  }, skip: shots == null || shots.isEmpty);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

class _Meetings extends MeetingsRepository {
  _Meetings(this.json, this.agenda) : super(Dio());
  final Map<String, dynamic> json;
  final List<MeetingAgendaItem> agenda;

  @override
  Future<Meeting> getMeeting(String id) async => Meeting.fromJson(json);

  @override
  Future<List<MeetingAgendaItem>> listAgenda(String meetingId) async => agenda;
}

class _Availability extends AvailabilityRepository {
  _Availability() : super(Dio());

  @override
  Future<BookingPageStats> getInstitutionProfileStats(
          String institutionId, String profileId) async =>
      const BookingPageStats(
        days: 90,
        booked: 14,
        upcoming: 3,
        held: 8,
        noShow: 1,
        cancelledByBooker: 1,
        cancelledByHost: 1,
      );
}

class _Notifications extends NotificationsRepository {
  _Notifications() : super(Dio());

  @override
  Future<NotificationsPage> page(
          {int limit = 30, String? cursor, bool forceRefresh = false}) async =>
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
            ('lena', 'Lena Park'),
            ('sam', 'Sam Ortiz'),
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
      loader.addFont(
          Future.value(ByteData.view(File(f).readAsBytesSync().buffer)));
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
  Directory? fonts;
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
    if (c.existsSync()) {
      fonts = c;
      break;
    }
  }
  if (fonts != null) {
    await family('Roboto', [
      for (final w in ['regular', 'medium', 'bold'])
        '${fonts.path}/roboto-$w.ttf',
    ]);
    final icons = File('${fonts.path}/materialicons-regular.otf');
    if (icons.existsSync()) await family('MaterialIcons', [icons.path]);
  }
}
