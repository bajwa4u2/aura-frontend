import 'package:dio/dio.dart';

class CommunicationPreferencesRepository {
  CommunicationPreferencesRepository(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> load() async {
    final res = await _dio.get('/communications/preferences/me');
    return loadFromRaw(res.data);
  }

  Map<String, dynamic> loadFromRaw(dynamic raw) {
    return _normalizePreferences(raw);
  }

  Future<Map<String, dynamic>> save(Map<String, dynamic> patch) async {
    final res = await _dio.post(
      '/communications/preferences/me',
      data: patch,
    );
    return _normalizePreferences(res.data);
  }

  Map<String, dynamic> _normalizePreferences(dynamic raw) {
    final root = _asMap(raw);
    final data = _asMap(root['data']);
    final prefs = _firstNonEmptyMap([
      _asMap(root['preferences']),
      _asMap(data['preferences']),
      data,
      root,
    ]);

    return <String, dynamic>{
      'inAppEnabled': _asBool(prefs['inAppEnabled'], fallback: true),
      'emailEnabled': _asBool(prefs['emailEnabled'], fallback: true),
      'emailMessageReceived': _asBool(prefs['emailMessageReceived'], fallback: true),
      'emailInviteReceived': _asBool(prefs['emailInviteReceived'], fallback: true),
      'emailInviteResponded': _asBool(prefs['emailInviteResponded'], fallback: true),
      'emailAnnouncementPublished': _asBool(prefs['emailAnnouncementPublished'], fallback: true),
      'emailSystem': _asBool(
        _firstNonNull([
          prefs['emailSystem'],
          prefs['emailSystemNotice'],
          prefs['emailWelcome'],
        ]),
        fallback: true,
      ),
    };
  }
}

Map<String, dynamic> _asMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return <String, dynamic>{};
}

Map<String, dynamic> _firstNonEmptyMap(List<Map<String, dynamic>> candidates) {
  for (final candidate in candidates) {
    if (candidate.isNotEmpty) return candidate;
  }
  return <String, dynamic>{};
}

dynamic _firstNonNull(List<dynamic> values) {
  for (final value in values) {
    if (value != null) return value;
  }
  return null;
}

bool _asBool(dynamic raw, {required bool fallback}) {
  if (raw is bool) return raw;
  if (raw is num) return raw != 0;
  final text = (raw ?? '').toString().trim().toLowerCase();
  if (text.isEmpty) return fallback;
  if (text == 'true' || text == '1' || text == 'yes' || text == 'on') return true;
  if (text == 'false' || text == '0' || text == 'no' || text == 'off') return false;
  return fallback;
}
