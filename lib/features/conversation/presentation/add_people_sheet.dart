import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../search/search_repository.dart';
import '../../../core/net/dio_provider.dart';
import '../data/conversations_repository.dart';
import '../../../core/identity/person_identity_model.dart';

/// ADD PEOPLE — the conversation's contextual entry into the canonical
/// Invitation System. Pick people (or type an email for someone not on
/// Aura yet); each receives a consent invitation. No conversion ceremony,
/// no naming prerequisite, no machinery (canon §14/§36).
Future<void> showAddPeopleSheet(
  BuildContext context,
  WidgetRef ref,
  String conversationId,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AuraSurface.page,
    builder: (_) => _AddPeopleSheet(conversationId: conversationId),
  );
}

class _AddPeopleSheet extends ConsumerStatefulWidget {
  const _AddPeopleSheet({required this.conversationId});
  final String conversationId;

  @override
  ConsumerState<_AddPeopleSheet> createState() => _AddPeopleSheetState();
}

class _AddPeopleSheetState extends ConsumerState<_AddPeopleSheet> {
  final _query = TextEditingController();
  List<Map<String, dynamic>> _results = const [];
  bool _busy = false;

  Future<void> _search(String q) async {
    if (q.trim().length < 2) {
      setState(() => _results = const []);
      return;
    }
    final result = await SearchRepository(ref.read(dioProvider)).search(q);
    if (mounted) setState(() => _results = result.users);
  }

  Future<void> _invite({String? userId, String? email}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(conversationsRepositoryProvider).addPeople(
        widget.conversationId,
        recipients: [
          if (userId != null) {'userId': userId},
          if (email != null) {'email': email},
        ],
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation sent.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not invite — try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final typedEmail = _query.text.trim();
    final looksLikeEmail =
        typedEmail.contains('@') && typedEmail.contains('.');
    return Padding(
      padding: EdgeInsets.only(
        left: AuraSpace.s16,
        right: AuraSpace.s16,
        top: AuraSpace.s16,
        bottom: MediaQuery.of(context).viewInsets.bottom + AuraSpace.s16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add people', style: AuraText.headline),
          const SizedBox(height: AuraSpace.s4),
          Text(
            'They join after accepting your invitation and can read the '
            'conversation history.',
            style: AuraText.small.copyWith(color: AuraSurface.muted),
          ),
          const SizedBox(height: AuraSpace.s12),
          TextField(
            controller: _query,
            autofocus: true,
            onChanged: _search,
            decoration: const InputDecoration(
              hintText: 'Search people, or type an email…',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: AuraSpace.s8),
          if (looksLikeEmail)
            ListTile(
              leading: const Icon(Icons.alternate_email_rounded),
              title: Text('Invite $typedEmail to Aura and this conversation'),
              onTap: _busy ? null : () => _invite(email: typedEmail),
            ),
          // F053/F116 — the people you add are named the way the
          // conversation will name them.
          for (final u in _results.take(8))
            if (AuraPersonIdentity.fromJson(u) case final person)
            ListTile(
              leading: const Icon(Icons.person_outline_rounded),
              title: Text(person.label),
              subtitle: Text('@${person.handle}', style: AuraText.micro),
              onTap: _busy
                  ? null
                  : () => _invite(userId: (u['id'] ?? '').toString()),
            ),
        ],
      ),
    );
  }
}
