import 'package:flutter/material.dart';

import '../../support_models.dart';

class SupportCaseListTile extends StatelessWidget {
  const SupportCaseListTile({
    super.key,
    required this.supportCase,
    required this.onTap,
  });

  final SupportCaseSummary supportCase;
  final VoidCallback onTap;

  Color _statusColor(BuildContext context, String status) {
    final cs = Theme.of(context).colorScheme;
    switch (status) {
      case 'NEW':
        return Colors.orange;
      case 'OPEN':
        return Colors.blue;
      case 'WAITING_ON_USER':
        return Colors.purple;
      case 'WAITING_ON_AURA':
        return Colors.teal;
      case 'RESOLVED':
        return Colors.green;
      case 'CLOSED':
        return cs.outline;
      default:
        return cs.outline;
    }
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'CRITICAL':
        return Colors.red;
      case 'HIGH':
        return Colors.orange;
      case 'MEDIUM':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(context, supportCase.status);
    final severityColor = _severityColor(supportCase.severity);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        supportCase.ref,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _Badge(label: supportCase.category, color: theme.colorScheme.primary),
                      const SizedBox(width: 4),
                      _Badge(label: supportCase.severity, color: severityColor),
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (supportCase.aiSummary != null) ...[
                    Text(
                      supportCase.aiSummary!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 2),
                  ],
                  Row(
                    children: [
                      Icon(Icons.circle, size: 8, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        supportCase.status.replaceAll('_', ' '),
                        style: theme.textTheme.labelSmall?.copyWith(color: statusColor),
                      ),
                      if (supportCase.requesterEmail != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          supportCase.requesterEmail!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (supportCase.assignedAdminDisplayName != null)
              Chip(
                label: Text(
                  supportCase.assignedAdminDisplayName!,
                  style: theme.textTheme.labelSmall,
                ),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
      ),
    );
  }
}
