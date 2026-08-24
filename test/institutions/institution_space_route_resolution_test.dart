import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/institutions/institution_access_provider.dart';
import 'package:aura/core/institutions/institution_route_scope.dart';
import 'package:aura/core/institutions/institution_space_route_scope.dart';
import 'package:aura/core/net/dio_provider.dart';
import 'package:aura/features/institutions/spaces/institution_space_screen.dart';

/// REACHING AN INSTITUTION SPACE.
///
/// Measured in production on 2026-08-24: `/institution/:addr/spaces/:space`
/// sat on a bare "Loading" indefinitely and NEVER issued the Space screen's
/// own requests. The institution shell around it rendered correctly, and the
/// sibling list route at `/institution/:addr/spaces` resolved fine, so the
/// failure was somewhere in the two address boundaries the detail route adds.
///
/// Static reading could not separate the candidates, because all three of
/// them render the SAME bare word: `ProductState.loading` ignores its subject
/// and always renders "Loading". So this reproduces the chain with the real
/// widgets and a recording transport, and asks each boundary what it does.
void main() {
  const institutionId = 'inst-1';
  const slug = 'aura-platform-llc';
  const spaceSlug = 'conversation-certification';
  const spaceId = 'space-1';

  InstitutionAccess memberOf() => const InstitutionAccess(
        state: InstitutionAccessState.verifiedMember,
        memberships: [
          MemberAffiliation(
            id: institutionId,
            name: 'Aura Platform',
            slug: slug,
            role: 'OWNER',
            canSpeakOfficially: true,
            isVerified: true,
          ),
        ],
      );

  Future<ProviderContainer> pump(
    WidgetTester tester,
    Widget child,
    _RecordingAdapter adapter,
  ) async {
    final container = ProviderContainer(overrides: [
      institutionAccessProvider.overrideWith((ref) => memberOf()),
      dioProvider.overrideWith((ref) {
        final dio = Dio(BaseOptions(baseUrl: 'https://api.test/v1'));
        dio.httpClientAdapter = adapter;
        return dio;
      }),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return container;
  }

  testWidgets('the institution boundary resolves a slug it holds locally',
      (tester) async {
    final adapter = _RecordingAdapter();
    String? gave;
    await pump(
      tester,
      InstitutionRouteScope(
        address: slug,
        builder: (id) {
          gave = id;
          return const Text('reached');
        },
      ),
      adapter,
    );

    expect(gave, institutionId,
        reason: 'a slug in the membership snapshot must resolve locally');
    expect(adapter.paths, isEmpty,
        reason: 'and must not need the server to do it');
  });

  testWidgets('the SPACE boundary asks the server and yields a space id',
      (tester) async {
    final adapter = _RecordingAdapter(
      responses: {
        '/institutions/$institutionId/spaces/by-address/$spaceSlug/entry': {
          'ok': true,
          'spaceId': spaceId,
          'canonicalSlug': spaceSlug,
          'matched': 'CANONICAL',
        },
      },
    );
    String? gave;
    await pump(
      tester,
      InstitutionSpaceRouteScope(
        institutionId: institutionId,
        address: spaceSlug,
        builder: (e) {
          gave = e.spaceId;
          return const Text('reached');
        },
      ),
      adapter,
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      adapter.paths,
      contains('/institutions/$institutionId/spaces/by-address/$spaceSlug/entry'),
      reason: 'the space entry boundary must actually ask',
    );
    expect(gave, spaceId);
  });

  testWidgets('THE WHOLE CHAIN reaches the Space, which then asks for it',
      (tester) async {
    // The production failure was of the chain, not of either boundary alone.
    final adapter = _RecordingAdapter(
      responses: {
        '/institutions/$institutionId/spaces/by-address/$spaceSlug/entry': {
          'ok': true,
          'spaceId': spaceId,
          'canonicalSlug': spaceSlug,
          'matched': 'CANONICAL',
        },
      },
    );
    String? reachedSpace;
    await pump(
      tester,
      InstitutionRouteScope(
        address: slug,
        builder: (id) => InstitutionSpaceRouteScope(
          institutionId: id,
          address: spaceSlug,
          builder: (e) {
            reachedSpace = e.spaceId;
            return const Text('reached');
          },
        ),
      ),
      adapter,
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(reachedSpace, spaceId,
        reason: 'the detail route must reach the Space it names');
  });

  testWidgets('the screen does NOT re-ask for what the boundary resolved',
      (tester) async {
    // The waterfall this removes: the boundary resolved the address, then the
    // screen fetched the Space again and its conversation id again, each trip
    // starting only after a widget mounted. Measured at ~18s to become usable
    // while every call took under 0.3s.
    final adapter = _RecordingAdapter();
    await pump(
      tester,
      InstitutionSpaceScreen(
        institutionId: institutionId,
        spaceId: spaceId,
        entry: const SpaceAddress(
          spaceId: spaceId,
          canonicalSlug: spaceSlug,
          isCanonical: true,
          space: {'id': spaceId, 'title': 'Certification'},
          conversationId: 'conv-1',
        ),
      ),
      adapter,
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      adapter.paths.where((p) => p.contains('/spaces/')),
      isEmpty,
      reason: 'entry state already arrived with the boundary answer',
    );
  });

  testWidgets('a caller WITHOUT a boundary answer still loads for itself',
      (tester) async {
    // The measured production symptom was that these two never happened: the
    // surface sat on "Loading" and no request for the Space itself was ever
    // issued.
    final adapter = _RecordingAdapter(
      responses: {
        '/institutions/$institutionId/spaces/$spaceId': {
          'ok': true,
          'space': {'id': spaceId, 'title': 'Conversation Certification'},
        },
        // Deliberately no conversation: the screen must then SAY so rather
        // than render an empty timeline that looks like silence.
        '/institutions/$institutionId/spaces/$spaceId/conversation': {
          'ok': true,
          'conversationId': null,
        },
      },
    );
    await pump(
      tester,
      InstitutionSpaceScreen(institutionId: institutionId, spaceId: spaceId),
      adapter,
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(adapter.paths, contains('/institutions/$institutionId/spaces/$spaceId'),
        reason: 'the Space screen must ask for its Space');
    expect(
      adapter.paths,
      contains('/institutions/$institutionId/spaces/$spaceId/conversation'),
      reason: 'and for the conversation that Space owns',
    );
  });
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({this.responses = const {}});

  final Map<String, Map<String, dynamic>> responses;
  final List<String> paths = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    final body = responses[options.path];
    if (body == null) {
      return ResponseBody.fromString(jsonEncode({'ok': false}), 404,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          });
    }
    return ResponseBody.fromString(jsonEncode(body), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
  }

  @override
  void close({bool force = false}) {}
}
