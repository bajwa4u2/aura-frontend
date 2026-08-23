import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../net/dio_provider.dart';
import '../product/product_state.dart';
import '../product/product_state_view.dart';

/// The canonical Conversation a legacy `/direct/:threadId` address resolves to.
///
/// The server owns the mapping — it is pair identity, not an id relationship —
/// so this asks rather than deriving anything locally. A client that tried to
/// compute it would need the thread's participants, which is the payload it is
/// trying to reach.
final legacyDirectThreadConversationProvider =
    FutureProvider.family<String?, String>((ref, threadId) async {
  final id = threadId.trim();
  if (id.isEmpty) return null;

  try {
    final res = await ref.read(dioProvider).get('/direct-threads/$id');
    final body =
        res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
    final data =
        body['data'] is Map ? Map<String, dynamic>.from(body['data'] as Map) : body;

    final conversationId = data['conversationId']?.toString().trim() ?? '';
    return conversationId.isEmpty ? null : conversationId;
  } on DioException catch (e) {
    // A 404 is a real answer: the thread names nothing this person may see.
    // Anything else is a failure to find out and must not be reported as
    // absence.
    if (e.response?.statusCode == 404) return null;
    rethrow;
  }
});

/// DIRECTTHREAD CUTOVER — a legacy address resolves INTO the canonical surface.
///
/// Founder authorisation 2026-08-23. Content was already reconciled and read
/// state swept forward, so DirectThread stopped being a communication
/// authority. What remains is durable addresses: persisted notification
/// deeplinks and older released clients still name `/direct/:threadId`.
///
/// Those must keep working — the ruling is explicit that compatibility a
/// durable link requires is not deleted. But compatibility RESOLVES INTO the
/// canonical Conversation; it does not reopen the legacy surface. Rendering
/// the old screen here would have preserved a second messaging authority for
/// exactly as long as one old link survived, which is indefinitely.
///
/// So this is a door, not a screen: it resolves and replaces. `replace` rather
/// than `push`, so the legacy address does not become a back-stack entry a
/// reader can return to.
class DirectThreadCutoverScope extends ConsumerStatefulWidget {
  const DirectThreadCutoverScope({super.key, required this.threadId});

  final String threadId;

  @override
  ConsumerState<DirectThreadCutoverScope> createState() =>
      _DirectThreadCutoverScopeState();
}

class _DirectThreadCutoverScopeState
    extends ConsumerState<DirectThreadCutoverScope> {
  bool _sent = false;

  void _goCanonical(String conversationId) {
    if (_sent) return;
    _sent = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.replace('/messages/c/$conversationId');
    });
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.threadId.trim();
    if (id.isEmpty) {
      return const AuraProductState(
        state: ProductState.empty,
        headline: 'That conversation could not be found',
      );
    }

    final resolved =
        ref.watch(legacyDirectThreadConversationProvider(id));

    return resolved.when(
      loading: () => const AuraProductState(state: ProductState.loading),
      // Resolved-but-unknown is a truthful empty state, never an eternal
      // spinner and never a silent bounce to somewhere unrelated.
      error: (_, __) => const AuraProductState(
        state: ProductState.empty,
        headline: 'That conversation could not be found',
      ),
      data: (conversationId) {
        if (conversationId == null) {
          return const AuraProductState(
            state: ProductState.empty,
            headline: 'That conversation could not be found',
          );
        }
        _goCanonical(conversationId);
        return const AuraProductState(state: ProductState.loading);
      },
    );
  }
}
