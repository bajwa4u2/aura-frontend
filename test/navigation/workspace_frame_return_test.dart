import 'package:aura/core/navigation/return_path_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// DD-43 (2026-10-09): one way back in the institution workspace. Section
/// pages have none (the rail is the navigation); records and composers draw
/// their own "Back to <section>"; every other deeper route keeps the
/// governed affordance.
void main() {
  test('a workspace section page has no shell Back', () {
    for (final s in ['desk', 'public-engagement', 'explore', 'members', 'meetings', 'edit-profile', 'verification']) {
      expect(workspaceFrameOwnsReturn('/institution/city-of-taylor/$s'), isTrue, reason: s);
    }
  });

  test('records and composers draw their own Back', () {
    expect(workspaceFrameOwnsReturn('/institution/x/public-engagement/rec_1'), isTrue);
    expect(workspaceFrameOwnsReturn('/institution/x/public-engagement/participation'), isTrue);
    expect(workspaceFrameOwnsReturn('/institution/x/announcements/new'), isTrue);
    expect(workspaceFrameOwnsReturn('/institution/x/announcements/a1/edit'), isTrue);
    expect(workspaceFrameOwnsReturn('/institution/x/posts/new'), isTrue);
    expect(workspaceFrameOwnsReturn('/institution/x/posts/p1/edit'), isTrue);
    expect(workspaceFrameOwnsReturn('/institution/x/posts/p1'), isTrue);
  });

  test('other deeper routes and everything outside the workspace keep the shell Back', () {
    expect(workspaceFrameOwnsReturn('/institution/x/spaces/s1'), isFalse);
    expect(workspaceFrameOwnsReturn('/institutions/x'), isFalse);
    expect(workspaceFrameOwnsReturn('/messages/c/1'), isFalse);
    expect(workspaceFrameOwnsReturn('/institution/x'), isFalse);
  });

  // Seen live, 9 Oct 2026: reply to an institution post, cancel, and the
  // post page kept the composer's "Cancel" above its own Back, because the
  // address was read from where the browser was last sent, not from the
  // page now on top.
  testWidgets('after a pushed page is closed, the page on top is the one read', (tester) async {
    final router = GoRouter(
      initialLocation: '/institution/x/posts/p1',
      routes: [
        GoRoute(path: '/institution/x/posts/p1', builder: (_, __) => const Text('post')),
        GoRoute(path: '/compose', builder: (_, __) => const Text('compose')),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.push('/compose');
    await tester.pumpAndSettle();
    expect(livePath(router), '/compose');
    router.pop();
    await tester.pumpAndSettle();
    expect(livePath(router), '/institution/x/posts/p1');
  });
}
