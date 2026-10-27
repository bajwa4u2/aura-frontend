import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/files/save_file_bytes.dart';
import 'package:aura/core/institutions/institution_access_provider.dart';
import 'package:aura/core/product/temporal.dart';
import 'package:aura/core/ui/aura_platform_components.dart';
import 'package:aura/features/institutions/profile/institution_profile_screen.dart';
import 'package:aura/features/me/data/data_export_repository.dart';
import 'package:aura/features/me/presentation/data_export_screen.dart';
import 'package:aura/features/me/presentation/widgets/data_export_panel.dart';

// DOWNLOAD MY DATA (2026-10-27): every state says what happened, plainly.
void main() {
  final file = ExportFile(
    bytes: Uint8List.fromList(utf8.encode('{}')),
    filename: 'aura-my-data-2026-10-27.json',
  );

  Future<void> pumpPanel(
    WidgetTester tester, {
    required ExportFetch fetch,
    ExportSave? save,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DataExportPanel(
          buttonLabel: 'Download my data',
          fetch: fetch,
          save: save ?? (_) async => const MediaSaveResult(MediaSaveStatus.saved, ''),
        ),
      ),
    ));
  }

  AuraPrimaryButton button(WidgetTester tester) =>
      tester.widget<AuraPrimaryButton>(find.byType(AuraPrimaryButton));

  testWidgets('saved: names the file', (tester) async {
    await pumpPanel(tester, fetch: () async => file);
    await tester.tap(find.text('Download my data'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Your data is saved as aura-my-data-2026-10-27.json.'), findsOneWidget);
  });

  testWidgets('preparing: the button is busy and cannot be pressed twice', (tester) async {
    final pending = Completer<ExportFile>();
    await pumpPanel(tester, fetch: () => pending.future);
    await tester.tap(find.text('Download my data'));
    await tester.pump();
    expect(find.text('Preparing your data…'), findsOneWidget);
    expect(button(tester).onPressed, isNull);
    pending.complete(file);
    await tester.pumpAndSettle();
  });

  testWidgets('save dialog closed: says nothing was saved', (tester) async {
    await pumpPanel(
      tester,
      fetch: () async => file,
      save: (_) async => const MediaSaveResult(MediaSaveStatus.cancelled, ''),
    );
    await tester.tap(find.text('Download my data'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nothing was saved.'), findsOneWidget);
  });

  testWidgets('once a day: says when, and the button rests', (tester) async {
    await pumpPanel(
      tester,
      fetch: () async => throw ExportOnceADay(DateTime(2026, 10, 28, 9, 41)),
    );
    await tester.tap(find.text('Download my data'));
    await tester.pumpAndSettle();
    expect(
      find.text('You can download your data again after ${AuraTemporal.fullShort(DateTime(2026, 10, 28, 9, 41))}.'),
      findsOneWidget,
    );
    expect(button(tester).onPressed, isNull);
  });

  testWidgets('once a day without a time: says tomorrow', (tester) async {
    await pumpPanel(tester, fetch: () async => throw const ExportOnceADay(null));
    await tester.tap(find.text('Download my data'));
    await tester.pumpAndSettle();
    expect(find.text('You can download your data again tomorrow.'), findsOneWidget);
  });

  testWidgets('failure: plain message and Retry, which works', (tester) async {
    var calls = 0;
    await pumpPanel(tester, fetch: () async {
      calls++;
      if (calls == 1) throw Exception('network');
      return file;
    });
    await tester.tap(find.text('Download my data'));
    await tester.pumpAndSettle();
    expect(find.text('Your data could not be prepared. Please try again.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Your data is saved as'), findsOneWidget);
  });

  testWidgets('the screen says what is and is not included before anything is pressed', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: DataExportScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text(DataExportScreen.intro), findsOneWidget);
    expect(find.text(DataExportScreen.excluded), findsOneWidget);
    expect(find.text(DataExportScreen.onceADay), findsOneWidget);
    expect(find.text('Download my data'), findsWidgets);
    expect(find.textContaining('JSON'), findsNothing);
  });

  testWidgets('the institution section offers its own download', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: InstitutionDataExportSection(institutionId: 'i1'))),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Your institution\'s data'), findsOneWidget);
    expect(find.text(InstitutionDataExportSection.intro), findsOneWidget);
    expect(find.text('Download this institution\'s data'), findsOneWidget);
  });

  test('only owners and administrators govern the institution (the section\'s gate)', () {
    InstitutionIdentity as(String? role) => InstitutionIdentity(
          id: 'i1', name: 'I', slug: 'i', isAuthorizedSpeaker: false,
          capabilities: const {}, role: role);
    expect(as('OWNER').governsInstitution, isTrue);
    expect(as('ADMIN').governsInstitution, isTrue);
    expect(as('MEMBER').governsInstitution, isFalse);
    expect(as(null).governsInstitution, isFalse);
  });

  test('reads the server\'s filename and once-a-day time', () {
    expect(
      DataExportRepository.filenameFrom('attachment; filename="aura-my-data-2026-10-27.json"', fallback: 'x'),
      'aura-my-data-2026-10-27.json',
    );
    expect(DataExportRepository.filenameFrom(null, fallback: 'aura-my-data-x.json'), 'aura-my-data-x.json');
    final body = utf8.encode(jsonEncode({
      'code': 'EXPORT_ONCE_A_DAY',
      'retryAt': '2026-10-28T13:41:00.000Z',
    }));
    expect(DataExportRepository.retryAtFrom(body), DateTime.utc(2026, 10, 28, 13, 41));
    expect(DataExportRepository.retryAtFrom('not json'), isNull);
  });
}
