import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    final worksAsync = ref.watch(feedProvider);

    return AuraScaffold(
      body: Center(
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
              const _PublicAccessBand(),
              const SizedBox(height: AuraSpace.s20),
              const _SectionHeader(
                title: 'Works',
                subtitle: 'Published works.',
              ),
              const SizedBox(height: AuraSpace.s12),
              worksAsync.when(
                data: (posts) {
                  if (posts.isEmpty) {
                    return const AuraCard(
                      child: Text(
                        'No public works yet.',
                        style: AuraText.body,
                      ),
                    );
                  }

                  final show = posts.take(6).toList();

                  return Column(
                    children: [
                      for (final p in show) ...[
                        _PublicWorkPreview(post: p),
                        const SizedBox(height: AuraSpace.s10),
                      ],
                      const SizedBox(height: AuraSpace.s6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton(
                          onPressed: () => context.go('/search'),
                          child: const Text('More works'),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const AuraCard(child: _LoadingBlock()),
                error: (e, _) => AuraCard(
                  child: Text(
                    'Could not load works right now. ($e)',
                    style: AuraText.body,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PublicAccessBand extends StatelessWidget {
  const _PublicAccessBand();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 820;

        if (stacked) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PublicWorksHeader(),
              SizedBox(height: AuraSpace.s16),
              _AccessPanel(),
            ],
          );
        }

        return const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: _PublicWorksHeader(),
            ),
            SizedBox(width: AuraSpace.s16),
            Expanded(
              flex: 4,
              child: _AccessPanel(),
            ),
          ],
        );
      },
    );
  }
}

class _PublicHero extends StatelessWidget {
  const _PublicWorksHeader();

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
            'Aura is a public and member environment for people and institutions that want continuity, accountability, and a quieter form of presence online.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s14),
          Text(
            'Read the public record, search the work, or enter through the member and institution paths beside this surface.',
            style: AuraText.small.copyWith(
              color: AuraSurface.muted,
            ),
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

class _AccessPanel extends StatelessWidget {
  const _AccessPanel();

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      padding: const EdgeInsets.all(AuraSpace.s18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _AccessPanelHeader(),
          SizedBox(height: AuraSpace.s14),
          _CompactAccessCard(
            title: 'Members',
            subtitle:
                'Enter your member account.',
            primaryLabel: 'Login',
            primaryRoute: '/login',
            secondaryLabel: 'Register',
            secondaryRoute: '/register',
            icon: Icons.person_outline,
          ),
          SizedBox(height: AuraSpace.s12),
          _CompactAccessCard(
            title: 'Institutions',
            subtitle:
                'Enter an institutional account.',
            primaryLabel: 'Login',
            primaryRoute: '/institution/sign-in',
            secondaryLabel: 'Register',
            secondaryRoute: '/institution/create',
            icon: Icons.apartment_outlined,
          ),
        ],
      ),
    );
  }
}

class _AccessPanelHeader extends StatelessWidget {
  const _AccessPanelHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter Aura',
          style: AuraText.body.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AuraSpace.s8),
        Text(
          'Member and institutional entry.',
          style: AuraText.small.copyWith(
            color: AuraSurface.muted,
          ),
        ),
      ],
    );
  }
}

class _CompactAccessCard extends StatelessWidget {
  const _CompactAccessCard({
    required this.title,
    required this.subtitle,
    required this.primaryLabel,
    required this.primaryRoute,
    required this.secondaryLabel,
    required this.secondaryRoute,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String primaryLabel;
  final String primaryRoute;
  final String secondaryLabel;
  final String secondaryRoute;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AuraSurface.page,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AuraSurface.divider),
      ),
      padding: const EdgeInsets.all(AuraSpace.s14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AuraSurface.accentSoft,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AuraSurface.divider),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: AuraSurface.muted,
                ),
              ),
              const SizedBox(width: AuraSpace.s10),
              Expanded(
                child: Text(
                  title,
                  style: AuraText.body.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s10),
          Text(
            subtitle,
            style: AuraText.small.copyWith(height: 1.4),
          ),
          const SizedBox(height: AuraSpace.s14),
          Wrap(
            spacing: AuraSpace.s10,
            runSpacing: AuraSpace.s10,
            children: [
              FilledButton(
                onPressed: () => context.go(primaryRoute),
                child: Text(primaryLabel),
              ),
              OutlinedButton(
                onPressed: () => context.go(secondaryRoute),
                child: Text(secondaryLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PublicWorkPreview extends StatelessWidget {
  const _PublicWorkPreview({required this.post});
  final Post post;

  @override
  Widget build(BuildContext context) {
    final a = post.author;
    final authorMap = _asMap(a);
    final name = ((authorMap['displayName'] ?? a?.displayName ?? '') as String)
        .trim();
    final handle =
        ((authorMap['handle'] ?? a?.handle ?? '') as String).trim();

    final byline =
        handle.isEmpty ? name : '@$handle${name.isNotEmpty ? ' • $name' : ''}';

    final text = post.text.trim();

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
                  byline.isEmpty ? 'Work' : byline,
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
  const _Pill({required this.label, required this.icon, required this.onTap});

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