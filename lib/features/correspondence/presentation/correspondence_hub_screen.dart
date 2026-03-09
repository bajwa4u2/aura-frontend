import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../../institutions/data/institutions_repository.dart';

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

final _correspondenceMeProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/users/me');
  return _unwrapMap(res.data);
});

enum _CorrespondenceMode {
  admin,
  institution,
  member,
}

class CorrespondenceHubScreen extends ConsumerWidget {
  const CorrespondenceHubScreen({super.key});

  bool _isAdmin(Map<String, dynamic> me) {
    final role = (me['role'] ?? '').toString().toLowerCase();
    if (role == 'admin') return true;

    final id = (me['id'] ?? '').toString().trim();
    if (id.isEmpty) return false;

    return _adminUserIdList().contains(id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meAsync = ref.watch(_correspondenceMeProvider);
    final institutionAsync = ref.watch(institutionAccessProvider);

    return meAsync.when(
      loading: () => AuraScaffold(
        title: 'Correspondence',
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AuraScaffold(
        title: 'Correspondence',
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Could not load correspondence workspace.',
                  style: AuraText.title,
                ),
                const SizedBox(height: AuraSpace.s10),
                Text('$e', style: AuraText.body),
              ],
            ),
          ),
        ),
      ),
      data: (me) {
        final isAdmin = _isAdmin(me);

        if (isAdmin) {
          return const _AdminCorrespondenceScreen();
        }

        return institutionAsync.when(
          loading: () => AuraScaffold(
            title: 'Correspondence',
            body: const Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const _MemberCorrespondenceScreen(),
          data: (institutionAccess) {
            final hasInstitutionStanding =
                institutionAccess.state == InstitutionAccessState.pending ||
                    institutionAccess.state ==
                        InstitutionAccessState.verifiedMember ||
                    institutionAccess.state ==
                        InstitutionAccessState.authorizedSpeaker;

            if (hasInstitutionStanding) {
              return _InstitutionCorrespondenceScreen(
                access: institutionAccess,
              );
            }

            return const _MemberCorrespondenceScreen();
          },
        );
      },
    );
  }
}

class _SectionIntroCard extends StatelessWidget {
  const _SectionIntroCard({
    required this.title,
    required this.body,
    this.backLabel = 'Back to account',
    this.backRoute = '/me',
  });

  final String title;
  final String body;
  final String backLabel;
  final String backRoute;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AuraText.title),
          const SizedBox(height: AuraSpace.s10),
          Text(body, style: AuraText.body),
          const SizedBox(height: AuraSpace.s12),
          OutlinedButton(
            onPressed: () => context.go(backRoute),
            child: Text(backLabel),
          ),
        ],
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.title,
    required this.detail,
    required this.status,
    this.onTap,
  });

  final String title;
  final String detail;
  final String status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 132),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.all(AuraSpace.s14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AuraSpace.s8),
                Expanded(
                  child: Text(detail, style: AuraText.body),
                ),
                const SizedBox(height: AuraSpace.s10),
                Text(
                  status,
                  style: AuraText.small.copyWith(
                    fontWeight: FontWeight.w600,
                    color: enabled ? Colors.black87 : Colors.black54,
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

class _ToolGrid extends StatelessWidget {
  const _ToolGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AuraSpace.s12,
      runSpacing: AuraSpace.s12,
      children: children
          .map((child) => SizedBox(width: 320, child: child))
          .toList(),
    );
  }
}

class _AdminCorrespondenceScreen extends StatefulWidget {
  const _AdminCorrespondenceScreen();

  @override
  State<_AdminCorrespondenceScreen> createState() =>
      _AdminCorrespondenceScreenState();
}

