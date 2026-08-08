import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/session_providers.dart';
import '../application/thread_call_lifecycle_controller.dart';
import 'incoming_live_overlay.dart';

class ThreadCallLifecycleHost extends ConsumerWidget {
  const ThreadCallLifecycleHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(tokenStoreProvider);
    final token = store.accessToken?.trim() ?? '';
    final isMemberSession =
        store.isLoaded && token.isNotEmpty && !isGuestAccessToken(token);

    if (!isMemberSession) {
      return child;
    }

    ref.watch(threadCallLifecycleProvider);

    return AuraIncomingLiveLayer(child: child);
  }
}
