import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';

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
              _InstitutionStatePanel(
                title: 'Pending institution requests',
                body:
                    'Verification requests awaiting review will appear here. This is where approval and rejection actions belong.',
              ),
              _InstitutionStatePanel(
                title: 'Verified institutions',
                body:
                    'Approved institutions will appear here as active records inside the system.',
              ),
              _InstitutionStatePanel(
                title: 'Suspended institutions',
                body:
                    'Institutions whose standing is temporarily restricted will appear here.',
              ),
              _InstitutionStatePanel(
                title: 'Rejected institutions',
                body:
                    'Rejected requests and rejected institution records will appear here for reference.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InstitutionStatePanel extends StatelessWidget {
  const _InstitutionStatePanel({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AuraText.title),
        const SizedBox(height: AuraSpace.s10),
        Text(body, style: AuraText.body),
        const SizedBox(height: AuraSpace.s14),
        const AuraCard(
          child: Text(
            'Live institution request and approval data will be connected here next.',
            style: AuraText.body,
          ),
        ),
      ],
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