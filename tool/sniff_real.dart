import 'dart:io';
import 'package:aura/core/media/media_mime.dart';
import 'package:aura/core/media/attachment.dart';
void main(List<String> a) {
  for (final p in a) {
    final b = File(p).readAsBytesSync();
    final mime = sniffMimeFromBytes(b);
    print('${p.split(RegExp(r"[\/]")).last}: sniffed=$mime  kind=${mime == null ? "(null)" : kindFromMime(mime).name}');
  }
}
