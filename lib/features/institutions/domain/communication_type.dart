/// Institution communication type — purely presentational.
///
/// Backend post + announcement DTOs do not currently carry a free-form
/// metadata field, so the type is encoded as a leading marker on the
/// stored `title`:
///
///     "[OFFICIAL:ADVISORY] Real title text"
///
/// On render, [InsCommunicationDecoded.parse] strips the marker and yields
/// the type + clean title. Legacy posts (no marker) decode to
/// [InsCommunicationType.update] with the title returned verbatim, so
/// existing content keeps rendering unchanged.
///
/// The marker is intentionally bracketed in a way that, even when an old
/// client renders the raw title, the user sees a sensible "[OFFICIAL:...]"
/// badge rather than a corrupted title.
library;


enum InsCommunicationType {
  announcement,
  update,
  notice,
  advisory,
}

extension InsCommunicationTypeX on InsCommunicationType {
  /// Stable wire token used inside the title marker.
  String get wire {
    switch (this) {
      case InsCommunicationType.announcement:
        return 'ANNOUNCEMENT';
      case InsCommunicationType.update:
        return 'UPDATE';
      case InsCommunicationType.notice:
        return 'NOTICE';
      case InsCommunicationType.advisory:
        return 'ADVISORY';
    }
  }

  /// Priority used for client-side feed ordering. Lower = higher priority.
  /// Stable within the same value (callers pair this with index for ties).
  int get priorityRank {
    switch (this) {
      case InsCommunicationType.announcement:
        return 0;
      case InsCommunicationType.advisory:
        return 1;
      case InsCommunicationType.notice:
        return 2;
      case InsCommunicationType.update:
        return 3;
    }
  }

  /// Human-readable label for chips/badges.
  String get label {
    switch (this) {
      case InsCommunicationType.announcement:
        return 'Announcement';
      case InsCommunicationType.update:
        return 'Update';
      case InsCommunicationType.notice:
        return 'Notice';
      case InsCommunicationType.advisory:
        return 'Advisory';
    }
  }

  static InsCommunicationType fromWire(String? raw) {
    final v = (raw ?? '').toUpperCase().trim();
    switch (v) {
      case 'ANNOUNCEMENT':
        return InsCommunicationType.announcement;
      case 'NOTICE':
        return InsCommunicationType.notice;
      case 'ADVISORY':
        return InsCommunicationType.advisory;
      case 'UPDATE':
      default:
        return InsCommunicationType.update;
    }
  }
}

/// Result of stripping the type marker from a stored title.
class InsCommunicationDecoded {
  const InsCommunicationDecoded({
    required this.type,
    required this.cleanTitle,
    required this.hadMarker,
  });

  final InsCommunicationType type;
  final String cleanTitle;

  /// True when the source title carried an `[OFFICIAL:TYPE]` marker.
  /// False for legacy/unmarked content — caller may then fall back to
  /// rendering only the OFFICIAL eyebrow without a TYPE pill.
  final bool hadMarker;

  /// Marker pattern: `[OFFICIAL:TYPE]` followed by a single space.
  /// Anchored to start; case-insensitive on the type token to keep
  /// rendering tolerant.
  static final RegExp _marker =
      RegExp(r'^\[OFFICIAL:([A-Z_]+)\]\s+', caseSensitive: false);

  static InsCommunicationDecoded parse(String? rawTitle) {
    final src = (rawTitle ?? '').trim();
    final m = _marker.firstMatch(src);
    if (m == null) {
      return InsCommunicationDecoded(
        type: InsCommunicationType.update,
        cleanTitle: src,
        hadMarker: false,
      );
    }
    final wire = m.group(1) ?? '';
    final clean = src.substring(m.end).trim();
    return InsCommunicationDecoded(
      type: InsCommunicationTypeX.fromWire(wire),
      cleanTitle: clean,
      hadMarker: true,
    );
  }

  /// Encode a clean title + type back into the stored form.
  ///
  /// `cleanTitle` MUST be non-empty — composers should derive a title
  /// from the body when the user leaves the title field blank before
  /// calling this.
  static String encode({
    required InsCommunicationType type,
    required String cleanTitle,
  }) {
    final t = cleanTitle.trim();
    return '[OFFICIAL:${type.wire}] $t';
  }
}
