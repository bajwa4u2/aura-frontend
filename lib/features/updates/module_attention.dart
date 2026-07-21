/// AXR-1 — Notification Synchronization: module attention projection.
///
/// Principle: every event produces global awareness (the Activity
/// timeline / notifications bell — already true) AND local awareness in
/// its owning module. This file is the single mapping from notification
/// types to owning modules, projected from the one already-polled
/// [NotificationsState] — no second unread source, no drift: the module
/// badges and the global bell always derive from the same rows.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// Destination modules that surface local attention badges.
enum AttentionModule { messages, institutions, meetings, mentions }

/// Owning module for each notification type. Types without a local
/// destination (likes, saves, follows, system) live only in Activity —
/// that is their owning surface.
AttentionModule? attentionModuleForType(String type) {
  switch (type) {
    case 'MESSAGE':
      return AttentionModule.messages;
    case 'SPACE_INVITE':
    case 'THREAD_INVITE':
    case 'INVITE_ACCEPTED':
      return AttentionModule.institutions;
    case 'MEETING_BOOKED':
    case 'MEETING_REMINDER':
    case 'MEETING_STARTING':
    case 'MEETING_SUMMARY_SHARED':
      return AttentionModule.meetings;
    case 'MENTION':
      return AttentionModule.mentions;
    default:
      return null;
  }
}

/// Per-module unread counts.
class ModuleAttention {
  const ModuleAttention({
    this.messages = 0,
    this.institutions = 0,
    this.meetings = 0,
    this.mentions = 0,
  });

  final int messages;
  final int institutions;
  final int meetings;
  final int mentions;

  int of(AttentionModule m) {
    switch (m) {
      case AttentionModule.messages:
        return messages;
      case AttentionModule.institutions:
        return institutions;
      case AttentionModule.meetings:
        return meetings;
      case AttentionModule.mentions:
        return mentions;
    }
  }
}

/// Computes per-module unread counts from raw notification rows
/// (each a map with `type` and `readAt`). Pure — unit-testable.
ModuleAttention moduleAttentionFromItems(
    List<Map<String, dynamic>> items) {
  var messages = 0;
  var institutions = 0;
  var meetings = 0;
  var mentions = 0;
  for (final item in items) {
    final readAt = (item['readAt'] ?? '').toString().trim();
    if (readAt.isNotEmpty) continue;
    final type = (item['type'] ?? '').toString().trim();
    switch (attentionModuleForType(type)) {
      case AttentionModule.messages:
        messages++;
      case AttentionModule.institutions:
        institutions++;
      case AttentionModule.meetings:
        meetings++;
      case AttentionModule.mentions:
        mentions++;
      case null:
        break;
    }
  }
  return ModuleAttention(
    messages: messages,
    institutions: institutions,
    meetings: meetings,
    mentions: mentions,
  );
}

/// Live per-module attention, derived from the same notification state
/// that powers the global bell — one source of truth, synchronized by
/// construction.
final moduleAttentionProvider = Provider<ModuleAttention>((ref) {
  final items = ref.watch(
      notificationsControllerProvider.select((state) => state.items));
  return moduleAttentionFromItems(items);
});
