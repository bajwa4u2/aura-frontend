import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_providers.dart';
import 'package:aura/core/auth/session_providers.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../providers.dart';

class UpdatesScreen extends ConsumerWidget {
  const UpdatesScreen({super.key});

  String _label(Map<String, dynamic> n) {
    final t = (n['type'] ?? '').toString().trim();
    switch (t) {
      case 'reply':
        return 'Replied';
      case 'like':
        return 'Appreciated';
      case 'follow':
        return 'Followed you';
      default:
        return t.isEmpty ? 'Update' : t;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthed = ref.watch(isAuthedProvider);

    return AuraScaffold(
      title: 'Updates',
      actions: [
        _UpdatesMenu(isAuthed: isAuthed),
      ],
      body: isAuthed
          ? _AuthenticatedUpdatesBody(labelFor: _label)
          : const _PublicUpdatesBody(),
    );
  }
}

class _UpdatesMenu extends ConsumerWidget {
  const _UpdatesMenu({required this.isAuthed});

  final bool isAuthed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'Updates menu',
      onSelected: (value) async {
        switch (value) {
          case 'announcements':
            context.go('/announcements');
            break;
          case 'login':
            context.go('/login?redirect=%2Fupdates');
            break;
          case 'register':
            context.go('/register?redirect=%2Fupdates');
            break;
          case 'mark_all_read':
            final repo = ref.read(notificationsRepoProvider);
            await repo.markAllRead();
            ref.invalidate(notificationsProvider);
            break;
        }
      },
      itemBuilder: (_) {
        if (isAuthed) {
          return const [
            PopupMenuItem<String>(
              value: 'announcements',
              child: Text('Announcements'),
            ),
            PopupMenuItem<String>(
              value: 'mark_all_read',
              child: Text('Mark all read'),
            ),
          ];
        }

        return const [
          PopupMenuItem<String>(
            value: 'announcements',
            child: Text('Announcements'),
          ),
          PopupMenuItem<String>(
            value: 'register',
            child: Text('Create account'),
          ),
          PopupMenuItem<String>(
            value: 'login',
            child: Text('Login'),
          ),
        ];
      },
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Icon(Icons.more_horiz),
      ),
    );
  }
}

class _PublicUpdatesBody extends StatelessWidget {
  const _PublicUpdatesBody();

