/// Establishment Pass — one meeting-owned asset object for the whole
/// lifecycle: preparation materials (links / briefing files), files shared
/// during the meeting, and recordings. Assets are permanent parts of the
/// Meeting Record; guests only ever see guest-visible READY assets.
enum MeetingAssetKind {
  link,
  file,
  recording;

  static MeetingAssetKind parse(String? raw) {
    switch ((raw ?? '').toUpperCase()) {
      case 'FILE':
        return MeetingAssetKind.file;
      case 'RECORDING':
        return MeetingAssetKind.recording;
      default:
        return MeetingAssetKind.link;
    }
  }
}

class MeetingAsset {
  final String id;
  final String meetingId;
  final MeetingAssetKind kind;

  /// PREPARATION (briefing material) or MEETING (shared/captured live).
  final String stage;
  final String status;
  final String title;
  final String? url;
  final String? mimeType;
  final int? sizeBytes;
  final int? durationSeconds;
  final bool visibleToGuests;
  final String addedByName;
  final DateTime createdAt;

  const MeetingAsset({
    required this.id,
    required this.meetingId,
    required this.kind,
    required this.stage,
    required this.status,
    required this.title,
    this.url,
    this.mimeType,
    this.sizeBytes,
    this.durationSeconds,
    required this.visibleToGuests,
    required this.addedByName,
    required this.createdAt,
  });

  bool get isReady => status == 'READY';

  factory MeetingAsset.fromJson(Map<String, dynamic> j) => MeetingAsset(
        id: (j['id'] ?? '').toString(),
        meetingId: (j['meetingId'] ?? '').toString(),
        kind: MeetingAssetKind.parse(j['kind']?.toString()),
        stage: (j['stage'] ?? 'PREPARATION').toString(),
        status: (j['status'] ?? 'READY').toString(),
        title: (j['title'] ?? '').toString(),
        url: j['url'] as String?,
        mimeType: j['mimeType'] as String?,
        sizeBytes: (j['sizeBytes'] as num?)?.toInt(),
        durationSeconds: (j['durationSeconds'] as num?)?.toInt(),
        visibleToGuests: j['visibleToGuests'] as bool? ?? true,
        addedByName: (j['addedByName'] ?? '').toString(),
        createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString())
                ?.toLocal() ??
            DateTime.now(),
      );
}
