/// A PERSON, AS AN OPERATOR SUBJECT.
///
/// One place to see who someone is, what standing they hold, what has been
/// decided about them, and what may be done next — without pretending those
/// are one authority. Identity verification, account standing and admin
/// capability are three different decisions made by three different
/// authorities, and this shows them side by side without merging them.
///
/// Audit lives HERE, on the subject, not only in a global log. An operator
/// investigating a person should not have to go and search a chronological
/// list of the whole estate to find out what happened to them.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ui/operator_states.dart';
import 'package:go_router/go_router.dart';

import '../../../core/trust/verification.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../data/admin_providers.dart';
import '../data/operator_work.dart';
import '../domain/operator_authority_provider.dart';
import '../domain/operator_capability.dart';
import '../ui/operator_action.dart';
import '../ui/operator_kit.dart';
import 'record_area.dart' show readableReason;

final personVerificationProvider = FutureProvider.autoDispose
    .family<AdminPersonVerification, String>((ref, userId) async {
  return ref.watch(adminRepositoryProvider).fetchPersonVerification(userId);
});

/// The whole person in one request. Deliberately NOT routed through the
/// providers that swallow 401/403 into an empty list: an operator who is
/// refused must be told so, not shown a person with nothing about them.
final personDetailProvider = FutureProvider.autoDispose
    .family<AdminPersonDetail, String>((ref, userId) async {
  return ref.watch(adminRepositoryProvider).fetchUser(userId);
});

class SubjectPersonArea extends ConsumerWidget {
  const SubjectPersonArea({super.key, required this.userId, this.focus});

  final String userId;

  /// Which part of the subject the operator was sent here for.
  ///
  /// The worklist's identity rows address `/admin/subjects/person/:id/identity`
  /// because an identity decision belongs ON the person, not on a queue page
  /// showing a decision with no subject around it. The focus does not hide
  /// anything — every section stays present and in the same order; it only
  /// decides what leads.
  final String? focus;

  bool get _identityFirst => (focus ?? '').toLowerCase() == 'identity';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authority = ref.watch(operatorAuthorityProvider).valueOrNull ??
        const OperatorAuthority.none();

