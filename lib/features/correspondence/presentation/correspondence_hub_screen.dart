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
                  'This is the communication desk for Aura. Inbox lives here alongside contacts, institutions, and templates.',
                  style: AuraText.body,
                ),
                const SizedBox(height: AuraSpace.s12),
                Wrap(
                  spacing: AuraSpace.s10,
                  runSpacing: AuraSpace.s10,
                  children: [
                    OutlinedButton(
                      onPressed: () => context.go('/me'),
                      child: const Text('Back to account'),
                    ),
                    OutlinedButton(
                      onPressed: () => _tabs.animateTo(0),
                      child: const Text('Open inbox'),
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
                  height: 420,
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
            'Inbox UI is now anchored inside the final Correspondence Hub. Next step is connecting the live admin inbox data and states: New, Open, Waiting, Closed.',
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

class _InstitutionsPanel extends StatelessWidget {
  const _InstitutionsPanel();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Institutions', style: AuraText.title),
        const SizedBox(height: AuraSpace.s10),
        Text(
          'Organization records connected to inquiries, partnerships, and institutional participation will live here.',
          style: AuraText.body,
        ),
        const SizedBox(height: AuraSpace.s14),
        const AuraCard(
          child: Text(
            'Institutions will become the organizational layer of correspondence and admin routing.',
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