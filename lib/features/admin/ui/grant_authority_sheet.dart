/// APPOINTING AN OPERATOR.
///
/// Until 2026-09-17 the console could list a person's grants, narrow them and
/// revoke them — but it could not create one. `createGrant()` had sat in the
/// repository with no caller since it was written, so the only way to appoint
/// an operator was `scripts/bootstrap-admin.ts`, which refuses once any active
/// grant exists. In practice that meant Aura could never appoint a second
/// operator at all, and found out when it needed one: the Founder's identity
/// submission could not be reviewed by anybody, because he was the only admin
/// and a reviewer may never decide their own submission.
///
/// This is the missing surface, and nothing more than the missing surface. It
/// calls the same canonical `POST /v1/admin/grants` the API has always
/// exposed, under the same `USERS_WRITE` gate, producing the same
/// `admin.grant.created` audit row naming the real grantor.
///
/// TWO RULES IT ENFORCES IN THE UI, because the API cannot:
///
///   * OWNER IS NOT OFFERED. `effectivePermissionsForGrant()` resolves OWNER
///     to the entire permission catalogue regardless of any stored array, so an
///     OWNER grant intended to be narrow is not narrow and cannot be made
///     narrow. Offering it beside a permission picker would be offering a
///     choice that does not mean what it appears to mean.
///
///   * AT LEAST ONE PERMISSION MUST BE CHOSEN. The API falls back to the
///     role's defaults when the permissions array is absent. That is a role
///     shortcut that silently expands authority, so this surface never sends
///     an empty array.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../data/admin_providers.dart';
import 'operator_action.dart';
import 'operator_kit.dart';

/// The catalogue, from the server that defines it.
///
/// Never a list held on this side: the two would drift the first time a scope
/// is added, which is how the identity scopes came to be ungrantable.
final adminPermissionCatalogueProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  return ref.read(adminRepositoryProvider).fetchPermissionCatalogue();
});

/// WHAT A CAPABILITY FAMILY ACTUALLY GOVERNS.
///
/// Presentation only. The CATALOGUE is still the server's — a family absent
/// from this map renders with its raw name and no description rather than
/// being hidden, because hiding a scope nobody wrote a line for is how the
/// identity scopes came to be ungrantable in the first place.
///
/// Descriptions state what the server actually enforces. Nothing here invents
/// a semantic the routes do not have.
const _familyDescription = <String, String>{
  'IDENTITY_VERIFICATION':
      'Is this person really who they say they are. The identity review queue, '
      'the government ID and selfie evidence behind it, and the decision.',
  'VERIFICATION':
      'Is this institution legitimate, and does this person hold the authority '
      'they claim over it. Institution domains, existence and authority proofs, '
      'and revoking institution authority.',
  'USERS':
      'People. Accounts, standing, and appointing operators — USERS_WRITE is '
      'what allows granting authority to somebody else.',
  'AUDIT':
      'The estate record. The admin audit log, every grant in the estate, and '
      'the migration reports.',
  'MODERATION': 'Reported content and moderation decisions.',
  'COMMUNICATIONS':
      'Institutional communication — drafting, approving and sending.',
  'ANNOUNCEMENTS': 'Announcements and their publication.',
  'INSTITUTIONS': 'Institution records and settings.',
  'SETTINGS': 'Platform configuration.',
  'ANALYTICS': 'Usage and platform analytics.',
  'SYSTEM_HEALTH': 'Platform health and service status.',
  'PRODUCT_FEEDBACK': 'Product feedback submitted by members.',
  'SUPPORT': 'Support requests.',
  'DISCOVERY': 'Whether what Aura published is reachable and being found.',
  'DISCOVERY_EVIDENCE':
      'The search text people actually typed. Person-identifying at low '
      'volume, and a separate grant from Discovery for that reason.',
  'EXTERNAL_CONSUMERS':
      'Systems that build on Aura Meetings, and the credentials they hold.',
};

/// Families close enough in name to be mistaken for one another.
///
/// `IDENTITY_VERIFICATION_*` and `VERIFICATION_*` are four near-identical
/// names governing two unrelated questions. In a flat alphabetical list they
/// sit adjacent with nothing to separate them.
const _confusableWith = <String, String>{
  'VERIFICATION': 'IDENTITY_VERIFICATION',
  'IDENTITY_VERIFICATION': 'VERIFICATION',
};

