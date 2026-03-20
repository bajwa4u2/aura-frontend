import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/admin_access_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';

class AdminWorkspaceScreen extends ConsumerWidget {
  const AdminWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminAsync = ref.watch(appAdminAccessProvider);

    return AuraScaffold(
      title: 'Admin workspace',
      showHomeAction: true,
      body: adminAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: AuraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Failed to load', style: AuraText.title),
                  const SizedBox(height: AuraSpace.s10),
                  Text(e.toString(), style: AuraText.body),
                ],
              ),
            ),
          ),
        ),
        data: (admin) {
          if (!admin.isAdmin) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: AuraCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Not available', style: AuraText.title),
                      const SizedBox(height: AuraSpace.s10),
                      Text(
                        'This workspace is only available to platform admins.',
                        style: AuraText.body,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final me = admin.me ?? <String, dynamic>{};
          final name = (me['displayName'] ?? me['name'] ?? '').toString().trim();
          final email = (me['email'] ?? '').toString().trim();

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.s16,
              AuraSpace.s12,
              AuraSpace.s16,
              AuraSpace.s24,
            ),
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AuraCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Admin workspace', style: AuraText.title),
                          const SizedBox(height: AuraSpace.s8),
                          Text(
                            'This is the platform authority surface. It should hold the administrative tools that shape system-level behavior without mixing them into member presence.',
                            style: AuraText.body,
                          ),
                          const SizedBox(height: AuraSpace.s12),
                          Wrap(
                            spacing: AuraSpace.s10,
                            runSpacing: AuraSpace.s10,
                            children: [
                              if (name.isNotEmpty) _Chip(label: name),
                              if (email.isNotEmpty) _Chip(label: email),
                              const _Chip(label: 'Role: Platform admin'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AuraSpace.s12),
                    AuraCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Authority surfaces', style: AuraText.title),
                          const SizedBox(height: AuraSpace.s10),
                          Text(
                            'Announcements are wired first. Other system controls can be added here without leaking admin functions into member-facing routes.',
                            style: AuraText.body,
                          ),
                          const SizedBox(height: AuraSpace.s14),
                          Wrap(
                            spacing: AuraSpace.s10,
                            runSpacing: AuraSpace.s10,
                            children: [
                              FilledButton.icon(
                                onPressed: () => context.go('/announcements'),
                                icon: const Icon(Icons.campaign_outlined),
                                label: const Text('Announcements'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

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
