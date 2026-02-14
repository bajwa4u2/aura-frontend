class NotificationItem {
  NotificationItem({
    required this.id,
    required this.type,
    required this.createdAt,
    required this.actorHandle,
    required this.actorDisplayName,
    required this.postText,
    required this.readAt,
  });

  final String id;
  final String type;
  final DateTime createdAt;
  final String actorHandle;
  final String actorDisplayName;
  final String? postText;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  factory NotificationItem.fromJson(Map<String, dynamic> j) {
    return NotificationItem(
      id: j['id'] as String,
      type: (j['type'] ?? '').toString(),
      createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      actorHandle: j['actor']?['handle'] ?? '',
      actorDisplayName: j['actor']?['displayName'] ?? '',
      postText: j['post']?['text'],
      readAt: j['readAt'] != null
          ? DateTime.tryParse(j['readAt'].toString())
          : null,
    );
  }
}
