import 'package:dio/dio.dart';

import 'domain/communications_models.dart';

class CommunicationsRepository {
  CommunicationsRepository(this._dio);

  final Dio _dio;

  Future<CommunicationPreferences> loadPreferences() async {
    final res = await _dio.get('/communications/preferences/me');
    return _parsePreferences(res.data);
  }

  Future<CommunicationPreferences> savePreferences(
    Map<String, dynamic> patch,
  ) async {
    final res = await _dio.post(
      '/communications/preferences/me',
      data: patch,
    );
    return _parsePreferences(res.data);
  }

  Future<DigestPreviewResult> previewDigest({
    required CommunicationFrequencyOption frequency,
  }) async {
    final res = await _dio.post(
      '/communications/digests/preview',
      data: {'frequency': frequency.value},
    );
    return _parseDigestPreview(frequency.value, res.data);
  }

  Future<DigestActionResult> createDigest({
    required CommunicationFrequencyOption frequency,
  }) async {
    final res = await _dio.post(
      '/communications/digests',
      data: {'frequency': frequency.value},
    );
    return DigestActionResult(
      frequency: frequency.value,
      raw: _asMap(res.data),
    );
  }

  Future<CommunicationRenderPreview> previewNewsletter({
    required String subject,
    required String headline,
    required String body,
    required String ctaLabel,
    required String ctaUrl,
  }) async {
    final res = await _dio.post(
      '/communications/newsletters/preview',
      data: {
        'subject': subject,
        'headline': headline,
        'body': body,
        'ctaLabel': ctaLabel,
        'ctaUrl': ctaUrl,
      },
    );
    return _parsePreview(res.data);
  }

  Future<NewsletterTestResult> testNewsletter({
    required String to,
    required String subject,
    required String headline,
    required String body,
    required String ctaLabel,
    required String ctaUrl,
  }) async {
    final res = await _dio.post(
      '/communications/newsletters/test',
      data: {
        'to': to,
        'subject': subject,
        'headline': headline,
        'body': body,
        'ctaLabel': ctaLabel,
        'ctaUrl': ctaUrl,
      },
    );
    final root = _asMap(res.data);
    return NewsletterTestResult(
      ok: _asBool(root['ok'], fallback: true),
      queued: _asBool(root['queued'], fallback: false),
      skipped: _asBool(root['skipped'], fallback: false),
      reason: _stringOf(root['reason']),
      outboxId: _stringOf(root['outboxId']),
      raw: root,
    );
  }

  Future<CommunicationDraftResult> createAiDraft({
    required String draftType,
    required String category,
    required String audience,
    required String goal,
    required String sourceText,
  }) async {
    final res = await _dio.post(
      '/communications/drafts/ai',
      data: {
        'draftType': draftType,
        'category': category,
        'audience': audience,
        'goal': goal,
        'sourceText': sourceText,
      },
    );
    final root = _asMap(res.data);
    final draft = _asMap(root['draft']);
    return CommunicationDraftResult(
      id: _stringOf(draft['id']),
      status: _stringOf(draft['status']),
      source: _stringOf(draft['source']),
      subject: _stringOf(draft['subject']),
      bodyText: _stringOf(draft['bodyText']),
      sendStatus: _stringOf(root['sendStatus']),
      raw: root,
    );
  }

  Future<CampaignCreationResult> createCampaign({
    required String name,
    required String category,
    required String audienceKind,
    required String subject,
    required String bodyText,
    required String ctaLabel,
    required String ctaUrl,
  }) async {
    final res = await _dio.post(
      '/communications/campaigns',
      data: {
        'name': name,
        'category': category,
        'audienceKind': audienceKind,
        'subject': subject,
        'bodyText': bodyText,
        'ctaLabel': ctaLabel,
        'ctaUrl': ctaUrl,
      },
    );
    final root = _asMap(res.data);
    final campaign = _asMap(root['campaign']);
    final draft = _asMap(root['draft']);
    return CampaignCreationResult(
      campaignId: _stringOf(campaign['id']),
      campaignStatus: _stringOf(campaign['status']),
      draftId: _stringOf(draft['id']),
      draftStatus: _stringOf(draft['status']),
      raw: root,
    );
  }

