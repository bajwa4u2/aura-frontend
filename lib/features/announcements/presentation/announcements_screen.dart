import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../domain/announcement.dart';
import '../providers.dart';

const String _adminUserIds =
    String.fromEnvironment('AURA_ADMIN_USER_IDS', defaultValue: '');

List<String> _adminUserIdList() {
  return _adminUserIds
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

Map<String, dynamic> _asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return <String, dynamic>{};
}

Map<String, dynamic> _unwrapMap(dynamic raw) {
  final root = _asMap(raw);
  final data = root['data'];

  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);

  return root;
}

final _announcementsMeProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/users/me');
  return _unwrapMap(res.data);
});

class AnnouncementsScreen extends ConsumerWidget {
  const AnnouncementsScreen({super.key});

  bool _isAdmin(Map<String, dynamic> me) {
    final role = (me['role'] ?? '').toString().toLowerCase();
    if (role == 'admin') return true;

    final id = (me['id'] ?? '').toString().trim();
    if (id.isEmpty) return false;

    return _adminUserIdList().contains(id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meAsync = ref.watch(_announcementsMeProvider);
    final institutionAsync = ref.watch(institutionAccessProvider);
    final pinnedAsync = ref.watch(pinnedAnnouncementsProvider);
    final listAsync = ref.watch(announcementsProvider);

    return meAsync.when(
      loading: () => AuraScaffold(
        title: 'Announcements',
        showHomeAction: true,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) {
        return _PublicAnnouncementsScreen(
          pinnedAsync: pinnedAsync,
          listAsync: listAsync,
        );
      },
      data: (me) {
        final isAdmin = _isAdmin(me);

        if (isAdmin) {
          return _AdminAnnouncementsScreen(
            pinnedAsync: pinnedAsync,
            listAsync: listAsync,
          );
        }

        return institutionAsync.when(
          loading: () => AuraScaffold(
            title: 'Announcements',
            showHomeAction: true,
            body: const Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) {
            return _PublicAnnouncementsScreen(
              pinnedAsync: pinnedAsync,
              listAsync: listAsync,
            );
          },
          data: (institutionAccess) {
            final hasInstitutionStanding =
                institutionAccess.state == InstitutionAccessState.pending ||
                    institutionAccess.state == InstitutionAccessState.verifiedMember ||
                    institutionAccess.state == InstitutionAccessState.authorizedSpeaker;

            if (hasInstitutionStanding) {
              return _InstitutionAnnouncementsScreen(
                access: institutionAccess,
                pinnedAsync: pinnedAsync,
                listAsync: listAsync,
              );
            }

            return _PublicAnnouncementsScreen(
              pinnedAsync: pinnedAsync,
              listAsync: listAsync,
            );
          },
        );
      },
    );
  }
}

class _PublicAnnouncementsScreen extends StatelessWidget {
  const _PublicAnnouncementsScreen({
    required this.pinnedAsync,
    required this.listAsync,
  });

  final AsyncValue<List<Announcement>> pinnedAsync;
  final AsyncValue<List<Announcement>> listAsync;

  @override
  Widget build(BuildContext context) {
    return AuraScaffold(
      title: 'Announcements',
      showHomeAction: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AuraSpace.s16,
          AuraSpace.s12,
          AuraSpace.s16,
          AuraSpace.s24,
        ),
        children: [
          const _IntroCard(
            title: 'Announcements',
            body: 'This is the public announcements surface for official platform notices.',
          ),
          const SizedBox(height: AuraSpace.s12),
          _PinnedSection(asyncValue: pinnedAsync),
          const SizedBox(height: AuraSpace.s12),
          _AllSection(asyncValue: listAsync),
        ],
      ),
    );
  }
}

class _AdminAnnouncementsScreen extends ConsumerWidget {
  const _AdminAnnouncementsScreen({
    required this.pinnedAsync,
    required this.listAsync,
  });

