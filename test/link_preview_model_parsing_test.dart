import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/announcements/domain/announcement.dart';
import 'package:aura/features/feed/domain/feed_item.dart';
import 'package:aura/features/feed/domain/post.dart';

/// Compose Link Intelligence / OG Preview -- Phase 1 (+ Announcement
/// extension).
///
/// Proves the three client-side content models (`Post`, used by
/// `post_card.dart`'s previously-dead `_finalAttachmentBlock`; `FeedItem`,
/// used by `unified_feed_card.dart`; and `Announcement`, used by
/// `announcement_detail_screen.dart`) correctly parse the flat
/// `linkUrl`/`linkTitle`/`linkDescription`/`linkImageUrl`/`linkSiteName`
/// fields the backend now returns -- this is the actual "activation" of
/// the previously-built-but-dead preview card: before this field existed
/// on `Post`, `post_card.dart`'s dynamic `dyn.linkUrl` read always threw
/// and was silently swallowed.
void main() {
  group('Post.fromJson link fields', () {
    test('parses all link fields from a READY preview response', () {
      final post = Post.fromJson({
        'id': 'p1',
        'authorId': 'u1',
        'text': 'check this out',
        'createdAt': '2026-08-12T00:00:00.000Z',
        'linkUrl': 'https://example.com/article?utm_source=x',
        'linkTitle': 'A Great Article',
        'linkDescription': 'Learn something new.',
        'linkImageUrl': 'https://example.com/cover.jpg',
        'linkSiteName': 'example.com',
      });

      expect(post.linkUrl, 'https://example.com/article?utm_source=x');
      expect(post.linkTitle, 'A Great Article');
      expect(post.linkDescription, 'Learn something new.');
      expect(post.linkImageUrl, 'https://example.com/cover.jpg');
      expect(post.linkSiteName, 'example.com');
    });

    test('linkUrl is present even when metadata is absent (plain-link fallback)', () {
      final post = Post.fromJson({
        'id': 'p1',
        'authorId': 'u1',
        'text': 'a link with no preview yet',
        'createdAt': '2026-08-12T00:00:00.000Z',
        'linkUrl': 'https://example.com',
        'linkTitle': null,
        'linkDescription': null,
        'linkImageUrl': null,
      });

      expect(post.linkUrl, 'https://example.com');
      expect(post.linkTitle, isNull);
    });

    test('all link fields are null when the post has no link', () {
      final post = Post.fromJson({
        'id': 'p1',
        'authorId': 'u1',
        'text': 'no link here',
        'createdAt': '2026-08-12T00:00:00.000Z',
      });

      expect(post.linkUrl, isNull);
      expect(post.linkTitle, isNull);
      expect(post.linkImageUrl, isNull);
    });

    test('copyWith preserves link fields when not explicitly overridden', () {
      final post = Post.fromJson({
        'id': 'p1',
        'authorId': 'u1',
        'text': 't',
        'createdAt': '2026-08-12T00:00:00.000Z',
        'linkUrl': 'https://example.com',
        'linkTitle': 'Title',
      });

      final copy = post.copyWith(text: 'edited text');

      expect(copy.linkUrl, 'https://example.com');
      expect(copy.linkTitle, 'Title');
      expect(copy.text, 'edited text');
    });
  });

  group('FeedItem.fromJson link fields', () {
    FeedItem buildItem(Map<String, dynamic> extra) {
      return FeedItem.fromJson({
        'id': 'f1',
        'type': 'INSTITUTION_POST',
        'authorType': 'INSTITUTION',
        'author': {'id': 'a1', 'type': 'institution', 'name': 'Test Inst', 'handleOrSlug': 'test'},
        'body': 'institution post body',
        'visibility': 'PUBLIC',
        'distribution': 'GLOBAL_ELIGIBLE',
        'status': 'PUBLISHED',
        'targetRoute': '/institution/i1/posts/f1',
        'interaction': <String, dynamic>{},
        ...extra,
      });
    }

    test('parses link fields for an institution post rendered via FeedItem/UnifiedFeedCard', () {
      final item = buildItem({
        'linkUrl': 'https://example.com/report',
        'linkTitle': 'Quarterly Report',
        'linkDescription': 'Full breakdown of Q3 results.',
        'linkImageUrl': 'https://example.com/report.png',
        'linkSiteName': 'example.com',
      });

      expect(item.linkUrl, 'https://example.com/report');
      expect(item.linkTitle, 'Quarterly Report');
      expect(item.linkDescription, 'Full breakdown of Q3 results.');
      expect(item.linkImageUrl, 'https://example.com/report.png');
      expect(item.linkSiteName, 'example.com');
    });

    test('is entirely null when no link is attached', () {
      final item = buildItem({});
      expect(item.linkUrl, isNull);
      expect(item.linkTitle, isNull);
    });
  });

  group('Announcement.fromJson link fields', () {
    Announcement buildAnnouncement(Map<String, dynamic> extra) {
      return Announcement.fromJson({
        'id': 'ann-1',
        'slug': 'a-slug',
        'title': 'An announcement',
        'summary': 'Summary',
        'excerpt': 'Summary',
        'bodyMarkdown': 'Body text',
        'pinned': false,
        ...extra,
      });
    }

    test('parses link fields for an announcement rendered via AnnouncementDetailScreen', () {
      final announcement = buildAnnouncement({
        'linkUrl': 'https://example.com/notice?utm_source=x',
        'linkTitle': 'Official Notice',
        'linkDescription': 'Details of this official notice.',
        'linkImageUrl': 'https://example.com/notice.png',
        'linkSiteName': 'example.com',
        'linkFaviconUrl': 'https://example.com/favicon.ico',
      });

      expect(announcement.linkUrl, 'https://example.com/notice?utm_source=x');
      expect(announcement.linkTitle, 'Official Notice');
      expect(announcement.linkDescription, 'Details of this official notice.');
      expect(announcement.linkImageUrl, 'https://example.com/notice.png');
      expect(announcement.linkSiteName, 'example.com');
      expect(announcement.linkFaviconUrl, 'https://example.com/favicon.ico');
    });

    test('linkUrl is present even when metadata is absent (plain-link fallback)', () {
      final announcement = buildAnnouncement({
        'linkUrl': 'https://example.com',
        'linkTitle': null,
        'linkImageUrl': null,
      });

      expect(announcement.linkUrl, 'https://example.com');
      expect(announcement.linkTitle, isNull);
    });

    test('is entirely null when no link is attached', () {
      final announcement = buildAnnouncement({});
      expect(announcement.linkUrl, isNull);
      expect(announcement.linkTitle, isNull);
      expect(announcement.linkImageUrl, isNull);
    });
  });
}
