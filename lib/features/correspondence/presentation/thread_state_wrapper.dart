import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'thread_screen.dart';

class ThreadStateWrapper extends ConsumerWidget {
  const ThreadStateWrapper({
    super.key,
    this.threadId,
    this.child,
  }) : assert(threadId != null || child != null);

  final String? threadId;
  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (threadId != null && threadId!.trim().isNotEmpty) {
      return ThreadScreen(threadId: threadId!.trim());
    }
    return child ?? const SizedBox.shrink();
  }
}