  final AsyncValue<List<Announcement>> pinnedAsync;
  final AsyncValue<List<Announcement>> listAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AuraScaffold(
      title: 'Announcements',
      showHomeAction: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AuraSpace.s16,
          AuraSpace.s12,
          AuraSpace.s16,
          AuraSpace.s24,
        ),
        children: [
          const _IntroCard(
            title: 'Admin announcement workspace',
            body:
                'This is the working surface for official platform notices. Use it to create notices, review pinned notices, review the archive, and open the public announcements view.',
          ),
          const SizedBox(height: AuraSpace.s12),
          AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Workspace', style: AuraText.title),
                const SizedBox(height: AuraSpace.s10),
                Text(
                  'This area is reserved for official announcement work only.',
                  style: AuraText.body,
                ),
                const SizedBox(height: AuraSpace.s14),
                Wrap(
                  spacing: AuraSpace.s10,
                  runSpacing: AuraSpace.s10,
                  children: [
                    FilledButton.icon(
                      onPressed: () => context.go('/announcements/create?scope=platform'),
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Create platform notice'),
                    ),
                    FilledButton.icon(
                      onPressed: () => ref.invalidate(announcementsProvider),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Refresh archive'),
                    ),
                    FilledButton.icon(
                      onPressed: () => ref.invalidate(pinnedAnnouncementsProvider),
                      icon: const Icon(Icons.push_pin_outlined, size: 18),
                      label: const Text('Refresh pinned'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/announcements'),
                      icon: const Icon(Icons.public_outlined, size: 18),
                      label: const Text('Open public announcements'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AuraSpace.s12),
          _PinnedSection(
            asyncValue: pinnedAsync,
            title: 'Pinned platform notices',
          ),
          const SizedBox(height: AuraSpace.s12),
          _AllSection(
            asyncValue: listAsync,
            title: 'Announcement archive',
            emptyTitle: 'No announcements yet',
            emptyBody: 'When platform notices are published, they will appear here.',
          ),
        ],
      ),
    );
  }
}

class _InstitutionAnnouncementsScreen extends StatelessWidget {
  const _InstitutionAnnouncementsScreen({
    required this.access,
    required this.pinnedAsync,
    required this.listAsync,
  });

  final InstitutionAccess access;
  final AsyncValue<List<Announcement>> pinnedAsync;
  final AsyncValue<List<Announcement>> listAsync;

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _value(dynamic value) => (value ?? '').toString().trim();

  String _institutionName() {
    final institution = _asMap(access.institution);
    final request = _asMap(access.request);

    final fromInstitution = _value(institution['name']);
    if (fromInstitution.isNotEmpty) return fromInstitution;

    final fromRequest = _value(request['organizationName']);
    if (fromRequest.isNotEmpty) return fromRequest;

    return 'Institution announcements';
  }

  String _domain() {
    final institution = _asMap(access.institution);
    final request = _asMap(access.request);

    final fromInstitution = _value(institution['domain']);
    if (fromInstitution.isNotEmpty) return fromInstitution;

    return _value(request['domain']);
  }

  String _standingLabel() {
    switch (access.state) {
      case InstitutionAccessState.pending:
        return 'Standing: Pending review';
      case InstitutionAccessState.verifiedMember:
        return 'Standing: Active';
      case InstitutionAccessState.authorizedSpeaker:
        return 'Standing: Active with speech authority';
      case InstitutionAccessState.none:
        return 'Standing: Not active';
    }
  }

