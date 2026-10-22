import 'package:aura/core/errors/client_error_reporter.dart';
import 'package:aura/core/errors/report_silently.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<Map<String, dynamic>> sent;
  ClientErrorReporter reporter({bool force = true}) => ClientErrorReporter(
        send: (body) async => sent.add(body),
        force: force,
        build: '1.7.0+46',
        platform: 'android',
      );

  setUp(() {
    sent = [];
    ClientErrorReporter.currentRoute = () => null;
  });
  tearDown(() => ReportSilentlySink.sink = (_, __, ___) {});

  test('a crash is sent with build, platform, stack and screen', () {
    ClientErrorReporter.currentRoute = () => '/posts/p1?token=secret';
    reporter().report(StateError('boom'), StackTrace.current, context: 'flutter');
    expect(sent, hasLength(1));
    final body = sent.single;
    expect(body['message'], contains('[flutter] StateError'));
    expect(body['build'], '1.7.0+46');
    expect(body['platform'], 'android');
    expect(body['stack'], isNotEmpty);
    expect(body['route'], '/posts/p1', reason: 'the query string never leaves');
  });

  test('nothing is sent outside release builds unless forced', () {
    reporter(force: false).report(StateError('boom'), null);
    expect(sent, isEmpty);
  });

  test('the same failure is sent once; at most ten per session', () {
    final r = reporter();
    r.report(StateError('same'), null);
    r.report(StateError('same'), null);
    expect(sent, hasLength(1));
    for (var i = 0; i < 20; i++) {
      r.report(StateError('different $i'), null);
    }
    expect(sent, hasLength(ClientErrorReporter.maxPerSession));
  });

  test('emails, tokens and long numbers are removed; sizes are capped', () {
    reporter().report(
      FormatException(
        'user amina@example.com Bearer abc.def eyJhbGc.eyJzdWI.sig 1234567890 '
        '${'x' * 3000}',
      ),
      null,
    );
    final message = sent.single['message'] as String;
    expect(message, isNot(contains('amina@example.com')));
    expect(message, isNot(contains('eyJhbGc')));
    expect(message, isNot(contains('abc.def')));
    expect(message, isNot(contains('1234567890')));
    expect(message.length, lessThanOrEqualTo(ClientErrorReporter.maxMessage));
  });

  test('a failing send never surfaces', () async {
    final r = ClientErrorReporter(
      send: (_) async => throw StateError('offline'),
      force: true,
      build: 'b',
      platform: 'p',
    );
    expect(() => r.report(StateError('x'), null), returnsNormally);
    await Future<void>.delayed(Duration.zero);
  });

  test('install routes reportSilently to the reporter', () {
    ClientErrorReporter.install(reporter: reporter());
    reportSilently(StateError('quiet'), null, 'app.registerCurrentDevice');
    expect(sent.single['message'], contains('[app.registerCurrentDevice]'));
  });
}
