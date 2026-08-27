import 'dart:io';

import 'package:video_player/video_player.dart';

/// Native platforms hand back a real filesystem path.
VideoPlayerController? localVideoController(String path) {
  final trimmed = path.trim();
  if (trimmed.isEmpty) return null;
  return VideoPlayerController.file(File(trimmed));
}
