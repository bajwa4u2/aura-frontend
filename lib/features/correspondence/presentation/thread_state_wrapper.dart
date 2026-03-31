import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'thread_screen.dart';

class ThreadStateWrapper extends ConsumerWidget {
  const ThreadStateWrapper({
    super.key,
    required this.threadId,
  });

  final String threadId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ThreadScreen(threadId: threadId);
  }
}