class _AdminCorrespondenceScreenState extends State<_AdminCorrespondenceScreen>
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
      title: 'Admin Correspondence',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const _SectionIntroCard(
            title: 'Admin Correspondence Hub',
            body:
                'This workspace belongs to the platform administrator. Inbox handling, contacts, institution review, and templates are managed here as one operational system.',
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
                  height: 540,
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

class _InstitutionCorrespondenceScreen extends StatelessWidget {
  const _InstitutionCorrespondenceScreen({required this.access});

  final InstitutionAccess access;

  String _value(dynamic value) => (value ?? '').toString().trim();

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _institutionName() {
    final institution = _asMap(access.institution);
    final request = _asMap(access.request);

    final fromInstitution = _value(institution['name']);
    if (fromInstitution.isNotEmpty) return fromInstitution;

    final fromRequest = _value(request['organizationName']);
    if (fromRequest.isNotEmpty) return fromRequest;

    return 'Institution correspondence';
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
    final standing = _standingLabel();

    return AuraScaffold(
      title: 'Institution Correspondence',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(institutionName, style: AuraText.title),
                const SizedBox(height: AuraSpace.s10),
                Text(
                  'This workspace belongs to the institution-facing account surface. It should remain separate from app-admin correspondence handling.',
                  style: AuraText.body,
                ),
                const SizedBox(height: AuraSpace.s12),
                Wrap(
                  spacing: AuraSpace.s10,
                  runSpacing: AuraSpace.s10,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AuraSpace.s10,
                        vertical: AuraSpace.s6,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        standing,
                        style: AuraText.small.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
          const SizedBox(height: AuraSpace.s14),
          AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Institution correspondence tools', style: AuraText.title),
                const SizedBox(height: AuraSpace.s10),
                Text(
                  'These tools should be institution-specific. Until their routes and workflows are built, they remain placeholders instead of borrowing admin paths.',
                  style: AuraText.body,
                ),
                const SizedBox(height: AuraSpace.s12),
                const _ToolGrid(
                  children: [
                    _ToolTile(
                      title: 'Institution inbox',
                      detail:
                          'Incoming institution-related messages and replies should appear here.',
                      status: 'Placeholder',
                    ),
                    _ToolTile(
                      title: 'Outbound correspondence',
                      detail:
                          'Institution-originated replies, statements, and message history should live here.',
                      status: 'Placeholder',
                    ),
                    _ToolTile(
                      title: 'Representative directory',
                      detail:
                          'Approved institution representatives and correspondence roles should be visible here.',
                      status: 'Placeholder',
                    ),
                    _ToolTile(
                      title: 'Response templates',
                      detail:
                          'Institution-safe reusable responses and templates should live here.',
                      status: 'Placeholder',
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
}

class _MemberCorrespondenceScreen extends StatelessWidget {
  const _MemberCorrespondenceScreen();

  @override
  Widget build(BuildContext context) {
    return AuraScaffold(
      title: 'Correspondence',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const _SectionIntroCard(
            title: 'Member Correspondence',
            body:
                'This space belongs to the signed-in member account. Admin correspondence and institution correspondence are handled in separate workspaces.',
          ),
          const SizedBox(height: AuraSpace.s14),
          AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Member correspondence tools', style: AuraText.title),
                const SizedBox(height: AuraSpace.s10),
                Text(
                  'Member correspondence is not fully built yet. This surface should stay separate from both app-admin handling and institution workflows.',
                  style: AuraText.body,
                ),
                const SizedBox(height: AuraSpace.s12),
                const _ToolGrid(
                  children: [
                    _ToolTile(
                      title: 'Inbox',
                      detail:
                          'Personal correspondence for the signed-in member account should appear here.',
                      status: 'Placeholder',
                    ),
                    _ToolTile(
                      title: 'Contacts',
                      detail:
                          'Member-facing contact history and conversation records should live here.',
                      status: 'Placeholder',
                    ),
                    _ToolTile(
                      title: 'Templates',
                      detail:
                          'Reusable member-safe replies and drafts should live here later.',
                      status: 'Placeholder',
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
          'Incoming contact submissions will appear here. This is the first operational layer of the admin hub.',
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
          'Institution review and institution records are managed here for the app-admin workspace only.',
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
            final organizationName = _readValue(r, 'organizationName').isEmpty
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