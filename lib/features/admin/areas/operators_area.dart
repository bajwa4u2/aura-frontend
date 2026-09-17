/// OPERATOR GOVERNANCE — who may act as Aura, and with what authority.
///
/// Appointment used to be a button on every person's page, wherever a person
/// happened to hold no grant. That was wrong in two directions at once: it put
/// an estate-level governance act beside every ordinary member in the estate,
/// and it appeared ONLY when somebody held no authority, so a person who
/// already held a grant could never be given a second one. Broad in
/// presentation, incomplete in behaviour.
///
/// Appointing an operator is not an attribute of a person. It is a decision
/// about the estate, and it belongs on a surface of its own where the current
/// state can be read before anything is changed.
///
/// Same canonical API throughout: `GET /v1/admin/grants` under `AUDIT_READ` to
/// read, `POST /v1/admin/grants` under `USERS_WRITE` to appoint. No parallel
/// operator system, no new authority.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../data/admin_providers.dart';
import '../domain/operator_authority_provider.dart';
import '../domain/operator_capability.dart';
import '../ui/grant_authority_sheet.dart';
import '../ui/operator_kit.dart';

/// Every grant in the estate, revoked ones included.
///
/// History is the point: authority that was held and then taken away is
/// exactly what somebody reviewing operator governance needs to see.
final operatorGrantsProvider =
    FutureProvider.autoDispose<List<AdminGrant>>((ref) async {
  return ref.read(adminRepositoryProvider).fetchGrants();
});

/// People to appoint from, narrowed by what the operator types.
final _appointCandidatesProvider = FutureProvider.autoDispose
    .family<List<AdminUserSummary>, String>((ref, query) async {
  if (query.trim().length < 2) return const [];
  return ref
      .read(adminRepositoryProvider)
      .fetchUsers(query: query.trim(), limit: 20);
});

class OperatorsArea extends ConsumerWidget {
  const OperatorsArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authority = ref.watch(operatorAuthorityProvider).valueOrNull ??
        const OperatorAuthority.none();

    // AUDIT_READ is what the grants endpoint requires. Asking the same question
    // the server will ask keeps a visible surface and a working request from
    // disagreeing.
    if (!authority.can(OperatorCapability.auditRead)) {
      return const Padding(
        padding: EdgeInsets.all(AuraSpace.s20),
        child: OperatorInsufficientCapability(needs: 'audit'),
      );
    }

