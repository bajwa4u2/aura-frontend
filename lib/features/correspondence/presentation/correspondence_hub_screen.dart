import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../data/institutions_repository.dart';

class CorrespondenceHubScreen extends StatefulWidget {
  const CorrespondenceHubScreen({super.key});

  @override
  State<CorrespondenceHubScreen> createState() =>
      _CorrespondenceHubScreenState();
}

class _CorrespondenceHubScreenState extends State<CorrespondenceHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  static const _tabTitles = <String>[
    'Inbox',
    'Contacts',
    'Institutions',
    'Templates',
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _tabTitles.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuraScaffold(
      title: 'Correspondence',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Correspondence Hub', style: AuraText.title),
                const SizedBox(height: AuraSpace.s10),
                Text(
                  'This is the communication desk for Aura. Inbox, contacts, institutions, and templates are managed here as one system.',
                  style: AuraText.body,
                ),
                const SizedBox(height: AuraSpace.s12),
                OutlinedButton(
                  onPressed: () => context.go('/me'),
                  child: const Text('Back to account'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AuraSpace.s14),
          AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TabBar(
                  controller: _tabs,
                  isScrollable: true,
                  tabs: const [
                    Tab(text: 'Inbox'),
                    Tab(text: 'Contacts'),
                    Tab(text: 'Institutions'),
                    Tab(text: 'Templates'),
                  ],
                ),
                const SizedBox(height: AuraSpace.s14),
                SizedBox(
                  height: 520,
                  child: TabBarView(
                    controller: _tabs,
                    children: const [
                      _InboxPanel(),
                      _ContactsPanel(),
                      _InstitutionsPanel(),
                      _TemplatesPanel(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InboxPanel extends StatelessWidget {
  const _InboxPanel();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Inbox', style: AuraText.title),
        const SizedBox(height: AuraSpace.s10),
        Text(
          'Incoming contact submissions will appear here. This is the first operational layer of the hub.',
          style: AuraText.body,
        ),
        const SizedBox(height: AuraSpace.s14),
        const AuraCard(
          child: Text(
            'Inbox will carry live admin message states: New, Open, Waiting, and Closed.',
            style: AuraText.body,
          ),
        ),
      ],
    );
  }
}

class _ContactsPanel extends StatelessWidget {
  const _ContactsPanel();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Contacts', style: AuraText.title),
        const SizedBox(height: AuraSpace.s10),
        Text(
          'People records created from contact intake and future communication activity will live here.',
          style: AuraText.body,
        ),
        const SizedBox(height: AuraSpace.s14),
        const AuraCard(
          child: Text(
            'Contacts will become the people directory behind communication history.',
            style: AuraText.body,
          ),
        ),
      ],
    );
  }
}

class _InstitutionsPanel extends StatefulWidget {
  const _InstitutionsPanel();

  @override
  State<_InstitutionsPanel> createState() => _InstitutionsPanelState();
}

class _InstitutionsPanelState extends State<_InstitutionsPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  static const _statusTabs = <String>[
    'Pending',
    'Verified',
    'Suspended',
    'Rejected',
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _statusTabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Institutions', style: AuraText.title),
        const SizedBox(height: AuraSpace.s10),
        Text(
          'Institution verification and institution records are managed here together.',
          style: AuraText.body,
        ),
        const SizedBox(height: AuraSpace.s14),
        TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Verified'),
            Tab(text: 'Suspended'),
            Tab(text: 'Rejected'),
          ],
        ),
        const SizedBox(height: AuraSpace.s14),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: const [
              _PendingInstitutionPanel(),
              _VerifiedInstitutionsPanel(),
              _SuspendedInstitutionsPanel(),
              _RejectedInstitutionsPanel(),
            ],
          ),
        ),
      ],
    );
  }
}

String _readValue(Map<String, dynamic> map, String key) {
  return (map[key] ?? '').toString().trim();
}

String _readInstitutionSlug(Map<String, dynamic> map) {
  return _readValue(map, 'slug');
}

Widget _institutionOpenProfileButton(BuildContext context, String slug) {
  if (slug.isEmpty) return const SizedBox.shrink();

  return OutlinedButton(
    onPressed: () => context.go('/institutions/$slug'),
    child: const Text('Open public profile'),
  );
}

