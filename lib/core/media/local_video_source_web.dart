import 'package:video_player/video_player.dart';

/// On web an XFile's `path` is a blob: URL, which the media element loads
/// exactly like any other source — no bytes are copied to do it.
VideoPlayerController? localVideoController(String path) {
  final trimmed = path.trim();
  if (trimmed.isEmpty) return null;
  return VideoPlayerController.networkUrl(Uri.parse(trimmed));
}