    final grants = ref.watch(operatorGrantsProvider);
    final canWrite = authority.can(OperatorCapability.usersWrite);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        return ListView(
          padding: EdgeInsets.all(wide ? AuraSpace.s20 : AuraSpace.s12),
          children: [
            OperatorSection(
              title: 'Appointing an operator',
              child: OperatorPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'An operator grant is authority over other people’s '
                      'accounts, standing and records. It is recorded against '
                      'your name, and it does not expire unless an expiry is '
                      'set.',
                      style: TextStyle(
                        color: AuraSurface.muted,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: AuraSpace.s12),
                    if (canWrite)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          onPressed: () => _appoint(context, ref),
                          icon: const Icon(Icons.shield_moon_outlined, size: 16),
                          label: const Text('Appoint an operator'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AuraSurface.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AuraSpace.s16,
                              vertical: AuraSpace.s12,
                            ),
                          ),
                        ),
                      )
                    else
                      const OperatorInsufficientCapability(needs: 'users'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AuraSpace.s20),
            OperatorSection(
              title: 'Operator grants',
              subtitle: 'Every grant in the estate, revoked ones included',
              child: grants.when(
                loading: () => const OperatorLoading(lines: 5),
                error: (_, __) => const OperatorFailure(
                  title: 'The grant list could not be read',
                  detail: 'Nothing has changed. Read the current state before '
                      'appointing or revoking anybody.',
                ),
                data: (rows) => rows.isEmpty
                    ? const OperatorPanel(
                        child: OperatorClear(
                          title: 'No operator grants exist',
                          icon: Icons.shield_outlined,
                        ),
                      )
                    : Column(
                        children: [
                          for (final g in rows) ...[
                            _GrantRow(grant: g),
                            if (g != rows.last)
                              const SizedBox(height: AuraSpace.s8),
                          ],
                        ],
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _appoint(BuildContext context, WidgetRef ref) async {
    final picked = await showModalBottomSheet<AdminUserSummary>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PersonPicker(),
    );
    if (picked == null || !context.mounted) return;

    final done = await runGrantAuthority(
      context,
      ref,
      userId: picked.id,
      personLabel: '${picked.person.displayName} · ${picked.email}',
    );
    if (done) {
      ref.invalidate(operatorGrantsProvider);
    }
  }
}

/// Choose the person BEFORE choosing the authority.
///
/// Deliberately a search rather than a list of everybody: appointing an
/// operator should require knowing who you are appointing.
class _PersonPicker extends ConsumerStatefulWidget {
  const _PersonPicker();

  @override
  ConsumerState<_PersonPicker> createState() => _PersonPickerState();
}

class _PersonPickerState extends ConsumerState<_PersonPicker> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(_appointCandidatesProvider(_query));
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: const BoxDecoration(
          color: AuraSurface.card,
          border: Border(top: BorderSide(color: AuraSurface.divider)),
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AuraRadius.xl)),
        ),
        padding: const EdgeInsets.fromLTRB(
          AuraSpace.s20,
          AuraSpace.s16,
          AuraSpace.s20,
          AuraSpace.s20,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Who are you appointing?',
                style: TextStyle(
                  color: AuraSurface.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AuraSpace.s12),
              TextField(
                controller: _controller,
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(color: AuraSurface.ink, fontSize: 13.5),
                decoration: const InputDecoration(
                  hintText: 'Name, handle or email',
                  hintStyle:
                      TextStyle(color: AuraSurface.muted, fontSize: 13.5),
                  filled: true,
                  fillColor: AuraSurface.elevated,
                  border: OutlineInputBorder(borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: AuraSpace.s12),
              Flexible(
                child: results.when(
                  loading: () => const OperatorLoading(lines: 3),
                  error: (_, __) => const OperatorFailure(
                    title: 'People could not be searched',
                  ),
                  data: (people) {
                    if (_query.trim().length < 2) {
                      return const Padding(
                        padding: EdgeInsets.only(top: AuraSpace.s8),
                        child: Text(
                          'Type at least two characters.',
                          style: TextStyle(
                            color: AuraSurface.muted,
                            fontSize: 12.5,
                          ),
                        ),
                      );
                    }
                    if (people.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.only(top: AuraSpace.s8),
                        child: Text(
                          'Nobody matches that.',
                          style: TextStyle(
                            color: AuraSurface.muted,
                            fontSize: 12.5,
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: people.length,
                      itemBuilder: (_, i) {
                        final p = people[i];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            p.person.displayName,
                            style: const TextStyle(
                              color: AuraSurface.ink,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            '${p.email}  ·  @${p.handle}',
                            style: const TextStyle(
                              color: AuraSurface.muted,
                              fontSize: 11.5,
                            ),
                          ),
                          onTap: () => Navigator.of(context).pop(p),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One grant, stated so it can be read before anything is decided about it.
class _GrantRow extends StatelessWidget {
  const _GrantRow({required this.grant});

  final AdminGrant grant;

  @override
  Widget build(BuildContext context) {
    final label = grant.granteeDisplayName.isNotEmpty
        ? grant.granteeDisplayName
        : (grant.granteeHandle.isNotEmpty ? '@${grant.granteeHandle}' : grant.userId);

    return OperatorPanel(
      tone: grant.active ? OperatorTone.pending : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AuraSurface.ink,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              OperatorStatePill(
                state: grant.active ? grant.role.toUpperCase() : 'REVOKED',
              ),
            ],
          ),
          const SizedBox(height: 4),
          // STORED GRANT DATA, not effective authority. An OWNER grant resolves
          // to the whole catalogue whatever this array says, so the row is
          // labelled rather than presented as what the holder can do.
          _line(
            'Permissions on the grant',
            grant.permissions.isEmpty
                ? 'none stored — role defaults apply'
                : grant.permissions.join(', '),
          ),
          if (grant.role.toUpperCase() == 'OWNER')
            _line(
              'Note',
              'OWNER resolves to every permission, whatever is stored above.',
            ),
          if (grant.grantedBy.isNotEmpty) _line('Granted by', grant.grantedBy),
          if (grant.reason.isNotEmpty) _line('Reason', grant.reason),
          _line('Granted', grant.createdAt.toIso8601String()),
          if (grant.expiresAt != null)
            _line('Expires', grant.expiresAt!.toIso8601String()),
        ],
      ),
    );
  }

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.only(top: 3),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(
              color: AuraSurface.muted,
              fontSize: 12,
              height: 1.35,
            ),
            children: [
              TextSpan(
                text: '$label  ',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              TextSpan(text: value),
            ],
          ),
        ),
      );
}
