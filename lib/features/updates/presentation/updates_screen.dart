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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthed = ref.watch(isAuthedProvider);

    if (isAuthed) {
      return AuraScaffold(
        showHeader: false,
        body: _AuthenticatedUpdatesBody(),
      );
    }

    return const AuraScaffold(
      title: 'Updates',
      actions: [
        _UpdatesMenu(),
      ],
      body: _PublicUpdatesBody(),
    );
  }
}

class _UpdatesMenu extends ConsumerWidget {
  const _UpdatesMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthed = ref.watch(isAuthedProvider);

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

          case 'refresh':
            ref.read(notificationsRepoProvider).clearCache();
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
              value: 'refresh',
              child: Text('Refresh'),
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
    return const _CenteredUpdatesList(
      children: [
        AuraCard(
          child: _PublicIntro(),
        ),
        SizedBox(height: AuraSpace.s16),
        AuraCard(
          child: _PublicExplanation(),
        ),
      ],
    );
  }
}

class _PublicIntro extends StatelessWidget {
  const _PublicIntro();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Updates are personal.', style: AuraText.title),
        const SizedBox(height: AuraSpace.s10),
        Text(
          'When you join, this page becomes your private record of replies, acknowledgements, and activity that matters to you.',
          style: AuraText.body,
        ),
        const SizedBox(height: AuraSpace.s16),
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
    );
  }
}

class _PublicExplanation extends StatelessWidget {
  const _PublicExplanation();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What this page is for', style: AuraText.title),
        SizedBox(height: AuraSpace.s10),
        _Bullet('Replies and acknowledgements tied to your writing.'),
        _Bullet('Institutional and community changes relevant to you.'),
        _Bullet('A private record of movement, not a public feed.'),
      ],
    );
  }
}

class _AuthenticatedUpdatesBody extends ConsumerWidget {
  const _AuthenticatedUpdatesBody();

  Future<void> _refresh(WidgetRef ref) async {
    ref.read(notificationsRepoProvider).clearCache();
    ref.invalidate(notificationsProvider);
    await ref.read(notificationsProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);

    return async.when(
      data: (items) {
        if (items.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => _refresh(ref),
            child: const _CenteredUpdatesList(
              alwaysScrollable: true,
              children: [
                AuraCard(
                  child: Text(
                    'Nothing has been recorded for you yet.',
                    style: AuraText.body,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: _CenteredUpdatesSeparatedList(
            alwaysScrollable: true,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: AuraSpace.s10),
            itemBuilder: (context, i) {
              final item = Map<String, dynamic>.from(items[i]);
              final actor = _actorFrom(item);

              final displayName = actor['displayName']!.trim().isNotEmpty
                  ? actor['displayName']!.trim()
                  : 'Aura';

              final handle = actor['handle']!.trim();

              final headline = _nonEmpty(item['headline'])
                  ? item['headline'].toString().trim()
                  : 'Activity on Aura';

              final detail = item['detail']?.toString().trim() ?? '';
              final createdAt = item['createdAt']?.toString().trim() ?? '';

              return AuraCard(
                child: _UpdateRow(
                  displayName: displayName,
                  handle: handle,
                  headline: headline,
                  detail: detail,
                  createdAt: createdAt,
                ),
              );
            },
          ),
        );
      },
      loading: () {
        return const _CenteredUpdatesList(
          alwaysScrollable: true,
          children: [
            Center(child: CircularProgressIndicator()),
          ],
        );
      },
      error: (e, _) {
        return RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: _CenteredUpdatesList(
            alwaysScrollable: true,
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
                  'Pull to refresh after the backend settles.',
                  style: AuraText.body,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Map<String, String> _actorFrom(Map<String, dynamic> item) {
    final raw = item['actor'];

    if (raw is Map) {
      final actor = Map<String, dynamic>.from(raw);

      return {
        'displayName': (actor['displayName'] ?? '').toString(),
        'handle': (actor['handle'] ?? '').toString(),
      };
    }

    return const {
      'displayName': 'Aura',
      'handle': '',
    };
  }

  static bool _nonEmpty(dynamic value) {
    return value != null && value.toString().trim().isNotEmpty;
  }

  static String _timeAgo(String raw) {
    final parsed = DateTime.tryParse(raw);

    if (parsed == null) return '';

    final now = DateTime.now().toUtc();
    final dt = parsed.toUtc();
    final diff = now.difference(dt);

    if (diff.inSeconds < 45) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';

    return '${(diff.inDays / 365).floor()}y ago';
  }
}

class _UpdateRow extends StatelessWidget {
  const _UpdateRow({
    required this.displayName,
    required this.handle,
    required this.headline,
    required this.detail,
    required this.createdAt,
  });

  final String displayName;
  final String handle;
  final String headline;
  final String detail;
  final String createdAt;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: const Color(0x332E2A26),
          child: Text(
            displayName.characters.first.toUpperCase(),
            style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: AuraSpace.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AuraText.body.copyWith(fontWeight: FontWeight.w800),
              ),
              if (handle.isNotEmpty) ...[
                const SizedBox(height: AuraSpace.s4),
                Text(
                  '@$handle',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AuraText.body.copyWith(color: Colors.white70),
                ),
              ],
              const SizedBox(height: AuraSpace.s8),
              Text(
                headline,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
              ),
              if (detail.isNotEmpty) ...[
                const SizedBox(height: AuraSpace.s6),
                Text(
                  detail,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AuraText.body,
                ),
              ],
              if (createdAt.isNotEmpty) ...[
                const SizedBox(height: AuraSpace.s8),
                Text(
                  _AuthenticatedUpdatesBody._timeAgo(createdAt),
                  style: AuraText.body.copyWith(color: Colors.white60),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CenteredUpdatesList extends StatelessWidget {
  const _CenteredUpdatesList({
    required this.children,
    this.alwaysScrollable = false,
  });

  final List<Widget> children;
  final bool alwaysScrollable;

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
              physics: alwaysScrollable
                  ? const AlwaysScrollableScrollPhysics()
                  : null,
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
    this.alwaysScrollable = false,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final IndexedWidgetBuilder separatorBuilder;
  final bool alwaysScrollable;

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
              physics: alwaysScrollable
                  ? const AlwaysScrollableScrollPhysics()
                  : null,
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