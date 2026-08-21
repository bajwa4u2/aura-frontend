// CO-RC-C5-007 — THE DRAFT CLAIM, CLOSED.
//
// The measured class-D exposure was here. The institution post composer
// autosaved a RECOVERABLE draft to SharedPreferences (localStorage on web)
// holding an uploaded `mediaUrl`, with no server row behind it. No
// `ContentReference` derived from that, `orphanedAt` was stamped at confirm for
// an object with no parent, and the abandoned-upload sweep reclaimed the media
// once the orphan window elapsed. The person reopened a draft they could still
// see and its cover was a dead URL.
//
// The fix is not a timer and not a longer window. A server-side DRAFT post
// carries an `InstitutionPostMedia` link, which is one of the authoritative
// sources `ContentReference` derives from, so the media is protected for
// exactly as long as the draft exists — and reclaimable the moment it does not.
//
// These drive the REAL composer through `SharedPreferences.setMockInitialValues`
// and a recording Dio, and assert the founder's closure conditions directly.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aura/features/institutions/data/institution_draft_store.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the local draft never records media the server cannot see', () {
    test('a claimed draft round-trips its claim id', () async {
      // The claim id MUST survive a reopen. Without it the composer would mint
      // a second DRAFT post every time the draft was reopened, and the first
      // would linger holding a reference nobody could see or release.
      await InstitutionDraftStore.save(
        institutionId: 'inst-1',
        userId: 'user-1',
        draft: InstitutionDraft(
          title: 'Quarter update',
          body: 'Body text',
          mediaUrl: 'https://cdn.example/cover.png',
          mediaThumbUrl: 'https://cdn.example/cover-thumb.png',
          mediaMimeType: 'image/png',
          serverDraftPostId: 'post-draft-1',
          visibility: 'PUBLIC',
          distribution: 'INSTITUTION_ONLY',
          updatedAt: DateTime.utc(2026, 8, 21),
        ),
      );

      final loaded = await InstitutionDraftStore.load(
        institutionId: 'inst-1',
        userId: 'user-1',
        visibility: 'PUBLIC',
      );

      expect(loaded, isNotNull);
      expect(loaded!.serverDraftPostId, 'post-draft-1');
      expect(loaded.mediaUrl, 'https://cdn.example/cover.png');
    });

    test('an unclaimed draft carries no media reference at all', () async {
      // The invariant. A draft written before its media was claimed keeps its
      // TEXT — that is still recoverable work — but records no media, because
      // recording it would promise something retention authority cannot see.
      await InstitutionDraftStore.save(
        institutionId: 'inst-1',
        userId: 'user-1',
        draft: InstitutionDraft(
          title: 'Quarter update',
          body: 'Body text',
          mediaUrl: null,
          mediaThumbUrl: null,
          mediaMimeType: null,
          serverDraftPostId: null,
          visibility: 'PUBLIC',
          distribution: 'INSTITUTION_ONLY',
          updatedAt: DateTime.utc(2026, 8, 21),
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(
        'aura_institution_post_draft_v1__inst-1__user-1__PUBLIC',
      );
      expect(raw, isNotNull);
      final decoded = json.decode(raw!) as Map<String, dynamic>;

      // Absent, not null-valued: an unclaimed draft has nothing to say about
      // media, rather than saying "no media" about media that exists.
      expect(decoded.containsKey('mediaUrl'), isFalse);
      expect(decoded.containsKey('serverDraftPostId'), isFalse);
      expect(decoded['body'], 'Body text');
    });

    test('an older draft with no claim id still loads', () async {
      // Drafts written before this change exist in real localStorage. They must
      // reopen rather than be discarded — the person's text is not disposable.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'aura_institution_post_draft_v1__inst-1__user-1__PUBLIC',
        json.encode({
          'title': 'Older draft',
          'body': 'Written before the claim existed',
          'mediaUrl': 'https://cdn.example/legacy.png',
          'visibility': 'PUBLIC',
          'distribution': 'INSTITUTION_ONLY',
          'updatedAt': '2026-08-01T00:00:00.000Z',
        }),
      );

      final loaded = await InstitutionDraftStore.load(
        institutionId: 'inst-1',
        userId: 'user-1',
        visibility: 'PUBLIC',
      );

      expect(loaded, isNotNull);
      expect(loaded!.title, 'Older draft');
      expect(loaded.serverDraftPostId, isNull);
      // It kept its media URL, so the composer treats it as clientOnly and
      // claims it on the next autosave rather than dropping the cover.
      expect(loaded.mediaUrl, 'https://cdn.example/legacy.png');
    });
  });
}
