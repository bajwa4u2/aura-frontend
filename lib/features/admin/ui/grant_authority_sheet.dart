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
                'From the server catalogue. Only what you tick is granted.',
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
                  data: (all) => ListView.builder(
                    shrinkWrap: true,
                    itemCount: all.length,
                    itemBuilder: (_, i) {
                      final p = all[i];
                      final on = _chosen.contains(p);
                      return CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: on,
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _chosen.add(p);
                          } else {
                            _chosen.remove(p);
                          }
                        }),
                        title: Text(
                          p,
                          style: const TextStyle(
                            color: AuraSurface.ink,
                            fontSize: 12.5,
                            fontFamily: 'monospace',
                          ),
                        ),
                      );
                    },
                  ),
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
