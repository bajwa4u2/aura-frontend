import 'package:video_player/video_player.dart';

/// Fallback for a platform with neither dart:io nor dart:html. Nothing can
/// open a local file here, so the caller falls back to the honest tile.
VideoPlayerController? localVideoController(String path) => null;
