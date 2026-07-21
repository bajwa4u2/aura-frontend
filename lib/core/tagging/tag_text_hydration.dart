import 'tag_entities.dart';

class HydratedTagText {
  const HydratedTagText({required this.text, required this.references});

  final String text;
  final List<TagReference> references;
}

HydratedTagText hydrateTextWithDisplayTags(
  String text,
  List<TagReference> references,
) {
  if (text.isEmpty || references.isEmpty) {
    return HydratedTagText(text: text, references: references);
  }

  final ranges = <_HydrationRange>[];
  var searchFrom = 0;
  for (final reference in references) {
    if (!reference.isMention) continue;
    final source = reference.durableSourceText;
    if (source.isEmpty) continue;
    var start = reference.startOffset;
    var end = reference.endOffset;
    final validRange =
        start != null &&
        end != null &&
        start >= 0 &&
        end <= text.length &&
        start < end &&
        text.substring(start, end) == source;
    if (!validRange) {
      start = text.indexOf(source, searchFrom);
      end = start < 0 ? -1 : start + source.length;
    }
    if (start < 0 || end > text.length) continue;
    ranges.add(_HydrationRange(start, end, reference));
    searchFrom = end;
  }
  if (ranges.isEmpty) {
    return HydratedTagText(text: text, references: references);
  }

  ranges.sort((a, b) => a.start.compareTo(b.start));
  final buffer = StringBuffer();
  final out = <TagReference>[];
  var cursor = 0;
  for (final range in ranges) {
    if (range.start < cursor) continue;
    if (range.start > cursor) {
      buffer.write(text.substring(cursor, range.start));
    }
    final nextStart = buffer.length;
    final token = range.reference.displayToken;
    buffer.write(token);
    out.add(
      range.reference.withSourceText(
        token,
        start: nextStart,
        end: nextStart + token.length,
      ),
    );
    cursor = range.end;
  }
  if (cursor < text.length) {
    buffer.write(text.substring(cursor));
  }

  return HydratedTagText(text: buffer.toString(), references: out);
}

class _HydrationRange {
  const _HydrationRange(this.start, this.end, this.reference);

  final int start;
  final int end;
  final TagReference reference;
}