  Future<CommunicationRenderPreview> previewCampaignDraft(String draftId) async {
    final id = draftId.trim();
    final res = await _dio.post('/communications/campaigns/drafts/$id/preview');
    return _parsePreview(res.data);
  }

  Future<CampaignActionResult> approveCampaignDraft(String draftId) async {
    final id = draftId.trim();
    final res = await _dio.post('/communications/campaigns/drafts/$id/approve');
    final root = _asMap(res.data);
    return CampaignActionResult(
      status: _stringOf(root['status']),
      raw: root,
    );
  }

  Future<CampaignQueueResult> testCampaignDraft({
    required String draftId,
    required String to,
  }) async {
    final id = draftId.trim();
    final res = await _dio.post(
      '/communications/campaigns/drafts/$id/test',
      data: {'to': to},
    );
    final root = _asMap(res.data);
    return CampaignQueueResult(
      ok: _asBool(root['ok'], fallback: true),
      queued: _asBool(root['queued'], fallback: false),
      skipped: _asBool(root['skipped'], fallback: false),
      reason: _stringOf(root['reason']),
      outboxId: _stringOf(root['outboxId']),
      raw: root,
    );
  }

  CommunicationPreferences _parsePreferences(dynamic raw) {
    final root = _asMap(raw);
    final data = _asMap(root['data']);
    final prefs = _firstMap([
      _asMap(root['preferences']),
      _asMap(data['preferences']),
      data,
      root,
    ]);

    final channelKeys = <String, MapEntry<String, String>>{
      'social': const MapEntry('socialChannel', 'socialFrequency'),
      'messages': const MapEntry('messagesChannel', 'messagesFrequency'),
      'institutions': const MapEntry(
        'institutionsChannel',
        'institutionsFrequency',
      ),
      'announcements': const MapEntry(
        'announcementsChannel',
        'announcementsFrequency',
      ),
      'securityAuth': const MapEntry('securityChannel', 'securityFrequency'),
      'support': const MapEntry('supportChannel', 'supportFrequency'),
      'productUpdates': const MapEntry(
        'productUpdatesChannel',
        'productUpdatesFrequency',
      ),
      'newsletter': const MapEntry(
        'newsletterChannel',
        'newsletterFrequency',
      ),
      'digest': const MapEntry('digestChannel', 'digestFrequency'),
    };

    final groups = <String, CommunicationPreferenceGroup>{};

    for (final entry in _preferenceGroupDefinitions.entries) {
      final key = entry.key;
      final definition = entry.value;
      final fieldMap = channelKeys[key]!;
      final groupRaw = _asMap(prefs[key]);
      final channel = communicationChannelOptionFromRaw(
        _stringOf(groupRaw[fieldMap.key]).isNotEmpty
            ? _stringOf(groupRaw[fieldMap.key])
            : _stringOf(prefs[fieldMap.key]),
      );
      final frequency = communicationFrequencyOptionFromRaw(
        _stringOf(groupRaw[fieldMap.value]).isNotEmpty
            ? _stringOf(groupRaw[fieldMap.value])
            : _stringOf(prefs[fieldMap.value]),
      );

      groups[key] = CommunicationPreferenceGroup(
        key: key,
        title: definition.$1,
        subtitle: definition.$2,
        channel: channel,
        frequency: frequency,
        protected: definition.$3,
        raw: groupRaw,
      );
    }

    return CommunicationPreferences(
      raw: prefs,
      inAppEnabled: _asBool(
        _firstNonNull([
          prefs['inAppEnabled'],
          prefs['in_app_enabled'],
        ]),
        fallback: true,
      ),
      emailEnabled: _asBool(prefs['emailEnabled'], fallback: true),
      legacyFlags: <String, bool>{
        'emailMessageReceived': _asBool(
          prefs['emailMessageReceived'],
          fallback: true,
        ),
        'emailInviteReceived': _asBool(
          prefs['emailInviteReceived'],
          fallback: true,
        ),
        'emailInviteResponded': _asBool(
          prefs['emailInviteResponded'],
          fallback: true,
        ),
        'emailAnnouncementPublished': _asBool(
          prefs['emailAnnouncementPublished'],
          fallback: true,
        ),
        'emailSystem': _asBool(
          _firstNonNull([
            prefs['emailSystem'],
            prefs['emailSystemNotice'],
            prefs['emailWelcome'],
          ]),
          fallback: true,
        ),
      },
      groups: groups,
    );
  }