  @override
  Widget build(BuildContext context) {
    return _CenteredUpdatesList(
      children: [
        AuraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Updates are personal.', style: AuraText.title),
              const SizedBox(height: AuraSpace.s10),
              Text(
                'When you join, this page becomes your private record of replies, follows, and acknowledgements.',
                style: AuraText.body,
              ),
              const SizedBox(height: AuraSpace.s16),
              Wrap(
                spacing: AuraSpace.s10,
                runSpacing: AuraSpace.s10,
                children: [
                  FilledButton(
                    onPressed: () =>
                        context.go('/register?redirect=%2Fupdates'),
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
        const SizedBox(height: AuraSpace.s16),
        AuraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Why this is gated', style: AuraText.title),
              const SizedBox(height: AuraSpace.s10),
              const _Bullet('Updates can reveal reading and writing patterns.'),
              const _Bullet(
                'They also include personal context from other people.',
              ),
              const _Bullet(
                'Aura treats attention as a private ledger, not a public feed.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AuthenticatedUpdatesBody extends ConsumerWidget {
  const _AuthenticatedUpdatesBody({required this.labelFor});

  final String Function(Map<String, dynamic>) labelFor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);

    return async.when(
      data: (items) {
        final safeItems = items;

        if (safeItems.isEmpty) {
          return const _CenteredUpdatesList(
            children: [
              AuraCard(
                child: Text(
                  'No updates.',
                  style: AuraText.body,
                ),
              ),
            ],
          );
        }

        return _CenteredUpdatesSeparatedList(
          itemCount: safeItems.length,
          separatorBuilder: (_, __) => const SizedBox(height: AuraSpace.s10),
          itemBuilder: (context, i) {
            final raw = safeItems[i];
            final n = Map<String, dynamic>.from(raw);

            final actorRaw = n['actor'];
            final actor = actorRaw is Map
                ? Map<String, dynamic>.from(actorRaw)
                : <String, dynamic>{};

            final name =
                (actor['displayName'] ?? actor['handle'] ?? 'Someone')
                    .toString()
                    .trim();
            final handle = (actor['handle'] ?? '').toString().trim();
            final readAt = n['readAt'];
            final isRead = readAt != null;
            final id = (n['id'] ?? '').toString().trim();

            final displayLine = handle.isNotEmpty
                ? '$name (@$handle)'
                : name;

            return AuraCard(
              onTap: () async {
                if (id.isEmpty || isRead) return;

                final repo = ref.read(notificationsRepoProvider);
                await repo.markRead(id);
                ref.invalidate(notificationsProvider);
              },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0x332E2A26),
                    child: Text(
                      name.isNotEmpty
                          ? name.characters.first.toUpperCase()
                          : 'A',
                      style: AuraText.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AuraSpace.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          displayLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AuraText.body.copyWith(
                            fontWeight:
                                isRead ? FontWeight.w600 : FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AuraSpace.s6),
                        Text(
                          labelFor(n),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AuraText.body,
                        ),
                      ],
                    ),
                  ),
                  if (!isRead) ...[
                    const SizedBox(width: AuraSpace.s8),
                    const Padding(
                      padding: EdgeInsets.only(top: AuraSpace.s4),
                      child: Icon(Icons.circle, size: 10),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
      loading: () {
        return const _CenteredUpdatesList(
          children: [
            Center(child: CircularProgressIndicator()),
          ],
        );
      },
      error: (e, _) {
        return _CenteredUpdatesList(
          children: [
            AuraCard(
              child: Text(
                'Could not load updates: $e',
                style: AuraText.body,
              ),
            ),
            const SizedBox(height: AuraSpace.s12),
            const AuraCard(
              child: Text(
                'If your backend was running before, restart it so the Notifications module is registered.',
                style: AuraText.body,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CenteredUpdatesList extends StatelessWidget {
  const _CenteredUpdatesList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        double horizontalPadding;
        double maxWidth;

        if (width < 600) {
          horizontalPadding = AuraSpace.s12;
          maxWidth = double.infinity;
        } else if (width < 980) {
          horizontalPadding = AuraSpace.s24;
          maxWidth = 760;
        } else {
          horizontalPadding = AuraSpace.s32;
          maxWidth = 820;
        }

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                AuraSpace.s16,
                horizontalPadding,
                AuraSpace.s24,
              ),
              children: children,
            ),
          ),
        );
      },
    );
  }
}

class _CenteredUpdatesSeparatedList extends StatelessWidget {
  const _CenteredUpdatesSeparatedList({
    required this.itemCount,
    required this.itemBuilder,
    required this.separatorBuilder,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final IndexedWidgetBuilder separatorBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        double horizontalPadding;
        double maxWidth;

        if (width < 600) {
          horizontalPadding = AuraSpace.s12;
          maxWidth = double.infinity;
        } else if (width < 980) {
          horizontalPadding = AuraSpace.s24;
          maxWidth = 760;
        } else {
          horizontalPadding = AuraSpace.s32;
          maxWidth = 820;
        }

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                AuraSpace.s12,
                horizontalPadding,
                AuraSpace.s24,
              ),
              itemCount: itemCount,
              separatorBuilder: separatorBuilder,
              itemBuilder: itemBuilder,
            ),
          ),
        );
      },
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: AuraSpace.s4),
            child: Icon(Icons.circle, size: 6),
          ),
          const SizedBox(width: AuraSpace.s10),
          Expanded(
            child: Text(
              text,
              style: AuraText.body,
            ),
          ),
        ],
      ),
    );
  }
}