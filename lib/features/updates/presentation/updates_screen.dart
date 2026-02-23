import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../providers.dart';

class UpdatesScreen extends ConsumerWidget {
  const UpdatesScreen({super.key});

  String _label(Map<String, dynamic> n) {
    final t = (n['type'] ?? '').toString();
    if (t == 'reply') return 'Replied';
    if (t == 'like') return 'Appreciated';
    if (t == 'follow') return 'Followed you';
    return t.isEmpty ? 'Update' : t;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthed = ref.watch(isAuthedProvider);

    // Public-safe read-only version.
    if (!isAuthed) {
      return AuraScaffold(
        title: 'Updates',
        actions: [
          TextButton(
            onPressed: () => context.go('/login?redirect=%2Fupdates'),
            child: const Text('Login'),
          ),
        ],
        body: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: AuraSpace.s16,
            right: AuraSpace.s16,
            top: AuraSpace.s16,
            bottom: AuraSpace.s24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Updates are personal.', style: AuraText.title),
                    SizedBox(height: AuraSpace.s10),
                    Text(
                      'When you join, this page becomes your private record of replies, follows, and acknowledgements.',
                      style: AuraText.body,
                    ),
                    SizedBox(height: AuraSpace.s16),
                    Wrap(
                      spacing: AuraSpace.s10,
                      runSpacing: AuraSpace.s10,
                      children: [
                        FilledButton(
                          onPressed: () => context.go('/register?redirect=%2Fupdates'),
                          child: const Text('Create account'),
                        ),
                        OutlinedButton(
                          onPressed: () => context.go('/login?redirect=%2Fupdates'),
                          child: const Text('Login'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: AuraSpace.s16),
              AuraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Why this is gated', style: AuraText.title),
                    SizedBox(height: AuraSpace.s10),
                    const _Bullet('Updates can reveal reading and writing patterns.'),
                    const _Bullet('They also include personal context from other people.'),
                    const _Bullet('Aura treats attention as a private ledger, not a public feed.'),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Authenticated: current behavior.
    final async = ref.watch(notificationsProvider);

    return AuraScaffold(
      title: 'Updates',
      actions: [
        TextButton(
          onPressed: () async {
            final repo = ref.read(notificationsRepoProvider);
            await repo.markAllRead();
            ref.invalidate(notificationsProvider);
          },
          child: const Text('Mark all read'),
        )
      ],
      body: async.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(child: Text('No updates.', style: AuraText.body));
          }
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(AuraSpace.s16, AuraSpace.s12, AuraSpace.s16, AuraSpace.s24),
            itemCount: items.length,
            separatorBuilder: (_, __) => SizedBox(height: AuraSpace.s10),
            itemBuilder: (context, i) {
              final n = items[i];
              final actor = (n['actor'] is Map) ? (n['actor'] as Map).cast<String, dynamic>() : const <String, dynamic>{};
              final name = (actor['displayName'] ?? actor['handle'] ?? 'Someone').toString();
              final handle = (actor['handle'] ?? '').toString();
              final readAt = n['readAt'];
              final isRead = readAt != null;

              return AuraCard(
                onTap: () async {
                  final id = (n['id'] ?? '').toString();
                  if (id.isNotEmpty && !isRead) {
                    final repo = ref.read(notificationsRepoProvider);
                    await repo.markRead(id);
                    ref.invalidate(notificationsProvider);
                  }
                },
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0x332E2A26),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'A',
                        style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    SizedBox(width: AuraSpace.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$name ${handle.isNotEmpty ? '(@$handle)' : ''}',
                            style: AuraText.body.copyWith(
                              fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: AuraSpace.s6),
                          Text(_label(n), style: AuraText.body),
                        ],
                      ),
                    ),
                    if (!isRead)
                      Padding(
                        padding: EdgeInsets.only(top: AuraSpace.s4),
                        child: const Icon(Icons.circle, size: 10),
                      ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          padding: EdgeInsets.all(AuraSpace.s16),
          children: [
            AuraCard(child: Text('Could not load updates: $e', style: AuraText.body)),
            SizedBox(height: AuraSpace.s12),
            AuraCard(
              child: Text(
                'If your backend was running before, restart it so the Notifications module is registered.',
                style: AuraText.body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: AuraSpace.s10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: AuraSpace.s4),
            child: const Icon(Icons.circle, size: 6),
          ),
          SizedBox(width: AuraSpace.s10),
          Expanded(child: Text(text, style: AuraText.body)),
        ],
      ),
    );
  }
}
