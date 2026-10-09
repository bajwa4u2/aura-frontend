import 'package:aura/core/navigation/return_path_frame.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
