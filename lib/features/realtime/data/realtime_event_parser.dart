class RealtimeParsedEvent {
  const RealtimeParsedEvent({
    required this.name,
    required this.payload,
  });

  final String name;
  final Map<String, dynamic> payload;
}

class RealtimeEventParser {
  static RealtimeParsedEvent parse(String name, dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return RealtimeParsedEvent(name: name, payload: raw);
    }

    if (raw is Map) {
      return RealtimeParsedEvent(
        name: name,
        payload: Map<String, dynamic>.from(raw),
      );
    }

    return RealtimeParsedEvent(
      name: name,
      payload: <String, dynamic>{'value': raw},
    );
  }
}
