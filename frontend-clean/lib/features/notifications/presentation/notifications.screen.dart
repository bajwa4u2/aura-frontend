import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../domain/notification_item.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: _buildBody(context, ref, state),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    NotificationsState state,
  ) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load notifications'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () =>
                  ref.read(notificationsControllerProvider.notifier).load(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.items.isEmpty) {
      return const Center(child: Text('Nothing here yet.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: state.items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final n = state.items[i];
        return _NotificationTile(
          item: n,
          onTap: () =>
              ref.read(notificationsControllerProvider.notifier).markRead(n),
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.onTap,
  });

  final NotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ts = '${item.createdAt.toLocal()}'.split('.').first;

    return ListTile(
      onTap: onTap,
      tileColor: item.isRead ? null : Colors.grey.shade200,
      title: Text(
        '${item.actorDisplayName} ${_label(item.type)}',
        style: TextStyle(
          fontWeight: item.isRead ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.postText != null && item.postText!.isNotEmpty)
            Text(
              item.postText!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 4),
          Text(
            ts,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _label(String type) {
    switch (type) {
      case 'like':
        return 'liked your post';
      case 'reply':
        return 'replied to you';
      case 'follow':
        return 'followed you';
      default:
        return 'did something';
    }
  }
}
