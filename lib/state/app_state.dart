import 'package:flutter/foundation.dart';

/// Legacy in-app state holder (kept for future profile caching if needed).
/// Current production auth/session is handled in lib/core/auth/*.
/// This file remains intentionally small to avoid drift.
class AppState extends ChangeNotifier {
  bool isMember = false;

  String? id;
  String? handle;
  String? displayName;
  String? bio;
  String? avatarUrl;

  void setBackendUser({
    required String id,
    required String handle,
    required String displayName,
    String? bio,
    String? avatarUrl,
  }) {
    this.id = id;
    this.handle = handle;
    this.displayName = displayName;
    this.bio = bio;
    this.avatarUrl = avatarUrl;
    isMember = true;
    notifyListeners();
  }

  void clear() {
    isMember = false;
    id = null;
    handle = null;
    displayName = null;
    bio = null;
    avatarUrl = null;
    notifyListeners();
  }
}
