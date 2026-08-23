import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/product/product_state.dart';
import '../../../core/product/product_state_view.dart';
import '../../../core/product/temporal.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/admin_providers.dart';
import 'admin_error.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MIGRATION RECONCILIATION
//
// Why this screen exists: the reconciliation report is Bearer-guarded, so
// opening its API URL in a browser sends only the HttpOnly refresh cookie and
// returns UNAUTHORIZED. The evidence was therefore unreachable by the one
// person who has to sign off on it. This is the authenticated path — the same
// session, the same guard, on every platform the client runs on.
// ─────────────────────────────────────────────────────────────────────────────

class AdminMigrationsScreen extends ConsumerWidget {
  const AdminMigrationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(adminConvergenceReportProvider);

    return AuraScaffold(
      title: 'Migration reconciliation',
      showHomeAction: true,
      body: reportAsync.when(
        loading: () => const AuraProductState(state: ProductState.loading),
        // Retryable: an admin read that failed is worth attempting again, and
        // the recovery offer is honest because nothing here mutates.
        error: (e, _) => AuraProductState(
          state: ProductState.retryableError,
          headline: 'Could not read reconciliation',
          detail: adminErrorMessage(e),
          onRecover: () => ref.invalidate(adminConvergenceReportProvider),
        ),
        data: (report) => _ConvergenceReport(report: report),
      ),
    );
  }
}

class _ConvergenceReport extends StatelessWidget {
  const _ConvergenceReport({required this.report});

  final AdminConvergenceReport report;

  @override
  Widget build(BuildContext context) {
    if (!report.migrated) {
      return AuraProductState(
        state: ProductState.empty,
        headline: 'Convergence has not run here',
        detail: report.reason ?? 'No reconciliation record exists yet.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AuraSpace.s16),
      children: [
        _Verdict(report: report),
        const SizedBox(height: AuraSpace.s16),
        _Section(
          title: 'DirectThread → Conversation',
          subtitle: report.migrationFinishedAt == null
              ? 'Migration timestamp unavailable.'
              : 'Migrated ${ProductTime(report.migrationFinishedAt!, TimeEvent.occurred).exact}',
          rows: [
            _Row('Legacy threads', '${report.sourceThreads}'),
            _Row('Audited threads', '${report.auditedThreads}'),
            _Row('Conversations created', '${report.destinationCreated}'),
            _Row(
              'Merged into existing',
              '${report.destinationMergedIntoExisting}',
            ),
            _Row('Legacy messages', '${report.legacyMessages}'),
            _Row('Migrated messages', '${report.migratedMessages}'),
          ],
        ),
        const SizedBox(height: AuraSpace.s16),
        _Section(
          title: 'Gate — must be zero',
          subtitle:
              'A thread that lost messages, or one that produced no audit row '
              'at all, blocks cutover.',
          rows: [
            _Row(
              'Unreconciled threads',
              '${report.unreconciledThreads}',
              bad: report.unreconciledThreads != 0,
            ),
            _Row(
              'Skipped threads',
              '${report.skippedThreads}',
              bad: report.skippedThreads != 0,
            ),
          ],
        ),
        const SizedBox(height: AuraSpace.s16),
        _Section(
          title: 'Live drift — the cutover condition',
          subtitle:
              'The audit above proves the migration was complete when it ran. '
              'It does not prove the two systems still agree, because the '
              'legacy writer is still live.',
          rows: [
            _Row(
              'Legacy messages not converged',
              '${report.legacyMessagesNotConverged}',
              bad: report.legacyMessagesNotConverged != 0,
            ),
            _Row(
              'Legacy cursors moved since migration',
              '${report.legacyCursorsMovedSinceMigration}',
              bad: report.legacyCursorsMovedSinceMigration != 0,
            ),
          ],
        ),
        const SizedBox(height: AuraSpace.s16),
        _Section(
          title: 'Flagged for adjudication',
          subtitle:
              'An institution slot carried a read cursor. Canonical read state '
              'is per human, so that slot has no equivalent. Recorded rather '
              'than fabricated.',
          rows: [
            _Row(
              'Institution-slot cursors dropped',
              '${report.institutionSideReadStateDropped}',
            ),
          ],
        ),
      ],
    );
  }
}

class _Verdict extends StatelessWidget {
  const _Verdict({required this.report});

  final AdminConvergenceReport report;

  @override
  Widget build(BuildContext context) {
    final ready = report.cutoverReady;
    final auditClean = report.auditClean;

    final (Color tone, IconData icon, String title, String body) = switch ((
      auditClean,
      ready,
    )) {
      (false, _) => (
          const Color(0xFFEF4444),
          Icons.error_outline_rounded,
          'Migration incomplete',
          'History was lost or skipped. Do not cut over.',
        ),
      (true, false) => (
          const Color(0xFFF59E0B),
          Icons.sync_problem_rounded,
          'Migrated, not yet cutover-ready',
          'Nothing was lost, but the legacy system has been written to since '
              'the migration ran. Cutover requires a write freeze or a '
              're-sweep first.',
        ),
      (true, true) => (
          const Color(0xFF22C55E),
          Icons.verified_rounded,
          'Converged and in agreement',
          'Every legacy thread is accounted for and the two systems match as '
              'of this read.',
        ),
    };

    return Container(
      padding: const EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AuraRadius.r16),
        border: Border.all(color: tone.withValues(alpha: 0.40)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tone),
          const SizedBox(width: AuraSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AuraText.emphasis),
                const SizedBox(height: AuraSpace.s4),
                Text(body, style: AuraText.small),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.subtitle,
    required this.rows,
  });

  final String title;
  final String subtitle;
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.r16),
        border: Border.all(color: AuraSurface.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AuraText.emphasis),
          const SizedBox(height: AuraSpace.s4),
          Text(subtitle, style: AuraText.small),
          const SizedBox(height: AuraSpace.s12),
          ...rows,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.bad = false});

  final String label;
  final String value;
  final bool bad;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AuraSpace.s4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AuraText.small)),
          Text(
            value,
            style: AuraText.small.copyWith(
              fontWeight: FontWeight.w700,
              color: bad ? const Color(0xFFEF4444) : null,
            ),
          ),
        ],
      ),
    );
  }
}