  @override
  Widget build(BuildContext context) {
    final institutionName = _institutionName();
    final domain = _domain();
    final standing = _standingLabel();

    return AuraScaffold(
      title: 'Announcements',
      showHomeAction: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AuraSpace.s16,
          AuraSpace.s12,
          AuraSpace.s16,
          AuraSpace.s24,
        ),
        children: [
          AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(institutionName, style: AuraText.title),
                const SizedBox(height: AuraSpace.s10),
                Text(
                  'This area holds institution-facing announcement context while platform notices remain visible for reference.',
                  style: AuraText.body,
                ),
                const SizedBox(height: AuraSpace.s12),
                Wrap(
                  spacing: AuraSpace.s10,
                  runSpacing: AuraSpace.s10,
                  children: [
                    _StatusChip(label: standing),
                    if (domain.isNotEmpty) _StatusChip(label: 'Domain: $domain'),
                    FilledButton.icon(
                      onPressed: () => context.go('/announcements/create?scope=institution'),
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Create institution notice'),
                    ),
                    OutlinedButton(
                      onPressed: () => context.go('/institution/dashboard'),
                      child: const Text('Back to institution dashboard'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AuraSpace.s12),
          _PinnedSection(
            asyncValue: pinnedAsync,
            title: 'Pinned platform notices',
          ),
          const SizedBox(height: AuraSpace.s12),
          _AllSection(
            asyncValue: listAsync,
            title: 'Platform announcements',
            emptyTitle: 'Nothing yet',
            emptyBody: 'Platform notices will appear here when published.',
          ),
        ],
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AuraText.title),
          const SizedBox(height: AuraSpace.s10),
          Text(body, style: AuraText.body),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s10,
        vertical: AuraSpace.s6,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AuraText.small.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _PinnedSection extends StatelessWidget {
  const _PinnedSection({
    required this.asyncValue,
    this.title = 'Pinned platform notices',
  });

  final AsyncValue<List<Announcement>> asyncValue;
  final String title;

  @override
  Widget build(BuildContext context) {
    return asyncValue.when(
      loading: () => const _LoadingCard(label: 'Loading pinned…'),
      error: (e, _) => _ErrorCard(error: e),
      data: (items) {
        if (items.isEmpty) {
          return AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AuraText.title),
                const SizedBox(height: AuraSpace.s10),
                Text(
                  'No pinned notices right now.',
                  style: AuraText.body,
                ),
              ],
            ),
          );
        }

        return AuraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AuraText.title),
              const SizedBox(height: AuraSpace.s10),
              for (final a in items) ...[
                _AnnouncementRow(
                  title: a.title.isEmpty ? a.slug : a.title,
                  subtitle: a.publishedAt == null ? null : a.publishedAt!.toLocal().toString(),
                  onTap: () => context.go('/announcements/${a.slug}'),
                ),
                const SizedBox(height: AuraSpace.s8),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _AllSection extends StatelessWidget {
  const _AllSection({
    required this.asyncValue,
    this.title = 'All platform notices',
    this.emptyTitle = 'Nothing yet',
    this.emptyBody = 'When platform notices are published, they will appear here.',
  });

  final AsyncValue<List<Announcement>> asyncValue;
  final String title;
  final String emptyTitle;
  final String emptyBody;

  @override
  Widget build(BuildContext context) {
    return asyncValue.when(
      loading: () => const _LoadingCard(label: 'Loading announcements…'),
      error: (e, _) => _ErrorCard(error: e),
      data: (items) {
        if (items.isEmpty) {
          return AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(emptyTitle, style: AuraText.title),
                const SizedBox(height: AuraSpace.s10),
                Text(
                  emptyBody,
                  style: AuraText.body,
                ),
              ],
            ),
          );
        }

        return AuraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AuraText.title),
              const SizedBox(height: AuraSpace.s10),
              for (final a in items) ...[
                _AnnouncementRow(
                  title: a.title.isEmpty ? a.slug : a.title,
                  subtitle: a.publishedAt == null ? null : a.publishedAt!.toLocal().toString(),
                  onTap: () => context.go('/announcements/${a.slug}'),
                ),
                const SizedBox(height: AuraSpace.s8),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _AnnouncementRow extends StatelessWidget {
  const _AnnouncementRow({
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          children: [
            const Icon(Icons.campaign_outlined, size: 18),
            const SizedBox(width: AuraSpace.s10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: AuraText.small),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AuraSpace.s10),
          Text(label, style: AuraText.body),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Failed to load', style: AuraText.title),
          const SizedBox(height: AuraSpace.s10),
          Text(error.toString(), style: AuraText.body),
        ],
      ),
    );
  }
}