/// Read or act, from the verb the permission ends in.
String? _verbOf(String permission) {
  if (permission.endsWith('_READ')) return 'read only';
  if (permission.endsWith('_WRITE')) return 'can act';
  if (permission.endsWith('_APPROVE')) return 'can approve';
  if (permission.endsWith('_SEND')) return 'can send';
  return null;
}

/// The family a permission belongs to: everything before the trailing verb.
String _familyOf(String permission) {
  for (final suffix in const ['_READ', '_WRITE', '_APPROVE', '_SEND']) {
    if (permission.endsWith(suffix)) {
      return permission.substring(0, permission.length - suffix.length);
    }
  }
  return permission;
}

/// What the operator chose, once they have chosen it.
class _Proposed {
  const _Proposed({required this.role, required this.permissions});
  final String role;
  final List<String> permissions;
}

/// Roles this surface will offer.
///
/// OWNER is deliberately absent — see the library comment. The role is a label
/// here: for every role below, an explicit permissions array is what the
/// authority resolves, so the choice of role never widens what is granted.
const _offerableRoles = <String, String>{
  'ANALYST': 'Analyst — the narrowest standing label',
  'SUPPORT': 'Support',
  'MODERATOR': 'Moderator',
  'ADMIN': 'Admin',
};

/// Run the full appointment ceremony. Returns true when a grant was created.
Future<bool> runGrantAuthority(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  required String personLabel,
}) async {
  final proposed = await showModalBottomSheet<_Proposed>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _GrantAuthoritySheet(personLabel: personLabel),
  );
  if (proposed == null || !context.mounted) return false;

  final done = await runOperatorAction(
    context,
    OperatorAction(
      title: 'Grant operator authority',
      subject: personLabel,
      detail:
          'Creates one grant with exactly the permissions listed. The role '
          'does not widen them — the explicit list is what the authority '
          'resolves.',
      confirmLabel: 'Grant authority',
      requiresReason: true,
      reasonLabel: 'Why this person needs this authority',
      consequences: [
        OperatorConsequence(
          text: '${proposed.permissions.length} '
              'permission${proposed.permissions.length == 1 ? '' : 's'} '
              'granted: ${proposed.permissions.join(', ')}.',
          tone: OperatorTone.warn,
          icon: Icons.key_rounded,
        ),
        const OperatorConsequence(
          text: 'They can act on every surface those permissions open.',
          tone: OperatorTone.warn,
          icon: Icons.admin_panel_settings_rounded,
        ),
        OperatorConsequence.recorded('This grant, naming you as the grantor'),
      ],
      perform: (reason) async {
        await ref.read(adminRepositoryProvider).createGrant(
              userId: userId,
              role: proposed.role,
              permissions: proposed.permissions,
              reason: reason ?? '',
            );
        return 'Granted. ${proposed.permissions.length} '
            'permission${proposed.permissions.length == 1 ? '' : 's'}, '
            'recorded against your authority.';
      },
    ),
  );
  return done;
}

class _GrantAuthoritySheet extends ConsumerStatefulWidget {
  const _GrantAuthoritySheet({required this.personLabel});

  final String personLabel;

  @override
  ConsumerState<_GrantAuthoritySheet> createState() =>
      _GrantAuthoritySheetState();
}

class _GrantAuthoritySheetState extends ConsumerState<_GrantAuthoritySheet> {
  final _chosen = <String>{};
  String _role = 'ANALYST';