    if (!authority.can(OperatorCapability.usersRead)) {
      return const Padding(
        padding: EdgeInsets.all(AuraSpace.s20),
        child: OperatorInsufficientCapability(needs: 'people'),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;

        // THE THREE DECISIONS, HELD APART. Identity (who they are), standing
        // (whether the account may be used) and operator authority (what they
        // may do to Aura) are three authorities. They are shown together and
        // never merged into one "status", which is the collapse the old
        // console's single `status` column invited.
        final identity = _IdentityBlock(userId: userId, authority: authority);
        final standing = _StandingBlock(userId: userId, authority: authority);
        final grants =
            _OperatorAuthorityBlock(userId: userId, authority: authority);
        final work = _RelatedWork(userId: userId);
        final history = _PersonHistory(userId: userId, authority: authority);
        final devices = _PersonDevices(userId: userId);

        return ListView(
          padding: EdgeInsets.all(wide ? AuraSpace.s20 : AuraSpace.s12),
          children: [
            _SubjectHeader(userId: userId),
            const SizedBox(height: AuraSpace.s20),
            if (_identityFirst) ...[
              const OperatorPanel(
                child: Row(
                  children: [
                    Icon(Icons.badge_outlined,
                        size: 16, color: AuraSurface.accent),
                    SizedBox(width: AuraSpace.s10),
                    Expanded(
                      child: Text(
                        'You were sent here by an identity decision waiting on '
                        'this person.',
                        style: TextStyle(
                          color: AuraSurface.ink,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AuraSpace.s20),
            ],
            if (wide)
              // Desktop investigates with evidence and history side by side.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        identity,
                        const SizedBox(height: AuraSpace.s20),
                        standing,
                        const SizedBox(height: AuraSpace.s20),
                        grants,
                      ],
                    ),
                  ),
                  const SizedBox(width: AuraSpace.s20),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        work,
                        const SizedBox(height: AuraSpace.s20),
                        history,
                        const SizedBox(height: AuraSpace.s20),
                        devices,
                      ],
                    ),
                  ),
                ],
              )
            else ...[
              // Mobile drills in: the subject first, then what is waiting on
              // it, then what has happened. Same capability, staged — never a
              // reduced set of decisions.
              identity,
              const SizedBox(height: AuraSpace.s20),
              standing,
              const SizedBox(height: AuraSpace.s20),
              grants,
              const SizedBox(height: AuraSpace.s20),
              work,
              const SizedBox(height: AuraSpace.s20),
              history,
              const SizedBox(height: AuraSpace.s20),
              devices,
            ],
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _IdentityBlock extends ConsumerWidget {
  const _IdentityBlock({required this.userId, required this.authority});

  final String userId;
  final OperatorAuthority authority;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canReadIdentity =
        authority.can(OperatorCapability.identityVerificationRead);

    if (!canReadIdentity) {
      // Deliberate: holding USERS_READ does not admit anyone to identity
      // evidence. The separation is a governance decision, not a UI detail.
      return const OperatorSection(
        title: 'Identity',
        child: OperatorInsufficientCapability(needs: 'identity verification'),
      );
    }

    final verification = ref.watch(personVerificationProvider(userId));

    return verification.when(
      loading: () => const OperatorSection(
        title: 'Identity',
        child: OperatorLoading(lines: 2),
      ),
      error: (e, _) => OperatorSection(
        title: 'Identity',
        child: OperatorFailure(
          title: 'Verification state could not be read',
          onRetry: () => ref.invalidate(personVerificationProvider(userId)),
        ),
      ),
      data: (v) {
        final canWrite =
            authority.can(OperatorCapability.identityVerificationWrite);
        return OperatorSection(
          title: 'Identity',
          subtitle: v.activeClasses.isEmpty
              ? 'No active verification'
              : '${v.activeClasses.length} active '
                  'class${v.activeClasses.length == 1 ? '' : 'es'}',
          child: OperatorPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (v.activeClasses.isEmpty)
                  const Text(
                    'This person holds no verified identity class.',
                    style:
                        TextStyle(color: AuraSurface.muted, fontSize: 13),
                  )
                else
                  Wrap(
                    spacing: AuraSpace.s8,
                    runSpacing: AuraSpace.s8,
                    children: [
                      for (final c in v.activeClasses)
                        OperatorStatePill(
                          state: c,
                          tone: OperatorTone.good,
                        ),
                    ],
                  ),
                if (canWrite) ...[
                  const SizedBox(height: AuraSpace.s16),
                  // BOTH halves of the decision. The console could only ever
                  // revoke: the grant endpoint existed, the authority enforced
                  // every rule behind it, and no surface could reach it — so a
                  // verified class could be taken away in Aura and only ever
                  // given somewhere else.
                  Wrap(
                    spacing: AuraSpace.s8,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.verified_rounded, size: 16),
                        label: const Text('Grant a class'),
                        onPressed: () => _grant(context, ref, v),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.gpp_bad_rounded, size: 16),
                        label: const Text('Revoke verification'),
                        style: TextButton.styleFrom(
                          foregroundColor: AuraSurface.dangerInk,
                        ),
                        onPressed: v.activeClasses.isEmpty
                            ? null
                            : () =>
                                _revoke(context, ref, v.activeClasses.first),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: AuraSpace.s12),
                  const Text(
                    'You may read this, but not decide it.',
                    style:
                        TextStyle(color: AuraSurface.faint, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// The three classes `PersonVerificationClass` defines, and no others.
  ///
  /// Held here rather than typed by an operator: a class the enum does not
  /// carry is a class the authority refuses, and finding that out at the API
  /// is finding it out after the operator has already written their reasoning.
  static const _grantableClasses = <String, String>{
    'IDENTITY': 'Identity — this is really them',
    'INSTITUTION_AFFILIATION':
        'Institution affiliation — a verified relationship with an institution',
    'ROLE_OR_CREDENTIAL':
        'Role or credential — a substantiated office, standing or qualification',
  };

  Future<void> _grant(
    BuildContext context,
    WidgetRef ref,
    AdminPersonVerification current,
  ) async {
    final held = current.activeClasses.map((c) => c.toUpperCase()).toSet();
    final available = _grantableClasses.entries
        .where((e) => !held.contains(e.key))
        .toList(growable: false);

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This person already holds every class.'),
        ),
      );
      return;
    }

    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AuraSurface.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AuraRadius.xl)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AuraSpace.s20,
                AuraSpace.s20,
                AuraSpace.s20,
                AuraSpace.s8,
              ),
              child: Text(
                'Which class',
                style: TextStyle(
                  color: AuraSurface.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (final entry in available)
              ListTile(
                title: Text(
                  entry.value,
                  style: const TextStyle(
                    color: AuraSurface.ink,
                    fontSize: 13.5,
                  ),
                ),
                onTap: () => Navigator.of(sheetContext).pop(entry.key),
              ),
            const SizedBox(height: AuraSpace.s12),
          ],
        ),
      ),
    );

