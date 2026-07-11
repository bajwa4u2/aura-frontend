import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:aura/features/meetings/data/availability_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'authenticated institution booking omits guest identity fields',
    () async {
      final adapter = _CaptureAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
        ..httpClientAdapter = adapter;
      final repo = AvailabilityRepository(dio);
      final scheduledAt = DateTime.utc(2026, 7, 11, 16);

      await repo.createInstitutionBooking(
        'aura-platform-llc',
        'founder-conversation',
        scheduledAt: scheduledAt,
        durationMinutes: 30,
        timezone: 'America/New_York',
      );

      expect(
        adapter.lastPath,
        '/i/aura-platform-llc/meet/founder-conversation',
      );
      expect(adapter.lastBody.containsKey('bookerName'), isFalse);
      expect(adapter.lastBody.containsKey('bookerEmail'), isFalse);
      expect(adapter.lastBody['scheduledAt'], scheduledAt.toIso8601String());
      expect(adapter.lastBody['durationMinutes'], 30);
    },
  );

  test('anonymous institution booking submits identity fields', () async {
    final adapter = _CaptureAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
      ..httpClientAdapter = adapter;
    final repo = AvailabilityRepository(dio);

    await repo.createInstitutionBooking(
      'aura-platform-llc',
      'founder-conversation',
      bookerName: 'Visitor',
      bookerEmail: 'visitor@example.com',
      scheduledAt: DateTime.utc(2026, 7, 11, 16),
      durationMinutes: 30,
      timezone: 'America/New_York',
    );

    expect(adapter.lastBody['bookerName'], 'Visitor');
    expect(adapter.lastBody['bookerEmail'], 'visitor@example.com');
  });
}

class _CaptureAdapter implements HttpClientAdapter {
  String? lastPath;
  Map<String, dynamic> lastBody = const {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastPath = options.path;
    lastBody = Map<String, dynamic>.from(options.data as Map);
    return ResponseBody.fromString(
      jsonEncode({
        'data': {
          'bookingId': 'booking-1',
          'meetingId': 'meeting-1',
          'meetingCode': 'ABC123',
          'joinUrl': 'https://aura.example/meetings/join/ABC123?bt=token',
          'cancelUrl': 'https://aura.example/meet/cancel/token',
          'scheduledAt': lastBody['scheduledAt'],
          'durationMinutes': lastBody['durationMinutes'],
          'timezone': lastBody['timezone'],
          'hostName': 'Host',
          'meetingTitle': 'Founder conversation',
        },
      }),
      201,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
