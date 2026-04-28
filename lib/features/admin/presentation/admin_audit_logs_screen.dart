import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/admin_providers.dart';

class AdminAuditLogsScreen extends ConsumerWidget {
  const AdminAuditLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(adminAuditLogsProvider);

    return AuraScaffold(
      title: 'Audit log',
      showHomeAction: true,
      body: logsAsync.when(
        loading: () => const Center(
          child: AuraLoadingState(message: 'Loading audit log…'),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AuraSpace.s16),
            child: AuraErrorState(
              title: 'Failed to load audit log',
              body: e.toString(),
              action: AuraSecondaryButton(
                label: 'Retry',
                icon: Icons.refresh_rounded,
                onPressed: () => ref.invalidate(adminAuditLogsProvider),
              ),
            ),
          ),
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(
              child: AuraEmptyState(
                title: 'No audit entries',
                body: 'Admin actions will appear here once recorded.',
                icon: Icons.history_rounded,
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.s16,
              AuraSpace.s16,
              AuraSpace.s16,
              AuraSpace.s32,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AuraSurface.card,
                      borderRadius: BorderRadius.circular(AuraRadius.card),
                      border: Border.all(color: AuraSurface.divider),
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < entries.length; i++) ...[
                          _AuditRow(entry: entries[i]),
                          if (i < entries.length - 1)
                            Container(
                              height: 1,
                              margin: const EdgeInsets.symmetric(
                                horizontal: AuraSpace.s16,
                              ),
                              color: AuraSurface.divider,
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.entry});

  final AdminAuditLogEntry entry;

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '${months[local.month - 1]} ${local.day}, ${local.year} $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s16,
        vertical: AuraSpace.s12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AuraSurface.elevated,
              borderRadius: BorderRadius.circular(AuraRadius.md),
              border: Border.all(color: AuraSurface.divider),
            ),
            child: const Icon(
              Icons.history_rounded,
              size: 16,
              color: AuraSurface.faint,
            ),
          ),
          const SizedBox(width: AuraSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.action,
                  style: AuraText.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AuraSurface.ink,
                  ),
                ),
                const SizedBox(height: AuraSpace.s4),
                Text(
                  entry.actorEmail.isNotEmpty
                      ? entry.actorEmail
                      : entry.actorId,
                  style: AuraText.small.copyWith(color: AuraSurface.muted),
                ),
                if (entry.targetType.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Target: ${entry.targetType}${entry.targetId != null ? ' · ${entry.targetId}' : ''}',
                    style: AuraText.micro.copyWith(color: AuraSurface.faint),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AuraSpace.s10),
          Text(
            _formatDate(entry.createdAt),
            style: AuraText.micro.copyWith(color: AuraSurface.faint),
          ),
        ],
      ),
    );
  }
}