    if (chosen == null || !context.mounted) return;

    // An affiliation ASSERTS a relationship with an institution, so naming it
    // is part of the claim. The authority refuses the grant without one —
    // offering the class with no way to answer that would be offering an act
    // that always fails.
    String? institutionId;
    if (chosen == 'INSTITUTION_AFFILIATION') {
      institutionId = await _pickInstitution(context, ref);
      if (institutionId == null || !context.mounted) return;
    }

    final done = await runOperatorAction(
      context,
      OperatorAction(
        title: 'Grant verification',
        subject: _verificationSubject(ref, chosen),
        detail: 'The identity authority records this and applies it. It '
            'refuses a second active record for a class, and it requires the '
            'reason you give here.',
        confirmLabel: 'Grant',
        requiresReason: true,
        reasonLabel: 'The evidence this rests on',
        consequences: [
          OperatorConsequence.becomesPublic('This verified class'),
          OperatorConsequence.notifies('The person'),
          OperatorConsequence.recorded('This decision and your reason'),
        ],
        perform: (reason) async {
          await ref.read(adminRepositoryProvider).grantPersonVerificationClass(
                userId,
                verificationClass: chosen,
                reason: reason ?? '',
                issuingInstitutionId: institutionId,
              );
          return 'Verified. The class is now public and the decision is '
              'recorded.';
        },
      ),
    );
    if (done) {
      ref.invalidate(personVerificationProvider(userId));
      ref.invalidate(personDetailProvider(userId));
    }
  }

  /// How the confirmation names what is about to change.
  ///
  /// The taxonomy's word for the class, and the PERSON'S OWN NAME — never
  /// `ROLE_OR_CREDENTIAL · person cmfixture0pr00pi01rm3fyglq`. The id is the
  /// fallback only when the person could not be resolved, in which case it is
  /// the honest answer rather than a decorated one.
  String _verificationSubject(WidgetRef ref, String verificationClass) {
    final className =
        PersonVerificationClass.tryParse(verificationClass)?.label ??
            verificationClass;

    final person = ref.read(personDetailProvider(userId)).valueOrNull?.person;
    final name = person?.displayName.trim() ?? '';
    if (name.isNotEmpty) return '$className · $name';
    final handle = person?.handle.trim() ?? '';
    if (handle.isNotEmpty) return '$className · @$handle';
    return '$className · $userId';
  }

  /// Which institution the affiliation is WITH.
  ///
  /// Reads the institution directory rather than asking for an id: an operator
  /// knows the institution by its name, and an id typed from memory is an id
  /// typed wrong.
  Future<String?> _pickInstitution(BuildContext context, WidgetRef ref) async {
    final institutions = await ref
        .read(adminRepositoryProvider)
        .fetchInstitutions()
        .catchError((_) => <AdminInstitutionSummary>[]);

    if (!context.mounted) return null;
    if (institutions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No institution could be read, so an affiliation cannot be named.',
          ),
        ),
      );
      return null;
    }

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AuraSurface.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AuraRadius.xl)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AuraSpace.s20,
                AuraSpace.s20,
                AuraSpace.s20,
                AuraSpace.s8,
              ),
              child: Text(
                'Affiliated with',
                style: TextStyle(
                  color: AuraSurface.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: institutions.length,
                itemBuilder: (_, i) {
                  final institution = institutions[i];
                  return ListTile(
                    dense: true,
                    title: Text(
                      institution.name,
                      style: const TextStyle(
                        color: AuraSurface.ink,
                        fontSize: 13.5,
                      ),
                    ),
                    subtitle: Text(
                      institution.status,
                      style: const TextStyle(
                        color: AuraSurface.muted,
                        fontSize: 11.5,
                      ),
                    ),
                    onTap: () =>
                        Navigator.of(sheetContext).pop(institution.id),
                  );
                },
              ),
            ),
            const SizedBox(height: AuraSpace.s12),
          ],
        ),
      ),
    );
  }

  Future<void> _revoke(
    BuildContext context,
    WidgetRef ref,
    String verificationClass,
  ) async {
    final done = await runOperatorAction(
      context,
      OperatorAction(
        title: 'Revoke verification',
        subject: _verificationSubject(ref, verificationClass),
        detail: 'The identity authority records this decision and applies it. '
            'Aura Admin invokes that authority; it does not decide here.',
        confirmLabel: 'Revoke',
        destructive: true,
        requiresReason: true,
        reasonLabel: 'Why this is being revoked',
        consequences: [
          const OperatorConsequence(
            text: 'The person loses this verified class immediately.',
            tone: OperatorTone.danger,
            icon: Icons.remove_moderator_rounded,
          ),
          OperatorConsequence.notifies('The person'),
          OperatorConsequence.recorded('This decision and your reason'),
        ],
        perform: (reason) async {
          await ref.read(adminRepositoryProvider).revokePersonVerification(
                userId,
                verificationClass: verificationClass,
                reason: reason ?? '',
              );
          return 'Verification revoked. The person has been notified and the '
              'decision recorded.';
        },
      ),
    );
    if (done) ref.invalidate(personVerificationProvider(userId));
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _RelatedWork extends ConsumerWidget {
  const _RelatedWork({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final work = ref.watch(operatorWorkListProvider);

    // NEVER `SizedBox.shrink()` ON FAILURE. This section disappeared from a
    // live subject page when the worklist could not be read, so an operator
    // saw a subject with apparently nothing waiting on them — the most
    // dangerous possible reading of a failed dependency.
    return OperatorSection(
      title: 'Waiting on this subject',
      child: work.when(
        loading: () => const OperatorLoading(lines: 1),
        error: (_, __) => OperatorFailure(
          title: 'Open work could not be read',
          detail: 'This is a read failure. It does not mean nothing is '
              'waiting on this person.',
          onRetry: () => ref.invalidate(operatorWorkListProvider),
        ),
        data: (signal) => OperatorSignalView<OperatorWorklist>(
          signal: signal,
          subject: 'open work',
          // A CLAUSE CANNOT FILL A NOUN SLOT. This produced, live:
          // "You do not hold a queue you can work authority."
          unauthorizedSentence: 'You do not hold any queue you can work. '
              'An operator who does can act on this.',
          onRetry: () => ref.invalidate(operatorWorkListProvider),
          loading: const OperatorLoading(lines: 1),
          builder: (context, worklist) {
            final mine = worklist.items
                .where((i) => i.subjectId == userId)
                .toList(growable: false);

            if (mine.isEmpty) {
              return OperatorPanel(
                child: OperatorClear(
                  title: worklist.complete
                      ? 'Nothing open'
                      : 'Nothing open in the queues that answered',
                  icon: Icons.check_circle_outline_rounded,
                ),
              );
            }

            return OperatorPanel(
              padding: const EdgeInsets.symmetric(vertical: AuraSpace.s4),
              child: Column(
                children: [
                  for (final item in mine)
                    ListTile(
                      dense: true,
                      onTap: () => context.go(item.destination),
                      title: Text(
                        item.title,
                        style: const TextStyle(
                          color: AuraSurface.ink,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        item.sourceLabel,
                        style: const TextStyle(
                          color: AuraSurface.muted,
                          fontSize: 11.5,
                        ),
                      ),
                      trailing: OperatorAge(days: item.ageDays, dense: true),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PersonHistory extends ConsumerWidget {
  const _PersonHistory({required this.userId, required this.authority});

  final String userId;
  final OperatorAuthority authority;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!authority.can(OperatorCapability.auditRead)) {
      return const OperatorSection(
        title: 'History',
        child: OperatorInsufficientCapability(needs: 'audit'),
      );
    }

    final verification = ref.watch(personVerificationProvider(userId));

    return verification.when(
      loading: () => const OperatorSection(
        title: 'History',
        child: OperatorLoading(lines: 2),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (v) {
        if (v.history.isEmpty) {
          return const OperatorSection(
            title: 'History',
            child: OperatorPanel(
              child: OperatorClear(
                title: 'No decisions recorded',
                icon: Icons.history_rounded,
              ),
            ),
          );
        }
        return OperatorSection(
          title: 'History',
          subtitle: 'Decisions recorded against this person',
          child: OperatorPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final record in v.history)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AuraSpace.s12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // A timeline reads as a sequence, which is what
                        // history is. A table of rows does not.
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(top: 6),
                          decoration: const BoxDecoration(
                            color: AuraSurface.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AuraSpace.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  OperatorStatePill(
                                    state: record.state,
                                    dense: true,
                                  ),
                                  const SizedBox(width: AuraSpace.s8),
                                  Text(
                                    // THE TAXONOMY'S OWN WORDS, not its
                                    // column value. An unrecognised class
                                    // keeps its stored name rather than being
                                    // renamed into something this build
                                    // invented.
                                    PersonVerificationClass.tryParse(
                                          record.verificationClass,
                                        )?.label ??
                                        record.verificationClass,
                                    style: const TextStyle(
                                      color: AuraSurface.ink,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              if (record.reason.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  readableReason(record.reason),
                                  style: const TextStyle(
                                    color: AuraSurface.muted,
                                    fontSize: 12,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// WHO THIS IS — the header the old console never had.
///
/// `/admin/users` showed a row; opening a person showed the row again. Nothing
/// named them, so an operator revoking authority read an id and hoped.
class _SubjectHeader extends ConsumerWidget {
  const _SubjectHeader({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(personDetailProvider(userId));

    return detail.when(
      loading: () => const OperatorPanel(child: OperatorLoading(lines: 1)),
      // Deliberately quiet: the sections below each report their own failure,
      // and three copies of the same message is not three pieces of news.
      error: (_, __) => const SizedBox.shrink(),
      data: (p) => OperatorPanel(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.person.displayName.isEmpty
                        ? '@${p.person.handle}'
                        : p.person.displayName,
                    style: const TextStyle(
                      color: AuraSurface.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    p.person.handle.isEmpty
                        ? p.email
                        : '@${p.person.handle} · ${p.email}',
                    style: const TextStyle(
                      color: AuraSurface.muted,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AuraSpace.s12),
            OperatorStatePill(
              state: p.status,
              tone: p.isDisabled ? OperatorTone.danger : OperatorTone.good,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// ACCOUNT STANDING — a different decision from identity, kept apart from it.
///
/// Whether an account may be used is not whether a person is who they say they
/// are. Aura holds these as two authorities and the console shows them as two
/// sections, side by side, never merged into one "status".
class _StandingBlock extends ConsumerWidget {
  const _StandingBlock({required this.userId, required this.authority});

  final String userId;
  final OperatorAuthority authority;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(personDetailProvider(userId));

    return detail.when(
      loading: () => const OperatorSection(
        title: 'Standing',
        child: OperatorLoading(lines: 2),
      ),
      error: (e, _) => OperatorSection(
        title: 'Standing',
        child: OperatorFailure(
          title: 'This person could not be read',
          detail: '$e',
          onRetry: () => ref.invalidate(personDetailProvider(userId)),
        ),
      ),
      data: (p) {
        final canWrite = authority.can(OperatorCapability.usersWrite);
        return OperatorSection(
          title: 'Standing',
          subtitle: p.isDisabled
              ? 'This account cannot be used'
              : 'This account is in good standing',
          child: OperatorPanel(
            tone: p.isDisabled ? OperatorTone.danger : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Fact(
                  label: 'Email',
                  value: p.emailVerifiedAt == null
                      ? 'Not verified'
                      : 'Verified',
                  tone: p.emailVerifiedAt == null
                      ? OperatorTone.warn
                      : OperatorTone.good,
                ),
                _Fact(label: 'Account type', value: p.accountType),
                if (p.city != null || p.country != null)
                  _Fact(
                    label: 'Location',
                    value: [p.city, p.country]
                        .whereType<String>()
                        .join(', '),
                  ),
                _Fact(
                  label: 'Devices',
                  value: '${p.devices.where((d) => d.isActive).length} active '
                      'of ${p.devices.length}',
                ),
                if (canWrite) ...[
                  const SizedBox(height: AuraSpace.s16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: p.isDisabled
                        ? TextButton.icon(
                            icon: const Icon(Icons.lock_open_rounded, size: 16),
                            label: const Text('Restore this account'),
                            onPressed: () => _setStanding(context, ref, p, true),
                          )
                        : TextButton.icon(
                            icon: const Icon(Icons.block_rounded, size: 16),
                            label: const Text('Disable this account'),
                            style: TextButton.styleFrom(
                              foregroundColor: AuraSurface.dangerInk,
                            ),
                            onPressed: () =>
                                _setStanding(context, ref, p, false),
                          ),
                  ),
                ] else ...[
                  const SizedBox(height: AuraSpace.s12),
                  const Text(
                    'You may read this, but not decide it.',
                    style: TextStyle(color: AuraSurface.faint, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _setStanding(
    BuildContext context,
    WidgetRef ref,
    AdminPersonDetail person,
    bool restore,
  ) async {
    final done = await runOperatorAction(
      context,
      OperatorAction(
        title: restore ? 'Restore this account' : 'Disable this account',
        subject: person.person.displayName.isEmpty
            ? '@${person.person.handle}'
            : '${person.person.displayName} · @${person.person.handle}',
        detail: restore
            ? 'The person can sign in again and their content becomes '
                'reachable on the terms it was already published under.'
            : 'The person cannot sign in. This does not delete anything and '
                'does not decide anything about their identity.',
        confirmLabel: restore ? 'Restore' : 'Disable',
        destructive: !restore,
        requiresReason: true,
        reasonLabel: restore ? 'Why this is being restored' : 'Why',
        consequences: [
          if (restore)
            const OperatorConsequence(
              text: 'The person can sign in again.',
              tone: OperatorTone.good,
              icon: Icons.lock_open_rounded,
            )
          else ...[
            const OperatorConsequence(
              text: 'The person can no longer sign in.',
              tone: OperatorTone.danger,
              icon: Icons.block_rounded,
            ),
            const OperatorConsequence(
              text: 'Their sessions on every device stop working.',
              tone: OperatorTone.warn,
              icon: Icons.devices_rounded,
            ),
          ],
          OperatorConsequence.recorded('This decision and your reason'),
        ],
        perform: (reason) async {
          await ref.read(adminRepositoryProvider).updateUserStatus(
                person.id,
                restore ? 'ACTIVE' : 'DISABLED',
                reason: reason,
              );
          return restore
              ? 'The account is active again. The decision is recorded.'
              : 'The account is disabled. The decision is recorded.';
        },
      ),
    );
    if (done) ref.invalidate(personDetailProvider(userId));
  }
}

/// One labelled fact. Deliberately not a table: a table implies the rows are
/// the same kind of thing, and these are not.
class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.tone});

  final String label;
  final String value;
  final OperatorTone? tone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: const TextStyle(color: AuraSurface.faint, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: TextStyle(
                color: tone?.ink ?? AuraSurface.ink,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// OPERATOR AUTHORITY — what this person may do to Aura.
///
/// A third decision, separate again from identity and standing. `/admin/grants`
/// listed every grant in the estate with no way to reach the person it was
/// about; this is the same authority, asked about one subject.
class _OperatorAuthorityBlock extends ConsumerWidget {
  const _OperatorAuthorityBlock({required this.userId, required this.authority});

  final String userId;
  final OperatorAuthority authority;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // AUDIT_READ is what the grants endpoint requires. Asking the same
    // question the server will ask keeps a visible section and a working
    // request from disagreeing.
    if (!authority.can(OperatorCapability.auditRead)) {
      return const OperatorSection(
        title: 'Operator authority',
        child: OperatorInsufficientCapability(needs: 'audit'),
      );
    }

    final detail = ref.watch(personDetailProvider(userId));

    return detail.when(
      loading: () => const OperatorSection(
        title: 'Operator authority',
        child: OperatorLoading(lines: 2),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (p) {
        if (p.grants.isEmpty) {
          return const OperatorSection(
            title: 'Operator authority',
            child: OperatorPanel(
              child: OperatorClear(
                title: 'Holds no operator authority',
                icon: Icons.shield_outlined,
              ),
            ),
          );
        }

        final canWrite = authority.can(OperatorCapability.usersWrite);
        // SELF-AUTHORITY. Removing your own grant is a legitimate act — an
        // operator may stand down — but it is not the same act as removing
        // somebody else's, and the console must not present it as if it were.
        final isSelf =
            authority.userId.isNotEmpty && authority.userId == p.id;

        return OperatorSection(
          title: 'Operator authority',
          subtitle: p.roles.isEmpty
              ? 'No active role'
              : '${p.roles.join(', ')} · ${p.permissions.length} '
                  'permission${p.permissions.length == 1 ? '' : 's'}',
          child: OperatorPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isSelf) ...[
                  const _SelfAuthorityNotice(),
                  const SizedBox(height: AuraSpace.s12),
                ],
                for (final grant in p.grants) ...[
                  // THE CONTROL IS WITHHELD, NOT WIRED TO FAIL. The authority
                  // refuses to remove the last owner; offering a button that
                  // exists only to be rejected teaches an operator that the
                  // console does not know its own rules.
                  _GrantRow(
                    grant: grant,
                    canRevoke: canWrite && !_isLastOwner(p, grant),
                    withheldReason: canWrite && _isLastOwner(p, grant)
                        ? 'Nobody else can act as owner. Appoint another '
                            'owner before withdrawing this one.'
                        : null,
                    onRevoke: () =>
                        _revoke(context, ref, p, grant, isSelf: isSelf),
                  ),
                  if (grant != p.grants.last)
                    const Divider(height: AuraSpace.s20, color: AuraSurface.divider),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Would this revocation leave Aura with nobody who can act as owner?
  ///
  /// Answered from what the SERVER said (`otherOwnerHolders`), never from a
  /// client-side recount of a grants list — a second implementation of an
  /// authority rule is a second answer waiting to disagree. A null count is
  /// unknown, and unknown never withholds a legitimate control.
  static bool _isLastOwner(AdminPersonDetail person, AdminGrant grant) =>
      grant.role.toUpperCase() == 'OWNER' &&
      grant.derivedStatus == AdminGrantStatus.active &&
      person.isSoleOwnerHolder;

  Future<void> _revoke(
    BuildContext context,
    WidgetRef ref,
    AdminPersonDetail person,
    AdminGrant grant, {
    bool isSelf = false,
  }) async {
    final done = await runOperatorAction(
      context,
      OperatorAction(
        title: isSelf
            ? 'Withdraw your own operator authority'
            : 'Revoke operator authority',
        subject: '${grant.role} · ${person.person.displayName.isEmpty ? '@${person.person.handle}' : person.person.displayName}',
        detail: 'The grant is marked revoked. Aura Admin invokes the grant '
            'authority; the authority decides and records.',
        confirmLabel: isSelf ? 'Withdraw my authority' : 'Revoke',
        destructive: true,
        requiresReason: true,
        reasonLabel: 'Why this authority is being withdrawn',
        consequences: [
          // FIRST PERSON WHEN IT IS THE OPERATOR'S OWN AUTHORITY. Reading
          // "they immediately lose" about yourself is exactly how a
          // consequential act gets confirmed without being understood.
          if (isSelf)
            OperatorConsequence(
              text: 'YOU immediately lose ${grant.permissions.length} admin '
                  'permission${grant.permissions.length == 1 ? '' : 's'}, and '
                  'this console stops answering for you.',
              tone: OperatorTone.danger,
              icon: Icons.logout_rounded,
            )
          else
            OperatorConsequence(
              text: 'They immediately lose '
                  '${grant.permissions.length} admin '
                  'permission${grant.permissions.length == 1 ? '' : 's'}.',
              tone: OperatorTone.danger,
              icon: Icons.remove_moderator_rounded,
            ),
          if (isSelf)
            const OperatorConsequence(
              text: 'You cannot restore it yourself afterwards. Another '
                  'owner has to grant it back.',
              tone: OperatorTone.danger,
              icon: Icons.lock_person_rounded,
            )
          else
            const OperatorConsequence(
              text: 'Any admin surface they have open stops answering.',
              tone: OperatorTone.warn,
              icon: Icons.desktop_access_disabled_rounded,
            ),
          OperatorConsequence.recorded('This decision and your reason'),
        ],
        perform: (reason) async {
          await ref
              .read(adminRepositoryProvider)
              .revokeGrant(grant.id, reason: reason);
          return 'Authority revoked. The decision is recorded.';
        },
      ),
    );
    if (done) ref.invalidate(personDetailProvider(userId));
  }
}

/// The operator is looking at their own authority.
///
/// Stated once, at the top, rather than repeated on every row: an operator who
/// does not realise whose grants these are is the one who makes the mistake
/// this notice exists to prevent.
class _SelfAuthorityNotice extends StatelessWidget {
  const _SelfAuthorityNotice();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.person_pin_circle_rounded,
            size: 16, color: AuraSurface.accent),
        SizedBox(width: AuraSpace.s8),
        Expanded(
          child: Text(
            'This is your own authority. Anything withdrawn here is withdrawn '
            'from you, immediately.',
            style: TextStyle(
              color: AuraSurface.ink,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _GrantRow extends StatelessWidget {
  const _GrantRow({
    required this.grant,
    required this.canRevoke,
    required this.onRevoke,
    this.withheldReason,
  });

  final AdminGrant grant;
  final bool canRevoke;
  final VoidCallback onRevoke;

  /// Why the control is absent, when it is absent for a GOVERNING reason
  /// rather than for lack of capability. Absence with no explanation reads as
  /// a bug; absence with one reads as a rule.
  final String? withheldReason;

  @override
  Widget build(BuildContext context) {
    final status = grant.derivedStatus;
    final live = status == AdminGrantStatus.active ||
        status == AdminGrantStatus.bootstrap;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              grant.role,
              style: const TextStyle(
                color: AuraSurface.ink,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: AuraSpace.s8),
            OperatorStatePill(
              state: status.name,
              dense: true,
              tone: live ? OperatorTone.good : OperatorTone.neutral,
            ),
            const Spacer(),
            // Only a LIVE grant can be withdrawn. Offering to revoke one that
            // is already revoked is offering an act with no consequence.
            if (canRevoke && live)
              TextButton(
                onPressed: onRevoke,
                style: TextButton.styleFrom(
                  foregroundColor: AuraSurface.dangerInk,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Revoke'),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Granted by ${grant.grantedBy.isEmpty ? 'the system' : grant.grantedBy}',
          style: const TextStyle(color: AuraSurface.muted, fontSize: 12),
        ),
        if (grant.reason.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            grant.reason,
            style: const TextStyle(
              color: AuraSurface.muted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
        if (grant.permissions.isNotEmpty) ...[
          const SizedBox(height: AuraSpace.s8),
          Wrap(
            spacing: AuraSpace.s4,
            runSpacing: AuraSpace.s4,
            children: [
              for (final permission in grant.permissions)
                OperatorStatePill(state: permission, dense: true),
            ],
          ),
        ],
        // THE RULE, WHERE THE CONTROL WOULD HAVE BEEN. A missing button with
        // no explanation is indistinguishable from a broken one, and an
        // operator who cannot tell which will try again rather than act on
        // the actual constraint.
        if (withheldReason != null && live) ...[
          const SizedBox(height: AuraSpace.s8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.gpp_maybe_rounded,
                  size: 15, color: AuraSurface.warnInk),
              const SizedBox(width: AuraSpace.s6),
              Expanded(
                child: Text(
                  withheldReason!,
                  style: const TextStyle(
                    color: AuraSurface.muted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// WHERE AURA REACHES THEM.
///
/// Present because a support case that begins "I stopped getting calls" is
/// answered here and nowhere else. Read-only by design: revoking someone's
/// device is not an act this console owns.
class _PersonDevices extends ConsumerWidget {
  const _PersonDevices({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(personDetailProvider(userId));

    return detail.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (p) {
        if (p.devices.isEmpty) {
          return const OperatorSection(
            title: 'Devices',
            child: OperatorPanel(
              child: OperatorClear(
                title: 'No registered device',
                detail: 'Aura has nowhere to deliver a call or a notification.',
                icon: Icons.phonelink_erase_rounded,
              ),
            ),
          );
        }
        final active = p.devices.where((d) => d.isActive).toList();
        final retired = p.devices.where((d) => !d.isActive).toList();
        return OperatorSection(
          title: 'Devices',
          subtitle: '${active.length} active of ${p.devices.length}',
          child: OperatorPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final device in [...active, ...retired])
                  Padding(
                    padding: const EdgeInsets.only(bottom: AuraSpace.s8),
                    child: Row(
                      children: [
                        Icon(
                          device.isActive
                              ? Icons.smartphone_rounded
                              : Icons.phonelink_erase_rounded,
                          size: 15,
                          color: device.isActive
                              ? AuraSurface.goodInk
                              : AuraSurface.faint,
                        ),
                        const SizedBox(width: AuraSpace.s8),
                        Expanded(
                          child: Text(
                            device.label,
                            style: TextStyle(
                              color: device.isActive
                                  ? AuraSurface.ink
                                  : AuraSurface.faint,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        if (device.appVersion != null)
                          Text(
                            device.appVersion!,
                            style: const TextStyle(
                              color: AuraSurface.muted,
                              fontSize: 11.5,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
