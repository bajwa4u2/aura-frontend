import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, required this.handle});
  final String handle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileControllerProvider(handle));

    if (state.loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.error != null || state.profile == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Could not load profile')),
      );
    }

    final p = state.profile!;

    return Scaffold(
      appBar: AppBar(title: Text('@${p.handle}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            p.displayName,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          if (p.bio != null && p.bio!.isNotEmpty)
            Text(p.bio!, style: const TextStyle(height: 1.4)),
          const SizedBox(height: 16),
          Row(
            children: [
              _Stat(label: 'Followers', value: p.followersCount),
              const SizedBox(width: 18),
              _Stat(label: 'Following', value: p.followingCount),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () =>
                ref.read(profileControllerProvider(handle).notifier).toggleFollow(),
            child: Text(p.isFollowing ? 'Unfollow' : 'Follow'),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$value',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.black54)),
      ],
    );
  }
}