class _PendingInstitutionPanel extends ConsumerWidget {
  const _PendingInstitutionPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingInstitutionRequestsProvider);

    return pendingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e', style: AuraText.body),
      data: (items) {
        if (items.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pending institution requests', style: AuraText.title),
              const SizedBox(height: AuraSpace.s10),
              Text(
                'There are no pending institution verification requests right now.',
                style: AuraText.body,
              ),
            ],
          );
        }

        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: AuraSpace.s10),
          itemBuilder: (context, i) {
            final r = items[i];
            final id = _readValue(r, 'id');
            final organizationName =
                _readValue(r, 'organizationName').isEmpty
                    ? 'Unnamed institution'
                    : _readValue(r, 'organizationName');
            final workEmail = _readValue(r, 'workEmail');
            final websiteUrl = _readValue(r, 'websiteUrl');
            final roleTitle = _readValue(r, 'roleTitle');
            final jurisdiction = _readValue(r, 'jurisdiction');
            final purpose = _readValue(r, 'purpose');

            return AuraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(organizationName, style: AuraText.title),
                  if (workEmail.isNotEmpty) ...[
                    const SizedBox(height: AuraSpace.s6),
                    Text(workEmail, style: AuraText.small),
                  ],
                  if (websiteUrl.isNotEmpty) ...[
                    const SizedBox(height: AuraSpace.s6),
                    Text('Website: $websiteUrl', style: AuraText.small),
                  ],
                  if (roleTitle.isNotEmpty) ...[
                    const SizedBox(height: AuraSpace.s6),
                    Text('Role: $roleTitle', style: AuraText.small),
                  ],
                  if (jurisdiction.isNotEmpty) ...[
                    const SizedBox(height: AuraSpace.s6),
                    Text('Jurisdiction: $jurisdiction', style: AuraText.small),
                  ],
                  if (purpose.isNotEmpty) ...[
                    const SizedBox(height: AuraSpace.s10),
                    Text(purpose, style: AuraText.body),
                  ],
                  const SizedBox(height: AuraSpace.s12),
                  Wrap(
                    spacing: AuraSpace.s10,
                    runSpacing: AuraSpace.s10,
                    children: [
                      FilledButton(
                        onPressed: id.isEmpty
                            ? null
                            : () async {
                                await ref.read(
                                  approveInstitutionRequestProvider(id).future,
                                );
                                ref.invalidate(pendingInstitutionRequestsProvider);
                                ref.invalidate(verifiedInstitutionsProvider);
                              },
                        child: const Text('Approve'),
                      ),
                      OutlinedButton(
                        onPressed: id.isEmpty
                            ? null
                            : () async {
                                await ref.read(
                                  rejectInstitutionRequestProvider(id).future,
                                );
                                ref.invalidate(pendingInstitutionRequestsProvider);
                                ref.invalidate(rejectedInstitutionsProvider);
                              },
                        child: const Text('Reject'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _VerifiedInstitutionsPanel extends ConsumerWidget {
  const _VerifiedInstitutionsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verifiedAsync = ref.watch(verifiedInstitutionsProvider);

    return verifiedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e', style: AuraText.body),
      data: (items) {
        if (items.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Verified institutions', style: AuraText.title),
              const SizedBox(height: AuraSpace.s10),
              Text(
                'No verified institutions yet.',
                style: AuraText.body,
              ),
            ],
          );
        }

        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: AuraSpace.s10),
          itemBuilder: (context, i) {
            final item = items[i];
            final name = _readValue(item, 'name').isEmpty
                ? 'Unnamed institution'
                : _readValue(item, 'name');
            final slug = _readInstitutionSlug(item);
            final websiteUrl = _readValue(item, 'websiteUrl');
            final domain = _readValue(item, 'domain');
            final jurisdiction = _readValue(item, 'jurisdiction');

            return AuraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AuraText.title),
                  if (slug.isNotEmpty) ...[
                    const SizedBox(height: AuraSpace.s6),
                    Text('Slug: $slug', style: AuraText.small),
                  ],
                  if (websiteUrl.isNotEmpty) ...[
                    const SizedBox(height: AuraSpace.s6),
                    Text('Website: $websiteUrl', style: AuraText.small),
                  ],
                  if (domain.isNotEmpty) ...[
                    const SizedBox(height: AuraSpace.s6),
                    Text('Domain: $domain', style: AuraText.small),
                  ],
                  if (jurisdiction.isNotEmpty) ...[
                    const SizedBox(height: AuraSpace.s6),
                    Text('Jurisdiction: $jurisdiction', style: AuraText.small),
                  ],
                  if (slug.isNotEmpty) ...[
                    const SizedBox(height: AuraSpace.s12),
                    _institutionOpenProfileButton(context, slug),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SuspendedInstitutionsPanel extends ConsumerWidget {
  const _SuspendedInstitutionsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suspendedAsync = ref.watch(suspendedInstitutionsProvider);

    return suspendedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e', style: AuraText.body),
      data: (items) {
        if (items.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Suspended institutions', style: AuraText.title),
              const SizedBox(height: AuraSpace.s10),
              Text(
                'No suspended institutions.',
                style: AuraText.body,
              ),
            ],
          );
        }

        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: AuraSpace.s10),
          itemBuilder: (context, i) {
            final item = items[i];
            final name = _readValue(item, 'name').isEmpty
                ? 'Unnamed institution'
                : _readValue(item, 'name');
            final slug = _readInstitutionSlug(item);
            final domain = _readValue(item, 'domain');
            final jurisdiction = _readValue(item, 'jurisdiction');

            return AuraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AuraText.title),
                  if (slug.isNotEmpty) ...[
                    const SizedBox(height: AuraSpace.s6),
                    Text('Slug: $slug', style: AuraText.small),
                  ],
                  if (domain.isNotEmpty) ...[
                    const SizedBox(height: AuraSpace.s6),
                    Text('Domain: $domain', style: AuraText.small),
                  ],
                  if (jurisdiction.isNotEmpty) ...[
                    const SizedBox(height: AuraSpace.s6),
                    Text('Jurisdiction: $jurisdiction', style: AuraText.small),
                  ],
                  if (slug.isNotEmpty) ...[
                    const SizedBox(height: AuraSpace.s12),
                    _institutionOpenProfileButton(context, slug),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _RejectedInstitutionsPanel extends ConsumerWidget {
  const _RejectedInstitutionsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rejectedAsync = ref.watch(rejectedInstitutionsProvider);

    return rejectedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e', style: AuraText.body),
      data: (items) {
        if (items.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rejected institutions', style: AuraText.title),
              const SizedBox(height: AuraSpace.s10),
              Text(
                'No rejected institutions.',
                style: AuraText.body,
              ),
            ],
          );
        }

        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: AuraSpace.s10),
          itemBuilder: (context, i) {
            final item = items[i];
            final name = _readValue(item, 'name').isEmpty
                ? 'Unnamed institution'
                : _readValue(item, 'name');
            final slug = _readInstitutionSlug(item);
            final domain = _readValue(item, 'domain');
            final jurisdiction = _readValue(item, 'jurisdiction');

            return AuraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AuraText.title),
                  if (slug.isNotEmpty) ...[
                    const SizedBox(height: AuraSpace.s6),
                    Text('Slug: $slug', style: AuraText.small),
                  ],
                  if (domain.isNotEmpty) ...[
                    const SizedBox(height: AuraSpace.s6),
                    Text('Domain: $domain', style: AuraText.small),
                  ],
                  if (jurisdiction.isNotEmpty) ...[
                    const SizedBox(height: AuraSpace.s6),
                    Text('Jurisdiction: $jurisdiction', style: AuraText.small),
                  ],
                  if (slug.isNotEmpty) ...[
                    const SizedBox(height: AuraSpace.s12),
                    _institutionOpenProfileButton(context, slug),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _TemplatesPanel extends StatelessWidget {
  const _TemplatesPanel();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Templates', style: AuraText.title),
        const SizedBox(height: AuraSpace.s10),
        Text(
          'Reusable response patterns for support, institutions, investors, and privacy communication will live here.',
          style: AuraText.body,
        ),
        const SizedBox(height: AuraSpace.s14),
        const AuraCard(
          child: Text(
            'Templates will help keep replies consistent once outbound handling is connected.',
            style: AuraText.body,
          ),
        ),
      ],
    );
  }
}