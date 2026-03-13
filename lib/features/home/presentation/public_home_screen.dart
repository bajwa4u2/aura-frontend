import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../feed/domain/post.dart';
import '../../feed/providers.dart';

Map<String, dynamic> _asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return <String, dynamic>{};
}

class PublicHomeScreen extends ConsumerWidget {
  const PublicHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(feedProvider);

    return AuraScaffold(
      title: 'Aura',
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 980;

          final hero = const _PublicHero();
          final entryStack = const _EntryStack();

          final feedSection = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(
                title: 'Public record',
                subtitle: 'Approved public posts.',
              ),
              const SizedBox(height: AuraSpace.s12),
              feedAsync.when(
                data: (posts) {
                  if (posts.isEmpty) {
                    return const AuraCard(
                      child: Text(
                        'No public posts yet.',
                        style: AuraText.body,
                      ),
                    );
                  }

                  final show = posts.take(6).toList();

                  return Column(
                    children: [
                      for (final p in show) ...[
                        _PublicPostPreview(post: p),
                        const SizedBox(height: AuraSpace.s10),
                      ],
                      const SizedBox(height: AuraSpace.s6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton(
                          onPressed: () => context.go('/search'),
                          child: const Text('See more'),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const AuraCard(child: _LoadingBlock()),
                error: (e, _) => AuraCard(
                  child: Text(
                    'Could not load public feed yet. ($e)',
                    style: AuraText.body,
                  ),
                ),
              ),
            ],
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.s16,
              AuraSpace.s16,
              AuraSpace.s16,
              AuraSpace.s24,
            ),
            children: [
              hero,
              const SizedBox(height: AuraSpace.s20),
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: feedSection,
                    ),
                    const SizedBox(width: AuraSpace.s16),
                    Flexible(
                      flex: 4,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 380),
                        child: entryStack,
                      ),
                    ),
                  ],
                )
              else ...[
                entryStack,
                const SizedBox(height: AuraSpace.s20),
                feedSection,
              ],
              const SizedBox(height: AuraSpace.s24),
            ],
          );
        },
      ),
    );
  }
}

class _PublicHero extends StatelessWidget {
  const _PublicHero();

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      padding: const EdgeInsets.all(AuraSpace.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A civic layer for accountable public writing.',
            style: AuraText.title,
          ),
          const SizedBox(height: AuraSpace.s10),
          Text(
            'For members and institutions.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s16),
          Wrap(
            spacing: AuraSpace.s10,
            runSpacing: AuraSpace.s10,
            children: [
              _Pill(
                label: 'Mission',
                icon: Icons.flag_outlined,
                onTap: () => context.go('/mission'),
              ),
              _Pill(
                label: 'Founder',
                icon: Icons.person_outline,
                onTap: () => context.go('/founder'),
              ),
              _Pill(
                label: 'Institutions',
                icon: Icons.apartment_outlined,
                onTap: () => context.go('/institutions'),
              ),
              _Pill(
                label: 'Investors',
                icon: Icons.assured_workload_outlined,
                onTap: () => context.go('/investors'),
              ),
              _Pill(
                label: 'Contact',
                icon: Icons.mail_outline,
                onTap: () => context.go('/contact'),
              ),
              _Pill(
                label: 'Search',
                icon: Icons.search,
                onTap: () => context.go('/search'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EntryStack extends StatelessWidget {
  const _EntryStack();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PublicAuthPanel(),
        SizedBox(height: AuraSpace.s14),
        _InstitutionEntryCard(),
      ],
    );
  }
}

class _PublicAuthPanel extends StatelessWidget {
  const _PublicAuthPanel();

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      padding: const EdgeInsets.all(AuraSpace.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Enter as member', style: AuraText.title),
          const SizedBox(height: AuraSpace.s10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => context.go('/register?redirect=%2Fhome'),
              child: const Text('Create member account'),
            ),
          ),
          const SizedBox(height: AuraSpace.s10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.go('/login?redirect=%2Fhome'),
              child: const Text('Member sign in'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InstitutionEntryCard extends StatelessWidget {
  const _InstitutionEntryCard();

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      padding: const EdgeInsets.all(AuraSpace.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Enter as institution', style: AuraText.title),
          const SizedBox(height: AuraSpace.s10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => context.go('/institution/create'),
              child: const Text('Create institutional account'),
            ),
          ),
          const SizedBox(height: AuraSpace.s10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.go('/institution/sign-in'),
              child: const Text('Institution sign in'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PublicPostPreview extends StatelessWidget {
  const _PublicPostPreview({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final a = post.author;
    final name = (a?.displayName ?? '').trim();
    final handle = (a?.handle ?? '').trim();
    final byline =
        handle.isEmpty ? name : '@$handle${name.isNotEmpty ? ' • $name' : ''}';

    final text = (post.text ?? '').trim();
    final previewLength = MediaQuery.of(context).size.width < 600 ? 160 : 240;

    final preview = text.length <= previewLength
        ? text
        : '${text.substring(0, previewLength)}…';

    return AuraCard(
      onTap: () => context.push('/posts/${post.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AuraSurface.accentSoft,
                  shape: BoxShape.circle,
                  border: Border.all(color: AuraSurface.divider),
                ),
              ),
              const SizedBox(width: AuraSpace.s10),
              Expanded(
                child: Text(
                  byline.isEmpty ? 'Public entry' : byline,
                  style: AuraText.small.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AuraSurface.muted,
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s10),
          Text(
            preview.isEmpty ? '—' : preview,
            style: AuraText.body.copyWith(height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AuraText.title),
        const SizedBox(height: AuraSpace.s8),
        Text(subtitle, style: AuraText.muted),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s12,
          vertical: AuraSpace.s10,
        ),
        decoration: BoxDecoration(
          color: AuraSurface.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AuraSurface.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AuraSurface.muted),
            const SizedBox(width: AuraSpace.s8),
            Text(label, style: AuraText.small),
          ],
        ),
      ),
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AuraSpace.s18),
      child: const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
