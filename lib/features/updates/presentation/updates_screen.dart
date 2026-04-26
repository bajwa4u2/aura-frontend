import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aura/core/auth/session_providers.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
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
    final rawMap = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    final post = rawMap['post'] is Map
        ? Map<String, dynamic>.from(rawMap['post'])
        : <String, dynamic>{};
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
        showHeader: false,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1160),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AuraSpace.s16,
                AuraSpace.s20,
                AuraSpace.s16,
                AuraSpace.s32,
              ),
              children: [
                _UpdatesHeader(),
                const SizedBox(height: AuraSpace.s24),
                _SignInPrompt(
                  onSignIn: () => context.go('/login?redirect=%2Fupdates'),
                  onRegister: () => context.go('/register?redirect=%2Fupdates'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AuraScaffold(
      showHeader: false,
      body: RefreshIndicator(
        color: AuraSurface.accent,
        onRefresh: _load,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1160),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AuraSpace.s16,
                AuraSpace.s20,
                AuraSpace.s16,
                AuraSpace.s32,
              ),
              children: [
                _UpdatesHeader(),
                const SizedBox(height: AuraSpace.s24),
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
                    body:
                        'When Aura has something important to say, it will appear here.',
                    icon: Icons.notifications_none_rounded,
                  )
                else
                  ..._items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: AuraSpace.s10),
                      child: _UpdateTile(
                        headline: (item['headline'] ?? 'Update').toString(),
                        detail: (item['detail'] ?? '').toString().trim(),
                        createdAt: (item['createdAt'] ?? '').toString().trim(),
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

class _UpdatesHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Updates', style: AuraText.headline),
        const SizedBox(height: AuraSpace.s6),
        Text(
          'Announcements, releases, and public changes from Aura.',
          style: AuraText.body.copyWith(color: AuraSurface.muted, height: 1.5),
        ),
      ],
    );
  }
}

class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt({required this.onSignIn, required this.onRegister});

  final VoidCallback onSignIn;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s20),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.xl),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sign in to access updates', style: AuraText.subtitle),
          const SizedBox(height: AuraSpace.s8),
          Text(
            'Platform announcements, releases, and notices are visible after signing in.',
            style: AuraText.body.copyWith(color: AuraSurface.muted),
          ),
          const SizedBox(height: AuraSpace.s16),
          Wrap(
            spacing: AuraSpace.s10,
            runSpacing: AuraSpace.s10,
            children: [
              AuraPrimaryButton(
                label: 'Sign in',
                onPressed: onSignIn,
                icon: Icons.login_rounded,
              ),
              AuraSecondaryButton(
                label: 'Create account',
                onPressed: onRegister,
                icon: Icons.person_add_alt_1_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UpdateTile extends StatelessWidget {
  const _UpdateTile({
    required this.headline,
    required this.detail,
    required this.createdAt,
    required this.onTap,
  });

  final String headline;
  final String detail;
  final String createdAt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final timeLabel = createdAt.isNotEmpty ? _timeAgo(createdAt) : '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        child: Container(
          padding: const EdgeInsets.all(AuraSpace.s16),
          decoration: BoxDecoration(
            color: AuraSurface.card,
            borderRadius: BorderRadius.circular(AuraRadius.card),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AuraSurface.accentSoft,
                  borderRadius: BorderRadius.circular(AuraRadius.r10),
                  border: Border.all(
                    color: AuraSurface.accent.withValues(alpha: 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.campaign_outlined,
                  size: 18,
                  color: AuraSurface.accentText,
                ),
              ),
              const SizedBox(width: AuraSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline,
                      style: AuraText.small.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (detail.isNotEmpty) ...[
                      const SizedBox(height: AuraSpace.s4),
                      Text(
                        detail,
                        style: AuraText.small.copyWith(
                          color: AuraSurface.muted,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (timeLabel.isNotEmpty) ...[
                      const SizedBox(height: AuraSpace.s6),
                      Text(
                        timeLabel,
                        style: AuraText.micro.copyWith(
                          color: AuraSurface.faint,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AuraSpace.s8),
              const Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: AuraSurface.faint,
              ),
            ],
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
