import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aura/core/auth/session_providers.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import 'updates_repository.dart';

class UpdatesScreen extends ConsumerStatefulWidget {
  const UpdatesScreen({super.key});

  @override
  ConsumerState<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends ConsumerState<UpdatesScreen> {
  static const _pollInterval = Duration(seconds: 20);

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const [];
  Timer? _pollTimer;

  UpdatesRepository get _repo => UpdatesRepository(ref.read(dioProvider));

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (!mounted || _loading) return;
      _refreshSilently();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
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

  Future<void> _refreshSilently() async {
    try {
      _repo.clearCache();
      final items = await _repo.listUpdates(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _items = items;
      });
    } catch (_) {}
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
            Text('Updates', style: AuraText.title),
            const SizedBox(height: AuraSpace.s16),
            AuraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Public record', style: AuraText.body.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: AuraSpace.s8),
                  Text(
                    'Announcements, releases, and public changes appear here.',
                    style: AuraText.small,
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
            constraints: const BoxConstraints(maxWidth: 920),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AuraSpace.s16,
                AuraSpace.s16,
                AuraSpace.s16,
                AuraSpace.s24,
              ),
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Updates', style: AuraText.title)),
                    OutlinedButton(
                      onPressed: _load,
                      child: const Text('Refresh'),
                    ),
                  ],
                ),
                const SizedBox(height: AuraSpace.s16),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_error != null)
                  AuraCard(
                    child: Text(_error!, style: AuraText.small),
                  )
                else if (_items.isEmpty)
                  AuraCard(
                    child: Text('No updates yet.', style: AuraText.small),
                  )
                else
                  ..._items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: AuraSpace.s10),
                      child: AuraCard(
                        child: InkWell(
                          onTap: () => _openUpdate(item),
                          borderRadius: BorderRadius.circular(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AuraSurface.card,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: AuraSurface.divider),
                                ),
                                child: const Icon(Icons.campaign_outlined, size: 18),
                              ),
                              const SizedBox(width: AuraSpace.s12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (item['headline'] ?? 'Update').toString(),
                                      style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                                    ),
                                    if ((item['detail'] ?? '').toString().trim().isNotEmpty) ...[
                                      const SizedBox(height: AuraSpace.s6),
                                      Text(
                                        item['detail'].toString(),
                                        style: AuraText.small.copyWith(color: AuraSurface.muted),
                                      ),
                                    ],
                                    if ((item['createdAt'] ?? '').toString().trim().isNotEmpty) ...[
                                      const SizedBox(height: AuraSpace.s8),
                                      Text(
                                        _timeAgo((item['createdAt'] ?? '').toString()),
                                        style: AuraText.small.copyWith(color: AuraSurface.muted),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
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
