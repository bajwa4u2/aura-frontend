import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/admin/data/admin_models.dart';

void main() {
  AdminConvergenceReport parse(Map<String, dynamic> json) =>
      AdminConvergenceReport.fromJson(json);

  const migratedAndClean = {
    'migrated': true,
    'sourceThreads': 5,
    'auditedThreads': 5,
    'unreconciledThreads': 0,
    'skippedThreads': 0,
    'legacyMessagesNotConverged': 0,
    'legacyCursorsMovedSinceMigration': 0,
  };

  group('AdminConvergenceReport', () {
    test('a clean audit is not by itself a cutover verdict', () {
      // The exact confusion this screen exists to prevent: the migration was
      // complete when it ran, but the legacy writer has moved since.
      final report = parse({
        ...migratedAndClean,
        'legacyCursorsMovedSinceMigration': 1,
      });

      expect(report.auditClean, isTrue);
      expect(report.cutoverReady, isFalse);
    });

    test('cutover readiness requires present-tense agreement', () {
      expect(parse(migratedAndClean).cutoverReady, isTrue);

      expect(
        parse({...migratedAndClean, 'legacyMessagesNotConverged': 2})
            .cutoverReady,
        isFalse,
      );
    });

    test('a lost or skipped thread fails the audit outright', () {
      expect(parse({...migratedAndClean, 'unreconciledThreads': 1}).auditClean,
          isFalse);
      expect(
          parse({...migratedAndClean, 'skippedThreads': 1}).auditClean, isFalse);
    });

    test('an unrun migration reports as unrun rather than as converged', () {
      final report = parse({
        'migrated': false,
        'reason': 'convergence migration has not run here',
      });

      expect(report.migrated, isFalse);
      expect(report.reason, 'convergence migration has not run here');
    });
  });
}
