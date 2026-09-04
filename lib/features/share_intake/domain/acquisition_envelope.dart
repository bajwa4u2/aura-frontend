import 'dart:typed_data';

/// WHICH OPERATING SYSTEM DOOR THE CONTENT CAME THROUGH.
///
/// Recorded, never trusted. A share sheet tells Aura what it thinks it is
/// handing over, and every platform's answer is a hint rather than a fact.
enum AcquisitionPlatform { android, ios, windows, web }

/// WHAT THE OS SAID THE PAYLOAD IS.
///
/// Deliberately coarse. The precise class is decided by
/// `ContentIntake`, which reads the bytes; this only says which shape the
/// adapter received so the envelope can be built without inventing structure.
enum AcquiredPayloadKind {
  /// Plain text with no URL in it.
  text,

  /// A URL, possibly with surrounding text. Shared from a browser or any app
  /// with a "share link" action.
  url,

  /// Bytes, whatever the OS claimed they are.
  file,
}

/// ONE PIECE OF CONTENT AS THE OPERATING SYSTEM HANDED IT OVER.
///
/// Everything on it is a CLAIM. `declaredMimeType` is what the sharing app
/// said, `fileName` is what it called the file, and neither is evidence. The
/// only thing here that can be checked is [bytes], and checking it is
/// `ContentIntake`'s job rather than this class's.
class AcquiredPayload {
  const AcquiredPayload({
    required this.kind,
    this.text,
    this.bytes,
    this.filePath,
    this.declaredMimeType,
    this.fileName,
    this.sourceUri,
    this.sizeBytes,
  });

  final AcquiredPayloadKind kind;

  /// Present for [AcquiredPayloadKind.text] and [AcquiredPayloadKind.url].
  final String? text;

  /// Present for [AcquiredPayloadKind.file] when the adapter had the content
  /// in hand. Either this or [filePath] is set; never neither.
  final Uint8List? bytes;

  /// A COPY THE ADAPTER ALREADY TOOK, inside Aura's own storage.
  ///
  /// The platform's own reference is not carried here, and that is the point.
  /// An Android `content://` grant is scoped to the intent that delivered it:
  /// alive now, gone long before the person has looked at the preview, chosen
  /// a conversation and pressed a button. Reading it later is a share that
  /// works in testing and fails as a permission error in someone's hand. So
  /// the adapter takes the content while the grant is alive — as a file rather
  /// than a byte array, because a shared video can be a hundred megabytes and
  /// a copy is bounded work where a channel transfer is an ANR.

  /// What the sharing application claimed. A hint for tie-breaking only, and
  /// never the answer when the bytes disagree.
  final String? declaredMimeType;

  /// The original name, kept because a person recognises their own file by it
  /// and because an extension is a second weak hint.
  final String? fileName;

  final String? filePath;

  /// Where it came from, when the OS says. A `content://`, `file://` or
  /// `https://` reference — retained as PROVENANCE and deliberately never
  /// re-opened; [filePath] is what gets read.
  final String? sourceUri;

  /// What the adapter actually took in, when it counted. A claim like the
  /// rest; capacity is judged again by intake.
  final int? sizeBytes;

  bool get isTextual =>
      kind == AcquiredPayloadKind.text || kind == AcquiredPayloadKind.url;
}

/// EVERYTHING AURA KNOWS ABOUT A SHARE AT THE MOMENT IT ARRIVES.
///
/// The single shape every platform adapter produces and the only shape the
/// governed destination consumes. Android, iOS and Windows differ in how they
/// deliver a share and in nothing after this class.
///
/// WHAT IS DELIBERATELY ABSENT: a destination, an acting identity, and any
/// notion of publishing. A share is an ACQUISITION. Where it goes, who it goes
/// as, and whether it goes at all are decided afterwards by a person, in Aura,
/// with the content in front of them.
class AcquisitionEnvelope {
  const AcquisitionEnvelope({
    required this.platform,
    required this.payloads,
    required this.receivedAt,
    this.refusals = const <String>[],
    this.handoffReference,
    this.subject,
  });

  final AcquisitionPlatform platform;

  /// One or more items. A share sheet can hand over several images at once,
  /// and refusing the second is not something a person would forgive.
  final List<AcquiredPayload> payloads;

  /// Provenance. When this arrived, so a stale handoff can be recognised as
  /// stale rather than replayed as new.
  final DateTime receivedAt;

  /// Items the adapter could not take in, each with the reason in words.
  ///
  /// Carried rather than dropped. A platform adapter can legitimately refuse
  /// before Aura ever sees the content — an item too large to be worth reading,
  /// a provider that will not open its own file — and a person who watched
  /// three photographs go into a share sheet and two arrive needs to be told
  /// which, and why.
  final List<String> refusals;

  /// The opaque token an iOS Share Extension writes alongside the payload in
  /// the App Group container. Never a credential, and never anything the
  /// extension could act on by itself.
  final String? handoffReference;

  /// The title or subject some platforms attach to a share. Offered to the
  /// person as a starting point, never used as a caption without them seeing
  /// it.
  final String? subject;

  bool get isEmpty => payloads.isEmpty && refusals.isEmpty;

  /// The single URL in this share, when there is exactly one and nothing else.
  /// Used to offer a link preview, never to publish on its own.
  String? get singleUrl {
    if (payloads.length != 1) return null;
    final only = payloads.first;
    return only.kind == AcquiredPayloadKind.url ? only.text : null;
  }
}
