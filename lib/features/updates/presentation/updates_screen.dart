import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aura/core/auth/session_providers.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../updates_repository.dart';

class UpdatesScreen extends ConsumerStatefulWidget {
  const UpdatesScreen({super.key});

  @override
  ConsumerState<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends ConsumerState<UpdatesScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const [];

  UpdatesRepository get _repo => UpdatesRepository(ref.read(dioProvider));

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      _repo.clearCache();
      final items = await _repo.listUpdates(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load updates.';
        _loading = false;
      });
    }
  }

  void _openUpdate(Map<String, dynamic> item) {
    final targetUrl = (item['targetUrl'] ?? '').toString().trim();
    final raw = item['raw'];
    final rawMap = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final post = rawMap['post'] is Map ? Map<String, dynamic>.from(rawMap['post']) : <String, dynamic>{};
    final postId = _firstNonEmpty([
      (rawMap['postId'] ?? '').toString(),
      (post['id'] ?? '').toString(),
    ]);

    if (targetUrl.isNotEmpty) {
      context.push(targetUrl);
      return;
    }
    if (postId.isNotEmpty) {
      context.push('/posts/$postId');
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAuthed = ref.watch(isAuthedProvider);

    if (!isAuthed) {
      return AuraScaffold(
        title: 'Updates',
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const AuraGradientHeader(
              title: 'Updates',
              subtitle: 'Announcements, releases, and public changes appear here.',
            ),
            const SizedBox(height: AuraSpace.s16),
            AuraCard(
              child: Wrap(
                spacing: AuraSpace.s10,
                runSpacing: AuraSpace.s10,
                children: [
                  AuraPrimaryButton(
                    label: 'Create account',
                    onPressed: () => context.go('/register?redirect=%2Fupdates'),
                    icon: Icons.person_add_alt_1_rounded,
                  ),
                  AuraSecondaryButton(
                    label: 'Login',
                    onPressed: () => context.go('/login?redirect=%2Fupdates'),
                    icon: Icons.login_rounded,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return AuraScaffold(
      showHeader: false,
      body: RefreshIndicator(
        onRefresh: _load,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1160),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                const AuraGradientHeader(
                  title: 'Updates',
                  subtitle: 'A quiet public feed for attention, announcements, and activity.',
                ),
                const SizedBox(height: AuraSpace.s16),
                if (_loading)
                  const AuraLoadingState(message: 'Loading updates…')
                else if (_error != null)
                  AuraErrorState(
                    title: 'Could not load updates',
                    body: _error!,
                    action: AuraSecondaryButton(
                      label: 'Refresh',
                      onPressed: _load,
                      icon: Icons.refresh_rounded,
                    ),
                  )
                else if (_items.isEmpty)
                  const AuraEmptyState(
                    title: 'No updates yet',
                    body: 'When Aura has something important to say, it will appear here.',
                    icon: Icons.notifications_none_rounded,
                  )
                else
                  ..._items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: AuraSpace.s10),
                      child: AuraNotificationTile(
                        title: (item['headline'] ?? 'Update').toString(),
                        body: [
                          if ((item['detail'] ?? '').toString().trim().isNotEmpty)
                            item['detail'].toString(),
                          if ((item['createdAt'] ?? '').toString().trim().isNotEmpty)
                            _timeAgo((item['createdAt'] ?? '').toString()),
                        ].where((s) => s.trim().isNotEmpty).join(' • '),
                        icon: Icons.campaign_outlined,
                        onTap: () => _openUpdate(item),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _firstNonEmpty(List<String> values) {
  for (final value in values) {
    if (value.trim().isNotEmpty) return value.trim();
  }
  return '';
}

String _timeAgo(String raw) {
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