  DigestPreviewResult _parseDigestPreview(String frequency, dynamic raw) {
    final root = _asMap(raw);
    final data = _asMap(root['data']);
    final itemsRaw = _firstNonNull([
      root['items'],
      data['items'],
      root['notifications'],
      data['notifications'],
    ]);
    final items = _extractList(itemsRaw);

    return DigestPreviewResult(
      frequency: frequency,
      itemCount: _asInt(
        _firstNonNull([
          root['itemCount'],
          data['itemCount'],
          items.length,
        ]),
        fallback: items.length,
      ),
      subject: _stringOf(
        _firstNonNull([root['subject'], data['subject']]),
      ),
      previewText: _stringOf(
        _firstNonNull([root['previewText'], data['previewText']]),
      ),
      items: items,
      raw: root.isNotEmpty ? root : data,
    );
  }

  CommunicationRenderPreview _parsePreview(dynamic raw) {
    final root = _asMap(raw);
    final data = _asMap(root['data']);
    return CommunicationRenderPreview(
      subject: _stringOf(_firstNonNull([root['subject'], data['subject']])),
      previewText: _stringOf(
        _firstNonNull([root['previewText'], data['previewText']]),
      ),
      text: _stringOf(_firstNonNull([root['text'], data['text']])),
      html: _stringOf(_firstNonNull([root['html'], data['html']])),
      raw: root.isNotEmpty ? root : data,
    );
  }

  Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  Map<String, dynamic> _firstMap(List<Map<String, dynamic>> candidates) {
    for (final candidate in candidates) {
      if (candidate.isNotEmpty) return candidate;
    }
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _extractList(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
  }

  String _stringOf(dynamic value) {
    final text = (value ?? '').toString().trim();
    return text;
  }

  int _asInt(dynamic value, {required int fallback}) {
    if (value is int) return value;
    return int.tryParse(_stringOf(value)) ?? fallback;
  }

  bool _asBool(dynamic value, {required bool fallback}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = _stringOf(value).toLowerCase();
    if (text.isEmpty) return fallback;
    if (text == 'true' || text == '1' || text == 'yes' || text == 'on') {
      return true;
    }
    if (text == 'false' || text == '0' || text == 'no' || text == 'off') {
      return false;
    }
    return fallback;
  }

  dynamic _firstNonNull(List<dynamic> values) {
    for (final value in values) {
      if (value != null) return value;
    }
    return null;
  }
}

const Map<String, (String, String, bool)> _preferenceGroupDefinitions = {
  'social': ('Social', 'Replies, reposts, reactions, and follows.', false),
  'messages': ('Messages', 'Direct correspondence and thread messages.', false),
  'institutions': (
    'Institutions',
    'Space invites, member updates, and institutional activity.',
    false,
  ),
  'announcements': (
    'Announcements',
    'Official notices and public publishing signals.',
    false,
  ),
  'securityAuth': (
    'Security / auth',
    'Verification, password reset, and account protection notices.',
    true,
  ),
  'support': (
    'Support',
    'Contact replies, help follow-up, and transactional support notices.',
    true,
  ),
  'productUpdates': (
    'Product updates',
    'Release notes, account updates, and platform improvements.',
    false,
  ),
  'newsletter': (
    'Newsletter',
    'Broader product outreach and editorial updates.',
    false,
  ),
  'digest': (
    'Digest',
    'Grouped summaries of missed activity.',
    false,
  ),
};
