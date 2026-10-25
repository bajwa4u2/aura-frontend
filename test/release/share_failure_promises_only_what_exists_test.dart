import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A FAILURE MESSAGE PROMISES ONLY WHAT EXISTS (2026-10-25).
///
/// When sharing to a Facebook Page or Instagram failed, the composer said
/// "Try again from the post." There is no way to share an already published
/// post to a Page or Instagram; sharing happens only while composing. The
/// message now points to what does exist: the post's Share menu and its link.
void main() {
  test('the share-failure message does not send people to a missing action', () {
    final src = File('lib/features/posts/presentation/compose_screen.dart').readAsStringSync();
    expect(src, isNot(contains('Try again from the post')));
    expect(src, contains('copy its link from Share to post it there yourself'));
  });
}