  @override
  Widget build(BuildContext context) {
    final catalogue = ref.watch(adminPermissionCatalogueProvider);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: AuraSurface.card,
          border: Border(top: BorderSide(color: AuraSurface.divider)),
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AuraRadius.xl)),
        ),
        padding: const EdgeInsets.fromLTRB(
          AuraSpace.s20,
          AuraSpace.s12,
          AuraSpace.s20,
          AuraSpace.s20,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AuraSpace.s16),
                  decoration: BoxDecoration(
                    color: AuraSurface.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Grant operator authority',
                style: TextStyle(
                  color: AuraSurface.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.personLabel,
                style: const TextStyle(
                  color: AuraSurface.muted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: AuraSpace.s16),
              _RoleRow(
                role: _role,
                onChanged: (r) => setState(() => _role = r),
              ),
              const SizedBox(height: AuraSpace.s16),
              const Text(
                'Permissions',
                style: TextStyle(
                  color: AuraSurface.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'From the server catalogue, grouped by what they govern. Only '
                'what you tick is granted.',
                style: TextStyle(color: AuraSurface.muted, fontSize: 12),
              ),
              const SizedBox(height: AuraSpace.s8),
              Flexible(
                child: catalogue.when(
                  loading: () => const OperatorLoading(lines: 4),
                  error: (_, __) => const OperatorFailure(
                    title: 'The permission catalogue could not be read',
                    detail:
                        'Without it this surface would be guessing at what can '
                        'be granted, so it will not offer a choice.',
                  ),
                  data: (all) {
                    // GROUPED BY WHAT THEY GOVERN. A flat alphabetical list
                    // put VERIFICATION_* directly beneath
                    // IDENTITY_VERIFICATION_* with nothing to tell them apart
                    // — four near-identical names, two unrelated questions,
                    // and no way to know which was which without reading the
                    // source.
                    final families = <String, List<String>>{};
                    for (final perm in all) {
                      families.putIfAbsent(_familyOf(perm), () => []).add(perm);
                    }
                    final ordered = families.keys.toList()..sort();
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: ordered.length,
                      itemBuilder: (_, i) {
                        final family = ordered[i];
                        final members = families[family]!..sort();
                        final description = _familyDescription[family];
                        final confusable = _confusableWith[family];
                        final anyChosen =
                            members.any((m) => _chosen.contains(m));

                        return Padding(
                          padding:
                              const EdgeInsets.only(bottom: AuraSpace.s16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                family.replaceAll('_', ' '),
                                style: const TextStyle(
                                  color: AuraSurface.ink,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              if (description != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    description,
                                    style: const TextStyle(
                                      color: AuraSurface.muted,
                                      fontSize: 11.5,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              // The warning appears once this family is
                              // actually being granted. A caution on every
                              // family every time is a caution nobody reads.
                              if (confusable != null && anyChosen)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'This is NOT '
                                    '${confusable.replaceAll('_', ' ')}. '
                                    'Check you mean this one.',
                                    style: const TextStyle(
                                      color: AuraSurface.dangerInk,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 2),
                              for (final perm in members)
                                CheckboxListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  value: _chosen.contains(perm),
                                  onChanged: (v) => setState(() {
                                    if (v == true) {
                                      _chosen.add(perm);
                                    } else {
                                      _chosen.remove(perm);
                                    }
                                  }),
                                  title: Text(
                                    perm,
                                    style: const TextStyle(
                                      color: AuraSurface.ink,
                                      fontSize: 12.5,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  subtitle: _verbOf(perm) == null
                                      ? null
                                      : Text(
                                          _verbOf(perm)!,
                                          style: const TextStyle(
                                            color: AuraSurface.muted,
                                            fontSize: 11,
                                          ),
                                        ),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: AuraSpace.s12),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AuraSpace.s12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      // NEVER an empty list. An absent permissions array makes
                      // the API fall back to the role's defaults, which is the
                      // silent expansion this surface exists to avoid.
                      onPressed: _chosen.isEmpty
                          ? null
                          : () => Navigator.of(context).pop(
                                _Proposed(
                                  role: _role,
                                  permissions: _chosen.toList()..sort(),
                                ),
                              ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AuraSurface.accent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AuraSurface.elevated,
                        padding: const EdgeInsets.symmetric(
                          vertical: AuraSpace.s14,
                        ),
                      ),
                      child: Text(
                        _chosen.isEmpty
                            ? 'Choose at least one permission'
                            : 'Review ${_chosen.length} '
                                'permission${_chosen.length == 1 ? '' : 's'}',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleRow extends StatelessWidget {
  const _RoleRow({required this.role, required this.onChanged});

  final String role;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Role label',
          style: TextStyle(
            color: AuraSurface.ink,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'A label only. The explicit permissions below are what the authority '
          'resolves. OWNER is not offered here — it resolves to every '
          'permission regardless of what is ticked.',
          style: TextStyle(color: AuraSurface.muted, fontSize: 12),
        ),
        const SizedBox(height: AuraSpace.s8),
        Wrap(
          spacing: AuraSpace.s8,
          runSpacing: AuraSpace.s8,
          children: [
            for (final entry in _offerableRoles.entries)
              ChoiceChip(
                selected: role == entry.key,
                onSelected: (_) => onChanged(entry.key),
                label: Text(entry.key),
                labelStyle: TextStyle(
                  color: role == entry.key ? Colors.white : AuraSurface.ink,
                  fontSize: 12,
                ),
                selectedColor: AuraSurface.accent,
                backgroundColor: AuraSurface.elevated,
                side: const BorderSide(color: AuraSurface.divider),
              ),
          ],
        ),
      ],
    );
  }
}
