import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/identity/person_identity_model.dart';
import '../../../../core/product/product_language.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_surface.dart';
import '../../../institutions/data/institutions_repository.dart';

/// One institution member who could be added to a meeting.
class MeetingMemberChoice {
  const MeetingMemberChoice({required this.userId, required this.name});
  final String userId;
  final String name;
}

/// The members of [institutionId] who are not already in the meeting.
Future<List<MeetingMemberChoice>> loadMeetingMemberChoices(
  InstitutionsRepository repo,
  String institutionId, {
  required Set<String> alreadyIn,
}) async {
  final data = await repo.listMembers(institutionId);
  final raw = data['members'];
  final out = <MeetingMemberChoice>[];
  if (raw is List) {
    for (final entry in raw.whereType<Map>()) {
      final member = Map<String, dynamic>.from(entry);
      final userId = (member['userId'] ?? '').toString().trim();
      if (userId.isEmpty || alreadyIn.contains(userId)) continue;
      final user = member['user'] is Map
          ? Map<String, dynamic>.from(member['user'] as Map)
          : const <String, dynamic>{};
      out.add(MeetingMemberChoice(
        userId: userId,
        name: AuraPersonIdentity.fromJson(user).label,
      ));
    }
  }
  out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return out;
}

/// ADD AURA MEMBERS AFTER THE MEETING EXISTS (6 Nov 2026).
///
/// Members could be chosen only while the meeting was being created; after
/// that the page offered "Invite by email" alone. The server has always
/// taken `userId` on its invite route, and now makes that person a
/// participant who is asked to accept or decline.
///
/// Returns the chosen user ids, or null when the dialog was dismissed.
Future<List<String>?> showAddMeetingMembersDialog(
  BuildContext context, {
  required String institutionId,
  required Set<String> alreadyIn,
}) {
  return showDialog<List<String>>(
    context: context,
    builder: (_) => _AddMembersDialog(
      institutionId: institutionId,
      alreadyIn: alreadyIn,
    ),
  );
}

class _AddMembersDialog extends ConsumerStatefulWidget {
  const _AddMembersDialog({
    required this.institutionId,
    required this.alreadyIn,
  });

  final String institutionId;
  final Set<String> alreadyIn;

  @override
  ConsumerState<_AddMembersDialog> createState() => _AddMembersDialogState();
}

class _AddMembersDialogState extends ConsumerState<_AddMembersDialog> {
  final _search = TextEditingController();
  final _chosen = <String>{};
  late Future<List<MeetingMemberChoice>> _members;

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(() => setState(() {}));
  }

  void _load() {
    _members = loadMeetingMemberChoices(
      ref.read(institutionsRepositoryProvider),
      widget.institutionId,
      alreadyIn: widget.alreadyIn,
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add members'),
      content: SizedBox(
        width: 460,
        child: FutureBuilder<List<MeetingMemberChoice>>(
          future: _members,
          builder: (context, snap) {
            // Waits only while there is nothing to show (a refresh keeps the
            // place).
            if (!snap.hasData && !snap.hasError) {
              return const Padding(
                padding: EdgeInsets.all(AuraSpace.s16),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            if (snap.hasError) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Couldn't load the member list."),
                  const SizedBox(height: AuraSpace.s8),
                  TextButton(
                    onPressed: () => setState(_load),
                    child: Text(ProductLabels.of(ProductAction.retry)),
                  ),
                ],
              );
            }
            final all = snap.data ?? const <MeetingMemberChoice>[];
            if (all.isEmpty) {
              return const Text(
                'Every member of this institution is already in the meeting.',
              );
            }
            final query = _search.text.trim().toLowerCase();
            final shown = query.isEmpty
                ? all
                : all
                    .where((m) => m.name.toLowerCase().contains(query))
                    .toList();
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    labelText: 'Search members',
                    prefixIcon: Icon(Icons.search_rounded),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AuraSpace.s8),
                Flexible(
                  child: shown.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(AuraSpace.s8),
                          child: Text(
                            'No members match that search.',
                            style: TextStyle(color: AuraSurface.muted),
                          ),
                        )
                      : ListView(
                          shrinkWrap: true,
                          children: [
                            for (final m in shown)
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: _chosen.contains(m.userId),
                                title: Text(m.name),
                                onChanged: (on) => setState(() {
                                  if (on == true) {
                                    _chosen.add(m.userId);
                                  } else {
                                    _chosen.remove(m.userId);
                                  }
                                }),
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: AuraSpace.s8),
                const Text(
                  'Each person is told in Aura and by email, and asked to '
                  'accept or decline.',
                  style: TextStyle(color: AuraSurface.muted),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _chosen.isEmpty
              ? null
              : () => Navigator.of(context).pop(_chosen.toList()),
          child: Text(
            _chosen.length <= 1 ? 'Add member' : 'Add ${_chosen.length} members',
          ),
        ),
      ],
    );
  }
}
