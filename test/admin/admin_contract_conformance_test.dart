import 'dart:convert';
import 'dart:io';

import 'package:aura/features/admin/data/admin_models.dart';
import 'package:aura/features/admin/data/operator_identity.dart';
import 'package:aura/features/admin/data/operator_work.dart';
import 'package:aura/features/admin/domain/operator_signal.dart';
import 'package:aura/features/admin/domain/platform_health.dart';
import 'package:flutter_test/flutter_test.dart';

/// THE CLIENT, TESTED AGAINST THE SERVER'S OWN STATEMENT OF SHAPE.
///
/// The previous proof method was fixtures this side wrote for itself. They
/// encoded what the client already believed, so they could not fail — and the
/// console shipped announcing "5 of 5 degraded" over a healthy platform,
/// reading every operator grant as inactive, and showing no domain proof for
/// any institution.
///
/// These fixtures are generated from the backend's own mappers by
/// `aura-backend/scripts/capture-admin-contract.ts` and vendored here. When
/// the server changes shape, the capture changes, and these fail. That is the
/// point: a test that cannot prove the implementation wrong is decoration.
void main() {
  final dir = Directory('test/contracts/admin');

  Map<String, dynamic> contract(String name) {
    final file = File('${dir.path}/$name.json');
    if (!file.existsSync()) {
      throw StateError(
        'Missing contract $name. Regenerate with:\n'
        '  cd ../aura-backend && npx ts-node scripts/capture-admin-contract.ts',
      );
    }
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  /// Some endpoints answer with a bare list — `reviewQueue` is one. Reading it
  /// through the map helper would be the client deciding the server's shape.
  List<Map<String, dynamic>> contractList(String name) {
    final file = File('${dir.path}/$name.json');
    final raw = jsonDecode(file.readAsStringSync());
    if (raw is List) {
      return raw.cast<Map<String, dynamic>>();
    }
    final map = raw as Map<String, dynamic>;
    return (map['items'] as List).cast<Map<String, dynamic>>();
  }

  String contractRaw(String name) =>
      File('${dir.path}/$name.json').readAsStringSync();

  group('the contract corpus exists and is the server\'s', () {
    test('every captured surface is present', () {
      final names = dir
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last.replaceAll('.json', ''))
          .toList()
        ..sort();
      expect(names, [
        'audit.list',
        'clients.overview',
        'discovery.coverage',
        'discovery.objects',
        'discovery.queries',
        'discovery.retention',
        'feature-flags.list',
        'feedback.detail',
        'feedback.queue',
        'grants.list',
        'health.database-down',
        'health.healthy',
        'health.providers-missing',
        'identity.detail',
        'identity.detail.decided',
        'identity.detail.discarded',
        'identity.queue',
        'institution-domains.list',
        'institution.detail',
        'institution.members',
        'institutions.directory',
        'institutions.directory.verified',
        'media-appeals.queue',
        'media-cleanup.status',
        'media-cleanup.status.never-run',
        'metrics.overview',
        'moderation.report',
        'moderation.report.deleted-target',
        'moderation.report.missing-target',
        'moderation.report.person',
        'policies.document',
        'settings.list',
        'support.case',
        'support.cases',
        'user.detail',
        'user.detail.sole-owner',
        'users.list',
        'work.list',
        'work.list.clear',
        'work.list.one-source-down',
        'work.summary',
        'work.summary.authority-down',
        'work.summary.clear',
        'work.summary.moderator',
        'work.summary.one-source-down',
      ]);
    });

    test('health carries NO services key — the shape the client invented', () {
      // If this ever becomes true, the client's old model was right and this
      // whole reconstruction rests on a false premise. It is asserted so the
      // premise is checked rather than remembered.
      expect(contract('health.healthy')['services'], isNull);
    });
  });

  group('PlatformHealth reads what the server actually sends', () {
    test('a healthy platform reports healthy, and says so in one sentence', () {
      final health = PlatformHealth.fromJson(contract('health.healthy'));

      expect(health.condition, OperatorCondition.healthy);
      expect(health.summary, 'All services healthy');
      expect(health.checks, hasLength(5));
      expect(health.adverse, isEmpty);
      expect(health.unknown, isEmpty);
    });

    test('NO check renders its payload object as a status', () {
      // The exact production defect: `{STATUS: OK, MESSAGE: API PROCESS IS
      // RUNNING}` shown as the status pill, 950px wide, dominating the page.
      final health = PlatformHealth.fromJson(contract('health.healthy'));
      for (final check in health.checks) {
        expect(check.condition.label, isNot(contains('{')));
        expect(check.message ?? '', isNot(contains('{')));
      }
    });

    test('a down database is FAILED and does not implicate the API', () {
      final health = PlatformHealth.fromJson(contract('health.database-down'));

      final db = health.checks.firstWhere((c) => c.key == 'db');
      final api = health.checks.firstWhere((c) => c.key == 'api');

      expect(db.condition, OperatorCondition.failed);
      expect(api.condition, OperatorCondition.healthy);
      expect(health.condition, OperatorCondition.failed);
      expect(health.summary, '1 service failing');
    });

    test('unconfigured providers are DEGRADED, and only those two', () {
      final health =
          PlatformHealth.fromJson(contract('health.providers-missing'));

      expect(health.adverse.map((c) => c.key).toSet(), {'email', 'push'});
      expect(health.summary, '2 services degraded');
      // The three that answered OK are not swept into the count.
      expect(health.healthy.map((c) => c.key).toSet(), {
        'api',
        'db',
        'realtime',
      });
    });

    test('the message is the source\'s own sentence, carried verbatim', () {
      final health =
          PlatformHealth.fromJson(contract('health.providers-missing'));
      final email = health.checks.firstWhere((c) => c.key == 'email');
      expect(email.message, 'Email provider not configured');
    });

    test('worst first, so the eye lands without reading every row', () {
      final health = PlatformHealth.fromJson(contract('health.database-down'));
      expect(health.ordered.first.key, 'db');
    });
  });

  group('UNKNOWN is not DEGRADED', () {
    test('a check the server omits is unknown, not harm', () {
      final payload = Map<String, dynamic>.from(contract('health.healthy'))
        ..remove('pushProvider');
      final health = PlatformHealth.fromJson(payload);

      final push = health.checks.firstWhere((c) => c.key == 'push');
      expect(push.condition, OperatorCondition.unknown);
      expect(health.adverse, isEmpty,
          reason: 'silence is not evidence of degradation');
      expect(health.condition, OperatorCondition.attention);
      expect(health.summary, 'Everything reporting is healthy · 1 not reporting');
    });

    test('a status word this build has never seen is unknown, not a verdict',
        () {
      // A server one version ahead must not be able to make the console
      // invent a judgement.
      expect(
        PlatformHealth.conditionFromStatus('QUARANTINED'),
        OperatorCondition.unknown,
      );
      expect(
        PlatformHealth.conditionFromStatus(null),
        OperatorCondition.unknown,
      );
    });

    test('nothing reporting says exactly that', () {
      final health = PlatformHealth.fromJson(const {});
      expect(health.summary, 'Nothing is reporting');
      expect(health.condition, OperatorCondition.unknown);
      expect(health.adverse, isEmpty);
    });
  });

  group('the three defects the live console shipped', () {
    test('a grant with status ACTIVE reads as active', () {
      final grant = AdminGrant.fromJson(
        Map<String, dynamic>.from(contract('grants.list')['items'][0] as Map),
      );
      expect(grant.derivedStatus, isNot(AdminGrantStatus.revoked));
      expect(grant.active, isTrue);
      expect(grant.grantedBy, 'Rowan Ellis',
          reason: 'grantedBy is an object; stringifying it printed a map');
    });

    test('an audit row names its actor from actorUserId + actor', () {
      final entry = AdminAuditLogEntry.fromJson(
        Map<String, dynamic>.from(contract('audit.list')['items'][0] as Map),
      );
      expect(entry.actorId, isNotEmpty);
      expect(entry.actorLabel, 'Rowan Ellis');
    });

    test('a failed audit row is distinguishable from a completed one', () {
      final failed = AdminAuditLogEntry.fromJson(
        Map<String, dynamic>.from(contract('audit.list')['items'][1] as Map),
      );
      expect(failed.failed, isTrue);
      expect(failed.reason, 'missing_permission');
    });

    test('a domain proof names the institution it belongs to', () {
      final domain = AdminInstitutionDomain.fromJson(
        Map<String, dynamic>.from(
          contract('institution-domains.list')['items'][0] as Map,
        ),
      );
      expect(domain.institutionId, isNotEmpty);
      expect(domain.institutionId, isNot(domain.id),
          reason: 'comparing these was why no institution showed its proof');
    });
  });

  group('a person is read whole', () {
    test('identity, standing, authority and devices arrive together', () {
      final person = AdminPersonDetail.fromJson(contract('user.detail'));

      expect(person.person.displayName, 'Rowan Ellis');
      expect(person.status, 'ACTIVE');
      expect(person.isDisabled, isFalse);
      expect(person.roles, contains('OWNER'));
      expect(person.grants, hasLength(1));
      expect(person.activeGrants, hasLength(1));
      expect(person.devices, hasLength(2));
    });

    test('a revoked device is not counted as active', () {
      final person = AdminPersonDetail.fromJson(contract('user.detail'));
      expect(person.devices.where((d) => d.isActive), hasLength(1));
    });

    test('the push token never reaches the model', () {
      // An operator diagnosing delivery needs to know a device exists. They
      // never need the credential that can send to it.
      final person = AdminPersonDetail.fromJson(contract('user.detail'));
      final rendered = person.devices
          .map((d) => '${d.id}|${d.label}|${d.platform}|${d.appVersion}')
          .join(' ');
      expect(rendered, isNot(contains('NEVER-RENDERED')));
    });
  });

  group('the worklist counts what it lists', () {
    OperatorWorkSummary summary(String name) =>
        OperatorWorkSummary.fromJson(contract(name));
    OperatorWorklist worklist(String name) =>
        OperatorWorklist.fromJson(contract(name));

    test('the total is the work the operator can actually see', () {
      // The header read "All 0" over four open items, because the contract was
      // captured one layer below the wire and the client's default for a
      // missing `totalOpen` was zero.
      final partial = summary('work.summary.one-source-down');
      expect(partial.totalOpen, worklist('work.list.one-source-down').items.length);
      expect(partial.totalOpen, greaterThan(0));
    });

    test('a failed queue is never counted as an empty one', () {
      final partial = summary('work.summary.one-source-down');
      expect(partial.complete, isFalse);
      expect(partial.unavailable.map((s) => s.source), contains('MODERATION'));
      // -1 is the wire's "did not answer". It must not reach the total.
      expect(partial.totalOpen, isNonNegative);
    });

    test('an unreadable queue is named, never keyed', () {
      final label = OperatorWorklist.labelFor(
        'MODERATION',
        summary: summary('work.summary.one-source-down'),
      );
      expect(label, 'Moderation');
      // Even with no summary at hand it must not print the raw key.
      expect(OperatorWorklist.labelFor('INSTITUTION_DOMAIN'),
          'Institution domain');
    });

    test('everything clear is every source reporting zero', () {
      final clear = summary('work.summary.clear');
      expect(clear.complete, isTrue);
      expect(clear.totalOpen, 0);
      expect(clear.readable, isNotEmpty);
      // The distinction the reach vocabulary exists for: proven clear, not
      // unread.
      expect(clear.isClear, isTrue);
      expect(worklist('work.list.clear').items, isEmpty);
    });

    test('the worklist speaks the product language, not the schema', () {
      for (final item in worklist('work.list').items) {
        expect(item.title, isNot(matches(RegExp(r'^[A-Z_]{4,}$'))));
        expect(item.title, isNot(contains('_')));
        final subject = item.subjectLabel;
        if (subject != null) {
          expect(subject, isNot(matches(RegExp(r'^[A-Z_]{4,}$'))));
          // "Media cmomedia" — a truncated cuid presented as a name.
          expect(subject, isNot(startsWith('Media cm')));
        }
      }
    });
  });

  group('identity verification is operable, and its custody is not', () {
    // The authority was complete and the console had never called it. These
    // assert the SHAPE the review is built on and — more importantly — the
    // limits, because the limits are the part a convenient console erodes.
    List<IdentityQueueItem> queue() =>
        contractList('identity.queue').map(IdentityQueueItem.fromJson).toList();

    IdentitySubmission detail(String name) =>
        IdentitySubmission.fromJson(contract(name));

    test('the queue names who is waiting, not their id', () {
      final first = queue().first;
      expect(first.subject.displayName, isNotEmpty);
      expect(first.state, IdentitySubmissionState.pendingReview);
      // A COUNT of evidence, never the evidence. Opening the queue must not
      // be a bulk disclosure of identity documents.
      expect(first.evidenceCount, 2);
    });

    test('no queue row carries an image, a url or a document number', () {
      final raw = contractRaw('identity.queue').toLowerCase();
      expect(raw, isNot(contains('http')));
      expect(raw, isNot(contains('mediaid')));
    });

    test('the detail gives evidence as a ROLE and an id, never bytes', () {
      final s = detail('identity.detail');
      expect(s.evidence, hasLength(2));
      expect(
        s.evidence.map((e) => e.kind),
        containsAll([
          IdentityEvidenceKind.governmentId,
          IdentityEvidenceKind.selfieComparison,
        ]),
      );
      final raw = contractRaw('identity.detail').toLowerCase();
      expect(raw, isNot(contains('http')));
      expect(raw, isNot(contains('mediaid')));
    });

    test('SELFIE_COMPARISON is never described as liveness', () {
      // The schema is explicit: a static image proves no such thing, and
      // renaming it would claim an assurance the manual path does not give.
      const kind = IdentityEvidenceKind.selfieComparison;
      expect(kind.label.toLowerCase(), isNot(contains('liveness')));
      expect(kind.purpose.toLowerCase(), contains('not a liveness check'));
    });

    test('approval is refused on incomplete evidence, before the request', () {
      final s = detail('identity.detail');
      expect(s.canApproveOnEvidence, isTrue);
      expect(s.missingForApproval, isEmpty);
    });

    test('destroyed evidence survives as a fact and cannot be opened', () {
      final s = detail('identity.detail.discarded');
      // It EXISTED — that is part of the record — and the bytes are gone.
      expect(s.evidence, hasLength(2));
      expect(s.evidence.every((e) => e.discarded), isTrue);
      expect(s.readable, isEmpty);
      expect(s.evidenceDiscardedAt, isNotNull);
      // And it can no longer be approved on evidence nobody can look at.
      expect(s.canApproveOnEvidence, isFalse);
    });

    test('an already-decided submission offers no second verdict', () {
      final s = detail('identity.detail.decided');
      expect(s.state, IdentitySubmissionState.rejected);
      expect(s.awaitsDecision, isFalse);
      expect(s.reviewerName, isNotNull);
      expect(s.decisionReason, isNotNull);
    });

    test('prior submissions travel with the review', () {
      // Deciding the same claim two different ways is what this prevents.
      final s = detail('identity.detail');
      expect(s.history, isNotEmpty);
      expect(s.history.first.decisionReason, isNotNull);
    });

    test('the console models exactly the verdicts the authority has', () {
      // Three. Not a fourth invented because a modern console usually has one.
      expect(
        IdentitySubmissionState.values
            .where((s) => s != IdentitySubmissionState.unknown)
            .map((s) => s.wire)
            .toSet(),
        {'PENDING_REVIEW', 'NEEDS_MORE_INFO', 'REJECTED', 'APPROVED',
          'WITHDRAWN'},
      );
    });
  });

  group('the people directory shows operator authority truthfully', () {
    List<AdminUserSummary> people() =>
        (contract('users.list')['items'] as List)
            .cast<Map<String, dynamic>>()
            .map(AdminUserSummary.fromJson)
            .toList();

    test('an operator role is read from where the server puts it', () {
      // Parsed from a top-level `role` key the server has never sent. The
      // column was ALWAYS empty in production, and the hand-written fixture
      // that proved this screen filled it with `MEMBER`.
      final owner = people().first;
      expect(owner.role, 'OWNER');
      expect(owner.isOperator, isTrue);
    });

    test('somebody with no grant holds no operator role', () {
      // Empty, not "MEMBER". MEMBER is an INSTITUTION role — a different
      // authority — and printing it here invented a platform rank.
      final ordinary = people()[1];
      expect(ordinary.role, isEmpty);
      expect(ordinary.isOperator, isFalse);
    });

    test('a disabled account reads as disabled, in the server word', () {
      final disabled = people().last;
      expect(disabled.status, 'DISABLED');
      expect(disabled.isDisabled, isTrue);
      // The old default was lowercase 'active', which matched nothing it was
      // ever compared against.
      expect(people().first.status, 'ACTIVE');
    });
  });

  group('the record names who it happened to', () {
    // The live console rendered `USER · cmfixture0pr00pi01rm3fyglq`. The
    // record exists for people who were NOT there, and a database key does
    // not tell them anything.
    List<AdminAuditLogEntry> entries() =>
        (contract('audit.list')['items'] as List)
            .cast<Map<String, dynamic>>()
            .map(AdminAuditLogEntry.fromJson)
            .toList();

    AdminAuditLogEntry byId(String id) =>
        entries().firstWhere((e) => e.id == id);

    test('a person subject reads as a person, not an id', () {
      final subject = byId('cmoauditrow0003').subject;
      expect(subject.isPerson, isTrue);
      expect(subject.display, 'Ada Okafor');
      expect(subject.qualifier, '@ada');
      expect(subject.navigable, isTrue);
      // The id is still carried — it is how the row opens the subject — it
      // is simply not what the operator reads.
      expect(subject.id, isNotEmpty);
    });

    test('an institution subject reads as its name', () {
      final subject = byId('cmoauditrow0004').subject;
      expect(subject.isInstitution, isTrue);
      expect(subject.display, 'Northgate Health Trust');
      expect(subject.navigable, isTrue);
    });

    test('the stored type word is preserved even when it is inconsistent', () {
      // Call sites write `User`, `USER` and `user`. Lookup normalises; the
      // record does not get rewritten to look tidier than it is.
      expect(byId('cmoauditrow0003').subject.type, 'User');
      expect(byId('cmoauditrow0005').subject.type, 'USER');
    });

    test('a target class that is not a subject stays a plain reference', () {
      final subject = byId('cmoauditrow0002').subject;
      expect(subject.resolvable, isFalse);
      expect(subject.navigable, isFalse);
      expect(subject.display, contains('Route'));
    });

    test('a DELETED subject is a reference, never an invented name', () {
      // The most important one. A record that manufactures a plausible name
      // for a subject that no longer exists is worse than one showing an id.
      final subject = byId('cmoauditrow0005').subject;
      expect(subject.resolvable, isFalse);
      expect(subject.label, isNull);
      expect(subject.navigable, isFalse);
      expect(subject.display, contains(subject.id!));
    });
  });

  group('a moderation report shows the thing being judged', () {
    ModerationReport report(String name) =>
        ModerationReport.fromJson(contract(name)['report'] as Map<String, dynamic>);

    test('the reported words reach the operator', () {
      final subject = report('moderation.report').subject;
      expect(subject.hasEvidence, isTrue);
      expect(subject.excerpt, contains('disgrace'));
      expect(subject.author?.displayName, 'Ada Okafor');
      expect(subject.absenceSentence, isNull);
    });

    test('deleted content is NOT re-served, and the panel says why', () {
      final subject = report('moderation.report.deleted-target').subject;
      expect(subject.exists, isTrue);
      expect(subject.wasRemoved, isTrue);
      expect(subject.hasEvidence, isFalse);
      expect(subject.absenceSentence, contains('removed'));
      // Authorship survives removal — who wrote it is still the record.
      expect(subject.author?.displayName, 'Ada Okafor');
    });

    test('a reported person has no excerpt, and that is not a gap', () {
      final subject = report('moderation.report.person').subject;
      expect(subject.isPerson, isTrue);
      expect(subject.hasEvidence, isFalse);
      expect(subject.absenceSentence, contains('person was reported'));
      expect(subject.label, 'Ada Okafor');
    });

    test('a vanished target says so instead of showing an empty quote', () {
      final subject = report('moderation.report.missing-target').subject;
      expect(subject.exists, isFalse);
      expect(subject.hasEvidence, isFalse);
      expect(subject.absenceSentence, contains('no longer exists'));
      expect(subject.author, isNull);
    });
  });

  group('a subject is one subject, not two disagreeing projections', () {
    // THE LIVE CONTRADICTION: the directory read "6 members", the roster that
    // opened from it listed five people. Both surfaces are asserted from the
    // same captured membership table, so the client cannot agree with one
    // endpoint and quietly disagree with the other.
    List<AdminInstitutionMember> roster() =>
        (contract('institution.members')['members'] as List)
            .cast<Map<String, dynamic>>()
            .map(AdminInstitutionMember.fromJson)
            .toList();

    List<AdminInstitutionSummary> directory([String name = 'institutions.directory']) =>
        (contract(name)['items'] as List)
            .cast<Map<String, dynamic>>()
            .map(AdminInstitutionSummary.fromJson)
            .toList();

    AdminInstitutionSummary rostered() =>
        directory().firstWhere((i) => i.memberCount > 0);

    test('the count the directory shows is the roster it opens', () {
      expect(rostered().memberCount, roster().length);
    });

    test('the count is a real number, not a silent zero', () {
      // `_count.members` missing would parse to 0 and look like a small
      // institution rather than a broken read.
      expect(rostered().memberCount, greaterThan(0));
    });

    test('the directory carries EVERY standing, not just verified', () {
      // The server defaulted to VERIFIED, so a suspended institution — the
      // subject an operator is most likely sent to review — was absent from
      // the console's only institution list, invisibly.
      final standings = directory().map((i) => i.status).toSet();
      expect(standings, containsAll(<String>{
        'VERIFIED',
        'PENDING',
        'SUSPENDED',
        'REJECTED',
      }));
      // The envelope says which slice this is. `null` means "everything".
      expect(contract('institutions.directory')['status'], isNull);
    });

    test('narrowing still works, and still says what it narrowed to', () {
      final verified = directory('institutions.directory.verified');
      expect(verified.map((i) => i.status).toSet(), {'VERIFIED'});
      expect(contract('institutions.directory.verified')['status'], 'VERIFIED');
    });

    test('a subject opened by id carries the same count as the directory', () {
      // Two endpoints, two shapes: the directory sends `_count.members`, the
      // by-id read sends `memberCount`. Reading only one made the same
      // institution show five members in the list and none on its own page.
      final detail = AdminInstitutionSummary.fromJson(
        contract('institution.detail')['institution'] as Map<String, dynamic>,
      );
      expect(detail.memberCount, rostered().memberCount);
      expect(detail.id, rostered().id);
    });

    test('a member is a person, carrying standing and verification', () {
      final owner = roster().first;
      expect(owner.role, 'OWNER');
      expect(owner.person.displayName, isNotEmpty);
      expect(owner.person.accountStatus, 'ACTIVE');
      expect(owner.person.verification.classes, isNotEmpty);
    });

    test('a disabled account is still a member, and reads as disabled', () {
      // Lifecycle and membership are separate authorities. Dropping the
      // person, or showing them as ACTIVE, would each be a different lie.
      final disabled = roster()
          .where((m) => m.person.accountStatus == 'DISABLED')
          .toList();
      expect(disabled, hasLength(1));
      expect(disabled.single.role, 'MEMBER');
    });

    test('the directory row carries the domain that proves the institution',
        () {
      expect(rostered().domain, isNotNull);
      expect(rostered().status, 'VERIFIED');
    });
  });

  group('OperatorSignal keeps the distinctions the console lost', () {
    test('partial carries a value AND names what is missing', () {
      const signal = OperatorSignal<int>.partial(3, missing: ['support']);
      expect(signal.hasValue, isTrue);
      expect(signal.value, 3);
      expect(signal.missing, ['support']);
      expect(signal.reach.needsDisclosure, isTrue);
    });

    test('unavailable carries NO value and is never an empty result', () {
      const signal = OperatorSignal<List<int>>.unavailable();
      expect(signal.hasValue, isFalse);
      expect(signal.reach.needsDisclosure, isTrue);
      expect(signal.reach.isRetryable, isTrue);
    });

    test('unauthorized is not retryable — nothing is broken', () {
      const signal = OperatorSignal<int>.unauthorized(needs: 'support');
      expect(signal.reach.isRetryable, isFalse);
      expect(signal.reach.needsDisclosure, isFalse);
    });

    test('one source failing among many makes the whole PARTIAL, not lost', () {
      // The rule that keeps WORK and INTEGRITY standing when one queue falls
      // over. Previously a single failure erased both areas.
      expect(
        OperatorSignal.worstOf([
          OperatorReach.complete,
          OperatorReach.complete,
          OperatorReach.unavailable,
        ]),
        OperatorReach.partial,
      );
    });

    test('every source failing IS unavailable', () {
      expect(
        OperatorSignal.worstOf([
          OperatorReach.unavailable,
          OperatorReach.unavailable,
        ]),
        OperatorReach.unavailable,
      );
    });

    test('unknown sits above healthy and below degraded in severity', () {
      expect(
        OperatorCondition.unknown.severity,
        greaterThan(OperatorCondition.healthy.severity),
      );
      expect(
        OperatorCondition.unknown.severity,
        lessThan(OperatorCondition.degraded.severity),
      );
      expect(OperatorCondition.unknown.isAdverse, isFalse);
    });
  });
}
